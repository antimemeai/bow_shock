# Scoped inference, native agent bridge and grounded extraction

Implementation plan, 2026-10-01. This lane implements
[the bridge contract](../design/agent-bridge.md) and
[learned table workflow](../design/evidence-and-tables.md), using the shared
authority/evidence service rather than inventing permissions inside prompts.
Nothing here adopts a model provider/SDK or starts an agent. Codex CLI 0.160.0
and the existing workspace Jev tool are available; local/hosted inference
remains provider-neutral.

## B1 — Closed contracts with a controlled provider

After authority/evidence types exist, define the host-owned observation bundle,
proposal kinds, correlation/generation/deadline and final-result records. Implement
one bounded JSONL decoder and closed type validation in the Rust host. Native
CEF and provider messages have different operation tables; there is no generic
pass-through. Serde's normal JSON behavior ignores unknown fields unless explicitly
restricted, so apply closed validation to every nested proposal type and reject
duplicate/ambiguous keys, unsupported variants, excessive nesting and oversized
records before admission. [Serde container attributes](https://serde.rs/container-attrs.html).

The native AppKit shell starts the owned Rust authority worker; that worker
owns provider adapters and later starts the Codex child. CEF lifecycle/control
messages use bounded inherited private pipes, not raw external browser endpoints.
Host/attachment generations remain explicit. The native input helper has a
separate independent stop/liveness channel so a busy CEF observation callback
cannot prevent cancellation. Renderer subprocesses never inherit authority/
provider/helper channels. Test actual descriptor inheritance and helper modes.

Implement a controlled fake provider **before** a live adapter. It supplies
partial/malformed/duplicate finals, stale request generations, deadlines,
disconnect/reconnect, provider-switch attempts and instruction-shaped page text.
Its output goes through the production decoder/admission service. Direct
fixtures count actual accepted actions/writes/sends, including zero effect on
rejected output; do not treat a rejection log as the effect oracle.

Initial IPC limits are proposed and tested: 64 KiB encoded control/proposal
records, one final candidate per request, one active request per task and bounded
display queues. Larger DOM data uses a separately bounded observation stream;
bodies/blobs use authorized identities and bounded chunks with cumulative byte
limits, never arbitrary file paths or unlimited base64 in control records.
Keep product logs out of protocol stdout; bounded stderr is diagnostic data.
Exhaustion cancels admissions and reports gaps rather than silently dropping
authority events and continuing. Native full-snapshot work remains its separate
capability gate.

## B2 — Disclosure before a real model

Implement projection policy and conservative derivative/history ancestry in
the shared evidence service. Selection precedes provider-visible history.
Unknown origins/sensitivity and unenforceable modalities remain withheld;
structured exclusions and explicitly reviewed projections govern supported data.
The transport owner rechecks live export generation/provider/account at the last
host-controlled byte handoff, serialized with revocation. Its cancellable queue
must not sit beyond that boundary inside a client library it cannot control.

Red tests block provider transport before handoff, revoke scope and inspect
actual received bytes after reconnect. A separate test begins handoff then
revokes; outcome must honestly report potentially transmitted/retained data.
Test descendant queues and old provider histories, including compacted marker
quotations and paginated unknown history. Unknown ancestry or a narrower policy
creates a fresh host-owned thread/context; `excludeTurns` cannot sanitize context.
Inspect actual outgoing DOM/AX/provenance/pixel/summary payloads against known
fixture markers and approved projection, including sensitive echoes.

Only after those tests choose a real inference adapter for an explicit local/
hosted data scope. The API/UI identifies placement, model/version, account,
capabilities and output limits. Local does not imply contained; hosted does not
imply permission to export all authenticated content. An unavailable provider
leaves human observation/staging usable. No automatic provider fallback.

## B3 — Codex stdio integration

Use the installed-version schemas already inspected in ignored context, with
their regeneration commands in [the design](../design/agent-bridge.md#codex-adapter-versioned-baseline-and-experimental-path).
Before enabling a real session, verify version, selected role/configuration,
model/account and supported handshake. Implement only initialize/initialized,
selected thread start/resume, turn start/steer/interrupt and required responses
for known callbacks. Correlate JSON-RPC request IDs, thread/turn/item/call IDs
and connection generation separately. The controlled provider tests run against
this production transport interface as well.

Start with final `outputSchema` proposals. Inspect exact turn completion and
final item, then validate/admit through the host. `expectedTurnId` mismatch,
late approval resolution, item IDs shared by distinct callbacks and unknown
history must exercise actual state transitions. Stderr/history persistence has
its own secret/retention policy. No thread resume revives a grant. Close and
host failure establish old child/process/callback ownership before replacement.

This adapter classifies ordinary shell-capable Codex as a **trusted coding peer**.
It is not the constrained browser-model deployment merely because final output
is typed. Approvals for Codex shell/files never become browser input/send/export
grants. Keep the peer's development environment separate in UI/configuration;
page evidence cannot call a generic App Server command/configuration/MCP method.
Actual enforcement of a constrained Codex deployment is a later explicit gate
over all ambient execution/IPC/tool paths, not a prompt or read-only-file setting.

Dynamic browser tools are optional after the baseline. Exported experimental
`dynamicTools` establishes a wire shape; a real opt-in registration/callback probe
must pass before enabling it. Unknown callbacks, duplicate resolution, stale
generation and stored tool descriptions yield no effect. Failure leaves the
outputSchema/conversation route usable; it does not broaden the tool interface.

## X1 — Deterministic grounded table, before learned generalization

Use the actual retained native observation from owned list/detail pages. Define
one reviewed schema and row boundary with locale/units/duplicate policy. Produce
bounded field candidates with source node/fragment/origin/visibility provenance.
A deterministic selector establishes capture/grounding/normalization without
requiring model accuracy to test it. All six field states survive the UI and DB.

The native table view shows source highlights beside rows, captured range and
schema/pattern versions. It stages immutable approval content and commits through
the shared exact-version transaction/lifecycle path. Test DB rows directly for
changed staging, duplicate acknowledgement, mixed-origin revocation, expiry,
writer stall and required deletion. Virtualized fixtures have a known complete
row set; initial collection reports only observed rows.

**Exit:** first useful human browse → observe → stage → review → commit/reopen
task, with partial/inaccessible/ambiguous cases and accurate retention choice.
This slice need not wait for live models, native delegation or packet faults.

## X2 — Teach families, then integrate bounded browsing

Learned rules are a small declarative vocabulary over retained, already scoped
observation records: host-generated repeated-group/row IDs, bounded relative
child paths, role/attribute equality predicates from an allowlist, grounded
field-candidate IDs and approved normalization-rule IDs. No arbitrary CSS/XPath,
JS, executable expression, recursive rule, network read or regex program is
accepted. Model text never selects an evaluator or native operation. Expanding
this handful of predicates later requires a reviewed sub-plan, not a general DSL.

Initial proposed limits: at most 64 rule nodes, depth 8, 200 rows and 20 fields
per staging batch, 16 KiB retained source per field, and 100,000 total record
visits per evaluation. Enforce visit/allocation limits inside each permitted
operator; evaluate on a bounded worker off the authority loop with one active
job and a finite queue. Exhaustion returns explicit truncated/unknown/no-match
evidence, no automatic commit and no additional DOM fetch. Wall-clock timeout
alone is not a work bound. Test permitted positives as well as deep/recursive,
instruction-shaped and combinatorial negative rules; inspect exact grounded
results and Stop processing while the evaluator exhausts its budget.

Supply positive demonstrations and adjacent negative page types. The person
names meanings and corrects boundaries; the model proposes versioned structural
rules and selects grounded field candidates/no match. Code copies the selected
source and normalizes it; generated values never become extracted facts.
Hold out page instances, changed templates, optional fields, hidden content,
duplicates and virtualization. Evaluate exact field/row grounding, incorrect
commits and review/correction time against reviewed fixture truth.

When native input is independently supported, connect one bounded scroll task
to this extractor: at most six gestures/two minutes, declared origins, no final
submission, one in-flight primitive. The authority checks fresh identity and
target; the executor creates its adaptive gesture; physical takeover stops
input while retaining permitted partial rows. Reacquire each new viewport/
document; avoid stitching incompatible fragments or claiming a complete site.

## X3 — Jev and ambiguous advisory choices

First compare deterministic candidates/rules with reviewed ambiguous extraction
and traffic cases. The existing constructed pilot is availability evidence,
not held-out calibration. Use the existing workspace client on nonprivate
fixtures without copying credentials; integrating a product API/SDK remains a
separate concrete adoption choice. Jev receives an approved redacted view and
retains model/probability/threshold version with each advisory result.

Choice needs a no-match/unknown alternative; independent Noul flags represent
coexisting change categories. Confidence cannot commit rows, mute a deterministic
new recipient, send traffic or alter an armed intervention. Test high-confidence
wrong/unknown and instruction-shaped observed content through the host, with
actual zero unauthorized effects. Compare held-out accuracy and review effort
with the deterministic arm before enabling semantic advice by default.

## Handoff

Each step adds one usable conversation/extraction capability and receives
independent code review against its direct oracles. Native readers provide
evidence and coverage; authority provides permission; the bridge provides a
candidate; table services stage/write exact reviewed data. No lane manufactures
another lane's success from confidence, a turn-completed notification or a
post-action DOM predicate that could have preexisted.
