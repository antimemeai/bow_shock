#import "blackbird_connection.h"
#import "blackbird_packet.h"
#include <cerrno>
#include <fcntl.h>
#include <mach/mach_time.h>
#include <crt_externs.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <initializer_list>

namespace {
constexpr NSUInteger MaxPendingBytes = 8 * 1024 * 1024;
double Now() {
  static const mach_timebase_info_data_t scale = [] { mach_timebase_info_data_t s; mach_timebase_info(&s); return s; }();
  return static_cast<double>(mach_continuous_time()) * scale.numer / scale.denom / 1e9;
}
void Close(int& fd) { if (fd >= 0) { close(fd); fd = -1; } }
bool AboveStdio(int& fd) {
  if (fd >= 3) return true;
  int next = fcntl(fd, F_DUPFD_CLOEXEC, 3); if (next < 0) return false; Close(fd); fd = next; return true;
}
bool Pipe(int (&fds)[2]) {
  if (pipe(fds)) return false;
  return AboveStdio(fds[0]) && AboveStdio(fds[1]) &&
    fcntl(fds[0], F_SETFD, FD_CLOEXEC) != -1 && fcntl(fds[1], F_SETFD, FD_CLOEXEC) != -1;
}
bool Launch(NSURL* executable, NSURL* directory, int& input, int& output, pid_t& pid) {
  int toChild[2] = {-1, -1}, fromChild[2] = {-1, -1}, diagnostics = -1;
  bool result = false, actionsReady = false, attributesReady = false;
  posix_spawn_file_actions_t actions; posix_spawnattr_t attributes;
  do {
    if (!Pipe(toChild) || !Pipe(fromChild)) break;
    if (fcntl(toChild[1], F_SETFL, O_NONBLOCK) == -1 || fcntl(fromChild[0], F_SETFL, O_NONBLOCK) == -1 ||
        fcntl(toChild[1], F_SETNOSIGPIPE, 1) == -1) break;
    diagnostics = fcntl(STDERR_FILENO, F_DUPFD_CLOEXEC, 3);
    if (diagnostics < 0 && errno == EBADF) diagnostics = open("/dev/null", O_WRONLY | O_CLOEXEC);
    if (diagnostics < 0 || !AboveStdio(diagnostics)) break;
    if (posix_spawn_file_actions_init(&actions)) break; actionsReady = true;
    if (posix_spawnattr_init(&attributes)) break; attributesReady = true;
    if (posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT)) break;
    // The _np spelling supports the same operation on pre-macOS-26 targets.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    const int chdirResult = posix_spawn_file_actions_addchdir_np(&actions, directory.fileSystemRepresentation);
#pragma clang diagnostic pop
    if (chdirResult ||
        posix_spawn_file_actions_adddup2(&actions, toChild[0], STDIN_FILENO) ||
        posix_spawn_file_actions_adddup2(&actions, fromChild[1], STDOUT_FILENO) ||
        posix_spawn_file_actions_adddup2(&actions, diagnostics, STDERR_FILENO)) break;
    bool closed = true;
    for (int fd : {toChild[0], toChild[1], fromChild[0], fromChild[1], diagnostics})
      if (posix_spawn_file_actions_addclose(&actions, fd)) closed = false;
    if (!closed) break;
    const char* path = executable.fileSystemRepresentation;
    char application[] = "--application";
    char* arguments[] = {const_cast<char*>(path), application, nullptr};
    if (posix_spawn(&pid, path, &actions, &attributes, arguments, *_NSGetEnviron())) break;
    input = toChild[1]; toChild[1] = -1; output = fromChild[0]; fromChild[0] = -1; result = true;
  } while (false);
  if (actionsReady) posix_spawn_file_actions_destroy(&actions);
  if (attributesReady) posix_spawnattr_destroy(&attributes);
  for (int& fd : toChild) Close(fd); for (int& fd : fromChild) Close(fd); Close(diagnostics);
  return result;
}
void Reap(pid_t& pid) {
  if (pid <= 0) return;
  double deadline = Now() + .25; bool signalled = false, killed = false;
  for (;;) {
    pid_t result = waitpid(pid, nullptr, WNOHANG);
    if (result == pid || (result < 0 && errno == ECHILD)) { pid = -1; return; }
    if (!signalled) { kill(pid, SIGTERM); signalled = true; }
    if (!killed && Now() >= deadline) { kill(pid, SIGKILL); killed = true; }
    poll(nullptr, 0, 10);
  }
}
NSData* Frame(NSDictionary* value) {
  NSData* packet = BSBlackbirdEncodePacket(value, nullptr); if (!packet) return nil;
  uint32_t n = static_cast<uint32_t>(packet.length);
  const uint8_t prefix[] = {static_cast<uint8_t>(n >> 24), static_cast<uint8_t>(n >> 16), static_cast<uint8_t>(n >> 8), static_cast<uint8_t>(n)};
  NSMutableData* frame = [NSMutableData dataWithBytes:prefix length:4]; [frame appendData:packet]; return [frame copy];
}
bool Text(id value) { return [value isKindOfClass:NSString.class]; }
}

@implementation BSBlackbirdConnection {
  NSURL* _executableURL; NSURL* _sessionURL; NSURL* _directoryURL; NSString* _model;
  NSLock* _lock; dispatch_queue_t _worker;
  NSMutableArray<NSData*>* _outgoing; NSUInteger _pendingBytes;
  NSMutableArray* _closeCompletions;
  NSMutableArray<NSDictionary*>* _events; NSUInteger _eventBytes; BOOL _deliveryScheduled, _eventOverflow;
  void (^_handler)(NSDictionary*);
  NSString* _openID; NSString* _activeID; NSString* _steeringFromID;
  BOOL _started, _ready, _running, _closing, _finished, _cancelQueued;
  double _closeDeadline;
}
- (instancetype)initWithExecutableURL:(NSURL*)executableURL sessionURL:(NSURL*)sessionURL
                 workingDirectoryURL:(NSURL*)workingDirectoryURL model:(NSString*)model {
  self = [super init];
  if (self) {
    _executableURL = [executableURL copy]; _sessionURL = [sessionURL copy]; _directoryURL = [workingDirectoryURL copy]; _model = [model copy];
    _lock = [NSLock new]; _worker = dispatch_queue_create("dev.oxcart.blackbird-io", DISPATCH_QUEUE_SERIAL);
    _outgoing = [NSMutableArray array]; _closeCompletions = [NSMutableArray array]; _events = [NSMutableArray array];
  }
  return self;
}
- (BOOL)isReady { [_lock lock]; BOOL value = _ready; [_lock unlock]; return value; }
- (BOOL)isRunning { [_lock lock]; BOOL value = _running && _activeID != nil; [_lock unlock]; return value; }
- (NSString*)activeRequestID { [_lock lock]; NSString* value = [_activeID copy]; [_lock unlock]; return value; }
- (void)setEventHandler:(void (^)(NSDictionary*))handler { [_lock lock]; _handler = [handler copy]; [_lock unlock]; }
- (void (^)(NSDictionary*))eventHandler { [_lock lock]; id handler = _handler; [_lock unlock]; return handler; }
- (BOOL)emit:(NSDictionary*)event {
  // One main-queue drain owns a bounded batch. A second bounded batch may be
  // produced while callbacks run; a slow UI never creates unbounded blocks.
  NSData* packet = BSBlackbirdEncodePacket(event, nullptr);
  NSUInteger bytes = packet.length;
  [_lock lock];
  if (!packet || _eventOverflow || _events.count >= 256 || bytes > MaxPendingBytes || _eventBytes > MaxPendingBytes - bytes) {
    _eventOverflow = YES; [_lock unlock]; return NO;
  }
  [_events addObject:event]; _eventBytes += bytes;
  BOOL schedule = !_deliveryScheduled; _deliveryScheduled = YES;
  [_lock unlock];
  if (schedule) dispatch_async(dispatch_get_main_queue(), ^{ [self deliverEvents]; });
  return YES;
}
- (void)deliverEvents {
  [_lock lock];
  NSArray<NSDictionary*>* events = [_events copy]; [_events removeAllObjects]; _eventBytes = 0; _deliveryScheduled = NO;
  void (^handler)(NSDictionary*) = _handler; [_lock unlock];
  if (handler) for (NSDictionary* event in events) handler(event);
}
- (void)start {
  [_lock lock];
  if (_started || _finished) { [_lock unlock]; return; }
  _started = YES; _running = YES; _openID = NSUUID.UUID.UUIDString;
  NSData* open = Frame(@{@"type": @"open", @"id": _openID, @"session": _sessionURL.path,
                         @"model": _model, @"effort": @"high"});
  if (open) { [_outgoing addObject:open]; _pendingBytes += open.length; }
  [_lock unlock];
  dispatch_async(_worker, ^{ @autoreleasepool { [self pump]; } });
}
- (NSString*)sendObjective:(NSString*)objective observations:(NSArray<NSDictionary*>*)observations steer:(BOOL)steer {
  NSString* requestID = NSUUID.UUID.UUIDString;
  NSData* frame = Frame(@{@"type": steer ? @"steer" : @"turn", @"id": requestID,
                          @"objective": objective, @"observations": observations});
  if (!frame) return nil;
  [_lock lock];
  if (!_ready || !_running || _closing || (_activeID && (!steer || _steeringFromID)) || frame.length > MaxPendingBytes || _pendingBytes > MaxPendingBytes - frame.length) {
    [_lock unlock]; return nil;
  }
  [_outgoing addObject:frame]; _pendingBytes += frame.length;
  _steeringFromID = steer ? _activeID : nil; _activeID = requestID; _cancelQueued = NO;
  [_lock unlock]; return requestID;
}
- (void)cancel {
  [_lock lock];
  if (!_activeID || !_running || _closing || _cancelQueued) { [_lock unlock]; return; }
  NSData* frame = Frame(@{@"type": @"cancel", @"id": _activeID});
  // Ordinary requests leave control capacity outside the data-queue limit.
  [_outgoing addObject:frame]; _pendingBytes += frame.length; _cancelQueued = YES;
  [_lock unlock];
}
- (void)closeWithCompletion:(void (^)(void))completion {
  [_lock lock];
  if (_finished || !_started) {
    _finished = YES; [_lock unlock]; if (completion) dispatch_async(dispatch_get_main_queue(), completion); return;
  }
  if (completion) [_closeCompletions addObject:[completion copy]];
  if (!_closing) {
    _closing = YES; _ready = NO; _closeDeadline = Now() + 2;
    NSData* frame = Frame(@{@"type": @"close", @"id": NSUUID.UUID.UUIDString});
    [_outgoing addObject:frame]; _pendingBytes += frame.length;
  }
  [_lock unlock];
}
- (BOOL)receiveEvent:(NSDictionary*)event error:(NSString**)error {
  NSString* type = event[@"type"];
  if (!Text(type) || !Text(event[@"id"])) { *error = @"Blackbird emitted an event without type/id"; return NO; }
  if ([type isEqual:@"ready"]) {
    if (![event[@"id"] isEqual:_openID] || ![event[@"protocol"] isKindOfClass:NSNumber.class] ||
        [event[@"protocol"] unsignedLongLongValue] != 1 || !Text(event[@"model"]) || !Text(event[@"session"])) {
      *error = @"Blackbird emitted an invalid ready event"; return NO;
    }
    [_lock lock]; if (!_closing) _ready = YES; [_lock unlock];
  } else if ([type isEqual:@"text"]) {
    if (!Text(event[@"text"])) { *error = @"Blackbird emitted invalid text"; return NO; }
  } else if ([type isEqual:@"final"]) {
    if (!Text(event[@"text"]) || ![@[@"completed", @"cancelled", @"failed"] containsObject:event[@"outcome"]]) {
      *error = @"Blackbird emitted an invalid final event"; return NO;
    }
    [_lock lock];
    if ([event[@"id"] isEqual:_steeringFromID]) _steeringFromID = nil;
    if ([event[@"id"] isEqual:_activeID]) { _activeID = nil; _cancelQueued = NO; }
    [_lock unlock];
  } else if ([type isEqual:@"closed"]) {
    if (![self emit:event]) *error = @"Blackbird output exceeded the UI event queue limit";
    return NO;
  } else if ([type isEqual:@"error"]) {
    if (!Text(event[@"message"])) { *error = @"Blackbird emitted an invalid error event"; return NO; }
    [_lock lock];
    if ([event[@"id"] isEqual:_activeID] && ![event[@"final_follows"] boolValue]) {
      _activeID = _steeringFromID; _steeringFromID = nil; _cancelQueued = NO;
    }
    [_lock unlock];
  } else if (![type isEqual:@"status"]) {
    *error = @"Blackbird emitted an unknown event type"; return NO;
  }
  if (![self emit:event]) { *error = @"Blackbird output exceeded the UI event queue limit"; return NO; }
  return YES;
}
- (void)pump {
  int input = -1, output = -1; pid_t pid = -1;
  NSString* failure = nil; BOOL sawClosed = NO;
  NSMutableData* received = [NSMutableData data]; NSData* sending = nil; NSUInteger written = 0;
  const double readyDeadline = Now() + 20;
  if (!Launch(_executableURL, _directoryURL, input, output, pid)) failure = @"Could not launch Blackbird --application";
  while (!failure && !sawClosed) {
    @autoreleasepool {
      [_lock lock];
      BOOL closing = _closing, ready = _ready; double closeDeadline = _closeDeadline;
      if (!sending && _outgoing.count) { sending = _outgoing.firstObject; [_outgoing removeObjectAtIndex:0]; written = 0; }
      [_lock unlock];
      if (closing && Now() >= closeDeadline) break;
      if (!closing && !ready && Now() >= readyDeadline) { failure = @"Blackbird did not become ready"; break; }
      struct pollfd fds[] = {{output, POLLIN, 0}, {input, static_cast<short>(sending ? POLLOUT : 0), 0}};
      int polled = poll(fds, 2, 20);
      if (polled < 0) { if (errno == EINTR) continue; failure = @"Blackbird pipe poll failed"; break; }
      if (sending && (fds[1].revents & POLLOUT)) {
        ssize_t count = write(input, static_cast<const uint8_t*>(sending.bytes) + written, sending.length - written);
        if (count > 0) {
          written += count;
          if (written == sending.length) {
            [_lock lock]; _pendingBytes -= sending.length; [_lock unlock]; sending = nil;
          }
        } else if (count < 0 && errno != EAGAIN && errno != EINTR) failure = @"Blackbird input pipe failed";
      }
      if (fds[0].revents & (POLLIN | POLLHUP | POLLERR | POLLNVAL)) {
        uint8_t bytes[16384]; ssize_t count = read(output, bytes, sizeof(bytes));
        if (count > 0) {
          [received appendBytes:bytes length:count];
          while (received.length >= 4) {
            const uint8_t* data = static_cast<const uint8_t*>(received.bytes);
            uint32_t length = (uint32_t(data[0]) << 24) | (uint32_t(data[1]) << 16) | (uint32_t(data[2]) << 8) | data[3];
            if (length < 5 || length > BSBlackbirdMaximumPacketBytes) { failure = @"Blackbird emitted an invalid frame length"; break; }
            if (received.length < static_cast<NSUInteger>(length) + 4) break;
            NSError* error = nil;
            id event = BSBlackbirdDecodePacket([received subdataWithRange:NSMakeRange(4, length)], &error);
            [received replaceBytesInRange:NSMakeRange(0, static_cast<NSUInteger>(length) + 4) withBytes:nullptr length:0];
            if (![event isKindOfClass:NSDictionary.class]) { failure = error.localizedDescription ?: @"Blackbird event was not a map"; break; }
            if (![self receiveEvent:event error:&failure]) { sawClosed = !failure; break; }
          }
        } else if (count == 0) {
          failure = received.length ? @"Blackbird closed stdout inside a frame" : @"Blackbird disconnected before closed";
        } else if (errno != EAGAIN && errno != EINTR) failure = @"Blackbird output pipe failed";
      }
      if (!failure && !sawClosed && (fds[1].revents & (POLLERR | POLLHUP | POLLNVAL))) failure = @"Blackbird closed its input pipe";
    }
  }
  Close(input); Close(output); Reap(pid);
  [_lock lock];
  _ready = NO; _running = NO; _finished = YES; _activeID = nil; [_outgoing removeAllObjects]; _pendingBytes = 0;
  NSArray* completions = [_closeCompletions copy]; [_closeCompletions removeAllObjects];
  BOOL requestedClose = _closing;
  if (_eventOverflow) {
    // Explicit terminal error replaces undelivered output after overflow.
    [_events removeAllObjects]; _eventBytes = 0; _eventOverflow = NO;
    failure = @"Blackbird output exceeded the UI event queue limit; undelivered output was discarded";
  }
  [_lock unlock];
  if (failure) [self emit:@{@"type": @"error", @"id": @"", @"message": failure, @"fatal": @YES}];
  if (!sawClosed) [self emit:@{@"type": @"closed", @"id": @"", @"reason": requestedClose && !failure ? @"closed" : @"disconnected"}];
  for (void (^completion)(void) in completions) dispatch_async(dispatch_get_main_queue(), completion);
}
@end
