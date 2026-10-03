# Clock simplification investigation

The operator asked why a process could not read system time directly, then
observed that eliminating complexity often eliminates or illuminates problems.
Read the clock producer, Rust supervisor, table/agent worker integration and
original clock plan/journal. The original subprocess rationale was avoiding
unsafe Rust, not security isolation. Its lifecycle and JSON transport are
avoidable for trusted native clock reads.

Requested one independent, read-only research/review unit under Blackbird's
conceptual delegation rule. Pinned Rust 1.94.1 source uses an Apple uptime clock
for Instant, excluding sleep; SystemTime is wall time. Apple's documented
continuous clock includes sleep. Keep that actual kernel clock and boot UUID,
which are shared with native capture/deadlines and retained SQLite data.

Prepared `docs/plan/native-clock-simplification.md`: a small original safe
platform interface with narrowly scoped unsafe FFI, no new third-party runtime
dependency, and deletion of executable configuration, JSON, launch supervision
and child cleanup. Existing table/agent freshness and irreversible-write
boundaries remain. The unsafe-policy tradeoff and portable test path are
explicit; no product implementation or policy change was made in this pass.
No app, model task, probe, test, build/signing or credential operation ran.

Independent review agrees with the domain and adapter direction. It identified
two details to settle before implementation: the portable/Linux test backend
and a native-continuous bracketing definition for sample age. Updated the plan
to avoid relying on uptime/wall elapsed time as a suspend-freshness guarantee
and preserve the known non-atomic final-read/write interval.
