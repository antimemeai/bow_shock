# Native continuous clock producer

The table review found that clean retained commit/reopen needs real clock
continuity, not purge-only restart or an assumed wall timestamp. Read installed
mach_time.h (continuous clock advances during sleep) and queried the real kernel
boot-session UUID. Wrote the native-clock subplan and extended the owned app
oracle first: it failed on absent clock_start.

Implemented a small original Foundation/SDK producer with checked sysctl UUID,
mach_timebase_info status/nonzero ratio and 128-bit time conversion bounded to
uint64 nanoseconds. Unknown data returns unavailable; there is no wall fallback.
The CMake-built fixed CLI probe uses the same producer and returns one JSON line;
the table worker can query that actual owned executable without unsafe Rust.

Strict native compilation passed. The actual probe returned the kernel UUID and
continuous nanoseconds; the integrated app fixture then passed startup/end UUID
comparison against external sysctl and increasing timestamps. Independent native
review checked the wrapper's source. This earns the producer on this SDK, not
suspend/restart retention semantics in the evidence library. The authority owner
is fixing exact approval, dirty-close and clean-reopen findings; its worker must
query a fresh native sample at actual persistence boundaries. A cached sample
aged using an uptime clock cannot prove current continuous time across sleep.
N2a independent expiry/control and N3 workload qualification remain separate.
