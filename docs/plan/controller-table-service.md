# Closed controller table service

2026-10-02. The reviewed SQLite library is useful only once the native parent can
stage, display exact review content, approve and reopen saved rows. This unit
connects that library to the owned controller child. It introduces no model,
Codex, export, network or input capability. Native AppKit integration follows
separately; only an explicitly configured owned fixture may supply source data.

One authority loop owns request ordering, Stop generation, the Store and opaque
approval handles. Dedicated bounded stdin/stdout threads do blocking framing.
One separate single-flight worker queries the existing owned native clock probe;
no pipe, native subprocess or SQLite wait occurs on the authority loop. Clock
paths and DB paths come from trusted CLI configuration, never request fields.
Every managed operation samples after its request arrives. Idle clock polling
continues while stdin/stdout stall; SQLite independently checks its own native
clock before irreversible writes. Stop requires no clock/IO and overtakes waiting
table operations, invalidating their captured generation before they can run.

Keep exact existing bootstrap replies. Table mode adds only closed versioned
scope/stage/revise/review/approve/commit/status/list/read/delete/close records, with
monotonic request IDs and object-only decoding. Scope must equal the configured
owned origin. Approved source records preserve all six states and native IDs;
the parent, not this protocol, establishes DOM grounding. Approvals return host
tokens mapped to the library's private handle, never deserialize a handle.
Same-content duplicate approval/commit reuses identity; changed review must fail.
Exact Review.content is the string the UI displays and returns unchanged.

Limit controller batches to two rows, six fields per row and 16 KiB serialized
batch; exact review content to 24 KiB. JSON escaping and envelope overhead must
still fit the existing 65,536-byte frame limit. Eight incoming frames, eight
pending requests/replies, one writer frame and one clock job are the maximum;
exhaustion fails closed rather than waiting on the actor. Malformed protocol,
clock failure, writer failure or stalled handoff terminates unsuccessfully,
stops preparation and leaves dirty recovery disposition. No automatic retry or
recovery purge is introduced. An explicit healthy close drains SQLite and marks
clean; EOF/transport loss does not silently invent that disposition in table mode.

The actor retains pending read/review replies until the writer is ready, obtains
a new actual clock sample, and revalidates the managed result and generation at
that byte-handoff boundary. A blocked previous write cannot make a queued result
fresh indefinitely. Once a frame's write begins, partial delivery is possible;
failure is reported as uncertain transport, never retractable bytes. Writer
stall supervision is conservative and bounded; main-process exit terminates
blocked IO threads without joining them. Required PublicationGuard replies expose the actual source/retained boot and
deadline for review/read/list; the native UI checks a fresh actual witness
before assignment and invalidates on expiry/activation. Legacy Source.fragment
and capture interval omissions preserve exact saved bytes, but new native
staging requires actual intervals and observed raw fragments; no guessed
defaults are allowed.

Direct red process tests precede code: unchanged bootstrap replies; actual child
stage/review/changed approval/duplicate commit plus independent SQLite rows;
clean native-clock child close/reopen; malformed closed input with zero rows;
real stdout backpressure while Stop rejects a lock-stalled preparation and
while idle expiry purges committed rows. Inspect real SQLite content/dirty
markers, not service acknowledgements alone. Then run the meaningful changed
tests and basic Rust checks once, followed by independent code review. Detsim,
mutants and higher tiers remain explicitly deferred by the operator.

## Correction sub-plan after independent service review

CT-01 is accepted: terminal actor exit kills Rust threads, but does not kill
separate clock OS children. Reproduce actual pending overflow with a configured
owned probe recording its exact PID and execing sleep, then require failed
controller exit plus disappearance of that exact PID. Add a transport-fault
case while the SQLite worker has its own active probe. Kill only recorded fixture
PIDs on red failure, never unrelated processes.

A small shared ClockOwner cancellation/active-query token spans the controller
clock worker and SQLite clock queries. Cancellation is atomic and nonblocking;
queries check it before spawn and inside supervision. A query's owned Child
RAII kills/reaps on all exits/unwinds before releasing its active count. Terminal
service cleanup cancels, denies future spawn and waits outside the healthy
actor loop for quiescence before process exit; never join blocked pipe threads.
If OS kill/reap cannot complete, remain terminal and non-admitting rather than
exit and knowingly abandon an owned child. Forced process termination cannot
run Rust cleanup and remains a separate native-parent safety requirement. The
owned original probe does not fork descendants; inherited descendant stdout
and arbitrary executable trees are outside this query contract.

CT-02 needs a precise provenance correction, not blanket exclusion: native price
projection legitimately retains the whole captured cell and node while multiple
literal candidates remain ambiguous. When a fragment is supplied, require every
nonempty candidate to occur literally within it; reject invented selection text.
Fragmentless alternatives stay explicitly unsupported as selected-source claims.
Require node_id's nullable key at native wire decoding to match the documented
shape, rather than silently interpreting an omitted key as null. Write direct
negative and legitimate-positive cases before code, run changed checks, then
return both findings to the same independent reviewer.
