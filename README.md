# Bow Shock

A semi-automatic browser: a person and an agent work in the same visible
browsing session, with deliberate limits on what the agent can do and a native
connection to an agent runtime such as Codex.

This repository has progressed from research through [reviewed design](docs/design/README.md)
to [the reviewed implementation plan](docs/plan/README.md). Rust implements bounded
controller pipe framing and a [control-only child process](docs/plan/controller-bootstrap.md)
with the [basic rigor checks](docs/plan/rust-basics.md). The matched CEF runtime
has been acquired and the owned native shell passes its construction smoke;
remaining runtime gates are explicit in [the experiment](docs/experiments/native-shell.md).
The [owned-fixture reader](papers/native-observation-code-review.md) and
[reviewed-table library](docs/experiments/local-table-evidence.md) also pass
their direct checks and independent reviews. Their native UI integration and
general observation workload gates remain open.

Current scope: a dedicated window, macOS first and Linux second. The model reads
native rendered DOM and proposes work; a separate OS input executor supplies
keyboard/mouse/scroll events. Request/response editing, traffic baselines and
alerts, external network perturbation experiments, and learned DOM-to-table
extraction are core requirements. Read [the product brief](docs/product-intent.md).

Read [BLACKBIRD.md](BLACKBIRD.md) for the working doctrine,
[the research index](papers/README.md) for the corpus,
[the reference manifest](QUARANTINE.md) for acquired source, and
[ISSUES.md](ISSUES.md) for open decisions. Work history lives in [journal/](journal/).

The important design question is where the browser enforces the person's
delegation: which tab, page version, actions, destinations, and duration belong
to the agent, and how the person takes control back. Engine embedding,
observation, actuation, and agent conversation are distinct decisions.

## Local setup

For the Rust POC foundation, the repository pins Rust 1.94.1 and its components.
Use `scripts/rigor` for formatting, Clippy, nextest, doctests, dependency policy
and release compilation. If the pinned developer tools are absent, install them
with `scripts/rigor install-tools`. The workflow repeats these checks on macOS
ARM64 and Linux x86_64/ARM64; only the local macOS run has been executed so far.
The portable child accepts only initialization, ping, Stop generation and
shutdown records; it has no delegated powers. The native shell connection has
actual process failure tests and independent review. Runtime adoptions are recorded in [the dependency manifest](docs/dependencies.json)
and [the matching CEF manifest](runtime/cef-macos-arm64.json).
Deterministic simulation, mutation runs and heavier verification tiers are
deferred by operator direction; see [implemented invariants](docs/INVARIANTS.md).

Python 3.13+ and Git suffice for the research utilities; no package installation
is needed. `pdftotext` is optional for reading downloaded papers. Source archives,
clean reference trees, document snapshots, and paper PDFs are local ignored
artifacts. The source catalogs and acquisition records are tracked.

```sh
python3 scripts/acquire.py --kind all
```

The utility resolves source repositories to commits on the first acquisition,
then reuses those pins. It preserves archives and never executes acquired code.
Failures remain explicit in `papers/acquisition.json`; consult the shopping list.
Use `--id SOURCE_ID` to acquire one source and `--kind refs`, `papers`, or `docs`
to select a class. `--restore` rebuilds extracted trees from preserved archives
and retains previous trees under `context/retired-references/`. Full Chromium
checkout/build is a separate, future task. Archives omit submodule contents;
the ledger records those gaps explicitly.

After acquisition, refresh the tracked inventory and gap summaries with
`python3 scripts/research_inventory.py`. The expanded network collection has
[its own reading map](papers/network-quarantine.md). The existing workspace
[Jev tool is available for bounded research judgments](papers/jev-network-judgments.md).

The [design specification](docs/design/README.md) connects the research to native
observation, grants and OS input, agent/provider integration, the human network
workbench, outside-browser interventions, and reviewed tables. Its
[local controls concept](docs/design/controls.svg) needs no external design tool.
Blackbird requires adversarial design review before the implementation plan,
and plan review before product code.

The [implementation plan](docs/plan/README.md) orders native feasibility,
authority/evidence, grounded tables, model/Codex integration, OS input and the
network workbench/experiments. Its [tribunal](papers/plan-tribunal.md) resolved
seven distinct plan findings. The first native sub-plan and dependency proposal
are concrete; native construction and owned-fixture reader/table units are
verified at their documented scope. The joined operator workflow follows.
