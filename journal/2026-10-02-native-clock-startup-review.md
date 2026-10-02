# Native clock startup source and observer review

Read ClockOwner supervision, native producer/probe, CMake packaging, build script
and already acquired pinned Rust process source under explicit no-launch/no-sign/
no-clock-resource-change scope. No confirmed source cause. Communicated exact
error-predicate ambiguity (mono/wall timeout or backward-wall error), timer starts
after spawn return, tiny/no-descendant Foundation-only producer, and source-only
signal inheritance not a causal finding. Proposed one phase-classified exactPID
trace without deadline/freshness/headroom changes or warm-up-as-fix.

Reviewed/accepted observer plan concept: SDK ABI/direct owned sleeper +wrongpath
oracle, strict app/controller/probe path/parent/birth bindings, bounded polling/
retention/samples, explicit missed/denied/nonatomic gaps. Noted firstseen age lower
bound and sampling perturbation. Observer code/oracle review pending. Recorded
papers/native-clock-startup-source-review.md; no product edit/app/model/test/clock
launch or Keychain/signing action by reviewer.

Initial observer source review matched SDK BSD136/task96 layouts and exact
ownership checks; owner's3 actual sleeper/ABI/wrong-path tests green3.219s,
sampler disabled in all. Raised CO-01 blocking sampler Popen on polling thread
and CO-02 silent16-controller retention bound. Requested separate single-flight
sampler owner + stalled-launch/poll/cleanup oracle and explicit partial event.
Actual packaged Mach-O otool inspection confirms no CEF linkage; no launch.
Observer acceptance was pending those corrections, not a clock availability fix.

Final source/oracle review accepted one controlled Stop diagnostic. CO-01 closed
with separate single-flight sampler worker, recorded launch timing, actual reap;
CO-02 closed with explicit controller-limit gap. Reviewed final observer hash
43674a304e804da8c7736fd9c94be6b662a16a0859e2cb91b84e2d42868c733e
and tests1f7879506902716be61927e7523a5cf4b023b7776c50df7358c7a432955f1e64.
Owner's4 actual owned-process cases green4.905s include raw SDK child count1,
deliberately held sampler launch with continuing polls, real owned sampler
absent/reaped and both threads ended. Read pinned Apple wrapper source and
tracked origin/restoration manifest. No reviewer launch. Retained-only caps,
sampling perturbation/nonatomic identity and uninterruptible OS spawn explicit;
any live-thread summary is unresolved ownership. Root's one controlled trace
and present failure cause remain separate/unearned; no availability fix claimed.
