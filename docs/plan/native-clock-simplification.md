# Read the native clock in-process

2026-10-03. The operator challenged the clock subprocess and pointed out that
removing complexity can remove or expose a problem. This is a proposal for the
replacement, not a claim that the intermittent failure's cause was captured.

The original reason for the executable was to let Rust read the real kernel
clock without unsafe Rust (`journal/2026-10-02-native-clock.md`). It is not an
isolation boundary. Existing Rust already has access to time. The required
witness is more specific: the same kernel boot UUID and scaled
`mach_continuous_time` domain used by the native shell and stored deadlines.
Pinned Rust 1.94.1 `Instant` uses an Apple uptime clock excluding suspend;
`SystemTime` uses adjustable wall time. Neither is a replacement for this
witness. See the independent simplification research in `papers/`.

## Replacement

Introduce one small original platform-clock crate, exposing only a safe
`read()` result containing validated boot identity and continuous nanoseconds.
On macOS, call the installed SDK's `sysctlbyname`, `mach_continuous_time` and
`mach_timebase_info` directly, using checked wide conversion and the same UUID/
positive integer limits as today. No Foundation, subprocess, JSON, dynamic
plugin, caller-selected executable or new third-party dependency is needed.
Keep acquisition references as study material; copy no reference implementation.

This requires a narrow change to the current Rust policy: permit documented
unsafe FFI solely in that adapter crate. Keep `unsafe_code = forbid` in the
controller, evidence and framing crates. The adapter owns its exact ABI,
initialized fixed buffers, lengths, return checks and safe public interface.
This policy tradeoff must be discussed with the operator before implementation.

Have the controller, agent transport and SQLite worker call this adapter at
their existing clock-read boundaries. SQLite still samples after acquiring the
write lock and before irreversible writes. Keep original boot matching, source
freshness, expiry, publication guards and cancellation semantics. An unavailable
or invalid kernel reading still denies the operation. Retain a conservative
sample-age check for scheduling/suspension across a read, using native
continuous-clock bracketing rather than assuming uptime or adjustable wall
elapsed time establishes it; do not increase any accepted age or deadline.
The final read and write remain separate operations with the existing
acknowledged scheduling gap, not an atomic clock/write guarantee.

Remove production clock executable configuration, child supervision/kill/reap,
query JSON decoding, the executable's native target/staging/signing and obsolete
clock-child lifecycle tests. Replace the old worker's executable-path state with
the in-process clock interface. Simplify clock ownership to actual remaining
read cancellation/quiescence needs; do not retain process-lifetime abstractions
when there is no child. Keep bounded authority/SQLite separation where it also
serves other IO. The historical trace utility and failures can remain research
artifacts, not part of normal runtime qualification.

## Direct checks and review

Before source changes, review the adapter ABI/policy and integration plan.
Earn a direct red oracle for the new safe read interface. Check its boot UUID
against an independent kernel query, and bracket its nanoseconds with the
existing native clock. Replace native persistence tests' producer subprocess
with actual in-process reads. Retain clean same-boot reopen, expired/dirty/
different-boot denial and real lock-stall expiry oracles. Review the small FFI
and its callers independently, then run the Rust basics once.

Define the portable/Linux test path explicitly before changing test interfaces;
do not silently fallback to wall time or a process-relative counter. Linux
product integration remains a separate platform gate. Rebuild the canonical
native bundle and exercise owned native Save/reopen and agent retirement on
the final source. A changed ad hoc bundle may require the existing local
macOS authorization step; no Keychain or signing-identity change is proposed.

Success removes the per-read process mechanism and preserves the existing
clock contract. It does not retroactively establish the old failure's cause.
