# Proposed native runtime and observation contract

Design proposal, 2026-10-01, [tribunal reviewed](../../papers/design-tribunal.md). The operator has authorized design under Blackbird; this document does not adopt CEF, choose a binary distribution, install dependencies, or authorize implementation. It proposes an owned, windowed CEF runtime, macOS first and Linux second, with native rendered-page observation and a separate OS input executor. The model consumes observations and returns proposals; it does not drive the page.

The proposal follows [product intent](../product-intent.md) and the acquired [engine](../../papers/browser-engines.md), [native surfaces](../../papers/native-browser-surfaces.md), and [OS input](../../papers/os-input-and-behavior.md) research. Requirements below are proposed invariants. Source reading establishes available interfaces and constraints; **no candidate CEF binary has been run, and no compatibility, snapshot coverage, sandbox, or OS delivery behavior has been measured**.

## Runtime choice and ownership

Propose CEF's Chrome bootstrap with Chrome-style, windowed browser content. Prefer the Chrome layer's existing browser features and dialogs as the first study candidate. This does not promise Chrome branding, services, codecs, account integration, fingerprint equivalence, or site acceptance. The acquired architecture says Alloy bootstrap was removed in M128 and that Chrome bootstrap can host Chrome or Alloy styles; an old “choose Alloy versus Chrome runtime” instruction would miss that distinction. [Pinned architecture](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/docs/architecture.md).

The native host owns one dedicated top-level window and a browser-instance registry. Each browser surface has a host-issued identity that is never reassigned during the host's lifetime. CEF integer browser IDs, native window handles and frame IDs are lookup keys within that identity, not durable user-task identities. Browser tabs/popups, if supported, are explicit new surfaces: preserve opener identity and consult the control authority before observation or delegated effects. A popup does not inherit model authority merely because its opener was authorized. Human navigation, browser controls, permission dialogs and downloads remain human/browser behavior with their own execution owners.

CEF/Chromium owns renderer, GPU, network and utility process creation and isolation. Retain the sandbox and normal engine site-isolation behavior; do not relax it to simplify native inspection. The host owns app lifecycle, browser lifecycle callbacks and the observation broker. It does not infer process ownership from the visible URL or assume one renderer per tab. [CEF process model](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/docs/general_usage.md), [Chromium process/site-isolation study source](https://github.com/chromium/chromium/blob/faee0a28a27e62768c53844d7a29a63d609315dd/docs/process_model_and_site_isolation.md).

Reference pins are CEF `ff57d4eae16d36457895f2de115a71d502e85a08`, Chromium `faee0a28a27e62768c53844d7a29a63d609315dd`, and protocol `8b7f1d955017db8633ecae04cdfa194f731c9eff`. These are separate acquired study revisions, **not a demonstrated compatible release tuple**. A later distribution proposal must name its matching CEF/Chromium/API/protocol versions, OS/architecture, packaging and feature support.

## Processes, threads and authority

| Owner | Proposed responsibilities | Boundary |
| --- | --- | --- |
| Native host, CEF browser UI thread | Browser/frame lifecycle; dispatch fixed observation methods; copy DevTools callback bytes; maintain live identity registry | No inference, unbounded parsing, archive I/O or model-controlled method dispatch on UI thread |
| CEF renderer main thread | Blink's native DOMSnapshot/AX work; optional restricted CefDOMVisitor adapter | Engine handles stay inside engine-defined callback scope; no model runtime or native control capability |
| Observation worker | Decode owned message copies, filter sensitive data, join frame fragments, normalize provenance, publish bounded immutable observations | Cannot inject page input, execute JS or invent completeness |
| Onboard inference / coding-agent connection | Read approved observation records; issue typed proposals | No CEF objects, arbitrary CDP envelopes or OS input handles |
| Control authority and OS executor | Validate accepted intent/current target; deliver actual keyboard/mouse/scroll events; takeover/cancellation | Defined by the control/input design; observation is insufficient authority |

CEF's DevTools observer runs on browser UI thread. Its message/result/parameter bytes are valid only during the callback. Copy bounded bytes while that scope is valid; process the copy elsewhere. Enforce host-owned response-copy, parsing/node, memory and deadline budgets. These bound host retention/work, not native Blink traversal or DevTools serialization: `captureSnapshot` has no node/time-limit parameter. A timeout can stop waiting without stopping engine work. If a callback already received an oversized message, record failure and release it; native filtering afterward does not undo engine work or guarantee the UI was unaffected. Record observation overhead and dropped/truncated fragments. [Observer contract](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_devtools_message_observer.h).

Permit at most one native capture transaction per owned browser, with one
coalesced pending refresh; child fan-out is bounded by that transaction's
measured concurrency limit. Do not retry repeatedly while an engine capture is
unresolved. Large-page native work, cancellation/watchdog semantics and lifecycle
responsiveness are capability gates measured on real growing-tree/text fixtures.
If full snapshots cannot meet the operational limit, disable that capture mode
and expose only a separately verified partial reader. Never present a host discard
as a hard renderer work bound. The OS helper's stop/liveness channel and physical
stop shortcut must remain independent of blocked CEF UI/observation callbacks;
otherwise delegation is unavailable during that observation mode.

The host-side observer is privileged native code. Renderer responses and IPC payloads remain untrusted data: validate size/schema/session/frame membership and lifecycle against browser-owned state before publication. A page cannot assign a trusted origin by supplying an attribute, URL-looking string or serialized record. The coding-agent integration must separately prevent general shell/native privileges from bypassing this interface. A pipe allowlist alone cannot enforce “model never drives the page” if the same agent can run arbitrary commands on the desktop; that confinement gate belongs to the agent/control design.

## Native observation transport

Use a local native CEF DevTools attachment; no remote-debug listener is required. The broker creates method names, parameter schemas and session envelopes from its own fixed operation table. Models request a bounded observation operation, never arbitrary protocol JSON. Observation excludes `Runtime.evaluate`, script injection, CEF DOM setters, direct navigation, cookie mutation and `Input.dispatch*`. Entire protocol domains cannot be granted wholesale because reader and writer commands coexist.

Proposed reader operations are native DOMSnapshot capture with a fixed minimal computed-style set; bounded AX tree retrieval for specified live frames; native DOM geometry/hit-test reads for specified observation nodes; frame/target metadata and lifecycle subscriptions needed for identity. Screenshot transport is a separately reviewed reader because it can disclose mixed-origin and sensitive content. Enabling observation domains, lifecycle subscriptions and target attachments changes inspector state, but gives no page-actuation authority; it is not zero-impact measurement. Measure overhead and changes to AX availability, timing and runtime identity.

CEF's convenience `ExecuteDevToolsMethod` constructs `id`, `method` and `params` only. It has no session-envelope argument. `SendDevToolsMessage` forwards a raw envelope, and `OnDevToolsMessage` sees raw responses before CEF's typed event/result parsing. Those typed callbacks omit session identity. Consequently, cross-process target routing must use **broker-generated** bounded envelopes and raw callback parsing that preserves `sessionId`; global message IDs, native attachment IDs, target membership and pending request ownership must remain explicit. This path is source-supported but not yet verified in a candidate binary. No model receives the raw transport. [Pinned controller implementation](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/libcef/browser/devtools/devtools_controller.cc), [browser interface](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_browser.h).

If local child-target routing cannot be established, publish explicit partial frame coverage and prohibit proposals requiring the missing frame. Do not silently substitute a page-JavaScript extractor, disable site isolation or attach to unrelated targets. A target-discovery/attachment controller may use protocol management commands solely to establish observation sessions; every attached target must belong to the authorized browser surface/frame graph.

## Representation, visibility and sensitive data

The primary observation is an immutable native **rendered-page projection** joining DOM structure, layout/style/text, AX semantics and optional pixels. These are independent projections captured over intervals. DOM nodes with no layout, offscreen layout, AX ignored nodes, generated content, shadow roots, canvas/video and compositor effects have different meanings. Keep their distinctions; do not call text content “visible text” or call a layout rectangle “clickable.”

Blink's acquired DOMSnapshot implementation performs a native lifecycle update through compositing inputs and traverses local documents/nodes. It does not run a model-authored JavaScript extraction routine, but it can expose hidden nodes and input values. Shadow DOM is flattened. A snapshot's native origin does not mean its entire contents are safe or equivalent to the window's pixels. [Snapshot implementation](https://github.com/chromium/chromium/blob/faee0a28a27e62768c53844d7a29a63d609315dd/third_party/blink/renderer/core/inspector/inspector_dom_snapshot_agent.cc), [schema](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/DOMSnapshot.pdl).

Default model projection includes authorized rendered/semantic content relevant to the current view. Expanded offscreen DOM for table extraction requires the observation scope to permit it and must retain `offscreen`/`hidden`/`visibility_unknown` markers. DOM/layout/paint order alone cannot settle occlusion. Where the renderer cannot establish the requested visibility, preserve uncertainty or withhold content; native hit-test and optional current pixels add evidence rather than manufacture certainty.

Before publication/logging, enforce supported structured exclusions: password/
credential/payment input values, credential headers, known sensitive URL/form
fields and host-known secret matches in supported representations. Redact content
and provenance, including titles and AX names, under the same policy. These
rules do not prove that arbitrary visible prose, images or mirrored values contain
no secrets. A semantic classifier can suggest sensitivity; it cannot certify absence.

Sensitive authentication/payment forms or an unknown page-sensitivity state are
withheld as a page/region across DOM, AX and pixels until the person chooses a
concrete disclosure scope. An approved routine page-family projection names the
allowed visible/semantic fields and representations, with residual unrecognized
secret/echo risk stated in its review. Newly detected sensitive regions suspend
that projection. Known marker echoes are excluded where enforceable; if a
modality cannot enforce its reviewed exclusion/crop, withhold it. Expanded/raw
diagnostic capture is a separate explicit local policy, never an automatic model
view. This narrows the guarantee to enforced classes and reviewed projection,
rather than promising universal removal of authentication/payment secrets.

Scope applies per frame/origin, not just top document. If screenshot redaction
cannot enforce the chosen policy, it is unavailable to that consumer. Restrict
raw callback copies to the bounded processing interval and do not persist raw
DOM/protocol dumps by default. Preserve withheld/missing reasons separately
from empty values. Include mirrored markers in ordinary text/ARIA/URL/canvas and
unknown supported text in the direct actual-payload oracle.

Proposed AX access uses local CDP Accessibility for structured model semantics; platform AX remains the browser's assistive-technology integration. In windowed CEF, Complete mode provides Chromium-managed platform AX objects. `CefAccessibilityHandler` TreeOnly callbacks are associated with windowless integration and are not assumed to be the owned-window route. Keep experimental AX viewport collapse off for the first candidate because the acquired option disables CDP `nodesUpdated` events; neither this choice nor `getFullAXTree` proves full frame coverage. [CEF AX behavior](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_browser.h), [AX schema](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Accessibility.pdl).

CefDOMVisitor is a possible fallback for bounded structural reads, not the primary rendering-aware projection. VisitDOM is renderer-only; visitor document/node handles must be released before returning. Copy primitives without inference or blocking work in the callback. CEF immediately detaches the document afterward. Its `GetElementInnerText` implementation calls Blink TextContent, and form values are transformed; neither is an exact visible/raw-value oracle. Report reduced capabilities instead of pretending fallback output matches DOMSnapshot. [Lifetime implementation](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/libcef/renderer/frame_impl.cc#L255), [node implementation](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/libcef/renderer/dom_node_impl.cc).

## Identity, capture and invalidation

Each observation contains the following conceptual fields; this is a contract, not an implemented wire schema.

| Field group | Required meaning |
| --- | --- |
| Host/browser identity | Host run, dedicated window/surface identity, live CEF browser association; never recycled into an old proposal |
| Native routing identity | Attachment generation, target/session, frame namespace and ID; verified joins between CEF and CDP namespaces |
| Document identity | Host-issued monotonically new document incarnation on committed replacement; engine loader identity where available; BFCache activation generation |
| Origin provenance | Browser/engine-derived effective security origin and document URL separately; opaque/unknown status; never inferred solely from URL |
| Capture identity | Unique capture/fragment IDs, monotonic start/end intervals, operation/runtime/projection versions, completed versus failed/canceled fragments |
| Presentation context | Viewport/scroll/zoom/backing scale/content bounds/display mapping, timestamped per fragment; local presentation revision and uncertainty |
| Node joins | Observation-local DOM index, session/document-scoped backend node/AX IDs; no permanent node authority |
| Coverage | Expected frame graph, observed authorized frames, withheld/missing/changed/detached/unsupported frames, truncation budgets, representation limits |

A CEF frame ID is not presumed equal to a CDP frame ID. Establish the mapping through native browser/frame/target metadata and test it across swaps; missing mapping is missing provenance. Effective origin comes from engine metadata such as Page frame `securityOrigin`, with URL retained only as location. Sandboxed opaque origins, inherited about:blank/srcdoc and redirects need explicit treatment. A serialized opaque origin cannot establish that two opaque origins are the same authority: bind it to that document incarnation, or mark the authority unknown. [Page frame schema](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Page.pdl).

Lifecycle states are `created_unattached`, `attached_active`, `detached`, `destroyed` for routing, plus document/activation generations. Unattached temporary cross-origin frames cannot produce accepted observations. Detach, replacement, renderer termination, browser close or inspector-agent detach invalidates affected pending captures and node joins; pending requests have deadlines because detached-agent results may never arrive. BFCache reattachment does not resurrect old action eligibility. Navigation inside the same document can retain document identity but changes relevant location/presentation state. [CEF frame callbacks](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_frame_handler.h), [inspector detach](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_devtools_message_observer.h).

`DOM.documentUpdated` invalidates protocol node IDs. DOM/layout can also change without navigation: lazy loads, animation, fonts, zoom, human scroll, resize and overlays. The host's presentation revision advances on known relevant events and new captures; it is **not an engine-wide layout epoch or proof that all mutations were observed**. AX update subscriptions are incomplete evidence, too. Model proposals retain the observation ID and semantic target; the executor must independently refresh/validate the current target and mapping. It cannot authorize an effect from the old rectangle alone. No atomicity is claimed between capture, native validation and an OS event; human takeover cancels queued work, and the input design must bound the residual race.

## Mixed-origin and OOPIF aggregation

The evidence registry supplies the shared `ObservationRef` tuple. Attachment
and BFCache activation generations are mandatory even when a loader/document
identity survives. `DOM.documentUpdated` and known native node-ID invalidations
advance a node-reference generation and invalidate affected action references.
Observation-local indexes remain readable within their retained snapshot, but
cannot be reinterpreted as current protocol nodes. Effective-origin matching
uses [the shared denied/opaque-frame policy](control-and-input.md#grant-and-intent-records);
unknown metadata grants no implicit frame authority.

One local snapshot is not a globally atomic browser snapshot: acquired Blink code iterates `LocalFrame` objects. The broker discovers the browser-owned frame graph, fans out bounded reads to verified local/OOPIF sessions, then checks the graph and document incarnations again before publishing. Its aggregate records per-fragment intervals and coverage. Root/frame changes during capture yield `changed_during_capture` for the affected region or cancellation if root identity cannot be established. Missing child content is a typed gap, never an empty iframe or a fabricated join.

Joining DOM/layout/AX requires compatible frame/document incarnation and native node linkage. If an AX fragment and DOM fragment disagree or arrive across an invalidation, do not splice them into one node. Policy may permit a partial observation for summarizing the remaining authorized content; proposals concerning missing, withheld or incompatible fragments cannot execute. Capture width, cross-process skew and presentation-change budgets must be selected from native runtime measurements before action-sensitive observations are accepted.

Observation authority is supplied by the control design and explicitly covers browser surface, effective frame/origin scope, representations and sensitive/offscreen content. Cross-origin visibility on screen does not automatically permit unrestricted native DOM export. A full-page screenshot can cross those same scope boundaries. A policy grant covering all visible frames must be explicit; an origin transition triggers reevaluation even when a frame remains in the same screen rectangle.

## Platform and compatibility gates

macOS candidate packaging must follow the matching CEF distribution's app/framework/helper/sandbox layout, initialize the correct NSApplication/event-loop integration, and shut down only after browser lifecycle completion. Acquired sandbox docs specify dynamically loaded macOS sandbox support from M138; the sample is source guidance, not evidence that an unsigned or differently packaged binary is sandboxed. Match API versions with the distribution. Linux follows after this contract works on macOS, with its own sandbox, toolkit/compositor, fonts, GPU and event-routing characterization. [Sandbox source docs](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/docs/sandbox_setup.md), [macOS sample](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/tests/cefsimple/cefsimple_mac.mm).

Coordinate conversions are explicit transforms, not a universal devicePixelRatio multiplier: CSS/layout coordinates, widget coordinates, host content coordinates, Cocoa's origin convention, display scale and OS screen coordinates differ. CEF docs distinguish DIP, CSS zoom, native toolkits and macOS behavior. Verify multi-display transitions and overlays/browser chrome before geometry is actionable. [Coordinate-system guidance](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/docs/general_usage.md#coordinate-systems).

Use the candidate runtime's coherent defaults first. UA overrides do not guarantee matching client hints; codecs/protected media, platform permissions, IME, accessibility, TLS, storage/workers, password/passkeys and downloads require feature checks and representative human workflows. Inspector attachment, AX enablement and native observation may themselves affect exposed state/timing. Compare observed values with a same-platform/version ordinary browser, record actual differences and usefulness, and avoid a single undetectability score. Actual OS events and `isTrusted` do not prove human origin, tracker resistance or acceptance. [Pinned UA metadata generation](https://github.com/chromium/chromium/blob/faee0a28a27e62768c53844d7a29a63d609315dd/components/embedder_support/user_agent_utils.cc).

## Direct verification scenarios before implementation approval

| Scenario | Direct oracle and required outcome |
| --- | --- |
| Main document replaced while capture is pending | Owned page A/B carry distinct visible markers and native commit identities; old A result cannot be published as B or authorize B input |
| Same-document layout shift without navigation | Owned page moves/overlays the target and changes its label; stale coordinates/semantic target fail current validation or refresh before input eligibility |
| BFCache return / renderer crash / inspector detach | Native lifecycle plus owned marker; old node/session/proposal associations invalid, captures terminate with reasons rather than hanging |
| Same-origin iframe plus cross-origin OOPIF | Owned origins expose distinct DOM/AX/visual markers; recorded graph matches actual coverage, per-fragment times and joins; missing child session is explicit |
| Child navigates between origin scopes during fan-out | Native commit/origin metadata and controlled marker; no A/B splice and no out-of-scope child text/AX/URL/pixels reach model |
| Sandboxed srcdoc/about:blank and opaque origins | Known owned sandbox/inheritance setup; effective-origin classification cannot be derived from URL or reused serialized opaque strings |
| Hidden/offscreen/password/canvas/shadow/overlay content | Owned expected values and current visual reference; policy exclusions hold across DOM, AX, screenshots and logs; unknown visibility remains unknown |
| Scroll/zoom/Retina/two displays/window resize | Owned marked target and native screen/window bounds; transforms locate the current content correctly, with uncertain mapping ineligible for effects |
| Budget exhaustion/malformed/late message | Controlled native test producer; broker rejects oversized or mismatched fragments, reports partial state, and keeps lifecycle/UI responsive |
| Model requests mutation or arbitrary target/session | Broker operation table and isolated agent capability oracle; no arbitrary protocol/input/JS command reaches CEF and no external shell bypass is available |
| Human takes control during model inference | Executor/control timeline; stale proposal remains observational history and does not issue queued OS effects |
| Platform compatibility | Actual matched binary, sandbox status and feature/workflow outcomes on macOS; repeat supported contracts on explicit Linux display/toolkit stack |

These scenarios directly attack identity, disclosure, lifetime, mapping and capability claims. They are not tests of downloaded tests or a request to install/run anything now. Unresolved gates are candidate binary/release selection, sandbox/API matching, local OOPIF envelope routing, effective-origin/frame-ID mapping, projection visibility/redaction, measurable capture budgets and skew, geometry validation, agent confinement, and ordinary platform/site compatibility. They must remain visible through tribunal review and the later implementation plan.
