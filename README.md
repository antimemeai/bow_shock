# Oxcart

A live native browser with Blackbird working beside you. Browse ordinary sites,
read the rendered page, and send your objective and page context to Blackbird.
The conversation panel streams replies, accepts steering during work, and stops
an active request. Blackbird keeps the conversation and runs its ordinary coding
engine and tools. Oxcart owns browser observation and presentation.

## Run

Build the Blackbird application interface in its worktree:

```sh
cd ~/projects/blackbird-oxcart
cmake --preset debug -DCMAKE_OSX_SYSROOT="$(xcrun --show-sdk-path)"
cmake --build build/debug --target blackbird --parallel 6
```

Then build and open Oxcart:

```sh
cd ~/projects/bow_shock
python3.13 scripts/build-native.py
./scripts/oxcart https://news.ycombinator.com/
```

Select another executable with `--blackbird /absolute/path/to/blackbird`.
The launcher prefers the Blackbird integration worktree, then the ordinary
Blackbird release build. The selected executable must support `--application`.
`--data-dir` selects a dedicated browser profile and Blackbird session;
`--model` selects the Blackbird model. Provider authentication belongs to
Blackbird and uses its existing account configuration.

The panel shows the selected browser URL, conversation and a multiline composer.
**Read page** shows a fresh native reading locally. **Send** includes a fresh
reading when the checkbox is selected; **Steer** interrupts current work and
starts the replacement objective. Command+Enter sends. **Stop** cancels pending
capture and requests cancellation of Blackbird's active work. Ordinary native
browser navigation continues while the agent works.

Page observations retain URL/title, frame/document/capture identity, timing,
truncation and coverage. The reader includes rendered root-document text and
omits input/textarea values. Child-frame text, pixels and accessibility are not
currently included; occlusion and clipping are not evaluated. Origin metadata
comes from the Chromium loader and does not establish effective window origin.
Blackbird receives page content separately from the operator objective.

The integration does not yet supply Blackbird with browser action tools.
Keyboard/mouse/scroll execution, network inspection/editing/perturbation and
learned table extraction remain subsequent product work. Blackbird's ordinary
coding tools retain their usual agency.

## Development

The operator's October 16 direction replaces the old catalog POC: develop on
live sites, investigate actual failures and fix them directly. The launcher
starts no local web server. The active native target compiles the live reader,
Blackbird binary client and conversation panel. Earlier catalog source/results
remain historical, including in-progress work that predates this change.

[The integration plan](docs/plan/live-blackbird.md) records current ownership and
interface. [The live-reader plan](docs/plan/live-observation.md) records its actual
capture behavior. The Blackbird side documents the wire contract in
`../blackbird-oxcart/docs/APPLICATION_INTERFACE.md`.

Production uses AppKit/Objective-C++ and the adopted matched CEF runtime.
Native Blackbird IPC uses length-prefixed BBM2 values. The retained Rust/Codex
adapter is bumped to Codex 0.162.1; Blackbird is the current browser conversation
integration. Runtime acquisition is recorded in `runtime/cef-macos-arm64.json`.
Use an installed Python 3.13+ for the development utilities.

Focused checks:

```sh
python3.13 tests/live_observation.py
python3.13 tests/blackbird_transport.py
python3.13 scripts/try-poc.py https://www.python.org/ --smoke-output context/runtime/python.plist
```

The live smoke command captures the real site and writes a binary plist result.
Add `--smoke-objective 'Summarize the page in one sentence.'` for an actual
Blackbird turn using the captured page. Protocol/state tests use direct native
inputs; browser development uses live pages.

Read [BLACKBIRD.md](BLACKBIRD.md), [AGENTS.md](AGENTS.md),
[product intent](docs/product-intent.md) and [ISSUES.md](ISSUES.md).
Historical literature and source studies are indexed in [papers/](papers/README.md);
work history is recorded in [journal/](journal/).
