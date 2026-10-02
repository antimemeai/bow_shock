# Rust foundation and basic rigor

The operator accepted the POC arrangement and required the Rust rigor stack
despite the controller's small size, then explicitly said to skip detsim,
mutants and similar work for now. Read Blackbird/project guidance and the
reviewed plan. Located and read the workspace wiki's draft Rust rigor stack.
Updated the plan to retain direct failure tests and independent review while
deferring simulator/model escalation, mutation fleets and heavier proof tools.
Use “controller” for the Rust application role following the operator's earlier
terminology question.

Written construction sub-plan: `docs/plan/rust-basics.md`. Implemented one useful
transport unit for the later native-app/controller connection: bounded UTF-8
newline framing through dedicated synchronous IO-worker primitives. It owns
payload limits, byte preservation and terminal framing/IO errors. It admits no
commands or effects and does not start a runtime/controller process.

Created pinned Rust 1.94.1, matching fmt/Clippy, nextest configuration, deny
policy, developer-tool pins and one local/CI entrypoint. Existing developer
tools are nextest 0.9.137 and cargo-deny 0.20.2. Package metadata confirms their
Rust minimums as 1.91 and 1.88.0 respectively. Their installation/restoration is
explicit; no global tool install was performed. The first crate uses only std;
Cargo.lock contains no third-party runtime or development package. Consequently
this initial dependency check has no external package graph to audit; the
policy will check the resolved graph when real dependencies enter.

Direct oracle sequence: wrote 12 specification-derived integration cases and
ran them against unimplemented signatures: all 12 failed. Implemented framing
from the std BufRead/Write contracts. `scripts/rigor` then passed fmt, Clippy with
warnings denied, all 12 nextest cases, one doctest, cargo-deny and release build.
The initial deny run had allowance-not-encountered warnings because there are no
external packages; a narrow config suppresses only unused license allowances,
and the repeat deny check passed without warnings. Byte-size limits and actual
emitted bytes are the oracles, not calls to a mock permission check.

Blackbird-required independent adversarial review found no actionable defect.
Its two optional edge-oracle suggestions were accepted: failure writing only the
LF delimiter after successful payload bytes, and a writer returning zero bytes.
Both cases pass; Clippy was rerun for those new tests. No production guard-bypass
or mutation feature was added. The review is retained in
`papers/rust-basics-code-review.md`.

CI repeats the same entrypoint on macos-15 ARM64, ubuntu-24.04 x86_64 and
ubuntu-24.04-arm ARM64. GitHub's runner docs confirm those architectures.
Checkout v5 is pinned to `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`, resolved from
upstream; credentials persistence is off and workflow permissions are read-only.
No remote workflow was run or repo pushed. Native browser/input/network and
timing/durability claims remain entirely open. No CEF archive, serde/SQLite/model
library, OS permission, network intervention or automated page effect was adopted
or exercised during this unit.

Final edits make every Cargo invocation explicitly select the repository's
toolchain pin, including tool restoration, and give an actionable missing-tool
message. The final local run through the updated entrypoint passed fmt, Clippy,
all 14 nextest cases, the doctest, warning-free cargo-deny and release compilation.
