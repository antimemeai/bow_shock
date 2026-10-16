# Human input: data and event semantics

2026-10-16. Operator requires measured typing, errors, pointing and scrolling,
including intended-to-mistaken-key probabilities and all relevant page triggers.
This extends the [earlier movement research](os-input-and-behavior.md) and
supersedes the old plan's blanket exclusion of modeled typing errors. No native
input was posted and no behavioral model was fitted in this research unit.

## Sources actually acquired and inspected

[Dhakal et al., CHI 2018](https://userinterfaces.aalto.fi/136Mkeystrokes/): acquired
the complete 1,572,785,433-byte keystroke ZIP and paper. Read the paper's collection,
instrumentation, preprocessing, metric and results sections; inspected the ZIP
README, columns and a deterministic 100-participant sample. Records include prompt,
final text, key identity and press/release timestamps. This supports joint timing
and error analysis; the task is sentence transcription, not ordinary browser work.
The archive contains 168,593 participant files; retain that observed count rather
than substituting the paper's participant total. The dataset's non-commercial,
attribution terms are distinct from the capture software's MIT license.

Also acquired the authors' [capture implementation](https://github.com/aalto-ui/136m-keystrokes/tree/98dcee94dc6c0464b35e8ca43d60e1b225cc621f)
at `98dcee94dc6c0464b35e8ca43d60e1b225cc621f`. Read `typingtest.js`'s key
handlers and `Keystroke.scala`. It associates down/press/up events, writes paired
timestamps on release and suppresses repeated alphabetic keydowns. Its exported
records are not a lossless browser-event trace. Preserve instrument behavior as
context; do not infer every native repeat or event order from this dataset.

[MacKenzie and Soukoreff, NordiCHI 2002](https://www.yorku.ca/mack/nordichi2002-shortpaper.pdf):
read the character-error alignment method. Multiple equally optimal alignments
can explain the same prompt/transcription pair; one chosen alignment is not
ground truth about the user's intended key. Preserve that ambiguity in estimates.
[Soukoreff and MacKenzie, CHI 2003](https://www.yorku.ca/mack/chi03.html): read the
error taxonomy and corrected/uncorrected distinction. Final text alone misses
errors that were corrected; retain the input stream and correction actions.

[Balabit dataset](https://github.com/balabit/Mouse-Dynamics-Challenge/tree/d00d6f779254a2a917deeab4a5b7a9e8643bd91e):
acquired the full archive at `d00d6f779254a2a917deeab4a5b7a9e8643bd91e`, read its
README and inspected every training CSV. These are remote-desktop administrative
sessions with record/client timestamps, coordinates, button and state. There is
no explicit target geometry or native macOS/trackpad calibration. Keep that
domain and recording-path difference visible. The archive has no LICENSE file;
public research availability does not select it for redistribution.

Read the relevant keyboard/input/composition sections of [UI Events, 2026-02-21](https://www.w3.org/TR/2026/WD-uievents-20260221/),
the input-type/cancellation tables in [Input Events Level 2, 2026-10-15](https://www.w3.org/TR/2026/WD-input-events-2-20261015/),
and coalescing/compatibility mapping in [Pointer Events Level 3, 2026-06-30](https://www.w3.org/TR/2026/REC-pointerevents3-20260630/).
The standards describe browser events, not measured human timing or proof of
the current CEF build's behavior. Confirm actual dispatch/default actions when
implementing the native executor and event observation.

## Direct inspection results

`python3.13 scripts/inspect-human-input.py` reads the preserved archives and writes
an immutable binary-plist inspection under `context/human-input-study/`.

| Scope | Observed result |
| --- | --- |
| Typing: first 100 numerically ordered participant files | 73,285 rows; 6 invalid timing/row records excluded from timing summaries |
| Valid key holds in that sample, including modifiers | median 102 ms; p10 64 ms; p90 165 ms |
| Consecutive printable keys within a sentence, in derived press order | 59,503 pairs; 9,431 have the next down before the previous up |
| Correction-related observations in that sample | 4,599 Backspace rows; 485 of 1,478 observed sentence sections have final text unequal to the prompt |
| Mouse: all training files | 10 accounts, 65 sessions, 2,253,816 rows |
| Mouse states | Move 1,926,971; Pressed 75,978; Released 75,978; Drag 79,393; Up 40,193; Down 55,303 |
| Mouse timing | 345,099 equal adjacent client timestamps; no decreasing adjacent client timestamps |

These describe the selected data, not a calibrated Oxcart profile. In particular,
prompt inequality is not a per-key mistake rate, and repeated mouse timestamps
must not be silently replaced with invented fine timing. No confusion matrix
or universal typo percentage was estimated. Original records remain unchanged.

## Consequences for implementation

Fit intended-key/context to observed-key probabilities with counts and uncertainty;
include insertions, omissions, transpositions, recognition delay and correction
episodes. Keyboard adjacency alone is not evidence of a pair's frequency. Keep
one coherent session profile rather than sampling a new typing style per key.
Use participants/sessions, not random events from the same session, to separate
fitting from held-out comparison. Identify remaining native device/task and
trackpad data gaps; collect scoped Oxcart traces when building that surface.

For actual site behavior, native events let Chromium handle keydown/up, legacy
keypress when emitted, input/composition, focus, pointer/mouse and scroll.
Record actual recipients, cancellation and resulting page/network changes.
Capture-phase observation alone cannot establish a later handler's final
default-prevention result. Intermediate errors can trigger suggestions, validation
or requests before correction. Connect behavior-profile identity and events to
the visit/attempt/recipe and preserved traffic; final field text is insufficient.

See [the implementation plan](../docs/plan/empirical-input.md) and
[acquisition/restoration manifest](human-input-manifest.md).
