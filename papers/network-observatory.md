# Network observatory: requests, responses and tracking drift

Research date: 2026-10-01. Scope: Bow Shock's owned browser, macOS first and
Linux second. The operator wants to inspect and handcraft both requests and
responses, retain useful traffic logs, and notice meaningful changes in tracking
behavior, including Meta/Facebook Pixel. These capabilities are distinct from
agent navigation. This report studies mechanisms and limitations; it does not
choose dependencies, implement a product, or promise complete network capture.

Read alongside [agent connections](agent-connections.md),
[browser engines](browser-engines.md) and the requirements/design work. The host
remains the authority for the coding-agent connection. A proposed network send,
replay or substitution is a separate capability requiring its own bounds; access
to network tools must not implicitly grant arbitrary page JavaScript or CDP.

## Observation, intervention and handcrafted traffic

| Mechanism | Useful purpose | Material limits |
| --- | --- | --- |
| CDP `Network` | Observe browser request/response events, available bodies, timing, cache/worker attribution, WebSocket messages | Target/session coverage and bounded buffers; unavailable bodies; event ordering; evolving experimental streaming |
| CDP `Fetch` | Pause matching requests, change method/headers/body, cancel, supply responses, handle auth | Changes page execution and timing; every paused request needs a decision; response-stream ownership is destructive |
| CEF resource request handlers | Owned-browser native request hooks and lifecycle attribution | IO-thread callbacks, worker requests without frames, immutable response headers at the ordinary response callback |
| CEF response filter | Observe/transform streamed response content | Body filter only; cannot set status/headers; must consume and flush correctly without blocking IO |
| CEF custom resource handler | Provide a response with chosen status, headers and streamed content | A replacement loader, with responsibility for cancellation, ranges, redirects and asynchronous reads |
| Dedicated request composer | Human reviews and sends a newly constructed request | Auth context must be explicit; a replay can repeat server side effects and change cookies |
| External TLS-intercepting proxy | Independent HTTP-flow inspection and mutation | Trust/routing changes; traffic served locally is absent; proxy protocol and replay limitations |

DevTools already offers an instructive human interface: inspect headers and
payload, copy requests as cURL/fetch, and persist local response overrides.
Overrides disable cache and do not save arbitrary changes in the Elements DOM
tree. These are useful precedents for showing intervention as a visible mode.
[DevTools Network reference](https://developer.chrome.com/docs/devtools/network/reference),
[local overrides](https://developer.chrome.com/docs/devtools/overrides).

The logical browser view, page-visible response, and bytes exchanged on the
network are different evidence. A cache hit or service-worker-generated response
may have no corresponding server exchange. Protocol header maps cannot restore
HTTP/2 or HTTP/3 wire framing or exact header byte order. Inspection should retain
representation labels and source rather than call every body "raw".

## CDP: separate the observational and paused-request paths

Read the pinned PDL as the contract, then the corresponding implementation. The
existing protocol acquisition is revision
`8b7f1d955017db8633ecae04cdfa194f731c9eff`; its browser runtime still needs a
capability probe and compatible engine pin. Tip-of-tree documentation is a moving
reference, particularly for experimental commands.
[Network PDL](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Network.pdl),
[Fetch PDL](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Fetch.pdl).

`Network.enable` exposes aggregate/per-resource buffer bounds and a maximum POST
notification size. `getResponseBody` returns text plus `base64Encoded`;
`getRequestPostData` explicitly omits files from multipart data. A missing,
evicted, incomplete, file-excluded or unrequested body must have a distinct
availability reason, not become an empty body. Chromium's renderer resource
store evicts content under both per-resource and aggregate budgets. Its network
agent emits errors when the requested resource/body is missing or evicted.
[Resource store](https://github.com/chromium/chromium/blob/faee0a28a27e62768c53844d7a29a63d609315dd/third_party/blink/renderer/core/inspector/network_resources_data.cc),
[renderer network agent](https://github.com/chromium/chromium/blob/faee0a28a27e62768c53844d7a29a63d609315dd/third_party/blink/renderer/core/inspector/inspector_network_agent.cc).

Durable messages can retain response data outside a renderer across process
swaps. The current PDL deprecates the `enableDurableMessages` enable argument in
favor of experimental `configureDurableMessages`, noting a possible deadlock
when enable is awaited before releasing a debugger-waiting renderer. Do not
copy a generic "turn on everything before resume" sequence without checking the
pinned runtime. Experimental `streamResourceContent` returns buffered data and
adds body chunks to subsequent `dataReceived` events; ordinary byte-count events
are not automatically a response-body stream. Indefinite EventSource and large
downloads require bounded incremental storage, with truncation and connection
close represented explicitly. [Network PDL](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Network.pdl).

Network extra-info events can arrive before or after their main event, and some
requests have none. Correlation must therefore tolerate late fields and retain
raw events. Redirect chains require hop identity: `requestWillBeSent` carries
the preceding redirect response; Fetch has its own request ID and optional
`networkId` and `redirectedRequestId`. Extra-info status can distinguish a wire
304 from the effective cached 200, or supply a response status for a CORS failure.
Duplicate headers in that extra-info map are concatenated with newlines;
`headersText` may be absent for HTTP/2 or QUIC. Cookie send/block information is
separate from simply reading the page cookie string. [Network PDL](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Network.pdl).

Use `(browser session, CDP session/target, request ID, redirect hop)` rather than
a global request ID alone. Preserve frame/document/loader association when
present, initiating stack, timestamps and cache/service-worker flags. Frames
and workers need coverage across navigation and startup; workers can lack a
loader or frame. An observer attaching after an exchange cannot reconstruct all
earlier bodies. Logging scope should state which targets were attached and when.
[Renderer agent](https://github.com/chromium/chromium/blob/faee0a28a27e62768c53844d7a29a63d609315dd/third_party/blink/renderer/core/inspector/inspector_network_agent.cc),
[browser network handler](https://github.com/chromium/chromium/blob/faee0a28a27e62768c53844d7a29a63d609315dd/content/browser/devtools/protocol/network_handler.cc).

For WebSocket capture, retain handshake and message events separately from HTTP
bodies. PDL defines text payload for opcode 1 and base64 for other opcodes.
DevTools' Messages display shows only the last 100 messages; copying its display
is not an enduring log. Network PDL has WebTransport lifecycle events, which
should not be mistaken for a complete WebTransport payload log.
[Network PDL](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Network.pdl),
[DevTools reference](https://developer.chrome.com/docs/devtools/network/reference).

`Fetch.enable` pauses matches until continue/fail/fulfill; broad filters would
turn passive logging into a browser-wide dependency on an editor/agent. Request
continuation can change URL invisibly to the page, method, POST body and headers.
Header overrides apply to that hop, not automatically to redirected requests.
`fulfillRequest` can provide status, headers and body. Experimental
`continueResponse` can change status/headers but requires the full corresponding
set when any is changed. [Fetch PDL](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Fetch.pdl).

Crucially, `Fetch.takeResponseBodyAsStream` is not a passive tee. After taking
the stream, the request cannot continue unchanged: cancel it or provide a body.
Only sequential reads are supported. `getResponseBody` is mutually exclusive
with stream-taking, is limited to response-stage pauses, and has no redirect
response body. Commands that change the request or disable the domain while a
body retrieval is underway have undefined behavior. The Chromium interceptor
owns the body pipe and implements these paths; read its state machine before
designing live response editing. [Fetch PDL](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Fetch.pdl),
[URL loader interceptor](https://github.com/chromium/chromium/blob/faee0a28a27e62768c53844d7a29a63d609315dd/content/browser/devtools/devtools_url_loader_interceptor.cc).

## CEF: native hooks and response-editing limits

The existing full CEF source acquisition at
`ff57d4eae16d36457895f2de115a71d502e85a08` supplies the following study paths.
`OnBeforeResourceLoad` can modify or cancel a request, asynchronously if needed.
`OnResourceRedirect` allows changing the destination. `OnResourceResponse`
receives a read-only response: it does not permit editing HTTP status or headers.
Its request-based retry/redirect path is deprecated. `GetResourceResponseFilter`
also receives read-only request/response objects. [Resource request handler](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_resource_request_handler.h).

`CefResponseFilter` transforms streamed content, with explicit counts of bytes
consumed and written, bounded output space, pending-output/empty-input flush
handling, and an error result. Retaining input buffer pointers is forbidden.
Callbacks run on browser IO, so a database write, agent round-trip or slow UI
cannot run inline there. A copying queue with explicit byte limits/loss behavior
is a design candidate, not an excuse for silently dropping data. The wrapper
uses Mojo data pipes and a pending-output buffer. This reading did not establish
whether every compression/encoding path supplies the same representation; test
gzip, binary, ranges and cancellation before naming the captured bytes.
[Filter interface](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_response_filter.h),
[filter wrapper](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/libcef/browser/net_service/response_filter_wrapper.cc).

A fully handcrafted response needs a custom `CefResourceHandler` or Fetch
fulfillment. The custom handler supplies status, MIME type, optional headers and
length, can redirect, and implements asynchronous read/skip/cancel. Body editing
alone cannot correctly claim a changed HTTP status or remove a response cookie.
Original versus browser-delivered responses should both retain their identity;
the server's original side effects are not undone by substituting its response.
Content length, charset, compression, ranges, integrity and cache interactions
remain concrete verification work. [Resource handler](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_resource_handler.h).

CEF browser/frame references may be absent for service-worker and standalone
URL requests. Completion may arrive after browser close, and includes aborted
loads. The source has worker-fetch regression tests for requests after browser
close, navigation and shared-context association. Study
`libcef/browser/net_service/resource_request_handler_wrapper.cc`,
`tests/ceftests/resource_request_handler_unittest.cc`,
`tests/ceftests/urlrequest_unittest.cc` and
`tests/cefclient/browser/response_filter_test.cc`; do not infer that every worker
belongs to the currently visible tab. [Handler interface](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_resource_request_handler.h),
[worker tests](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/tests/ceftests/resource_request_handler_unittest.cc).

## Authenticated handcrafted requests and replay

Request editing can mean changing an in-flight page request, sending a new request
from the browser's profile, or sending from an independent HTTP client. Those
must be distinguishable. A new request using stored credentials can perform
server mutations even if its method is GET; retry must not be automatic merely
because a connection or coding-agent turn ended.

`CefURLRequest::Create` creates a browser-process request without a browser/frame
association and accepts an explicit request context (otherwise the global
context). Its POST supports only one FILE or BYTES element. Frame-associated
`CreateURLRequest` is a different path. `UR_FLAG_ALLOW_STORED_CREDENTIALS` permits
stored username/password/cookies to be sent and response cookies to be saved.
Make both credential use and resulting session changes part of the operator's
send decision. Multipart data may exclude elements in `CefPostData`; inspector
display of those elements is not a faithful replay payload.
[URL request interface](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_urlrequest.h),
[request/post-data interfaces](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_request.h),
[request flags](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/internal/cef_types.h).

Page `fetch` remains constrained by browser credentials policy, forbidden headers
and CORS; it is not an unrestricted raw request editor. An independent client has
its own cookie jar, TLS fingerprint and network behavior. CDP `Network.replayXHR`
is experimental and specifically replays an original XHR configuration, not
every HTTP request. Do not market these three paths as equivalent.
[MDN Fetch](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch),
[Network PDL](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Network.pdl).

Host-granted network operations should bind destination, redirects, credential
context, method/body, duration and result-byte limits independently of page
driving grants. The host validates the actual request, not merely a tool name;
otherwise a raw CDP command, arbitrary JS or request-to-local-service can bypass
the intended boundary. Human takeover must release or cancel already paused
requests without waiting for the agent. This is a design recommendation, not a
claim that these primitives already enforce Bow Shock's policy.

External interception is another reference option. mitmproxy uses two TLS
connections and requires trust in its interception CA. Its protocol docs declare
HTTP/1 trailer, HTTP/2 priority/push and HTTP/3 compatibility/replay limits;
WebSocket client/server replay is also unsupported. It cannot observe an HTTP
exchange that the browser satisfies locally. Such a proxy changes the experiment
and needs separate trust/routing decisions; native decrypted hooks avoid an
additional CA. [How mitmproxy works](https://docs.mitmproxy.org/stable/concepts/how-mitmproxy-works/),
[protocol limitations](https://docs.mitmproxy.org/stable/concepts/protocols/).

## Facebook/Meta Pixel: baseline behavior rather than changing identifiers

Current Meta Pixel reference, implementation and advanced-matching pages could
not be read here (429/fetch failure); Business Help redirected to login. Preserve
that acquisition gap. The available official Blueprint material confirms that
advanced matching shares hashed customer information with website events; that
does not make the payload anonymous or appropriate for unredacted agent context.
[Meta Blueprint advanced matching](https://www.facebookblueprint.com/student/path/211540-advanced-matching-course).

The primary PixelConfig paper uses differential static/dynamic analysis and
configuration ablation, with archived health/control websites from 2017–2024.
It distinguishes activity, identity and restrictions. Its observed traffic uses
`facebook.com/tr`, GET/POST, pixel IDs, page/referrer fields and bracketed
custom/user-data parameters. These observations are useful parser hypotheses,
not a complete current vendor contract. The authors explain why live dynamic
traffic alone misses behaviors requiring unvisited pages or interactions.
[PixelConfig, v1](https://arxiv.org/html/2603.09380v1).

The author repository is pinned separately in the catalog. Its
`Analysis/processSnapshots.py` extracts configuration structures with regular
expressions and JSON parsing; notably its `fbq.set` pattern accepts an empty
array, not arbitrary nonempty rule arrays. Study its collection/provenance and
normalization techniques; do not adopt the parser as a general JavaScript parser
or claim its CSV schemas exhaust current Pixel behavior.
[Pinned parser](https://github.com/Yash-Vekaria/pixel-config/blob/4426e53848932a5e4f4aa95b1a4d598d59bee6a2/Analysis/processSnapshots.py).

Proposed baseline dimensions should come from observed exchanges and declared
normalization rules:

- Stable semantics: destination family/path, HTTP method, observed pixel/event
  identity, parameter names and value types, nested payload shape, data categories,
  initiating script/config identity, cookie/advanced-matching presence, and
  relationships to the operator's page/action.
- Expected variation: timestamps, nonce/event/click/browser IDs, cookie values,
  session-specific tokens, experiment assignments, and variable product data.
  Preserve meaningful presence/type/format changes without treating every new
  exact value as an alert. A pixel identifier can be deployment-stable while a
  click identifier is naturally variable; one blanket "ignore IDs" rule loses
  useful evidence.
- Observation context: route/page type, document epoch, consent state, login
  state, action sequence, profile/cache/worker settings, engine and observer
  versions, attachment coverage and observation duration.

These are Bow Shock design inferences, not Meta guarantees. Detection should
combine destination with initiator/script and parsed event evidence. A matching
hostname alone identifies traffic, not its semantic purpose. Browser evidence
cannot establish the absence of server-to-server conversions or all trackers,
nor that a hashed value is harmless. No request during a partial log proves
neither tracking absence nor a site change.

Candidate alerts: new destination/event/data category, new parameter or type,
changed deployment identifier, newly exposed query/referrer detail, newly present
advanced-matching fields, and a changed configuration/script behavior. Expected
event disappearance requires comparable covered actions and observation bounds.
Rate/count changes should compare like contexts with sample counts. Changes in
consent state, instrument configuration or browser release should first explain
the difference rather than silently become a new tracking baseline.

Keep raw capture under an explicit local retention policy and expose redacted
views to the coding agent. Sanitized HAR excludes some sensitive headers by
default but does not establish that URLs and bodies contain no personal data.
Parser-derived records should retain capture/body identity, parser version,
normalization rules and baseline version. An offline comparison then reproduces
the actual difference without sending a live tracker request. Store a proposed
baseline separately until the operator accepts it; never let an alert rewrite
its own comparison reference. [HAR export behavior](https://developer.chrome.com/docs/devtools/network/reference).

## Connection to rendered DOM extraction and direct verification

The rendered-DOM/table mapping is a separate lane. Network rows can link a
rendered snapshot via browser/tab/document epoch and timestamps, but the original
HTML response and a JSON API response are not the locally rendered table. Late
responses, SPA route changes and worker fetches must not be attributed solely
by the tab's current URL. Persist those uncertain links as uncertain.

Before selecting mechanisms, a small controlled browser/server experiment should
directly compare received requests, server responses and browser-delivered
responses. Exercise redirects with credentials, duplicate headers, multipart
files, compression/binary/range bodies, cache hits and 304, service-worker local
responses and worker lifetime, process swaps, buffer eviction, indefinite SSE,
WebSocket text/binary, cancellation and human release of a paused request. These
are independent fault classes; server observations answer the wire/send claim,
browser delivery answers the response-edit claim. An event log checking its own
derived summaries would not establish either.

Unresolved: exact current Meta event/wire parameter contract; CEF filter
representation under compression and alternate loaders; runtime support and
retention behavior for experimental CDP body streaming/durability; coverage of
all owned-browser worker/download contexts; and acceptable local retention and
agent disclosure scope. macOS/Linux packaging and callbacks need platform
verification after the engine choice. No upstream software was executed in this
research.
