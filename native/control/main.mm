#import "continuous_clock.h"
#include "protocol.h"
#include <cerrno>
#include <fcntl.h>
#include <limits>
#include <poll.h>
#include <sys/stat.h>
#include <unistd.h>

namespace {
using namespace bs_control;
bool Add(uint64_t now, uint64_t duration, uint64_t& result) {
  if (duration > std::numeric_limits<uint64_t>::max() - now) return false;
  result = now + duration; return true;
}
bool Clock(uint64_t& now) {
  NSDictionary* sample = BSContinuousClockWitness();
  if (!sample) return false;
  now = [sample[@"continuous_ns"] unsignedLongLongValue];
  return true;
}
bool ConfigurePipes() {
  struct stat input{}, output{};
  if (fstat(STDIN_FILENO, &input) || fstat(STDOUT_FILENO, &output) ||
      !S_ISFIFO(input.st_mode) || !S_ISFIFO(output.st_mode)) return false;
  // The trusted spawning host must create two distinct private pipes. Darwin
  // endpoint st_ino values do not establish anonymous-pipe identity/privacy.
  for (int fd : {STDIN_FILENO, STDOUT_FILENO}) {
    int flags = fcntl(fd, F_GETFL);
    if (flags == -1 || (flags & O_ACCMODE) != (fd == STDIN_FILENO ? O_RDONLY : O_WRONLY) ||
        fcntl(fd, F_SETFL, flags | O_NONBLOCK) == -1 ||
        fcntl(fd, F_SETFD, FD_CLOEXEC) == -1) return false;
  }
  return fpathconf(STDOUT_FILENO, _PC_PIPE_BUF) >= static_cast<long>(kRecordBytes) &&
      fcntl(STDOUT_FILENO, F_SETNOSIGPIPE, 1) != -1;
}
struct Pending { Wire wire{}; uint64_t deadline = 0; };
class Helper final {
 public:
  int Run() {
    uint64_t now;
    if (!Clock(now)) return Close(Fault::Clock);
    last_clock_ = now;
    if (!Add(now, kInitTimeoutNs, deadline_)) return Close(Fault::Overflow);
    for (;;) {
      @autoreleasepool {
        Fault fault = Check(now);
        if (fault != Fault::None) return Close(fault);
        if (closing_ && queued_ == 0) return 0;
        pollfd fds[] = {{closing_ ? -1 : STDIN_FILENO, POLLIN, 0},
            {queued_ ? STDOUT_FILENO : -1, POLLOUT, 0}};
        int result = poll(fds, 2, 10);
        int poll_error = errno;  // Preserve syscall failure before Foundation calls.
        fault = Check(now);  // Suspension/EINTR cannot postpone continuous expiry.
        if (fault != Fault::None) return Close(fault);
        if (result == -1) { if (poll_error == EINTR) continue; return Close(Fault::IO); }
        if (!queued_) {
          // Darwin does not expose a widowed pipe through a zero-event poll.
          // Probe after the finite input wait, ignoring writable readiness so
          // ordinary idle stdout cannot cause a busy loop.
          pollfd output{STDOUT_FILENO, POLLOUT, 0};
          int probed = poll(&output, 1, 0);
          if (probed == -1 && errno != EINTR) return Close(Fault::IO);
          if (output.revents & (POLLERR | POLLHUP | POLLNVAL)) return Close(Fault::IO);
        }
        if (fds[1].revents & (POLLERR | POLLHUP | POLLNVAL)) return Close(Fault::IO);
        if (fds[0].revents & POLLNVAL) return Close(Fault::IO);
        if (fds[0].revents & (POLLIN | POLLHUP | POLLERR)) {
          ssize_t read_bytes = read(STDIN_FILENO, input_.data() + received_, kRecordBytes - received_);
          if (read_bytes == 0) return Close(received_ ? Fault::Truncated : Fault::IO);
          if (read_bytes < 0) { if (errno != EAGAIN && errno != EINTR) return Close(Fault::IO); }
          else {
            received_ += static_cast<std::size_t>(read_bytes);
            if (received_ == kRecordBytes) {
              fault = Check(now);
              if (fault == Fault::None) fault = Accept(now);
              if (fault != Fault::None) return Close(fault);
              received_ = 0;
            }
          }
        }
        if (queued_ && (fds[1].revents & POLLOUT)) {
          fault = Check(now);
          if (fault != Fault::None) return Close(fault);
          // The private output is a pipe, and this record is <=PIPE_BUF.
          // A positive short write is poisoned rather than retried as a frame.
          ssize_t bytes = write(STDOUT_FILENO, pending_[head_].wire.data(), kRecordBytes);
          if (bytes == static_cast<ssize_t>(kRecordBytes)) { head_ = (head_ + 1) % 2; --queued_; }
          else if (bytes >= 0 || (errno != EAGAIN && errno != EINTR)) return Close(Fault::IO, false);
        }
      }
    }
  }
 private:
  Fault Check(uint64_t& now) {
    if (!Clock(now) || now < last_clock_) return Fault::Clock;
    last_clock_ = now;
    if (!closing_ && now >= deadline_) return initialized_ ? Fault::LeaseExpired : Fault::InitializationExpired;
    if (queued_ && now >= pending_[head_].deadline) return Fault::WriteStall;
    return Fault::None;
  }
  Fault Accept(uint64_t now) {
    Record request;
    Fault fault = DecodeRequest(input_, request);
    if (fault != Fault::None) return fault;
    Op op = static_cast<Op>(request.op);
    if (!initialized_) {
      if (op != Op::Initialize) return Fault::State;
      if (request.sequence != 1) return Fault::Sequence;
      if (request.stop_generation != 0) return Fault::Fence;
    } else {
      if (op == Op::Initialize || request.run != run_) return Fault::State;
      if (request.sequence <= sequence_) return Fault::Sequence;
      bool fence_op = op == Op::Stop || op == Op::Cancel;
      if (fence_op ? request.stop_generation <= generation_ : request.stop_generation != generation_) return Fault::Fence;
    }
    bool renew = op == Op::Initialize || op == Op::Heartbeat;
    if (renew ? request.lease_ms == 0 || request.lease_ms > kMaxLeaseMs : request.lease_ms != 0) return Fault::Lease;
    if (queued_ == 2) return Fault::Queue;
    uint64_t expires = deadline_, write_deadline;
    if ((renew && !Add(now, static_cast<uint64_t>(request.lease_ms) * 1000000, expires)) ||
        !Add(now, kWriteTimeoutNs, write_deadline)) return Fault::Overflow;
    initialized_ = true; run_ = request.run; sequence_ = request.sequence;
    generation_ = request.stop_generation; deadline_ = expires;
    if (op == Op::Stop || op == Op::Cancel) status_ = Status::Fenced;
    if (op == Op::Shutdown) { status_ = Status::Closed; closing_ = true; }
    request.op |= 128; request.lease_ms = 0; request.status = status_;
    pending_[(head_ + queued_) % 2] = {EncodeReply(request), write_deadline};
    ++queued_;
    return Fault::None;
  }
  int Close(Fault fault, bool can_write = true) {
    // Terminal state first; drop every ordinary reply and never read/renew again.
    status_ = Status::Closed; closing_ = true; queued_ = 0;
    if (can_write) {
      Record terminal;
      terminal.op = 255; terminal.run = run_; terminal.sequence = sequence_;
      terminal.stop_generation = generation_; terminal.status = Status::Closed; terminal.error = fault;
      Wire wire = EncodeReply(terminal);
      // One nonblocking diagnostic attempt; no waits, retries or stderr IO.
      (void)write(STDOUT_FILENO, wire.data(), wire.size());
    }
    return ExitCode(fault);
  }
  Wire input_{};
  Pending pending_[2];
  std::size_t received_ = 0, head_ = 0, queued_ = 0;
  std::string run_;
  uint64_t sequence_ = 0, generation_ = 0, deadline_ = 0, last_clock_ = 0;
  Status status_ = Status::Live;
  bool initialized_ = false, closing_ = false;
};
}  // namespace

int main(int argc, char**) {
  @autoreleasepool {
    if (argc != 1) return bs_control::ExitCode(bs_control::Fault::Syntax);
    if (!ConfigurePipes()) return bs_control::ExitCode(bs_control::Fault::IO);
    return Helper().Run();
  }
}
