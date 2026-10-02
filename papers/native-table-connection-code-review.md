# Native table parent connection review

2026-10-02. Independent BLACKBIRD review of the original `BSTableConnection`
Foundation/POSIX transport. The Rust table actor/evidence store was reviewed in
the preceding unit; this review covers its native parent, closed wire, and
owned child. It does not authorize a model endpoint, general DOM reader, OS
input, or establish the eventual CEF/UI/database join.

No remaining code blocker in this closed trusted-parent transport scope after
the corrections and independent 14-method process run. Reviewed production
`table_connection.mm` SHA-256:
`764d036ff72de4112f9e88b43b777b877df6a266e31dd2e3e7ad425e129a5557`;
header: `cf558488962d1b5c3b966eed9da85bd692edaf0c778390d01a915529083f66c9`.
No product source was edited by the reviewer.

## Findings

**NTC-01 — initialization could restore invalidated authority. Corrected in
source; independently checked at its two boundaries.** The worker could decode
an initialization reply, race `invalidate`, then unconditionally set
`connected = YES`. Its queued initialization callback was also exempt from
terminal invalidation. The owner now refuses delivery under the same flag lock
when invalidated, and checks invalidation again before publishing initialization
on main. Only validated Stop, table-close and shutdown acknowledgements retain
their deliberate terminal-ack exception. An ignored probe compiling the actual
class directly established that invalidation before delivery rejects without
setting connected, and invalidation before its queued callback withholds the
initialization success. This is a direct boundary oracle, not a claim that a
randomly scheduled race was reproduced.

**NTC-02 — transport deadline scope was overstated. Clarified.** The initial
plan said the two-second request deadline applied at every publication boundary.
The implementation ends that transport deadline at a complete validated response
frame, then checks accepted Stop generation and the actual saved data guard
again before main publication. The owner selected and documented that narrower
contract. A long-lived review can therefore survive a delayed main callback
while its real guard remains current. Main/UI assignment must still check the
saved boot ID and continuous deadline; wall time and timer delivery do not
substitute for that check.

**NTC-03 — real-service harness could cancel healthy close prematurely.
Corrected by the owner.** Its unconditional 2.6-second manual invalidation could
interrupt a correctly progressing review/commit/read/list trace before the
allowed four-second close response completed. The owner retained that failure
and changed only the real Rust trace to wait on actual shutdown acknowledgement,
with a seven-second finite fallback and ten-second driver timeout. The focused
corrected Rust/reopen/PID oracle passed; production source was unchanged.

## Source assessment

The API names the closed operations and uses generated native run identity and
global strictly increasing request IDs. One ordinary slot and one urgent Stop
slot can coexist; complete frames preserve their admission order and cannot
interleave bytes. Slots remain retained while callbacks queue, then release
before the callback can chain the next request. A Stop acknowledged while an
ordinary reply is pending changes the worker generation immediately; stale
ordinary content is withheld before main publication. Refusal preserves a
correlation ID where available and distinguishes `unknown` submitted outcome
from `not_submitted`; it does not manufacture a successful Rust reply or zero-row
effect.

Bootstrap replies require the original exact byte order. Table replies have
closed outer and nested variants, exact boolean/integer classes, bounded
identities, six field-state shapes, and a canonical recursive JSON round trip.
Review content remains an opaque string. The parent checks the supplied guard
locally and sends only Review to Rust; Rust independently reconstructs the
current review and compares the exact staging/version/content before approval.
Thus a local guard is a publication freshness check, not a fabricated private
approval capability.

The worker owns distinct private pipes, spawn and unreaped PID. Spawn sources
are moved above stdio, descriptors default closed across exec, stderr is an
explicit duplicate or owned `/dev/null`, and the environment is minimal. The
child's SIGCHLD disposition is explicitly reset so its own clock-child owner
can reap. Worker polling, deadlines, idle death, invalidation and TERM→KILL→reap
stay off the UI thread; the final blocking join belongs after the live UI loop.
The host must retain sole waitpid ownership with default SIGCHLD, no
SA_NOCLDWAIT and no competing child reaper. Child-disposition reset does not
repair a host that abandons or steals wait ownership.
PID metadata is not a reusable signaling handle. A sent response is drained
before ordinary reap so payload/LF split writes and buffered terminal ACKs are
not discarded solely because the child exited.

## Evidence and limits

The ignored actual-source decoder probe compiled with
`-Wall -Wextra -Werror`. It accepted a canonical Review with version
`18446744073709551615` and preserved exact UTF-8 content containing accented
text, emoji, U+2028, quotes, slash, backslash, LF and NUL. It rejected nested and
outer duplicate keys, a nested boolean/fraction, unsigned overflow, nested
unknown fields and noncanonical whitespace. Root arrays nested 512, 4096 and
30000 levels were denied without exception or process failure; these probes
exercise the actual Foundation parser, not a replacement decoder.

A canonical read containing all six legacy field states, absent legacy
intervals/fragments, UINT64_MAX attachment generation and INT64_MAX positive
node ID was accepted. Nested node booleans/fractions and signed-node overflow,
zero generation, integer `partial`, missing-with-node, empty-without-node,
single-candidate ambiguity, newline identity, half-present interval, duplicate
state tag and duplicate observation field were denied. Legacy absence is kept
absent; these decoding probes do not grant fresh observation authority to a
retained record.

Independent `python3 -u tests/table_connection.py -v` passed all 14 methods in
80.478 seconds, including an isolated pinned locked Cargo build in 15.91 seconds.
The ignored log is `context/review-controller-table/native-table-independent.log`.
It exercised actual Foundation/OS process ownership, live/fragmented canonical
replies, exact Review approval, terminal ACK delivery, concurrent urgent Stop and
ordinary slots, worker/main guard expiry, idle death, no-reply transport expiry
before manual invalidation, malformed/truncated/oversize replies, closed parent
stdio, unrelated inherited descriptor denial and child SIGCHLD reset. The fake
peer's initialize receipt establishes the intended malformed phase; direct
decoder probes separately establish the parser's specific rejection behavior.

The actual Rust child/clock/SQLite trace checked reviewed content against the
stored review, retained rows against native read output, saved boot/deadline
against the returned guard, dirty=0, exact clean reopen, and absence of both
original service PIDs. The independent run loaded the earlier 2.6-second trace
cutoff and happened to finish in time; the owner's corrected trace passed its
focused latest check in 27.918 seconds, including a cold pinned Cargo build.
No production source changed, so another full suite would add no new fault class.

An independent direct actual-class main-callback oracle checked a current real
guard before accepting delivery, blocked main beyond its saved deadline, then
required the queued callback to return `stale_guard` without Review content.
This isolates final callback expiry; the concurrent worker/UI fixture alone can
also fail at the worker boundary under slow scheduling. The compile-time-only
startup oracle stops the exact owned parent after deadline capture, before
worker dispatch/spawn, waits 2.2 seconds, then requires no child and no initialize
frame on resume. It does not establish a buffered-reply or mid-write pause case.

Earlier table harness runs reached initialization/Ping but missed the late main
timer. Another deliberately SIGCHLD-ignored-parent trace printed JOINED but its
driver timed out; the sample contained no call graph. Their causes remain
unexplained. The final SIGCHLD oracle observes the child's inherited default,
then restores the host's sole-reap precondition before exit. The old peer-driven
pause oracle failed to observe suspension and was replaced with the direct
startup boundary above. Later successful runs do not explain these failures or
the preceding control unit's unexplained real-helper initialization failure.
N3 availability acceptance and the CEF/UI join remain separate gates.

The suite demonstrates fragmented incoming replies and no-reply stalls, rather
than a forced saturated outbound pipe or partial-request-write oracle. Source
inspection establishes offset retention and finite transport deadlines there.
Urgent Stop cannot overtake an already partially written ordinary frame; this
unit claims no physical-input Stop latency or OS-effect quiescence. Native
TERM/KILL teardown reaps the owned Rust service, not an arbitrary descendant
tree; forced service death can bypass its clock-owner cleanup. The reviewed
clock producer is concrete and must not fork descendants retaining stdout.

References: [transport plan](../docs/plan/native-table-connection.md),
[closed Rust wire](../docs/experiments/controller-table-wire.md),
[preceding actor review](controller-table-service-code-review.md),
[native control parent review](native-control-connection-code-review.md).
