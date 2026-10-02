# Native agent and onboard-model bridge

Design proposal, 2026-10-01; [tribunal reviewed](../../papers/design-tribunal.md). This specifies the bridge boundary,
not an adopted provider, SDK, transport library or browser engine. It follows
[product intent](../product-intent.md): the model observes locally rendered state
and proposes work; the independent OS executor delivers input. Human network
diagnostics, extraction and environment interventions have their own execution
owners. Supporting research is [agent connections](../../papers/agent-connections.md)
and [network observatory](../../papers/network-observatory.md).

Assumption pending operator choice: both local and hosted inference are supported
through provider adapters. The interface stays neutral; a provider without a
required capability is unavailable for that workflow. There is no automatic
switch from local to hosted inference, nor automatic disclosure to a second
provider. The owned window is macOS first and Linux second.

## Authority and the same-UID limit

The bridge is an authenticated conversation/proposal channel. It does not own
browser control, synthesize OS input, send diagnostic HTTP requests, change host
routes or commit extraction rows. Those effects remain with their respective
host services. A valid schema establishes what a proposal says; it establishes
neither permission nor that its intended effect occurred.

Two roles must remain distinguishable in configuration and the UI:

| Role | Intended powers | Security claim |
| --- | --- | --- |
| Constrained browser role | Receive selected observations; return typed proposals and explanations | Only available when its runtime lacks independent execution paths and its actual deployment supports the claimed containment |
| Trusted coding agent | Work in an operator-selected development environment; discuss observations and propose browser/network/extraction work | Trusted for its environment's ambient privileges; browser tools constrain cooperative requests through this bridge only |

A coding agent running as the person's UID with arbitrary shell can use whatever
files, IPC, network, OS automation and process privileges that environment permits.
It may reach a browser debugging endpoint or change a profile outside Bow Shock's
tool gateway. Hiding those tools, issuing a browser grant, using a private socket
or asking the agent to follow instructions does not sandbox that agent. Tokens
and Unix peer UID checks do not distinguish two programs with the same ambient
authority. This design explicitly does not claim resistance to an adversarial
trusted coding agent, compromised host or authorized same-UID shell.

The constrained browser role has no general shell, filesystem-write, raw CDP,
arbitrary page JavaScript, OS automation, unbounded HTTP client, proxy admin or
environment-controller interface. A provider inference API that only returns
data can serve this role through the trusted host adapter. A local inference
daemon is still a trusted executable; "local" is not itself containment. If a
Codex deployment retains arbitrary shell or unrestricted MCP/tool routes, it is
classified as a trusted coding agent even when it returns a typed browser proposal.

Codex permission settings can limit a particular execution environment, but
their effectiveness, external MCP authority, child processes, inherited handles
and host access must be measured before claiming a constrained role. A read-only
filesystem setting alone does not bound authenticated browser effects. A future
separate-user/container/VM execution boundary needs its own macOS/Linux design and
direct escape/coverage review; this document does not invent one.

## Ownership and provider contract

The host selects an adapter instance, its authenticated account/endpoint,
execution role, observation disclosure policy and allowed operation set. Model
output cannot select another account, change its role, add a tool/provider, amend
permissions, choose a local file to upload or alter a runtime configuration.
Provider credentials never appear in observations, proposal fields or page data.

Each adapter exposes a descriptor with provider/runtime identifier and version,
model identifier, local/hosted inference placement, applicable account reference,
execution role, protocol/schema version, and a capability result. Capability
states are `supported`, `unsupported` or `unverified`, with the version and probe
that established them. Availability, account entitlement and authorization are
separate properties. A model appearing in a catalog is not sufficient evidence
that the account may use it.

The required logical operations are:

- **Open:** create a provider session from host-selected settings and return its
  instance identity and effective capabilities. Auth/setup failure returns no
  usable session.
- **Propose:** take a bounded observation bundle, operator objective, permitted
  proposal kinds and host-issued request identity/deadline; return incremental
  display events and at most one final candidate for that request.
- **Steer:** append a human correction to the named active request when supported.
  Failure or absence requires a new request, not an implicit parallel continuation.
- **Cancel:** request provider cancellation and report its actual semantics.
  The host independently invalidates pending proposals immediately.
- **Reconcile:** read current/persisted provider state after interruption when
  supported. It does not reissue effectful work.
- **Close:** disconnect/release the instance according to process ownership,
  clear live callback ownership and invalidate its pending proposals.

Required workflow capabilities include input modality, maximum input/output
size, final structured output or equivalent strict host validation, streaming
event identities, cancellation and persistence semantics, and optional tool-call
support. Locality, tool advertisements or a provider's self-reported capability
are not attestations of isolation. The host's role classification is authoritative.

A provider lacking screenshots may receive a declared DOM/text-only bundle;
the user can see that limitation. A model unable to return a valid proposal may
still provide ordinary discussion. It cannot receive arbitrary execution power
as compensation for a weaker output format. Network latency, context limits,
usage limits and unavailable models produce visible degraded/unavailable states.

## Observation and disclosure

An observation bundle resolves the complete `ObservationRef` freshness tuple
from host evidence: host run, session/window/tab, attachment/target/frame,
document/BFCache activation/node-ID generations, effective origin and timestamped
presentation context. It includes observation time and extraction/snapshot version. It
identifies included DOM, accessibility, screenshot, network-summary or existing
table evidence; omitted/inaccessible/truncated content has explicit reasons.
Engine handles and debugging endpoints are never provider references.

Page-controlled text is labeled as page evidence. The operator objective and
host policy are distinct inputs. A page instruction such as "run this command"
does not become an operator message or a trusted bridge instruction. Labels
help interpretation; authority checks remain necessary even if the model ignores
them. Conversation summaries retain origin/provenance and disclosure scope rather
than laundering old page text into host instructions.

Observation selection applies before transmission and before provider-visible
history is created. Hidden fields, cookies, authorization headers, tracker/customer
identifiers, filesystem paths and screenshots require the selected disclosure
policy. A DOM read can disclose authenticated content even though it has no
mutation. All frame/origin inclusion follows the observation service's grants;
the bridge never treats a same-tab frame as automatically in scope.

Hosted inference and provider-held conversation history are external disclosures.
The host records which observation references were supplied, the provider/account
destination and the disclosure-policy version in the shared timeline. It cannot
promise erasure of copies already retained by a provider. Local inference can
still persist sensitive conversation data. Resume, fork, compaction and model
switching therefore require disclosure reconciliation rather than trusting a
conversation ID as an authorization token.

The disclosure selector is the export effect owner. It binds an immutable bundle
and derivative ancestry to an export grant, session epoch, export generation,
provider/account/model and deadline. It rechecks them at each last host-controlled
handoff of bytes to the provider transport, under the same serialized authority
decision as revocation. Serialization or entry into an adapter queue is not
transmission authorization. Revocation discards unsent queued bundles and their
pending retries; a new connection/provider cannot flush them. A client unable
to enforce that handoff/revocation boundary cannot advertise cancellable scoped
export. Bytes already handed to OS/client transport may arrive afterward;
outcomes distinguish `not_transmitted`, `transport_handoff_started`,
`partially_transmitted`, and `provider_retained_unknown`. Interrupt/abort is
best effort for handed-off bytes, never a recall claim. Scope changes invalidate
pending model admissions independently of whether the provider stops.

Every host-created conversation has conservative disclosure ancestry: the
union of origin/document/data-class/provider/account scopes for supplied and
derived content, including model quotations and compacted summaries. Inference
does not remove those labels by summarizing or claiming it redacted something.
Continued use, retention and new transmission are separate decisions. Resume,
fork, compaction and account/provider/model changes are allowed only if the
effective history is known and its entire ancestry is within the current use
and destination policy. Otherwise start a fresh thread with host-selected
authorized reconstructed context, or obtain a concrete expanded-history choice.
Unknown/incomplete provider history is not clean history. Codex `excludeTurns`
omits history from the response payload; it is not a context-deletion operation.
No automatic copying of old history to another provider/account occurs.

After scope reduction, stop further use of an out-of-scope provider thread even
when the provider retains its old copies. Provider-side derived context cannot
always be inspected or erased: a backend that cannot establish ancestry remains
unavailable for clean-scope resume and uses a fresh host-owned context. The UI
shows the limitation rather than asserting provider erasure. Restored dynamic
tool descriptions are data and never revive grants.

## Typed proposals and admission

The host creates a proposal request envelope containing its request ID, bridge
instance/generation, task ID, observation IDs, allowed proposal kinds, deadline
and size limits. The provider returns a candidate containing that request ID,
candidate ID, one kind, its typed payload, evidence references, stated intended
effect and uncertainty/need-for-clarification. The adapter adds trusted provider
and conversation identifiers; identity claimed inside model JSON is not used
to establish the caller.

Candidate kinds are deliberately separated:

| Kind | Candidate describes | Execution owner |
| --- | --- | --- |
| Input proposal | Semantic target reference, intended keyboard/mouse/scroll operation, text/value where permitted, and observed preconditions | OS executor validates the fresh target, window/focus, grant, sequence limits and takeover state |
| Network draft | A reviewable request/response edit, substitution or new-request specification and evidence | Network workbench; drafting does not send, intercept or activate a rule |
| Extraction candidate | Page-type/field/row mapping or extracted values with source spans and uncertainty | Extraction service stages, validates and commits under its own contract |
| Environment experiment draft | Proposed interruption conditions, scope and duration | Environment controller; a draft cannot alter routes/interfaces |
| Explanation/clarification | Discussion or explicit inability to ground the next step | Conversation UI; no executor |

Input proposals cannot contain script text, CDP method names, raw OS event
streams or provider-selected execution code. A DOM target is evidence for intent,
not a stable right to act on a later document. The OS executor, rather than the
model or bridge, owns trajectory/timing realization. Network diagnostic powers
and database commits never piggyback on an input grant.

Admission follows this order: enforce frame/byte limits; decode without evaluating
content; strictly validate the closed kind-specific schema; correlate host-issued
request and generation; check observation/deadline; enqueue one candidate for
the relevant execution owner. Unknown fields, unsupported kinds, inconsistent
evidence or duplicate competing finals are rejected. Partial streamed JSON and
display deltas never dispatch an effect. Any schema repair asks for a fresh
candidate within bounds; it cannot silently remove a dangerous field and execute
the altered meaning.

The execution owner checks the current grant and preconditions at the actual
effect boundary. Grant IDs are references to host state, not bearer authority
supplied by a model. No broad grant can be inferred from natural-language praise,
a Codex approval or a prior successful proposal. Revocation, affected navigation/
activation, input takeover, provider change or bridge restart invalidates the
affected pending admissions. The
shared authority design defines exact epoch/grant transitions; this bridge uses
them rather than keeping a second policy copy.

Historical observations remain readable evidence under retention policy, but
are action-ineligible after attachment/activation/node invalidation. A fresh
grant cannot revive them. Admission resolves host evidence rather than trusting
model-supplied freshness integers; the executor independently checks the same
tuple and current target at the effect boundary.

Results name their narrow truth: draft accepted/rejected, action admitted,
delivery attempted/completed, effect observed, failed, canceled-before-effect or
outcome unknown. Provider turn completion is not action success. Reusing a
candidate ID never repeats an effect: the host returns its recorded disposition
or reconciliation requirement. Unknown remote outcome cannot be repaired by
automatically resending a request or OS input.

## Codex adapter: versioned baseline and experimental path

Local preflight identified `codex-cli 0.160.0` and exported schemas in
[the local schema directory](../../context/design/codex-0.160.0). No agent or
App Server was started for this design. The acquired Codex source pin
`59f18e8133f2c1d3427677658752ac46697d41b7` is separate source-study evidence; it
is not presumed to be the installed binary's exact implementation.

The initial native connection design is a host-owned child process using
inherited stdio and JSONL framing. This gives explicit connection/process
ownership without a listener. Stderr is diagnostic output, not protocol input.
Framing has hard size/time limits and malformed protocol input closes admission.
Unix sockets or WebSockets are optional later adapters needing their own peer,
listener, reconnect and approval-owner specification. Loopback and same-UID
socket permissions do not establish containment of a trusted coding agent.

Official docs describe initialization, thread/turn/item streaming, stdio/unix/ws,
version-specific schema generation, and experimental dynamic tools. The installed
exports below, rather than mutable examples alone, define this adapter's initial
wire shapes. [Official App Server docs](https://learn.chatgpt.com/docs/app-server).

1. Before connection use, the host verifies the selected executable/version,
   schema identity and role configuration. An unknown version cannot silently
   reuse the previous supported contract. Do not upgrade a running bridge.
2. Send `initialize` with host client identity and only implemented capability
   opt-ins, validate its response, then send `initialized` once. The generated
   response includes `userAgent`, platform and Codex-home metadata; it does not
   supply a complete execution-capability attestation.
3. Create/resume the host-selected thread with explicit model/provider and
   environment/approval settings. Defaults and loaded configuration are not
   accepted as proof of a constrained role. Start and resume can apply overrides;
   some turn overrides also persist to subsequent turns.
4. Submit an observation and objective with `turn/start`. Its `outputSchema`
   constrains the final assistant message: use it for a single typed candidate,
   then apply host validation. This field does not disable Codex's other tools
   or sandbox its shell before the final message.
5. Track provider thread, turn and item IDs separately from browser/task IDs.
   `turn/steer` requires `expectedTurnId`; a mismatched active turn is an error,
   not permission to steer another turn. `turn/interrupt` names thread and turn.
6. On `turn/completed`, reconcile final status and the final item before accepting
   a candidate. A duplicate event updates known state without another dispatch.
   If observed provider settings/model/account no longer match host selections,
   invalidate pending candidates and re-establish capabilities.

Exact local wire evidence:
[initialize definitions](../../context/design/codex-0.160.0/ClientRequest.json),
[initialize response](../../context/design/codex-0.160.0/v1/InitializeResponse.json),
[thread start](../../context/design/codex-0.160.0/v2/ThreadStartParams.json),
[thread resume](../../context/design/codex-0.160.0/v2/ThreadResumeParams.json),
[turn start](../../context/design/codex-0.160.0/v2/TurnStartParams.json),
[steer](../../context/design/codex-0.160.0/v2/TurnSteerParams.json),
[interrupt](../../context/design/codex-0.160.0/v2/TurnInterruptParams.json).

Dynamic browser tools are a gated alternative, not a baseline promise. The
standard `ThreadStartParams` export omits `dynamicTools`; a second export with
`--experimental` includes it as an optional array of `DynamicToolSpec`.
This establishes the installed version's experimental wire shape, not successful
registration or effective tool authority in a running configuration. Require
explicit experimental opt-in and a controlled integration probe before enabling
this route. Persisted tool descriptions from a resumed thread do not revive
browser grants. [Experimental thread-start schema](../../context/design/codex-0.160.0-experimental/v2/ThreadStartParams.json).

To recreate the inspected schemas with the same installed CLI version (no server
is started):

```sh
codex --version
codex app-server generate-json-schema --out context/design/codex-0.160.0
codex app-server generate-json-schema --experimental --out context/design/codex-0.160.0-experimental
```

When enabled, dynamic tools only request bounded observations or typed proposals.
The generated callback has `threadId`, `turnId`, `callId`, optional namespace,
tool and unrestricted JSON `arguments`. Validate arguments against Bow Shock's
own strict schema and callback ownership; never dispatch arbitrary JSON because
the wire accepts it. Return a bounded result in `contentItems` and `success`.
This success flag describes the callback result and must not claim an unobserved
browser effect. Unknown or already-resolved callbacks cannot execute work.
[Call schema](../../context/design/codex-0.160.0/DynamicToolCallParams.json),
[response schema](../../context/design/codex-0.160.0/DynamicToolCallResponse.json).

`modelProvider/capabilities/read` in this export reports `imageGeneration`,
`namespaceTools` and `webSearch` only. It does not report sandbox enforcement,
browser authority, tool registration support, account entitlement or all input
modalities. Read it as that limited signal, alongside explicit capability probes.
[Provider-capability schema](../../context/design/codex-0.160.0/v2/ModelProviderCapabilitiesReadResponse.json).

The client method schema also contains direct command, filesystem, configuration,
MCP and thread shell-command routes. The browser-facing bridge never offers a
generic RPC forwarder. Its allowlist is the conversation/capability/host-owned
auth methods actually implemented by this adapter. Trusted coding workflows can
use their separately selected development environment; page evidence cannot
invoke that environment's command API. Supporting App Server as a transport does
not require adopting all of its methods.

## Approvals, identity and failure ownership

Codex command/file/permission approvals are provider execution approvals, not
browser grants. Route each pending request to the host UI using connection
generation, JSON-RPC request ID, thread/turn/item identifiers, and optional
`approvalId`/kind. A command item can have multiple approval callbacks; item ID
alone is not a unique pending approval. Show the actual command/environment and
requested scope. Do not interpret best-effort parsed command labels as a complete
effect description.

No timeout means approval. Browser-role requests for prohibited capabilities are
declined; trusted coding-agent execution follows its separately chosen operator
policy. A grant for one browser action cannot create session-wide shell or
network-policy amendments. A provider `serverRequest/resolved` notification
clears the pending callback; late UI responses are discarded. Auth-token refresh
is handled by the host identity service, scoped to the selected account, and its
secrets bypass ordinary timeline/model content.
[Command approval](../../context/design/codex-0.160.0/CommandExecutionRequestApprovalParams.json),
[permission approval](../../context/design/codex-0.160.0/PermissionsRequestApprovalParams.json),
[resolved notification](../../context/design/codex-0.160.0/v2/ServerRequestResolvedNotification.json).

Use the runtime's supported sign-in mechanism or separately authorized provider
credentials. A signed-in CLI is not permission to copy credentials to another
application or hosted service. App Server token-sharing/distribution choices
need to follow the intended integration's supported flow; secrets never reach
page state. [Official sign-in integration](https://developers.openai.com/siwc/token-sharing-open-source/codex-app-server).

| Condition | Required bridge behavior |
| --- | --- |
| Human takeover/revocation | Invalidate host admissions first; notify executors and request provider interruption independently; discard later proposals |
| Missing/unavailable model, rate/context/usage limit | Report the reason; stop proposal admission for that request; do not change provider/model/disclosure scope silently |
| Transport/process loss | Advance generation, mark in-flight candidates/callbacks unavailable, reconcile executor outcomes; never resend effects because a turn reply was lost |
| Partial or malformed structured output | Preserve a bounded diagnostic, reject the candidate; no partial execution or automatic script fallback |
| Provider response after deadline/cancellation | Record late completion for reconciliation/display only; reject admission |
| Provider version/account/config change | Invalidate capabilities and pending work; reconnect/probe with fresh generation and required disclosure review |
| Resume/fork/history unavailable | Start fresh only under host choice; history context may be lost, grants never reconstructed from it |
| Slow event stream/overfull buffer | Stop new admission and interrupt/close within bounds; mark incomplete display evidence rather than drop authority events and continue |

App Server history-reading/listing APIs may recover conversation evidence but do
not recover Bow Shock execution authority. The inspected schemas contain
paginated turns/items and deprecated full-history hydration notes; actual usable
history modes require version/capability confirmation. No assumption of gap-free
notification replay or guaranteed exactly-once transport is made.

## Review claims and acceptance evidence

Before implementation approval, pressure-test at least these traces: malicious
page text requests shell/raw CDP; a final JSON candidate arrives after takeover;
a response is lost after OS delivery or an HTTP send; a turn-steer precondition
mismatches; multiple approval callbacks share an item; an old thread restores
dynamic tool descriptions; a provider switch would disclose earlier sensitive
history; and a version accepts a method whose capability was not negotiated.

Direct evidence must show the execution owner performed no stale/unauthorized
effect, not merely that the bridge printed a rejection. A controlled provider
can deliver late/duplicate/malformed envelopes; a controlled browser/server/input
target supplies the independent effect oracle. For a claimed constrained role,
test the actual deployment's independent shell/IPC/network paths. A trusted
same-UID coding agent escaping the browser tools demonstrates the stated ambient
trust boundary; it cannot be reported as containment success.

Remaining decisions: onboard inference placement/provider policy; exact
constrained-role deployment, if any; Codex experimental-tool support; supported
version/update policy; provider-history retention and deletion semantics; and
socket-based deployment. This doc establishes the contracts those choices must
satisfy. It does not select dependencies or authorize product implementation.
