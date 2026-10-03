# Clock simplification source review

Read original clock plan/journal, E-01 correction, authority/retention contracts,
current Store/SQLite/agent/native UI clock gates and unsafe policy. Original
subprocess rationale was avoiding unsafe Rust while obtaining fresh native
samples, not an isolation/security guarantee. Direct kernel calls can remove
process/JSON/supervision complexity without changing clock domain or useful
retention behavior.

Acquired/read exact pinned Rust1.94.1 time implementation/public contract and
recorded origins/checksums/restoration in runtime/rust-agent-primary.json.
Apple Instant uses CLOCK_UPTIME_RAW excluding sleep; SystemTime is wall
CLOCK_REALTIME. Neither substitutes for kernel boot identity plus continuous
nanoseconds. Read installed mach SDK contract. Sent root early conclusions:
fresh direct sample at existing operation/publication/worker/agent boundaries,
same saved domain, kernel boot/timebase caching only, no cached current time.

Recorded papers/native-clock-simplification-review.md. Scoped Rust FFI cannot
override inherited forbid from an inner module. Reviewed root's separate original
adapter-crate proposal, which retains forbid in all3 existing crates and changes
policy only for that adapter. Portable/Linux test backend and continuous-domain
sample-age definition remain implementation-plan details; no process mechanism
is needed to satisfy either. No blanket relaxation/dependency adoption implied. No code,
test, native, clock, app or model launched; no product code changed. Runtime
acceptance belongs to a later concrete simplification unit.
