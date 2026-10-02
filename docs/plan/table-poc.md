# Local reviewed-table construction unit

2026-10-02. The operator accepted the CEF/AppKit/Rust/JSON/SQLite POC and defers
detsim, mutants and heavier tiers. This sub-plan implements the first P3 table
authority/evidence boundary in one small library, before controller integration.
No model, export, network or OS input capability is introduced.

One caller-owned mutable authority object serializes staging, exact review,
ordinary Stop/revocation and stronger deletion/expiry. A single bounded SQLite
worker handles all database IO; the caller pumps completions without waiting.
At most four bounded commits exist, with finite worker jobs and output. Record
non-authority preparation, then live final admission, then confirmed durable
admission before atomic rows/result. SQLite FULL synchronization and WAL are
explicit local settings, with finite busy timeout. Errors/unknown outcomes are
not automatically retried. Ordinary Stop cancels preparation, but grandfathered
admission may finish; lifecycle cancellation denies publication immediately and
queues actual purge after in-flight writes release their copies.

Stage data is session-only memory. Every field retains one of the six reviewed
states plus native source identity, text/node/visibility and normalization rule.
The current native reader's run/surface/frame/document/activation/capture IDs and
verified tuple origin are copied, never inferred from URL. The trusted controller
creates these field records; this library is not a model-facing extractor.
Immutable approval binds exact serialized review bytes and version, avoiding
collision-prone noncryptographic content hashes. The immutable commit record
retains that exact content and identity, rows/result together in one transaction.

Saving rows is a separate explicit local retention choice permitted by the
source policy; committing cannot automatically preserve raw snapshots. Expiry
denies current reads and writers. Native boot identity and continuous-clock
samples establish same-boot expiry continuity; clean retained rows reopen with
their exact saved identities and content. A durable dirty-run marker precedes
managed access.
Unclean or clock-unknown old data remain unavailable, never auto-replayed. An
explicit recovery purge removes quarantined managed rows/registry before a fresh run opens;
the browser profile is separate. This is logical managed-artifact deletion,
not forensic SSD/WAL erasure. No blob store/general policy engine is necessary.

Write direct specification-derived red integration tests before implementation:
exact rows and all field states; changed review/version; duplicate commit ID;
real SQLite writer-lock stall with responsive Stop and deletion; mixed-origin
revocation while preparation waits; admitted writer then Stop versus deletion;
expiry; budget rejection; durable dirty boundary and killed-process reopen;
no replay and explicit purge. Oracles query actual SQLite rows/content and use
real process termination. A small fixture-only probe may expose fixed scenarios
for those tests; it is not a product command server or production fault toggle.

Adopt pinned rusqlite 0.40.2 with bundled SQLite only after verifying live primary
docs; preserve the resolved Cargo.lock/checksums and graph in the dependency
manifest. Existing exact Serde versions are reused. Run Rust basics, then obtain
independent adversarial code review and integrate findings before UI exposure.

## Correction sub-plan after independent review

E-01/E-02/E-03 are accepted. The first implementation incorrectly made every
retained reopen destructive-only, reused approval after a changed retention
review, and allowed a queued close after storage failure. Those are failures
against the reviewed useful outcome, not waived POC restrictions.

First reproduce changed-retention and real SQLite-timeout-during-close with
actual registry bytes/dirty state. Reject different exact approval content
explicitly; preserve same-content duplicate identity. Failure cancels clean-close
work and requires all commit/lifecycle states resolved before marking clean.

Add a small trusted-native ClockWitness (boot UUID, continuous nanoseconds).
Clock-enabled managed operations receive a new sample explicitly; old cached
read paths deny. Persist same-boot deadlines and the last clean clock witness;
on clean same-boot startup reconstruct exact committed identities/rows and
purge expired records. Unclean, other-boot, legacy and inconsistent results remain
denied. No wall-clock inference substitutes for retention. The worker queries
the owned native clock probe after acquiring the DB lock and before COMMIT,
checking boot identity and the persisted deadline; a failed or incompatible
query rolls back/denies. Cached parent time cannot substitute for this query.
Bounded probe supervision runs off the authority thread. The native parent
supplies fresh witnesses for managed operations; an independent native
clock/control owner remains necessary
before general-product enablement under a busy/sleeping CEF UI thread.

Use actual native boot/continuous samples in clean process reopen and expiry
tests, retain crash negatives, run changed meaningful checks and basic Rust
gates, then return all three findings to the original reviewer for recheck.
