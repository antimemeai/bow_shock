# Codex 0.160.0 native tandem preflight

2026-10-02. Research and metadata-only measurements for the first owned-catalog
tandem milestone. No model turn, SDK/package adoption, credential copying,
browser launch or product-source edit occurred. Read Blackbird, the reviewed
agent bridge/B1–B3 plan and native tandem/control plans. The separately owned
Rust unit is `docs/plan/controller-agent-proposals.md`.

## Primary evidence and restoration

The installed native arm64 executable reports `codex-cli 0.160.0`. Its generated
stable schemas in `context/design/codex-0.160.0` govern this adapter; experimental
schemas are separately retained but not enabled. Regenerate with the same CLI:

```sh
codex --version
codex app-server generate-json-schema --out context/design/codex-0.160.0
codex app-server generate-json-schema --experimental --out context/design/codex-0.160.0-experimental
```

Studied the original [OpenAI App Server documentation](https://learn.chatgpt.com/docs/app-server),
fetched this date. It describes JSONL stdio, initialization, fresh threads,
per-turn structured output and interruption. Version-specific schemas and
original source, rather than current documentation examples alone, decide field
names and event semantics here. Do not confuse `codex exec --json` events with
App Server notifications.

Original source is the already acquired OpenAI archive at revision
`59f18e8133f2c1d3427677658752ac46697d41b7`, documented with archive SHA-256 and
restoration URL in `papers/acquisition.json`. Reviewed selected App Server files
under `quarantine/codex-source`; additionally read `core/src/config/mod.rs`,
`features/src/lib.rs` and `utils/home-dir/src/lib.rs` directly from that preserved
archive with Python's standard `tarfile`. The archive revision is an independent
reference pin, not an asserted build provenance match for the installed binary.
The installed schema and actual metadata probe establish the local version.

The inspected stable `ClientRequest.json` SHA-256 is
`1c7fec8758deb95ffe967060130e8d1ddb7a0a5a437ee9b64086dddbed8f5831`;
`TurnCompletedNotification.json` is
`016870158603b0f84bd9f8f65f927161c9fd5128e5ec632087616462dc44e085`.

Metadata-only outputs are sanitized in
`context/research/codex-preflight/{metadata,selected-metadata}.json`; the selected
probe is retained there as `selected_metadata.py`. Raw account email, tokens,
credential files, configuration contents and history were not written or printed.

## Measured startup configuration

Both owned metadata processes completed initialization/account/catalog or
configuration/account-reference reads, closed stdin, exited zero and were reaped.
They had bounded reply/frame waits and terminal TERM/KILL of their owned process
group if EOF cleanup failed; no cancellation fallback was needed. This research
probe is not the production process supervisor.

The first probe found a managed ChatGPT account present, plan type `pro`,
`requiresOpenaiAuth=true`, eight visible catalog models and no further cursor.
The catalog default was `gpt-6.1-sol`; this reports current metadata, not a model
choice policy or successful inference access. Initial `account/updated` and
`remoteControl/status/changed` notifications were observed before explicit
account reads. Treat those as startup signals before establishing a baseline.

The second probe used only the selected existing authorized runtime HOME,
CODEX_HOME, LANG and a standard PATH in its child environment. Its working
directory was the actual operator home for this metadata-only probe. It did not
relocate the account, create a replacement Codex home or copy credentials.
`initialize.codexHome` matched the canonical selected runtime home. Original
configuration code canonicalizes an explicit existing CODEX_HOME and otherwise
uses the user's `.codex` directory. The existing native LANG-only environment is
insufficient to establish the intended runtime/account selection.

Measured argument array after the absolute selected Codex executable:

```text
app-server --stdio --strict-config
-c model_provider="openai"
-c model="gpt-6.1-sol"
-c sandbox_mode="read-only"
-c approval_policy="never"
-c web_search="disabled"
--disable shell_tool --disable unified_exec --disable multi_agent
```

`config/read` with `includeLayers=false` was inspected in memory, and only the
named model/provider/policy/web-search/feature metadata were retained. It confirmed
all these overrides and disabled feature flags. An actual production thread must
still verify its returned effective configuration; startup acceptance alone does
not prove thread/project-layer or provider behavior. Keep the operator-selected
development directory distinct from the runtime account directory and page data.
Use the actual native executable, not a shell command assembled from page text.
No API key or secret environment inheritance was necessary for this measured
managed-account configuration. Other providers/proxies are not implicitly supported.

Disabling these features and using read-only/never are routing restrictions, not
containment. Existing MCP/plugins, other runtime execution paths and the same-UID
environment remain relevant. The adapter exposes no browser tools or generic RPC.
The descriptor is **trusted coding peer**, local stdio executable with **hosted
inference** for this selected OpenAI managed-account setup. It is not a constrained
browser model. The configuration neither proves model entitlement nor erases any
provider-retained context.

## Account reference and descriptor

Stable `account/read` accepts `refreshToken:false`; its response exposes
`requiresOpenaiAuth` and optional account variants. A ChatGPT variant has
`type`, `email` and `planType`, but no opaque account ID. Email/type/plan are
measured identity metadata, not an account/workspace authentication boundary.
Never fabricate a strong identity from plan type or a catalog listing.

Stable `account/rateLimits/read` optionally returns `accountId`, described as the
account associated with the backend usage snapshot. The actual selected probe
returned one; only a SHA-256 reference was retained. This provides a nonsecret
backend reference without decoding/copying auth storage. Absence remains
unverified; backend errors must not trigger provider fallback. The original source
also demonstrates account changes can occur while a backend read is in flight.
Bind the measured reference to the selected runtime/connection generation; retire
on post-baseline account/configuration changes. It is not resistance to an
adversarial same-UID agent or an external mutation of its auth configuration.

The UI descriptor should carry runtime/version, provider/model, hosted/local
placement, selected account type/reference and reference-verification state,
trusted execution role, protocol version, selected environment and capability
states. Credentials never enter that descriptor. Catalog availability,
entitlement, successful structured inference and scoped export are different
claims. Only the last two later controlled/live oracles can establish their paths.

## Closed wire and final correlation

| Step | Exact installed stable contract |
| --- | --- |
| Initialize | `initialize` with `clientInfo{name,title,version}`, capabilities `experimentalApi:false`; wait for reply, then `initialized` notification. Reply includes `userAgent`, `platformOs`, `platformFamily`, `codexHome`. |
| Account/model metadata | `account/read{refreshToken:false}`, `model/list{limit,includeHidden:false,cursor}`; pagination is explicit and finite. Optional backend-reference read remains metadata, never an auth-token operation. |
| Fresh thread | `thread/start{model,modelProvider,cwd,approvalPolicy:"never",sandbox:"read-only",ephemeral:true,serviceName}`. Verify effective `model`, `modelProvider`, `cwd`, approval/reviewer and sandbox in response, plus selected runtime home and account baseline, before page-byte handoff. |
| Turn | `turn/start{threadId,input:[{type:"text",text}],outputSchema}`. Only host-owned selected candidate IDs/projection/objective are input; no toolOutput, paths, images, mentions or skills. No model/provider/policy overrides from page/model output. |
| Final item | `item/completed` includes `threadId`, `turnId`, `completedAtMs`, typed `item`. Agent messages have `id`, `type:"agentMessage"`, `text` and optional `phase`. Deltas are never extraction data. |
| Terminal | `turn/completed{threadId,turn}` with matching turn ID, `status:"completed"`, no error and matching validated terminal agent message. Failed/interrupted/inProgress are not successful proposals. |
| Interrupt | `turn/interrupt{threadId,turnId}` returns an empty result. Host retirement occurs immediately and independently; the response is neither disclosure recall nor proof that output/process activity stopped. |

Thread-start stable export has no `dynamicTools`; experimental opt-in is absent.
Set `approvalsReviewer:"user"` explicitly when starting the thread to avoid
inheriting an automatic reviewer; reject an unexpected returned reviewer.
Thread-start's sandbox enum is `read-only` while the returned policy object
uses `type:"readOnly"`; validate the effective object, not a string comparison.
No resume/fork/compaction, steer, direct command/filesystem/configuration/MCP route
is part of this extraction slice. `ephemeral` avoids ordinary thread persistence;
it does not establish provider erasure, absence of runtime logs or containment.

Original `request_processors/turn_processor.rs` submits the input before producing
its response, so clients cannot assume notifications always arrive after the
turn-start acknowledgement. Hold a finite pre-ACK event set and correlate when
the actual turn ID arrives, or fail unavailable; never admit an uncorrelated final.
Distinguish a server request (`method` plus `id`) from a client response by shape:
numeric request IDs can overlap in opposite directions.

Original `bespoke_event_handling.rs::emit_turn_completed_with_status` sends either
one last agent message with `itemsView:"summary"` or no items with
`itemsView:"notLoaded"`. It does not supply a full turn history. `thread_state.rs`
selects the last nonempty agent message with `phase:"final_answer"` **or null**;
the schema explicitly says providers do not consistently emit phases. Do not
treat the first phase-null interim message as final. Reconcile the terminal
summary with an already completed item by exact item ID/text; the repeated
representation is one candidate, while conflicting finals remain rejected.
Unknown/missing terminal content is unavailable rather than a request to resume
unknown history. Strictly validate the terminal text against the host's closed
selection/no-match schema after complete turn correlation and fresh authority.

## Server callbacks and retirement

Every callback belongs to its connection generation and its direction-specific
JSON-RPC ID, with thread/turn/item/approval/call IDs where present. Item ID alone
cannot own multiple approval callbacks. No callback grants a browser effect.
For this extraction-only unit, no UI approval wait or session acceptance is needed:

| Callback | Closed negative response, then retire the unsupported task |
| --- | --- |
| `item/commandExecution/requestApproval`, `item/fileChange/requestApproval` | `result:{decision:"cancel"}`. |
| `item/permissions/requestApproval` | `result:{permissions:{},scope:"turn"}`; no filesystem/network grant. |
| `mcpServer/elicitation/request` | `result:{action:"cancel"}`. |
| `item/tool/call` | `result:{contentItems:[],success:false}`; never dispatch dynamic JSON arguments. |
| `item/tool/requestUserInput` | `result:{answers:{}}`; no invented human answer, then retire. |
| Legacy `execCommandApproval`, `applyPatchApproval` | `result:{decision:"abort"}`. |
| External auth-token refresh, attestation or unknown callback | Unsupported protocol error/close and owned reap; no token reading, external login, attestation or generic dispatch. |

An implementation may instead fail-close/reap on a prohibited callback, with no
claim of a supported dialog. Managed auth should not require host external-token
refresh. `serverRequest/resolved` names `threadId` and `requestId`; late resolution
cannot restore a retired request. Account updates after baseline, mismatched
identity/settings, unknown callbacks, malformed/oversized output, stream/process
failure and deadlines retire proposal admission. No automatic resend of a lost
turn or replacement provider is permitted. Bytes already handed to a transport
remain potentially disclosed/retained regardless of interruption or reap.

## Owner plan review and direct oracles

The owner plan's conceptual boundary and controlled-peer-before-live ordering are
sound. Safe OwnedFd/std UnixStream setup, a sole authority owner and nonblocking
chunk writes under the same revocation lock address the actual byte-handoff
invariant without an async SDK. Communicated the contracts above before code.
Concrete bounded frames/input/selection/explanation/setup/turn/stderr/pre-ACK
retention must be part of its closed implementation contract. Fresh actual native
clock checks and authority identity gate every sensitive handoff/publication;
cached metadata/status must not revive retired source or proposals.

Controlled actual peers must cover permitted exact projection, excluded markers,
Stop before handoff and after a partial write, stalled stdin/stdout, terminal
identity conflicts/late/duplicate/malformed output, callback ID overlap and
pre-ACK ordering, actual zero automatic SQL writes and owned child reap before
replacement. Same final item in item/completed and terminal summary is a positive
compatibility case; conflicting finals are negative. Missing backend identity,
effective configuration mismatch and post-baseline account change are unavailable.
No model turn has yet established structured inference access. Root's reviewed
synthetic export/live-turn and native review/Save/SQLite join remain later evidence.

## Actual notification envelope and workspace-routing compatibility

The first actual joined metadata setup exposed two fields that the controlled
peer had omitted. A fresh metadata-only run with the production socket shape,
selected argv/environment and `experimentalApi:false` reproduced both safely;
no turn was submitted, and the owned process was killed/reaped. Sanitized shape
and binding results are in
`context/review-controller-agent/metadata-diagnosis/routing-research.log`.

Stable installed `ServerNotification.json` declares optional outer `emittedAtMs`
as an integer with int64 format. Pinned `ServerNotificationEnvelope` stores
`Option<i64>` and omits None for older peers; current outgoing notifications
always populate it. It is emission wall-clock metadata, never native authority
time. A closed adapter should admit only this optional signed integer in
addition to method/params, preserving callback direction and all existing
frame/depth/queue budgets. Unknown extra keys remain unavailable.

Stable installed `GetAccountResponse.json` excludes the `workspaceRouting`
property, while the experimental export includes optional null or a
`WorkspaceRouting` object. The pinned account processor nevertheless builds and
serializes that field for ordinary account/read. The source's outbound
experimental filter strips command-approval callback fields only; it does not
strip account responses. Experimental false therefore does not guarantee the
property's absence on the real wire. This is a schema-export/runtime distinction,
not permission to request unrelated experimental capabilities.

The exact object has string `chatgptAccountId`, string `backendOrigin` and
`accountRoutingOverride` enum `NO_CONSTRAINT`, `us`, `us_cr`. The actual selected
account returned this object: ordinary HTTPS chatgpt.com, no URL userinfo/query/
fragment, NO_CONSTRAINT, and its account ID matched the separately measured
rate-limit backend reference. Only shape, safe origin tuple and equality were
recorded; no email/credentials/raw account reference were printed.

This field can carry selected-account/backend routing policy. The smallest
proposed compatibility correction accepts absent/null for older peers and a
closed typed ordinary chatgpt.com/NO_CONSTRAINT object cross-bound to the
measured account reference. Other backend or regional routing should stay
unavailable until destination/policy support is explicitly reviewed. Merely
ignoring arbitrary routing objects would erase a meaningful destination check.
The controller owner/root decide and review this scoped contract before code;
the installed actual metadata failure is not an entitlement or inference test.

An authorized fresh empty thread/start preflight (no turn) additionally showed
runtime-serialized `runtimeWorkspaceRoots`, `activePermissionProfile` and
`multiAgentMode`, although stable export removes these experimental properties.
Pinned response source declares an absolute-path vector (default empty), optional
profile object/null and the deprecated default explicitRequestOnly mode. Actual
safe values were singleton selected cwd, null profile and explicitRequestOnly;
the stable readOnly sandbox also returned boolean `networkAccess:false`. These
observations are retained in `thread-policy.log`, without thread history content.

The owner's narrow accepted policy permits absent legacy fields, empty/singleton
selected cwd roots, null profile and explicitRequestOnly only. Sandbox is a
closed readOnly object with optional boolean false networkAccess (absence has
the source default false). Unknown fields, foreign roots, nonnull named profile,
other delegation modes and tool-network true are unavailable before page bytes.
This verifies effective settings; it does not prove coding-peer containment.
