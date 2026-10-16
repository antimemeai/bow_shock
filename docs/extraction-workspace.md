# Extraction workspace and preview

The native application stores extraction data under `<data-dir>/extraction/`.
All persistent host artifacts are native binary property lists or exact text/
binary files. Foundation/AppKit and the existing Blackbird file/program tools
are used; no new library or browser-action interface is introduced.

## Visits and attempts

`visits/<id>/visit.bplist` records a visit's identity, initial URL/title and date.
Navigation starts a new collection. Explicit readings are linked through
`reading_added` events; the complete reading directories remain in `readings/`.
Human scrolling and expansion plus **Read page** can accumulate successive states.
There is no continuous observer in this unit.

Each `attempts/<id>/` contains:

- `attempt.bplist`: immutable objective, phase, visit, exact reading references,
  selected recipe identity/path and any predecessor/correction.
- `inputs.bplist` and `FORMAT.txt`: input references and the full output contract.
- `work/`: the model's working files, including its `result.bplist` submission.
- `received.bplist`: exact submitted bytes retained at turn completion, even if
  parsing or validation fails; a missing submission remains a reported failure.
- `response.txt`: the model's final response; `validation-error.txt` for rejected
  completed output or `outcome-note.txt` for cancellation/failure.
- `preview.txt`, `preview.rtf`, `preview.pdf`, `preview.bplist`: actual native
  renderer output and source/character mappings, including an error preview when
  the submitted result is invalid.

The initial model turn gets one automatic `tweak` turn that reads the actual
saved preview. Missing/malformed output can use that one revision; continued
failure returns to the operator. A manual correction creates one new `manual`
attempt and includes any new explicit readings from the same current visit.
Earlier attempts keep their original inputs. A correction to a previous visit
uses its retained sources. Stop cancels automation and retains working/submitted
files. App shutdown waits for queued extraction IO and Blackbird closure.

The stage's attempt menu covers the current run; earlier runs remain inspectable
in the stored workspace. Recipe history is loaded across app restarts.

Failed admitted Blackbird turns emit an error with `final_follows=true`, then a
failed final. Oxcart keeps that request active until final and preserves any
submission, final response, outcome and actual error message. Rejected
commands instead report no following final. A failure does not trigger an
automatic tweak.
Commands rejected without an admitted final are recorded separately as
`command_rejected` with outcome `rejected`; metrics count these independently.

Reuse a saved reading without opening another browser/Keychain prompt:

```
python3.13 scripts/extract-reading.py /path/to/readings/CAPTURE \
  --blackbird /path/to/blackbird \
  --objective 'Organize the useful information and retain source links'
```

This runs the same native coordinator, renderer and real Blackbird file tools,
including the initial pass and exactly one tweak. It creates a fresh retained
workspace by default; `--data-dir` chooses one explicitly. New run records never
replace earlier records. Its native driver has a unique build path per invocation
so starting another extraction cannot replace a running executable.

`scripts/build-blackbird-runtime.py --repo /path/to/blackbird --revision master`
exports/builds a retained Blackbird revision with stable workflow/helper paths,
preserving its active Git checkout. Oxcart's launcher prefers that retained
mainline runtime; `--blackbird` still selects an explicit executable.

## Result format

The agent writes a binary plist with `format=oxcart.extraction`, integer
`version=1`, `title`, `blocks`, `issues`, `assessment` and `recipe`. `assessment`
is `ready` or `needs_help`; it is the bot's judgment, not a claim of collection
completeness. Empty output must report `needs_help`.

Supported blocks are `heading`, `paragraph`, `list`, `record` (arbitrary labeled
string values) and `table` (columns/rows). Every content block has an
`interpretation` (`observed`, `normalized`, `summary`, `inferred`) and nonempty
`sources`. A source binds an input `capture_id`, optionally a document index and
UTF-8 byte offset/length. Whole-capture references support metadata/full-DOM facts;
document ranges must fit that saved text view. The host rejects foreign captures,
invalid ranges and unsupported shapes; it preserves the original bytes.

Source links open archived text, highlight valid UTF-8 ranges, and identify
whole-capture metadata and full archive paths. Page/model text is rendered as
literal attributed text. AppKit lays out native tables; strings do not become
HTML, scripts or executable links. The bot can inspect the saved renderer text
and structured source map with its existing tools. Human visual inspection uses
the native stage; PDF/RTF preserve its displayed document for later study.

`FORMAT.txt` beside each attempt supplies exact keys and types. Use standard
`plutil -p` or Python `plistlib` to inspect the binary artifacts.

## Whole immutable recipes

`recipes/<id>/recipe.bplist` contains the entire recipe: page type, applicability,
complete collection/extraction instructions, unique ID/date, source attempt and
the prior active recipe's ID when superseding one. Saving a successor never
edits its predecessor. A separate `recipe_activated` event makes it active for
that page type after the new file succeeds. A failed activation preserves the
old choice and the complete unactivated successor. No patch chain is needed.

**Recipes…** lists current and historical recipes and supports explicit selection
for the next extraction. Choosing a historical recipe for a particular attempt
does not rewrite activation history. **Save recipe…** edits a complete candidate
in a sheet and creates a new active successor. The attempt manifest binds the
exact selected recipe; automatic revision keeps that same recipe even if the
next-extraction selection changes.

## Events and preservation

`events/<id>.bplist` contains dated, ordered stage events, a host-run ID and local
uptime. Events cover visits, readings, attempt/model/render stages, cancellation,
failure and recipe activation. The workspace has one serialized writer; sequence
numbers recover from the prior event history on restart. These are initial
instrumentation for the metrics/proxy fast follow, not semantic success scores.

The first metrics report is available with:

```sh
python3.13 scripts/extraction-metrics.py DATA_DIR/extraction
```

Each run creates a new `reports/<id>/metrics.bplist` and `metrics.txt`, retaining
the exact source event filenames. Reports include per-attempt stage intervals,
phases and recipe identity, model outcomes, validation errors, cancellation,
previews, source document text bytes and recipe activations. Missing stage events
or incomparable host clocks produce unavailable timing. Model completion, bot
assessment, error notes and recipe activation remain separate observations.
Corrupt or absent inputs are reported; counts do not infer collection completeness.

New artifacts use private files, exclusive publication and synchronization.
Failed publications retain their `.pending-*` files. Original readings, model
submissions, previews, corrections, recipes and activation history have no
automatic expiry or garbage collection. The model's in-progress `work/` files
are drafts; `received.bplist` and host artifacts are immutable snapshots.

## Run and direct checks

Build normally after closing apps using that bundle, or keep a current run open
and choose a separate build directory:

```sh
python3.13 scripts/build-native.py --build-dir context/build/extraction-final
./scripts/oxcart https://www.python.org/ --app 'context/build/extraction-final/Bow Shock.app/Contents/MacOS/Bow Shock'
python3.13 tests/extraction_workspace.py
python3.13 tests/extraction_controller.py
```

The native checks exercise actual filesystem retention/restart, failed activation,
source bounds, native renderer exports and initial/tweak/manual/Stop coordination.
Controlled model outcomes test the coordinator without a fake website. Actual
live extraction uses the ordinary native reader and real Blackbird engine:

```sh
python3.13 scripts/check-live.py https://www.python.org/ --extraction \
  --objective 'Organize project identity and documentation resources with actual link destinations.' \
  --expect-text Python --expect-preview-text Python \
  --expect-preview-text https://docs.python.org \
  --app 'context/build/extraction-final/Bow Shock.app/Contents/MacOS/Bow Shock'
```
