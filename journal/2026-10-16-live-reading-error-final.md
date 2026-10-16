# Repair the actual model tool failure and retain failed turns

The previously waiting live browser runs finished during the AFK work. Python.org
captured a complete native reading (one document, 2199 DOM nodes, 299 text blocks,
4038 rendered UTF-8 bytes); its real Blackbird turn failed with invalid_range.
The older Wikipedia run had the same failure. The OS reported Safe Storage
userCanceledErr; the Python.org page still loaded/captured. No permission was
automated. Earlier statements that the runs were still waiting are superseded.

Inspected the retained Blackbird audit with its matching mainline binary. The
first actual exec proposal included task_id="", a valid command, empty argv,
timeout_seconds=120, yield_ms=1000, pty=false and output_max_bytes=180. Blackbird
incorrectly looked up the optional empty task binding as a real task. Fixed only
the empty case in an isolated worktree from master; a direct native regression
reproduced invalid_range before the predicate change and passed afterward.
Nonempty unknown tasks remain rejected before dispatch. Updated tool guidance.

The failure exposed another actual defect: Blackbird emits error then final for
an admitted failed turn, while command rejection emits error alone. Oxcart ended
the extraction on error, quit the live check and skipped final artifact capture.
Blackbird errors now include final_follows, true for admitted failures. The native
connection keeps ownership until final, and the extraction coordinator retains
the actual error while waiting, then saves submitted bytes, response, failed
outcome and note before finishing. It does not start a tweak after engine failure.
The written unit is `docs/plan/error-final-preservation.md`.

Native process checks cover error/final ordering and cancellation while the failed
turn remains active, alongside rejected steering and child shutdown. Coordinator
checks now include an actual saved submission followed by error/final; received
bytes, response, actual invalid_range note and failed metrics survive. Both pass.
The controlled coordinator artifacts are under
`context/build/controller-checks/621dc4c9-aee3-4da7-b857-fcba06cb2b90`.
The final six-scenario run is under
`context/build/controller-checks/a491353a-70ec-40da-ab1a-9c92214e4d36`;
command rejection has its own event/count and rejected outcome, distinct from
an admitted engine failure. It preserves attempt files without inventing an
admitted final or triggering an automatic retry.

Added `scripts/extract-reading.py` plus a native AppKit driver to run the real
coordinator/renderer/Blackbird against a retained reading without another browser
or Keychain prompt. Each invocation compiles a unique driver path and publishes
a new run record. It can reuse a workspace without replacing earlier runs.
The first actual run used the repaired Blackbird against the original Python.org
source archive, not a synthetic site:

`context/runtime/retained-extractions/2772d201-7bef-4404-abb5-e4681cfc689a/`

Initial attempt `FFAE0C27-B6FE-4EB7-8D65-0DB32F2C18DA` completed and rendered
47 blocks. Its single tweak `A8A2797D-C81A-4A5C-BAC2-BD8F9793366A` completed
and rendered 56 blocks. Both saved binary results and actual text/RTF/PDF/source
maps; zero validation/read errors. Inspected the actual initial PDF as an image.
The final preview has 22,208 UTF-8 bytes, with organized resource/documentation
links and source mappings. Metrics snapshot is
`extraction/reports/836e7039-0857-4c49-b38c-e6a03fc09a7d` in that workspace.
Model times were 225.341 and 251.112 seconds. This is a real successful pipeline
run, not a claim of collection completeness. The tweak reports needs_help with
four gaps, including a concrete discrepancy between displayed 2026 PSF-news
dates and paths containing july-2024-newsletter; original values remain intact.

One output incorrectly described a native plist date as timezone-unspecified.
Clarified FORMAT.txt guidance: plist dates are absolute UTC, Python's default
naive datetimes represent UTC, and a workspace visit date is not necessarily
the earlier reading's capture/publication date. Earlier artifacts remain unchanged.

Default Blackbird discovery now prefers the retained mainline runtime so an
independent TUI development build cannot silently replace the selected interface.
Added `scripts/build-blackbird-runtime.py` to export an owned Git revision/tree,
retain its archive and earlier source, materialize the relocated shared-doctrine
link, record native source metadata and build all runtime resources at stable
paths. This avoids leaving a temporary worktree as the executable's workflow/
runner location. Fixed the export's aware-datetime serialization during its direct
build; failed partial records/stages and original archives remain retained.

The repaired Blackbird passes empty_exec_task, application, application_cli and
tasks. Its repository's full commit hook additionally ran 228 tests; 227 passed,
and its only failure was the required Microsoft tui-test executable not yet
installed in the fresh worktree. Installed the already adopted pinned development
tool and resumed normal commit checks. No new library or TUI implementation work.
Issue arconaut-6fc records the fix and actual success; bd backup was run.

The default and isolated Oxcart native bundles build/sign successfully. Practical
browser traffic editing, additional target coverage and empirical OS input remain
follow-on work; no native actor or complete Facebook extraction is claimed.
