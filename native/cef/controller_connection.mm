#import "controller_connection.h"
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
    mach_timebase_info_data_t value; mach_timebase_info(&value); return value;
  }();
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
bool Launch(NSString* path, int& input, int& output, pid_t& pid) {
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
    if (posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT) != 0) break;
    if (posix_spawn_file_actions_adddup2(&actions, toChild[0], STDIN_FILENO) != 0 ||
        posix_spawn_file_actions_adddup2(&actions, fromChild[1], STDOUT_FILENO) != 0 ||
        posix_spawn_file_actions_adddup2(&actions, stderrCopy, STDERR_FILENO) != 0) break;
    bool closed = true;
    for (int fd : {toChild[0], toChild[1], fromChild[0], fromChild[1], stderrCopy})
      if (posix_spawn_file_actions_addclose(&actions, fd) != 0) closed = false;
    if (!closed) break;
    const char* executable = path.fileSystemRepresentation;
    char* argv[] = {const_cast<char*>(executable), nullptr};
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

@implementation BSControllerConnection {
  NSURL* _executableURL;
  dispatch_queue_t _worker;
  dispatch_group_t _finished;
  NSLock* _lock;
  BOOL _started, _ready, _invalid, _pending, _notified;
  uint64_t _requestId, _stopGeneration;
  NSDictionary* _request;
  void (^_completion)(NSDictionary*);
  void (^_disconnect)(void);
  double _deadline;
  pid_t _ownedPid;
}
- (instancetype)init {
  NSString* path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/MacOS/bow-shock-controller"];
  return [self initWithExecutableURL:[NSURL fileURLWithPath:path]];
}
- (instancetype)initWithExecutableURL:(NSURL*)url {
  self = [super init];
  if (self) {
    _executableURL = [url copy]; _runId = NSUUID.UUID.UUIDString;
    _worker = dispatch_queue_create("dev.bowshock.controller-io", DISPATCH_QUEUE_SERIAL);
    _finished = dispatch_group_create();
    _lock = [[NSLock alloc] init]; _ownedPid = -1;
  }
  return self;
}
- (pid_t)childPid { [_lock lock]; pid_t pid = _ownedPid; [_lock unlock]; return pid; }
- (void)setDisconnectHandler:(void (^)(void))handler {
  [_lock lock]; _disconnect = [handler copy]; [_lock unlock];
}
- (void (^)(void))disconnectHandler {
  [_lock lock]; void (^handler)(void) = _disconnect; [_lock unlock]; return handler;
}
- (void)startWithCompletion:(void (^)(NSDictionary*))completion {
  [_lock lock];
  if (_started || _invalid) {
    [_lock unlock]; dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); }); return;
  }
  _started = YES; _pending = YES;
  _request = @{@"version": @1, @"op": @"initialize", @"run_id": _runId};
  _completion = [completion copy]; _deadline = Now() + 2;
  dispatch_group_enter(_finished);
  [_lock unlock]; dispatch_async(_worker, ^{ [self pump]; dispatch_group_leave(self->_finished); });
}
- (void)sendOperation:(NSString*)operation completion:(void (^)(NSDictionary*))completion {
  [_lock lock];
  if (_invalid || !_ready || _pending || _requestId == UINT64_MAX ||
      ![@[@"ping", @"stop_all", @"shutdown"] containsObject:operation]) {
    [_lock unlock]; dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); }); return;
  }
  _requestId += 1; _pending = YES;
  _request = @{@"version": @1, @"op": [operation copy], @"id": @(_requestId)};
  _completion = [completion copy]; _deadline = Now() + 2;
  [_lock unlock];
}
- (void)invalidate { [_lock lock]; _invalid = YES; [_lock unlock]; }
- (void)waitForTermination { [self invalidate]; dispatch_group_wait(_finished, DISPATCH_TIME_FOREVER); }
- (void)disconnect {
  [_lock lock]; _invalid = YES;
  void (^completion)(NSDictionary*) = _completion;
  _completion = nil; _request = nil; _pending = NO;
  void (^handler)(void) = _disconnect;
  if (_notified) handler = nil;
  _notified = YES;
  [_lock unlock];
  dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil); if (handler) handler(); });
}
- (void)pump {
  int input = -1, output = -1; pid_t pid = -1;
  if (!Launch(_executableURL.path, input, output, pid)) { [self disconnect]; return; }
  [_lock lock]; _ownedPid = pid; [_lock unlock];
  NSData* outgoing = nil; NSUInteger written = 0;
  NSMutableData* frame = [NSMutableData dataWithCapacity:65536];
  NSData* expectedBytes = nil; NSDictionary* expectedReply = nil;
  BOOL shutdown = NO, failed = NO;
  while (!failed && !shutdown) {
    @autoreleasepool {
      [_lock lock];
      BOOL invalid = _invalid; NSDictionary* request = _request;
      double deadline = _deadline; uint64_t generation = _stopGeneration;
      [_lock unlock];
      if (invalid || (request && Now() >= deadline)) { failed = YES; break; }
      if (request && !outgoing) {
        NSString* op = @{@"initialize": @"initialized", @"ping": @"pong", @"stop_all": @"stopped", @"shutdown": @"shutdown"}[request[@"op"]];
        if ([op isEqual:@"stopped"] && generation == UINT64_MAX) { failed = YES; break; }
        generation += [op isEqual:@"stopped"] ? 1 : 0;
        NSString* idField = request[@"id"] ? [NSString stringWithFormat:@",\"id\":%llu", [request[@"id"] unsignedLongLongValue]] : @"";
        NSString* canonical = [NSString stringWithFormat:@"{\"version\":1,\"op\":\"%@\",\"run_id\":\"%@\"%@,\"stop_generation\":%llu,\"active_powers\":[]}", op, _runId, idField, generation];
        expectedBytes = [canonical dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableDictionary* reply = [@{@"version": @1, @"op": op, @"run_id": _runId, @"stop_generation": @(generation), @"active_powers": @[]} mutableCopy];
        if (request[@"id"]) reply[@"id"] = request[@"id"];
        expectedReply = reply;
        NSMutableData* bytes = [[NSJSONSerialization dataWithJSONObject:request options:0 error:nil] mutableCopy];
        [bytes appendBytes:"\n" length:1]; outgoing = bytes; written = 0;
      }
      bool writing = outgoing && written < outgoing.length;
      // Do not poll a closed stdin after finishing the request: POLLERR would
      // otherwise turn an idle/awaiting-response worker into a busy loop.
      pollfd fds[] = {{output, POLLIN, 0}, {writing ? input : -1, POLLOUT, 0}};
      int polled = poll(fds, 2, 20);
      if (polled == -1 && errno != EINTR) { failed = YES; break; }
      if ((fds[1].revents & (POLLERR | POLLHUP | POLLNVAL)) && outgoing && written < outgoing.length) {
        failed = YES; break;
      }
      if (fds[1].revents & POLLOUT) {
        ssize_t count = write(input, static_cast<const char*>(outgoing.bytes) + written, outgoing.length - written);
        if (count > 0) written += count;
        else if (count == 0 || (errno != EAGAIN && errno != EINTR)) { failed = YES; break; }
      }
      if (fds[0].revents & (POLLIN | POLLHUP | POLLERR | POLLNVAL)) {
        unsigned char bytes[4096]; ssize_t count = read(output, bytes, sizeof(bytes));
        if (count <= 0) {
          if (count == 0 || (errno != EAGAIN && errno != EINTR)) failed = YES;
        } else {
          for (ssize_t i = 0; i < count; ++i) {
            if (!outgoing || written != outgoing.length) { failed = YES; break; }
            if (bytes[i] == '\n') {
              if (i + 1 != count || ![frame isEqual:expectedBytes]) { failed = YES; break; }
              [_lock lock]; invalid = _invalid || Now() >= _deadline;
              void (^completion)(NSDictionary*) = _completion;
              if (!invalid) {
                _stopGeneration = [expectedReply[@"stop_generation"] unsignedLongLongValue];
                _ready = YES; _pending = NO; _request = nil; _completion = nil;
              }
              [_lock unlock];
              if (invalid) { failed = YES; break; }
              NSDictionary* delivered = expectedReply;
              dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(delivered); });
              shutdown = [expectedReply[@"op"] isEqual:@"shutdown"];
              outgoing = nil; expectedBytes = nil; expectedReply = nil; [frame setLength:0]; break;
            }
            if (bytes[i] == '\r' || frame.length == 65536) { failed = YES; break; }
            [frame appendBytes:bytes + i length:1];
          }
        }
      }
      // An exited child can leave payload and delimiter in separate reads.
      // While a response is pending, drain to a complete frame/EOF before reap;
      // its PID stays owned and its two-second deadline still applies.
      if (!outgoing || shutdown) {
        pid_t result = waitpid(pid, nullptr, WNOHANG);
        if (result == pid || (result == -1 && errno == ECHILD)) { pid = -1; if (!shutdown) failed = YES; }
        else if (result == -1 && errno != EINTR) failed = YES;
      }
    }
  }
  // Connection state is known before process exit/reap. Report it promptly;
  // group completion independently joins actual process ownership cleanup.
  [self disconnect]; Close(input); Close(output); TerminateAndReap(pid);
}
@end
