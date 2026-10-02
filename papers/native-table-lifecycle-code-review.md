# Independent native lifecycle source/result review

2026-10-02. Root reviewed the lifecycle owner's diff in main.mm and
table_controls.{h,mm}, complete actual-process driver and direct report.
No blocking finding in this narrow unit. The once-per-run browser pin prevents
implicit replacement after selected-browser close. Epoch retirement now precedes
reader invalidation on navigation and renderer termination, so synchronous old
capture callbacks cannot reuse the decision. Empty saved-list availability updates
immediately; action methods reject pending Stop independently of their widgets.

Inspected the actual three-case green, final browser repeat and normal catalog
Save/reopen logs. Independently reopened all four fault-run SQLite stores read-only:
zero rows/commits and clean dirty marker matched their healthy table close/CEF
shutdown result records. Source confirms fixed crash/extra-window hooks require
named lifecycle smoke, output and validated owned loopback Amber startup. Stop
holds a real validated revision continuation, and the external driver checks exact
owned Rust PID/parent/database before suspending only that child; the app/helper
stay live under their existing budgets. Registered notification delivery exercises
real handlers, while physical sleep/wake remains untested.

The independent review does not rerun already-green unchanged traces or promote
this into arbitrary browser qualification, commit cancellation, physical input,
renderer cancellation or containment of descendants. Canonical whole-app build
and tandem integration follow separate reviewed units. Earlier availability
failures remain recorded rather than explained by successful runs.
