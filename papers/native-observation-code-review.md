# Native fixture reader code review

2026-10-02. Independent BLACKBIRD review of the original N2 reader, its native
shell integration and actual owned-fixture oracle. Read
[the subplan](../docs/plan/native-observation-fixture.md),
`native/cef/observation.h/.mm`, `native/cef/main.mm`, the supplemental native
continuous-clock producer and `tests/native_observation_smoke.py`. Primary
contracts are the adopted CEF15400 headers and the exact Chromium
`a654841425914cbb703a2931e07b70a83aedbafd` sources recorded in
[the observation acquisition manifest](../runtime/observation-primary.json).
General observation, provider export, effects and actionable geometry remain
disabled. No product code was edited by this reviewer.

## Findings and disposition

| ID | Severity | Finding | Required correction and evidence |
| --- | --- | --- | --- |
| NO-1 | Medium | The first reader used only a main-queue `dispatch_after` notification for its three-second timeout. A delayed timer could allow native responses to advance and publish after continuous time had expired. | Closed at fixture scope: owner added continuous checks before result advancement/dispatch/final publication and preserves late pending-response reconciliation. Independent source recheck and actual deterministic continuous-deadline rejection passed. The direct test targets pre-dispatch advancement, not every late response/publication branch. |
| NO-2 | Low | The first pause test waited for a capture-start marker, then polled every10ms before externally stopping the app. A previously observed successful capture took about3.65ms; publication could complete before SIGSTOP. The marker established that capture began, not that it remained active when paused. | Closed: default-NO smoke-gated self-stop occurs after timestamping and before dispatch/timer arming. Driver observes the exact app in T state, waits3.4s and resumes it. The actual four-case run passed, removing the polling race. |

No further concrete publication-authority escape was found in the reviewed
owned-root fixture scope. This is not approval for a general page reader or a
claim that untested failure paths have passed.

## Provenance and lifecycle

The broker dispatches a fixed method list and fixed style names. It exposes no
Runtime evaluation, script expressions, external DevTools socket, model command
strings or mutation method. Root integration creates it only with smoke output
and explicit fixture origin/field configuration, after the main load. It closes
before browser destruction and forwards known main-load/renderer termination
signals. This is a development reader, not an implicitly enabled normal UI
capability.

The source correction about origins is essential. Matched
InspectorPageAgent::BuildObjectForFrame constructs `securityOrigin` from the
loader URL. LocalWindowProxy instead passes the main world's actual DomWindow
SecurityOrigin to MainThreadDebugger, which supplies raw origin and native
frameId with default-world metadata to the Runtime context event. The broker
requires an unambiguous default context for the native root frame, whose origin
exactly equals the host's configured loopback tuple, before sending the snapshot
command. It does not authorize from Page URL or Page securityOrigin.
([Page frame source](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/third_party/blink/renderer/core/inspector/inspector_page_agent.cc),
[main-world source](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/third_party/blink/renderer/bindings/core/v8/local_window_proxy.cc),
[context metadata](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/third_party/blink/renderer/core/inspector/main_thread_debugger.cc))

Opaque origins are not necessarily spelled `null` in this native raw field.
Matched opaque SecurityOrigin constructors retain precursor separately and
leave tuple fields empty; ToRawString builds those fields without the ordinary
null-serialization test. The actual CSP-sandboxed root emitted `://`, and exact
tuple matching rejected it before snapshot publication despite its HTTP URL.
([SecurityOrigin](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/third_party/blink/renderer/platform/weborigin/security_origin.cc))

The selected snapshot document must carry the native root frameId exactly once.
The final root frame/loader and live context ID/origin must still match, with no
observed lifecycle revision change. Runtime context destruction/clearing and
attachment changes erase cached context authority; conflicting default contexts
poison rather than replace the frame entry with newly accepted authority.
Page/DOM/native lifecycle signals advance conservative invalidation counters.

CEF and CDP frame IDs remain distinct: the output labels their relationship as
root browser association only. It does not claim ID equivalence, an OOPIF join,
child authority, pixel mapping or a globally atomic snapshot. Every published
record has a unique capture ID and the native loader/revision identity. The
generation counters are observed invalidation sequences, not proof that every
DOM mutation was detected. Stable frame/loader identity cannot make text or
layout continuously current; the record is explicitly non-atomic and its bounds
are non-actionable.

## Sensitive projection and work boundaries

Only host-reviewed exact field IDs from the root document can publish.
The worker validates schema/index limits, walks native parent relationships,
requires layout presence, excludes script/style/head/frame/media/object regions
and rejects hidden/zero-opacity ancestor chains. Any form/input/textarea/select
in the root projection withholds the page. Ambiguous/missing fields, excess
work/text, unavailable layout text and host-known secret echoes have typed
withholding reasons. Output does not contain raw attributes, input values,
snapshot strings, title/query content or child document fields.

The known marker mechanism is a fixture oracle and explicit deny-list, not a
universal sensitive-data classifier. Contenteditable regions, application
secrets, cross-origin servicing and future general field selection need their
own reviewed policy before broader observation. Layout presence also does not
establish visible pixels, occlusion or safe click coordinates.

Callback bytes are copied during their documented CEF lifetime on the UI
thread, capped at1MiB per message with at most2MiB copied outstanding bytes and
64 callbacks. Parsing and projection run on one worker. Projection applies
document/string/node/layout/field/text and traversal bounds; these reject or
withhold instead of truncating into apparently complete evidence. The raw-byte
queue cap is not a total resident-memory quota for Foundation decoded objects.

These limits are applied after Blink has traversed and serialized the native
snapshot. Matched source iterates inspected local frames and visits their
documents; raw callback data can consequently include child and sensitive
material before host filtering. Root-only publication does not mean the native
command traverses only the root, or that restricted child bytes never enter
host memory. Raw data is temporary and no raw snapshot logging/storage/export
is implemented. N3 must settle native traversal/time/memory and servicing
controls before general reader authority is enabled.
([matched snapshot implementation](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/third_party/blink/renderer/core/inspector/inspector_dom_snapshot_agent.cc),
[protocol](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/third_party/blink/public/devtools_protocol/domains/DOMSnapshot.pdl))

## Async lifetime and deadline recheck

The Observer holds a weak owner; the registration and browser handle are
released on close. Queued worker/main blocks retain the Objective-C owner
until reconciliation, but closed callbacks become inert and no CEF access
occurs from the projection worker. A projected result is accepted only for the
same active capture ID; `_projectionInFlight` prevents overlapping captures
even if a prior completion was invalidated. An outstanding native request keeps
retry unavailable until its matching response or detach clears ownership.
Timeout and lifecycle failure withhold fields; they do not assert that native
work was cancelled.

The final NO-1 source has continuous checks at handler entry, before each
dispatch, and at publication both before and after the native frame reads.
After timing out, the handler still consumes the matching request ID and clears
its pending state, but sees no active completion and cannot advance the capture.
The queue timer is only a notification aid. This source correction addresses
late advancement independently of timer ordering.

The supplemental `BSContinuousClockWitness` reads the OS boot-session UUID,
validates it as NSUUID, checks the kernel timebase and nonzero scale, converts
continuous ticks using128-bit arithmetic and checks the uint64 range. It has no
wall-clock fallback. The full native shell smoke matched its UUID to the
external OS and observed increasing nanoseconds. This supports that producer;
it does not turn current observation timestamps into table expiry authority or
complete cross-run provenance integration.

## Actual oracle evidence and remaining scope

The native owner's initial three-case smoke passed after compiling the matched
decoder correction for Blink's `-1` empty-string sentinel. Exact published text
was Amber and $12.00. Hidden and known-secret echo fields were withheld; five
native frames were observed while only root fields published. Same-origin,
cross-origin, inherited srcdoc and sandboxed srcdoc child markers did not occur
in output. A root password control withheld all fields. A CSP-sandbox root
failed with effective-origin-unverified and no fields; its temporary native
diagnostic established raw origin `://`, then was removed.

The final instrumented actual four-case run passed. The deterministic paused
case used exact owned app PID33187, observed self-stop after timestamping but
before native dispatch and timer arming, resumed after3.4s, and required timeout
failure with no fields. Therefore its rejection comes from continuous boundary
checking, not an already-armed queue timer. It does not exercise a buffered late
native response or a pause immediately before final publication; those guards
were reviewed independently in source. Both concrete findings are closed at
this stated scope.

The first rebuilt four-case attempt instead timed out40s on its initial public
fixture, before any capture-start or lifetime stage appeared in retained stderr.
This is a real open result, not deadline-oracle success. The test then cleaned
up its app and temporary profile without a live native sample; the reviewer
requested exact owned process sampling and failure-profile retention before
further retries, consistent with the earlier N1 lifecycle diagnostic practice.
No causal link to the new reader source, signing correction or prior teardown
watchdog is established by this evidence.

The owner subsequently strengthened that same app oracle to retain the exact
owned PID/state/return code, sample an unreaped live app at8s on its sole-owner
thread, and retain failed profile/result/stderr under ignored context. The
instrumented four-case repeat with the same stdio shape passed, with all startup
and shutdown stages recorded. Ordinary public PID33119 and sensitive PID33156
were still alive at8s and sampled in the main AppKit run/event loop. The stripped
framework's nearest exported symbol aliases do not identify actual internal
functions. This does not explain the prior40s timeout or establish a causal
reader fix; retain that nonreproduced result as an empirical lifetime limit.

Not yet exercised by the native reader smoke: lifecycle change mid-capture,
detach/reattach, queue saturation, close during pending projection, repeated
capture/retry reconciliation, ambiguous fields and every malformed decoder
shape. Source guards were reviewed, but there is no claim that these direct
fault cases passed. The current unit supports a narrow owned fixture milestone.
N3 native-work/control-owner gates, general sensitivity policy, retained-table
authority, OS input, model export and the earlier unexplained teardown watchdog
remain separate open work. Detsim and mutants stay deferred by the operator.
