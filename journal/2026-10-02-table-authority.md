# Local table authority/evidence

2026-10-02. Assigned one whole conceptual unit: reviewed staging, exact commit,
real SQLite worker/lifecycle and conservative restart. Read current doctrine,
reviewed plans/design and operator Rust direction. Coordinated native observation
identity with the reader owner; library integration is a later controller task.
The [sub-plan](../docs/plan/table-poc.md) precedes code. Direct DB/process red
oracles precede implementation; detsim/mutants/heavier tiers remain deferred.

Implemented one caller-owned authority and bounded SQLite worker. Staging/
approval version and exact serialized bytes bind host-issued commit identities;
live scope recheck follows non-authority durable preparation, final admission
is serialized without IO blocking, and confirmed admission precedes atomic
rows/result. Stop preserves admitted work; deletion/expiry denies publication
and purges in-flight persistence. All six field states and selected source
provenance survive reviewed storage. Stage memory is session-only.

Verified primary rusqlite 0.40.2 docs/features, SQLite WAL/transaction contracts
and std File locking. Adopted exact rusqlite with defaults disabled and bundled
SQLite; actual libsqlite3-sys 0.38.2 contains SQLite 3.53.2 and its source ID,
recorded in dependencies.json plus resolved registry versions/checksums in
Cargo.lock. Kernel lifetime ownership excludes another live writer before
recovery. Dirty/clock-unknown old records remain denied; recovery requires an
explicit purge, not an inferred clock or automatic commit retry.

Initial red test construction failed because the library/API did not yet
exist; it was not a runtime conformance result. The implemented seven direct
DB/process oracles now inspect exact rows/states, real write-lock/Stop/deletion,
mixed-origin revocation, expired data, actual killed writers, missing durable
deletion intent, live-owner exclusion and explicit recovery. One ignored test
function is explicitly run as the child in those process tests. No deterministic
simulator, mutation run or higher-tier framework was added.

scripts/rigor passed on macOS: fmt, warnings-denied Clippy, 33 workspace nextest
tests, existing doctest, cargo-deny advisories/licenses/sources and locked release
build. [Integration API and limitations](../docs/experiments/local-table-evidence.md)
record conservative restart denial and managed logical deletion boundaries.
Independent review is pending before controller/UI integration; no native,
input/network/export or power-loss durability claim comes from this unit.

Independent review reproduced E-01/E-02/E-03. All are valid: retained clean
reopening was missing, a changed retention review silently reused long retention,
and failed closing IO could later mark dirty=0/Closed. These were implementation
failures, not acceptable POC scope changes. Added the correction sub-plan and
direct changed-retention/actual busy-timeout tests; both initially failed on
the reported traces before the fixes, then passed against real SQLite.

Fixed exact approval binding/reuse and cancelled clean-close after storage
failure, including unresolved DB/lifecycle checks. Added explicit native-clock
operations and same-boot durable deadlines. The root supplied an original actual
boot UUID/mach continuous-time producer; the worker independently queries it
after acquiring the DB lock and before COMMIT, not cached parent time. Clean
same-boot startup now reconstructs exact acknowledged rows/identities and purges
expired rows. Other boot/unclean/legacy data remain denied without silent replay.
No cached read path works in native-clock mode.

Native direct tests pass for actual clean child shutdown/reopen, exact saved
identity/content, actual deadline purge, clean incompatible boot quarantine and
an authority-starved writer whose lock is released after expiry. The last test
queries zero rows before resuming actor polls: expiry comes from the worker's
actual native query. No operator machine sleep was invoked; the independent
control/clock path under CEF overload/sleep remains a general-product gate.
Clockless current-run tests are development-only and do not satisfy reopening.
Corrected scripts/rigor is green: formatting, warnings-denied Clippy, all 39
workspace nextest cases (two fixture functions are ignored by default and
explicitly launched by their process tests), existing doctest, cargo-deny and
locked release build. The original reviewer must recheck E-01/E-02/E-03 before
the findings can be called closed. No additional dependency, simulator or
mutation framework was added for these corrections.

The original independent reviewer re-ran its actual SQLite probe and all four
targeted native-clock/process cases. E-01/E-02/E-03 are closed: exact clean
same-boot retained identities/content reopen, changed retention cannot reuse
old approval, and failed closing remains dirty after the lock is released.
The worker's fresh native query was also checked against actual actor-starved
expiry. The report retains native publication and independent control/clock
integration as open gates. Root integrated that reviewed status into the
experiment; no operator-machine sleep or general-browser outcome is claimed.
