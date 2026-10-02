# Native private controller connection correction subplan

The actual Foundation connection currently blocks waiting for 4096 bytes and
closes blocking NSFileHandle reads on the UI thread. Replace its transport and
owned child lifecycle as one unit, retaining the public startup/send/invalidate
API. UI methods change bounded flags/pending state only. One serial worker owns
spawn, all descriptors, nonblocking poll/read/write, continuous two-second
request deadlines and idle process supervision. At most one request is pending.

Use posix_spawn with CLOEXEC-default, explicit stdio dup2 actions and minimal
LANG environment. Original pipe endpoints are close-on-exec, parent ends are
nonblocking, and the write endpoint suppresses SIGPIPE. No descriptor close,
wait, signal or blocking pipe IO runs on the UI thread. Invalidation reaches
the worker within its finite poll interval; it stops ordinary IO and performs
TERM, finite grace, KILL and owned-PID waitpid reconciliation. Never signal a
PID after reap. Idle exit/unsolicited output invalidates and notifies the main
queue through disconnectHandler.
Keep all owned spawn-source descriptors above 2 before constructing actions;
otherwise a closed parent stdin may let pipe() allocate fd 0 and a subsequent
source-close action destroys the child's assigned stdin. Closed stderr uses an
owned /dev/null source. Exercise closed parent stdio directly in the probe.
Final app exit must call waitForTermination only after the live message loop
has ended, so an async invalidate cannot leave a child behind. That explicit
join waits for the worker's actual reap, never substitutes a sleep interval.

This bootstrap binds replies to the exact current Rust Reply serialization:
version/op/run_id/id-if-present/stop_generation/active_powers, in that order,
with compact JSON and decimal integers. Compare bounded wire bytes to the
expected reply rather than NSJSONSerialization's lossy numeric/duplicate-key
decoder. This consciously requires canonical replies from our owned Rust child;
it is not a generic JSON or future provider protocol. Return a dictionary built
from the expected typed values only after equality. Any malformed/truncated,
oversized or unsolicited reply is terminal; late replies cannot clear a fault.

Before implementation, compile the actual existing class into a Foundation
probe. Exercise small live replies, idle death, stalled TERM-ignoring child,
UI-heartbeat/invalidate latency, exact PID reaping, malformed numbers and
duplicate keys. Preserve the direct red observations; add committed probe and
runner fixtures, implement and rerun those real process/pipe oracles. Root owns
CEF/main/build integration; this unit changes the connection only.
