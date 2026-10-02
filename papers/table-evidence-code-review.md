# Local table authority/evidence independent code review

2026-10-02. Read BLACKBIRD, project guidance, the table construction subplan,
local evidence experiment report, authority-conformance plan and X1. Reviewed
`crates/evidence` source and direct DB/process tests. Product code was not edited.
Detsim, mutants and heavier tiers remain operator-deferred. This is the A1–A4
table unit review, not a request for another grant manager or broader framework.

Three high-severity findings were found and are now corrected and independently
rechecked, as recorded below. All three were reproduced against the
actual compiled Store and SQLite, using the ignored local probe
`context/review/table-probe.rs`. The intended P3 outcome remains exact human
review → commit → retained-result reopen; rejecting every saved result is not
completion of that outcome.

## E-01 — High: every retained clean restart is unusable

`worker.rs:164` quarantines any database containing commits, independent of a
clean shutdown. Startup never loads committed identities/content into Store;
`read` consults only the new run's initially empty in-memory commit map. The only
available recovery path destroys all old rows and registry entries.

The probe commits one exact `retained-marker` row with a reviewed 60,000 ms
retention, waits for actual acknowledgement, closes through `Health::Closed`,
and opens under a fresh run while the retention is still valid. The independent
SQLite query finds one saved row; managed health is `RestrictionUnknown` and
`read(original_commit_id)` fails. The existing positive test expects this
failure, so it enshrines an outcome contrary to X1's explicit commit/reopen exit.

The authority plan permits uncertainty to deny access; it also expressly
requires permitted retention survivors and warns against considering a path
that rejects everything correct. The construction subplan's blanket denial
does not supersede the reviewed goal. Merely removing `records != 0` is unsafe:
expiry and exact immutable result reconstruction must be implemented together.

Implement a concrete retention clock witness and clean restart reconciliation.
A macOS first slice can carry the native parent's actual boot-session identity
and `mach_continuous_time` sample, persist the same-boot continuous deadline,
and validate continuity before loading exact durable committed results. The
installed Apple SDK's `mach/mach_time.h:58–62` explicitly says continuous time
advances during sleep; `sysctl -n kern.bootsessionuuid` returns a boot UUID on the
current machine. These are feasibility evidence for that approach, not proof
that a yet-unwritten adapter correctly enforces it. Unknown/different-boot and
unclean runs may remain denied pending explicit reconciliation; a clean
same-boot permitted survivor must have a nondestructive usable path.

Direct acceptance needs actual clean process shutdown/restart with exact
original identity/content, expiry with denied/purged actual rows, and unknown
clock/unclean restart negatives. Do not infer elapsed retention from a wall
timestamp alone or present recovery purge as retained-result reopening.

## E-02 — High: a new retention review approves old content

`lib.rs:415` returns an existing staging approval whenever one exists, after
checking that the newly supplied Review matches the current stage. It never
checks whether that new review content equals the existing immutable Commit's
content. A retention change modifies review bytes without modifying the staging
version, so both checks independently succeed while binding different content.

The probe approves the original stage at 60,000 ms, reviews and approves that
same stage at 100 ms, then commits the second returned handle. Both handles
resolve to the same CommitId. Actual SQLite `commits.review` still contains
`"retention_ms":60000`; managed `read` remains successful after 150 ms. The
person's second approval therefore commits longer retention than displayed.

Bind approval identity to the complete exact review. Reuse an existing approval
only when its exact bytes/version match. A changed retention must either be
explicitly rejected with an actionable requirement to revise/review, or receive
a new exact reviewed identity with the old preparation safely revoked before
admission. Never silently substitute the old result. Add direct DB/content and
expiry checks for changed retention, plus same-content duplicate success.

## E-03 — High: a failed closing write can mark the run clean

`close` schedules `global_job = Some(Work::Close)`. A subsequent worker error
sets `Health::Failed` in `fail` but leaves that queued close intact. `dispatch`
does not require healthy closing state for the global job. After the failing
commit's inflight flag clears, later polls send Close, whose worker transaction
writes `meta.dirty=0`; completion then reports `Health::Closed`.

The probe waits for durable admission, acquires a real SQLite `BEGIN IMMEDIATE`
writer lock, and calls close. The row write reaches the two-second native busy
timeout: Store reports `Failed`, the commit reports `Unknown`. After rollback
releases the lock, later polls report `Closed`; independent queries show
`meta.dirty=0` and the unresolved commit still `state='admitted'`.

This violates the authority plan's explicit rule that a storage fault cannot
produce a clean shutdown marker, and can mask unresolved failure when startup
reconciliation is repaired for E-01. Cancel/withhold clean-close dispatch after
a failure and require actual healthy writer quiescence plus resolved lifecycle
obligations before clean persistence. Keep actionable failure and dirty status
until conservative recovery or verified reconciliation succeeds. Add the real
writer-timeout-while-closing oracle; releasing the lock must never turn that
failed run into a clean one.

## Evidence reproduction and scope

The ignored probe was built against the already compiled reviewed Rust library
and pinned bundled SQLite, then run once:

```sh
rustc --edition=2024 context/review/table-probe.rs \
  --extern bow_shock_evidence=target/debug/deps/libbow_shock_evidence-5c02c08f108a8d5a.rlib \
  --extern rusqlite=target/debug/deps/librusqlite-441c02cdf334fcc9.rlib \
  -L dependency=target/debug/deps -o context/review/table-probe
context/review/table-probe
```

The target artifact filenames are run-specific; find current equivalents with
`rg --files target/debug/deps`. Probe source constructs one grounded marker
batch through the public API, queries the real DB with rusqlite, and uses actual
sleep/native SQLite lock timeout. Its output confirmed all three violations in
about three seconds. No whole rigor stack repetition or production fault toggle
was introduced. SQLite independently confirms committed review bytes, row count,
dirty marker and durable commit state; in-memory status alone is not the oracle.

Other inspected paths preserve ordinary Stop versus stronger deletion, defer
IO to the bounded worker, fence late results and avoid automatic commit retry.
The existing kill/restart and admitted-write/deletion tests provide useful
direct evidence for those particular paths. They do not cover the permitted
clean survivor, changed retention or failure-during-close traces above. Native
clock transport, UI mapping and later browser/provider effects remain separate
integration work.

## Independent correction recheck

Read the accepted correction subplan, changed evidence API/worker/clock source,
native producer/subplan/journal and the new direct tests. Recompiled the ignored
independent probe against the corrected library, with actual clock samples from
`context/build/native/bow_shock_clock_probe`. The corrected probe additionally
links the existing serde_json rlib to decode that original native executable's
output. It replaces the original failing assertions with the intended direct
DB outcomes; it does not modify production code or use a fabricated clock.

**E-01 corrected.** `open_with_clock` reconstructs committed results only after
the worker validates a clean same-boot database, current native clock, persisted
deadline, exact review and actual ordered row payloads. The independent probe
committed and cleanly closed its marker, opened under a new run, then obtained
the exact original CommitId, batch and unchanged persisted review bytes.
Clockless cached `read` was denied. The actual-native-clock integration tests
also launched a real separate child for clean commit/shutdown, then reopened
its exact result in the test process. Expired actual rows were removed, and a
clean database with an incompatible persisted boot remained denied with its
retained row present. This earns clean same-boot reopening, not cross-boot
deadline reconciliation.

**E-02 corrected.** An existing approval is reused only when exact content and
version match. The independent original 60,000 ms → 100 ms review trace now
rejects the changed approval explicitly. A same-content duplicate resolves to
the same identity, and actual SQLite has one immutable commit with the original
reviewed retention. No shorter review is silently acknowledged as an old one.

**E-03 corrected.** Failure clears queued global work; Close additionally
requires healthy Closing state, terminal resolved authority records and a DB
with no unresolved commit/deletion intent. The independent real SQLite lock
trace again timed out the admitted writer during close. After lock release and
100 additional polls it remained Failed/Unknown, with actual `meta.dirty=1`
and the admitted unresolved DB record still visible to diagnostics. The queued
clean close no longer overwrites the failure.

The SQLite worker's `native_gate` queries the actual owned clock probe after
acquiring the transaction write lock and again immediately before calling
COMMIT. It verifies boot/nonregression/deadline and rolls back while setting the
lifecycle fence if expiry wins. The direct actor-starved writer test held a
real SQLite writer lock beyond the saved native deadline, released it without
another authority sample, and found zero row persistence before the authority
resumed. Its admitted record was then actually purged. Probe subprocess output
and supervision are bounded and run off the authority thread. The actual sample
and native COMMIT are separate operations; this does not claim atomicity of OS
time sampling with filesystem durability.

Verification commands: the corrected independent rustc/SQLite probe; then
`BOW_SHOCK_NATIVE_CLOCK_PROBE=/Users/patrickbeam/projects/bow_shock/context/build/native/bow_shock_clock_probe cargo test --locked -p bow-shock-evidence --test native_clock -- --nocapture`.
The latter passed four direct tests; its fixed child fixture is ignored in the
outer listing and is explicitly executed by the clean-process test. The whole
rigor stack was left to the owner rather than repeated in review.

Disposition: **E-01, E-02 and E-03 closed after direct independent rechecks.** No
finding was waived as a POC limitation. No additional production finding arose
in this correction scope. Native caller freshness/publication mapping,
independent clock/control operation under a sleeping or overloaded CEF UI,
cross-boot uncertainty and later browser/provider effects remain their separate
explicit integration gates; this review does not certify those behaviors.
