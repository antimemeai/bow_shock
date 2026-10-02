# Closed native table connection

2026-10-02. One original Foundation/POSIX sibling of the reviewed bootstrap
connection joins the trusted AppKit parent to the reviewed Rust table service.
The parent supplies concrete executable/database/clock-probe paths and the exact
owned origin. This unit adds no CEF read, model endpoint, authority grant, input,
network or package. Existing bootstrap implementation stays intact. Service
CT-01/CT-02 corrections independently passed before real-service integration.

The header exposes explicit typed operation selectors only; no generic RPC.
startWithCompletion returns the original canonical initialized reply. The caller
polls table_status until Ready, then explicitly sets the configured origin.
Root owns that UI startup state machine, CMake and packaging. runId is generated
by the native parent before spawn and shared with the independent control-only
helper; stopGeneration mirrors accepted Rust Stop replies. connected is a
short-lock thread-safe getter cleared by the worker before notifying UI, so the
control helper can observe authority death while CEF/AppKit is stalled.

One worker owns spawn/PID, both nonblocking private pipes, write ordering,
continuous deadlines and actual reap. Normalize inherited pipe sources above2,
use close-on-exec plus POSIX_SPAWN_CLOEXEC_DEFAULT and only explicit child
stdin/stdout/stderr file actions. Reset SIGCHLD to default in the Rust child so
its ClockOwner retains sole reap ownership despite any GUI parent disposition. Minimal LANG environment; suppress SIGPIPE.
The native host must itself retain waitpid ownership: default SIGCHLD, no
SA_NOCLDWAIT and no competing child reaper. Resetting the child's disposition
does not make an ignored-parent lifecycle supported. Trusted paths name the
original no-descendant controller and clock probe; arbitrary descendants or
forced host termination remain outside this orderly ownership contract.
UI methods admit flags/one bounded operation and return without pipe IO, wait or
blocking close. Worker poll is finite, observes idle death and clears connection
before terminating the exact owned unreaped child, finite TERM→KILL→actual reap.
Final waitForTermination is only after the live UI loop has ended. Uninterruptible
kernel teardown may delay final join, never permit new work or hide disconnection.

Exactly one ordinary slot plus one urgent Stop slot may coexist. Globally
increasing positive request IDs are assigned at admission and complete frames
write in that order; Stop cannot interleave an incomplete table frame. Stop may
reach Rust while a preceding table request awaits its clock/SQLite worker. Each
slot remains owned while its one callback is queued, then releases immediately
before invocation so that completion may chain the next closed request; queued
callback work remains bounded by the two slots. Rejected admission invokes a local refusal synchronously on the calling
thread; accepted completions run on main. Guarded callbacks recheck native boot,
continuous deadline and accepted Stop generation before handoff. Root rechecks
again immediately before assigning UI content and clears on expiry/activation.
Two seconds supervise ordinary request/reply transport until a complete valid
frame; healthy table_close may use four seconds for its final SQLite drain.
Transport deadlines include queue/write wait and are checked before accepting
frames, independently of UI timers. After receipt, delayed UI publication uses
the actual PublicationGuard boot/deadline and accepted generation, rather than
a transport callback-age limit. A still-permitted exact review may remain valid
for human review after its transport has finished.

Decode the exact owned Rust wire: bootstrap field order/bytes unchanged; table
objects recursively sorted and flat closed variants. Parse then enforce closed
field sets, exact integer/boolean types and bounded nested native provenance;
canonical round-trip must equal original bytes to deny duplicate keys, lossy
numbers and unsupported serialization. Review.content is an opaque exact string
through display/approval; never parse/reencode it as the returned approval.
Read/review/list require PublicationGuard. Legacy retained optional provenance
may remain absent and must be shown unavailable, not guessed. Approve accepts a
retained guard locally and forwards only Review, matching corrected wire.

Older-generation data after an accepted Stop is withheld and its ordinary
callback retired. Correlation metadata survives where supplied; admitted outcome
may be unknown and never implies zero rows. Local failures use a closed native
withheld result or nil transport failure, never forge a Rust success. Root will
handle this state honestly and may query actual status later. No automatic retry
or reconstruction of private approval authority is introduced.

Direct red oracle precedes implementation: compile the actual connection class
with a test-only Foundation parent and owned fake peer; require closed canonical
bootstrap/table replies, unchanged Review.content, duplicate/type/unknown denial,
fragmented/truncated/oversize frames and actual bounded admission. Then test live
small replies, exact FD ownership, idle child death, partial/stalled IO, ignored
TERM, continuous pause expiry, main heartbeat and actual child disappearance.
A peer that stalls ordinary table handling must still receive urgent Stop in
strict sequence. Exercise stale guard and older-generation data withholding at
both worker and delayed UI callback publication; no fake clock or production
fault switch. A compile-time test-only self-stop after capturing the startup
deadline and before worker dispatch lets the OS oracle observe the exact stopped
parent, wait past two continuous seconds and resume it. That checks expired
startup before child spawn, with no buffered child reply claimed. Finally spawn the actual reviewed Rust service with an actual
native clock/owned SQLite path and check exact review/approval/commit, actual rows,
saved deadlines and clean reopen. Independent review follows green. Shared CEF
app/browser/keychain launch remains outside this unit and requires root's later
join/work gate.
