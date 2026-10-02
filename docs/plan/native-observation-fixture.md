# N2 native fixture reader subplan

Use adopted CEF 154.0.32/Chromium 154.0.8037.58 API 15400. This unit is a
development-only broker for an explicitly owned loopback fixture and reviewed
field IDs. It enables no general reader, input, provider export or raw evidence
storage. Root owns shell/build/UI integration. N3 native workload and independent
control-owner gates follow before any general observation.

Read actual distribution observer/browser/frame headers and matched Chromium
DOMSnapshot, Page and MainThreadDebugger source. Fixed methods are Page.enable,
Runtime.enable (context lifecycle only), DOM.enable (node invalidation events),
Page.getFrameTree (before/after), DOMSnapshot.captureSnapshot (display/visibility/
opacity styles, no extra DOM rect/paint flags), and Browser.getVersion. No
Runtime.evaluate, model strings, mutation, AX bulk capture or external socket.
Snapshot geometry is sufficient for this field fixture; AX/actions are withheld.
Chromium's 154.0.8037.58 tag resolves to commit
`a654841425914cbb703a2931e07b70a83aedbafd`; restore URLs and SHA-256 digests are
tracked in runtime/observation-primary.json. Main-world LocalWindowProxy passes
the actual DomWindow SecurityOrigin to MainThreadDebugger. Blink AddString uses
`-1` for empty strings, and document layout nodes may have empty computed-style
arrays; the worker decoder follows those native cases rather than inventing
nonempty string/style requirements.

Matched InspectorPageAgent::BuildObjectForFrame constructs securityOrigin from
the loader URL, so this value does not establish effective origin for sandboxed
or inherited documents. MainThreadDebugger::ContextCreated sends the passed
SecurityOrigin's raw string and native frameId in default-context auxData.
Join an unambiguous live default context to the native root frame ID; effective
origin must exactly match the host's loopback scope. Missing or ambiguous context
origin withholds the page. Matched SecurityOrigin opaque constructors keep the
precursor separate (security_origin.cc:180–185); ToRawString/BuildRawString
(545–563) omit the SerializesAsNull check and serialize empty tuple members as
`://`. The actual CSP-sandbox root oracle must record its returned raw origin
and deny it by exact tuple comparison; it must not assume literal `null`. Child frames are all withheld
in this first reader, including inherited and sandboxed frames; no fabricated
CEF/CDP ID equivalence or OOPIF routing claim.

Root calls initWithBrowser:runId:surfaceId:allowedOrigin:fieldIds:secretMarkers:,
captureFixtureWithCompletion: after main load, nativeLifecycle: for known frame/
document/renderer changes, and close before browser destruction. All interface
calls and CEF dispatch are UI-only. OnDevToolsMessage copies at most 1MiB within
callback lifetime into a finite queue; decoding/projection run on one worker.
One capture is active; additional requests reject busy (coalescing can follow).
Host callback-copy/node/field limits do not bound native renderer traversal or
DevTools serialization. Timed-out native capture remains unresolved/unavailable
until its response or detach is reconciled, never silently retried.

Capture brackets its root frame/loader/default-context identity, records the
run/surface/attachment/document/activation/node generations, and invalidates on
Page/DOM/Runtime lifecycle and native callbacks. Publish only exact host-reviewed
element IDs, native backend IDs, bounded descendant text and snapshot layout
bounds with occlusion/current-screen uncertainty. Never publish raw strings,
attributes, input values, titles, URL queries, child content or raw AX. Any form
control makes this conservative fixture projection withheld. Known secret marker
echoes remove affected fields; absent/hidden/unsupported fields have typed reasons.
All successful output is partial (root-only, non-atomic, non-actionable).

Direct oracle: owned HTTP fixtures provide selected text and hidden/form/echo/
child markers. Actual CEF smoke output must contain exact permitted fields,
native root/loader/context provenance and coverage, and none of denied marker
bytes. Owned sandboxed/inherited/cross-origin children must remain withheld.
First run against current shell without observation and fail on missing record;
then implement/integrate and check actual projected payload. Pure captured-input
projection probes can attack malformed/lifecycle limits but cannot replace the
actual native fixture oracle. Independent code/source review follows green.

Review correction subplan: the 3 s host deadline is measured with continuous
time. Compare it when consuming a native result, before every subsequent method,
and immediately before publication; a delayed UI dispatch timer is only a
notification aid. Timeout reconciles the pending native command without
pretending to cancel renderer work. The direct owned-app deadline oracle must
self-stop at a default-off smoke-only point after capture start and before
first dispatch, observe the exact owned process T state, resume after 3.4 s,
and assert no successful field record. Marker-only parent signal polling is
insufficient because the capture can complete in a few milliseconds.
Keep this separate from the N3 native-work bound, which is still unearned.

The node generation is a conservative counter for known native lifecycle
invalidations, not complete in-document mutation coverage. DOMSnapshot does
not create a full DOM subscription; same-document text changes can occur between
reads. Its backend IDs and layout coordinates are evidence-only. Any future
action must freshly resolve/re-observe rather than treating this counter as a
lease on a live node. Non-atomic coverage remains explicit.
