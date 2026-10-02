# Native parent connection to the control-only helper

This unit owns one original Foundation/POSIX parent connection, its concrete
child and two distinct private pipes. It joins the externally supplied table
host run and caller-owned Rust Stop generation to the already reviewed160-byte
native control protocol. It cannot grant, drive or resume input. Root owns
main/AppKit/CMake wiring; the table owner exposes a locked connected getter for
the worker's authorityAliveProvider. Neither existing controller connection nor
the helper implementation is refactored in this unit.

Public methods publish bounded flags/one pending fence, never perform process
or pipe waits on the UI. A serial worker owns spawn, nonblocking IO, canonical
ACK validation, continuous time and exact unreaped PID cleanup. Initialization
has2s for launch and initial ACK from the constructor's clock sample before
spawn; subsequent requests have100ms from dispatch. Helper control liveness is250ms; heartbeat is
due50ms after an accepted ACK, with10ms polling. These are schedule-dependent
liveness conditions, not hard wall-time scheduling promises. Continuous expiry
is checked after suspension and before writes, ACK acceptance and ordinary
advancement. Loss of the worker-only authority provider closes independently
of a main callback. The provider must be thread-safe, nonblocking and free of
UI/CEF calls; an arbitrarily blocked provider cannot be made finite by this unit.

One request is in flight and one external fence may wait behind it. A fence
takes priority over any new heartbeat; strictly newer caller generations may
skip, but never derive a grant or local generation. Heartbeats retain the exact
last acknowledged fence and remain Fenced after Stop. Sequence overflow,
non-increasing fence, malformed/noncanonical/unsolicited/partial/late replies,
EOF, pipe stalls and child death fail closed. Wrong API requests reject without
replacing an accepted fence. Accepted external callback slots stay occupied
until their main-queue delivery, bounding callback backlog during UI stalls.
Queued callbacks recheck closed state and cannot publish success after fault.

Use the original reviewed POSIX supervision patterns: move all spawn sources
above stdio, distinct CLOEXEC pipes, POSIX_SPAWN_CLOEXEC_DEFAULT, explicit dup2,
minimal LANG environment, nonblocking parent ends, descriptor SIGPIPE
suppression and owned /dev/null stderr. No helper/CEF descriptor inheritance.
State becomes disconnected before TERM; finite250ms TERM grace then KILL and
waitpid reconcile only the still-owned child. Final waitForTermination is an
explicit off-live-UI join. Physical process exit while OS-suspended or in
uninterruptible kernel work is not promised; the worker retains ownership.

Read BLACKBIRD, the original controller connection and actual helper/clock
source, Darwin SDK spawn/fcntl/poll contracts and their existing process oracles
before implementation. Write this subplan, public header, direct Foundation
probe and actual helper tests first; compile a nil/closed entry and observe
the required initialization fail. Then implement and run strict warnings plus
actual process tests: real helper initialized ACK/heartbeats/fence, stalled main
run loop while worker progresses, independently lost authority, malformed and
partial replies, stalled child/TERM-ignore, EOF/idle death, descriptor collision,
constructor launch deadline and exact owned PID absence after join. Signal only
unreaped Popen children; never probe or disturb unrelated apps/processes.
External-driver Stop tests show this control channel, not a physical human Stop
listener or quiescent OS effects. No CEF launch, Keychain, input API, model,
network change, fake clock, detsim or mutation work is introduced.

Independent source/process review follows green before root integration. Native
capture servicing/work limits and actual table/UI joins remain separate gates.

The initial ACK establishes the parent's live watchdog because its first write
can precede the helper's native runtime startup. The helper independently owns
its acceptance-time250ms lease. Later parent renewals conservatively start at
dispatch, and Stop leaves that deadline intact then makes heartbeat immediately
due. Delayed main-queue callbacks also check the continuously renewed watchdog;
an accepted ACK is historical control metadata, never a grant or proof of
quiescent input effects. The constructor alone defines startup timing; process
loading before that constructor is not measured by this budget.

Actual direct suite uses temporary unique binaries, the original helper and a
few fault peers. A separate small native process-entry fixture checks minimal
environment/private descriptor inheritance before an interpreter can alter
them. The exact owned app self-stops after initialization; driver observes its
T state and the independent real helper's Z state before resuming/reaping.
The main-loop-stall case observes worker fence7 and reap before main resumes,
and rejects a second accepted callback slot until the first main delivery.
Failed startup evidence is retained under ignored context/runtime when the
driver times out; the live unreaped parent is sampled before cleanup.

Availability diagnosis after root's closed-stdin failure: expose one bounded
static terminal-phase reason and bounded owned-child exit code. These contain
no path/run/page/unaccepted bytes. Record first known closure cause, preserving
it through final join/invalidation; distinguish configuration/launch/clock/
authority/initialization/live deadline/IO/canonical/child-exit phases. Retain
each actual probe stdout/stderr before test assertions so non-timeout failures
remain inspectable. Reproduce the focused closed-stdio case under actual compile
load; a green repetition alone does not explain the failure. Keep live lease
and reply limits unchanged while diagnosing. Source/process re-review follows.
Normal live-test authority revocation is timed from delivered positive start
callback, not merely worker connected state. A separate delayed-main case
intentionally exercises withholding when independent authority loss precedes
that callback. The TERM-ignore fixture signals handler readiness before the
UI invalidation measurement; the extra inherited-handle probe stays above2 so
it cannot refill deliberately closed stdio.

Root's diagnostic recheck isolated a synthetic Python idle peer that never
initialized before2s (not a real-helper descriptor failure). Replace all fault
peers with an original compiled POSIX fixture using independent fixed byte
offsets, no production codec. Ready/seen/sent markers prove the intended peer
phase was reached; malformed/partial tests must assert their static parent
reason plus those owned markers, not only nil. Idle exit waits for successful
UI presentation before releasing the peer, which keeps answering heartbeats
until that release. Run focused idle/malformed/TERM-ignore oracles; do not change
product startup or live budgets, and retain the older real-helper nil cause as
unresolved without matching evidence.
