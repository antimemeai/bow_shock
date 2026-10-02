#import "table_connection.h"
#import "continuous_clock.h"
#import <CoreFoundation/CoreFoundation.h>
#include <limits>
#include <errno.h>
#include <fcntl.h>
#include <mach/mach_time.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <initializer_list>

namespace {
double Now() {
  static const mach_timebase_info_data_t scale = [] {
    mach_timebase_info_data_t value = {};
    if (mach_timebase_info(&value) != KERN_SUCCESS) return mach_timebase_info_data_t{};
    return value;
  }();
  if (!scale.numer || !scale.denom) return std::numeric_limits<double>::infinity();
  return static_cast<double>(mach_continuous_time()) * scale.numer / scale.denom / 1e9;
}
void Close(int& fd) { if (fd >= 0) { close(fd); fd = -1; } }
bool AboveStdio(int& fd) {
  if (fd >= 3) return true;
  int moved = fcntl(fd, F_DUPFD_CLOEXEC, 3);
  if (moved == -1) return false;
  Close(fd); fd = moved; return true;
}
bool OwnedPipe(int (&fds)[2]) {
  return pipe(fds) == 0 && AboveStdio(fds[0]) && AboveStdio(fds[1]);
}
bool Configure(int fd, bool nonblocking) {
  return fcntl(fd, F_SETFD, FD_CLOEXEC) != -1 &&
      (!nonblocking || fcntl(fd, F_SETFL, O_NONBLOCK) != -1);
}
// Worker only. Keep the PID owned until reap; never signal a reaped/reused PID.
void TerminateAndReap(pid_t& pid) {
  if (pid <= 0) return;
  pid_t result = waitpid(pid, nullptr, WNOHANG);
  if (result == pid || (result == -1 && errno == ECHILD)) { pid = -1; return; }
  kill(pid, SIGTERM);
  double deadline = Now() + .25;
  bool killed = false;
  for (;;) {
    result = waitpid(pid, nullptr, WNOHANG);
    if (result == pid || (result == -1 && errno == ECHILD)) { pid = -1; return; }
    if (!killed && Now() >= deadline) { kill(pid, SIGKILL); killed = true; }
    // Rare uninterruptible exit stays owned/reconciled off the UI thread.
    poll(nullptr, 0, 20);
  }
}
bool Launch(NSString* path, NSString* database, NSString* clock, NSString* origin, int& input, int& output, pid_t& pid) {
  int toChild[2] = {-1, -1}, fromChild[2] = {-1, -1}, stderrCopy = -1;
  bool success = false, haveActions = false, haveAttributes = false;
  posix_spawn_file_actions_t actions;
  posix_spawnattr_t attributes;
  do {
    if (!OwnedPipe(toChild) || !OwnedPipe(fromChild)) break;
    if (!Configure(toChild[0], false) || !Configure(toChild[1], true) ||
        !Configure(fromChild[0], true) || !Configure(fromChild[1], false)) break;
    if (fcntl(toChild[1], F_SETNOSIGPIPE, 1) == -1) break;
    stderrCopy = fcntl(STDERR_FILENO, F_DUPFD_CLOEXEC, 3);
    if (stderrCopy == -1 && errno == EBADF) {
      stderrCopy = open("/dev/null", O_WRONLY | O_CLOEXEC);
      if (stderrCopy != -1 && !AboveStdio(stderrCopy)) break;
    }
    if (stderrCopy == -1 || posix_spawn_file_actions_init(&actions) != 0) break;
    haveActions = true;
    if (posix_spawnattr_init(&attributes) != 0) break;
    haveAttributes = true;
    sigset_t defaults; sigemptyset(&defaults); sigaddset(&defaults, SIGCHLD);
    if (posix_spawnattr_setsigdefault(&attributes, &defaults) != 0 ||
        posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF) != 0) break;
    if (posix_spawn_file_actions_adddup2(&actions, toChild[0], STDIN_FILENO) != 0 ||
        posix_spawn_file_actions_adddup2(&actions, fromChild[1], STDOUT_FILENO) != 0 ||
        posix_spawn_file_actions_adddup2(&actions, stderrCopy, STDERR_FILENO) != 0) break;
    bool closed = true;
    for (int fd : {toChild[0], toChild[1], fromChild[0], fromChild[1], stderrCopy})
      if (posix_spawn_file_actions_addclose(&actions, fd) != 0) closed = false;
    if (!closed) break;
    const char* executable = path.fileSystemRepresentation;
    char* argv[] = {const_cast<char*>(executable), const_cast<char*>("--table-db"),
        const_cast<char*>(database.fileSystemRepresentation), const_cast<char*>("--clock-probe"),
        const_cast<char*>(clock.fileSystemRepresentation), const_cast<char*>("--owned-origin"),
        const_cast<char*>(origin.UTF8String), nullptr};
    char lang[] = "LANG=en_US.UTF-8";
    char* environment[] = {lang, nullptr};
    if (posix_spawn(&pid, executable, &actions, &attributes, argv, environment) != 0) break;
    input = toChild[1]; toChild[1] = -1;
    output = fromChild[0]; fromChild[0] = -1;
    success = true;
  } while (false);
  if (haveAttributes) posix_spawnattr_destroy(&attributes);
  if (haveActions) posix_spawn_file_actions_destroy(&actions);
  for (int& fd : toChild) Close(fd);
  for (int& fd : fromChild) Close(fd);
  Close(stderrCopy);
  return success;
}
}

namespace {
BOOL Keys(id object, NSArray* required, NSArray* optional = @[]) {
  if (![object isKindOfClass:NSDictionary.class]) return NO;
  NSSet* allowed = [NSSet setWithArray:[required arrayByAddingObjectsFromArray:optional]];
  for (id key in object) if (![key isKindOfClass:NSString.class] || ![allowed containsObject:key]) return NO;
  for (NSString* key in required) if (!object[key]) return NO;
  return YES;
}
BOOL Text(id value, NSUInteger limit, BOOL empty = NO) {
  if (![value isKindOfClass:NSString.class]) return NO;
  NSData* bytes = [value dataUsingEncoding:NSUTF8StringEncoding];
  return bytes && bytes.length <= limit && (empty || bytes.length > 0);
}
BOOL Identity(id value, NSUInteger limit = 128) {
  return Text(value, limit) && [value rangeOfCharacterFromSet:
      [NSCharacterSet characterSetWithCharactersInString:@"\0\r\n"]].location == NSNotFound;
}
BOOL UInt(id value, uint64_t* result = nullptr, uint64_t maximum = UINT64_MAX, BOOL positive = NO) {
  if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return NO;
  const char type = *[value objCType];
  if (!strchr("cCsSiIlLqQ", type)) return NO;
  const bool unsign = strchr("CSILQ", type) != nullptr;
  if (!unsign && [value longLongValue] < 0) return NO;
  uint64_t number = [value unsignedLongLongValue];
  if (number > maximum || (positive && number == 0)) return NO;
  if (result) *result = number;
  return YES;
}
BOOL Boolean(id value) { return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID(); }
BOOL Review(id value) {
  return Keys(value, @[@"staging_id", @"version", @"content"]) && Identity(value[@"staging_id"]) &&
      UInt(value[@"version"], nullptr, UINT64_MAX, YES) && Text(value[@"content"], 24 * 1024);
}
BOOL Guard(id value) {
  if (!Keys(value, @[@"boot_id", @"valid_until_ns"]) || !Text(value[@"boot_id"], 36) ||
      !UInt(value[@"valid_until_ns"], nullptr, INT64_MAX, YES)) return NO;
  NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:value[@"boot_id"]];
  return uuid && [value[@"boot_id"] length] == 36;
}
BOOL CurrentGuard(id guard) {
  if (!Guard(guard)) return NO;
  NSDictionary* witness = BSContinuousClockWitness();
  return witness && [witness[@"boot_id"] isEqual:guard[@"boot_id"]] &&
      [witness[@"continuous_ns"] unsignedLongLongValue] < [guard[@"valid_until_ns"] unsignedLongLongValue];
}
BOOL Batch(id batch, BOOL native) {
  if (!Keys(batch, @[@"schema_version", @"pattern_version", @"partial", @"rows"]) ||
      !Identity(batch[@"schema_version"]) || !Identity(batch[@"pattern_version"]) || !Boolean(batch[@"partial"]) ||
      ![batch[@"rows"] isKindOfClass:NSArray.class] || [batch[@"rows"] count] == 0 || [batch[@"rows"] count] > (native ? 2u : 16u)) return NO;
  for (id row in batch[@"rows"]) {
    if (!Keys(row, @[@"fields"]) || ![row[@"fields"] isKindOfClass:NSArray.class] ||
        [row[@"fields"] count] == 0 || [row[@"fields"] count] > (native ? 6u : 8u)) return NO;
    for (id field in row[@"fields"]) {
      if (!Keys(field, @[@"name", @"state", @"source"]) || !Identity(field[@"name"])) return NO;
      id source = field[@"source"], state = field[@"state"];
      if (!Keys(source, @[@"observation", @"node_id", @"visibility", @"normalization"], @[@"fragment"]) ||
          !Identity(source[@"visibility"]) || !Identity(source[@"normalization"]) ||
          (source[@"node_id"] != NSNull.null && !UInt(source[@"node_id"], nullptr, INT64_MAX, YES)) ||
          (source[@"fragment"] && !Text(source[@"fragment"], 4096, YES))) return NO;
      id observation = source[@"observation"];
      if (!Keys(observation, @[@"run_id", @"surface_id", @"frame_id", @"document_id", @"capture_id", @"security_origin",
          @"attachment_generation", @"activation_generation", @"node_generation"], @[@"capture_start_ns", @"capture_end_ns"])) return NO;
      for (NSString* key in @[@"run_id", @"surface_id", @"frame_id", @"document_id", @"capture_id"])
        if (!Identity(observation[key])) return NO;
      if (!Identity(observation[@"security_origin"], 512)) return NO;
      for (NSString* key in @[@"attachment_generation", @"activation_generation", @"node_generation"])
        if (!UInt(observation[key], nullptr, UINT64_MAX, YES)) return NO;
      BOOL interval = observation[@"capture_start_ns"] || observation[@"capture_end_ns"];
      if ((native || interval) && (!UInt(observation[@"capture_start_ns"], nullptr, INT64_MAX, YES) ||
          !UInt(observation[@"capture_end_ns"], nullptr, INT64_MAX, YES) ||
          [observation[@"capture_start_ns"] unsignedLongLongValue] > [observation[@"capture_end_ns"] unsignedLongLongValue])) return NO;
      if (![state isKindOfClass:NSDictionary.class]) return NO;
      NSString* kind = state[@"kind"];
      if ([kind isEqual:@"value"] || [kind isEqual:@"invalid"]) {
        NSString* tail = [kind isEqual:@"value"] ? @"value" : @"reason";
        if (!Keys(state, @[@"kind", @"source", tail]) || !Text(state[@"source"], 4096, [kind isEqual:@"invalid"]) ||
            !Text(state[tail], 4096, YES) || source[@"node_id"] == NSNull.null) return NO;
        if (native && ![source[@"fragment"] isEqual:state[@"source"]]) return NO;
      } else if ([kind isEqual:@"ambiguous"]) {
        if (!Keys(state, @[@"kind", @"candidates"]) || ![state[@"candidates"] isKindOfClass:NSArray.class] ||
            [state[@"candidates"] count] < 2 || [state[@"candidates"] count] > 8) return NO;
        for (id candidate in state[@"candidates"]) {
          if (!Text(candidate, 4096, YES)) return NO;
          if (native && source[@"fragment"] && (!Text(candidate, 4096) || source[@"node_id"] == NSNull.null ||
              [source[@"fragment"] rangeOfString:candidate].location == NSNotFound)) return NO;
        }
      } else if ([kind isEqual:@"empty"] || [kind isEqual:@"missing"] || [kind isEqual:@"inaccessible"]) {
        if (!Keys(state, @[@"kind"])) return NO;
        BOOL present = [kind isEqual:@"empty"];
        if ((source[@"node_id"] != NSNull.null) != present) return NO;
        if (native && (present ? !source[@"fragment"] : source[@"fragment"] != nil)) return NO;
      } else return NO;
    }
  }
  NSData* encoded = [NSJSONSerialization dataWithJSONObject:batch options:NSJSONWritingSortedKeys | NSJSONWritingWithoutEscapingSlashes error:nil];
  return encoded && encoded.length <= (native ? 16u * 1024 : 64u * 1024);
}
NSData* Encode(NSDictionary* record) {
  if (![NSJSONSerialization isValidJSONObject:record]) return nil;
  NSData* raw = [NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingSortedKeys | NSJSONWritingWithoutEscapingSlashes error:nil];
  if (!raw || raw.length == 0 || raw.length > 65536) return nil;
  NSMutableData* frame = [raw mutableCopy]; [frame appendBytes:"\n" length:1]; return frame;
}
}

@interface BSTablePending : NSObject
@property(nonatomic) NSDictionary* request;
@property(nonatomic) NSData* bytes;
@property(nonatomic, copy) void (^completion)(NSDictionary*);
@property(nonatomic) double deadline;
@property(nonatomic) BOOL sent, delivered, startedWriting;
@property(nonatomic) NSDictionary* approvalGuard;
@end
@implementation BSTablePending
@end
namespace {
NSDictionary* Decode(NSData* bytes, BSTablePending* pending, NSString* run, uint64_t generation, uint64_t ceiling) {
  NSDictionary* reply = [NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil];
  uint64_t got = 0;
  if (!Keys(reply, @[@"version", @"op", @"run_id", @"stop_generation"],
      @[@"id", @"active_powers", @"staging_id", @"review", @"publication_guard", @"approval_id", @"commit_id", @"health", @"state", @"commit_ids", @"batch", @"code"]) ||
      !UInt(reply[@"version"]) || [reply[@"version"] unsignedLongLongValue] != 1 || ![reply[@"run_id"] isEqual:run] ||
      !UInt(reply[@"stop_generation"], &got) || got > ceiling) return nil;
  NSString* request = pending.request[@"op"];
  NSString* op = reply[@"op"];
  BOOL initial = [request isEqual:@"initialize"];
  if (!initial && (!UInt(reply[@"id"], nullptr, UINT64_MAX, YES) || ![reply[@"id"] isEqual:pending.request[@"id"]])) return nil;
  NSDictionary* bootstrap = @{@"initialize": @"initialized", @"ping": @"pong", @"stop_all": @"stopped", @"shutdown": @"shutdown"};
  if (bootstrap[request]) {
    if (![op isEqual:bootstrap[request]] || !Keys(reply, initial ? @[@"version", @"op", @"run_id", @"stop_generation", @"active_powers"] : @[@"version", @"op", @"run_id", @"id", @"stop_generation", @"active_powers"]) ||
        ![reply[@"active_powers"] isEqual:@[]] || (initial && got != 0) ||
        ([request isEqual:@"stop_all"] && (generation == UINT64_MAX || got != generation + 1))) return nil;
    NSString* idField = initial ? @"" : [NSString stringWithFormat:@",\"id\":%llu", [pending.request[@"id"] unsignedLongLongValue]];
    NSData* canonical = [[NSString stringWithFormat:@"{\"version\":1,\"op\":\"%@\",\"run_id\":\"%@\"%@,\"stop_generation\":%llu,\"active_powers\":[]}", op, run, idField, got] dataUsingEncoding:NSUTF8StringEncoding];
    return [bytes isEqual:canonical] ? reply : nil;
  }
  NSArray* extras = nil;
  if ([op isEqual:@"table_error"]) {
    extras = @[@"code"];
    if (![@[@"table_rejected", @"not_ready", @"stopped", @"publication_unavailable"] containsObject:reply[@"code"]]) return nil;
  } else {
    NSDictionary* operations = @{@"table_scope": @"table_scoped", @"table_stage": @"table_staged", @"table_revise": @"table_revised", @"table_review": @"table_reviewed", @"table_approve": @"table_approved", @"table_commit": @"table_committed", @"table_status": @"table_status", @"table_list": @"table_listed", @"table_read": @"table_read", @"table_delete": @"table_deleted", @"table_close": @"table_closed"};
    if (![op isEqual:operations[request]]) return nil;
    if ([op isEqual:@"table_scoped"] || [op isEqual:@"table_closed"]) extras = @[];
    else if ([op isEqual:@"table_staged"] || [op isEqual:@"table_revised"]) { extras = @[@"staging_id"]; if (!Identity(reply[@"staging_id"]) || ([op isEqual:@"table_revised"] && ![reply[@"staging_id"] isEqual:pending.request[@"staging_id"]])) return nil; }
    else if ([op isEqual:@"table_reviewed"]) { extras = @[@"review", @"publication_guard"]; if (!Review(reply[@"review"]) || !Guard(reply[@"publication_guard"]) || ![reply[@"review"][@"staging_id"] isEqual:pending.request[@"staging_id"]]) return nil; }
    else if ([op isEqual:@"table_approved"]) { extras = @[@"approval_id"]; if (!Identity(reply[@"approval_id"])) return nil; }
    else if ([op isEqual:@"table_committed"] || [op isEqual:@"table_deleted"]) { extras = @[@"commit_id"]; if (!Identity(reply[@"commit_id"]) || ![reply[@"commit_id"] isEqual:pending.request[[op isEqual:@"table_deleted"] ? @"commit_id" : @"approval_id"]]) return nil; }
    else if ([op isEqual:@"table_read"]) { extras = @[@"batch", @"publication_guard"]; if (!Batch(reply[@"batch"], NO) || !Guard(reply[@"publication_guard"])) return nil; }
    else if ([op isEqual:@"table_listed"]) {
      extras = @[@"commit_ids", @"publication_guard"];
      if (![reply[@"commit_ids"] isKindOfClass:NSArray.class] || [reply[@"commit_ids"] count] > 4 || !Guard(reply[@"publication_guard"])) return nil;
      NSMutableSet* seen = [NSMutableSet set];
      for (id token in reply[@"commit_ids"]) { if (!Identity(token) || [seen containsObject:token]) return nil; [seen addObject:token]; }
    } else if ([op isEqual:@"table_status"]) {
      extras = @[@"health", @"state"];
      if (![@[@"opening", @"ready", @"restriction_unknown", @"failed", @"closing", @"closed"] containsObject:reply[@"health"]] ||
          (reply[@"state"] != NSNull.null && ![@[@"preparing", @"admission_pending", @"admitted", @"writing", @"committed", @"rejected", @"purging", @"deleted", @"unknown"] containsObject:reply[@"state"]])) return nil;
    }
  }
  if (!extras || !Keys(reply, [@[@"version", @"op", @"run_id", @"id", @"stop_generation"] arrayByAddingObjectsFromArray:extras])) return nil;
  NSData* canonical = Encode(reply);
  return canonical.length == bytes.length + 1 && memcmp(canonical.bytes, bytes.bytes, bytes.length) == 0 ? reply : nil;
}
}

@implementation BSTableConnection {
  NSURL* _executableURL;
  NSURL* _databaseURL;
  NSURL* _clockProbeURL;
  NSString* _origin;
  NSLock* _lock;
  dispatch_queue_t _worker;
  dispatch_group_t _finished;
  BSTablePending* _ordinary;
  BSTablePending* _urgent;
  BOOL _started, _ready, _connected, _invalid, _notified;
  uint64_t _nextId, _generation;
  pid_t _pid;
  void (^_disconnect)(void);
}
- (instancetype)initWithExecutableURL:(NSURL*)url databaseURL:(NSURL*)database
    clockProbeURL:(NSURL*)clock ownedOrigin:(NSString*)origin {
  self = [super init];
  if (self) {
    _executableURL = [url copy]; _databaseURL = [database copy]; _clockProbeURL = [clock copy]; _origin = [origin copy];
    _runId = NSUUID.UUID.UUIDString; _pid = -1; _lock = [NSLock new];
    _worker = dispatch_queue_create("dev.bowshock.table-io", DISPATCH_QUEUE_SERIAL); _finished = dispatch_group_create();
  }
  return self;
}
- (BOOL)connected { [_lock lock]; BOOL value = _connected; [_lock unlock]; return value; }
- (pid_t)childPid { [_lock lock]; pid_t value = _pid; [_lock unlock]; return value; }
- (uint64_t)stopGeneration { [_lock lock]; uint64_t value = _generation; [_lock unlock]; return value; }
- (void)setDisconnectHandler:(void (^)(void))handler { [_lock lock]; _disconnect = [handler copy]; [_lock unlock]; }
- (void (^)(void))disconnectHandler { [_lock lock]; void (^value)(void) = _disconnect; [_lock unlock]; return value; }
+ (BOOL)publicationGuardIsCurrent:(NSDictionary*)guard { return CurrentGuard(guard); }
- (NSDictionary*)withheld:(BSTablePending*)pending reason:(NSString*)reason reply:(NSDictionary*)reply {
  NSMutableDictionary* result = [@{@"op": @"native_table_withheld", @"request_op": pending.request[@"op"], @"reason": reason,
      @"run_id": _runId, @"stop_generation": @(self.stopGeneration), @"effect_disposition": pending.startedWriting ? @"unknown" : @"not_submitted"} mutableCopy];
  if (pending.request[@"id"]) result[@"id"] = pending.request[@"id"];
  id correlation = reply[@"commit_id"] ?: reply[@"approval_id"] ?: reply[@"staging_id"] ?: pending.request[@"commit_id"] ?: pending.request[@"approval_id"] ?: pending.request[@"staging_id"];
  if (correlation && correlation != NSNull.null) result[@"correlation_id"] = correlation;
  return result;
}
- (void)admit:(NSString*)op fields:(NSDictionary*)fields valid:(BOOL)valid completion:(void (^)(NSDictionary*))completion {
  [self admit:op fields:fields valid:valid guard:nil completion:completion];
}
- (void)admit:(NSString*)op fields:(NSDictionary*)fields valid:(BOOL)valid guard:(NSDictionary*)guard completion:(void (^)(NSDictionary*))completion {
  BOOL urgent = [op isEqual:@"stop_all"], initial = [op isEqual:@"initialize"];
  BSTablePending* pending = [BSTablePending new];
  NSMutableDictionary* record = [fields mutableCopy]; record[@"op"] = op; record[@"version"] = @1;
  [_lock lock];
  NSString* refusal = !valid ? @"invalid_request" : (_invalid || (!initial && !_ready)) ? @"disconnected" :
      (initial ? _started : (urgent ? _urgent != nil : _ordinary != nil)) ? @"busy" : nil;
  if (!refusal && !initial && _nextId == UINT64_MAX) refusal = @"invalid_request";
  if (!refusal && !initial) record[@"id"] = @(++_nextId);
  pending.bytes = Encode(record);
  pending.request = pending.bytes ? [NSJSONSerialization JSONObjectWithData:pending.bytes options:0 error:nil] : [record copy];
  pending.completion = completion;
  NSData* guardBytes = guard ? Encode(guard) : nil;
  if (guardBytes) pending.approvalGuard = [NSJSONSerialization JSONObjectWithData:guardBytes options:0 error:nil];
  if (!refusal && !pending.bytes) refusal = @"invalid_request";
  if (refusal) { [_lock unlock]; completion([self withheld:pending reason:refusal reply:nil]); return; }
  pending.deadline = Now() + ([op isEqual:@"table_close"] ? 4 : 2);
  if (urgent) _urgent = pending; else _ordinary = pending;
  if (initial) { _started = YES; dispatch_group_enter(_finished); }
  [_lock unlock];
  if (initial) {
#if defined(BS_TABLE_CONNECTION_TEST)
    if (self.pauseAtStartForTesting) raise(SIGSTOP);
#endif
    dispatch_async(_worker, ^{ [self pump]; dispatch_group_leave(self->_finished); });
  }
}
- (void)startWithCompletion:(void (^)(NSDictionary*))completion {
  BOOL paths = _executableURL.isFileURL && _databaseURL.isFileURL && _clockProbeURL.isFileURL &&
      _executableURL.path.isAbsolutePath && _databaseURL.path.isAbsolutePath && _clockProbeURL.path.isAbsolutePath && Identity(_origin);
  [self admit:@"initialize" fields:@{@"run_id": _runId} valid:paths completion:completion];
}
- (void)scopeOrigin:(NSString*)origin completion:(void (^)(NSDictionary*))completion { [self admit:@"table_scope" fields:@{@"origin": origin ?: @""} valid:[origin isEqual:_origin] completion:completion]; }
- (void)stageBatch:(NSDictionary*)batch completion:(void (^)(NSDictionary*))completion { [self admit:@"table_stage" fields:@{@"batch": batch ?: @{}} valid:Batch(batch, YES) completion:completion]; }
- (void)reviseStaging:(NSString*)stage batch:(NSDictionary*)batch completion:(void (^)(NSDictionary*))completion { [self admit:@"table_revise" fields:@{@"staging_id": stage ?: @"", @"batch": batch ?: @{}} valid:Identity(stage) && Batch(batch, YES) completion:completion]; }
- (void)reviewStaging:(NSString*)stage retentionMs:(uint64_t)ttl completion:(void (^)(NSDictionary*))completion { [self admit:@"table_review" fields:@{@"staging_id": stage ?: @"", @"retention_ms": @(ttl)} valid:Identity(stage) && ttl > 0 && ttl <= 86400000 completion:completion]; }
- (void)approveReview:(NSDictionary*)review publicationGuard:(NSDictionary*)guard completion:(void (^)(NSDictionary*))completion { [self admit:@"table_approve" fields:@{@"review": review ?: @{}} valid:Review(review) && CurrentGuard(guard) guard:guard completion:completion]; }
- (void)commitApproval:(NSString*)approval completion:(void (^)(NSDictionary*))completion { [self admit:@"table_commit" fields:@{@"approval_id": approval ?: @""} valid:Identity(approval) completion:completion]; }
- (void)statusCommit:(NSString*)commit completion:(void (^)(NSDictionary*))completion { [self admit:@"table_status" fields:@{@"commit_id": commit ?: NSNull.null} valid:!commit || Identity(commit) completion:completion]; }
- (void)listWithCompletion:(void (^)(NSDictionary*))completion { [self admit:@"table_list" fields:@{} valid:YES completion:completion]; }
- (void)readCommit:(NSString*)commit completion:(void (^)(NSDictionary*))completion { [self admit:@"table_read" fields:@{@"commit_id": commit ?: @""} valid:Identity(commit) completion:completion]; }
- (void)deleteCommit:(NSString*)commit completion:(void (^)(NSDictionary*))completion { [self admit:@"table_delete" fields:@{@"commit_id": commit ?: @""} valid:Identity(commit) completion:completion]; }
- (void)closeWithCompletion:(void (^)(NSDictionary*))completion { [self admit:@"table_close" fields:@{} valid:YES completion:completion]; }
- (void)pingWithCompletion:(void (^)(NSDictionary*))completion { [self admit:@"ping" fields:@{} valid:YES completion:completion]; }
- (void)stopAllWithCompletion:(void (^)(NSDictionary*))completion { [self admit:@"stop_all" fields:@{} valid:YES completion:completion]; }
- (void)shutdownWithCompletion:(void (^)(NSDictionary*))completion { [self admit:@"shutdown" fields:@{} valid:YES completion:completion]; }
- (void)invalidate { [_lock lock]; _invalid = YES; _connected = NO; [_lock unlock]; }
- (void)waitForTermination { [self invalidate]; dispatch_group_wait(_finished, DISPATCH_TIME_FOREVER); }
- (BOOL)deliver:(BSTablePending*)pending reply:(NSDictionary*)reply {
  [_lock lock];
  if (_invalid) { [_lock unlock]; return NO; }
  pending.delivered = YES;
  if ([reply[@"op"] isEqual:@"initialized"]) { _ready = YES; _connected = YES; }
  if ([reply[@"op"] isEqual:@"stopped"]) _generation = [reply[@"stop_generation"] unsignedLongLongValue];
  [_lock unlock];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self->_lock lock];
    BOOL invalid = self->_invalid; uint64_t generation = self->_generation;
    if (self->_ordinary == pending) self->_ordinary = nil;
    if (self->_urgent == pending) self->_urgent = nil;
    [self->_lock unlock];
    // Release the queued slot at publication so the completion can chain one
    // next closed request; the worker cannot enqueue unbounded completed slots.
    NSDictionary* result = reply;
    BOOL lifecycle = [@[@"stopped", @"table_closed", @"shutdown"] containsObject:reply[@"op"]];
    if (invalid && !lifecycle) result = [self withheld:pending reason:@"disconnected" reply:reply];
    else if (!lifecycle && [reply[@"stop_generation"] unsignedLongLongValue] != generation)
      result = [self withheld:pending reason:@"stopped" reply:reply];
    else if (reply[@"publication_guard"] && !CurrentGuard(reply[@"publication_guard"]))
      result = [self withheld:pending reason:@"stale_guard" reply:reply];
    pending.completion(result);
  });
  return YES;
}
- (void)disconnect {
  [_lock lock]; _invalid = YES; _connected = NO;
  BSTablePending* ordinary = _ordinary; BSTablePending* urgent = _urgent;
  void (^handler)(void) = _disconnect; if (_notified) handler = nil; _notified = YES;
  [_lock unlock];
  for (BSTablePending* pending in @[ordinary ?: NSNull.null, urgent ?: NSNull.null]) {
    if ((id)pending != NSNull.null && !pending.delivered) {
      [_lock lock]; pending.delivered = YES; [_lock unlock];
      dispatch_async(dispatch_get_main_queue(), ^{
        [self->_lock lock];
        if (self->_ordinary == pending) self->_ordinary = nil;
        if (self->_urgent == pending) self->_urgent = nil;
        [self->_lock unlock]; pending.completion([self withheld:pending reason:@"disconnected" reply:nil]);
      });
    }
  }
  if (handler) dispatch_async(dispatch_get_main_queue(), handler);
}
- (void)pump {
  [_lock lock]; BOOL expiredStart = _invalid || (_ordinary && Now() >= _ordinary.deadline); [_lock unlock];
  if (expiredStart) { [self disconnect]; return; }
  int input = -1, output = -1; pid_t pid = -1;
  if (!Launch(_executableURL.path, _databaseURL.path, _clockProbeURL.path, _origin, input, output, pid)) { [self disconnect]; return; }
  [_lock lock]; _pid = pid; [_lock unlock];
  BSTablePending* writing = nil; NSUInteger offset = 0;
  NSMutableData* frame = [NSMutableData dataWithCapacity:65536];
  BOOL failed = NO, shutdown = NO;
  while (!failed && !shutdown) {
    @autoreleasepool {
      [_lock lock]; BOOL invalid = _invalid; BSTablePending* ordinary = _ordinary; BSTablePending* urgent = _urgent;
      uint64_t generation = _generation;
      [_lock unlock];
      if (invalid) break;
      for (BSTablePending* pending in @[ordinary ?: NSNull.null, urgent ?: NSNull.null])
        if ((id)pending != NSNull.null && !pending.delivered && Now() >= pending.deadline) failed = YES;
      if (failed) break;
      if (!writing) {
        BOOL ordinaryReady = ordinary && !ordinary.sent && !ordinary.delivered;
        BOOL urgentReady = urgent && !urgent.sent && !urgent.delivered;
        if (ordinaryReady && urgentReady)
          writing = [ordinary.request[@"id"] unsignedLongLongValue] < [urgent.request[@"id"] unsignedLongLongValue] ? ordinary : urgent;
        else writing = ordinaryReady ? ordinary : urgentReady ? urgent : nil;
        offset = 0;
      }
      pollfd fds[] = {{output, POLLIN, 0}, {writing ? input : -1, POLLOUT, 0}};
      int polled = poll(fds, 2, 20); int pollError = errno;
      if (polled == -1 && pollError != EINTR) { failed = YES; break; }
      if (writing && (fds[1].revents & (POLLERR | POLLHUP | POLLNVAL))) { failed = YES; break; }
      if (writing && (fds[1].revents & POLLOUT)) {
        if (writing.approvalGuard && !CurrentGuard(writing.approvalGuard)) {
          if (offset != 0) { failed = YES; break; }
          if (![self deliver:writing reply:[self withheld:writing reason:@"stale_guard" reply:nil]]) { failed = YES; break; }
          writing = nil; continue;
        }
        ssize_t count = write(input, static_cast<const char*>(writing.bytes.bytes) + offset, writing.bytes.length - offset);
        if (count > 0) { offset += count; [_lock lock]; writing.startedWriting = YES; [_lock unlock]; }
        else if (count == 0 || (errno != EAGAIN && errno != EINTR)) { failed = YES; break; }
        if (offset == writing.bytes.length) { [_lock lock]; writing.sent = YES; [_lock unlock]; writing = nil; offset = 0; }
      }
      if (fds[0].revents & (POLLIN | POLLHUP | POLLERR | POLLNVAL)) {
        unsigned char chunk[4096]; ssize_t count = read(output, chunk, sizeof(chunk));
        if (count <= 0) {
          if (count == 0 || (errno != EAGAIN && errno != EINTR)) failed = YES;
        } else for (ssize_t index = 0; index < count; ++index) {
          if (chunk[index] == '\n') {
            [_lock lock]; ordinary = _ordinary; urgent = _urgent; generation = _generation; [_lock unlock];
            BSTablePending* matched = nil; NSDictionary* reply = nil;
            uint64_t ceiling = generation + ((urgent && !urgent.delivered && generation != UINT64_MAX) ? 1 : 0);
            for (BSTablePending* pending in @[ordinary ?: NSNull.null, urgent ?: NSNull.null]) {
              if ((id)pending == NSNull.null || !pending.sent || pending.delivered) continue;
              NSDictionary* decoded = Decode(frame, pending, _runId, generation, ceiling);
              if (decoded) { if (matched) { failed = YES; break; } matched = pending; reply = decoded; }
            }
            if (failed || !matched || Now() >= matched.deadline) { failed = YES; break; }
            NSDictionary* published = reply;
            if (reply[@"publication_guard"] && !CurrentGuard(reply[@"publication_guard"]))
              published = [self withheld:matched reason:@"stale_guard" reply:reply];
            if (![self deliver:matched reply:published]) { failed = YES; break; }
            shutdown = [reply[@"op"] isEqual:@"shutdown"];
            [frame setLength:0];
            if (shutdown && index + 1 != count) { failed = YES; shutdown = NO; break; }
          } else {
            if (chunk[index] == '\r' || frame.length == 65536) { failed = YES; break; }
            [frame appendBytes:chunk + index length:1];
          }
        }
      }
      // Preserve ownership while any sent response can still have buffered bytes;
      // Rust writes payload/LF separately and healthy shutdown exits immediately.
      [_lock lock]; BOOL awaiting = (_ordinary && _ordinary.sent && !_ordinary.delivered) || (_urgent && _urgent.sent && !_urgent.delivered); [_lock unlock];
      if (!awaiting || shutdown) {
        pid_t done = waitpid(pid, nullptr, WNOHANG);
        if (done == pid || (done == -1 && errno == ECHILD)) { pid = -1; if (!shutdown) failed = YES; }
        else if (done == -1 && errno != EINTR) failed = YES;
      }
    }
  }
  [self disconnect]; Close(input); Close(output); TerminateAndReap(pid);
}
@end
