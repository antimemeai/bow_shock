# N2a independent control-only helper

Read N2a/N3, the reviewed original private-controller process/pipe code and
BSContinuousClockWitness. The native helper links Foundation/libc only and does
not include CEF, Security/Keychain, AX, event posting/listening or network APIs.
It introduces no dependency and does not launch the browser during the open
keychain-prompt investigation. Root owns target packaging and parent adapter.

Agreed closed binary v1 with root: exact160-byte big-endian records with run,
request sequence and caller-owned Stop fence separately identified. Heartbeats
renew only the finite control liveness lease, never increment a fence or resume
a fenced capability. Initialize starts fence0; Stop/cancel require a newer caller
fence. Input capability is absent for every reply and every state. The maximum
5s control lease is not an input permission or future actuation lease.

Wrote docs/plan/native-control-helper.md and independent struct-encoded actual
executable tests before implementation. A compiled actual entry scaffold exited
without the required initialize reply; exact-trace oracle failed EOF with zero
reply bytes. Then replaced that entry with the original closed state machine,
strict wire decoder, nonblocking inherited-pipe supervision, finite initial/
lease/write deadlines and bounded input/two-reply storage.

Source grounding: Darwin SDK26.2 sys/fcntl.h defines O_NONBLOCK/F_GETFL/CLOEXEC
and F_SETNOSIGPIPE; sys/poll.h defines readiness/error/hangup; sys/unistd.h names
_PC_PIPE_BUF. The original continuous-clock producer validates the OS boot UUID
and converts mach_continuous_time with checked128-bit arithmetic, without wall
fallback. Read Apple's archived write/poll/pipe manuals for short-write/error,
readiness and peer-death semantics. Links are in the subplan. Check the actual
output pipe's PIPE_BUF before using atomic160-byte writes. Short positive writes
are poisoned; terminal error has at most one nonblocking diagnostic attempt,
with no stderr write or output wait that could postpone expiry.

Initial11actual-process methods passed4.86s. Final14methods passed4.95s including
fragmented/truncated/badwire/state/sequence/fence cases, exact Stop/cancel trace,
non-resumption, max-width counters,1s initialization stall, idle/partial lease
expiry, exact owned helper SIGSTOP past lease with queued heartbeat rejected,
full stdout-pipe expiry/write-stall, peer EOF/dead reader without SIGPIPE,
finite output queue saturation, and inbound Stop progress while prior output
stays undrained. The last oracle uses valid initialize/Stop fence7 followed by
an old-fence heartbeat; Fence closure before output drainage distinguishes
inbound progress from waiting on the reply pipe. No fake time or DST is used.

The runner owns a concrete absolute compiled path and sole unreaped Popen PID;
it signals only that child, resumes it before cleanup, and performs actual wait.
Helper replies are independently encoded from the byte specification. Physical
output backpressure cannot promise an acknowledgement; it must close instead
of leaving a control state alive. OS scheduling/process exit while suspended
is not a finite wall-time guarantee. No input/authority grant or DB state exists.
Independent review and root integration follow; N3/N4 remain open.

Strengthening dead-reader test found an idle supervision gap: Darwin did not
report write-end widowhood for zero requested events. The direct focused test
was red; corrected the helper to exclude idle stdout from the finite main poll
and afterwards probe POLLOUT with zero timeout, using only error/hangup. This
avoids a writable-fd busy loop. Revised14-method suite passed5.03s; independent
focused idle-reader check passed2.12s. The reviewer also checked initialized
reader death, non-renewing Stop lease,128-byte run, argc and nonpipe denial.

Independent review found Darwin pipe endpoint inodes differ even for one pipe.
The helper's equality check could not establish distinct private channels.
Removed it and documented trusted spawning host obligations: create two
distinct private pipes, close extraneous handles and own the unreaped PID.
Helper fstat/type/direction checks are transport shape, not privacy/identity
proof. No capability escape was found; no unsupported Darwin endpoint identity
mechanism was added. Final review closure follows this source clarification.

Final self-review found errno was read after the Foundation clock sample rather
than immediately after poll. Saved the original syscall error before sampling,
while retaining continuous expiry precedence. Focused actual short/expired
SIGSTOP plus stalled/dead-reader methods passed2.195s. This did not induce an
errno-clobbering Foundation call; independent source review verifies ownership
of that error. Suite now contains15methods; the full prior14passed before this
narrow correction and its three focused methods passed afterwards.

Independent final review papers/native-control-helper-code-review.md closes
NC-1 idle peer supervision, NC-2 unsupported endpoint-identity claim and NC-3
saved syscall errno. Final source SHA-256 is
2c7fdacf895148365e8293ee5bdb15aa479699cc614dd78541a56b79221040e7.
No remaining concrete blocker at this control-only trusted-host scope. Root
packaging/controller adapter and N3 work gates follow; this helper grants no
input power and the real browser/keychain investigation was not exercised.
No commit was made by this delegated owner.
