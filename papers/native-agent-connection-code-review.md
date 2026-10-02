# Closed native proposal connection review

2026-10-02. Independent narrow review of root's new agent request/reply methods
in `table_connection.h/.mm`, written native-agent connection plan and the direct
Foundation decoder oracle. Startup configuration, Rust authority/export and the
native panel/join are separate conceptual units.

**Accepted for the closed native proposal wire; no blocking finding.**

The four named methods preserve the existing finite ordinary/urgent slots,
request identities, two-second budgets, canonical JSON roundtrip decoder and
owned child teardown. Agent start requires configured startup, exact Review,
unique closed host IDs (at most 12), bounded objective, TTL at most60s and current
source guard. That guard is copied into pending ownership and rechecked by the
original actual-clock write gate before a write; serialization is not permission.
Start acknowledgement must return the selected IDs unchanged, same boot and a
deadline no later than the original guard. No generic RPC or tool registration
is exposed.

Metadata requires the exact fourteen-field descriptor and narrow version/role/
provider/account/capability values; opening/unavailable carries null descriptor.
Status has closed states, task correlation, disclosure enum and code shape.
Candidate/no-match alone carry a data guard. Candidate has closed nested source-
grounded native Batch shape, unique host IDs, bounded explanation and matching
field count. Other states carry no proposal/data guard. This decoder checks
wire shape, not the Rust owner's original-candidate reconstruction; the latter
remains its separate authority invariant.

Null guard means absent data, so the changed generic publication checks skip
only actual NSNull. Non-null guarded data still passes fresh native witness
checks in the worker and immediately before main-thread completion. Unknown
operation/descriptor/proposal/error fields and stale or inconsistent shapes
are withheld; agent_error cannot masquerade as a table-operation result.

Direct red was valid ready metadata refused before the API/decoder existed.
Root's final decoder green was independently rerun by this reviewer with
`python3 tests/native_agent_decoder.py`; the actual strict-warning ObjC++ build
and Foundation executable passed. Cases exercise positive descriptor/opening,
start/current IDs and guard, guarded candidate/no-match, running absence and
cancel/error. Negatives attack role/unknown descriptor fields, selected-ID change,
boot/deadline extension, duplicate IDs, field-count/task mismatch, unguarded or
wrong-state data, unknown error/cross-operation error and unconfigured start.

Reviewed completed ordinary regression evidence: four actual native startup
cases passed in5.074s and five original transport/bootstrap/review/Stop/stale/
busy-UI cases passed in19.756s, retained in the final runtime logs. Earlier cold
first-child failures were not hidden: actual diagnostics recorded no first
instruction launch marker and AppleSystemPolicy rejection for the newly built
peer, versus the same executable's immediate subsequent successful launch.
The exact-path OS log and4.769s/0.081s first/second records are retained under
`context/runtime/agent-startup-diagnostic`. No production timeout or OS policy/
permission was relaxed, and this review does not claim a product fix for that
external startup failure. Runtime startup remains honestly unavailable when
the OS refuses or delays the selected child beyond the existing budget.

This acceptance does not prove actual Codex structured inference, account/model
entitlement, original source reconstruction, last-byte revocation, native panel
retirement or SQLite Save. Those are subsequent owners' direct oracles. No CEF,
keychain, actual inference or product-source mutation occurred in this review.
