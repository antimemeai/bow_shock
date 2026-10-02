# Matched native observation feasibility, development only

Read the N2/N3 lane, runtime-observation design and native-surfaces research,
then actual adopted distribution headers and matched Chromium154.0.8037.58
protocol/Blink sources. Record restoration URLs and digests separately in
runtime/observation-primary.json; callback contracts are those shipped with
CEF154.0.32 API15400. No quarantine reader implementation is copied.

Matched-source correction: InspectorPageAgent::BuildObjectForFrame constructs
its securityOrigin from the loader URL. That does not prove a document's live
effective origin in inherited/sandboxed cases. MainThreadDebugger::ContextCreated
instead sends its passed SecurityOrigin and native frame ID through a default
Runtime context event. Fixed Runtime.enable metadata is allowed; no JS evaluation
is exposed. The broker requires an unambiguous matching root default context,
and all children remain withheld in this first development fixture unit.

Wrote docs/plan/native-observation-fixture.md and an actual owned HTTP/native
oracle before implementation. Running that oracle against the existing app
completed native startup/shutdown but failed directly on the missing observation
record. The public fixture has known name/price fields, hidden/secret echoes,
same-origin and cross-origin children, and sandboxed srcdoc children. A separate
password fixture requires page withholding. These known bytes inspect the actual
published projection, not two copies of a normalized output.

Implemented an original Objective-C++ broker using fixed internal reader
methods, bounded callback-lifetime copies, bounded outstanding message queue,
off-UI parse/projection and root frame/context/document brackets. Fields are
restricted to reviewed exact DOM IDs. Host-known secret echoes, form controls,
excluded/hidden regions and missing/ambiguous fields produce typed withholding.
Native layout bounds remain non-actionable and occlusion-uncertain; no AX/pixels/
child data or raw snapshot logging is exposed. Callback/host node/work limits
do not bound native Blink work, and timed-out outstanding commands block retry
until response/detach reconciliation.

Compiler preflight uses the acquired tuple's C++20 requirement. Native integration
and actual green fixture/source review follow; this source/unit alone does not
enable a general reader or close the N3 workload/control-helper gates.

Actual owned native fixture run (root build/run lane 68721) passed all three
initial cases. Exact native text was Amber / $12.00; hidden and known secret
echo fields were withheld, and native coverage counted five frames while
publishing root-only fields. A password control withheld the projection. The
CSP-sandbox root's actual main-world context origin was `://`, rejected against
the host tuple scope. Matched SecurityOrigin constructors and ToRawString
explain this raw spelling; its immutable primary source is now in the existing
acquisition manifest. Temporary origin/attribute diagnostics are removed. The
initial attribute_shape failure was the older compiled decoder rejecting
Blink's `-1` empty-string sentinel; source-grounded owner correction preserves
strict attribute array/element data rather than accepting missing attributes.

Independent review found that a dispatch_after notification alone did not
establish the 3 s deadline when the UI queue was delayed. Added continuous-time
checks on response consumption, subsequent command dispatch and final publish.
A late matching response still clears outstanding native command ownership;
no renderer cancellation or native-work bound is claimed. The actual-app oracle
uses a smoke-only, default-off self-stop immediately after capture start and
before first native dispatch. The driver observes its exact owned app in T state,
resumes after 3.4 s and requires failed status with no fields. Initial marker-only
polling was rejected by independent review because a roughly 3.65 ms capture
could finish before the driver signal. Root gates the self-stop setting behind
smoke output plus an explicit switch. The deterministic point precedes timer
arming; the outcome attacks the next-dispatch deadline, while independent source
review additionally checks result and final-publication boundaries. Per-case actual
app stderr is retained in ignored context on positive or negative assertion
failures. Strict matched-header compiler preflight is green; coordinated actual
app rebuild/recheck and independent reader review follow.

The node generation is a conservative counter for known native lifecycle
invalidations, not complete in-document mutation coverage. DOMSnapshot does
not create a full DOM subscription; same-document text changes can occur between
reads. Its backend IDs and layout coordinates are evidence-only. Any future
action must freshly resolve/re-observe rather than treating this counter as a
lease on a live node. Non-atomic coverage remains explicit.

The first coordinated four-case repeat timed out at 40 s on the ordinary public
fixture before any capture marker or lifetime stderr. It did not reach the
self-stop/deadline case. No causal attribution to the reader was made. Parent
requested a same-stderr-FD-shape instrumented repeat before an FD comparison.
The oracle now records its exact owned PID at 8 s, samples only while that PID
remains live/unreaped on the sole wait owner, and retains the failed owned temp
profile/result/stderr under ignored context/runtime/native-observation-diagnostics.
Root adds startup stages to distinguish pre-CEF/startup/reader/teardown waits.
This diagnostic repeat does not enable observation or claim new native closure.

The coordinated instrumented same-FD-shape repeat passed all four actual-app
cases, including the deterministic owned self-stop/3.4 s resume timeout with
zero published fields. Full startup and teardown stages are preserved per case
in ignored stderr. At 8 s, ordinary public PID 33119 and sensitive PID 33156
were still live/unreaped; exact-process samples are retained. Those samples show
the main task in AppKit's run loop and are not a causal diagnosis of the earlier
empty-stderr timeout. The prior timeout remains recorded; the new result earns
the reader fixture/late-dispatch outcome at this tested scope, not general
runtime liveness or N3 workload bounds. Independent final reader review follows.

Independent final review in papers/native-observation-code-review.md closes
NO-1 (continuous deadline) and NO-2 (pause-oracle race) at the stated fixture
scope. The deterministic self-stop case directly exercises expired next-dispatch
rejection before timer arming. Native-result/final-publication boundaries and
late ownership reconciliation are source-reviewed, not separately claimed as
exercised. No additional owned-root publication escape was found. Lifecycle/
queue/close/retry fault oracles and N3 workload/control-owner gates remain open.
No commit was made by this delegated owner.

Root integrated the earned origin correction into the design specification:
Page frame `securityOrigin` is URL-derived in this exact Chromium build, while
the accepted root join uses live default-world execution-context metadata.
Matched source, the actual opaque-root fixture and independent reader review
support the correction. No general frame join or observation authority is earned
by this documentation change. Root's four-case run (tool session 45289) exited
zero; the retained log is context/runtime/native-observation-smoke.log.
