# Closed controller table service

Root corrected a documentation mismatch after the native adapter owner spotted
it: table_approve accepts the exact Review only, matching the production decoder
and direct process tests. PublicationGuard accompanies the review result and is
checked locally before native approval; it is not a forwarded input field.
Service source freshness and exact-content checks remain independent of that
local check. Independent service review is next before native/UI promotion.

The reviewed evidence unit now enters a closed trusted-native controller service.
The written sub-plan is docs/plan/controller-table-service.md. Read BLACKBIRD,
reviewed X1/native bridge plan, current bootstrap wire tests and evidence API.
Direct child-process tests were written first and run: all three fail against
current bootstrap with the table request rejected, before any claimed table
result. This is a real missing-service runtime red, not a compile-only red.
Actual SQLite/clock/backpressure traces become assessable once that service is
constructed. Existing borrowed deps only; no CEF launch or operator sleep.

Constructed one authority loop with bounded reader/writer and a single-flight
native-clock worker. Trusted CLI supplies the database/probe/owned origin;
request records have no paths, clocks or general method/JS capability. All table
operations consume monotonic IDs and actual fresh native samples; Stop runs
without waiting for a probe or pipe. Control acknowledgements can use an idle
writer during a clock query. Read/review/list wait for writer readiness and
revalidate exact data/deadline again, with actual PublicationGuard supplied for
native UI assignment/expiry checks. Partial started transport remains uncertain.

Native integration needs saved-ID discovery plus explicit source fragments and
capture intervals. Added small guarded evidence accessors and optional serde
fields with omission-preserving old exact bytes. Current native staging requires
actual intervals and raw observed fragments, while missing/inaccessible fields
remain absent; no guessed defaults or legacy cached-clock fallback. Controller
limits two rows/six fields/16KiB batch/24KiB review, exact opaque approval mapping,
eight-slot queues and two-second output handoff. Healthy table_close waits for
actual SQLite clean disposition. Transport faults stop and stay dirty.

Direct child/DB oracles cover six field states, exact review bytes and persisted
deadline guards, changed retention rejection, duplicate identity, fresh saved-ID
list and clean native same-boot reopen; nested unknown/positional/duplicate source
input has actual zero rows. Unread real stdout does not prevent expiry purge or
Stop cancelling a real lock-stalled preparation. Strengthened Stop's oracle to
require live child and actual Stop generation after unblocking, so mere process
death cannot substitute for cancellation. A real clock subprocess stall leaves
Stop acknowledgement responsive and terminates without creating a database.

The stall oracle initially found Stop acknowledgements incorrectly coupled to
clock-task completion; corrected that owner scheduling path. Concurrent freshly
compiled SDK producers also exceeded the deliberately unchanged 500ms runtime
clock supervisor before their first setup sample. Verify the actual producer
once during test setup (as existing evidence tests do), then runtime queries
remain new actual samples; do not reuse that setup witness or extend retention.
The five service process cases then passed concurrently. Full scripts/rigor
passed 44 workspace tests, warnings-denied Clippy, formatting, existing doctest,
cargo-deny and locked release build; two child fixtures remain intentionally
ignored by default and launched by their owning process tests. The final Stop
oracle strengthening reruns only changed service checks. Independent code review
is next; no CEF launch/keychain change, new package, simulator or mutant run.

Independent review found CT-01: real pending overflow left the configured clock
sleep child orphaned after controller exit. Accepted actual process ownership
failure; written correction subplan now covers shared query cancellation and
terminal quiescence, including SQLite query ownership. CT-02 distinguishes an
invented selected fragment from legitimate whole-cell provenance in the native
price projection. Read the report and original direct PID probe; no CEF launch.

Correction runtime reds reproduce the review: terminal pending overflow leaves
recorded PID44809 as PPID1 /bin/sleep after failed controller exit (that exact
fixture PID was cleaned); invented Ambiguous source receives table_staged.
ClockOwner correction registers active before checking cancellation, shares
ownership with every SQLite query, and keeps Child RAII kill/reap ahead of active
release. Terminal cleanup cancels then quiesces, warning once after two seconds
and remaining non-admitting if OS reap is unresolved. No blocked stdin/stdout
thread join returns to the authority loop. Direct greens require exact PID
absence after overflow and after broken stdout with both SQLite/control clock
children active. Forced OS death and descendant-retained stdout remain outside
this original non-forking producer contract, explicitly documented.

Ambiguous staging now accepts real whole-cell provenance only with a positive
container node and all nonempty candidates present literally; invented or
ungrounded selected fragments deny. Fragmentless legacy alternatives retain
compatibility. The native nullable node_id key is required explicitly. Direct
negative/positive process cases pass without changing saved exact bytes.

Two setup attempts were denied by the unchanged 500ms clock supervisor before
new script fixtures reached their intended fault state. Even an isolated new
wrapper showed this; compilation contention was not a sufficient explanation.
Verify actual fixture executable availability once during setup, then all runtime
witnesses remain fresh queries. A small nextest native-clock resource group also
limits unrelated concurrent SDK compilations to two; configuration checked
against [official test-group documentation](https://www.nexte.st/docs/configuration/test-groups/)
and actual nextest show-config. No runtime timeout, retention or retry was
relaxed. All eight service cases passed; original reviewer notified to rebuild
its separate target and independently recheck both findings. Final basic Rust
checks are in progress, with no additional package or verification framework.

Final corrected scripts/rigor is green: all47 workspace nextest cases (two
explicit child fixtures skipped by default and launched by their process tests),
fmt, warnings-denied Clippy, existing doctest, cargo-deny and locked release.
CT-01/CT-02 await the original independent recheck; this owner does not certify
its own review closure. No product/native file was launched or committed.
