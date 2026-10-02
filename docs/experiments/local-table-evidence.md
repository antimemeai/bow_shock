# Local reviewed-table library

2026-10-02. `crates/evidence` implements the first local table boundary, before
controller/UI integration. [The sub-plan](../plan/table-poc.md) owns its purpose.
No model, export, input or network capabilities exist here. The independent
[code review](../../papers/table-evidence-code-review.md) found three valid
failures in the first version; all three corrections passed independent direct
SQLite/process/native-clock rechecks. Controller/UI integration remains open.

The trusted controller creates one `Store::open_with_clock(path, run_id,
ClockWitness, probe_path)` for an application-owned local database and pumps
`poll_at(fresh_witness)` without waiting. The native parent samples actual boot
UUID and scaled `mach_continuous_time`; the configured original clock probe
supplies the same witness independently to the SQLite worker. Probe path is
trusted host configuration, never a model/page/protocol command field.

Managed native-clock operations take a fresh witness explicitly:

1. `set_origins_at` selects verified tuple origins; `stage_at(batch, source_policy,
   witness)` creates a host-issued staging identity. Fields preserve all six
   states and native run/surface/attachment/frame/document/activation/node/
   capture/origin provenance, source text, node and visibility. Actual grounding
   and disclosure-safe projection still belong to the native reader/extractor.
2. `review_at(staging_id, retention_ms, witness)` returns exact immutable display
   content/version/retention. `approve_at(review, witness)` validates those exact
   bytes and source policy. Identical duplicate approval reuses identity; a
   different retention review explicitly rejects and asks for revision/review.
   `revise_at` before final admission invalidates prior preparation/approval.
3. `commit_at(approval, witness)` returns one immutable CommitId. Preparation
   is non-authority; final admission needs a witnessed poll and live scopes;
   confirmed durable admission precedes atomic rows/result. Duplicates never
   dispatch another write. `status` distinguishes those stages.
4. `read_at(id, witness)` checks the actual supplied native sample against the
   persisted boot/deadline and returns only acknowledged exact committed rows.
   Cached `read()` and other un-witnessed managed methods deny in clock mode.
   A fresh caller sample is a trusted native contract, not a model-supplied time.
   `poll()` alone may process results/cleanup but cannot final-admit a native-
   clock preparation. The frontend must recheck at its publication boundary.
5. `stop` cancels new/preparing work; admitted work may finish. `delete` denies
   immediately and removes staging; completion waits for actual writer/purge.
   Required expiry uses continuous time, never inferred wall elapsed time.
6. `close_at` drains accepted work and marks clean only after healthy quiescence
   and resolved DB/lifecycle states. Any storage failure cancels clean-close
   dispatch. Dropping/crashing never marks clean. On clean same-boot reopen the
   worker verifies deadlines, exact commit identity/content and actual row
   payloads, purges expired records and loads permitted survivors nondestructively.
   Unclean, other-boot, legacy-clock or inconsistent results remain denied;
   `recover_purge` is an explicit destructive recovery, not retained-result reopen.

The SQLite worker queries the actual native clock **after acquiring a write
lock and again before irreversible COMMIT**. It rejects a failed/mismatched/
regressed clock, and rolls back an expired operation even if the authority has
not pumped a new clock sample. It never substitutes a cached actor sample or
Rust Instant for continuous retention time. The clock subprocess has bounded
output and supervision; it runs off the authority caller. Failure remains
unknown/dirty, with no automatic retry. A sample and COMMIT cannot be made an
atomic OS-time operation: delayed irreversible completion is reconciled under
lifecycle denial/purge, and current read/publication checks remain required.

General-product clock/lifecycle enablement still needs the independent N2a
native control/clock path under sleep or busy CEF, beyond this owned-fixture
producer. The current tests do not suspend the operator's machine or establish
that a UI tick alone is an independent expiry owner. The clockless `Store::open`
is retained for legacy/current-run development tests; it cannot satisfy retained
reopening and is not the native P3 deployment entry.

Limits: four staging IDs/four commit identities per store, sixteen rows/eight
fields, 4 KiB each source/value, eight origins, 256 KiB exact review, one-slot
command/completion channels, one SQLite worker and two-second busy timeout.
Batches may be copied within those finite limits; raw native snapshots/blobs
are not automatically saved. Bounded native clock probe output is 1 KiB with
500 ms supervision. Timing failures deny; they are not durability evidence.

A kernel-backed exclusive File::try_lock on the canonical database's persistent
sibling ownership file precedes dirty-run recovery or purge. Never unlink that
file or provide untrusted paths/hard-link aliases. SQLite uses WAL/FULL and
foreign keys, with a durable dirty marker before access. Schema v2 stores boot/
continuous deadlines; v1 upgrades preserve records but cannot fabricate a clock.
Managed logical deletion does not promise forensic erasure from SSDs/WAL/backups
or containment of a same-UID shell. A readonly independent DB inspector is an
explicit diagnostic outside managed access rules.

Direct tests inspect actual SQLite rows/review bytes/dirty markers. Real lock
stalls cover preparation Stop, admitted Stop versus deletion, and a native busy
failure during close. Real child kills cover admission/commit, missing durable
deletion intent and ownership exclusion. The native clock tests compile the
original producer against the SDK and run actual clean child shutdown/restart,
exact survivor loading, expired purge and incompatible persisted boot denial.
An actor-starved writer blocked past its actual continuous deadline persists
zero rows before the authority resumes. Those are DB/process oracles, not detsim.
The fixture child functions are explicitly invoked ignored tests, not production
fault switches. Full corrected Rust results and review closure are journaled.

Pinned dependencies/source identity are in [the dependency manifest](../dependencies.json)
and Cargo.lock. Source contracts: [rusqlite](https://docs.rs/rusqlite/0.40.2/rusqlite/),
[SQLite WAL/FULL](https://www.sqlite.org/wal.html), [transactions](https://www.sqlite.org/lang_transaction.html),
[standard-library lifetime lock](https://doc.rust-lang.org/std/fs/struct.File.html#method.try_lock),
and the original [native clock producer](../../native/cef/continuous_clock.mm).

Controller integration shares a ClockOwner with the Store via
`open_with_clock_owner`, while the dedicated control sampler uses that same
owner. Atomic cancel and active-query tracking keep owned clock subprocesses
reconciled before terminal service exit; registration precedes cancellation
checking, and active counts release only after actual child reap. Healthy
authority operations remain nonblocking. The convenience open/query entry points
remain for standalone tests; applications requiring terminal ownership must
retain the shared owner and drain it. Forced process death and producer
descendants retaining stdout remain explicit limitations.
