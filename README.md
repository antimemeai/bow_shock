# Oxcart

Oxcart's primary purpose is extracting and organizing information across a live
page visit, including content revealed through scrolling, expansion and lazy
loading. Organized output follows the information rather than the DOM's shape.
The current implementation supplies complete readings, accumulated per-visit
reading references, a native extraction preview and an immutable recipe box. See
[the visit-extraction plan](docs/plan/visit-extraction.md).

The extraction loop is a generic extraction, rendered preview and one
round of tweaks. Operator and bot then work through remaining page-specific
failures and save the successful approach as a dated page-type recipe. The
preview stage supports source inspection, selected-text corrections and recipe
successor saves; see
[the concrete next unit](docs/plan/extraction-preview-recipes.md).
Recipes are preserved: each update is a whole new recipe that becomes active,
superseding its predecessor. Keep all readings, attempts, previews and recipe
history for tracking and later study. Metrics/instrumentation and a bidirectional
traffic capture/editing proxy, including ads, are the fast follows; see
[the follow-up plan](docs/plan/instrumentation-proxy.md).
Initial instrumentation is available now: stage events are retained with the
workspace, and `python3.13 scripts/extraction-metrics.py DATA_DIR/extraction`
writes a new dated binary-plist/text report without replacing older reports.

A live native browser with Blackbird working beside you. Browse ordinary sites,
read the rendered page, and send your objective and page context to Blackbird.
The conversation panel streams replies, accepts steering during work, and stops
an active request. Blackbird keeps the conversation and runs its ordinary coding
engine and tools. Oxcart owns browser observation and presentation.

## Run

Blackbird's application interface is merged on master. A mainline source/build
export keeps Oxcart running while the main Blackbird checkout has independent
TUI work. Rebuild that retained runtime with:

```sh
cd ~/projects/blackbird/context/mainline-runtime/source
cmake --preset debug -B ../build/debug -DCMAKE_OSX_SYSROOT="$(xcrun --show-sdk-path)"
cmake --build ../build/debug --target blackbird --parallel 6
```

Then build and open Oxcart:

```sh
cd ~/projects/bow_shock
python3.13 scripts/build-native.py
./scripts/oxcart https://news.ycombinator.com/
```

Select another executable with `--blackbird /absolute/path/to/blackbird`.
The launcher checks the ordinary Blackbird release build, debug build, retained
mainline build, then `blackbird` on PATH, selecting one whose help advertises `--application`.
An explicit `--blackbird` selection takes precedence.
`--data-dir` selects a dedicated browser profile and Blackbird session;
`--model` selects the Blackbird model. Provider authentication belongs to
Blackbird and uses its existing account configuration.

The panel shows the selected browser URL, conversation and a multiline composer.
**Read page** saves a complete native reading locally. **Send** shares its file paths with Blackbird after a fresh
reading when the checkbox is selected; **Steer** interrupts current work and
starts the replacement objective. Command+Enter sends. **Stop** cancels pending
capture and requests cancellation of Blackbird's active work. Ordinary native
browser navigation continues while the agent works.

**Extract** uses the composer objective (or a general extraction objective), saves
a fresh reading and starts a structured extraction using readings collected in
this visit. **Preview** opens the native result stage. Blackbird writes an initial
result, reads its actual rendered preview and makes one automatic revision.
Further revisions come from your corrections in the preview editor; selected
result text is included. Source links open retained capture text and highlight
document byte ranges when supplied. Human scrolling/expansion plus **Read page**
adds further states; the next manual correction can include those new readings.

**Save recipe…** lets you edit the full proposed approach and saves a new dated
recipe that becomes active for that page type. **Recipes…** shows all versions
and lets you choose one for the next extraction, including a historical version
or the generic pass. Selecting a recipe is explicit in this first implementation.
Every attempt keeps its exact recipe identity. Original readings, outputs,
previews, failed attempts and superseded recipes remain on disk. See
[the workspace format](docs/extraction-workspace.md).

Each reading is saved under the selected data directory's `readings/<capture-id>/`:

- `reading.bplist`: metadata, before/after frame trees, coverage and document file paths.
- `dom.bplist`: complete returned DOMSnapshot columns and indexed strings for every returned document.
- `documents/N.txt` and `N.blocks.bplist`: full UTF-8 layout-text views and columnar byte offsets, node IDs, links and bounds.
- `blobs/`: large string values with exact bytes and declared encodings.
- `README.txt`: the format description for Blackbird and ordinary file tools.

There are no text, block, link, node-count, response-size or elapsed-time harvest
caps. A 64 KiB string-placement threshold moves values to blobs without shortening
them. Captures publish after all files succeed; IO failures are explicit.
A text-projection error leaves the complete source tables available and marks that
view incomplete. The archive retains hidden nodes and form fields returned by
Chromium; readable text views skip hidden/password/input/editor regions.

Blackbird receives a small locator rather than an inline page dump and chooses
whole-file, line, byte-range or programmatic reads through its ordinary tools.
No chunk size is imposed by Oxcart. Images/network bodies, pixels, accessibility
and separately attached out-of-process frame targets remain outside this reader;
coverage is recorded. Loader-origin metadata does not establish effective window
origin. Page data remains separate from the operator objective.

The integration does not yet supply Blackbird with browser action tools.
Keyboard/mouse/scroll execution, network inspection/editing/perturbation and
automatic page-type recognition remain subsequent product work. Blackbird's ordinary
coding tools retain their usual agency.

Collection currently follows explicit readings; continuous capture, page-local
agent exploration and fitted empirical input profiles remain later work. The
bot inspects saved renderer text/source maps; the native stage supports human
visual inspection and exports PDF/RTF from the displayed document.

## Development

The operator's October 16 direction replaces the old catalog POC: develop on
live sites, investigate actual failures and fix them directly. The launcher
starts no local web server. The active native target compiles the live reader,
Blackbird binary client and conversation panel. Earlier catalog source/results
remain historical, including in-progress work that predates this change.

[The integration plan](docs/plan/live-blackbird.md) records current ownership and
interface. [The live-reader plan](docs/plan/live-observation.md) records its actual
capture behavior. Blackbird documents the
[wire contract](https://github.com/antimemeai/blackbird/blob/master/docs/APPLICATION_INTERFACE.md).

Production uses AppKit/Objective-C++ and the adopted matched CEF runtime.
Native Blackbird IPC uses length-prefixed BBM2 values. The retained Rust/Codex
adapter is bumped to Codex 0.162.1; Blackbird is the current browser conversation
integration. Runtime acquisition is recorded in `runtime/cef-macos-arm64.json`.
Use an installed Python 3.13+ for the development utilities.

Focused checks:

```sh
python3.13 tests/live_observation.py
python3.13 tests/blackbird_transport.py
python3.13 tests/extraction_workspace.py
python3.13 tests/extraction_controller.py
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
