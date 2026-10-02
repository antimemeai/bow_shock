# Native connection and owned child lifecycle

Independent review exposed real bugs in the first NSFileHandle/NSTask adapter:
4096-byte reads wait for full size or EOF, UI invalidation closes a blocked read,
and a child ignoring TERM could keep that close blocked. Idle child death had no
notification/reap path. Foundation's collapsed JSON object/NSNumber comparisons
also accepted boolean version and fractional generation values.

Wrote [the correction subplan](../docs/plan/native-controller-link.md), then
compiled the actual connection class into a committed Foundation probe. Red
oracles observed a short live reply incorrectly yielding INIT nil, idle death
without DISCONNECTED, and UI invalidation timing out after five seconds with
a TERM-ignoring child. The test runner cleans the exact controlled fixture PID
on a failed test, checking its temporary executable command before signaling.

Replaced the adapter with a bounded nonblocking POSIX pipe pump on one serial
worker. UI methods only publish flags and one pending finite request. The worker
owns posix_spawn file actions, private CLOEXEC endpoints, SIGPIPE-suppressed
writing, poll every 20ms, two-second mach_continuous_time deadlines, strict
64KiB framing, idle supervision and owned PID handling. Faults notify the main
queue before teardown; worker TERM grace is .25sec then KILL and actual waitpid
reap. Kernel exit may remain uncertain; final waitForTermination outside the
live UI joins actual reconciliation rather than assuming a timer guarantees it.

Response acceptance explicitly binds compact canonical bytes from our current
Rust Reply serialization. No JSON Value/object collapse is used; booleans,
fractions, duplicate keys, wrong fields and wire extensions fail equality.
This is an intentional private bootstrap protocol subset, not generic JSON.

The reviewer also identified buffered-reply/child-exit ordering and descriptor
collision. A pending response drains to complete frame/EOF/deadline before reap;
a closed child stdin does not discard already-buffered complete replies. All
spawn source descriptors are moved above stdio before dup2/close actions, and
closed stderr uses an owned /dev/null source. A direct closed-parent-stdin test
failed red before that fix. Invalidation checks and continuous deadlines are
rechecked at the response acceptance boundary. childPid is original-PID smoke
metadata, never a live signaling handle.

Initial six-test actual-class suite passed, then seven tests passed with final
join included. Final focused probes passed for closed stdin/stderr, immediate
loop-end join against TERM-ignore, and actual release Rust four-operation wire
compatibility. An already-exited buffered-reply fixture SIGSTOPs only its own
probe parent before writing/exiting; the driver resumes the owned parent and
requires the valid reply plus disconnect, after directly observing the exact
child zombie and stopped parent states. That all-buffered test does not claim
to reproduce the separate partial-read race; no-reap-pending is the reviewed
source correction for that ordering. Independent final recheck follows.
Strict compilation of the actual class and probe passed with -Wall/-Wextra/
-Werror. The poll set excludes stdin after all request bytes are written, so a
closed stdin cannot repeatedly return POLLERR and consume idle CPU while stdout
is still live. Response deadline checks use the continuous clock at acceptance.
No grants/effects/agent/storage are enabled by these connection tests.

The same native reviewer independently ran the final actual-class suite:
eleven test methods passed in 61.494sec, plus the corrected exact-state
buffered-exit probe passed in 5.040sec. The reviewer inspected the final idle
poll correction and reports no remaining connection findings. Root separately
owns real CEF app teardown, packaging and full window smoke; Foundation tests
do not establish those integration outcomes.

Strengthened the deadline oracle to require INIT nil and DISCONNECTED before
the probe's later explicit invalidation. A focused CLI probe intermittently
missed late fixture timers: captured output already showed deadline rejection/
disconnect, and its exact child was absent. Direct sampled recheck completed
normally. The windowless command-line probe now holds a UserInitiated/
LatencyCritical NSProcessInfo activity to avoid idle App Nap coalescing its
supervisory timers; no production behavior changed. That focused strengthened
case passed. The committed compiler now enforces -Wall/-Wextra/-Werror and the
actual-Rust trace explicitly reads and invokes the pinned toolchain channel.
