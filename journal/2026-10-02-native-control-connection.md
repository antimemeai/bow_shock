# Native parent connection to the control-only helper

Owned the original BSControlConnection class, direct Foundation probe/process
tests and written subplan. Root owns main/AppKit/CMake; the table owner exposes
worker-readable connected/run/Stop metadata. Kept the original bootstrap link
and reviewed native helper unchanged. Read BLACKBIRD, their process/pipe/clock
source and direct oracles first. No new dependency or CEF/Keychain launch.

The compiled nil/closed scaffold failed the required actual-helper initialize
oracle: INIT nil PID-1 rather than INIT ok. Then implemented one serial worker
owning concrete posix_spawn, two distinct private CLOEXEC pipes, parent
nonblocking IO, explicit child stdio, minimal LANG environment and descriptor
SIGPIPE suppression. Spawn sources move above2 so closed parent stdin/stderr
cannot collide with dup2/close actions. Original child PID is exposed only as
metadata; the worker retains unreaped ownership for all signalling and actual
waitpid reconciliation. UI invalidation publishes flags only; disconnected
state precedes TERM,250ms grace, KILL and reap off the UI.

The externally supplied host run obeys the helper's closed ASCII wire identity.
Only initialize, internal heartbeat and mirrored caller Stop fences exist.
Every ACK must equal the complete expected160-byte canonical reply with exact
run/sequence/fence/status and zero input capability. One frame and one pending
external fence are bounded; accepted fence callbacks retain their slot until
UI delivery, preventing an accepted callback backlog during main stalls.
Non-increasing caller generations reject without replacing an accepted fence.
Heartbeats preserve acknowledged generation and remain Fenced after Stop.
The class never creates a local grant or resumes input.

Startup and live scheduling needed separate budgets. A private actual-source
diagnostic observed initial request expiry about108ms after dispatch:100ms
also included helper runtime startup. The original probe could revoke
authority350ms from the start before slow initialization had completed. The
final initialization budget is2s from constructor through launch/initial ACK,
matching the existing bootstrap's finite scale. The probe starts live checks
after the actual ACK. Subsequent requests retain100ms, helper lease250ms,
heartbeat50ms and poll10ms. The parent's initial live watchdog begins at ACK;
later renewals conservatively use dispatch time. Stop preserves that watchdog
and makes a heartbeat immediately due. Arithmetic is checked before removing
callbacks. Clock/provider/expiry checks precede ordinary IO/ACK advancement;
delayed main callbacks also check continuous liveness before returning success.
This is schedule-dependent control liveness, not input authority or hard OS
scheduling/process-exit promises. The provider must remain nonblocking and
thread-safe; it never calls UI/CEF.

The first inheritance oracle incorrectly compared Python's effective
environment to LANG alone. Directly observed the interpreter adds
LC_CTYPE=C.UTF-8. Replaced this oracle with a native process-entry fixture that
checks environment and descriptors before interpreter initialization, while
the probe deliberately opens a non-CLOEXEC extra handle. Native entry passed.
No parent environment or credentials are copied into the child.

One ignored diagnostic invocation and a later focused native inheritance
invocation timed out5s without a retained owned sample; both later invocations
passed. Their startup cause remains unproved, and there is no link established
to the older CEF startup/shutdown observations. Added direct timeout evidence
retention (owned PID stdout/stderr and exact still-unreaped parent sample before
cleanup) for a repeat, rather than claiming the timeouts were explained by the
initial-request or interpreter-oracle findings.

Final ten actual-process methods passed20.622s, including strict clang++
C++20/ARC/Foundation/CoreFoundation Wall/Wextra/Werror compilation. Oracles
cover original-helper initialization/heartbeats/exact fence7, main-loop stall
while worker ACK and authority-loss/reap proceed before UI resumes, late fence
callback withheld and additional callback slots rejected, constructor expiry/
wrong run/nonfile URL, malformed capability/fence/partial/stalled/EOF/flood
responses, idle child exit, closed parent stdio, native descriptor/environment
entry and flag-only invalidate against TERM-ignore. An exact owned app self-stop
test observes app T and actual helper Z before SIGCONT, proving independent
helper expiry without claiming the suspended parent can physically exit.
Every successful probe joins and the driver checks exact child PID absence.
No fake clock, input APIs, CEF, Keychain, detsim or mutation work is used.

Root independent source/process review follows this green snapshot before
packaging/UI integration. Native capture-work servicing and actual table/UI
join remain separate gates. External-driver fences exercise this control pipe;
they do not prove a physical human Stop listener or quiescent external effects.

## Independent availability failure and diagnostic refinement

Root's independent full10-method run failed the fd0 case with INIT nil PID46911,
DISCONNECTED/REAPED; its other nine methods passed. The old output did not
identify a terminal phase, and neither a descriptor collision nor startup
deadline was proved. Kept that availability failure open.

Added thread-safe failureReason containing only fixed source literals and an
actual owned childExitCode (-1 until known, normal exit or128+signal). The first
known reason survives final invalidate/join. Launch/configuration, clock,
authority, initial/live/request deadlines, pipe IO/EOF, unexpected/canonical
reply and child-reap phases are distinct. Callback-side clock/lease rejection
also records a reason before returning nil. No path/run/page or rejected wire
bytes are emitted. Actual test stdout/stderr are retained before assertions,
including non-timeout failures; timeout output is saved both at failure and
after sampling/cleanup so later terminal output is not discarded.

Twelve finite closed-stdin attempts overlapping actual native helper compilation
did not reproduce the old nil failure. All observed actual fence7 and the
intended authority_lost closure with exit27. These repetitions do not explain
the old failure. A later focused run timed out5s for owned probe52171 after INIT
ok/helper52173. Its retained sample shows main in normal CFRunLoop, worker in
normal poll transitioning to TerminateAndReap, and the probe background block
in usleep; the sample also briefly saw main ending its activity/returning.
That repeat was successful initialization followed by an overall probe timeout,
not the earlier nil-init symptom. Evidence remains under ignored
context/runtime/control-connection-failure-52171/. Its final terminal output
was not retained by that version of the timeout handler; the refined handler
now retains it. No causal explanation is asserted for either old symptom.

Studying the oracle found two concrete test issues. The deliberate extra
/dev/null handle could occupy fd0/2 and mask closed-stdio coverage; it now moves
above2 while remaining intentionally inheritable, preserving the input case.
The live-test revocation timer began at worker connected state, which precedes
main start-callback delivery. Correct late-publication withholding could then
produce INIT nil if authority was deliberately revoked before that callback.
Normal live tests now start their interval after actual positive UI delivery;
the intentional main stall marks that delivery before blocking. A separate
actual-helper delayed-main test reproduces this race intentionally and requires
nil with authority_lost, proving the mechanism without claiming it caused the
unsampled old failure. The TERM-ignore invalidation test now waits for the
fixture's installed-handler marker and requires actual KILL exit137, rather
than assuming a handler was installed50ms after process start.

Final eleven actual methods passed22.230s with strict compilation and exact
static reasons for configuration/launch/canonical/partial/stall/EOF/flood
cases. Runtime startup2s, ordinary100ms, helper250ms, heartbeat50ms and poll10ms
are unchanged in this refinement. Root must independently recheck this source
snapshot; the historical nil-init availability cause remains open pending
matching phase evidence. No CEF, Keychain, network/input or helper-product
change was made.

## Native fault-peer availability correction

Root's final independent11 run produced a narrower diagnostic failure: Python
idle peer53295 missed initialization2s and was reaped with KILL137. Its real
helper normal/closed-stdio/main-stall cases passed. This distinguishes a
synthetic interpreter-peer startup failure from the older unclassified real
helper nil case; the latter remains open.

Replaced the Python fault script with original compiled
tests/control_connection_fault_peer.cc (POSIX/C++ only, no Foundation or
production codec). Fixed byte offsets independently construct ACK mutations.
Owned ready/seen/sent markers establish handler setup, actual request arrival
and intended partial/malformed/EOF/flood phase. Tests require these phases plus
the parent's fixed reason, so a generic startup timeout cannot satisfy a
malformed/partial oracle. Stall intentionally proves ready but does not read.
Idle services heartbeat until the real positive main callback creates its
owned release marker, then exits normally; it no longer races a20ms delay
against presentation. The native inheritance fixture remains a separate
process-entry oracle and the original real control helper stays unchanged.

Focused idle/malformed/installed-TERM-ignore methods passed14.341s including
strict compilation. Added explicit normal child exit0 for idle. Product2s/
100ms/250ms budgets and product source are unchanged. Root will perform one
focused recheck; no blanket repeat suite was run for this fixture correction.
