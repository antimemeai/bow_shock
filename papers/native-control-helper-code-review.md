# Native control-only helper code review

2026-10-02. Independent BLACKBIRD review of the original N2a helper,
[its subplan](../docs/plan/native-control-helper.md),
[wire decoder](../native/control/protocol.h),
[actual executable](../native/control/main.mm),
[continuous-clock producer](../native/cef/continuous_clock.mm) and
[real-process oracle](../tests/native_control_helper.py). This review edits no
product code and launches no browser or Keychain operation. Parent packaging,
spawn/reap integration and future input delivery are separate units.

## Findings and disposition

| ID | Severity | Finding | Disposition |
| --- | --- | --- | --- |
| NC-1 | Medium | The original idle stdout poll requested no events. On this Darwin runtime it failed to observe an output reader disappearing until another request or a deadline intervened. The original test wrote initialize after closing the reader, masking idle supervision and introducing a parent BrokenPipe race. | Closed in source and actual process evidence: the owner strengthened the test, observed its failure, then excluded idle stdout from the finite input wait and added a zero-time POLLOUT probe afterward. Ordinary writable readiness is ignored, avoiding an idle busy loop. Independent focused backpressure/dead-reader test passed, and a separate initialized idle-reader-death probe exited IO without another request or SIGPIPE. |
| NC-2 | Low | Comparing stdin/stdout device and inode cannot establish distinct anonymous pipes on Darwin. A direct same-pipe probe observed different endpoint inodes and passed descriptor configuration, reaching initialization expiry instead of immediate IO rejection. | Closed at trusted-host scope: owner removed the unsupported comparison and explicitly requires the host to construct two distinct private pipes and expose only their intended ends. The helper validates type/direction/settings, not authenticated peer identity or pipe independence. Final source recompiled and direct probes passed. This control-only loopback expired safely; there is no input or effect authority to escape. |
| NC-3 | Low | Owner's final source review noticed that the main poll's errno was consulted after Foundation clock calls, allowing intervening code to disturb EINTR classification. This could cause an unnecessary fail-closed IO exit. | Closed by capturing errno immediately after poll and consulting that saved value after expiry checking. Independent source recheck confirmed the correction; owner's focused actual pause/dead-reader cases passed. The tests do not induce Foundation overwriting errno. |

No further concrete state-machine or transport escape was found in this
control-only unit. The host's private-pipe construction is a precondition for
integration, not something the wire protocol authenticates.

## Wire and state boundaries

Records have exactly160 bytes with explicit big-endian serialization; native
structure layout is absent. Magic/version/operation, reserved and capability
bytes, identity character set/length and unused padding are closed. The decoder
accepts at most128 ASCII identity bytes and never indexes from an unchecked
length. Terminal errors contain only the last accepted run, sequence and fence,
or empty/zero values before initialization. Malformed records do not advance
that state or echo unaccepted identity. Diagnostic delivery remains best effort.

Initialize requires sequence1 and fence0; subsequent sequences strictly
increase without increment arithmetic or wraparound. Stop/cancel require a
strictly newer caller-owned fence, while heartbeat/shutdown require its exact
current value. Heartbeat cannot increment a fence or restore Live after Fenced.
Stop/cancel do not renew liveness. The helper acknowledges a control fence;
it has no OS effects whose quiescence that acknowledgement could establish.
Every reply's input-capability byte is zero.

The wire rejects extra arguments, non-pipe descriptors and wrong access modes.
It sets nonblocking/CLOEXEC flags, verifies the output record fits PIPE_BUF and
uses descriptor-level F_SETNOSIGPIPE. Named FIFOs also satisfy S_ISFIFO; caller
authentication and anonymous private-pipe creation belong to the trusted host.
The helper neither spawns nor execs children, and it does not enumerate and
close arbitrary unrelated inherited descriptors. The production sole owner
must supply a closed descriptor inheritance set and retain/reap its exact child.
The direct runner does so with close_fds and one unreaped Popen owner.

## Continuous time and bounded transport

The clock producer validates the OS boot-session UUID and kernel timebase,
scales mach_continuous_time using checked128-bit arithmetic, and provides no
wall-clock fallback. The helper rejects missing/backwards time and arithmetic
overflow. Its initialization interval starts at the first clock sample in
Helper::Run, after descriptor configuration; it is not a timeout measured by
the parent from process spawn. Parent startup supervision remains necessary.

Expiry is checked before/after the finite10ms poll, before accepting a complete
frame and before each ordinary write. Partial input, output backpressure and
SIGSTOP cannot renew an expired lease on resumed work. Initialization is1s,
renewed control liveness is1..5000ms, and each queued reply is bounded by500ms.
Only two160-byte replies and one160-byte partial input are retained. A third
accepted-shaped request with the queue full closes before advancing counters.

Shutdown closes input advancement, drains its bounded reply and exits0.
Ordinary faults first close state/drop pending replies, then make at most one
nonblocking terminal write. Short positive writes poison the transport rather
than splitting/retrying a supposedly atomic record. EINTR/EAGAIN do not reset
deadlines. This design handles returned write counts and nonblocking errors,
and explicitly probes actual Darwin peer-death behavior beyond assumptions
from general readiness documentation.
([Apple write(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/write.2.html),
[Apple poll(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/poll.2.html))
The actual SDK26.2 fcntl/unistd headers and pipe manual ground
F_SETNOSIGPIPE/O_NONBLOCK/_PC_PIPE_BUF; archived Apple manuals are background,
not a substitute for the observed runtime oracles.

No process can promise a physical hard exit while OS-suspended. A suspension
between a time check and its following syscall also cannot make an earlier ACK
a timeless authority grant. Here acknowledgements report control state only;
future actuation must independently validate its own identity, fence, deadline
and actual effect settlement. The maximum5s control lease is not an input lease.

## Independent evidence and remaining scope

Compiled the actual source with clang++, C++17, ARC, Foundation and
Wall/Wextra/Werror into a private ignored review path, avoiding the owner's
binary. The original14-method suite passed4.590s. After NC-1, independently
recompiled and reran the strengthened output-stall/dead-reader method:
passed2.122s including compilation. After the final NC-2 source change,
independent strict compilation and that focused method passed1.769s; all
supplemental probes passed again. The owner reports the final full14-method
suite passed4.94s; that full post-fix rerun was not repeated by this reviewer.
The final NC-3 change was independently source reviewed. Owner's strict compile
and three focused process methods passed2.195s: a short owned pause preserves
a valid lease/queued renewal, a long pause rejects an expired renewal, and
output-stall/idle-reader death closes. The additional short-pause test brings
the suite to15 methods; the full15-method suite was not run for this narrow
saved-errno correction.

The suite independently struct-encodes exact replies and exercises fragmented
and truncated input, malformed bytes, run/sequence/fence violations, Stop and
cancel non-resumption, max-u64 counters, initialization/partial-input/idle
expiry, queued renewal after exact-owned-PID SIGSTOP past lease, output
backpressure, queue saturation, EOF and actual reap. Its undrained-output Stop
test sends a subsequent old-fence heartbeat and requires Fence closure,
distinguishing input progress from waiting for an earlier reply to drain.

Supplemental actual probes passed: Stop retained its original200ms lease and
closed with the exact accepted fenced terminal at about.236s from spawn;
128-byte identity serialized exactly; unexpected arguments and nonpipe
directions rejected without publication; initialized idle output-reader death
closed IO; same-pipe endpoints demonstrated NC-2 and initialization expiry.
Probes and private binary remain ignored in context/review-native-control/.

Reviewed helper SHA256 is
`2c7fdacf895148365e8293ee5bdb15aa479699cc614dd78541a56b79221040e7`;
protocol SHA256 is
`58da83cad789b468f38f97173b0097b72e316af4532d9b0c1531af23ce9f113f`.
No fake clock, detsim, mutation testing or new dependency is introduced.
Clock-unavailability/overflow and positive short-write branches are source
reviewed, not induced on the actual OS. Production packaging, host generation
joins, launch deadlines and real Stop/UI coordination need their integration
oracles. No input API, browser operation, general reader, table authority or
quiescent external effect is approved by this construction review.
