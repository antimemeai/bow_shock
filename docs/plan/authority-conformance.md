# Authority, evidence and lifecycle construction

Implementation plan, 2026-10-01. This lane owns the ordering boundary shared by
grants, effect admission, durable evidence and retained-data lifecycle. It
implements the reviewed [authority/input contract](../design/control-and-input.md)
and [evidence/table contract](../design/evidence-and-tables.md), including
[tribunal](../../papers/design-tribunal.md) AD-1 through AD-5, NE-2, NE-4 and
BR-01. The native and bridge lanes own their actual platform/transport adapters.
This document plans future work; it adds no implementation or dependency.
The subsequent [operator direction](rust-basics.md) defers deterministic
simulation, mutation runs and heavier verification for the POC. Keep explicit
specification-derived admission traces and real DB/transport failure tests;
the simulator/model escalation below is future work, not a POC prerequisite.

## Build a useful slice before a framework

The first slice needs one owned session, one observed page, a locally staged
table and one reviewed atomic commit. It has no delegated input, network edits
or hosted export enabled. Implement the authority owner and SQLite writer just
far enough to make that slice correct under revocation, lost acknowledgements,
expiry and restart. Add the other power adapters when their vertical slices
need them. Do not build a general policy language, distributed coordinator,
event-sourcing platform or fleet harness first.

The owner serializes session epochs, per-power generations, approval/admission
and lifecycle fences. It does not serialize every browser event, block CEF
callbacks on storage, or hold a lock while waiting for a model or native effect.
An accepted effect is not the same event as a dispatched request, delivered OS
event, durable transaction or confirmed server effect.

## The smallest executable contract

For the basic POC, begin with explicit expected transition traces; the executable
model and deterministic scheduler described here are deferred. On escalation,
write a small, executable transition model
for the reviewed semantic records. Keep it independent of the host's reducer,
IPC codecs and SQL implementation: a straightforward state table with explicit
transitions and expected observations is enough. Use the repository's existing
Python standard-library tooling for this small independent model and trace
driver; this adds no dependency and stays separate from the proposed Rust host.
Do not adopt a formal-methods package merely for this model.
The model is a direct expected-behavior oracle, not a second production service.

Its initial finite state is two origins, two powers (input and table commit),
two host runs, one active operation per power, one staging version, one exact
commit identity, one derived child and one helper lease. Abstract payloads to
marker identities and scope sets. Add workbench/environment/export state when
those real adapters enter the plan; the cause-to-power matrix must already
name all six powers so adding an adapter cannot silently reuse input authority.

| Transition family | State/outcome to specify |
| --- | --- |
| Grant and proposal | Host-issued identities; session epoch/power generation; origin/document/activation scope; finite budget/deadline; rejected, reserved or known prior result |
| Revoke and restart | Explicit affected-power set; generation/epoch increments; unsent rejection; retained fences; no automatic renewal |
| Helper dispatch | Bound host run; finite local lease/liveness; fence-before-apply; ordinary enqueue versus narrowly attributed recovery release; posted-event uncertainty |
| Commit | Mutable staging version; immutable approved content identity; non-authority preparation; final serialized admission; pending/confirmed durability before row dispatch; actual DB success/unknown/conflict |
| Lifecycle | Parent-derived policy intersection; expiry/access denial; durable deletion intent; durable dirty-run boundary and restriction-unknown recovery; writer reconciliation; physical cleanup pending/complete |
| Evidence failure | Known gap/unhealthy coverage; operations that require durable evidence unavailable; human browsing survives |

Do not model all HTTP or pointer physics here. Model the point at which a
specific adapter may start an effect, what survives a particular revocation,
and what observation can legitimately establish its outcome. Input renewal
has an explicit `drain_established` precondition; the model cannot invent it.
Environment recovery may remove/reconcile resources, never apply a stale fault.
Workbench Stop rejects a held unsent request; response/body ownership has its
separate adapter disposition. An export may proceed only at the last controlled
handoff under a live scope. An admitted table commit may finish after ordinary
revocation, but deletion/required expiry denies and reconciles its persistence.
There is no single generic “cancellation succeeded” bit across these effects.

Check the useful small interleavings exhaustively, including revoke delivered
before the helper has seen its first operation. Use seeded generated sequences
for larger traces when the corresponding production transitions exist. Every
failed sequence reports its input trace and actual effect/row/payload state;
seeded replay belongs to that direct test, not a separate certificate system.
If maintaining the abstract model adds no sensitivity beyond a simpler explicit
oracle for a behavior, replace that part with the simpler oracle.

## Ordered construction tasks

| Task | Build/artifact | Dependency | Exit and direct evidence |
| --- | --- | --- | --- |
| A1: transition contract | Explicit specification-derived fault traces below; executable model deferred for the basic POC | Reviewed plan; chosen implementation tools after operator dependency discussion | Expected traces reject the original tribunal counterexamples; admitted-before-revoke and unrelated-power survival have explicit allowed outcomes |
| A2: local authority | One owner, identity/generation checks, reservations, per-power cause matrix and finite deadlines | A1 | Production transitions match explicit expected traces; repeated IDs return known results; stale/opaque origins cannot acquire authority |
| A3: exact table transaction | Staging/approval content versions, immutable CommitId, admission handshake and atomic rows + commit-result record | A2; native snapshot fixture; selected SQLite integration | Real database contains exactly the reviewed batch or zero rows; lost reply reconciles the actual hash/version; changed approval cannot obtain success for an old commit |
| A4: lifecycle and recovery | Policy lineage, access fences, durable deletion intent, affected-writer tracking, startup reconciliation and bounded cleanup | A3; real blob storage only if this slice uses blobs | A controlled marker cannot become usable after expiry or reappear after completed deletion; paused writer/crash traces inspect actual tables/blobs/writer inputs |
| A5: native effect admissions | Add input, workbench, environment and export adapters one vertical slice at a time | A2/A4; each adapter's measured capability contract | Fake-IPC tests establish ordering; real receiver/server/resource/outbound-payload oracles separately establish actual adapter effects |
| A6: retained product workflow | Reviewed commit UI, current per-power status, gap/unhealthy state and reconciliation outcomes | A3/A4 plus native observation | Human can observe, stage, review, commit and reopen the exact result; revoked/expired/unknown cases stay explicit without preventing normal browsing |

A1 is deliberately small and followed immediately by A2/A3. A4 is part of the
first persistent slice, not a later privacy cleanup. A5 is incremental: useful
observation/table work must not wait for packet/link confinement or Quartz
delegation. One owner keeps this invariant coherent; other lanes supply adapters
and narrow adversarial reviews rather than implementing competing authorities.

## Admission and crash detail to settle in each sub-plan

For the local table slice, create a unique host-run identity at startup and keep
all effect/export grants invalid until reconciliation finishes. Persistent
records are evidence of prior outcomes and retained-data rules, not reusable
permissions. A reserved intent whose dispatch boundary is unknown stays unknown
and consumes its budget; starting a replacement operation is not reconciliation.

At table admission, the owner checks the exact approval and all origin/use/
retention scopes against the live generations, then records that CommitId as
committing before the writer can begin. Ordinary revocation ordered first rejects
the whole batch; admission ordered first may complete the exact immutable batch.
Persist rows and the actual CommitId/hash/version/result in one DB transaction.
On restart or acknowledgement loss, query that record. If absent, establish that
the old writer/transaction is quiescent before declaring no commit. If present,
report its exact contents. Never generate a new identity to “retry” ambiguity.
For the initial local slice, keep a commit registry in the application DB, with
nonblocking preparation and admission states:

1. Freeze the reviewed content and dispatch a `preparing` record to a bounded
   storage worker. It is not permission to write rows. The authority loop keeps
   processing Stop, revocation and required expiry while SQLite/IO is unresolved.
2. On confirmed durable preparation, the owner rechecks current generations,
   scope/retention, deadline and exact approval. A revocation that won while
   preparing rejects the batch. A late/timed-out preparation result cannot
   dispatch anything or revive a cancelled request.
3. The owner makes the final serialized `commit_admission` decision and marks
   that exact CommitId irrevocably `committing_pending_durability`. Persist the
   admission asynchronously; do not block the owner. Ordinary revocation after
   this decision can stop other powers while this already-admitted commit finishes.
4. Hand off the row transaction only after admission persistence is confirmed,
   with the admitted immutable ID/content and current lifecycle fence. Failure/
   timeout leaves durability/dispatch unknown and no speculative row handoff.
   Required deletion/expiry still cancels/suppresses persistence under its stronger
   fence; ordinary revocation does not erase a prior final admission.

No authority loop, CEF callback or effect-owner control loop waits on fsync,
SQLite locks, pipe writes or a provider. Dedicated bounded IO workers may stall;
timeouts stop waiting, not native work. Outstanding preparation/admission counts
and bytes are finite; a stalled worker denies new dependent admissions without
stalling Stop/expiry. Reconcile all old writer work before replacing its owner.

On restart, prepared-only records are non-authority and never replayed; an
admission without a final commit result stays unknown until writer/DB quiescence.
Record the final atomic rows/hash/version/result under the same CommitId. Kill
the process before/after preparation, final admission, admission durability and
row dispatch; also hold a real write lock/IO stall while exercising Stop and
expiry at actual receivers. The durable registry is recovery state, not evidence
that rows succeeded. Select/test actual SQLite durability configuration first.

Required expiry/deletion is a stronger lifecycle operation. Immediately deny
application access, staging review, publication and export for its restricted
lineage, including affected writer-held inputs. Persist the intent/fence before
claiming processed deletion. A writer still before a safely cancellable boundary
rolls back; an irreversible or unknown transaction is reconciled and purged.
Do not return deletion complete until affected writers are quiescent and actual
restricted descendants are gone. If storage is failing, access stays denied and
the operation remains requested/pending/failed. On restart, reconcile this state
and required expiries before opening any usable read/export path.

Missing durable intent after a crash cannot prove that a restriction never
occurred. Before opening managed reads/writes in a run, durably mark that store
unclean and record the run/known affected partitions. If that marker cannot be
persisted, keep managed data unavailable. Mark clean only after writers quiesce,
all requested restrictions/policies are durable, and required lifecycle work is
resolved; a storage fault can never produce a clean shutdown marker.

An unclean/unprovable restart with potential lost restriction enters
`restriction_unknown`: deny the affected managed partitions, or the whole evidence
store if their set is unknown. Reconcile known durable obligations and present
the unresolved partition to the operator; missing intent alone cannot clear it.
Keep unknown data quarantined/unusable unless its obligations can actually be
reconstructed, or conservatively purge it through an explicit recovery decision.
New human browsing can use a fresh managed store; the browser profile is separate
and is not purged. This conservative first-slice behavior may withhold unrelated
authorized evidence after an unclean run; measure that recovery cost before
optimizing it. Test a failed fence write followed by crash and restored capacity
against actual query/export paths, alongside permitted retained survivors.

Choose policy/deadline clock semantics explicitly. Helper leases use the native
continuous clock and expire across sleep. Durable retained-data expiry must
survive restart and wall-clock corrections without silently extending a policy;
an uncertain expiry/recovery state denies use pending reconciliation. The sub-
plan must show how saved deadlines and clock uncertainty produce that decision,
rather than comparing a wall timestamp and assuming elapsed time is known.

Lineage may include a separately approved row retention policy that permits
survival of its source, or a structural pattern stripped of private examples.
Test those permitted survivors alongside required descendants. A policy fence
must not erase unrelated retained data or treat all revocation as deletion.
SQLite/blob deletion here means application cleanup of actual managed artifacts,
not forensic erasure from SSDs, backups or prior recipients. Evaluate WAL/check-
point/vacuum or encryption choices if the selected storage threat model requires
more; do not promise physical erasure from a logical DELETE.

## Direct red/green traces

Write the red oracle before the production path. A test-only seam may pause at
the authority-to-writer/helper boundary, drop a reply, reorder IPC or exhaust a
storage budget. The oracle then reads the real resulting effects. It must not
merely assert that a mocked “permission checked” function was called.

| Trace | Failure it must raise on | Direct green outcome |
| --- | --- | --- |
| Human editor input while a network pause is held | Input takeover invalidates unrelated workbench authority, or ordinary input keeps dispatching after its processed fence | Input rejects further ordinary enqueue; independently authorized workbench survives; Global Stop follows its broader disposition |
| Revoke reaches helper before delayed first apply | Helper treats unseen operation as exempt or forgets its fence on reconnect | No stale native application begins; helper retains fence and reports the rejected operation |
| Two valid intent submissions race on last action budget | Both effects start, or duplicate ID consumes/dispatches twice | One reservation/admission; repeated ID returns the exact known result; remaining budget is correct |
| Revoke origin after validation but before commit admission | Mixed-origin batch still writes, or silently drops one origin's rows | Zero rows when revocation wins; exact entire batch may commit only when admission won |
| Commit v1, lose reply, edit same staging to v2 | Old v1 returned as success for v2 or unreviewed duplicate insertion | Reconciliation identifies v1 actual hash/version; terminal identity/conflict requires a linked reviewed correction |
| Stall admitted writer; expire/delete lineage; release writer | Restricted marker reappears as usable, or deletion-complete is reported with a live resurrection path | Immediate access denial; writer reconciled/rolled back/purged; complete only after actual cleanup/quiescence |
| Persist deletion intent, crash before purge, reopen | UI, table query, model export or baseline exposes fenced marker during startup | Reconciliation/denied status before serving those reads; actual descendants eventually removed or visible cleanup failure |
| Kill host after native dispatch; reconnect duplicate intent | New helper automatically replays, or unknown execution is shown complete | Unknown consumes reservation; no automatic dispatch; new input waits for measured prior helper/held-state/drain conditions |
| Disk full during reservation/result/gap persistence | Effect requiring durable evidence starts or appears successful without that evidence | New dependent effects unavailable; capture unhealthy/gap visible; no invented durable commit; ordinary human browsing remains possible |
| Save/promote under restrictive parent, then close session | Save extends forbidden expiry or expired evidence becomes an empty/valid field | Disallowed retention transition rejected; authorized survivors and unavailable dependencies match actual managed artifacts |

On escalation beyond the current POC, run a deterministic schedule simulator
for admission/IPC/writer races. For the POC, retain process
kill/restart against the real DB, and real native/server integration tests for
effects outside the simulator. These attack different fault classes. Reusing
the production transition function as the simulator's expected result would
not supply an independent oracle. A simulated helper cannot establish native
input confinement, finite OS queue drain, entitlement behavior or remote receipt.

Fuzz untrusted typed-record/IPC decoders when they exist: unknown enum values,
oversized records, repeated IDs, stale run/generation tuples and truncated
messages must produce bounded reject/close behavior without acquiring authority.
Property traces also check that scope narrowing cannot admit an effect newly
denied by the narrower scope; an unrelated power change cannot mint permission;
and duplicate immutable commit requests cannot change persisted content.
Keep exact semantic oracles for expected permitted cases to catch accidental
denial, rather than celebrating an implementation that simply rejects everything.

Mutation testing follows a stable meaningful suite if it adds information about
its sensitivity. Candidate fault classes are removal of a generation check,
budget reservation, exact-hash comparison, fence or atomic commit/result write.
Run mutants only on an available fleet, never on the operator laptop, as
[Blackbird](../../BLACKBIRD.md) requires. Fleet access is a prerequisite; lacking
it is an explicit deferred technique, not permission to run laptop mutants or
block a useful slice. Review surviving mutants by the actual semantic fault
and improve/replace the direct oracle where warranted; do not build a test that
certifies another test.

## Completion and ownership

The lane is complete for a slice when its real admitted effects, durable rows,
retention survivors and recovery states match the reviewed contract under the
specific traces exercised; UI statuses match those outcomes; its adversarial
code review findings are integrated; and the next lane receives a documented
admission/result interface. Native capabilities still unmeasured remain disabled.
There is no claim that formal-state agreement establishes all browser behavior,
that application deletion erases remote copies, or that a trusted same-UID
coding agent is contained by this authority owner.

Use one task journal entry per substantive sub-plan/outcome and retain concrete
failing traces. Keep model and production interfaces compact enough to review
together. New power adapters extend the same authority owner rather than adding
one-off grant checks scattered across UI callbacks and native services.
