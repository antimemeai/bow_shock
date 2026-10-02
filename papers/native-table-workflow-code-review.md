# Native page/table workflow independent review

2026-10-02. Preliminary source review of root's `table_controls.h/.mm`, the
BrowserClient/AppKit join in `main.mm`, owned fixture service/launcher and joined
CEF/SQLite test. This review does not own their implementation or the separate
native table-connection unit. Read the written workflow subplan, exact table wire
and evidence design. The actual initial CEF red is retained in
`context/runtime/native-table-workflow-red.log`; strict ObjC++ syntax success is
construction evidence, not joined acceptance. No CEF app or keychain operation
was launched by this review.

The exact immutable Review object is retained and passed back to approval, with
its content string displayed unchanged. Reads are labelled saved original
captures rather than current page evidence. Guarded reply assignment checks the
actual native publication guard again, and saved success waits for committed
status plus a guarded read. Six source states have separate text presentations;
private field data are withheld. Healthy close remains asynchronous in the live
CEF loop and teardown joins only afterward. These are positive source facts;
actual joined behavior and supported N3 workload remain to be demonstrated.

## NT-01 — High: independent Stop fence waits for the Rust acknowledgement

`stop:` retires the UI and submits urgent Rust Stop, but calls the independent
control helper's `fenceToGeneration:` only inside the `stopped` callback. A
stalled Rust clock/stdout path thus delays the independent fence, contrary to
this unit's stated immediate native Stop contract. `_stopping` only disables the
Stop button: `updateButtons` excludes `_closing` but not `_stopping` from general
availability. An older ordinary completion clears `_busy` before its epoch check
and can re-enable Observe while Stop/fence reconciliation is still pending.
There is no demonstrated OS input escape: the helper is currently control-only.
The dependency nevertheless blocks promotion of the promised independent Stop.

Trace: hold Rust's Stop reply; click Stop; deliver an old observation/review
completion. The UI decision is retired but helper generation remains old and
Observe becomes available before Stop completes. Required correction: request
both channels immediately, conservatively use the sole caller's predicted next
validated Stop generation, block all availability while reconciling, and require
exact Rust/helper agreement before enabling anything. A mismatch/lost result
closes both rather than fabricating agreement.

Direct oracle: with the actual Rust child held before reply, invoke the same
native Stop action and inspect the actual independent helper fence before Rust
resumes. Deliver an old ordinary callback and require all relevant buttons still
disabled. After resume require exact generation agreement; admitted DB outcomes
stay correlated/uncertain rather than being called zero-write on the UI epoch.
Root accepted this disposition; source correction/recheck is pending.

## NT-02 — Medium: displayed data lack the promised activation/wake check

The only ongoing revalidation is a default-mode 100ms NSTimer. There is no app
activation or workspace wake handler. Existing source/list text can remain
visible after expiry while that run-loop timer is delayed, and activation does
not itself clear/revalidate it. New reply checks do not revalidate an old display.
This is a local managed-display lifecycle gap, not a model/export leak.

Trace: display a short-lived guarded saved result, leave default timer mode or
pause the app past its deadline, then activate/wake before its periodic timer
runs. The cached source remains. Add actual activation/wake handlers that check
a fresh witness or retire unavailable display/list state before actions resume;
keep the periodic check as maintenance. The claim is live UI handling, not
instantaneous removal of cached window pixels while the entire process is paused.
Direct oracle: actual short retention, delayed default timer and activation/wake
notification; expired text/list/approval disappear, valid saved rows retain their
actual original deadline and cannot acquire a new lease. Root accepted the fix.

## NT-03 — Medium: browser replacement can reuse a reader for a different surface

`attachBrowser:` replaces `_browser`, while the lazy `_reader` remains bound to
the browser used for its first capture. BrowserClient forwards load/start/end and
renderer callbacks from every browser without matching the selected identity.
OnBeforeClose retires only the separate bootstrap observation until the last
browser closes. This permits another browser's load to mark `_loaded` and a
subsequent Observe to use the old reader despite a different `_browser`.

Trace: capture owned Amber in browser A; attach/load browser B with Birch; invoke
Observe. The existing reader still captures A, while the UI has switched its
browser pointer/load state to B. Closing A while B remains can also leave the
reader referring to the retired surface. Source IDs are not fabricated, but the
human-selected observation target is wrong/unavailable.

Bind the first selected owned browser explicitly, match every lifecycle event,
and close/retire that reader when its surface closes. Additional browsers may
remain human-browsable but must not silently retarget this table workflow. Direct
oracle: two actual CEF browser IDs with distinct known catalog values, plus
selected-browser close while the other remains; no cross-surface capture or
stale-reader dispatch. Root accepted this scoped correction.

## NT-04 — Medium: approval is incorrectly displayed as commit admission

The approve callback sets status to “Save admitted” before calling
`commitApproval:`. `table_approved` allocates an exact Preparing correlation; it
has not dispatched preparation or crossed final admission. A queued/stalled
commit can still be cancelled with zero rows. The later status loop correctly
waits for committed/read, but cannot repair the earlier lifecycle claim.

Keep the label queued/pending until actual status distinguishes admission;
never infer an irreversible effect from approval/correlation. Direct oracle:
hold commit transport after approval, assert the native label remains pending,
issue Stop, and inspect rejected/deleted status plus actual zero SQLite rows.
Root accepted changing this label.

## NT-05 — Medium: repeated Observe discards staging identities until the run fills

Every Observe retires and forgets `_stage`, then creates a new `table_stage`.
Unapproved prior stages remain in the reviewed Store, which has four staging
slots. The fifth observation without a save hits that finite capacity. The UI
then says “Observe again”, but the next observation cannot recover capacity in
this run. This is a concrete lifecycle/usable-recovery problem, not a request
for unbounded storage or a new general policy engine.

Reuse an existing editable unapproved staging identity with explicit revision
when replacing source, or show a truthful session-full/restart disposition.
Never revise a terminal/admitted stage or silently retry an unknown commit.
Direct oracle: five successive actual Observe→review cycles with zero commits;
inspect actual zero DB rows and require either valid exact revised review or
an actionable session disposition, not endless rejected Observe retries.
Root has been notified; disposition/source correction remains pending.

## Acceptance still pending

The current joined smoke covers automatic Amber/Birch Save and clean same-boot
reopen, with independent SQLite row/batch/dirty checks. It does not yet exercise
these UI retirement/Stop/activation traces, changed human retention selection or
show the exact displayed review string equals the stored review bytes. Those
must be direct joined checks where claimed; backend/connection tests cannot
substitute for the UI action path. Record the qualified owned workload and
actual callback/UI/memory/control observations before earning N3 support.
General observation, models and delegated OS/network effects remain outside
this unit. Corrections and actual joined green will be appended after recheck;
this preliminary report is not whole-unit acceptance.

## First correction source recheck

Rechecked the landed source rather than treating the proposed dispositions as
completion. NT-01 is corrected at source: `updateButtons` excludes `_stopping`
from ordinary availability, and Stop enqueues both Rust Stop and the conservative
next-generation helper fence without waiting for either acknowledgement. Each
reply must match `_requestedStop` exactly; both flags are necessary to re-enable
controls, and disagreement invalidates both connections. The control parent's
canonical decoded reply actually includes the checked `stop_generation` key.
An older callback clearing `_busy` cannot defeat the pending-Stop availability
gate. No delegated input capability is added.

NT-02 is corrected at source by main-queue app-activation, workspace-wake and
session-activation handlers that conservatively retire the displayed review,
source and saved list. Their observers are removed on close. This retires valid
displays too and requires a fresh Observe/Refresh; it never extends a guard.

NT-03 is corrected for the reported stale-reader trace: attachment does not
replace a live selected browser; load/end/renderer/close callbacks all compare
that selected identity. Closing it retires display and closes/releases its
reader. Existing extra browsers cannot switch the target through their load
callbacks. A later newly-created browser can currently bind after selected
close; root has been asked to clarify that scope against the "other windows
remain manual" label. That path constructs a new reader rather than reusing
the retired one.

NT-04 is corrected at source: approval now displays "Save queued; waiting for
durable table acknowledgement". The later status/read sequence remains the
only saved-result publication path.

These four findings are source-closed for their original traces, with the
direct joined runtime checks above still required before whole-unit acceptance.
NT-05 remains open at this snapshot: Observe still loses an editable staging
identity, and capacity rejection still recommends another Observe. No CEF app,
keychain operation or implementation mutation was performed by this review.

## Draft-stage correction source recheck

NT-05 is now source-closed. `_draftStage` survives retirement as correlation
metadata; a fresh native capture explicitly revises that never-approved stage
instead of silently allocating another. An accepted staging reply preserves
its ID even when its UI epoch was retired, without restoring page text or the
old review. Save clears the draft identity **before** approval dispatch: an
accepted approval with a lost acknowledgement cannot later be automatically
revised and invalidate/delete its possible save. The actual Store revision
rejects expired or terminal stages, and does not extend the original source
deadline. Rejection now gives clean-restart guidance and the panel states the
finite four-retained-table limit.

The promised direct five-observation, changed-retention and Stop path remains
pending. Require exact review version/retention replacement and actual zero
rows before any Save, in addition to successful repeated capture. This is a
source closure, not a substitute for that actual child/UI/SQLite oracle.

## Joined-oracle and workload source review

The draft smoke now invokes five actual Observe actions plus the retention action,
records six immutable review versions on one stage, and calls the same Stop action
as the native button. Its Python driver checks versions 1–6, the changed retention,
and independent zero SQLite rows/commits before the first Save. This directly
attacks NT-05 and draft retirement rather than merely checking an internal counter.
The original NT-01 held-Rust-reply and old-callback availability trace, activation/
wake and two-browser traces still require their own evidence where claimed.

**NT-06 — Medium, oracle: exact displayed bytes are not sampled from the view.**
The save smoke records `_review[@"content"]` as `displayed_review_content`, then
compares it to SQLite. A display-only transformation or incorrect `_exact.string`
assignment would leave that comparison green. Record the actual text view string
at Save. The independent SQLite comparison is otherwise the correct direct byte
oracle; this needs no additional testing layer.

**NT-07 — Medium, oracle: any failed growth capture is treated as a host boundary.**
The growth driver currently accepts any status other than `partial` as reaching a
configured host boundary. A `native_method_failed`, origin/identity failure or
transport failure would satisfy it too. Require an identified configured host
limit/waiting-deadline reason for this claim, or report the unrelated failure
as an operational failure without declaring that boundary measured.

The workload instrumentation correctly records actual continuous Stop target,
handler and both acknowledgement times with the independent helper active. It
uses the human Stop method and adds no input posting. RSS is correctly labelled
an observed sampled process-tree peak, not a hard bound. Catalog qualification is
limited to its measured 100ms target; arbitrary engine traversal is not claimed
cancelled or bounded. `stop_during_capture` is recorded but not required: a fast
capture that finishes before the 20ms Stop only proves ordinary live control
servicing. A claim of in-flight reader Stop handling needs an actual true case.
Actual joined/growth execution remains pending; these are source-review results.

## Final source snapshot recheck

NT-06 and NT-07 are source-closed: the smoke samples the actual `_exact.string`,
and the growth driver requires a named configured reader host-limit reason.
The exact view is noneditable plain text. Semantic source now iterates every
retained row; each field choice highlights its recorded literal fragment range
in the native view, without using old node IDs as current geometry. Review and
source assignment retain fresh publication checks. The expiry timer runs in
common modes in addition to activation/wake retirement. Stop requires both
initialized connected links, so initialization cannot produce an independent
helper-fence failure from an unavailable control connection.

The joined driver now preserves its actual CEF JSON, diagnostics and database
artifacts on success and failure. Final source review found no additional
blocking defect for this first owned-catalog slice. Runtime evidence still
pending at this snapshot must distinguish actual joined catalog actions from
unexecuted activation/multibrowser/held-reply fault paths and from general reader
or delegated-input promotion.

## Final disposition — accepted first owned-catalog POC

Reviewed final source SHA-256
`846795657caae114f13c350ce25cfc8e43e83865d7f019243bfae66b51666683`
and actual completed runs. All seven reported findings are corrected at source.
Accept this unit for the fixed immutable Amber/Birch catalog workflow, with its
explicit root-only partial coverage, four-retained-table budget, source guards
and absent model/input/network effects. This does not earn general reader,
coordinate/input, model/Codex or full P8 promotion.

The initial joined run reached the exact SQLite/display assertion and failed:
the sampled `NSTextView.string` was a mutable backing reference subsequently
cleared by retirement. Root corrected the actual sampling boundary with `copy`;
the complete oracle then passed without weakening checks or time budgets. Both
runs' artifacts remain under `context/runtime/native-table-workflow/`.

Completed evidence is `context/runtime/native-table-workflow-green.log` and
`run-ljhopkrs`. Four actual CEF cycles exercised five Observe actions, six exact
versions on one never-approved draft, changed retention, actual Stop retirement,
zero SQLite rows/commits before the first Save, Amber/Birch Save and clean
same-boot reopen of both identities. The driver's independent SQLite checks
matched row payloads, displayed bytes and stored Review strings, dirty=0 and
owned controller/helper PID absence after exit. The review additionally opened
that quiescent database read-only and independently confirmed two committed
records/two rows, both exact display strings (3,723 and 3,777 UTF-8 bytes), saved
batches, six draft versions, the cleared Stop display and dirty=0.

Completed narrow workload evidence is `context/runtime/native-capture-work.log`
and its eight-case `measurements.json`. Actual Stop occurred **during** both
catalog captures. Amber/Birch maximum measured AppKit gaps were 17.495/18.313ms;
Stop handler delays were 0.869/0.313ms, Rust acknowledgement delays
8.461/8.889ms and helper acknowledgement delays 11.426/6.494ms, measured against
the scheduled native continuous-time target. All satisfy the selected 100ms
catalog target. These are actual same-method UI/child servicing measurements,
not physical keyboard/listener or OS-effect-drain evidence.

Growth reached identified host boundaries: 8,192 leaves produced
`callback_copy_or_queue_limit`; 512KiB text produced `string_limit`. Actual
eight/32 alternate-origin child-frame cases reported CEF frame counts nine/33,
root-only partial coverage and withheld children, with general observation
false and clean close. Their Stop ran after capture, so no in-flight claim is
made for those cases. These records establish child-frame workload/coverage;
they do not independently establish per-frame renderer-process placement.
Sampled RSS is approximately 197–216MiB for the app and 825–1,006MiB for the
owned process tree, not a hard allocation bound. Discard/timeout does not claim
to cancel Blink work. Larger or arbitrary pages remain outside supported capture.

Held-Rust-reply plus late ordinary-callback availability, short-deadline app
activation/wake, selected-browser close with a second browser and precommit
transport-hold UI traces are source-reviewed corrections, not executed joined
fault qualifications in these runs. Preserve that limitation in promotion and
release claims. The separately reviewed transport/authority oracles retain
their own scope; they are not relabelled as these UI executions. This reviewer
performed no CEF launch, keychain access or product-source mutation.
