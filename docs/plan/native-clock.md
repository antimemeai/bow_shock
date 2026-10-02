# Native retained-data clock witness

The exact table/lifecycle review found that purge-only recovery cannot satisfy
clean commit/reopen. The trusted native parent supplies a boot-session identity
and a continuous timestamp to Rust, which remains the sole policy owner. This
does not grant models a clock-setting operation or extend retention.

Read installed mach_time.h and sysctl contracts. Produce the actual kernel
kern.bootsessionuuid and mach_continuous_time scaled by mach_timebase_info with
checked wide integer arithmetic. Failure returns unavailable, never wall time
or a guessed boot identity. macOS's continuous clock advances through sleep;
a different boot cannot establish the old deadline's elapsed time.

Direct red oracle: the owned native smoke requires real startup/end witnesses
with the external kernel UUID and increasing nanoseconds; the current app has
no such records. Then implement the small original native producer, compile
against the SDK and rerun the actual app. The table owner separately exercises
clean same-boot retained reads, deadline/regression/different-boot failures and
dirty restrictions against real SQLite. Fresh witnesses are required at managed
read/admission boundaries. A periodic CEF UI timer cannot qualify independent
expiry under capture overload; N2a's independent control owner remains a gate.
