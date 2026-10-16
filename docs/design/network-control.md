# Network control: human workbench and external environment

Current direction, 2026-10-16: a bidirectional proxy for capture and editorial
work on requests and responses, including ads, is an immediate fast follow to
the extraction/preview/recipe loop, alongside metrics and instrumentation.
Preserve original and sent/delivered traffic, transformations and historical
links for later study. The automatic expiry/eviction defaults and arbitrary
capture budgets below are historical, not current retention requirements.
See [the current delivery plan](../plan/instrumentation-proxy.md).

Status: design proposal, 2026-10-01, [tribunal reviewed](../../papers/design-tribunal.md). No engine, proxy, privileged helper, or dependency is adopted by this document. No host network changes are authorized by writing it. The [product intent](../product-intent.md) requires human request/response craftsmanship and deliberate interruptions outside Chromium to perturb tracker inference. This design preserves both powers while separating their execution owners from the model's ordinary OS-input path.

## 1. Owners and invariant boundaries

The host owns a **Network Workbench** for inspection, in-flight edits, new sends, replay, and synthetic responses. It also owns an **Environment Controller** for finite, outside-browser network interventions. A backend adapter implements only capabilities established for the selected engine/runtime and OS. The shared timeline receives evidence from each component; logging does not confer execution authority.

| Owner | Permitted work | Boundary |
|---|---|---|
| Human | Inspect; draft and commit request/response edits; authorize a send/replay; arm and stop an environment profile | Every commit names the affected exchange or destination, credential context, limits, and scope |
| Model | Explain redacted observations; draft a proposed edit/request/profile; compare evidence | A draft never sends, resumes, replaces a response, installs a breakpoint, or changes networking |
| Host workbench | Validate the human operation; own pauses; serialize protocol decisions; execute one committed operation | No arbitrary page JavaScript, unrestricted CDP, proxy scripting, or shell command interface |
| Environment controller/helper | Apply a human-armed finite profile; observe application and remove its own resources | No implicit privilege escalation, widened scope, or changes to another owner's rules/routes |
| Browser adapter | Translate typed operations to supported native hooks/protocol commands | No claims beyond its capability/coverage record; no network IO callback waiting for UI/model inference |

A normal navigation/input delegation grants none of the workbench or environment powers. Page content, captured request fields, proxy responses, and model output are data; they cannot issue control commands. Human diagnostics may deliberately have powers unavailable to ordinary page scripts, but the UI names the execution context before commit.

`NetworkGrant` uses the shared [authority owner](control-and-input.md#authority-transitions), session epoch and the relevant workbench or environment generation. Each operation has `operationId`, owner, grant/generation reference, capability version, session/tab/expected-navigation scope or an explicitly detached diagnostic context, exact exchange identity where applicable, permitted operation, destination/redirect policy, credential/cookie policy, byte limits, continuous-clock deadline, and failure disposition. The effect owner checks these again immediately before an effect. Reusing an operation ID returns its known state rather than sending again. An engine restart or profile replacement invalidates old context handles and pending drafts; a reconnect never replays a commit automatically.

Revoking a workbench or environment power advances that power's generation before rejecting queued effects. Global Stop invalidates both via session epoch; physical input takeover/editor typing and provider loss do not revoke human network powers. Workbench revocation stops new semantic sends and resolves its held pauses using the stage-specific revocation disposition. Environment revocation moves an active profile to restoration. Already submitted requests retain uncertain remote outcomes. Cleanup continues under recovery-only authority: remove owned resources, fail an unsent request pause, or resolve delivery of a response to an already-submitted request. It cannot submit a held request or new redirect hop. Observation follows its independent scope; [the cause-to-power matrix](control-and-input.md#authority-transitions) governs target loss and detached contexts.

## 2. Exchange identity and truthful representations

The host assigns an immutable exchange ID and per-hop IDs. Adapter-local keys include browser session, target/protocol session, request ID, redirect hop, and frame/document/loader association when known. A worker without a frame remains explicitly unattributed; URL/time correlation alone cannot promote it to a visible document. Late extra-info events append evidence without replacing prior observations.

Keep distinct records for the original outbound request, actual submitted request, original upstream response, and delivered replacement response. A response edit does not undo the original server request's effects. Each body has a representation label (`protocol_body`, `content_encoded`, `entity_decoded`, `unicode_text`, `redacted_derivative`, or `packet_capture`), encoding/charset, observed/retained length, completeness, and transformation version. Do not label a browser-decoded body as wire bytes. A body can be `not_requested`, `complete`, `partial`, `evicted`, `file_excluded`, `unavailable`, or `failed`; none equals an empty body.

Passive observation has states `starting → observing → stopping → stopped`, with `degraded` for coverage/storage gaps and `failed` for attachment loss. Observation begins only when selected targets acknowledge attachment. Starting later cannot reconstruct missing earlier bodies. Gap intervals, detached targets, and budget drops remain visible. Disabling observation cannot strand a workbench pause: the pause owner resolves it first or follows its tested teardown path.

Native request/response records and packet observations are separate evidence. A cached or worker response may have no server exchange; encrypted capture may have no application plaintext. The design follows the acquired [Network/Fetch contracts](../../papers/network-observatory.md) and [capture/representation findings](../../papers/network-measurement-and-logs.md).

## 3. Limits and storage policy

These are initial product limits proposed for review, not measured runtime capacities. A capability adapter must enforce them before allocation where it controls allocation; an API that materializes an unbounded body before returning cannot advertise bounded full-body capture.

| Resource | Initial limit | Exhaustion behavior |
|---|---|---|
| Retained observational body | 1 MiB per representation; 32 MiB aggregate live body memory | Stop retaining this body, append truncation/eviction evidence; keep normal browser delivery moving |
| Session body store | 256 MiB; separate 8 MiB reserve for control/lifecycle evidence | Evict oldest unpinned observational bodies with availability updates; never silently discard active operation input |
| Headers shown/edited | 64 KiB encoded block | Larger observation is partial; larger committed edit rejected; no silent applied-header truncation |
| Handcrafted upload or replacement body | 8 MiB encoded and 8 MiB decoded per operation | Reject commit before sending/substitution; partial captured bodies cannot be replayed as complete |
| Decode | Both absolute byte bounds above; expansion ratio at most 20:1 | Stop decode with reason; encoded view remains available within its bound |
| Simultaneous pauses | 8 per session and 32 MiB total retained edit data | Do not acquire another human pause; execute its predeclared fallback and log why |
| New-send/replay concurrency | 4 committed operations per session | Reject excess admissions before submission; no unbounded committed queue |
| Mutation input/working memory | 64 MiB total across drafts, sends, pauses, replacements, decode/re-encode and adapter copies; included within that total are the 32 MiB pause bound | Reserve worst-case finite input/working buffers before commit; reject if reservation unavailable or backend allocation is unbounded |
| Ordinary pause | 30 seconds initial; 120 seconds absolute maximum from acquisition | Execute the applicable disposition; no model-based extension |
| Controlled body acquisition | 10 seconds, also within operation deadline | Use only the adapter's verified bounded termination path; otherwise this capability is unavailable |
| New send/replay | 30 seconds wall duration, response retention bounds above; maximum 5 redirect hops if enabled | Abort locally; remote effect may already have occurred; no automatic resend |
| Environment profile | 30 seconds initial, 120 seconds maximum, one active profile per scope | Stop scheduling new effects and remove owned resources; report cleanup uncertainty explicitly |

The human may choose a smaller limit. A larger body workflow requires a separately reviewed finite limit and backend coverage; “unlimited” is not an option. Pinning data for an active edit reserves its whole maximum budget; it cannot evict another active operation. Deleting a capture does not revoke a send already executed.

Store ordinary observation as redacted metadata and bounded bodies. Credential-bearing raw views require a human-selected local diagnostic capture mode and session-private storage; exports and model derivatives use separate identities and redaction policies. TLS key logs are separate privileged diagnostic artifacts, never ordinary model context. Full raw capture and packet capture are off initially. Retention of each chosen raw artifact ends at session close unless the human explicitly saves it; saved artifacts record the retention choice. Logs contain secret-presence/credential-context references rather than actual authorization values.

For endless EventSource/downloads, retention reaches a byte bound and becomes partial; it must not synthesize EOF in the page. Stopping capture is different from stopping the transfer. A storage failure blocks new committed mutations that require retained evidence; already owned pauses/interventions still follow local deadlines and cleanup, using the control reserve or an explicit logging-gap record.

## 4. Breakpoints and pause ownership

A breakpoint is a human-armed finite rule, not a global default. It names owned browser context/targets, request or response stage, destination/path/method/resource filters, hit count, expiry, and fallback. Initial rules are one-shot, exact-exchange or narrowly matched rules. An absent URL pattern must not be translated into Fetch's match-all default. Authentication interception is a separate capability and off initially.

The host acquires an exclusive **pause lease** for each `(exchange, hop, stage, adapter generation)`. Only its state machine can resolve the adapter callback/Fetch ID. The UI edits a copy, not the live protocol object.

| Pause state | Legal transition / effect |
|---|---|
| `acquiring` | Adapter acknowledges pause → `held`; already ended/out of scope → `gone` |
| `held` | Inspect/draft; one validated human decision → `resolving`; deadline/power revocation/context loss/shutdown → disposition |
| `reading_body` | One serialized body acquisition; completion → `held` or `replacement_owned`; adapter-specific timeout → tested termination |
| `replacement_owned` | Original stream was taken or otherwise consumed; only full substitute or cancellation can resolve |
| `resolving` | Send one continue/edit/fail/fulfill decision; acknowledgement → `resolved`; target loss or ambiguous transport reply → `resolution_unknown` |
| `resolved`, `gone`, `resolution_unknown` | Terminal for this lease; stale UI/model decisions rejected |

Host decision and timer expiry compete through one atomic state transition. A second continue/cancel/edit cannot reach the adapter. An uncertain acknowledgement never causes the decision to be retried blindly. Shutdown stops acquiring pauses, drains ordinary leases, then stops adapters. Adapter-owned body reads are serialized with teardown rather than canceled by an unrelated `Fetch.disable` call.

For ordinary timeout/editor disconnect while authority remains live, an unchanged inspection pause may **continue original**; a human-armed block/edit-required rule instead **fails locally**. Explicit workbench/global revocation or affected context loss has a different disposition: a request-stage pause not yet submitted **fails locally**, so Stop cannot send it; a response-stage pause after upstream submission can **continue the original delivery** if unchanged and supported. Redirect request hops are independently unsent requests under the same rule. A body-owned pause **cancels locally** because the original cannot continue. Physical editor input/content takeover alone leaves its human workbench lease live. The rule review shows both timeout and revocation dispositions before arming. Crash recovery must enforce the same distinction; otherwise pause capability is unavailable. `not_sent` applies only when the adapter establishes no outbound submission for that operation; earlier hops or concurrent page traffic retain their own outcomes.

Human activity can extend a held pause only up to its original 120-second maximum and current grant deadline. Time counts while the machine sleeps using a continuous elapsed clock; on wake, expiry is processed before any stale commit. The controller, timer, and cancellation path do not depend on the remote model or an affected Internet path.

**Fetch constraint:** `takeResponseBodyAsStream` removes unchanged continuation; body acquisition and request-changing commands/domain disable are not safely interchangeable. Therefore an adapter cannot expose interactive response-body editing unless it demonstrates bounded buffering, sequential reads, cancellation/stream close, and final resolution on its exact runtime. `getResponseBody` is not used as an assumed bounded acquisition path. If these conditions are missing, body edits are unavailable through that adapter; header/request editing and known synthetic responses can remain available. [Acquired Fetch PDL](https://github.com/ChromeDevTools/devtools-protocol/blob/8b7f1d955017db8633ecae04cdfa194f731c9eff/pdl/domains/Fetch.pdl).

CEF `OnResourceResponse` is read-only, and its response filter changes body bytes rather than status/headers. A full handmade response needs a custom resource handler or supported fulfillment path. Filters own only bounded chunk transformation and flush state; they cannot block the IO thread for a human decision. [Acquired CEF interfaces](../../papers/network-observatory.md#cef-native-hooks-and-response-editing-limits).

## 5. Human edits, sends, replay, and side effects

The workbench exposes four separate commands: **edit paused request**, **replace/modify paused response**, **send new request**, and **send again from capture**. The human reviews the actual operation and then commits it. Model drafting can fill fields but cannot create a send authority. A previously committed immutable snapshot stays visible after subsequent draft changes.

An edit transaction is `draft → validated → committed → executing → completed | failed | outcome_unknown`, with `discarded` available before commit. Validation binds the edit to an active lease/context generation, reserves bytes, checks backend support, and constructs the actual encoded body/header set. A commit records the exact validated snapshot and consumes its one-use authorization. Any edit invalidates prior validation. Response headers/status/body are applied as one supported operation; adapters unable to do that cannot advertise the action.

Header edits preserve duplicate entries where supported and reject illegal protocol fields. The adapter regenerates authority/framing fields and body length according to actual protocol; any requested value it cannot preserve is shown before validation succeeds. Changing decoded text requires a known charset and explicit re-encoding. Stale compression/length metadata must be recomputed or removed consistently. Binary data is editable only as bounded bytes. Unsupported ranges, multipart file elements, trailer/integrity changes, or unknown representations cause an explicit rejected edit rather than best-effort silent transformation. A response replacement can change page cache/cookies; the committed operation names those effects.

New sends have an explicit execution context: `isolated_client` (default, no browser credentials), `selected_browser_context` (only where supported), or a specifically approved imported credential set. Never infer that an independent HTTP client reproduces browser SameSite, partitioning, service workers, cache, CORS, or TLS behavior. Stored credentials and response-cookie persistence are separate choices; context-bound credential send is rejected if the adapter cannot enforce either choice. Imports containing headers/cookies are drafts, not authorized sends.

Redirects are off by default for new sends. When enabled, revalidate each hop against destination/origin and method/body policy. Never carry imported authorization or cookies across origins automatically. An intercepted page redirect is another hop/lease; the original hop's header overrides do not automatically apply. Changes to the destination after validation invalidate the commit.

“Send again” is a new operation linked to the capture, not undo or archive replay. It requires complete request bytes or an explicitly composed replacement payload. Show method, destination, credential context, cookie persistence, redirect policy, and that server processing may repeat; GET is not a proof of harmlessness. Browser/client retries and transport early data must be controlled where supported and their unavoidable semantics declared. The composer does not automatically retry uncertain application sends or enable replayable early data. Stop before submission is `not_sent`; after submission it is `local_abort_requested`, followed by adapter completion and `remote_outcome_unknown` unless authoritative server evidence establishes more. [Replay/TLS source findings](../../papers/network-proxies-and-protocols.md).

Recorded-response replay is a different experiment mode: no unmatched upstream forwarding by default, a recorded matching policy, and separate original/served response identity. Date refresh, rewritten URLs, and TLS trust changes are explicit. This mode cannot be substituted for a live outside-browser fault experiment.

## 6. Environment controller and OS capability tiers

An intervention profile names its purpose (including perturbing tracker inference), owned scope, mechanism, traffic direction/protocol/destination selectors, bounded schedule/intensity, duration, affected control channels, cleanup plan, and signals it intends to measure. The human arms the exact profile; the controller may execute its finite schedule locally without repeated prompts. A model may propose parameters but does not adapt them beyond the armed policy. There is no arbitrary-command field.

An adaptive profile may also name local native signals, a finite transition
table and bounded response ranges: for example, a naturally observed path loss
stops scheduled faults and an observed recovery starts a limited settling interval.
The controller evaluates those reviewed guards locally, including ownership,
remaining duration and cumulative intensity limits. It cannot infer permission
to disable a different interface or expand traffic selectors. Distinguish
spontaneous OS events from intervention-caused events and record uncertain causal
attribution. Randomized schedules and gesture noise have separate parameters;
neither a Jev judgment nor a remote-model reply changes an armed profile.

Scope types are `owned_proxy_connections`, `verified_process_group`, `owned_network_topology`, `dedicated_external_path`, and `host_network`. The last is unavailable in the initial design. A visible window is not a process/socket scope. Browser helpers, network service, workers, and PID reuse require runtime attribution; an unclassified process/flow is excluded and coverage is degraded. A platform adapter rejects unsupported selectors before arming. It never changes a process-scoped request into an interface/host-wide fault.

| Capability | macOS first | Linux second | Permitted initial claim |
|---|---|---|---|
| TCP stream delay/stall/reset | Owned explicit proxy or verified native flow adapter; process-local extension is a later capability gate | Owned proxy or verified flow adapter | Changes selected TCP delivery; not kernel packet loss, UDP coverage, or OS link state |
| Packet delay/rate/loss | Owned external path/topology; Apple PF/dummynet only with separately verified narrow resource ownership | Owned namespace/veth topology with verified classifiers/netem placement | Changes packet delivery at the declared point; no offline promise |
| Process-selective native diversion | NetworkExtension precedent exists; entitlements, installed extension, audit-token/process coverage and lifecycle remain prerequisites | eBPF/local-capture precedent exists; kernel/privilege/process coverage remain prerequisites | Flow routing if verified; does not itself decrypt TLS or simulate link loss |
| Link/address/route transition | Only an independently owned path whose effects are proven confined; no host-interface/default-route fallback | Owned namespace interface/routes, with desktop portal behavior checked | OS/browser signals actually observed, possibly with surviving alternative paths |
| Controlled DNS fault | Owned proxy resolver/test path; no shared system DNS edits | Owned resolver/topology; no host resolver edits | Selected name-resolution effect; caches/existing sockets reported separately |
| Host PF/dnctl/interface control | Unsupported initially | Unsupported host-wide counterpart | Capability rejection with supported alternatives displayed |

No process-local packet-loss mechanism is presently established for the selected macOS browser, because the runtime is unselected and no confinement experiment ran. The first macOS build may therefore expose narrower TCP proxy experiments while packet/link profiles remain unavailable until reviewed. This is a capability gap to close, not permission to reinterpret the user's outside-browser requirement as synthetic browser emulation. CDP network emulation and page-dispatched offline events do not implement this controller.

The native diversion precedent is substantive but conditional: the acquired macOS provider filters flows using source audit-token/process information and copies selected TCP/UDP through IPC; it also has platform installation/entitlement and shutdown semantics. That does not establish confinement of Bow Shock's full process tree. [Pinned provider](https://github.com/mitmproxy/mitmproxy_rs/blob/51fe2b7c5aa8439c162abb665db61c6669d146d6/mitmproxy-macos/redirector/network-extension/TransparentProxyProvider.swift).

Comcast's PF backend is rejected as an ownership implementation: global PF reload/disable, fixed pipe 1, and global dummynet flush can affect other owners. Dummynet masks group flows rather than select which traffic enters the emulator. Netem's placement/timer limitations and Toxiproxy's stream-close semantics remain part of each capability's description. [Reviewed mechanisms and scope failures](../../papers/network-environments-and-capture.md).

## 7. Intervention lifecycle, evidence, and cleanup

| State | Required behavior |
|---|---|
| `draft` | No OS effects; capability check identifies unsupported scope/mechanism |
| `validated` | Exact profile, ownership boundary, budgets, control-channel exemption, baseline observation and recovery method established |
| `armed` | Human-authorized snapshot reserved; helper-local expiry/recovery ownership present before modification |
| `applying` | Apply only declared resources; record each acknowledged effect; partial failure → `restoring` |
| `active` | Publish actual start/parameters; run only bounded schedule; signal observations are independent of command success |
| `restoring` | Stop new effects; remove owned resources conditionally and idempotently; do not flush another owner's state |
| `restored` | Adapter observed declared resources removed/restored; remote connections may still be broken or retrying |
| `cleanup_failed` | Visible residual scope/resources and error; block new profiles in that scope, keep local recovery control |
| `effect_unknown` | Helper/IPC acknowledgement lost; reconcile actual owned resources before another application |

Preflight identifies the resource namespace, ownership identifiers and baseline values relevant to cleanup. Prefer new session-owned resources. If modifying a value is unavoidable, restore the previous value only when the current value still equals the intervention's last applied value; an external change is a conflict, not a reason to overwrite. A separate check followed by a write is insufficient when another owner can race: the adapter needs atomic conditional restoration or exclusive ownership for that resource; otherwise modification is unsupported. Cleanup runs after expiry, Stop, partial setup failure, target termination, or controller disconnect. Privileged persistent modifications require a helper-local expiry and startup reconciliation; if the adapter cannot remove its resources independently of the browser/controller, that persistent capability stays disabled.

The agent connection and local emergency Stop must remain outside the affected path throughout the profile, including reconnect/new flows and shared transports. An exemption is validated through the chosen topology/selector rather than assumed from destination names. The host reserves actual resource identities and intersecting traffic selectors/paths, not only display scope names. Initially reject overlapping resources or fault composition, including differently named process/topology scopes; uncertainty also conflicts. Reservations survive applying, active, effect-unknown, restoring and cleanup-failed states until reconciled removal. Atomic compare-and-restore alone cannot protect overlapping Bow Shock owners. Reconnect consults actual resources and returns their state; it never applies a profile again because an acknowledgement is missing. `restored` describes resources, not absence of server effects, restored TCP state, or erased tracker observations.

Each helper binds host-run/session epoch, environment generation, operation ID,
finite expiry and its recovery ownership before accepting an armed snapshot.
Revocation installs a helper-local generation/operation fence before cancelling
scheduled applications. A delayed first arm/apply with an older fence is rejected
even when its deadline has not elapsed. New host runs reconcile/quiesce old
helper ownership before acquiring resources. Stop is reported as requested,
processed by the effect owner, then restored/cleanup-failed/effect-unknown.
No native application starts after that owner processes its revocation fence;
already-started calls are reconciled and cannot be called restored on the basis
of an earlier empty resource scan. Recovery authority can only remove/reconcile,
never reauthorize a stale application. Finite helper-local expiry remains required
when IPC or the host disappears.

The intervention log joins requested schedule, human authorization, capability/runtime version, actual acknowledged application/removal, ownership IDs, continuous and wall-clock timestamps, unexpected helper/path changes, and gaps. Separate evidence fields report **transport outcomes**, **native OS path/config events**, **Chromium notifier/build configuration**, and **page-visible errors/online events/timing**. Independent server observations link when available; uncertain joins remain uncertain.

Chromium's Apple notifier has native path and legacy SystemConfiguration branches; Linux has netlink plus feature-controlled portal state. Packet loss need not change either OS online state or `navigator.onLine`; surviving paths may preserve online status. Conversely, an OS path transition does not prove an origin received no request. Observation of any one layer cannot stand in for the others. Controller traces must include expected signals that did not occur. [Pinned notifier analysis and primary links](../../papers/os-input-and-behavior.md#network-simulation-outside-the-browser).

Tracker alerts mark the intervention interval, retries, capture gaps, and baseline comparability. The intended experiment asks whether a selected inference becomes less useful while tasks remain usable. It may also create a distinctive pattern; identifiers/fingerprints can persist. No interface label promises fingerprint invisibility, human authenticity, or tracker confusion. The observatory compares measured disclosure/behavior and separately reports task cost.

## 8. Coverage contract and direct acceptance cases

Every adapter publishes `supported`, `unsupported`, or `unverified` for each operation and traffic class on its exact engine/platform build. Only `supported` capabilities can commit. Capability reporting distinguishes inspection, pause, request edit, response headers/status, body transform, full replacement, replay, cancellation, and environment fault; one working feature does not imply the others.

| Class | Required coverage result / fixture |
|---|---|
| Ordinary HTTP, binary, encoded/compressed and empty bodies | Owned server receives exact submitted request; browser receives exact delivered bytes/status/headers; representation and byte limits checked |
| Redirects and authentication | Each hop/challenge independently owned; cross-origin credential omission and expiry tested; no unresolved callback |
| Cache/304 and worker responses | Report effective versus wire status and absence of server exchange; worker attribution can be unknown without invented frame identity |
| Multipart/files, ranges, trailers, integrity | Complete retained input and adapter semantics required; missing file data/unsupported edit rejected |
| EventSource/long downloads | Observational truncation leaves delivery alive; editable full-body mode rejects unknown/unbounded stream |
| WebSocket | Handshake observation separate from bounded message observation; message editing unsupported initially |
| WebTransport/QUIC datagrams | Lifecycle observation where available; payload/editing unsupported until independent coverage established |
| CORS/preflight/failure and canceled transfer | Distinguish permission/error/capture loss from delivered body; remote side effects preserved as unknown unless server proves them |
| Target startup/crash/navigation/process swap | Coverage gaps explicit; old generation decisions rejected; bounded pause termination/recovery verified |
| Environment TCP, UDP, DNS, routes/link | Controlled receiver/OS/page evidence for the actual advertised mechanism, plus unaffected control connection and other-owner resources |

State-machine tests must directly exercise: timer versus human commit; duplicate/stale decisions; body-taking versus disable/shutdown; budget/decode exhaustion; late callback after close; send cancellation before/after server receipt; redirect after validation; process/PID change; partial profile setup; helper disconnect; machine sleep past expiry; cleanup after another owner changes a resource. The expected outcomes are at most one host decision dispatch per lease, an acknowledged resolution or explicit uncertainty, bounded resources, exact endpoint effects, and unchanged unrelated resources. Mere absence of a crash supplies none of these outcomes.

Use the acquired owned HTTP fixtures, Mockttp transform tests, Toxiproxy connection tests, and packetdrill's expected-packet verifier as oracle precedents. Packet capture statistics/offloading/timestamps constrain transport interpretation. A model judgment or serialized HAR is not the oracle for a server side effect or native link signal. No test suite ran for this design. [Source/test map](../../papers/network-quarantine.md).

Before an implementation plan promotes these capabilities, review must establish
coherent ownership and failure contracts for adapter selection, pause teardown,
macOS narrow packet/link support, process/worker coverage, credential/cookie
enforcement, body limits and owned-resource recovery. Native experiments must
then establish the advertised behavior on the chosen build. These are explicit
unverified capabilities rather than hidden host-wide substitutes.
