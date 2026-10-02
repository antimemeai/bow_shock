# Native effects tribunal: network control and shared authority

Review, 2026-10-01. Read the integrated design README, all five specifications and controls.svg. Principal targets are network control and its boundaries with shared grants, input, agent disclosure and recovery. This review does not fix specifications, adopt dependencies or demand native implementation before the design can proceed. Findings identify contracts that need a disposition now; their direct oracles belong in the later implementation plan.

Disposition proposed: resolve the four high-severity contradictions/ordering gaps before approving the implementation plan; make the medium-severity bound explicit or restrict the initial capability accordingly. These are design findings, not demonstrated implementation vulnerabilities.

## NE-1 — Stop can transmit a request that has not yet been sent

**High. Proposed disposition: specify stage-specific revocation behavior; resolve before plan approval.**

[Network control §1](../docs/design/network-control.md#1-owners-and-invariant-boundaries) says recovery after revocation can resolve an owned callback but cannot create a new send. [§4](../docs/design/network-control.md#4-breakpoints-and-pause-ownership) defaults an ordinary inspection pause to “continue original,” including human Stop, editor disconnect and context change. [§5](../docs/design/network-control.md#5-human-edits-sends-replay-and-side-effects) separately describes Stop before submission as `not_sent`. These instructions disagree for a request-stage pause.

Trace: the browser prepares a POST; an ordinary human inspection breakpoint holds it before outbound submission; the person presses global Stop; epoch revocation wins; recovery calls continue-original under the §4 fallback; the server receives the POST. The callback existed before revocation, but the outbound effect did not. Calling this cleanup does not make it a release of an already-started effect. Response-stage continuation has a different meaning and must not be conflated with request-stage continuation.

Decide whether preauthorizing a breakpoint also explicitly authorizes this particular post-Stop send, or whether revocation must fail any request not yet submitted. The UI and `not_sent` result must follow that choice. Ordinary timeout with a live grant can remain a distinct continue disposition. Imported credentials, destination changes and subsequent redirect hops must obey the same cutoff.

Direct oracle: an owned endpoint counts receipts of uniquely tagged POSTs. Pause before outbound submission, race ordinary expiry and explicit revocation separately, and record the sole native resolver command. A `not_sent` or revoked-no-new-send outcome must correspond to zero server receipts. If the chosen product contract permits a Stop-time release, the UI/event must explicitly report that effect instead.

## NE-2 — Global epoch and human takeover have no consistent independent-power rule

**High. Proposed disposition: define a cause-to-power transition matrix and grant-generation semantics; resolve before plan approval.**

[Control/input](../docs/design/control-and-input.md#authority-transitions) increments the host authority epoch on physical keyboard/pointer takeover and suspends active grants on disconnect, focus/document change and other causes. [Network control §1](../docs/design/network-control.md#1-owners-and-invariant-boundaries) makes independently authorized NetworkGrants refer to that same epoch and rechecks it before effects. [§4](../docs/design/network-control.md#4-breakpoints-and-pause-ownership) also resolves held pauses on takeover. Neither specification says whether ordinary human traffic-panel editing is an input-only takeover, a global network revocation, or an operation that preserves the network grant across an epoch increment.

Trace: a human arms a response-edit breakpoint and an input task; the response is held; the person clicks Traffic and starts typing the replacement; physical input increments the shared epoch and triggers the pause takeover disposition; the original response continues or the exchange fails before the edit can be committed. Even without a delegated gesture, a literal reading treats the physical editor input as takeover. An alternative implementation preserves the network grant and pause, but then its old epoch cannot pass the documented current-epoch check. The same ambiguity affects a human-armed environment profile when the provider disconnects and an intentionally detached diagnostic send when an unrelated renderer dies.

Independent authorization powers do not require independent authority owners. They do require a defined revocation set: distinguish global Stop from taking content input back, diagnostics editor activity, provider changes and target-specific invalidation. If one global epoch is only a serialization revision, say how unaffected grants stay valid and how an operation is bound to its own grant generation. No implicit rebinding of a revoked operation is acceptable.

Direct oracle: hold one request/response edit, one input grant, and one disjoint detached diagnostic operation. Exercise physical editor typing, content takeover, provider disconnect, frame replacement and global Stop. Assert the agreed power-specific state transitions, exactly one pause disposition, and actual server effects. Human editing must have a coherent path to commit its still-authorized draft; global Stop must not silently preserve revoked effects.

## NE-3 — One profile per named scope does not prevent overlapping resource ownership

**High. Proposed disposition: reserve/conflict-check actual affected resources and intersecting scopes; resolve before plan approval.**

[Network control §7](../docs/design/network-control.md#7-intervention-lifecycle-evidence-and-cleanup) claims one active profile per scope avoids overlapping restoration ownership. [§6](../docs/design/network-control.md#6-environment-controller-and-os-capability-tiers) permits different scope types, including verified process group and owned network topology. Different named/type scopes can cover the same resource or traffic path. The existing atomic compare-and-restore condition does not solve two active Bow Shock owners using the same resource value.

Trace: profile A for process group P sets a session-owned topology's shared delay resource from 0 to 100 ms. Profile B for topology N, containing P, also sets that resource to 100 ms. The scope keys differ, so the stated one-per-scope rule admits both. A expires, observes current 100 ms equal to its last applied value, and atomically restores 0 while B remains active. Both mutations are individually conditional, but A has removed B's effect. If B chose another value, A can instead leave a conflict and B can later restore A's expired value. Two independent new classifier resources can also unintentionally compose fault intensity on intersecting flows.

Define conflict admission over actual resources and selector/path intersections, not only the profile's display scope ID. The initial design can reject overlap rather than invent a composition framework. Reservation must cover applying, active, effect-unknown, restoring and cleanup-failed states; uncertainty is not a free scope.

Direct oracle: use two differently named overlapping owned scopes, identical and differing parameter values, with controlled application/expiry order. Inspect actual owned resources and receiver-side latency/fault counts. The second profile must be rejected under a no-overlap policy, or a reviewed composition owner must retain B's intended effect until B ends and restore the original baseline once.

## NE-4 — Revocation lacks a helper-side cutoff for delayed arm/apply messages

**High. Proposed disposition: define effect-owner cancellation ordering and recovery tombstones; resolve before plan approval.**

[Network control §1](../docs/design/network-control.md#1-owners-and-invariant-boundaries) checks authority immediately before effects; [§6–7](../docs/design/network-control.md#6-environment-controller-and-os-capability-tiers) permits a helper to execute an armed schedule locally and requires restoration after Stop/disconnect. The helper lifecycle does not specify how an old arm/apply message is rejected after newer revocation/restoration, or when Stop is acknowledged relative to helper cancellation. The input design explicitly states its enqueue cutoff and residual delivery horizon; the environment path needs an equally truthful boundary.

Trace: host authorizes profile operation O at epoch e and queues helper arm/apply; the message is delayed; global Stop advances authority to e+1 and requests restoration; the helper sees no installed resource and reports restored; the old O message later arrives and installs its finite fault. Its original deadline has not expired. Operation-ID deduplication does not help when this is the first delivery of O. Host-side pre-dispatch validation and an independent expiry do not establish the authority at native application time.

Specify helper-local operation/generation state, ordering of cancellation against scheduled effects, rejection of delayed/reconnected pre-revocation messages, and what happens to an already-started native call with uncertain completion. Preserve the distinction between Stop requested, cancellation processed and resources restored. A narrowly scoped recovery authority can remove/reconcile effects; it cannot authorize a stale application. This does not require an impossible zero-latency Stop promise.

Direct oracle: a controlled helper transport delays O, delivers revocation/restoration first, then releases O; also disconnect during an already-started native application. Inspect actual resources and tagged receiver traffic after the claimed cancellation/restoration point. No new application may begin after the effect owner processes the revocation fence; ambiguous in-flight effects must be reconciled and not labelled restored prematurely.

## NE-5 — Per-operation upload bounds leave aggregate diagnostic memory/admission undefined

**Medium. Proposed disposition: bound concurrent committed diagnostic operations and total pinned mutation bytes.**

[Network control §3](../docs/design/network-control.md#3-limits-and-storage-policy) bounds observational live memory, pause count/edit retention, and each upload/replacement body. [§5](../docs/design/network-control.md#5-human-edits-sends-replay-and-side-effects) allows independent new sends/replays, with their whole operation inputs pinned. No stated aggregate admission bound covers upload inputs, encoded/decoded working copies, and concurrent non-pause diagnostic sends. The one-primitive-per-window input limit does not cover these distinct human powers.

Trace: the human commits many distinct 8 MiB isolated-client requests while the controlled peer stalls reading uploads. Each operation meets its individual size/deadline and does not occupy a pause lease. All retain input and potentially re-encoding/client copies simultaneously; the 32 MiB observational limit and eight-pause limit do not constrain that sum. A 256 MiB stored-body budget is not a bound on transient/pinned sender memory or on client concurrency.

Specify an aggregate mutation-input/working-buffer reservation and concurrent-send admission limit, including encoded and decoded representations and client-library copies where controllable. Disk exhaustion and pressure must reject new admissions without discarding an active operation's exact committed input or consuming the recovery reserve.

Direct oracle: bounded native fake clients stall N known large uploads and body transformations. Inspect successful admission count, pinned/working bytes and recovery responsiveness while exceeding the declared aggregate limit. Rejected admissions must have zero server submission; previously admitted operations must retain their exact inputs and finite teardown.

## Coherent gates retained, rather than blockers requiring implementation now

Unavailable macOS packet/link confinement, native target/session support, process/worker attribution, body-stream termination, credential/cookie semantics, and Linux compositor routing are honest capability gates. The design already rejects unsupported selectors, host-wide substitutions and body-edit adapters without a tested bounded recovery path. These do not require a working product binary before tribunal approval; they require the future plan to keep the capability unavailable until its direct oracle passes.

The control-channel exemption is stated as a lifetime invariant, not merely a promise about one observed socket. A backend that cannot preserve it must remain unavailable. Its existing direct oracle should include provider reconnect/new flows, route/address changes and shared transports: an exemption may reduce browser-experiment coverage, which must remain explicit. No static destination-name exemption or process label alone establishes that invariant. This is an edge case of the existing capability gate, not a separate demand to implement native routing before reviewing the design.

The response-body ownership warning is coherent: taking the original stream forbids unchanged continuation, and shutdown must serialize with adapter-owned acquisition. The exact transition when ownership becomes irreversible and ambiguous take-body acknowledgements should be included in that adapter's existing termination oracle; this review does not manufacture a second platform blocker from an already acknowledged gate.

The trusted coding-agent same-UID limit is also explicit. The design does not falsely claim that a private native pipe confines ambient shell powers. Table commits independently recheck staged data scope, disclosure happens before provider history creation, and the controls SVG shows a suspended input task with retained partial evidence. Those are consistent with independently scoped observation continuing after content takeover, provided NE-2 defines which powers actually survive each authority transition.

## Final integration recheck

Rechecked the revised network-control contract, shared authority cause-to-power matrix, helper/input boundaries and tribunal dispositions against the original traces. This is design closure, not runtime conformance evidence.

| Finding | Recheck result |
| --- | --- |
| NE-1 | Closed in design: revocation fails unsent request-stage and redirect-hop pauses; live-authority timeout and already-submitted response delivery are distinct. `not_sent` requires actual adapter evidence. Global Stop is explicitly not a firewall for unrelated ordinary page traffic. |
| NE-2 | Closed in design: session epoch plus per-power generations preserves human editor/network authority during input takeover or provider loss; affected context loss and global Stop have explicit wider transitions. |
| NE-3 | Closed in design: actual resources and intersecting selectors/paths are reserved; overlapping named scopes and uncertain reservations are rejected through restoration/reconciliation. The identical-value restoration trace cannot be admitted. |
| NE-4 | Closed in design: helper-local host-run/generation/operation fences reject delayed first application after cancellation; requested/processed/restored remain distinct and in-flight native calls require reconciliation. |
| NE-5 | Closed in design: four committed diagnostic sends and a 64 MiB aggregate mutation budget cover drafts, inputs and working/adapter copies, with the pause budget included. Unbounded backend allocation cannot advertise the capability. |

The revised exemption also explicitly spans reconnect/new flows and shared transports. Body-stream ownership/teardown, native cancellation horizons, actual allocation control and platform confinement remain their existing measured capability gates. The revised contracts do not require those experiments to have run before design approval. I found no unresolved original trace or new cross-boundary design contradiction in this recheck; the original direct oracles remain required when the implementation plan enables each capability. No specifications were edited by this recheck.
