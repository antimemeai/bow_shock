# Network implementation lane

Status: implementation-plan proposal, 2026-10-01. This orders the reviewed
[network design](../design/network-control.md) and
[evidence/baseline design](../design/evidence-and-tables.md). It adopts no engine,
HTTP client, extension, emulator or storage dependency and authorizes no host
network change. Its capability experiments are future implementation tasks.

The first useful outcome is a person inspecting a bounded live exchange history
and detecting a meaningful change. The finished lane also includes human request
and response craftsmanship and actual interruptions outside Chromium. A TCP
proxy is useful early, but does not complete the packet/link requirement. That
requirement has an early topology decision and a release blocker below.

## Integration boundaries

The runtime lane provides the exact CEF build, owned request contexts, target
attachment generations and read-only native event bridge. The authority lane
provides serialized admission, session/power generations, continuous deadlines
and global Stop. The evidence lane provides bounded persistence, descendant
policy/expiry fences and explicit storage-health state. This lane owns exchange
identity, pause state, diagnostic sends, environment reservations and semantic
traffic comparisons. It must not implement a second authority registry or
independently decide whether an export is authorized.

The workbench and environment effect owners enforce deadlines locally. Neither
depends on model inference or an affected Internet connection. CEF IO callbacks
copy bounded facts and return; they never await a human or database transaction.
The human may browse while a capture is degraded, but new mutations requiring
durable evidence are rejected when storage is unhealthy.

Proposed source boundaries are `native/cef/network/` for thread-affine adapters,
`crates/network/` for exchange/workbench state, `native/network/` for
native scope and path observation, and `crates/evidence/` for versioned comparison
logic alongside the shared store. These are proposed locations, not directories
or product code created by this plan. Fixtures live under `fixtures/network/`;
native drivers under `tests/network/` and results under `docs/experiments/` once
implementation is authorized.

## Ordered work and deliverables

| Task | Prerequisites | Concrete result and direct acceptance condition |
| --- | --- | --- |
| N0: owned endpoint fixtures | Implementation authorization; runtime/server tooling choice | Resettable endpoints, separate server receipt log and known page outcomes. Exact bytes/status/header assertions distinguish server receipt from browser delivery. |
| N1: macOS mechanism/topology decision | N0; exact machine/OS and proposed signing/deployment information | Select a feasible confined packet/link experimental topology or report a specific blocked core requirement. Start before polish or generalized replay. |
| N2: metadata and bounded passive body observation | Runtime attachment/identity; shared store budgets | Live timeline with target/worker/gap attribution and truthful body representations. Streams keep delivering after retention truncates. |
| N3: deterministic baseline comparison | N2 and evidence retention/lineage | Reviewable baseline promotion, concrete delta alerts and incomparable/inconclusive outcomes. Seeded extra disclosure remains visible beside expected retries. |
| N4: isolated human composer and send-again | N0; authority admission; immutable draft snapshots | Bounded manual send, cancellation and uncertain-outcome reconciliation, no ambient browser credentials. Server sees the committed bytes once unless explicitly declared native transport semantics establish otherwise. |
| N5: pause-owner and teardown capability experiment | N0; local timers; exact adapter/runtime | Establish request versus response revocation, duplicate-resolution exclusion and bounded body-read cancellation before enabling any human-held breakpoint. |
| N6: narrow header/request edits and known response fulfillment | N5 passes applicable operations; N2; mutation reservations | One-shot human rules and before/after evidence. Stop fails unsent request pauses and cannot submit a new redirect hop. |
| N7: existing response-body edits | N5 passes bounded body ownership/termination specifically | Interactive bounded text/binary body replacement. A taken stream can only substitute or cancel; timeout never claims unchanged continuation. |
| N8: finite external intervention controller | N1 selected mechanism; authority/helper fences; local recovery | Actual externally affected browser transport/path, unaffected control connection, bounded expiry and owned-resource restoration under failures. |
| N9: complete tracker/workbench exercise | N3, N6, mandatory N7 existing-body edit and N8 packet plus native-path cases | Person establishes baseline, investigates a change, edits request and existing response, then runs actual external faults and compares measured outcomes/task cost. Missing capability makes this partial/blocked. |
| N10: Linux adaptation | Reviewed macOS contracts; Linux runtime/input slice | Namespace-local topology, correctly placed packet shaping and a native browser/page notifier comparison, without transplanting macOS scope assumptions. |

N1 runs beside N2 rather than waiting for N7. N3 and N4 can proceed independently
after their prerequisites. Within N5–N7, pause ownership and teardown are one
conceptual unit: splitting cancellation into a later owner would expose edits
without their recovery invariant. N8 is a separate native mechanism unit and can
progress beside workbench UI after N1. N9 is the integration outcome, not another
receipt layer. No product milestone claims full network support while N7 existing
response-body editing or N8's required packet-delivery and native path-transition
cases remain blocked. A failed body backend returns a concrete adapter replacement/
study sub-plan; it cannot disappear from the full-acceptance join.

## N0: fixtures whose answers are outside our adapter

Build small owned HTTP endpoints with immutable expected payloads and independent
request receipt counters, plus pages that expose observed status/body/events.
Use a different test origin for redirects and credential checks. A synthetic
pixel page uses recognizable event/recipient/body patterns without contacting
Meta or any third-party service. The server records each received operation ID
and byte payload before deliberately delaying its response, so cancel-after-send
can be distinguished from not-sent. Response replacement must compare both the
original server output and the replacement actually delivered to the page.

Required fixture families:

- Ordinary HTTP/1.1 and HTTP/2; empty/binary/UTF-8 and other known charsets;
  duplicate headers; gzip/encoded bodies; wrong lengths; decompression expansion;
  deliberately oversized headers/body and slow finite bodies.
- Redirects to the same and different origins; method/body-changing redirects;
  401/proxy challenges; an endpoint that processes a POST then disconnects;
  endpoints that return 5xx to expose automatic retry behavior.
- Fresh/cache/revalidation responses; service-worker cache and network fetch;
  worker fetch after the tab closes; OOPIF traffic; canceled navigation;
  overlapping same-URL requests with different bodies. Frame-less traffic stays
  frame-less unless the runtime supplies an authoritative attribution.
- Multipart/file uploads, range responses, trailers and integrity-constrained
  content as coverage/rejection cases. Do not infer support from ordinary text.
- Endless EventSource/download and WebSocket handshake/messages; HTTP/3 and
  WebTransport only on an explicitly configured fixture server/runtime that
  actually negotiates them. Unsupported protocol setup is an explicit gap.
- Network conditions with selected TCP and UDP peers and an independent control
  peer. Include new connections, established sockets, DNS/cache state and IPv4/
  IPv6 alternatives; a fault that affects one path cannot claim all paths.

The direct oracle is endpoint bytes/effects or known page/native-state outcomes.
For state races use a small executable transition model of pause/reservation
ownership and controllable callback order, then exercise the same fault on the
actual adapter where native behavior matters. Generated command strings cannot
establish confinement; successful HAR serialization cannot establish server
receipt. Fuzz parsers/normalization only for their own byte/state fault classes.
Mutation testing, if warranted later, runs on a fleet as Blackbird requires.

## N1: decide macOS confinement before committing its topology

First record the intended deployment: native same-host browser, hardware/OS,
signing/distribution path, availability of an owned test machine/guest or
external path, and whether managed-device requirements are acceptable. This
inventory contains capability facts, never credentials or copied provisioning
secrets. Read the exact SDK and selected runtime before constructing a probe.

The decision separates four useful but different branches:

| Branch | Early experiment | Result it can establish | What it cannot establish by itself |
| --- | --- | --- | --- |
| Browser-configured owned proxy | Route only an explicitly selected owned request context through a dedicated proxy and stall/reset an owned CONNECT stream | Outside-browser TCP stream effects; agent/local control remains outside the proxy | Kernel packet loss, direct Chromium UDP behavior or a native macOS offline transition |
| Signed process-selective native flow diversion | Minimal owned transparent provider with audit-token-based allowlist, finite lease and deny/exclude defaults | Which CEF network-service/worker flows can be selectively diverted; TCP/UDP stream/datagram support and lifecycle | Packet-level equivalence, plaintext TLS, entire process-tree coverage or OS link loss |
| Signed native packet filter | Investigate an owned controlled-flow selector with allow-by-default for every other packet and bounded delayed-packet ownership | Actual selected packet drop/delay if scope and cleanup can be established | Automatic process attribution, complete browser traffic selection or OS link transition |
| Owned packet/link topology | Browser genuinely uses an owned external path, or an explicitly selected dedicated macOS guest/machine whose interface/routes are ours | Selected packet delivery and independently observed native link/path transition | Equivalence to a same-host native session, unchanged fingerprints or complete offline semantics |

For direct macOS distribution, a transparent provider proposal requires the
appropriate Network Extension system-extension entitlement/profile and its
activation/install path. This is a dependency/deployment discussion before
installation, not a reason to execute an acquired redirector. Apple distinguishes
App Store app-extension packaging from direct-distribution system extensions;
the latter can outlive a login and therefore need their own expiry/recovery.
[Apple deployment table](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment),
[entitlement setup](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension).

Do not assume a consumer per-app packet tunnel solves this. Apple's routing
guide describes macOS per-app association through MDM-managed apps; confirm the
app/deployment support and routing rules before proposing it for our native
runtime. A packet tunnel that selectively claims traffic then proxies the rest
is outside Apple's recommended use cases. Whole-host default-route interception
does not satisfy confinement or control-channel preservation.
[Apple VPN routing](https://developer.apple.com/documentation/networkextension/routing-your-vpn-network-traffic),
[packet-tunnel use cases](https://developer.apple.com/documentation/technotes/tn3120-expected-use-cases-for-network-extension-packet-tunnel-providers).

The native provider prototype must enumerate actual selected-browser process
identities, network-service restarts, worker flows, PID reuse, DNS and UDP/QUIC
paths. Unknown flows bypass the interceptor and lower coverage; they never
expand the selector to all processes. It must exclude its own upstream sockets,
hosted inference/Codex traffic and future reconnects by verified ownership,
not a list of destination names. Measure what happens when provider/control IPC
dies and when an unrelated extension/configuration is already active. A passing
diversion probe authorizes only the measured flow tier, not packet/link claims.

Cookie-context isolation is not process/egress isolation: an isolated composer
may still use the same CEF network-service process as the page. Attribute those
flows explicitly. If a selected process/topology scope also affects diagnostics,
show that scope and reject incompatible concurrent sends rather than claiming an
unaffected composer. A context selector is supported only after the adapter can
actually enforce it. Host-side provider/agent processes and their local IPC have
an independent verified route/ownership exemption for the whole intervention,
including restarted helpers and new connections.

Investigate the packet-filter branch before declaring same-host packet support
unavailable. Apple's `NEFilterPacketProvider` offers packet allow/drop/delay and
later release of an owned delayed packet. Its documented handler supplies packet
context/interface/direction/bytes; this is not demonstrated per-process audit-
token attribution. Probe whether an exclusively owned controlled connection can
be selected without capturing another application's reused/overlapping tuple,
and whether fresh connections/fragments/IPv6 can be admitted safely. Incomplete
attribution permits a narrowly named established-flow experiment, not all-browser
scope. Delayed queues need byte/count/deadline bounds and provider-loss recovery;
unknown packets pass unchanged. Installation is still a signed system-extension
decision. Packet filtering alone does not create a native link transition.
[Apple packet provider](https://developer.apple.com/documentation/networkextension/nefilterpacketprovider),
[packet handler context](https://developer.apple.com/documentation/networkextension/nefilterpacketcontext).

For packet/link, an external gateway is feasible only if actual browser egress
is confined to it without rewriting shared host routes or claiming arbitrary
host traffic. Show the route/interface scope and alternative-path behavior at
the endpoint; a gateway label alone is insufficient. If no native same-host
path can establish this, the proposed fallback is an **owned macOS experimental
guest or dedicated Mac**, subject to an explicit deployment decision. It is not
a silent move to Linux or synthetic CDP network emulation. A guest must be a
macOS browser experiment, not a Linux browser called macOS because its host is
a Mac.

Apple Virtualization provides a macOS-on-Apple-silicon boot path, a VM view that
forwards configured keyboard/mouse devices, and a file-handle network attachment
carrying raw link-layer frames on a connected datagram socket. These are source-
grounded candidate building blocks. The exact guest/device configuration must
validate and boot before we select it; those API descriptions do not establish
that our full topology/input/agent bridge works.
[Mac guest boot](https://developer.apple.com/documentation/virtualization/vzmacosbootloader),
[VM input view](https://developer.apple.com/documentation/virtualization/vzvirtualmachineview),
[packet attachment](https://developer.apple.com/documentation/virtualization/vzfilehandlenetworkdeviceattachment).

The guest/machine branch adds joint gates with runtime/input owners: native
window/coordinate mapping, OS-event delivery and human takeover; read-only DOM
pipe; model/control transport independent of the faulted path; helper-local Stop
and expiry even while remote control is unreachable. A private guest-interface
transition does not require changing host interfaces. A frame shaper can affect
packet delivery outside Chromium, but does not by itself report virtual-link
loss; link/route transitions need their own guest OS mechanism and oracle.
An always-online management interface can also change native online state, so
the design must measure that consequence rather than promising an offline event.

At the end of the first N1 feasibility slice, record one of: native scoped
packet/link topology selected; owned guest/machine branch selected after review;
or core requirement blocked with the exact missing capability/operator resource.
The last outcome permits useful passive/workbench work but blocks claiming the
complete prototype. It must trigger a concrete topology/resource decision before
N9, not an open-ended “later” item. No fallback enables host PF reload/disable,
global dummynet flush, shared DNS edits or shared-interface teardown.

## N2: build passive capture without turning inspection into interception

Use in-process CEF DevTools `Network` metadata for target/request/hop lifecycle
and late extra-info, augmented by native resource callbacks where they provide
authoritative fields. Avoid a remote debugging listener. Exchange identities
include protocol session and redirect hop; preserve uncertainty between protocol,
native flow and packet IDs. Capture starts only after target acknowledgement and
target/worker coverage is displayed. Attachment loss/startup gaps are data.

For bodies, first prototype a strictly bounded, passthrough CEF response filter
on eligible flows: copy within the retention quota while delivering every byte
unchanged. Native body representation and compression behavior must be measured
against binary/compressed/streaming fixtures. If the filter cannot preserve
delivery under quota exhaustion or overload, disable that capture surface; do
not replace it with unbounded `Network.getResponseBody`/`Fetch.getResponseBody`.
Protocol buffer-size settings do not automatically bound every native allocation.
Oversized/unknown request-post data stays partial or unavailable when the native
API cannot inspect it without unbounded copying. Metadata-only remains useful.

Apply the reviewed design limits once through the shared reservation manager:
1 MiB retained body per representation, 32 MiB live observational bodies,
256 MiB session body store and separate 8 MiB control reserve. Decode limits
remain separate from retention/transport bounds. Headers above 64 KiB are partial
observations; no silently truncated edit is subsequently applied. Make eviction,
capture-drop and unhealthy storage visible while allowing ordinary delivery.

Store original observations and versioned redacted derivatives independently;
do not overwrite original request/response records when later editing them.
Secrets are withheld by deterministic reviewed projection before alerts/model
exports. Raw capture is a human-selected session mode with retention/access scope.
Deleting or expiring evidence must fence restricted descendants and change
baseline coverage; it is not just unlinking one body blob.

## N3: one meaningful baseline comparator before inference

Implement explicit reviewed grouping keys and normalizers before Jev. Start
with recipients, method/path/event, field presence/type/category, duplicate/count
and retry/redirect relations. Keep original evidence links and each normalizer
version. An operator rule may ignore a nonce's value while retaining presence,
length/type and equality relationships; do not erase an entire body or arbitrary
numeric variation. Independent change categories can coexist.

Promotion selects comparable workflow/build/profile/consent/capture/intervention
strata and the retained data policy. Capture several normal fixture sessions to
demonstrate promotion/review mechanics; a chosen small sample count does not
establish a timing distribution. Timing alerts wait for repeated samples and a
reviewed decision rule that accounts for spread. A build/mode/consent mismatch
returns incomparable, and missing worker/body coverage returns inconclusive for
the affected feature rather than unchanged. Expired baseline dependencies lower
available sample count and may prevent comparison.

Direct regression scenario: stable synthetic pixel events vary their nonce,
then an external interruption adds retries, and the changed fixture also adds
a contact-derived hash/new recipient. The comparator must report the disclosure
delta independently of expected retries and intervention context. Held-out
positive/negative fixture traces test over-normalization and duplicate/order
errors. Later operator-selected real captures validate usefulness; do not claim
that a synthetic pixel identifies every Meta endpoint or proves reduced inference.

Jev may then suggest ambiguous categories/priorities using an approved redacted
view with model/threshold versions and probabilities. Compare against deterministic
rules on reviewed held-out cases; measure missed meaningful changes and review
effort. It cannot authorize sends or suppress concrete deterministic disclosures.
No model SDK adoption is necessary to implement the initial comparator.

## N4: isolated composer before browser credentials

The first proposal uses native `CefURLRequest` and a fresh, non-shared in-memory
`CefRequestContext` for each diagnostic operation or explicitly isolated bounded
context. Never pass a null context: CEF would select the global context. Requests
are not associated with a frame, and the UI describes diagnostic semantics rather
than claiming the page's CORS, SameSite, cache or service-worker context.
[Pinned CEF URL request](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_urlrequest.h),
[request context](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_request_context.h).

Use `STOP_ON_REDIRECT`, `NO_RETRY_ON_5XX`, disabled stored credentials and no
cache reuse; reject authentication challenges. Browser-process streaming download
callbacks retain only bounded bytes while request lifetime stays on its creation
thread. Explicit redirect continuation creates the next validated bounded hop,
with no cross-origin credential copying. Verify native cancellation/retries,
TLS early-data behavior and exact endpoint effects instead of assuming one flag
rules out every transport resend. If unavoidable native resend semantics make
a proposed operation unsuitable, expose the limitation or reject that operation.
Do not silently swap to an independent client with different semantics.

CEF's `ALLOW_STORED_CREDENTIALS` flag jointly permits sending stored credentials
and saving response cookies. It is not a switch for independent cookie-persistence
choices. Therefore selected-browser-context sends remain unsupported until a
separate verified path enforces the requested credential AND persistence policy.
Imported explicit credentials are another reviewed operation in an isolated
context, not an automatic extraction of the user's browser jar. Cookie changes
from a delivered response replacement are independently surfaced.
[Pinned request flags](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/internal/cef_types.h).

Reserve the immutable encoded request and worst-case adapter copies before
commit: 8 MiB encoded/decoded operation bounds, four concurrent sends, total
64 MiB mutation working memory and 30-second operation deadline. Stream-copy
and native allocation limits need exact-runtime evidence. If CEF cannot implement
the required diagnostic semantics with bounded memory, discuss a separately
shipped/versioned libcurl backend before adopting it; platform curl availability
alone is not a backend/version selection.

Send-again copies a complete captured request into a new draft and highlights
method/destination, server-repeat possibility, redirects and credential choices.
Partial/file-excluded input cannot be replayed as complete. New edits invalidate
old validation and commits bind the exact displayed snapshot. Cancellation before
submission can become not-sent only with native evidence; after submission show
local-abort and unknown remote outcome unless the controlled peer establishes it.
Duplicate IDs reconcile the existing operation and never create another send.

## N5–N7: teardown comes before pauses and body editing

First test the pause adapter on owned fixtures with no human UI: acquire lease,
execute local deadline/Stop/crash paths, reconcile a lost acknowledgement and
reject duplicate/stale decisions. Use a small deterministic scheduler to race
commit, deadline, revocation, navigation, target loss and late callback. The actual
adapter must then exhibit the design's stage-specific behavior at the peer/page.
For request stage, revocation or relevant context loss fails an unsent pause;
ordinary expiry with still-live authority can continue only its predeclared
unchanged fallback. Response delivery after submission and stream-taking are
different states. The target/effect owner must enforce expiry if the host/model
control connection disappears. Native domain disable or IPC disconnect is not
an assumed fail-closed operation; measure it before advertising pause support.

Prefer one pause backend per exchange. The initial proposal is narrow CDP Fetch
interception through the existing in-process adapter, with request edits/header
or known synthetic response capabilities individually gated. If Fetch cannot
satisfy request-crash disposition, a CEF asynchronous request callback backend
may provide the narrower verified capability; this does not also establish
response editing. Do not layer both hooks on the same exchange or pass UI state
across unowned protocol IDs. One-shot exact/narrow rules require filters, hit
limit and expiry; never serialize an absent pattern as Fetch's match-all default.

The destructive stream experiment is mandatory before N7: take a finite owned
response, read sequential bounded chunks with a maximum working allocation, and
exercise timeout, oversized/decompression input, reader disconnect, stream close,
target crash, host loss and shutdown. It must establish which exact combination
of stream close/fail/fulfill releases the pause and upstream resources within
the reviewed 10-second acquisition/operation deadline. Do not interleave a body
read with a blind `Fetch.disable` or assume `getResponseBody` has a finite native
allocation. Once the original body is taken, substitute a complete bounded
replacement or cancel; never claim continue-original. Unsupported cleanup means
the body-edit capability remains unavailable until the adapter is replaced.
[Pinned Fetch contracts](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Fetch.pdl).

Only after these gates introduce the human pause editor, showing ordinary timeout
and revocation dispositions before arming. The editor operates on a copy. The
host sends at most one resolution per lease and acknowledges resolved versus
resolution-unknown. Eight pauses/32 MiB retained edit data intersect the total
64 MiB mutation working-memory bound. Reservation failure prevents another pause;
it does not leave an unowned flow waiting.

Validate framing, authority fields, duplicate headers, status/body consistency,
charset and compression together; display any adapter-generated fields before
approval. Unsupported multipart/trailer/range/integrity edits are rejected.
Ordinary endless streams stay observational and are ineligible for full-body
editing. `OnResourceResponse` is read-only and `CefResponseFilter` cannot substitute
status/headers: never use either as a purported full response replacement.

## N8: external effects with independent recovery

Full acceptance needs both an actual packet-delivery fault and an independently
measured native owned link/address/route transition. A packet-filter drop or
external gateway stall does not settle the native path case. Each mechanism
has its own confined topology and oracle; an unachievable second case returns
a blocked deployment/scope decision, not a completed full prototype.

Implement one selected N1 mechanism before complex adaptive profiles. A helper
first reserves actual resource IDs and intersecting paths/selectors, records
exclusive ownership, binds host-run/epoch/environment generation and finite
expiry, then accepts one immutable human-armed snapshot. Initial composition is
rejected, including overlaps under different display names. Unknown scope cannot
be broadened. Apply acknowledgements, OS observations and page/server effects
are separate events.

Install the helper-local revocation fence before canceling schedules. It rejects
a delayed first arm/apply after Stop. Already-started native calls reconcile to
actual resources; Stop-requested, owner-processed and restored are different UI
states. Keep reservations through applying, restoring, effect-unknown and cleanup-
failed. A new host run first reconciles/quiesces the old owner. Persistent effects
require helper-local expiry/startup recovery; otherwise the capability is disabled.
Remove only owned resources. A read-then-write compare/restore is inadequate for
a shared resource that another owner can race; require exclusive ownership or
an actual atomic conditional restore operation.

The controlled experiment runs a browser data path and unaffected control peer
simultaneously, then faults only the declared path. Verify established and new
connections, worker/network-service restart, IPv6 alternatives and hostname
resolution. Stop/expiry, partial setup, IPC/host/helper failure, sleep beyond expiry
and external resource changes must leave unrelated settings/traffic intact and
produce actual owned-resource state or explicit cleanup uncertainty. Reject
renewal when an uncertain prior operation overlaps. Local recovery works while
the network is unavailable.

For packet loss, observe the declared injection point and controlled receiver;
capture drops/offload/timestamp uncertainty must not masquerade as network loss.
For link/route change, record native path/configuration callbacks, the selected
Chromium notifier/build branch and page online/error/timing evidence independently.
Do not require an offline event for a transport fault or infer non-receipt from
`navigator.onLine`. Outside-browser mechanisms may produce genuine connection
errors while OS online state persists; the UI must say which was measured.

Then implement adaptive schedules as finite local transition tables, not model
commands: a native spontaneous path loss may stop scheduled faults, and recovery
may start a bounded settling interval. Guards enforce remaining duration,
cumulative intensity, selector scope and ownership. A model/Jev result cannot
expand the armed policy. Begin with 30-second profiles, absolute maximum 120
seconds and one profile per non-overlapping scope, as in the reviewed design.

Do not disable QUIC, replace TLS trust or globally configure a proxy to simplify
the normal browser. A TCP-only experiment names its unsupported UDP/QUIC paths;
a deliberately restricted diagnostic mode records its altered runtime settings
and gets a distinct fingerprint/baseline stratum. Proxy/gateway/TLS modes need
their own same-platform browser-compatibility measurements. A fault's usefulness
against a particular tracker inference and its task cost are evaluated later;
controller correctness does not establish that benefit.

## N9–N10: integrate and carry the invariants to Linux

The first complete network walkthrough uses the synthetic pixel and controlled
page: normal baseline, meaningful new disclosure, request edit, original-versus-
delivered response replacement, external interruption, expected retries plus
unsuppressed disclosure, and Stop/recovery. Record review/diagnosis effort and
task completion alongside errors/delta outcomes. Add a real human-selected tracker
investigation only after capture scope and data policy are reviewable; alerts
initially stay local. Packet/link support and body replacement retain their own
measured gates, so a narrower walkthrough is labelled partial.

Linux adapts the same effect contracts using an owned network namespace/veth
topology, with CEF child/network-service/worker processes launched into the owned
boundary before network access. Host agent/control remains outside it using a
separately verified local IPC path. Create namespace-owned interfaces/qdiscs/
resolver state; leave host routes, DNS and qdiscs intact. Select netem placement
from the actual traffic direction and receiver/TCP behavior, not copied commands.
Privilege/kernel/desktop-portal constraints are recorded before selecting this
deployment. A namespace interface loss and a shared desktop connectivity portal
may produce different Chromium/page signals; run the direct native/page/peer
comparison instead of requiring macOS notifier equivalence.
[Reviewed namespace/netem precedents](../../papers/network-environments-and-capture.md#linux-shaping-and-topology-references).

Recorded-response replay, HAR/WARC export, WebSocket message editing, generic
proxy rules and arbitrary script hooks are later proposals. Initial send-again
is already useful; archive replay is a distinct isolated mode with unmatched
forwarding off and exact original/served representation. Unsupported protocol
payload editing remains explicit rather than acquiring a proxy stack to hide
coverage gaps.

## Dependency proposals and review entry

Use selected CEF/Chromium native network hooks, standard native macOS APIs and the
shared local evidence store first. No interception CA is needed for browser-native
decrypted observation. The diagnostic composer proposal reuses CEF rather than
adopting a second HTTP stack. A minimal owned CONNECT proxy may support the narrow
TCP experiment; it terminates no origin TLS and cannot supply plaintext bodies.
Study Toxiproxy/mitmproxy/Mockttp patterns without installing or shipping them.
An actual Network Extension or macOS guest/topology adds signing/platform/resource
choices for concrete operator discussion after review; the plan does not grant
installation or reconfiguration authority. Native mechanisms are selected by
direct experiment, not reference availability.

Plan tribunal should attack these traces: Stop after a held request but before
submit; body taking plus target loss; unexpected cookie persistence; proxy mode
claimed as offline; missed helper/worker/IPv6 paths; unchanged alert after coverage
loss; contact disclosure hidden by a retry normalizer; delayed arm after cancel;
same-resource differently named profiles; helper loss with lingering fault; and
core packet/link capability indefinitely deferred behind UI. Every valid finding
changes this task sequence or its effect contract before code.

Further source/test grounding: [network quarantine map](../../papers/network-quarantine.md),
[native network hooks](../../papers/network-observatory.md),
[proxy protocol/state findings](../../papers/network-proxies-and-protocols.md),
[capture representation/oracles](../../papers/network-measurement-and-logs.md),
[outside-browser and input findings](../../papers/os-input-and-behavior.md),
and [design tribunal](../../papers/design-tribunal.md).
