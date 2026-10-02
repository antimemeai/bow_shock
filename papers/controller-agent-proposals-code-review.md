# Controller scoped agent proposal review

2026-10-02. Independent review of the controller-owned Codex0.160.0
proposal/export unit, its written plan, original installed protocol schemas and
actual controlled-child oracles. Native startup/wire/panel/CEF joining are
separate reviewed units. No product edits, actual inference or CEF launch by
this reviewer.

**Accepted for the closed scoped proposal service. All three findings are closed
by source correction and direct independent recheck; no remaining blocker.**

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
| `agent.rs` | `cdbd7ac5f6f9304327de76acebb74a4e161a9a147477aecf39be3493d3975074` |
| `agent_transport.rs` | `a32a77ca7836445a6234f3ed12954a9acebcf3cde8b474a85514ba9e0456574c` |
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
