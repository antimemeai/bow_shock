# Rust basics for the POC

2026-10-01. The operator requires the Rust rigor baseline even for the small
controller, and explicitly defers deterministic simulation, mutation testing
and the heavier tiers for now. This supersedes their scheduling in the earlier
plan; the authority and native-effect contracts remain unchanged.

## First construction unit

Build the controller's bounded newline-framing primitive and the basic developer
checks together. The AppKit shell will later use this transport through dedicated
IO workers. This unit does not start a controller process, parse typed commands,
admit an effect, or make a CEF/OS capability available.

Payloads are nonempty UTF-8, at most 65,536 bytes, with no literal CR/LF; a single
LF terminates each record. Escaped JSON newlines are ordinary payload bytes.
Clean EOF between frames is distinct from a truncated frame. Input corruption
or IO failure permanently poisons that direction; callers close/reconcile the
connection rather than attempting stream resynchronization. Invalid outgoing
payloads are rejected before IO. A partial write or failed flush poisons output
because its delivery is unknown. Framing does not establish JSON validity,
origin, identity, permission, durable completion, or a timeout.

Read through an owned fixed-size buffered reader, retain at most one bounded
frame, and reject excess before appending it. Do not use unbounded `lines()` or
`read_until()` on an untrusted stream. Synchronous reads/writes belong only on
IO workers, never the controller authority loop or CEF callbacks.

Write failing specification tests first: exact bytes and multiple frames;
limit-1/limit/limit+1; arbitrary transport fragmentation; clean/truncated EOF;
empty/CR/non-UTF-8 frames; IO interruption/error; partial writes; failed flush;
and no subsequent stream access after a terminal fault. Then implement using
the standard library and obtain an independent code review. No new library
dependency is needed for this construction unit.

## Basic gates

`scripts/rigor` runs the same commands locally and in the Rust CI matrix:

- Rust 1.94.1 with matching rustfmt and Clippy, pinned in `rust-toolchain.toml`.
- `cargo fmt --all --check` and Clippy on all targets/features with warnings denied.
- Locked nextest unit/integration tests and a separate locked doctest step.
- cargo-deny advisories, yanks, license and source policy over the lockfile.
- Release compilation with overflow checks retained.

Use existing nextest 0.9.137 and cargo-deny 0.20.2, pinned for tool restoration.
These developer tools offer isolated test execution and maintained dependency
policy machinery; owning substitutes would not improve our browser contract.
They are not runtime dependencies. Commit Cargo.lock. CI covers portable Rust on
macOS ARM64, Linux x86_64 and Linux ARM64; it cannot establish native CEF/input
behavior. Keep target-default CPU baselines; never transplant the wiki's
`x86-64-v3` setting into the ARM build or use `target-cpu=native` in shared output.

Real malformed input and failed IO supply the initial negative cases; no
production guard-bypass or runtime mutation feature is introduced. Property and
fuzz harnesses can be considered when typed parsers/state machines arrive;
this unit uses finite boundary and fragmentation cases. Detsim, mutation fleets,
Loom/Stateright, Kani/Flux/Aeneas and benchmark/coverage machinery are deferred.
Independent code review and directly checked failure outcomes still apply.

The workspace source is the operator's draft Rust rigor ladder at
`../quarantine_proj/xx_wiki/src/content/docs/testing-verification-rigor/rigor-stacks/rust.md`,
read 2026-10-01. It is study material, not a copied implementation or a shipped
dependency. Current primary references:
[BufRead contracts](https://doc.rust-lang.org/std/io/trait.BufRead.html),
[nextest execution](https://nexte.st/docs/running/),
[nextest configuration](https://nexte.st/docs/configuration/reference/),
[cargo-deny configuration](https://embarkstudios.github.io/cargo-deny/checks/cfg.html),
[advisory policy](https://embarkstudios.github.io/cargo-deny/checks/advisories/cfg.html),
[GitHub runner architectures](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
