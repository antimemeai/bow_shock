# Implemented construction invariants

Pipe framing, a control-only controller child, an owned native shell/fixture
reader and the local reviewed-table library are implemented at the scope below.
Native integration, general capture workload limits and delegated effects remain
future work. See [the construction sub-plan](plan/rust-basics.md).

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
| Approval binds exact content/version/retention; duplicates preserve one CommitId | Actual SQLite review bytes/rows; changed-retention rejection and exact duplicate | Native extraction and exact UI display must still be joined to this library |
| Ordinary Stop cancels preparation; stronger deletion/expiry deny current access and purge after writer quiescence | Real SQLite lock stalls, actual rows and killed-child restart cases | An admitted ordinary-Stop commit may finish; no browser effect authority follows |
| Retained clean same-boot rows reopen with original identity/content; unknown or dirty recovery denies | Actual clean child restart, native boot/continuous clock, expiry purge and incompatible boot | No operator-machine suspend was tested; current frontend publication needs its own fresh native witness |
| Persistence checks actual native time after write-lock acquisition and before COMMIT | Actor-starved actual writer lock held past deadline persists zero rows before actor resumes | Sampling and COMMIT are separate operations; this is no atomic OS-time/durability guarantee |
| Failed closing cannot mark unresolved storage clean | Real writer timeout followed by release and further polls leaves dirty=1 | Kernel/storage faults can still require explicit conservative recovery |
| Database IO runs on one bounded worker; managed ownership precedes recovery | Process/lock tests and actual persistent lock file | Trusted controller owns serialized calls; controller's nonblocking integration is still pending |

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
