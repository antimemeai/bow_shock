# Controller scoped agent proposal review

2026-10-02. Independent review of the controller-owned Codex0.160.0
proposal/export unit, its written plan, original installed protocol schemas and
actual controlled-child oracles. Native startup/wire/panel/CEF joining are
separate reviewed units. No product edits, actual inference or CEF launch by
this reviewer.

**Accepted for the closed scoped proposal service. All four findings are closed
by source correction and direct independent recheck; no remaining blocker.**

This includes the subsequent installed-runtime metadata compatibility correction
below. Actual metadata readiness is earned; actual structured inference and the
native human-review/Save join remain separate gates.

The intended boundary is narrow: an exact current unapproved Review authorizes
selected existing fields for one objective, account/model destination and native
deadline. The worker copies those fields into one fresh ephemeral thread. Final
JSON can select host candidate IDs or no-match; the host reconstructs retained
values and provenance. It cannot stage, approve, commit or supply new values.
Source reconstruction and original review identity are checked by the sole
authority; actual clock queries stay outside the small revocation lock and each
nonblocking export chunk holds that lock. Direct Child kill/reap precedes worker
quiescence. These are trusted-peer/direct-child properties, not containment of
Codex tools, ambient configuration or arbitrary descendants.

## Findings

**CA-01, medium — invalid phase types became legacy null-phase finals.**
The original parser used `as_str()` so boolean/array phase values collapsed to
the supported absent/null phase. The owner executed a controlled child with
`phase:true`; it reached `candidate` instead of `failed`, retained in
`context/review-controller-table/agent-phase-red.log`. Parse absent/null and
the known strings explicitly, reject all other types, and compare the terminal
summary phase with the completed item. Terminal success also needs explicit
`error:null`; missing error must not silently appear successful. The latest
source has these corrections. This reviewer independently reran actual
`phase_bool` and `missing_error` peers: both failed with null proposal, clean
exit, zero actual SQLite rows and all recorded owned PIDs absent.

**CA-02, medium — an empty summary could attest an unrelated final.**
The original summary loop vacuously accepted `itemsView:"summary",items:[]`
after an item/completed message. The owner independently isolated that trace:
it reached `candidate`, retained in `agent-empty-summary-isolated-red.log`.
Pinned0.160.0 summary semantics require exactly one matching final agent item;
the legitimate `notLoaded` view has no loaded items. The latest source now
distinguishes exactly one summary item from zero notLoaded items and checks
id/text/phase. This reviewer independently reran the actual empty-summary peer:
failed/null proposal, clean exit, zero actual rows and owned PIDs absent. The
three focused final-shape rechecks are retained in
`context/review-controller-agent/final-shapes-green.log`.

**CA-03, medium — delayed status changed its task identity.**
`Gate::AgentStatus` carried no task identity and recomputed the latest task at
publication. This reviewer earned an actual child/stdout trace with six bounded
large A status records, then cancellation of A and start of B while stdout was
blocked. On drain, old A request319 returned B task`agent-321`, state`running`,
instead of A or an explicit retired/unknown outcome. B export progressed within
527ms, and clean controller close/exit plus an independent SQLite query showed
zero rows. The trace is in
`context/review-controller-agent/status-correlation-red.log` and its preserved
run directory. Capture the logical task identity even for a null-task query;
before guarded publication, replacement must return `unknown_task`, never B.
The owner corrected the gate to carry a captured task ID. The same independent
actual stdout trace is green: A`agent-145`/B`agent-167`, queued A request165 now
returns `agent_error/unknown_task`, no old reply adopts B. B export progressed
within211ms; clean exit/zero actual rows also passed. The green is retained in
`context/review-controller-agent/status-correlation-green.log`. Source captures
the current logical task even for a null-task status query.

## Evidence and remaining scope

Reviewed owner controlled suite final nine-method green in
`context/review-controller-table/agent-service-final.log`: selected/excluded
markers, final/no-match and pre-ACK notifications, foreign IDs/unknown fields/
duplicate JSON/conflicting finals/direction-confused callbacks, Stop before
handoff and after full handoff, delayed actual clock denial, original review/
approval fencing, changed account/effective policy and actual native expiry.
Each clean fixture independently queries real SQLite for zero automatic rows and
checks recorded owned PIDs are absent. The earlier concurrent-host pre-main
startup failures are retained separately; serialization qualifies one owned
host, not simultaneous startup load. No timeout was relaxed to make a protocol
fault pass.

Strict JSON retains exact integer identity, rejects duplicate keys before map
collapse and bounds frame/depth/total records. Client result IDs cannot satisfy
method/id server callbacks; unsupported callbacks close/reap without approval or
auth. Cached metadata is asynchronous; fresh proposal setup rechecks version,
selected runtime home, measured account reference and effective model/provider/
cwd/approval/read-only/ephemeral settings before source bytes. Account reference
is a measured destination signal, not authentication against a hostile same-UID
peer or model entitlement. Ordinary CLI settings and outputSchema do not prove
tool containment.

This reviewer independently reran the two distinct fault oracles added after
that suite. In9.33s, the real Unix socket receive buffer was reduced, the owned
peer recorded an actual prefix without newline, and host status proved both
`partially_transmitted` and still `running` before Stop. Stop returned within
the original one-second assertion; the task retired canceled/partial, no complete
export appeared, real rows remained zero and owned children were absent. In6.20s,
the actual host stdout reader closed while an exported turn was still running;
the controller failed its writer, exited unsuccessful, and every recorded owned
provider PID was already absent. Real rows remained zero. The independent logs
are `context/review-controller-agent/private-writer-independent.log` and
`terminal-stdout-independent.log`. This attacks partial private input saturation
and terminal output failure, separately from a peer that stalls only after
consuming the entire export.

The reviewed production source SHA256 values are:

| File | SHA256 |
| --- | --- |
| `agent.rs` | `eeb5f7ce2f1a36180efd73aa9080f9623c1a5061a608833ee36bb25238cbb18e` |
| `agent_transport.rs` | `6cf84bec2770fc9aa4716d5e0bb1b6790b86df2cb204b09f152faad38d29f287` |
| `service.rs` | `192df7e6774afeb7d1dfb950f1570d80f28b9c0a477d3787665013a281bba9c0` |
| `protocol.rs` | `275a6cef2e85923a226f9d91d77bf1da591e6d09f454048967b880ae0f3e9669` |
| evidence `lib.rs` | `2f8ef45e679b4a5721368ae0823669694c179884e22c9be62af5df03e31bd170` |

The owned clock must not fork arbitrary descendants retaining output. Forced
controller death bypasses cleanup; there is no arbitrary process-tree or
hostile same-UID containment claim. The per-chunk clock query/100ms freshness
and deadline headroom deny delayed results; they are not an atomic OS
clock/write primitive across arbitrary suspension between the final check and
syscall. Controlled hosted-peer protocol compatibility is earned here; actual
model entitlement/structured inference and the native human-review/Save join
remain root's subsequent oracles. The owner still runs final affected basics
and tracked regression consolidation before construction is landed.

## Installed-runtime metadata compatibility correction

Actual first-join metadata returned unavailable before any source handoff. A
metadata-only diagnostic and this reviewer's independent socket/selected-env run
found two closed allowlist omissions: stable optional outer `emittedAtMs` and
the runtime-serialized `account/read.workspaceRouting`. The earlier fixture
omitted both and therefore did not qualify these real protocol shapes. This is
an availability finding; failure closed before page bytes, not an export bypass.

Pinned stable notification schema/source require an optional signed int64
emission timestamp. Experimental account schema/source define a precise routing
object which is serialized even when experimentalApi is false; the outbound
filter does not strip this account result. Details and sanitized independent
actual observations are appended to the preflight report. The observed ordinary
route is HTTPS chatgpt.com/NO_CONSTRAINT and selected account equals the measured
rate-limit reference.

Reviewed the owner's written correction before implementation: admit precisely
absent/signed timestamp without authority-clock use; admit absent/null legacy
routing or the closed ordinary route with account-ID crossbinding. Retain route
presence/identity in a serde-skipped internal Descriptor and compare fresh child
equality, preserving the fourteen-field native wire and preventing verified
object→absent/null downgrade. Unknown keys/types, other backend/regional routes,
account mismatch and changed routing remain unavailable. Plan, source and direct
process recheck accepted below.

Fresh thread preflight exposed three further runtime-serialized experimental
properties and stable readOnly networkAccess. Reviewed the narrow documented
policy and implementation: absent legacy or empty/singleton selected-cwd roots,
null permission profile, explicitRequestOnly mode; closed sandbox type readOnly
and absent/default-false or boolean false networkAccess. Actual safe values
match this scope. These are effective-setting checks, not containment.

**CA-04, medium — routing positional arrays bypassed the object-only shape.**
The new derived serde Routing type accepts sequence deserialization even with
deny_unknown_fields. This reviewer earned an actual controlled-child trace:
workspaceRouting array `[account,ordinary backend,NO_CONSTRAINT]` yielded ready
metadata and a candidate proposal, rather than failing the required object
shape. Clean exit and real SQLite rows0 passed. The red is preserved in
`context/review-controller-agent/routing-array-red.log`. Require an actual JSON
object before typed deserialization and add the direct negative; correction and
direct same-shape green closed this finding. The parser now requires is_object
before derived deserialization. The independent malformed-metadata process
family includes this exact positional array and requires unavailable/null
descriptor, no export, clean exit, real rows0 and owned PIDs absent.

The independent focused compatibility rerun passed four installed-shape methods
in29.67s and the routing-downgrade/thread-policy family in15.62s: twenty-three
owned controller fixture cycles. Positives include real integer emission
timestamps and the schema-valid negative signed integer, ordinary routing and
legacy null, and the observed thread extras/networkfalse. Negatives include
timestamp bool/fraction/null/overflow, unknown routing key/account mismatch/
backend/regional/scalar/array, routing object→null/absent downgrade, foreign
workspace root, nonnull profile, proactive mode, tool-network true/wrong type and
unknown sandbox key. The latter cases preserve identical routing and assert an
actual thread/start receipt, preventing an earlier descriptor mismatch from
masking the intended policy fault. Logs are
`context/review-controller-agent/installed-compatibility-independent.log` and
`thread-policy-independent.log`.

Reviewed the owner's actual installed production-service metadata-only green:
ready in1.245s, exact fourteen native descriptor fields, healthy table close/
shutdown/exit0, real rows0 and both recorded version/App Server PIDs absent.
Its sanitized `metadata-diagnosis/service-green.log` matches independently
observed schema/source/runtime fields. No actual model turn was needed for this
compatibility correction. Original task/source/byte-handoff/publication bounds
remain unchanged; owner runs affected basics/release before the live join retry.

## Closed reasoning-notice extension

Reviewed the written subplan against the installed stable schemas and pinned
item.rs/event-mapping source before implementation. Three known notifications
may occur with inherited Auto reasoning settings: summaryTextDelta, textDelta
and summaryPartAdded. They do not constitute terminal proposal evidence.
The source diff admits only these names, closed required parameter keys,
exact active thread/acknowledged turn, bounded nonempty item ID, signed i64
index and string delta where applicable (including empty strings). Part-added
has no delta field. All original frame/total-byte/record/pre-ACK/task-clock
bounds and final-item rules remain unchanged. The branch neither appends to
final messages nor creates an outbound reply, Store call or reasoning history.
No blocking source finding.

The owner's direct positive red showed a valid reasoning notice followed by a
valid final failing the old adapter. The new peer's delta deliberately contains
valid-looking selection JSON for the excluded field; positive final selection
must still copy only the retained selected field. Negative reasoning-only input
has no agentMessage final and must never produce a candidate. Foreign IDs,
types/unknown/duplicate keys are actual process fault cases, with a receipt
marker proving the reasoning phase was reached rather than failing at setup.
Independent final actual process rerun passed both methods in38.07s: two normal/
pre-ACK positives and sixteen foreign/malformed/reasoning-only fixture cycles.
The positives retained only the exact selected source despite a competing-looking
delta. Foreign thread/turn cases reach each notice kind; type/range, empty/wrong
item identity, unknown/duplicate/positional fields and inappropriate part-added
delta all fail with null proposal. Each fixture proves the reasoning phase was
reached and independently checks real rows0, healthy close and owned PID absence.
The log is `context/review-controller-agent/reasoning-independent.log`.

Caught and corrected one test-input masking issue: reasoning-only originally
carried an unselected candidate ID, so an accidental delta promotion could be
hidden by the downstream grounding rejection. The persisted fixture now uses
valid selected-ID/request-ID JSON in that case; competing-delta positives still
use the excluded ID. A final independent single-mode actual child probe with
that corrected eligible JSON failed/null proposal, clean exit, real rows0 and
owned PIDs absent (`reasoning-only-independent.log`). The source discards that
text because it is a reasoning notice, not because its candidate would be invalid.

**Reasoning-notice extension accepted; no remaining source or oracle finding.**
Final production transport hash is recorded above; the final persisted fixture
SHA256 is `e7a1cd4ccff95da44a1a7a07cf03a5be1f0d66c4293350283f1c9d3deee2c068`.
Owner runs required affected basics/release before the canonical native rebuild.
No actual inference, CEF launch, credential/Keychain or OS identity change occurred
in this review, and these tests make no live-provider availability claim.

## Closed MCP startup metadata follow-up

The owner's single explicitly authorized installed synthetic turn completed in
9.124s with66 records/24,522bytes, a coherent completed/summary final and actual
owned reap. Its shape-only trace exposed `mcpServer/startupStatus/updated` as the
first unsupported method. This is not claimed as the exact cause of the earlier
native failed task, nor as native workflow acceptance.

Independently read pinned stable schema and original source. The notification
has required name/status, optional nullable threadId/error/failureReason, four
states starting/ready/failed/cancelled and sole failure enum
reauthenticationRequired. The source emits the current conversation ID. It has
no turn ID: this is thread-scoped metadata, not turn-scoped authority.

Reviewed the owner's written subplan before code: require matching nonnull
fresh acknowledged thread and bounded nonempty name; closed typed fields and
nullable error string under original budgets. One validator must cover held
thread-start notices after its ACK and before export, pre-turn-ACK held notices
and the active stream. No unbound baseline notices, generic ignore, login/tool
approval, history, Store/UI write or new authority. The plan and final pure
validator/source diff are accepted. Discarding a startup status does not disable
MCP or prove trusted coding-peer containment.

Independent actual process rerun passed five methods in48.27s: three arrival-
phase positives and eighteen foreign/malformed/metadata-only fixture cycles.
All four states and nullable/absent/string errors are accepted without leaking
server names/error text into the proposal. The same validator handles the held
setup queue after thread ACK and before page export, the original pre-turn-ACK
replay and active stream. Foreign setup identity fails with not_transmitted and
no export; pre-ACK/active foreign identity, missing/null/wrong-type thread,
empty/wrong-type name, unknown/wrong-type status/failure reason/error, unknown/
positional/duplicate fields and method/id callback confusion fail/null proposal.
Metadata-only error text carries eligible selection JSON but has no final
agentMessage; it remains failed/null proposal. Every fixture asserts an actual
metadata-phase marker, real rows0, healthy close and owned PID absence.
The log is `context/review-controller-agent/mcp-startup-independent.log`.

**MCP startup-metadata extension accepted; no remaining finding.** Final product
hash is recorded above; the final persisted peer/test SHA256 is
`1ff940c0cf8290f2f6bbf23e935b881bf2c8d1bbdb2b0a5e37a3ed6f54756630`.
Required affected basics/release and root's canonical native build remain the
next gates. This reviewer made no product edits, actual model turn, CEF launch
or Keychain/OS identity change.
