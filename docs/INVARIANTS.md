# Implemented construction invariants

## Current live application — 2026-10-16

The active native target now uses the live root-document reader and Blackbird
application connection. The fixture-only workflow described below is historical
and is not compiled into the application.

The native reader decodes Chromium replies on a worker and emits typed page/text
records. It compares root loader/frame metadata across the read and reports its
actual interval and coverage. Forms do not disable observation. Input/textarea
values, child-frame text, pixels and accessibility are omitted; loader origin
metadata is not an effective-window-origin assertion. Stop drops the host's
pending capture; it does not claim to cancel Blink's internal work.

The Blackbird client uses four-byte big-endian lengths and BBM2 values, with a
4 MiB packet bound, 8 MiB ordinary outgoing queue, and bounded pending UI events.
Private subprocess IO, termination and reap run off AppKit's main thread. A
steer uses a new request ID; an old final cannot retire the replacement. Page
evidence and operator objectives are separate fields. The real Blackbird engine
owns its ordinary tools/session; no browser action executor is added here.

See [the current integration plan](plan/live-blackbird.md),
[live-reader plan](plan/live-observation.md), `tests/blackbird_transport.py` and
`tests/live_observation.py`. Browser behavior is exercised on actual live sites.

## Earlier construction records

Pipe framing, a control-only controller child, an owned native shell/fixture
reader, reviewed-table storage and scoped agent proposals are implemented at the
scope below. General capture, OS input and network effects retain their later
gates. See [the construction sub-plan](plan/rust-basics.md).

| Invariant | Direct check | Limits / revisit when |
| --- | --- | --- |
| Nonempty UTF-8 payload, at most 65,536 bytes, one LF terminator | Exact bytes, invalid payloads, limit-1/limit/limit+1, fragmented UTF-8 | This layer does not validate JSON or typed commands; larger messages require an explicit separate protocol |
| Input retains at most one 65,536-byte frame plus a 4,096-byte read buffer | Append guard before copying; boundary and fragmentation cases | Allocator metadata/reader implementation are outside this retained-byte bound; no native capture-work or queue bound follows |
| Clean inter-frame EOF differs from truncation | Empty source and unterminated record | A peer can stall without EOF: caller must supply worker supervision/deadlines |
| Corrupt input or IO failure ends that direction | Terminal errors followed by attempted reuse; failing IO raises on reaccess | Connection ownership/closure and cross-direction shutdown belong to the later adapter |
| Invalid output emits zero bytes; partial write/failed flush cannot be retried here | Actual output bytes and writer that raises on access after failure | Successful flush is not receiver acknowledgement or durable completion |
| Framing component uses safe code and no third-party packages | Workspace forbids unsafe; Cargo.lock and cargo-deny | Controller dependencies are separately adopted below; a later FFI adapter needs its own scoped review |

The framing crate uses std only. The controller adopts locked Serde/serde_json
for its closed protocol; see [dependency origins](dependencies.json).

| Controller bootstrap invariant | Direct check | Limits / revisit when |
| --- | --- | --- |
| Version 1 JSON objects only; known operations and exact fields | Actual process rejects unknown/duplicate fields, invalid types and positional arrays | Typed schema admission does not grant any effect |
| Initialization binds one parent-supplied run ID; positive request IDs strictly increase | Actual initialize/reinitialize/stale/max-ID traces | Bootstrap duplicates terminate; future effect IDs need their separately reviewed result reconciliation |
| Stop generation increases once per accepted Stop; active powers stay empty | Exact process replies and shutdown result | No actual helper cancellation or effect quiescence is claimed |
| Framing/schema errors send one bounded nonreflecting error then exit; output failure closes | Actual process errors, EOF, invalid pipe and post-init corruption | Synchronous bootstrap IO cannot establish Stop latency under backpressure |

The basic CI matrix checks portable Rust. No simulator, mutation run, or heavier
proof is required for the current POC, per the operator's 2026-10-01 direction.

| Reviewed-table invariant | Direct check | Limits / revisit when |
| --- | --- | --- |
| Approval binds exact content/version/retention; duplicates preserve one CommitId | Actual SQLite review bytes/rows; changed-retention rejection and exact duplicate | Owned catalog join qualifies exact native Review; general extraction remains unqualified |
| Ordinary Stop cancels preparation; stronger deletion/expiry deny current access and purge after writer quiescence | Real SQLite lock stalls, actual rows and killed-child restart cases | An admitted ordinary-Stop commit may finish; no browser effect authority follows |
| Retained clean same-boot rows reopen with original identity/content; unknown or dirty recovery denies | Actual clean child restart, native boot/continuous clock, expiry purge and incompatible boot | No operator-machine suspend was tested; current frontend publication needs its own fresh native witness |
| Persistence checks actual native time after write-lock acquisition and before COMMIT | Actor-starved actual writer lock held past deadline persists zero rows before actor resumes | Sampling and COMMIT are separate operations; this is no atomic OS-time/durability guarantee |
| Failed closing cannot mark unresolved storage clean | Real writer timeout followed by release and further polls leaves dirty=1 | Kernel/storage faults can still require explicit conservative recovery |
| Database IO runs on one bounded worker; managed ownership precedes recovery | Process/lock tests and actual persistent lock file; closed service's urgent Stop under real stalls | Trusted controller owns serialized calls; broader workloads remain unqualified |

The [table experiment](experiments/local-table-evidence.md) and
[independent review](../papers/table-evidence-code-review.md) record the direct
scope. SQLite/rusqlite adoption is pinned in the dependency manifest.

Native scope is separately documented in the [shell experiment](experiments/native-shell.md)
and [fixture reader review](../papers/native-observation-code-review.md). The
reader's bounded callback/projection storage and continuous publication deadline
do not bound Blink traversal work. General observation stays disabled. Explicit
root context metadata verifies the tested effective origin; child frames and
sensitive fields are withheld. Broader lifecycle/workload/servicing gates and
the earlier unexplained startup/teardown failures remain open.

| Scoped agent invariant | Direct check | Limits / revisit when |
| --- | --- | --- |
| Only selected whole fields from a current unapproved Review enter one fresh task | Actual private peer receives selected markers and no excluded marker; scope/version/approval/expiry changes deny handoff | Two owned catalog patterns; trusted coding peer and hosted inference, with no containment or erasure claim |
| Runtime version/home/account/routing/effective thread settings bind before fields leave | Actual installed metadata-only preflight; controlled account/routing/policy changes and closed-shape attacks | Codex 0.160.0, ordinary ChatGPT routing only; metadata does not establish model entitlement |
| Model result selects native IDs; original retained fields supply values and provenance | Actual conflicting/generated/foreign/malformed final cases; native subset reconstruction before Use | No general learned extraction or model-generated field values |
| Known intermediate notices cannot supply a proposal or authority | Correlated reasoning/MCP startup cases, foreign/malformed negatives and eligible JSON without a final produce no candidate | Only pinned closed notice shapes; startup status does not disable MCP or contain the trusted coding peer |
| Revocation fences unsent chunks and terminal transport failure reaps the direct child | Actual private socket saturation with Running → Stop; actual host stdout loss and owned PID absence | Already handed-off content may remain disclosed; arbitrary descendants/forced host death outside cleanup; clock and write are separate operations |
| Late task replies cannot become another task's proposal | Actual blocked stdout A → replacement B trace returns unknown_task for A | Current run only; no history/resume/retry or durable task reconciliation |
| Use revises the original draft; Save remains a separate exact Review action | Actual native proposal/Use/Review/Save/SQLite/reopen driver; zero SQL before Use and Save | Programmatic delivery to native actions on owned fixtures, with physical input still unqualified |
| Active native Quit joins its pending Rust revocation before healthy close | Actual pre-export Quit requires pending-fence join, exact ACK, no export and clean empty SQL | Wrong/missing ACK leaves close unclean; OS clock startup and broader concurrency availability remain unresolved |

The [controller review](../papers/controller-agent-proposals-code-review.md),
[native panel review](../papers/native-agent-panel-code-review.md) and
[joined experiment](experiments/native-agent-workflow.md) distinguish controlled
protocol, native lifecycle, installed metadata and live inference evidence.
