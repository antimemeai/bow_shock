# Design tribunal and dispositions

2026-10-01. The operator authorized the design phase. Under Blackbird, three
independent reviewers attacked component boundaries after the first complete
design set, rather than reviewing their own principal specifications. This
report records design decisions and their remaining empirical gates. There is
no product implementation, runtime conformance result or adopted dependency.

The [design entry](../docs/design/README.md) links the resulting specifications.
Independent reports preserve the original traces; this disposition table is the
current status of each claim after integration. Reports are not silently edited
to erase valid findings.

## Tribunal composition

| Reviewer lane | Principal target | Report |
| --- | --- | --- |
| Native-runtime researcher | Network/native effects and shared authority | [Native effects](design-review-native-effects.md) |
| Agent-connection researcher | Input authority, evidence and table lifecycle | [Authority/data](design-review-authority-data.md) |
| Network/tandem researcher | Bridge disclosure and native observation | [Bridge/observation](design-review-bridge-observation.md) |

All reviewed the integrated specification; the controls SVG was inspected in
the review and rendered/viewed locally by the root. The reviews identified 16
distinct issues: nine high-severity authority/disclosure gaps, six medium
contract gaps, and one medium native-work capability gate. Findings describe
possible traces in a draft, not observed exploits. The duplicated shared-epoch
issue was coalesced as NE-2.

## Integrated dispositions

| ID | Decision and direct consequence | Specification |
| --- | --- | --- |
| NE-1 high | Revocation fails an unsent request-stage pause, including new redirect hops; live-authority ordinary timeout may continue. Response delivery and body-owned cancellation are separate. Stop cannot submit a held request. | [Pause ownership](../docs/design/network-control.md#4-breakpoints-and-pause-ownership) |
| NE-2 high | One authority owner, session epoch plus per-power generations and explicit cause-to-power matrix. Content takeover/editor typing stops input; it preserves independently authorized human network work. Global Stop is broader. | [Transitions](../docs/design/control-and-input.md#authority-transitions) |
| NE-3 high | Reserve actual resources and intersecting selector/path scopes; initially reject overlaps/composition. Reservations persist through uncertainty/cleanup failure. Named-scope uniqueness and compare-restore alone are insufficient. | [Intervention lifecycle](../docs/design/network-control.md#7-intervention-lifecycle-evidence-and-cleanup) |
| NE-4 high | Helper-local host-run/generation fences reject delayed first arm/apply after cancellation. Stop requested/processed/restored are distinct; reconcile already-started native calls. | [Intervention lifecycle](../docs/design/network-control.md#7-intervention-lifecycle-evidence-and-cleanup) |
| NE-5 medium | Four concurrent diagnostic sends; 64 MiB total mutation drafts/inputs/working copies, including the pause sublimit. Reserve worst-case bounded backend memory before commit or reject capability. | [Network limits](../docs/design/network-control.md#3-limits-and-storage-policy) |
| AD-1 high | Finite helper execution lease/liveness, host-run fences and prior-helper quiescence before replacement grants. Fresh DOM alone cannot establish recovery. Posted-event drain and held state remain measured gates. | [Input delivery](../docs/design/control-and-input.md#delivery-and-the-unavoidable-race) |
| AD-2 medium | No ordinary enqueue after helper cancellation, with explicitly attributed bounded releases for executor-owned downs. Release can finish an effect; unsafe recipient/held state yields recovery uncertainty. | [Input delivery](../docs/design/control-and-input.md#delivery-and-the-unavoidable-race) |
| AD-3 high | Authority serializes irrevocable commit admission against revocation before DB writes. Revocation winning admission rejects the whole batch; an admitted transaction may finish later and stays visibly committing. Actual durable success comes from the DB record. | [Table commits](../docs/design/evidence-and-tables.md#page-family-patterns-and-table-commits) |
| AD-4 medium | Mutable StagingId/version differs from immutable CommitId bound to exact reviewed content. Terminal admission and a new linked correction prevent old-version success or accidental duplicate inserts. | [Table commits](../docs/design/evidence-and-tables.md#page-family-patterns-and-table-commits) |
| AD-5 medium | Derived artifacts inherit origin/class/access/use/expiry restrictions; explicit save/promote/commit reviews retained data and permitted extension. Expired dependencies alter availability, reviewability and baseline coverage; revocation differs from deletion. | [Evidence retention](../docs/design/evidence-and-tables.md#local-evidence-store) |
| BR-01 high | Disclosure owner rechecks grant/generation at serialized last host-controlled transport handoff. Drop unsent queues/retries on revocation; already handed-off bytes remain potentially received. | [Disclosure](../docs/design/agent-bridge.md#observation-and-disclosure) |
| BR-02 high | Conservative conversation ancestry; resumed/forked/compacted context must fit current use/destination policy. Unknown/out-of-scope history uses fresh authorized context or concrete expanded consent; provider retention is not erasure. | [Disclosure](../docs/design/agent-bridge.md#observation-and-disclosure) |
| BR-03 high | Guarantee enforced structured secret classes and reviewed projections, not universal absence of secrets. Sensitive/unknown regions and unenforceable modalities are withheld; explicitly approved views name residual echo risk. | [Sensitive projection](../docs/design/runtime-observation.md#representation-visibility-and-sensitive-data) |
| BR-04 medium | Unknown origins never match named grants; opaque consent binds exact frame/document/activation and is not reusable null-origin authority. Denied pixels require withholding or separately enforceable scope. | [Shared grant policy](../docs/design/control-and-input.md#grant-and-intent-records) |
| BR-05 medium | Complete host-run/attachment/document/activation/node-generation freshness tuple resolves from host evidence at admission and execution. Historical evidence never gains action eligibility from a new grant. | [ObservationRef](../docs/design/control-and-input.md#grant-and-intent-records), [runtime aggregation](../docs/design/runtime-observation.md#mixed-origin-and-oopif-aggregation) |
| BR-06 medium gate | Host copy/parsing/retention bounds are distinct from native capture work. One capture/coalesced refresh, native large-page/stop experiment and independent helper control path; unsupported full capture remains unavailable. | [Native work limits](../docs/design/runtime-observation.md#processes-threads-and-authority) |

No finding is dismissed as incorrect. Resolution here means the design now has
an explicit consistent contract or an honestly unavailable capability gate;
it does not mean a future implementation already satisfies it. The original
reports' direct oracles remain the scenarios to falsify the implementation.

Additional root integration corrections: expose Stop all in the actual SVG;
distinguish delegated-input state from other powers; describe adaptive profiles
as finite local OS-signal policies, not model-selected networking commands;
and inspect the installed Codex experimental schema. `dynamicTools` exists in
that export but successful registration remains a runtime gate.

## Review closure and next boundary

All three reviewers rechecked integration against their original traces and
recorded closure in their reports; no unresolved design contradiction remains.
The authority/data follow-up required two additional ordering decisions: prior
posted-event drain before input renewal, and required deletion/expiry taking
precedence over a stalled admitted writer. Both were integrated and independently
confirmed. This closes the design review at the contract level. Native unknowns remain: matched
CEF build/sandbox and servicing, OOPIF/origin/geometry mapping, capture overload,
native input routing and takeover horizon, constrained-agent deployment,
experimental Codex tools, response-body teardown, macOS confined packet/link
mechanisms and entitlement/process coverage, baseline semantics, and held-out
table/behavior evaluation.

The implementation plan may follow reviewed design; it must sequence direct
native capability experiments before enabling the corresponding claims. Actual
dependency adoption remains a discussion with the operator. No installation,
host-network fault, actuator test or product code is authorized merely by a
design disposition.
