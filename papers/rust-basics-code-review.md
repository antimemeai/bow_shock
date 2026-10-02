# Rust basics: independent code review

2026-10-01. Bounded review of the first Rust construction unit, required by
[Blackbird](../BLACKBIRD.md). Reviewed the [construction plan](../docs/plan/rust-basics.md),
[implemented invariants](../docs/INVARIANTS.md), controller-link source and tests,
workspace/package manifests, lockfile, toolchain/tool pins, rustfmt, nextest and
cargo-deny configuration, `scripts/rigor`, and the Rust CI workflow. Also checked
that the implementation-plan overview and authority lane recognize the
operator's deferral of deterministic simulation, mutation and heavier methods.
This review does not extend to an implemented browser, controller process,
typed-command parser, authority owner, OS-input adapter or evidence store.

## Result

No actionable code or tooling defects found within this unit. No severity-rated
findings remain open. The reader checks the frame limit before appending, uses a
fixed-size owned read buffer and validates UTF-8 after complete framing; split
UTF-8 transport reads preserve payload bytes. Corrupt/truncated input and failed
output permanently poison their direction. Invalid outgoing payloads are
rejected before any output access. The implementation distinguishes clean EOF,
truncation, malformed input and delivery-unknown output failure.

The tests assert exact results and bytes rather than merely successful execution.
Failing IO implementations raise on subsequent access, directly checking terminal
behavior. The public documentation accurately limits the claim: synchronous IO
requires dedicated workers; framing provides neither deadlines nor command
authority, and a successful flush provides no receiver acknowledgement.

Two optional edge-oracle improvements were suggested during review and integrated:
delimiter-only write failure after successful payload delivery, and a writer
returning `Ok(0)`. The added cases check exact error kinds, terminal reuse,
absence of flush after failure, and—in the delimiter case—the exact remaining
unterminated payload. They require no production fault switch or extra library.

## Execution evidence

The reviewer ran the original `scripts/rigor` against the 12-case suite. Formatting,
Clippy with warnings denied, all 12 nextest cases, the doctest, cargo-deny and
release compilation passed. The initial cargo-deny run emitted only unused
license-allowance warnings because there are no third-party packages. The owner
subsequently narrowly allowed that diagnostic in configuration; it does not
relax the license allowlist or other dependency checks.

After reviewing the two added tests, the reviewer ran only those cases:

```sh
cargo nextest run --workspace --all-features --locked --profile ci \
  -E 'test(delimiter_write_failure_leaves_an_unknown_unterminated_record) | test(zero_write_is_terminal)'
```

Both passed; the original 12 were skipped in that focused run. The reviewer did
not repeat unchanged full checks. These are local macOS results, not remote CI
execution evidence.

The CI matrix selects ARM64 macOS, x86_64 Linux and ARM64 Linux labels supported
by [GitHub's runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
The checkout revision was independently checked through the GitHub API as an
existing commit and the current `v5` tag target. The workflow uses read-only
contents permission, disables checkout credential persistence and invokes the
same rigor script. No universal portability or native browser capability claim
follows from inspecting the workflow.

The final runner adjustment was also inspected: all cargo commands, including
developer-tool installation, explicitly select the channel read from
`rust-toolchain.toml`, and missing developer-tool executables produce the same
actionable installation instruction as a version mismatch. Argument lists are
passed directly to subprocesses; no shell interpolation is introduced. No
additional finding arose. The reviewer did not rerun checks for this inspection;
the owner's final runner-validation run is separate from the reviewer execution
evidence above.

## Remaining limits

Finite boundary and fragmentation cases support this framing contract. They do
not qualify connection ownership, queue bounds, stalled-peer recovery, process
isolation, JSON/schema validation or any browser effect. Those belong to their
later construction units. No deferred simulation, mutation fleet, formal proof
or benchmark was demanded or run for this review.
