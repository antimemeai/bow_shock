# Implemented Rust invariants

Only the pipe-framing component is implemented. Engine isolation, command
validation, authority, time limits and durable evidence remain future work.
See [the construction sub-plan](plan/rust-basics.md).

| Invariant | Direct check | Limits / revisit when |
| --- | --- | --- |
| Nonempty UTF-8 payload, at most 65,536 bytes, one LF terminator | Exact bytes, invalid payloads, limit-1/limit/limit+1, fragmented UTF-8 | This layer does not validate JSON or typed commands; larger messages require an explicit separate protocol |
| Input retains at most one 65,536-byte frame plus a 4,096-byte read buffer | Append guard before copying; boundary and fragmentation cases | Allocator metadata/reader implementation are outside this retained-byte bound; no native capture-work or queue bound follows |
| Clean inter-frame EOF differs from truncation | Empty source and unterminated record | A peer can stall without EOF: caller must supply worker supervision/deadlines |
| Corrupt input or IO failure ends that direction | Terminal errors followed by attempted reuse; failing IO raises on reaccess | Connection ownership/closure and cross-direction shutdown belong to the later adapter |
| Invalid output emits zero bytes; partial write/failed flush cannot be retried here | Actual output bytes and writer that raises on access after failure | Successful flush is not receiver acknowledgement or durable completion |
| Rust component uses safe code and no third-party packages | Workspace forbids unsafe; Cargo.lock and cargo-deny | A later FFI adapter needs its own scoped review; do not relax this workspace globally |

The basic CI matrix checks portable Rust. No simulator, mutation run, or heavier
proof is required for the current POC, per the operator's 2026-10-01 direction.
