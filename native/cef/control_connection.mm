#import "control_connection.h"
#import "continuous_clock.h"
#include "protocol.h"
#include <cerrno>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <algorithm>
#include <limits>

namespace {
using namespace bs_control;
constexpr uint64_t kLaunchNs = 2000000000, kRequestNs = 100000000;
constexpr uint64_t kHeartbeatNs = 50000000, kLeaseNs = 250000000;
bool Time(uint64_t& now) {
  NSDictionary* sample = BSContinuousClockWitness();
  if (!sample) return false;
  now = [sample[@"continuous_ns"] unsignedLongLongValue]; return true;
}
bool Add(uint64_t now, uint64_t duration, uint64_t& result) {
  if (duration > std::numeric_limits<uint64_t>::max() - now) return false;
  result = now + duration; return true;
}
void Close(int& fd) { if (fd >= 0) { close(fd); fd = -1; } }
bool AboveStdio(int& fd) {
  if (fd >= 3) return true;
  int moved = fcntl(fd, F_DUPFD_CLOEXEC, 3);
  if (moved == -1) return false;
  Close(fd); fd = moved; return true;
}
bool Pipe(int (&fds)[2]) {
  return pipe(fds) == 0 && AboveStdio(fds[0]) && AboveStdio(fds[1]);
}
bool Configure(int fd, bool nonblocking) {
  int flags = fcntl(fd, F_GETFL);
  return flags != -1 && fcntl(fd, F_SETFD, FD_CLOEXEC) != -1 &&
      (!nonblocking || fcntl(fd, F_SETFL, flags | O_NONBLOCK) != -1);
}
bool Launch(NSString* path, int& input, int& output, pid_t& pid) {
  int toChild[2] = {-1, -1}, fromChild[2] = {-1, -1}, nullFd = -1;
  bool success = false, haveActions = false, haveAttributes = false;
  posix_spawn_file_actions_t actions;
  posix_spawnattr_t attributes;
  do {
    if (!Pipe(toChild) || !Pipe(fromChild)) break;
    if (!Configure(toChild[0], false) || !Configure(toChild[1], true) ||
        !Configure(fromChild[0], true) || !Configure(fromChild[1], false) ||
        fpathconf(toChild[1], _PC_PIPE_BUF) < static_cast<long>(kRecordBytes) ||
        fcntl(toChild[1], F_SETNOSIGPIPE, 1) == -1) break;
    nullFd = open("/dev/null", O_WRONLY | O_CLOEXEC);
    if (nullFd == -1 || !AboveStdio(nullFd) ||
        posix_spawn_file_actions_init(&actions) != 0) break;
    haveActions = true;
    if (posix_spawnattr_init(&attributes) != 0) break;
    haveAttributes = true;
    if (posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT) != 0 ||
        posix_spawn_file_actions_adddup2(&actions, toChild[0], 0) != 0 ||
        posix_spawn_file_actions_adddup2(&actions, fromChild[1], 1) != 0 ||
        posix_spawn_file_actions_adddup2(&actions, nullFd, 2) != 0) break;
    bool closed = true;
    for (int fd : {toChild[0], toChild[1], fromChild[0], fromChild[1], nullFd})
      if (posix_spawn_file_actions_addclose(&actions, fd) != 0) closed = false;
    if (!closed) break;
    const char* executable = path.fileSystemRepresentation;
    char* argv[] = {const_cast<char*>(executable), nullptr};
    char lang[] = "LANG=C"; char* environment[] = {lang, nullptr};
    if (posix_spawn(&pid, executable, &actions, &attributes, argv, environment) != 0) break;
    input = toChild[1]; toChild[1] = -1;
    output = fromChild[0]; fromChild[0] = -1; success = true;
  } while (false);
  if (haveAttributes) posix_spawnattr_destroy(&attributes);
  if (haveActions) posix_spawn_file_actions_destroy(&actions);
  for (int& fd : toChild) Close(fd);
  for (int& fd : fromChild) Close(fd);
  Close(nullFd); return success;
}
int ExitCode(int status) {
  return WIFEXITED(status) ? WEXITSTATUS(status) : (WIFSIGNALED(status) ? 128 + WTERMSIG(status) : -1);
}
void TerminateAndReap(pid_t& pid, int& code) {
  if (pid <= 0) return;
  int status = 0;
  pid_t result = waitpid(pid, &status, WNOHANG);
  if (result == pid) { code = ExitCode(status); pid = -1; return; }
  if (result == -1 && errno == ECHILD) { pid = -1; return; }
  kill(pid, SIGTERM);
  uint64_t now = 0, deadline = 0;
  bool killed = !Time(now) || !Add(now, 250000000, deadline);
  if (killed) kill(pid, SIGKILL);
  for (;;) {
    result = waitpid(pid, &status, WNOHANG);
    if (result == pid) { code = ExitCode(status); pid = -1; return; }
    if (result == -1 && errno == ECHILD) { pid = -1; return; }
    if (!killed && (!Time(now) || now >= deadline)) { kill(pid, SIGKILL); killed = true; }
    // Rare uninterruptible exit remains owned; no wait or signal runs on UI.
    poll(nullptr, 0, 10);
  }
}
bool RunId(NSString* value) {
  if (![value isKindOfClass:NSString.class] || value.length == 0 || value.length > 128) return false;
  for (NSUInteger i = 0; i < value.length; ++i) {
    unichar c = [value characterAtIndex:i];
    if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.')) return false;
  }
  return true;
}
Wire Request(const Record& record) {
  Wire wire = EncodeReply(record);
  wire[29] = 0; wire[30] = 0;
  WriteNumber(wire, 24, 4, record.lease_ms); return wire;
}
NSDictionary* Reply(const Record& record) {
  return @{@"run_id": [NSString stringWithUTF8String:record.run.c_str()],
      @"sequence": @(record.sequence), @"stop_generation": @(record.stop_generation),
      @"status": record.status == Status::Fenced ? @"fenced" : @"live",
      @"input_capability": @NO};
}
}

@interface BSControlConnection ()
- (void)pump;
- (void)disconnect;
- (void)fail:(NSString*)reason;
@end

@implementation BSControlConnection {
  NSURL* _executableURL;
  BOOL (^_authority)(void);
  dispatch_queue_t _worker;
  dispatch_group_t _finished;
  NSLock* _lock;
  BOOL _started, _ready, _invalid, _pendingFence, _fenceBusy, _notified;
  uint64_t _launchDeadline, _requestedGeneration, _generation, _pendingGeneration, _validUntil;
  pid_t _originalPid;
  NSString* _reason;
  NSInteger _exitCode;
  void (^_startCompletion)(NSDictionary*);
  void (^_fenceCompletion)(NSDictionary*);
  void (^_disconnect)(void);
}
- (instancetype)initWithExecutableURL:(NSURL*)url runId:(NSString*)runId
    authorityAliveProvider:(BOOL (^)(void))provider {
  self = [super init];
  if (self) {
    _lock = [[NSLock alloc] init]; _worker = dispatch_queue_create("dev.bowshock.control-link", DISPATCH_QUEUE_SERIAL);
    _finished = dispatch_group_create(); _executableURL = [url copy]; _runId = [runId copy];
    _authority = [provider copy]; _originalPid = -1; _exitCode = -1;
    uint64_t now;
    if (!RunId(runId) || !url.isFileURL || !url.path.isAbsolutePath || !provider)
      [self fail:@"invalid_configuration"];
    else if (!Time(now)) [self fail:@"clock_unavailable"];
    else if (!Add(now, kLaunchNs, _launchDeadline)) [self fail:@"clock_overflow"];
  }
  return self;
}
- (BOOL)connected { [_lock lock]; BOOL ready = _ready && !_invalid; [_lock unlock]; return ready; }
- (pid_t)childPid { [_lock lock]; pid_t pid = _originalPid; [_lock unlock]; return pid; }
- (uint64_t)acknowledgedGeneration { [_lock lock]; uint64_t value = _generation; [_lock unlock]; return value; }
- (NSString*)failureReason { [_lock lock]; NSString* reason = _reason ?: @"none"; [_lock unlock]; return reason; }
- (NSInteger)childExitCode { [_lock lock]; NSInteger code = _exitCode; [_lock unlock]; return code; }
- (void)setDisconnectHandler:(void (^)(void))handler {
  [_lock lock]; _disconnect = [handler copy]; [_lock unlock];
}
- (void (^)(void))disconnectHandler { [_lock lock]; auto handler = _disconnect; [_lock unlock]; return handler; }
- (void)deliver:(void (^)(NSDictionary*))completion reply:(NSDictionary*)reply releaseFence:(BOOL)releaseFence {
  if (!completion) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    uint64_t now = 0;
    BOOL clockAvailable = Time(now);
    [self->_lock lock];
    BOOL allowed = self->_ready && !self->_invalid && clockAvailable && now < self->_validUntil;
    if (reply && !allowed && !self->_reason) {
      self->_reason = !clockAvailable ? @"callback_clock_unavailable" :
          (now >= self->_validUntil ? @"callback_lease_deadline" : @"callback_not_connected");
      self->_invalid = YES; self->_ready = NO;
    }
    if (releaseFence) self->_fenceBusy = NO;
    [self->_lock unlock]; completion(allowed ? reply : nil);
  });
}
- (void)startWithCompletion:(void (^)(NSDictionary*))completion {
  [_lock lock];
  if (_started || _invalid) { [_lock unlock]; [self deliver:completion reply:nil releaseFence:NO]; return; }
  _started = YES; _startCompletion = [completion copy]; dispatch_group_enter(_finished);
  [_lock unlock];
  dispatch_async(_worker, ^{ [self pump]; dispatch_group_leave(self->_finished); });
}
- (void)fenceToGeneration:(uint64_t)generation completion:(void (^)(NSDictionary*))completion {
  [_lock lock];
  if (_invalid || !_ready || _fenceBusy || generation <= _requestedGeneration) {
    [_lock unlock]; [self deliver:completion reply:nil releaseFence:NO]; return;
  }
  _fenceBusy = YES; _pendingFence = YES; _pendingGeneration = generation;
  _requestedGeneration = generation; _fenceCompletion = [completion copy]; [_lock unlock];
}
- (void)fail:(NSString*)reason {
  [_lock lock]; if (!_reason) _reason = reason; _invalid = YES; _ready = NO; [_lock unlock];
}
- (void)invalidate { [self fail:@"invalidated"]; }
- (void)waitForTermination { [self invalidate]; dispatch_group_wait(_finished, DISPATCH_TIME_FOREVER); }
- (BOOL)check:(uint64_t&)now last:(uint64_t&)last {
  [_lock lock]; BOOL invalid = _invalid; [_lock unlock];
  if (invalid) return NO;
  if (!_authority()) { [self fail:@"authority_lost"]; return NO; }
  if (!Time(now)) { [self fail:@"clock_unavailable"]; return NO; }
  if (now < last) { [self fail:@"clock_backwards"]; return NO; }
  last = now; return YES;
}
- (void)disconnect {
  [_lock lock]; _invalid = YES; _ready = NO; _pendingFence = NO;
  auto start = _startCompletion; auto fence = _fenceCompletion;
  _startCompletion = nil; _fenceCompletion = nil;
  void (^handler)(void) = _disconnect;
  if (_notified) handler = nil;
  _notified = YES; [_lock unlock];
  [self deliver:start reply:nil releaseFence:NO]; [self deliver:fence reply:nil releaseFence:YES];
  if (handler) dispatch_async(dispatch_get_main_queue(), handler);
}
- (void)pump {
  int input = -1, output = -1; pid_t pid = -1;
  uint64_t now = 0, last = 0;
  if (![self check:now last:last]) { [self disconnect]; return; }
  if (now >= _launchDeadline) { [self fail:@"launch_deadline"]; [self disconnect]; return; }
  if (!Launch(_executableURL.path, input, output, pid)) { [self fail:@"launch_failed"]; [self disconnect]; return; }
  [_lock lock]; _originalPid = pid; [_lock unlock];
  uint64_t sequence = 0, generation = 0, requestDeadline = 0, leaseEnd = 0, nextHeartbeat = 0, sentAt = 0;
  BOOL initialized = NO, inFlight = NO, written = NO, fenced = NO;
  int exitCode = -1;
  Record current; Wire outgoing{}, expected{}, incoming{};
  std::size_t received = 0;
  for (;;) {
    @autoreleasepool {
      if (![self check:now last:last]) break;
      if (!initialized && now >= _launchDeadline) { [self fail:@"initialization_deadline"]; break; }
      if (initialized && now >= leaseEnd) { [self fail:@"lease_deadline"]; break; }
      if (inFlight && now >= requestDeadline) { [self fail:@"request_deadline"]; break; }
      if (!inFlight) {
        [_lock lock]; BOOL fence = _pendingFence; uint64_t target = _pendingGeneration;
        if (fence) _pendingFence = NO; [_lock unlock];
        if (!initialized || fence || now >= nextHeartbeat) {
          if (sequence == UINT64_MAX) { [self fail:@"sequence_exhausted"]; break; }
          current = Record{}; current.run = _runId.UTF8String; current.sequence = ++sequence;
          current.op = static_cast<uint8_t>(!initialized ? Op::Initialize : (fence ? Op::Stop : Op::Heartbeat));
          current.stop_generation = fence ? target : generation;
          current.lease_ms = fence ? 0 : 250;
          current.status = fence || fenced ? Status::Fenced : Status::Live;
          if (!Add(now, kRequestNs, requestDeadline)) { [self fail:@"clock_overflow"]; break; }
          // Initialization includes native runtime startup within constructor's
          // total launch budget. Ordinary requests use the shorter live budget.
          if (!initialized) requestDeadline = _launchDeadline;
          sentAt = now; outgoing = Request(current);
          Record ack = current; ack.op |= 128; ack.lease_ms = 0;
          expected = EncodeReply(ack); incoming = Wire{};
          received = 0; written = NO; inFlight = YES;
        }
      }
      pollfd fds[] = {{output, POLLIN, 0}, {inFlight && !written ? input : -1, POLLOUT, 0}};
      int result = poll(fds, 2, 10); int pollError = errno;
      if (![self check:now last:last]) break;
      if (!initialized && now >= _launchDeadline) { [self fail:@"initialization_deadline"]; break; }
      if (initialized && now >= leaseEnd) { [self fail:@"lease_deadline"]; break; }
      if (inFlight && now >= requestDeadline) { [self fail:@"request_deadline"]; break; }
      if (result == -1) { if (pollError == EINTR) continue; [self fail:@"poll_io"]; break; }
      if (fds[1].revents & (POLLERR | POLLHUP | POLLNVAL)) { [self fail:@"write_peer_closed"]; break; }
      if (fds[1].revents & POLLOUT) {
        if (![self check:now last:last]) break;
        if (now >= requestDeadline) { [self fail:initialized ? @"request_deadline" : @"initialization_deadline"]; break; }
        if (initialized && now >= leaseEnd) { [self fail:@"lease_deadline"]; break; }
        ssize_t bytes = write(input, outgoing.data(), outgoing.size());
        if (bytes == static_cast<ssize_t>(kRecordBytes)) written = YES;
        else if (bytes >= 0 || (errno != EINTR && errno != EAGAIN)) { [self fail:@"write_io"]; break; }
      }
      if (fds[0].revents & (POLLIN | POLLHUP | POLLERR | POLLNVAL)) {
        uint8_t buffer[kRecordBytes + 1];
        ssize_t bytes = read(output, buffer, inFlight ? kRecordBytes - received + 1 : sizeof(buffer));
        if (bytes == 0) { [self fail:@"reply_eof"]; break; }
        if (bytes < 0 && errno != EINTR && errno != EAGAIN) { [self fail:@"read_io"]; break; }
        if (bytes > 0) {
          if (!inFlight || !written || static_cast<std::size_t>(bytes) > kRecordBytes - received) { [self fail:@"unexpected_reply"]; break; }
          std::copy(buffer, buffer + bytes, incoming.begin() + received); received += bytes;
          if (received == kRecordBytes) {
            if (incoming != expected) { [self fail:@"noncanonical_reply"]; break; }
            if (![self check:now last:last]) break;
            if (now >= requestDeadline) { [self fail:initialized ? @"request_deadline" : @"initialization_deadline"]; break; }
            if (initialized && now >= leaseEnd) { [self fail:@"lease_deadline"]; break; }
            uint64_t renewedLease = leaseEnd, due;
            // Initial send can precede native runtime startup; only its accepted
            // ACK establishes parent live supervision. The helper independently
            // owns its250ms acceptance-time lease. Later renewals conservatively
            // use dispatch time, not potentially delayed acknowledgement time.
            if (current.op != static_cast<uint8_t>(Op::Stop) &&
                !Add(current.op == static_cast<uint8_t>(Op::Initialize) ? now : sentAt, kLeaseNs, renewedLease)) { [self fail:@"clock_overflow"]; break; }
            if (!Add(now, current.op == static_cast<uint8_t>(Op::Stop) ? 0 : kHeartbeatNs, due)) { [self fail:@"clock_overflow"]; break; }
            [_lock lock];
            if (_invalid) { [_lock unlock]; break; }
            void (^callback)(NSDictionary*) = nil;
            if (current.op == static_cast<uint8_t>(Op::Initialize)) callback = _startCompletion;
            if (current.op == static_cast<uint8_t>(Op::Stop)) callback = _fenceCompletion;
            if (current.op == static_cast<uint8_t>(Op::Initialize)) _startCompletion = nil;
            if (current.op == static_cast<uint8_t>(Op::Stop)) _fenceCompletion = nil;
            _ready = YES; _generation = current.stop_generation; _validUntil = renewedLease; [_lock unlock];
            initialized = YES; generation = current.stop_generation;
            fenced = current.status == Status::Fenced;
            leaseEnd = renewedLease; nextHeartbeat = due;
            [self deliver:callback reply:Reply(current) releaseFence:current.op == static_cast<uint8_t>(Op::Stop)];
            inFlight = NO;
          }
        }
      }
      // Preserve ownership while an exited child's buffered ACK is incomplete.
      if (!inFlight) {
        pollfd probe{input, POLLOUT, 0}; int probed = poll(&probe, 1, 0);
        if ((probed == -1 && errno != EINTR) || (probe.revents & (POLLERR | POLLHUP | POLLNVAL))) { [self fail:@"write_peer_closed"]; break; }
        int status = 0; pid_t resultPid = waitpid(pid, &status, WNOHANG);
        if (resultPid == pid) { exitCode = ExitCode(status); pid = -1; [self fail:@"child_exited"]; break; }
        if (resultPid == -1 && errno == ECHILD) { pid = -1; [self fail:@"child_unowned"]; break; }
        if (resultPid == -1 && errno != EINTR) { [self fail:@"wait_io"]; break; }
      }
    }
  }
  [self disconnect]; Close(input); Close(output); TerminateAndReap(pid, exitCode);
  [_lock lock]; _exitCode = exitCode; [_lock unlock];
}
@end
