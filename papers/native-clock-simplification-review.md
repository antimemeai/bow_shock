# Direct native clock simplification

2026-10-03. Read-only research for the operator's simplification proposal. No
code/test/native/model launch, product edit or dependency adoption.

**A direct in-process kernel clock can preserve the useful guarantees while
removing per-sample process launch, JSON pipes, supervision and child cleanup.**
The subprocess was an accommodation to the Rust unsafe policy, not a security
boundary. `journal/2026-10-02-native-clock.md` explicitly says the CLI probe lets
the table worker obtain an actual sample “without unsafe Rust.” E-01 required
clean same-boot retained reopening; the worker needed a fresh sample after DB
lock waits rather than a cached parent timestamp aged by Rust uptime.

## Clock semantics that remain necessary

Pinned Rust1.94.1, revision `e408947bfd200af42db322daf0fadfe7e26d3bd1`, uses
`CLOCK_UPTIME_RAW` for Apple `Instant`: its source explicitly excludes system
sleep and identifies the converted `mach_absolute_time` domain. `SystemTime`
uses `CLOCK_REALTIME`; wall corrections can change elapsed results. `Instant`
is opaque, supplies no boot UUID/persistable raw epoch, and the public API does
not promise suspend behavior across platforms/versions. Neither is a drop-in
replacement for saved continuous deadlines. [Pinned implementation](https://raw.githubusercontent.com/rust-lang/rust/e408947bfd200af42db322daf0fadfe7e26d3bd1/library/std/src/sys/pal/unix/time.rs),
[pinned public contract](https://raw.githubusercontent.com/rust-lang/rust/e408947bfd200af42db322daf0fadfe7e26d3bd1/library/std/src/time.rs).

Installed SDK `mach/mach_time.h` documents `mach_continuous_time` as advancing
during sleep. The existing native producer obtains `kern.bootsessionuuid` and
scales ticks using `mach_timebase_info`. Retain that exact domain, checked wide
integer conversion, canonical UUID spelling and positive/i64-bounded nanoseconds;
existing saved records and native UI guards then need no clock-domain migration.
Boot identity and timebase may be cached within the process after successful
kernel initialization; current time must be sampled at each required boundary.

Required boundaries are small and already present:

- Managed operation/read/review/list and reply publication use an actual new
  sample; preserve original source/retained deadlines and fail closed on unknown
  boot, regression or incompatible restart. Dirty recovery stays conservative.
- SQLite startup and writer gates sample independently after acquiring their
  real transaction lock and immediately before COMMIT. Cached actor time cannot
  establish expiry after a lock stall or sleep.
- Agent handoff samples before each sensitive write under the revocation
  discipline; retain source expiry/headroom and final-result checks. Native UI
  publication and helper leases continue using the same continuous domain.

The direct call removes the probe's500ms process-availability mechanism; it does
not relax a source retention deadline, grant authority or make clock/check/DB
COMMIT/socket write atomic against arbitrary process suspension. SQLite IO
remains off the authority loop. No replacement clock daemon, query worker or
diagnostic expansion is needed merely to transport a kernel timestamp.

## Unsafe policy implication

All three current Rust crates inherit workspace `unsafe_code = "forbid"`.
Direct C ABI declarations/calls require a deliberately scoped policy exception;
an inner module cannot lower `forbid`. [Rust lint contract](https://doc.rust-lang.org/reference/attributes/diagnostics.html#lint-check-attributes).
Keep the exception confined to the original macOS adapter, exposing a safe
`Result<ClockWitness>` API with fixed names, bounded owned buffers, checked ABI,
initialized outputs and no caller pointers. Root's proposal uses a small separate
original platform-clock crate, retaining `forbid` in all three existing crates.
A C/Objective-C shim still entails Rust FFI and extra
build wiring; it does not eliminate that decision. No external crate is needed
for these few system declarations, and none is authorized here.

Reviewed `docs/plan/native-clock-simplification.md`: the separate-crate interface,
removal of the process machinery and preservation of the existing read gates
are sound. Define the portable/Linux test backend before implementation, as the
proposal requires. Also define retained sample-age checks in the native
continuous domain; uptime or adjustable wall elapsed alone cannot guarantee
suspend freshness. Keep the existing non-atomic check/write limitation explicit.
These are concrete implementation-plan details, not reasons to retain a process.

This is source-level support for the simplification direction, not implemented
or runtime-tested acceptance. The two exact Rust source origins/checksums and
restoration commands were appended to `runtime/rust-agent-primary.json`.
