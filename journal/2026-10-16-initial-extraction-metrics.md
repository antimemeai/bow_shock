# Initial extraction metrics

Fast-followed the native extraction/preview/recipe unit with an owned standard-
library metrics utility. `scripts/extraction-metrics.py` reads the actual native
event and artifact history and saves a new dated UUID report in binary plist
and text. Earlier reports and source events remain untouched. Reports retain
the exact source event filenames for later study.

Counts cover visits, unique readings/text bytes, reading failures, attempt phases,
model outcomes, previews, validation failures, cancellation and recipe activation.
Per-attempt stage durations use native uptime events within the same host run;
missing/incomparable intervals are marked unavailable. Bot assessment, model turn
completion and operator recipe activation are separate fields. No precision,
recall or coverage percentage is invented from event counts.

Extended the controlled native coordinator check to retain its actual workspace
and run aggregation over it. Positive initial/tweak/manual execution, missing
outputs, Stop and malformed-but-binary result fields have direct known outcomes.
The first check found that cancelled model turns had an error note named like a
validation failure. The host now writes outcome-note.txt for noncompleted turns;
aggregation also interprets historical notes with their actual model outcome.
Invalid issues-field types remain unavailable metrics, not crashes or fake counts.

All four native coordinator/metrics cases now pass. Python utility compilation
and scoped diff checks pass; the final signed native bundle was rebuilt for
the outcome-note distinction. The earlier workspace/renderer and complete-reader
checks remain passed, with no unrelated suite rerun. No new library was adopted.

Ran a report against the actual pending Python.org workspace: one opened visit,
zero completed readings/attempts, consistent with its macOS Keychain wait. That
report is retained alongside the run; it does not establish a completed live
extraction. The live run is still waiting for the operator's OS Allow action.
No Keychain/trust/encryption or network configuration was changed.

This is the first report/tooling slice. The richer native metrics view,
bidirectional traffic capture/editor and empirically fitted input executor
remain subsequent implementation work. Unrelated clock changes are untouched.
