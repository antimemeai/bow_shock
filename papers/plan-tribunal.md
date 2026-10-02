# Implementation-plan tribunal

2026-10-01. The operator asked to proceed from the reviewed design to an
implementation plan and its review. [The plan](../docs/plan/README.md) now orders
native/runtime, shared admission/evidence, agent/extraction and network work.
This tribunal tests construction dependencies and outcomes; it does not claim
an implemented browser, native conformance or adopted dependencies.

## Independent review

| Reviewer lane | Principal target | Report |
| --- | --- | --- |
| Native runtime planner | Authority, bridge and extraction | [Authority/bridge](plan-review-authority-bridge.md) |
| Authority/evidence planner | Native runtime and network | [Native/network](plan-review-native-network.md) |
| Network planner | Integrated sequence and bootstrap | [Integration](plan-review-integration.md) |

The three reports contain nine findings, coalesced into seven distinct issues:
four high construction/recovery gaps and three medium execution/scope gaps.
PA-1/PI-1 describe the same blocked authority owner; NN-3/PI-3 describe the same
missing complete-capability join. All findings are accepted. Their original
traces remain in the reports; none is replaced by a ceremonial proof layer.

## Integrated decisions

| Finding | Plan change | Direct acceptance evidence when implemented |
| --- | --- | --- |
| PA-1 / PI-1, high | Async durable preparation is non-authority. Recheck live scope at final serialized admission, persist admission asynchronously and dispatch rows only after confirmed durability and lifecycle check. Bounded IO workers never block Stop/expiry; unknown late writes reconcile. | Stall actual SQLite lock/IO while revoking other powers and expiring data; actual receivers/export/DB show prompt fences, zero stale dispatch and exact admitted outcomes. |
| PA-2, high | Durable unclean/run boundary before managed access; failure keeps store closed. Unclean/unprovable restriction persistence defaults to denied affected partitions or whole store. Missing intent is not absence of restriction; unknown partitions remain unusable/quarantined or undergo explicit conservative recovery. | Fail a real deletion-fence write, crash and restore capacity; actual queries/exports cannot reopen the marker. Test authorized survivors and measure conservative recovery cost. |
| PA-3, medium | Small declarative host-owned predicates over retained observations, explicit rule depth/nodes/row/field/visit bounds and worker isolation. No generated code, arbitrary selector/regex or implicit DOM read. | Allowed pattern positives remain grounded; recursive/deep/pathological rules exhaust/reject while real authority Stop stays responsive. |
| NN-1, high | N2a builds a control-only independent helper before N3. OS posting/listening stays N4; initial host identities/minimal A1/A2 precede control, without waiting for full DB work. | Actual native capture pressure and independent helper Stop/liveness processing before actuation; UI callbacks or simulated heartbeat do not substitute. |
| NN-2, high | N2 reader is fixture/development-only. N3 capture-work gates general human observation/P3, while its coordinate gate applies separately to input. Failed full capture retains manual browsing/qualified partial modes. | Growing native trees/text/OOPIF workloads show actual latency/memory and independent control. Host discard/timeout cannot promote unmeasured native work. |
| PI-2, medium | P1 contains receiver/control-only feasibility; no actual OS posting. First human-armed primitive occurs at N4 after minimal A2 and N1–N3. Root milestones and first sub-plan use the same sequence. | No-authority/stale-host bootstrap emits no ordinary production event; first allowed finite primitive is judged at actual receiver. |
| NN-3 / PI-3, medium | Full macOS acceptance joins all required workflows, including N7 finite existing-response-body edit, N8 packet-delivery and native-path cases, native keyboard/mouse/wheel, scoped inference/Codex and learned tables/baselines. Missing core capability is partial/blocked or a reviewed scope amendment. | Exact build runs each named actual peer/page/native/DB workflow. Synthetic response alone cannot satisfy existing-body editing; TCP proxy alone cannot satisfy required packet/path cases. |

The first useful human table and metadata workflows remain independent of
unavailable full capabilities. The plan neither enables unsafe features to
finish a demo nor drops a requirement merely because a capability matrix says
unsupported. Failure branches return a concrete adapter/topology/criteria
decision. Dependency candidates are presented for operator discussion before
download/build/product code, not implicitly adopted from quarantine.

## Recheck and remaining gates

All three reviewers rechecked the integrated changes against their original
traces and appended closure to their reports. No unresolved plan contradiction
remains. The new preparation/admission and dirty-run recovery states are explicit
inputs to the small independent model when it is built. Empirical work remains in the
ordered native tasks: matched CEF packaging/API/sandbox/servicing, native capture
work and frames/geometry, actual input routing/held-state/drain, provider handoff/
history, SQLite durability/failed lifecycle recovery, CEF composer cookie/retry
semantics, pause/body teardown, signed packet-filter/diversion scope and an owned
macOS path transition, calibrated behavior and holdout semantic extraction/alerts.

No runtime was downloaded or executed, no host network or input was changed,
no production dependencies were installed and no product code was written in
this planning turn. The next execution unit is the small matched native runtime
and owned fixtures after the concrete dependency discussion.
