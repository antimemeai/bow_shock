# Controller-owned grounded agent proposals

2026-10-02. First B1–B3 extraction unit, under the authorized native tandem
milestone. The reviewed controller remains the serialized authority owner; CEF,
AppKit and human Save stay with the native shell. No new crate or unsafe code.

The native caller explicitly approves selected whole fields from an exact current
Review for one objective. Host IDs are `r0f0` through the existing two-row,
six-field projection. The host reconstructs the current Review, requires exact
identity/version/content, copies only selected retained fields and preserves the
source's original native deadline. The provider may select a nonempty subset of
those field IDs or return no-match. It cannot supply values, row IDs, evaluator
code, paths, provider configuration or a write. The resulting batch is copied
from retained source; native UI explicitly revises that same unapproved draft,
obtains a fresh exact Review and Saves it. No restaging with a fresh source TTL.
Final publication rechecks unchanged original Review/version/scope.

Closed native version-1 operations share the existing monotonic request IDs:
`agent_metadata`, `agent_start{review,candidate_ids,objective,ttl_ms}`,
`agent_status{task_id:string-or-null}` and `agent_cancel{task_id}`. Start returns
an immediate task identity; metadata/status return cached state, never wait for
inference. Only one task and one final exist; completed data remain source/Stop
gated and require PublicationGuard before UI publication. TTL is positive and
at most 60 seconds, capped by the original source deadline. StopAll is the first
native urgent retirement path, independent of ordinary task status requests.
Scope/revision/close, transport loss, expiry and cancellation invalidate it.

Optional trusted CLI agent configuration fixes executable, working directory,
model/provider and selected runtime home/account expectation. The exact closed
records are in [controller-agent-wire.md](../experiments/controller-agent-wire.md).
Actual installed
0.160.0 schemas and fresh handshake/account/effective thread settings must match
before observation handoff. Metadata starts asynchronously and has explicit
opening/ready/unavailable states. Fresh ephemeral thread per request; no resume,
fork, compaction, dynamic tool, generic RPC, automatic retry or provider fallback.
Codex stays a trusted coding peer, with hosted inference identified separately;
ordinary sandbox settings and typed output do not establish containment. Account
Initial metadata-only setup binds a measured backend account ID as session
baseline, optionally checking a configured expectation. Native Ask approves that
visible destination. Every fresh child must match it; absent ID is unverified
and unavailable for export, never synthesized from email/type. Runtime metadata
is only a measured identity signal, not authentication
against an adversarial same-UID peer or an entitlement guarantee.

Bounds: existing native frame 65,536 bytes; exact Review 24 KiB; selected batch
16 KiB/two rows/six fields each; objective 2 KiB; 1–12 distinct selected IDs;
final structured text 4 KiB and explanation 2 KiB. Provider frame 64 KiB, total
stdout at most 512 KiB/512 records per owned connection; nesting at most 32;
at most 16 notifications held while a response correlation is pending. Setup
has a ten-second finite deadline, transport-write two seconds, and turn/source
deadline at most sixty seconds. No streaming display queue is introduced;
diagnostic stderr is discarded, with bounded static host reasons only. These
are admission/transport bounds, not a claim about Codex's internal native work.
Numeric IDs from server requests and client replies belong separate directions:
method/id callbacks never satisfy a pending result. Unsupported callbacks close
and reap without approving execution, granting permissions, supplying auth or
waiting for native UI. Completion summary and item/completed must agree on the
same final item/text; repeated summary is not a second final. Phase-null interim
text and deltas are not candidates. Notifications racing a turn/start ACK are
held within the finite correlation budget. Post-baseline account/config changes
retire export and candidate authority, even if provider cancellation is uncertain.

One owned worker supervises the provider process and bounded JSONL. Two private
UnixStream pairs redirect inherited stdin/stdout using safe OwnedFd→Stdio. Only
parent endpoints become nonblocking. Every nonblocking write of observation
bytes holds the same small revocation lock as authority retirement and checks
the immutable task identity/generation and fresh actual native clock witness.
The actual clock query happens outside that lock; a delayed query cannot stall
authority Stop or extend the original deadline. Each write requires the query's
elapsed wall/monotonic age below 100ms and at least 100ms of saved native deadline
headroom. This conservative witness freshness allowance is not an atomic OS
clock/write primitive: process suspension between the check and syscall remains
a narrow limitation. Actual delayed-result denial is tested without fake time.
Serialization/enqueue is not
export. Revocation discards all unsent bytes;
already handed-off bytes remain possibly disclosed/retained. Outcomes report
not_transmitted/transport_handoff_started/partially_transmitted/
provider_retained_unknown, without erasure claims. Bounded read/write work and
finite fresh native-clock/IO supervision occur off the authority loop. Exact
owned Child kill/reap precedes quiescence; direct KILL is the standard-library
mechanism, not a TERM or arbitrary-descendant containment promise. Terminal host
drain waits off the healthy actor; forced host death remains outside cleanup.

Implement actual controlled App Server peers through this production transport
before live inference. Red process cases inspect exact received selected/excluded
markers, final grounding, malformed/duplicate/late finals, Stop before/after
handoff, stalled private IO, child death and exact reap. Inspect SQLite directly
for zero automatic writes. Source/API tests enforce object-only closed nested
decoding. Then run affected Rust basics and independent review. Only after these
greens may root run an explicitly selected synthetic-catalog actual Codex turn
and join the native human-review/Save workflow. No CEF/keychain launch in this unit.
The controlled suite runs one owned host at a time; simultaneous-host pre-main
startup availability is a separate unpassed workload after actual dyld stalls.

Grounding sources are the installed schema exports already acquired under
context/design/codex-0.160.0 and the existing original Store/controller contracts.
Safe nonblocking transport uses standard UnixStream/OwnedFd APIs and pinned Rust
standard-library socket code; study is not package adoption. Detailed measured
Codex metadata/notification shapes are supplied by the separate protocol research
owner before the worker state machine is finalized.
