# Implementation-plan review: authority, bridge and extraction

2026-10-01. Independent native-lane review of
[authority construction](../docs/plan/authority-conformance.md),
[bridge/extraction](../docs/plan/agent-and-extraction.md) and
[the integrated plan](../docs/plan/README.md). The reviewer did not use its own
native-runtime plan as the principal target. These are counterexamples to
proposed construction, not runtime findings; no product code exists.

The plan usefully keeps exact durable DB results, actual recipient effects,
provider payloads and native queue behavior separate. Independent state-table
oracles, early native gates and first deterministic extraction are coherent.
Empirical unknowns do not themselves block plan closure when the native task
has a direct early oracle and an unavailable failure branch. Three changes are
needed before the affected units are implementable without contradicting the
reviewed design.

## PA-1 — High: durable registry admission can block every revocation

**Location:** authority plan, “Admission and crash detail,” says the owner waits
for a bounded durable admission in the same application DB *before processing
the competing revocation*. The owner otherwise promises not to block while
waiting for storage/effects. This is a real sequencing conflict: a timeout
around SQLite does not bound fsync or settle an asynchronously finishing write.

**Trace:** table writer W1 has an admitted row transaction and stalls while
holding the SQLite write lock. A different reviewed table commit C2 requests a
registry admission. The sole authority owner waits for that database write.
Global Stop arrives, followed by required expiry of W1's lineage. The input
helper's independent channel may stop native input, but the authority cannot
advance workbench/export/environment generations or deny the expired lineage.
A previously approved unsent export or paused request remains admissible under
the old generation while the owner is waiting. Alternatively, a newly posted
helper operation continues until local lease expiry, without the intended
prompt host fence. This is possible even with a small registry record and a
finite SQLite busy timeout; storage latency is a different fault class.

**Required plan change:** choose an explicit pending durable-preparation phase
that leaves the authority event loop responsive. Final commit admission and
writer handoff need a serialized live-generation/policy check after preparation
finishes; revocation/expiry can win while preparation is pending. A late durable
record is not permission to dispatch. Name pending versus irrevocably admitted
registry states and crash reconciliation, including persistence that timed out
but later completed. Do not “fix” this by calling the stall bounded or by moving
all cancellation into one special UI button; the shared authority must process
all affected power/lifecycle fences.

**Direct oracle:** hold an actual SQLite write lock and separately stall the
durable admission operation. Request C2, Global Stop and required expiry while
storage remains blocked. Observe processed host generations and actual native/
server/provider effects; no newly forbidden effect starts, restricted data
becomes unusable, and C2 cannot dispatch when the write is released. Crash on
each side of preparation/final admission and inspect actual registry/rows after
quiescent recovery. A mock “revocation processed” callback is insufficient.

## PA-2 — High: an unpersisted lifecycle fence disappears at restart

**Location:** authority plan, required expiry/deletion and startup reconciliation.
It correctly says immediate denial precedes durable intent, failing storage
leaves access denied, and startup reconciles the state before reads. The plan
does not identify how startup knows about a fence that never reached storage.

**Trace:** a retained marker M is usable in the DB. The person requests deletion
or a new restrictive expiry becomes required. The owner immediately denies M,
then disk-full/IO failure prevents the durable deletion/fence write. It reports
requested/pending/failed rather than complete, as specified. The process dies.
After capacity is restored, startup sees only the older permissive policy and
no deletion intent. Ordinary restart reconciliation opens M for table queries,
baseline use or export. The plan's runtime denial disappeared without any
operator decision. Already persisted expiry dates cover only the subset of this
trace where the earlier DB policy itself establishes the restriction.

**Required plan change:** state a concrete conservative startup rule for
restriction/fence persistence uncertainty. For example, establish a durable
run-health/clean-shutdown boundary before managed reads become usable, and on
unclean or unprovable recovery keep affected data—or the managed store if the
affected set is unknown—denied until lifecycle obligations are reconciled with
the operator. Any chosen mechanism must itself fail closed when its update
cannot persist; an additional best-effort file is not automatically a solution.
Distinguish requested, durable processed and complete, and never infer “no
restriction” from a missing record after an uncertain write. This is application
access recovery, not a requirement for forensic SSD erasure.

**Direct oracle:** fault the real fence write before any intent is durable,
kill the owner, restore storage and restart. Query/export the managed marker
through actual product interfaces. It remains unavailable or enters explicit
conservative recovery; neither a clean older policy nor a missing deletion row
permits silent reuse. Include the permitted retained-row survivor case so the
chosen recovery mechanism can eventually restore authorized unrelated use.

## PA-3 — Medium: learned structural rules have no executable bounds

**Location:** bridge/extraction X2. The model proposes versioned structural
rules and grounded candidates; code copies selected source. That establishes
fact grounding, but the plan never chooses the rule representation or bounds
its evaluation. Closed JSON validation in B1 establishes syntax, not finite
evaluation or absence of an implicit script/selector-program escape.

**Trace:** a proposed pattern is well-typed and versioned but contains a recursive
row rule, pathological regular expression, combinatorial selector traversal or
an expression whose implicit evaluator runs generated code. It is approved as
a learned family. Applying it to a large retained observation loops or expands
work without bound in the shared Rust host, delaying authority cancellation/
expiry and staging availability; an evaluator with page access could exceed the
reader contract. Copying only grounded values does not prevent either trace.

**Required plan change:** choose a small host-owned declarative rule vocabulary
over retained observation records for X2, with explicit operator allowlist,
depth/work/candidate limits and rejection on budget exhaustion. Arbitrary JS,
native commands, executable expressions and unbounded regex are unavailable.
Evaluate off the authority loop; a failed rule yields no-match/unknown and no
new DOM read or effect. This can be a handful of structural predicates, not a
general DSL framework. Expanding the vocabulary later is separately reviewed.

**Direct oracle:** feed instruction-shaped, recursive/deep and pathological
patterns to the real evaluator, then apply allowed patterns to known fixture
records. Inspect exact grounded results, bounded resource use and timely host
revocation processing under exhaustion. Permitted examples must still match;
merely rejecting all rules does not satisfy learned extraction.

## Boundaries accepted without additional findings

The trusted same-UID Codex role is explicitly distinguished from a contained
browser model. Typed final output cannot establish confinement and the plan
does not claim it does. History ancestry is conservative, unknown/compacted
context yields a fresh authorized context, and provider fallback is unavailable.
The handoff oracle distinguishes unsent bytes from potentially received bytes;
actual adapter integration must preserve that interpretation for local Codex
stdio versus hosted provider delivery.

The A3/A4/A6 dependency order keeps lifecycle in the first persistent human
table slice. A model is not needed to validate native grounding or DB semantics.
The fixture/deterministic selection arm is therefore independent of model
accuracy. Input/body/path gates are early and direct, and no simulator certifies
those native effects. The adoption proposal precedes actual downloads/builds;
there is no request for implicit binding, proxy CA or system-global networking.

The plan can close after integrating these three changes and rechecking the
traces. This review is not a demand for another model/testing framework, a
general coordinator or unsupported runtime guarantees.

## Integration recheck

The reviewer re-read the modified authority construction, X2 rules and integrated
milestones against all three original traces. **PA-1, PA-2 and PA-3 are closed
at the implementation-plan level.**

- PA-1 now separates non-authorizing asynchronous `preparing`, live serialized
  final admission, asynchronous admission persistence and row handoff. The owner
  keeps processing revocation/expiry throughout stalled IO; pending durability
  never speculatively starts rows. Ordinary revocation after final admission and
  stronger required deletion remain distinct. Prepared-only or uncertain late
  records do not regain authority after restart. Actual SQLite stalls and crash
  boundaries remain direct implementation cases.
- PA-2 now requires a durable unclean marker before managed access and clean
  completion only after all obligations/writers settle. Missing/unprovable
  restriction persistence on an unclean restart yields denied partitions or the
  whole managed store. The plan explicitly pays the conservative recovery cost
  and preserves ordinary browsing with a fresh store; missing intent alone
  cannot reopen the old marker. Actual failed-write/restart query and export
  cases remain necessary, rather than certifying a health-marker log alone.
- PA-3 now uses a small non-executable retained-record vocabulary, operator-
  enforced traversal/allocation limits, finite staging/source budgets and a
  bounded worker off the authority loop. No CSS/XPath/regex/code evaluator or
  additional DOM read is implicit. Positive grounding and exhaustion/Stop
  oracles cover usefulness and liveness independently.

No additional plan contradiction arose in this recheck. Numeric operating limits,
storage durability/clean-boundary behavior and actual transport/native outcomes
remain experiments or implementation obligations; this closure asserts none of
them has already passed. The explicit preparation/final-admission states must
be included in the small A1 model and production tests when that unit is built.
