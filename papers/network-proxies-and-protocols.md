# Traffic proxies, editors, replay and protocol source

Research date: 2026-10-01. This lane expands the source corpus around the
operator's request for a substantial network-tools quarantine. The browser is
owned by Bow Shock, with macOS first and Linux second. The purpose is human
inspection, handcrafted requests/responses and durable observation, with a native
coding-agent connection whose powers remain bounded by the host.

Sixteen upstream repositories have verified HEAD revisions and selected paths
in [the acquisition catalog](network-proxy-sources.json). The catalog also adds
primary product documentation and HTTP/QUIC/TLS specifications. Root owns
acquisition and the actual ledger; catalog inclusion alone does not mean a source
archive has arrived. Source review here means the paths and focused fragments
identified below, not a whole-project audit. No packages were installed, upstream
code executed, certificates trusted, routes altered or dependencies adopted.

Read [network observatory](network-observatory.md) for browser-native CDP/CEF
hooks, Meta Pixel baselines and capture gaps. This report studies complementary
proxy/editor and protocol patterns, rather than replacing those hooks.

Acquisition follow-up: the mitmproxy source archive timed out, so its final
catalog scope is a verified individual-file subset containing licenses,
replay/flow/stream/protocol source and pertinent tests. Rustls retains its source
archive after retry. Curl and quiche use focused ZIPs; completed earlier upstream
archives are also preserved and recorded. Final actual status is in the ledger.

## A useful source collection has different layers

| Reference | What it teaches | Focused source reviewed |
| --- | --- | --- |
| mitmproxy | Flow lifecycle, separate client/server replay, streamed transforms and persisted traffic | [replay addons](https://github.com/mitmproxy/mitmproxy/blob/1ef9cec94a53db9e9f76fc9cff84216db7592deb/mitmproxy/addons/clientplayback.py) |
| mitmproxy_rs | macOS transparent NetworkExtension, process selection, Unix IPC; Linux eBPF redirector | [native transparent provider](https://github.com/mitmproxy/mitmproxy_rs/blob/51fe2b7c5aa8439c162abb665db61c6669d146d6/mitmproxy-macos/redirector/network-extension/TransparentProxyProvider.swift) |
| HTTP Toolkit UI | Human request composer, breakpoint editing, encoded/decoded bodies and cancel state | [send-store model](https://github.com/httptoolkit/httptoolkit-ui/blob/c8e9f7e0b23844ad6e355cc5f4ec771ec7bdff66/src/model/send/send-store.ts) |
| HTTP Toolkit server | Owned Chromium launch configuration and powerful local control API | [Chromium interceptors](https://github.com/httptoolkit/httptoolkit-server/blob/14665bbcc39d8ed89ab2e82b5529f0f51b7cd94d/src/interceptors/chromium-based-interceptors.ts) |
| Mockttp | Matching/forwarding rules, response substitution, encoding and HTTP/TLS demultiplexing | [request handlers](https://github.com/httptoolkit/mockttp/blob/7d03b2d97d1ee82969780d0878dfb744aba2c6ae/src/rules/requests/request-step-impls.ts) |
| Proxyman Atlantis | App-internal capture and message transport without TLS interception | [URLSession capture](https://github.com/ProxymanApp/atlantis/blob/6427600ec87d516a43754e4eaa7762f3271ac77f/Sources/NetworkInjector+URLSession.swift) |
| Whistle | Request/response inspectors, streamed transformations and bounded UI caches | [response inspector](https://github.com/avwo/whistle/blob/33820c617df12894bb38a5e8ea9019b96b3c955e/lib/inspectors/res.js) |
| GoProxy | Small CONNECT/request/response hooks and explicit HTTP/2 MITM example | [HTTP2 example](https://github.com/elazarl/goproxy/blob/a05e9220be0b6fd84566bf0d5f5880be94f3db36/examples/http2-mitm/main.go) |
| Martian | Composable modifiers, MITM certificate configuration and HAR representation | [MITM configuration](https://github.com/google/martian/blob/0f7e6797a04da412118541344bbe0d65945e24c9/mitm/mitm.go) |
| nghttp2 | Sans-IO HTTP/2 state machine; nghttpx proxy stream/connection ownership | [programmers guide](https://github.com/nghttp2/nghttp2/blob/19d06e62185d93d2398d85241cdbb460349bfe44/doc/programmers-guide.rst) |
| quiche | QUIC transport, HTTP/3 and QPACK, app-controlled event loop | [H3 module](https://github.com/cloudflare/quiche/blob/77d50358f98610b7d2329b3ca5450e1131aaf883/quiche/src/h3/mod.rs) |
| aioquic | Python QUIC/TLS/HTTP3 event correlation and async request completion | [H3 client example](https://github.com/aiortc/aioquic/blob/6d36838d008c2202c337142fa07e8bf80e96bac8/examples/http3_client.py) |
| hyper-h2 | Explicit protocol events and padding-aware flow-control accounting | [flow-control guidance](https://github.com/python-hyper/h2/blob/bc239af1d1b85bc70482804f30a0e0e587d90a08/docs/source/advanced-usage.rst) |
| h11 | HTTP/1 framing state and incomplete-header buffer bounds | [connection state](https://github.com/python-hyper/h11/blob/62c5068c971579d61fa1b55373390e12f25fd856/h11/_connection.py) |
| curl | Manual sends, redirects/cookies, backend-specific HTTP3 and key logging | [HTTP3 option](https://github.com/curl/curl/blob/39ad9b0771708c5aff20663a7ef3704bc55510d7/docs/cmdline-opts/http3.md) |
| rustls | TLS ownership, secret logging and early-data example | [key-log interface](https://github.com/rustls/rustls/blob/7dcbe4c1ae12185237d22e9197583329630a2014/rustls/src/key_log.rs) |

The first group offers end-user workflows or proxy engines. The final group
exposes transport/state-machine mechanics; it does not by itself provide a
browser profile, human editor, trustworthy recorder or authorization system.
Those differences are why the corpus includes both.

## mitmproxy: replay is several operations

The client replay addon rejects live flows and already in-flight flows; it marks
an accepted flow as a replay, clears its prior response/error and queues it.
Its stop command clears the queue. That command's body is not evidence that an
already sent request was canceled or its server effects undone. Bow Shock's
operator-facing stop status must distinguish pending cancellation, connection
abort and unknown remote outcome. [client replay implementation](https://github.com/mitmproxy/mitmproxy/blob/1ef9cec94a53db9e9f76fc9cff84216db7592deb/mitmproxy/addons/clientplayback.py)

Server replay instead matches incoming requests to recorded flows, copies the
recorded response, and may refresh dates. Matching options can omit parts of
content, host, port, query and selected headers. Unmatched traffic can be
forwarded, killed or answered with a configured status. These settings define an
experiment, not faithful playback by default: ignoring a parameter can collapse
distinct requests, refreshing a response changes captured evidence, and forwarding
an unmatched request can contact a real endpoint. Preserve the matching policy
and original-versus-served response separately. [server replay implementation](https://github.com/mitmproxy/mitmproxy/blob/1ef9cec94a53db9e9f76fc9cff84216db7592deb/mitmproxy/addons/serverplayback.py)

The streamed transformation example accepts each body chunk and a final empty
chunk. It is a useful reminder that a text replacement may straddle chunk
boundaries and a filter may have buffered output left to flush. The HTTP1/2/3
layer implementations and client replay tests are retained for later deeper
study. Do not assume that a body retained in a flow object captures every streamed
byte under every configuration. [stream-transform example](https://github.com/mitmproxy/mitmproxy/blob/1ef9cec94a53db9e9f76fc9cff84216db7592deb/examples/addons/http-stream-modify.py)

## Local and transparent capture: diversion is not decryption

mitmproxy documents explicit proxy, process-local capture, WireGuard, reverse,
transparent routing and TUN modes. Local capture on macOS/Linux is outbound.
Linux local capture requires a privileged BPF helper, recent supported kernels
and restricted process-name matching; container coverage depends on networking
mode. Transparent routing differs from the newer local/WireGuard modes, including
UDP coverage. These are actual scope limits, not merely setup inconvenience.
[Primary mode documentation](https://docs.mitmproxy.org/stable/concepts/modes/).

The macOS redirector reference explains system-extension installation, a Unix
control socket, matching interception specifications, and a separate Unix socket
per flow for buffering/backpressure. `TransparentProxyProvider` resolves the
source application's audit token to process information. It leaves flows to the
system when no process/spec matches, copies intercepted TCP or UDP through IPC,
and cancels the proxy when the control channel fails. This is a substantive
native-authority precedent for macOS, including entitlements and shutdown paths;
it is a more invasive integration than configuring our owned browser alone.
[native transparent provider](https://github.com/mitmproxy/mitmproxy_rs/blob/51fe2b7c5aa8439c162abb665db61c6669d146d6/mitmproxy-macos/redirector/network-extension/TransparentProxyProvider.swift) [redirector lifecycle](https://github.com/mitmproxy/mitmproxy_rs/blob/51fe2b7c5aa8439c162abb665db61c6669d146d6/mitmproxy-macos/redirector/README.md)

Its Linux implementation uses eBPF for redirection. Core virtual-device,
TCP/UDP, IPC, selection and network-test source is included so a later Linux
review can trace what the redirector actually forwards. Neither an eBPF hook,
NetworkExtension nor WireGuard tunnel magically gives plaintext TLS. They route
or transport the connection; a TLS endpoint, authorized key material or existing
browser-native decrypted hook supplies content access. No whole-machine capture
is proposed by acquiring these references. [Linux redirector overview](https://github.com/mitmproxy/mitmproxy_rs/blob/51fe2b7c5aa8439c162abb665db61c6669d146d6/mitmproxy-linux/README.md)

The owned browser makes narrowly configured capture plausible, but renderer and
network-service processes can differ from the visible browser process. A PID
filter needs measured process-tree coverage. Network diversion also lacks the
rendered document identity supplied by CDP/CEF. Correlating a proxy flow by URL
and time alone should remain uncertain when requests overlap or workers survive
a tab. These are Bow Shock design inferences requiring runtime experiments.

## HTTP Toolkit: editor, agent-facing authority and transport must stay distinct

The UI send store constructs a separate request through its server API with URL,
method, headers and encoded body. It supplies explicit TLS/client-certificate,
proxy/DNS and key-log options and associates an AbortController with a pending
send. Response events assemble a separately recorded exchange. This demonstrates
a human composer independent of the intercepted browser; it does not demonstrate
that a new send inherits browser SameSite, service-worker, partitioned-cookie or
cache behavior. [send-store model](https://github.com/httptoolkit/httptoolkit-ui/blob/c8e9f7e0b23844ad6e355cc5f4ec771ec7bdff66/src/model/send/send-store.ts)

The breakpoint model updates a previously correct content length when an encoded
body changes, handles encoding separately, and omits pseudoheaders that the
transport generates. Study its body/headers/test paths before designing request
editing as a freeform string textbox. It matters whether a value is a semantic
header, generated HTTP2 control field, compressed body or a user-supplied stale
length. [breakpoint model](https://github.com/httptoolkit/httptoolkit-ui/blob/c8e9f7e0b23844ad6e355cc5f4ec771ec7bdff66/src/model/http/exchange-breakpoint.ts)

The official View documentation makes a particularly useful provenance caveat:
after breakpoint editing, its displayed exchange is from the client's perspective.
Consequently, a modified upstream request or original upstream response is not
that same view. It also explains breakpoint timeout and decoded/re-encoded body
handling. Bow Shock wants before/after tracking and handmade intervention, so
storing both perspectives explicitly is preferable to silently changing one
exchange row. [View/breakpoint documentation](https://httptoolkit.com/docs/reference/view-page/).

The server's local API can launch applications. Its implementation restricts
origins, uses content-type checks and optionally authenticates requests; desktop
configuration supplies an authentication token. WebSocket origin restrictions
and the subsequent auth message are separate steps. That architecture needs
careful ownership: a coding-agent pipe may invoke permitted network operations,
but neither untrusted page content nor a remote UI should receive its unrestricted
admin API. This reading is a pattern study, not an end-to-end security audit.
[local API controls](https://github.com/httptoolkit/httptoolkit-server/blob/14665bbcc39d8ed89ab2e82b5529f0f51b7cd94d/src/api/api-server.ts)

The Chromium interceptor launches with proxy configuration and a CA SPKI-specific
certificate-error allowance, plus other browser flags and loopback exceptions.
These flags are useful evidence of how a tool creates its controlled browser;
they are not universal defaults for Bow Shock. Mockttp beneath it handles custom
headers, synthetic/streamed responses and TLS/HTTP classification. Its transform
integration tests compare actual client/server behavior, including destination
and Host updates. They offer a stronger study oracle than asserting that the rule
object was constructed. [Chromium interceptors](https://github.com/httptoolkit/httptoolkit-server/blob/14665bbcc39d8ed89ab2e82b5529f0f51b7cd94d/src/interceptors/chromium-based-interceptors.ts) [transform integration tests](https://github.com/httptoolkit/mockttp/blob/7d03b2d97d1ee82969780d0878dfb744aba2c6ae/test/integration/proxying/proxy-transforms.spec.ts)

## Proxyman, Whistle and Go libraries: borrow concepts with their limits

Proxyman's product documentation describes request/response breakpoints and
scripting. The public `ProxymanApp/Proxyman` repository is a product feedback and
release reference, not proxy implementation source. The acquired Atlantis
component is different: URLSession method swizzling observes app traffic and
transmits it to Proxyman. Its transporter compresses packages and maintains
pending-package/ready-connection state; this reading does not establish an
end-to-end retained-body cap. It cannot cover Chromium's network stack
simply because both run on macOS. Its docs explicitly exclude proxy debugging
features such as breakpoints. [URLSession capture](https://github.com/ProxymanApp/atlantis/blob/6427600ec87d516a43754e4eaa7762f3271ac77f/Sources/NetworkInjector+URLSession.swift) [capture transport](https://github.com/ProxymanApp/atlantis/blob/6427600ec87d516a43754e4eaa7762f3271ac77f/Sources/Transporter.swift)

The product breakpoint docs also distinguish continuing an unchanged request,
executing edits and aborting with a synthetic error. Scripting allows broader
request/response modifications but restricts WebSocket message editing in the
read documentation. Those are useful human-flow precedents; Atlantis availability
must not be confused with acquiring their implementation.
[Breakpoints](https://docs.proxyman.com/advanced-features/breakpoint),
[scripting](https://docs.proxyman.com/scripting/script).

Whistle's request and response inspectors show explicit body transforms,
content-length removal when modifications make lengths stale, cookie/header
handling and HTTP2 choices. Its data server has count/time/frame cache bounds.
A scrolling event UI with a cache is not durable capture; storage needs its own
loss and retention behavior. Its extensive rule language and optional DOM
inspection demonstrate how easily traffic tools accumulate unrelated powers.
Bow Shock should learn the mutation pipeline without exposing the entire rule
interpreter as a coding-agent tool. [response inspector](https://github.com/avwo/whistle/blob/33820c617df12894bb38a5e8ea9019b96b3c955e/lib/inspectors/res.js) [bounded data cache](https://github.com/avwo/whistle/blob/33820c617df12894bb38a5e8ea9019b96b3c955e/lib/util/data-server.js)

GoProxy supplies relatively small request/response/CONNECT dispatch primitives.
Its HTTP2 MITM example explicitly enables HTTP2 and disables upstream certificate
verification for its self-signed test backend. Keep that purpose visible rather
than copying the example's TLS policy into a general-purpose browser. Martian
supplies a contrasting structured-modifier approach; its HAR cache model is empty
because the relevant information is unsupported, and size fields can be unknown.
These references are useful for studying honest representation of missing data,
not as evidence that HAR preserves wire bytes or browser cache state.
[HTTP2 example](https://github.com/elazarl/goproxy/blob/a05e9220be0b6fd84566bf0d5f5880be94f3db36/examples/http2-mitm/main.go) [MITM configuration](https://github.com/google/martian/blob/0f7e6797a04da412118541344bbe0d65945e24c9/mitm/mitm.go) [HAR model](https://github.com/google/martian/blob/0f7e6797a04da412118541344bbe0d65945e24c9/har/har.go)

## HTTP1, HTTP2 and HTTP3 need different editing/recording semantics

nghttp2's programmers guide says its core performs no I/O: it receives/emits
bytes and calls the application's callbacks. The caller owns socket scheduling,
output flushing, session lifetime and avoiding recursive send/receive inside
callbacks. Its nghttpx source shows the additional proxy machinery. hyper-h2 is
another readable state/event implementation. Its guidance warns that output can
grow without bound unless drained, and flow control counts padding as well as
application bytes. Using only `len(data)` to acknowledge traffic can deadlock.
HTTP2 stream reset, GOAWAY and connection-wide credit make a generic single
request/response callback insufficient. [programmers guide](https://github.com/nghttp2/nghttp2/blob/19d06e62185d93d2398d85241cdbb460349bfe44/doc/programmers-guide.rst) [flow-control guidance](https://github.com/python-hyper/h2/blob/bc239af1d1b85bc70482804f30a0e0e587d90a08/docs/source/advanced-usage.rst)

h11's connection state separates event parsing from transport. Its maximum
incomplete-event buffer primarily limits the request/status line plus headers,
not every response's lifetime body size. Its supported-HTTP document identifies
extension metadata limitations. Keep parser buffer limits, retained-body limits
and live display limits distinct. [connection state](https://github.com/python-hyper/h11/blob/62c5068c971579d61fa1b55373390e12f25fd856/h11/_connection.py)

HTTP2 forbids connection-specific HTTP1 headers; intermediaries must remove them
when translating. A header editor therefore cannot promise to transmit every
entered name unchanged over every protocol. HTTP3 carries a request/final
response on a QUIC stream, with possible interim responses and partial processing.
Cancellation after partial processing differs from explicit rejection without
processing; retry policy must preserve that distinction.
[RFC9113 fields](https://www.rfc-editor.org/rfc/rfc9113.html#section-8.2.2),
[RFC9114 framing/cancellation](https://www.rfc-editor.org/rfc/rfc9114.html#section-4.1).

quiche supplies QUIC plus HTTP3/QPACK; its README and H3 module describe ALPN,
connection driving and stream APIs. The application still owns event-loop timing,
UDP input/output and processing returned events. aioquic's asyncio client and H3
example make request-event correlation and stream-end completion readable; the
example collects response events until completion, which is not a sufficient
strategy for indefinite streams or unbounded durable capture. A QUIC packet,
stream chunk, HTTP DATA frame and decoded body are different representations.
[H3 module](https://github.com/cloudflare/quiche/blob/77d50358f98610b7d2329b3ca5450e1131aaf883/quiche/src/h3/mod.rs) [H3 client example](https://github.com/aiortc/aioquic/blob/6d36838d008c2202c337142fa07e8bf80e96bac8/examples/http3_client.py)

The exact-file quiche ZIP retains substantial modules including inline tests,
QPACK and flow control, while excluding vendored TLS/build payload. This is a
source-study snapshot, not a buildable checkout. Runtime availability for H3,
WebTransport, HTTP datagrams and extended CONNECT must be checked independently;
seeing QUIC support in a library does not establish every higher-level feature.

## curl and TLS: practical diagnostics with explicit session differences

curl provides a valuable request-sending reference: redirect limits and method
changes, credentials forwarded across origins, cookie input/output, exact versus
encoded request bodies, and backend-specific protocol selection. Its independent
cookie jar is not the browser profile. Imported request snippets can also contain
credentials and cannot automatically become a safe coding-agent action.
[redirect semantics](https://github.com/curl/curl/blob/39ad9b0771708c5aff20663a7ef3704bc55510d7/docs/cmdline-opts/location.md) [cookie semantics](https://github.com/curl/curl/blob/39ad9b0771708c5aff20663a7ef3704bc55510d7/docs/cmdline-opts/cookie.md)

Current pinned source has an instructive capability distinction. The `--http3`
document describes direct HTTP3 with older-protocol fallback and says HTTP3 over
proxy is unavailable. Yet the same pin's `test_60_h3_proxy.py` tests experimental
`--proxy-http3`/CONNECT-UDP paths, guarded by feature/backend/server checks. Report
those modes separately and verify the actual build; a broad yes/no statement
about "curl supports HTTP3 proxies" would hide this. Its HTTP3 build document
also treats quiche backend support as experimental. It points to ngtcp2/nghttp3
as further primary protocol leads, not adopted dependencies.
[HTTP3 option documentation](https://github.com/curl/curl/blob/39ad9b0771708c5aff20663a7ef3704bc55510d7/docs/cmdline-opts/http3.md) [experimental H3 proxy tests](https://github.com/curl/curl/blob/39ad9b0771708c5aff20663a7ef3704bc55510d7/tests/http/test_60_h3_proxy.py) [HTTP3/backend documentation](https://github.com/curl/curl/blob/39ad9b0771708c5aff20663a7ef3704bc55510d7/docs/HTTP3.md)

rustls exposes a `KeyLog` interface and an example enabling diagnostic secret
logging; curl has backend-dependent key-log code too. Authorized key logging can
support independent packet analysis without inserting an interception CA, but
requires actual implementation support and corresponding traffic capture. Those
secrets grant decryption and may enable active modification; they must not flow
into ordinary page context, source control or unrestricted coding-agent context.
This is a concrete property of the diagnostic artifact, not an unsolicited
whole-system security workflow. [key-log interface](https://github.com/rustls/rustls/blob/7dcbe4c1ae12185237d22e9197583329630a2014/rustls/src/key_log.rs) [backend key-log implementation](https://github.com/curl/curl/blob/39ad9b0771708c5aff20663a7ef3704bc55510d7/lib/vtls/keylog.c)
[RFC9850](https://www.rfc-editor.org/rfc/rfc9850.html#section-3).

The rustls 0RTT example and aioquic's early-send option expose another request
boundary: early data is replayable. TLS1.3 discusses duplicated side effects and
ordering risks. Neither proxy replay nor transport early data should silently
repeat an operator's non-idempotent action. Cancellation does not retroactively
establish that the server never processed it. [0RTT example](https://github.com/rustls/rustls/blob/7dcbe4c1ae12185237d22e9197583329630a2014/examples/src/bin/simple-0rtt-client.rs)
[RFC8446 replay discussion](https://www.rfc-editor.org/rfc/rfc8446.html#appendix-E.5).

## Questions this corpus can answer next

Study actual client/server tests for transforms, redirects, auth, trailers,
GOAWAY, disconnects, canceled stream reads, compressed/binary bodies and H3
fallback. A controlled server directly observes what was received; the initiating
browser observes what a response substitution delivered. These are distinct
claims. HAR/event serialization tests answer storage representation, not either
wire behavior by themselves.

For macOS, compare owned-browser native hooks against a browser-configured proxy
before considering a system extension. For Linux, carry the same logical scopes
across CDP/CEF and verify process/worker coverage rather than transplanting macOS
redirector assumptions. Retain engine, proxy, TLS backend, protocol negotiation,
mutation policy and capture gaps alongside observed flows.

The host's network capability should bind destination/redirects, credential
context, requested change, duration and byte limits. General proxy admin, process
launch, arbitrary script/rule execution and page driving are separate powers.
This corpus teaches mechanisms; deciding which to adopt remains a design and
operator discussion. It contains no performance benchmark or production-readiness
claim, and none of the upstream test suites was run.
