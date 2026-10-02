# N2a independent native control helper

Build one original Foundation/POSIX executable with no CEF or input APIs. Its
only state is the host's run identity, request sequence, caller-owned fence
counter and finite control liveness lease. It is not an authority owner and
cannot grant, post, listen for or resume input. Root owns CMake/controller
integration and concrete production spawn/reap; this unit supplies the helper,
closed wire contract and direct actual-process oracle.

Protocol v1 uses exactly 160 bytes per record, big-endian integers, no native
struct layout. Offsets: magic `BSCH` 0..3; version 1 at 4; op at 5; zero reserved
6..7; sequence u64 at 8; stop generation u64 at 16; lease milliseconds u32 at
24; run length at 28; status/error/input-capability bytes at 29/30/31; 128-byte
run region at 32. Run length is 1..128 ASCII alphanumeric/-_. and unused padding
is exactly zero. Request status/error/input bytes are zero. Replies use op|128,
status live/fenced/closed (1/2/3), error zero and input capability always zero.
Terminal error op255 carries only the last accepted identity/sequence/fence,
or empty identity/zero counters before initialization; a poisoned or blocked
output can instead close with no error record. No request input is echoed on an
error. Unknown versions/operations, nonzero reserved/padding, stale sequence,
wrong run/fence, pre-init/re-init or invalid leases close the process.

Operations: initialize1 requires seq1/fence0 and a lease1..5000ms; heartbeat2
requires strictly newer sequence, the same current fence and lease1..5000ms;
stop3/cancel4 require a strictly newer caller fence and lease0; shutdown5 uses
current fence and lease0. Stop/cancel permanently move to fenced, do not extend
the current lease, and acknowledge that fence only. Heartbeat renews control
liveness in either state and never reopens a power. Sequence and fence are
separate; heartbeat cannot increment the caller's Stop counter. A five-second
control lease is not a future input lease or permission.

Reuse BSContinuousClockWitness: real boot UUID and mach_continuous_time, no
wall-clock fallback. Initialize within1s of helper entry, expire active control
at its continuous deadline, and bound pending reply writes by500ms. Compare time
before/after poll and before processing every complete frame, including after
SIGSTOP. Nonblocking inherited pipes, at most160 bytes partial input and two
queued160-byte replies, finite10ms poll interval, PIPE_BUF atomic record writes
and descriptor-level SIGPIPE suppression keep backpressure from blocking expiry.
Queue saturation or malformed IO is terminal; physical backpressure cannot
promise delivery of a cancellation acknowledgement. State closes first and
ordinary work never runs after fault. No retry or external effects exist.

Read the existing reviewed controller POSIX process/pipe implementation, actual
Darwin SDK nonblocking-pipe/poll/SIGPIPE contracts, and the original continuous
clock producer before implementation. Add direct executable tests first. A
minimal actual helper entry scaffold must fail the expected initialize reply;
then implement the closed state machine and transport. Oracles independently
encode the specified bytes and assert exact responses/EOF/exit: fragmented and
truncated frames, wrong wire/type/version/padding, sequence/fence violations,
Stop/cancel/non-resumption, finite initialization/input stalls, idle lease,
pipe peer death, full reply-pipe backpressure and exact owned helper SIGSTOP
past lease followed by a queued renewal. No fake clock or CEF app is used.

The test runner compiles and spawns one concrete absolute executable with only
LANG environment, inherited owned pipes and close_fds. It solely signals/reaps
its unreaped child; kernel process exit itself is not promised to be schedulable
while the OS suspends it. Expiry must be observed immediately on resumed work.
Independent review follows green. N3/native capture and all N4 input remain open.

Terminal error byte codes are1 syntax,2 unsupported op,3 state/run,4 sequence,
5 fence,6 lease,7 truncated,8 initial deadline,9 control expiry,10 reply stall,
11 IO,12 unavailable/backwards clock,13 arithmetic overflow,14 reply queue full.
Exit status is16+error. Successful shutdown exits0 after its complete reply.
Syntax/state/sequence/fence/lease checks precede queue admission, and no invalid
record advances accepted counters. Error output uses the last accepted values.

Grounding: actual Xcode SDK26.2 `sys/fcntl.h` (O_NONBLOCK/F_SETNOSIGPIPE),
`sys/poll.h` and `sys/unistd.h` (_PC_PIPE_BUF); Apple clang17.0.0 on arm64.
[Apple write(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/write.2.html)
requires handling returned counts and nonblocking errors;
[poll(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/poll.2.html)
provides readiness/hangup/error masks;
[pipe(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/pipe.2.html)
describes peer EOF/SIGPIPE. These older Apple manuals are contract background;
the actual SDK/runtime pipe oracles ground this tested macOS construction.
No implementation is copied from these references.

Direct dead-reader refinement found a real idle-supervision gap: requesting
zero stdout events did not report a widowed pipe on this Darwin runtime. Probe
stdout POLLOUT with zero timeout after the finite input wait when no reply is
pending. Ignore ordinary writable readiness; only its error/hangup closes.
This detects reader death without making the idle loop spin on writable stdout.
Recheck the actual dead-reader oracle before final review.

Trusted host obligation: construct two distinct private anonymous pipes, close
extraneous descriptors and retain sole process-reap ownership. The helper
verifies endpoint pipe type/direction and transport properties, not exclusivity
or channel identity. Independent review observed different st_ino values for
the two endpoints of one Darwin pipe; fstat equality therefore cannot prove
distinct anonymous pipes. Removed that unsupported comparison. A trusted host
loopback misconfiguration remains a violated host precondition, not a second
capability authority or an accepted input channel.
