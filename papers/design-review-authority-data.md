# Adversarial review: authority, input and evidence-to-table state

2026-10-01. Design review only; no product code, dependency adoption or native experiment. I reviewed the integrated [design README](../docs/design/README.md), [control/input contract](../docs/design/control-and-input.md), [evidence/tables contract](../docs/design/evidence-and-tables.md), their runtime/network boundaries, the project README and the [actual controls SVG](../docs/design/controls.svg). This is not an independent review of the agent bridge I authored.

There are five findings below. High means a missing contract can admit an effect after authority should have ended; medium means conflicting or incomplete semantics can misstate an operation or silently extend data lifetime. These are proposed failure traces, not observed implementation defects. The direct oracles are experiments to run after choosing coherent behavior, not additional machinery for certifying logs.

## AD-1 — Renewal after host failure does not require old executor quiescence

**High; missing recovery contract.**

[Authority transitions](../docs/design/control-and-input.md#authority-transitions) require at most one in-flight primitive per owned window, suspend grants after host restart, and permit renewal after fresh-state reconciliation. An ambiguous dispatch consumes its reservation and must not automatically retry. These are useful admission rules, but neither the record nor renewal condition establishes that an old helper can no longer enqueue events. A fresh DOM/window observation cannot establish that fact.

Trace: helper H1 has accepted a finite typing or pointer primitive; host A dies while H1 is between segments or awaiting a delayed cancellation message. The browser remains alive. Host B observes its current state, marks A's result unknown and suspended, and the person reviews a new grant. B dispatches a different primitive to H2. H1 then emits its next segment. No proposal ID was replayed, yet two executors act on the same window and old authority has survived renewal. Even termination of H1 does not remove its already-posted OS events.

The recovery contract must say what establishes loss of H1's ability to post, how an executor rejects stale host incarnations/messages, and when a replacement grant becomes eligible relative to the remaining delivery horizon and held-state recovery. This is separate from reconciling whether the old page effect happened. “Unknown consumes budget” cannot establish that there is no still-running old action. If quiescence cannot be established, the renewable state must remain distinguishable from a merely completed-but-unacknowledged action.

**Direct oracle:** an owned receiving application records actual events. Delay helper acknowledgement/cancellation between segments, kill the authority host, and attempt a fresh reviewed primitive under the replacement host. Observe old-helper emissions, held keys/buttons and posted-event drain at the receiver. A new primitive must not become eligible while the old executor can still create semantic events; any permitted already-posted drain must obey the chosen, visible recovery boundary. Do not use the new host's own admission log as the oracle for old-helper inactivity.

## AD-2 — The cancellation enqueue guarantee conflicts with recovery releases

**Medium; internal contradiction in the promised cutoff.**

[Delivery](../docs/design/control-and-input.md#delivery-and-the-unavoidable-race) promises “no further event enqueue after cancellation has been processed,” then requires releases of executor-owned held state under a platform recovery policy. It explicitly acknowledges that a release can finish an already-started action. The falsification table repeats the unqualified enqueue cutoff. Unlike the network document's recovery authority, this input policy does not define the exception's admission, endpoint or termination boundary.

Trace: an owned mouse-down has reached a button, cancellation is processed, and mouse-up has not been posted. Enqueueing mouse-up violates the literal cutoff and can cause the button's click; withholding it can leave held input state. If the window or native recipient has changed, the cleanup event may also finish a different interaction. The document recognizes these risks but gives two incompatible requirements to the implementation and its receiver-side oracle.

Choose a cutoff that distinguishes new semantic actions from narrowly permitted recovery events, and state how that recovery is authorized, bounded, attributed and reported when it itself finishes an action. A canceled execution cannot be presented as canceled-before-effect merely because its final event used cleanup authority. If a safe release recipient/ownership cannot be established, the contract must specify the suspended recovery outcome rather than assume a generic key/button-up is harmless.

**Direct oracle:** deliver mouse/key down to an owned receiver, process cancellation before release, and repeat with focus/recipient changes. Inspect the real down/up sequence and resulting page action. The selected contract must account for every post-cutoff event and actual effect, including a release completing the action; it must not satisfy the cutoff by omitting releases from the event count.

## AD-3 — Scope recheck and table commit have no defined shared linearization point

**High; authority/transaction race.**

[Table commits](../docs/design/evidence-and-tables.md#page-family-patterns-and-table-commits) recheck a staged batch's data scope if an origin is revoked before commit. They also require an atomic database write. The integrated README serializes authority changes through one owner, but does not state whether table authorization remains ordered with that owner's revocation while a separate database service commits. Atomic rows are not necessarily an atomic permission decision.

Trace: the person approves batch B, containing two origins. The authority service checks both scopes and sends B to the database worker. Before the worker commits, the person revokes one origin; the authority owner processes and acknowledges that revocation. The worker subsequently writes both origins' rows. Each local step can satisfy a pre-effect scope check and an atomic database transaction, yet the origin was revoked before commit. A different implementation could instead hold authority serialization until the transaction resolves; the current contract does not choose between these meanings.

Define the operation's commit point relative to scope revocation and the user's acknowledged revocation. Include queued/accepted transactions, multi-origin batches and an ambiguous database acknowledgement. The chosen rule must say whether B is rejected as a whole, has already committed under prior authority, or returns an uncertain state requiring reconciliation. Removing just the revoked rows would change the reviewed batch and therefore needs different approval; it is not an implicit safe fallback.

**Direct oracle:** pause the real database transaction at the authorization/write boundary, process an origin revocation, then release the transaction. Read the resulting table and commit identity directly. If revocation won the selected ordering, zero rows from that rejected batch may commit; if commit won, the UI must report the pre-revocation commit and its exact contents. Repeat with acknowledgement loss and a mixed-origin batch. A logged “scope checked” is insufficient.

## AD-4 — Mutable staging identity and commit idempotency disagree on revised content

**Medium; unresolved identity semantics.**

[Staging](../docs/design/evidence-and-tables.md#page-family-patterns-and-table-commits) permits changed staged batches, invalidates their previous approval, and binds the next approval to batch ID plus content hash/version. Commit reconciliation is then described as idempotent “by batch identity.” The document does not define whether that identity is a stable editable staging ID or the exact approved content version, nor what a second content version under an already-committed ID returns.

Trace: B/version 1 commits, but its acknowledgement is lost. The UI still offers staging B; the person corrects a value, reviews B/version 2 and approves it. Deduplicating only by B can return the version-1 commit as if the newly approved value was written. Treating version 2 as a fresh commit can instead duplicate rows or perform an unintended update. Rejecting the changed version may be correct, but requires a terminal conflict/reconciliation state rather than an apparent success for the revised batch. The existing duplicate/crash oracle does not resolve which identity it is checking.

Specify the exact immutable identity of an approved commit and the allowed relationship between an editable staging batch, committed content and a later correction. Reconciliation must return the actual committed hash/version and disposition. A known old commit cannot satisfy a new approval merely because the staging ID is unchanged.

**Direct oracle:** commit version 1, drop the acknowledgement, alter one value under the same staging ID, approve version 2 and reconnect. Inspect the transaction identity and resulting rows. The response must identify the exact version actually committed or reject/reconcile the conflict; neither duplicate insertion nor success for different reviewed content is acceptable.

## AD-5 — Saved staging and learned derivatives lack a defined retention transition

**Medium; missing data-lifetime contract, not a demonstrated export leak.**

[Evidence retention](../docs/design/evidence-and-tables.md#local-evidence-store) expires raw blobs, indexes and derived descendants “whose policy requires it.” Training examples stay within their retention/export policy; committed rows may retain provenance gaps. [Network storage](../docs/design/network-control.md#3-limits-and-storage-policy) expires chosen raw artifacts at session close unless explicitly saved. The SVG offers **Save draft · resolve later** and shows **partial table retained** after takeover. No shared rule defines which policy a staged value, learned pattern example, normalized equality token or baseline feature inherits, or what saving/promoting it changes.

Trace: a session-scoped diagnostic capture produces sensitive evidence; a derived field/equality feature is copied into staging or a baseline. The person saves the draft or promotes the baseline, then closes the session. Raw artifacts expire. One implementation treats derived data as ordinary durable rows/features and keeps it; another deletes descendants and leaves the saved draft or baseline apparently usable with missing inputs. Both can appeal to “whose policy requires it.” Revoking future observation/export is also not expressly distinguished from deleting retained artifacts. Input takeover should preserve useful authorized partial work, but must not silently decide the lifetime of all its descendants.

Define the retention/access choice for derived artifacts at creation and at save/promotion/commit, and the operation-specific meaning of revocation versus deletion. Decide how expiry updates staged review state, training examples and the availability/comparability of retained baseline inputs. The design can deliberately retain permitted aggregates or committed rows; it needs to identify that decision and the retained data, rather than imply that a raw-blob deletion removes every linkable derivative. Conversely, a missing source is not an empty field or a newly valid evidence-backed value.

**Direct oracle:** create a controlled sensitive marker in an authorized session, derive staging/training/baseline artifacts, then exercise session close, explicit save, origin revocation and required descendant deletion separately. Inspect the actual remaining database/blob artifacts and the user's saved-draft/baseline view. Every survivor must match its chosen policy; expired dependencies must produce the selected unavailable/gap/review state. Inspect outgoing exports as a separate leak oracle only when export is requested.

## Cross-document authority issue already covered by the other lane

[NE-2 in the native-effects review](design-review-native-effects.md#ne-2--global-epoch-and-human-takeover-have-no-consistent-independent-power-rule) captures the shared-epoch conflict. Physical content takeover, typing in the human workbench, provider disconnect and global Stop need distinct, explicit revocation sets. The input contract increments the host epoch, network operations refer to that same epoch, and independently continuing observation is intentional. The authority owner can remain singular; the unresolved issue is which grant generations are invalidated and how that is shown. This is one finding to coalesce, not a second independent copy here. The SVG's **Stop all** wording should be checked against the chosen set of input/network/environment/observation/export/table powers.

## Claims that need experiments rather than a design-defect label

The control/runtime documents already deny atomic focus-to-OS delivery, universal hit-target certainty, zero effects after physical takeover and universal human authenticity. Their receiver-side routing and takeover-horizon experiments bear directly on those claims. The bridge also distinguishes admission, delivery and observed effect; therefore I do not count the generic `Execution` result names alone as a false-success finding. Implementation must preserve those narrow meanings: a post-action DOM predicate can preexist or change independently, and cannot by itself prove server receipt, causality or exactly one remote effect. The SVG's **No action running** is a coherent illustrative state once AD-1 recovery has established it, not evidence that this state can already be measured.

The baseline contract correctly separates retries from new disclosure, keeps simultaneous categories, versions suppressions and requires incomparable/partial coverage to stay visible. Its direct mixed-change oracle should also include a shape-preserving replacement under an already-normalized field: an opaque high-entropy nonce changes into another opaque identifier with the same presence/type/length/equality behavior. Wire equality alone cannot establish that a new value is specifically an email-derived hash. Detection in that case depends on additional reviewed protocol/semantic evidence or must retain an unknown interpretation. This is an observability/normalization capability limit to expose in experiments, not a demand for a classifier that can infer the meaning of arbitrary bytes.

The project README accurately labels CEF, storage and native input as proposals and does not claim an implemented product. The SVG accurately shows a partial collection, a distinct ambiguous field, a reviewed commit path and no automatic resumption. No review finding here depends on converting those illustrative controls into product code during the design phase.

## Final recheck after disposition integration

2026-10-01. Rechecked the revised control/input and evidence/table specifications, integrated README, actual SVG and [tribunal dispositions](design-tribunal.md). This pass checks contract coherence against the original traces; it does not require an implemented helper, database or browser to claim that a design decision is resolved.

| Finding | Recheck result |
| --- | --- |
| AD-1 | Old helper future-enqueue trace resolved by finite helper-local lease/liveness, retained fences and replacement-host quiescence. One renewal condition remains unclear: drain of events already posted to the OS. |
| AD-2 | Resolved. The cutoff now concerns ordinary events, recovery releases have an explicit limited exception, and their effects cannot be reported as canceled-before-effect. |
| AD-3 | Resolved for scope revocation/Stop. Serialized irrevocable `commit_admission` is the authorization point; a winning admission may finish after revocation, with visible committing state and actual DB reconciliation. Required deletion/expiry has a separate unresolved interaction under AD-5 below. |
| AD-4 | Resolved. Editable `StagingId` differs from immutable, exact-content `CommitId`; admission makes the staging version terminal, corrections receive linked new identities, and reconciliation returns the actual committed version. |
| AD-5 | Derived-policy inheritance, explicit retention transitions, expiry reviewability and baseline availability resolve the original saved-derivative ambiguity. Required deletion/expiry racing an admitted writer still needs a rule. |
| NE-2, coalesced | Resolved for the reviewed physical-editor/takeover trace. Cause-to-power transitions and per-power generations preserve independently authorized workbench/environment work; session epoch provides broader Stop/restart invalidation. |

### Remaining AD-1 condition: helper death is not OS queue drain

The new input contract requires the prior helper to be terminated/quiescent and held state resolved before a replacement host can grant input. It also requires measurement of the outstanding delivery horizon. It does not expressly make that horizon's drain a renewal condition. A terminated helper meets the stated helper condition even when its complete, already-posted click or wheel burst remains queued; no unresolved held state need exist. A fast replacement grant can therefore start before those events arrive. This is not a renewed demand for zero effects after takeover: the already-posted residual is explicitly allowed, but its coexistence with a replacement primitive needs the chosen boundary.

**Remaining trace:** H1 posts the end of gesture G1; OS delivery is delayed; H1 terminates with no owned down left to release; the replacement host observes current page state and meets the helper/held-state conditions; G2 begins; G1 arrives amid G2. A fresh snapshot and proof of helper death do not establish absence of queued events.

State whether the measured backend drain boundary is included in input-renewal eligibility, or explicitly authorize and bound that overlap with truthful execution attribution. If a bounded drain cannot be established for the backend/workflow, renewal cannot assume the queue is empty. Apply the chosen rule whenever a prior primitive is uncertain, rather than relying on how long a person usually spends reviewing a new grant.

**Direct oracle:** delay receipt of an already-posted complete gesture, terminate the helper, and attempt renewal as soon as the stated helper conditions hold. Receiver-side events show whether renewal preceded the chosen drain boundary. The unresolved point is the ordering requirement, not whether its future native measurement has run.

### Remaining AD-5 interaction: required deletion versus irrevocable committing

The new lineage policy correctly forbids an expiry extension that a parent does not permit, and required expiry/deletion removes restricted descendants. The new commit policy allows an irrevocably admitted writer to finish afterward. Ordinary scope revocation is clearly ordered; required deletion or a non-extendable expiry is not classified as ordinary revocation and can conflict with the writer's retained snapshot.

**Remaining trace:** B inherits a non-extendable expiry E. Its review/admission happens before E, with a permitted retention choice that still ends at E. The writer stalls after admission. At E, the store deletes the source and currently stored descendants, updating staging availability. The writer later completes its atomic transaction from its immutable input and persists B's expired values. An explicit deletion during `committing` produces the same resurrection risk. Admission was authorized and the database write was atomic, but neither fact permits retention after E.

Define how required deletion/expiry includes queued or admitted writer inputs and final visibility/persistence. The design may serialize deletion with transaction completion, suppress persistence under a deletion fence, or choose another concrete rule; it must not acknowledge completed deletion while a known writer can subsequently restore the restricted values. If deletion is pending until reconciliation, display that pending state. This can preserve the deliberate rule that ordinary Stop/scope revocation does not undo an admitted commit.

**Direct oracle:** stall an admitted transaction, trigger required expiry or deletion, then release the writer and inspect the database, blob store, active writer inputs and reconciled UI. The restricted marker must not survive past an acknowledged completed deletion/required expiry or reappear afterward; any unresolved cleanup must remain explicitly pending. This inspects the surviving data directly rather than certifying a deletion event.

No other internal contradiction was found in this focused recheck. Native delivery, lease/drain capacities, exact DB crash semantics, retained-artifact inspection, grounding and normalization experiments remain empirical gates after these ordering choices are explicit.

### Closure recheck after the two ordering clarifications

2026-10-01, subsequent pass. The two remaining points above are now resolved as design contracts; their traces remain recorded rather than erased.

**AD-1:** replacement-host input eligibility now expressly requires the measured receiver-side already-posted drain boundary as well as prior-helper quiescence and resolved owned held state. The contract rejects helper death or fresh DOM as substitutes for queue drain, and makes delegation unavailable when a finite verified drain contract is absent. The delayed-G1/early-G2 trace now fails renewal eligibility. How a selected native backend establishes that boundary remains its direct receiver-side capability experiment, not an unresolved requirement to provide implementation evidence during design review.

**AD-5:** required expiry/deletion now explicitly supersedes ordinary scope-revocation grandfathering. Its lifecycle fence denies affected staging, commit and descendant data, including writer-held inputs; safe rollback is permitted, while irreversible or unknown writes must be reconciled and purged before usable publication. The fence remains until writers are quiescent and actual cleanup completes. A processed-deletion acknowledgement requires a durable intent/fence; storage failure stays visibly pending/failed with access denied. Restart reconciles deletion/expired policies before serving data. Expiry immediately ends availability, while physical cleanup can remain visibly pending. Consequently the stalled writer cannot resurrect an available expired value or justify a false deletion-complete acknowledgement. The table section explicitly links its irrevocable-admission rule to this exception, so there is no remaining conflict between the two contracts.

**Final result:** AD-1 through AD-5 and the coalesced NE-2 trace are resolved at the design level. No unresolved contradiction remains in this focused authority/data review. Native helper/routing/drain measurement, transaction and deletion fault experiments, exact retained-artifact inspection, grounding and normalization remain the stated empirical gates. No product implementation or conformance result is claimed.
