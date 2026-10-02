# Native clock startup source review

2026-10-02. Read-only review requested after two controlled native Stop joins
and an installed live attempt failed before page load on clock supervision.
No app/model/test/clock launch, signing, Keychain, clock-resource or product
change by this reviewer. The original500ms query limit, native freshness/
headroom and IO limits remain required.

**No confirmed source cause. Current causal phase is unknown.**

ClockOwner registers each activity before cancellation/spawn and retains it
until actual owned child reap. The query supervises a fixed trusted executable,
waits for its exit, rejects unsuccessful/stale results, then reads at most1025
bytes and validates its clock witness. The no-descendant producer contract is
required for the post-exit pipe read. The actual shipping source emits about95
bytes and exits after fflush; that output cannot fill a normal pipe. This is
not evidence about a wrong executable or arbitrary descendant keeping output
open.

The producer gets kern.bootsessionuuid, uses checked mach_continuous_time
timebase conversion, serializes one dictionary and exits. Its standalone CMake
target links Foundation only, not CEF. UUID/scale/conversion/JSON failures
normally yield immediate failed/invalid output, rather than establishing a
long-running child. Foundation/dyld/runtime startup and parent scheduling are
possible phases; none has been measured for the present failure.

The error `native clock query timeout/uncertain freshness` merges three
predicates: monotonic elapsed exceeds500ms, wall elapsed exceeds500ms, or
SystemTime elapsed is an error after a backward adjustment. The label alone
does not prove500ms of child work. Timers start after Command.spawn returns,
so spawn-call duration is a distinct phase. The actor's outer clock-task bound
does not make the query's spawn timing measurable retroactively.

One focused trace should distinguish:

1. Spawn call start/return and exact owned PID/path/birth identity.
2. Child pre-main/dyld versus producer-body sysctl/Foundation/serialization/
   fflush/exit, or inability to observe these phases.
3. Parent scheduling gaps, last try_wait result and the separate monotonic/
   wall elapsed predicates before kill.
4. Exit status and output length/validation phase when the child actually exits.

SIGCHLD masking alone does not prevent waitpid(WNOHANG) discovering a child's
exit; source inheritance is not a causal mask finding. Successful warmed calls
are not a fix or explanation. A minimal producer should be considered only
after actual captured phase/source evidence supports that change.

## Observer plan review

Accepted the written `docs/plan/native-clock-startup-diagnosis.md` concept:
matched SDK libproc ABI, only owned app→configured controller→bundled clock,
exact parent/path/birth revalidation, bounded lists/retention/poll gaps and
sampling attempts, no unrelated argv/environment/page/credential capture.
The direct owned-sleeper and deliberately wrong-path oracle is the appropriate
mechanism before root's one controlled join. Final code/ABI/oracle disposition
appears below.

First-seen150ms is a lower bound since observer sighting, not query start or
spawn return. Sampling can perturb or internally suspend target threads;
there must be no zero-overhead claim or explicit signals/pauses beyond the
permitted observation. PID revalidation and sampling cannot be atomic, so
vanished/reused/denied/missed/truncated observations remain gaps. A healthy run
without a slow clock does not qualify the stall diagnosis or establish a fix.

## Initial observer source/oracle review

The acquired SDK's `proc_bsdinfo` matches the diagnostic's136-byte layout,
PID/parent/uid/start fields; `proc_taskinfo` matches96bytes and the retained
resident/time/thread indices. The wrapper's child-list count is treated as a
PID count, with full256-entry lists denied conservatively. Identity is checked
before and after path reading, then parent/path/birth revalidated before sampling.
Actual packaged Mach-O dependency inspection by this reviewer confirms
Foundation, libc++, libSystem, CoreFoundation and libobjc, without CEF; this was
inspection only, not executable launch.

Owner's retained initial green records3 actual ABI/owned-chain/wrong-controller
tests in3.219s. All use `sample_limit=0`; they do not earn sampler-launch,
poll-independence or cleanup coverage. No tests were launched by this reviewer.

CO-01: `_sample` performs blocking `subprocess.Popen('/usr/bin/sample')` on
the polling thread. A slow/cold sampler launch can suppress precisely the
clock timeline needed around the500ms boundary. Requested a separate bounded
single-flight diagnostic sampler owner with launch-start/return evidence and
a focused stalled-launch/poll/cleanup oracle before the controlled join.

CO-02: the16-controller retention bound silently skips further matching
identities. Requested an explicit partial/gap event at the bound. Sample files
are capped after tool completion, so the initial source supports a retained
file-size bound rather than a hard bound on bytes written while sampling.
Both were pending at initial review and are closed by the following correction.

## Final observer disposition

**Accepted for one controlled Stop diagnosis; no clock availability fix or
present causal phase is established.** Reviewed final observer SHA256
`43674a304e804da8c7736fd9c94be6b662a16a0859e2cb91b84e2d42868c733e`
and oracle SHA256
`1f7879506902716be61927e7523a5cf4b023b7776c50df7358c7a432955f1e64`.
No executable/test/app/model/clock launch by this reviewer.

CO-01 closed: launch/wait/reap is now a separate single-flight sampler worker.
Discovery continues while it launches; at most two nonconcurrent attempts are
allowed, and launch start/return mono/wall durations are retained. Stop signals
only the diagnostic's owned sampler and reconciles its actual process. Its
two-second lifetime starts before launch, but cannot interrupt blocking OS
spawn. `thread_alive` or `sampler_thread_alive` in the final summary means
unresolved diagnostic ownership, not a complete trace or cleanup success.

CO-02 closed: controller retention overflow now increments gaps and emits
`controller_identity_limit`. Clock/list/timeline limits remain conservative.
Sample/stderr files have explicit post-collection retained-size caps, without
claiming a bound on native writes during sampling. A stack is retained only if
the tool header's PID/parent/launch-time/basename matches the bound identity;
otherwise it is deleted and recorded as unattributed. Full paths are redacted
by the tool, so pre-launch exact-path/birth checks retain their non-atomic scope.

Owner's final four actual owned-process cases passed in4.905s, retained in
`context/review-controller-agent/clock-observer-green.log`. The source directly
checks BSD/task reads, exact owned chain, wrong-controller withholding and raw
`proc_listchildpids` count1 for one owned child. The added fault oracle holds
only diagnostic sampler launch, verifies at least10 discovery polls during
300ms, then releases launch and verifies actual owned sampler PID absent after
Stop, with both observer threads ended. It launches the actual system sampler
against an owned sleeper; it does not exercise or establish shipping-clock
availability. Shared-cache effects from that diagnostic are not a causal fix.

The acquired Apple wrapper at revision
`f6217f891ac0bb64f3d375211650a4c1ff8ca1ea` explicitly divides returned bytes by
`sizeof(int)` for `proc_listchildpids`; reviewed source hash matches the tracked
origin/restoration entry in `runtime/clock-diagnostics-primary.json`. Sampling
perturbation, short children missed between polls, denied/vanished targets,
observer scheduling gaps and unavailable internal timeout predicates remain
limits. Root's single controlled trace and any causal interpretation are a
separate, still unearned runtime result.
