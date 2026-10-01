# Agent connections and browser actuation

Research pass: 2026-10-01. This report studies integration mechanisms for Bow
Shock; it selects no dependency or browser engine. Primary documentation and a
small set of source files were read. The source catalog is
[agent-sources.json](agent-sources.json); acquisition pins and restoration belong
in [acquisition.json](acquisition.json). Repository links below identify files
read at mutable `HEAD`; compare them with the acquired revision before turning
observations into an implementation specification.

The central finding is that connecting an agent and enforcing bounded browsing
are separate problems. Existing bridges provide useful observations and actions,
but a tandem browser needs its own authority over which actions may execute in
the person's live session. A conversation approval, a filesystem sandbox, and a
browser action grant describe different powers.

## The two protocol directions

**Browser as Codex client.** Codex App Server exposes a bidirectional JSON-RPC
interface for rich clients. Its wire format omits `jsonrpc`; default stdio uses
JSONL. It also documents WebSocket and Unix-socket connections. Initialize once,
acknowledge initialization, then use threads, turns and streamed item events.
`turn/steer` adds human input; `turn/interrupt` requests cancellation.
Server-initiated approval requests carry conversation/item identifiers.
Experimental dynamic tools let a client receive `item/tool/call` and return tool
results. Generate protocol schemas using the exact installed CLI version. The
docs currently mark App Server and WebSocket transport experimental and
unsupported for production. Remote WebSocket auth is configurable, and the docs
warn that non-loopback listeners can otherwise accept unauthenticated clients.
[Official App Server documentation](https://learn.chatgpt.com/docs/app-server).

**Browser as Codex tool provider.** Codex can consume external MCP servers over
stdio or Streamable HTTP, including authenticated HTTP servers. Server-wide
instructions and tool schemas guide model use; configurations expose server/tool
controls. This lets an existing Codex client call a browser-owned tool service.
[Official MCP client documentation](https://learn.chatgpt.com/docs/extend/mcp).

Do not conflate these with the old direction of hosting Codex as an MCP server:
the current documentation says `codex mcp-server` and the standalone
`codex-mcp-server` binary have been removed. App Server is a different protocol,
not an MCP replacement that an unchanged client can consume.
[Official removal notice](https://learn.chatgpt.com/docs/mcp-server).

For a local experiment, study a browser-owned child process with inherited
stdio before adding another listening port. This is a research preference, not
an engine or dependency decision: it makes process lifetime and connection
ownership straightforward to inspect. A socket deployment needs explicit peer
authentication, filesystem permissions where applicable, and a clear rule for
which client owns a pending approval. Loopback location alone does not establish
who may invoke actions.

OpenAI's separate Sign in with ChatGPT integration documents an OAuth-backed
Responses provider, child-process token delivery, stable client identity fields,
token renewal through process restart, and conversation resumption. It cautions
that a model catalog is not an entitlement check. Account authentication should
be resolved against the intended local/open-source versus hosted/commercial
distribution; do not assume access to a signed-in CLI grants a new application
unlimited rights to reuse its authentication.
[Official Sign in with ChatGPT App Server guide](https://developers.openai.com/siwc/token-sharing-open-source/codex-app-server).

## Bridge options worth comparing

The implications column is Bow Shock analysis, not a promise made by the source.

| Mechanism | Evidence to study | Implication for tandem browsing |
| --- | --- | --- |
| App Server client plus browser-owned tools | Rich-client protocol above; dynamic tools are experimental | Browser can present the conversation and keep action authority local; isolate version churn from engine control. |
| Existing Codex client plus constrained MCP service | External MCP direction above | Early experiments need less conversation UI; browser still must expose live ownership, revocation and approvals to the person. |
| Extension plus Native Messaging host | Chrome native host registration and framing | Can retain an existing browser and profile; installed host and extension identity become operational requirements. |
| Extension debugger attachment plus local broker | Chrome debugger API and Playwright relay | Gives tab-specific CDP access, but detach, restricted domains/pages and DevTools use need explicit handling. |
| Browser-owned automation endpoint | CDP/Playwright/Puppeteer reference code | Strong control of engine lifecycle; an unconstrained endpoint can bypass the intended action gateway. |
| WebDriver BiDi adapter | W3C protocol and Selenium/Puppeteer implementations | Useful independent portability and event-model reference; verify capabilities for each candidate browser. |

Native Messaging uses a registered host manifest with exact allowed extension
origins, then length-prefixed UTF-8 JSON over stdio. That differs from Codex
JSONL, so a host must translate framing rather than pipe bytes blindly. The host
receives the calling extension origin. Chrome caps host-to-browser messages at
1 MB and browser-to-host messages at 64 MiB. Only extension pages/service workers
can call native APIs; forwarding from content scripts requires origin validation
and sanitized payloads.
[Chrome Native Messaging documentation](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging).

The official
[Native Messaging sample](https://github.com/GoogleChrome/chrome-extensions-samples/tree/main/api-samples/nativeMessaging)
includes extension registration, a persistent `connectNative` port, disconnect
handling and host framing. It is an echo demonstration; it does not establish
browser action authentication or authorization. The
[Chrome debugger API](https://developer.chrome.com/docs/extensions/reference/api/debugger)
exposes a restricted subset of CDP domains and detach events; opening DevTools
can end an extension's debugger session. Study recovery as a ownership change,
not a reason to silently reacquire control.

For HTTP MCP, the versioned transport specification requires Origin validation
and recommends local-only binding and authentication. It also distinguishes a
transport disconnection from cancellation. Tools have input/output schemas, but
annotations are untrusted unless supplied by a trusted server. These are useful
protocol rules; they do not supply Bow Shock's page-state or delegation policy.
[MCP transport specification](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports),
[MCP tools specification](https://modelcontextprotocol.io/specification/2025-06-18/server/tools).

## Reference implementations: what to read and what not to assume

### Playwright MCP and Playwright's extension relay

Playwright MCP supplies accessibility-based observations and browser actions,
with options for isolated contexts, CDP attachment and an extension connection.
Its README explicitly says it is not a security boundary; origin allow/block
filters do not protect redirects. Treat those filters as convenience controls
until the actual containment mechanism is established.
[Playwright MCP README](https://github.com/microsoft/playwright-mcp).

The wrapper repository's
[src/README.md](https://github.com/microsoft/playwright-mcp/blob/main/src/README.md)
points to source in the Playwright monorepo. Read
[browserFactory.ts](https://github.com/microsoft/playwright/blob/main/packages/playwright-core/src/tools/mcp/browserFactory.ts),
[extensionContextFactory.ts](https://github.com/microsoft/playwright/blob/main/packages/playwright-core/src/tools/mcp/extensionContextFactory.ts),
and [cdpRelay.ts](https://github.com/microsoft/playwright/blob/main/packages/playwright-core/src/tools/mcp/cdpRelay.ts).
The factory distinguishes browser ownership and isolated, CDP and extension
connections. The extension path connects through a relay using `connectOverCDP`
with `noDefaults: true`; the relay separates extension and CDP endpoints. This
is a concrete source reference for preserving the user's browser settings while
attaching an automation client. Authentication and lifecycle details still need
the relay's full call graph and tests read.

The library documentation calls CDP attachment Chromium-only and lower fidelity
than Playwright's own protocol. It also warns that launch arguments and browser
versions affect behavior. `noDefaults` avoids selected default-context changes,
including focus/media emulation and download defaults. None of this establishes
that every CEF build satisfies the assumptions of Playwright's Chromium adapter.
[Playwright connectOverCDP documentation](https://playwright.dev/docs/api/class-browsertype#browser-type-connect-over-cdp).

### Chrome DevTools MCP

Study [the repository](https://github.com/ChromeDevTools/chrome-devtools-mcp)
for snapshots, element identities, input and navigation, diagnostics and
connection lifecycle. In the directly read
[script.ts](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/src/tools/script.ts),
`evaluate_script` accepts arbitrary inline or file-loaded JavaScript and is
marked `readOnlyHint: false`. Its handler executes in a page/frame or eligible
worker and can handle dialogs. A named click/submit policy would not contain
this power unless evaluation is independently constrained. Read input/page
handlers and their tests alongside the snapshot model before using these patterns
for a human's active session.

### Browser Use and Browser Harness

[Browser Use](https://github.com/browser-use/browser-use) is useful as an
autonomous baseline with browser state, observation, actions and an agent loop.
The directly read
[agent/service.py](https://github.com/browser-use/browser-use/blob/main/browser_use/agent/service.py)
has step hooks, a step budget, pause/resume and stop methods. `pause` describes
pausing before the next step and sets state/event flags; that is not evidence
that it retracts an already-issued browser action. The
[browser/session.py](https://github.com/browser-use/browser-use/blob/main/browser_use/browser/session.py)
contains direct CDP sessions and shared target/session lifecycle. Study whether
step hooks run before observation, planning, each action, or only a batch.

The current README also links
[Browser Harness](https://github.com/browser-use/browser-harness) as its CLI
companion for an existing agent. Its tree was inventoried (`_ipc.py`, `daemon.py`,
`auth.py`, MCP server), but its implementation was not deeply read in this pass.

### Stagehand

Study [Stagehand](https://github.com/browserbase/stagehand) for a decomposition
between observation, extraction, action and agent orchestration, plus browser
extension and CLI approaches. Direct reads covered action-handler utilities
and [its Codex integration example](https://github.com/browserbase/stagehand/blob/main/packages/integrations/codex/src/agent.ts).
The example configures an external stdio MCP server through SDK configuration
and keeps the local filesystem sandbox read-only while browser work happens in
the MCP server. It also selects automatic approval review and `on-failure`,
with comments about empirical headless behavior. Those settings are a particular
example's choices, not Bow Shock policy or current compatibility guidance. The
example illustrates why a filesystem sandbox does not bound authenticated
browser side effects.

### Agent Browser

[Agent Browser](https://github.com/vercel-labs/agent-browser) exposes a CLI,
daemon/session model, snapshots, action policy and confirmation controls. Its
current domain allowlist documentation covers multiple network routes and
rejects existing CDP sessions, reused profiles and other modes where containment
cannot be installed early enough. This restriction is especially relevant to a
human's existing authenticated session: an integration path can be convenient
yet unable to support a particular containment claim.

The directly read
[policy.rs](https://github.com/vercel-labs/agent-browser/blob/main/cli/src/native/policy.rs)
checks deny before confirmation before allow and includes tests for precedence.
Its `load_if_exists` helper converts a load error to absence using `.ok()`;
empty/missing allow lists can permit actions absent a deny default. This is a
call-graph audit lead, not a claim that the entire current CLI fails open. Study
how configuration errors and policy reloads reach the action dispatcher before
borrowing the pattern.

### CDP, Puppeteer, Selenium and WebDriver BiDi

[CDP definitions](https://github.com/ChromeDevTools/devtools-protocol) provide
the raw command/event surface. Pin protocol definitions with the actual browser
revision; do not infer compatibility from one protocol version string.
[Puppeteer](https://github.com/puppeteer/puppeteer) has separate CDP and BiDi
connection implementations and target lifecycle handling.
[Its BiDi documentation](https://pptr.dev/webdriver-bidi) documents Chrome and
Firefox support and remaining feature differences.
[Selenium](https://github.com/SeleniumHQ/selenium) provides another implementation
and tests; [its BiDi guide](https://www.selenium.dev/documentation/webdriver/bidi/)
explains the transition to bidirectional automation. The
[W3C specification](https://www.w3.org/TR/webdriver-bidi/) is the normative
reference, but the dated September 2026 draft fetch failed in this pass and
remains an acquisition task.

Chrome's remote-debugging switches changed starting with Chrome 136: default
profile debugging requires attention to the non-default user-data directory
rule. Study this before proposing an attach flow to the person's regular profile;
do not silently copy cookies or profiles to work around it.
[Chrome's remote-debugging change](https://developer.chrome.com/blog/remote-debugging-port).

## Candidate control contract to pressure-test

The following is an inference from the integration evidence and the user's
bounded-delegation goal. It is a research agenda, not an approved specification.

1. **One browser authority.** Every agent mutation reaches a browser-owned
   gateway, whether it arrived through MCP, a dynamic tool, an extension, a
   subprocess or a retry. The engine adapter's credentials/endpoints stay behind
   that gateway. A policy is incomplete if raw CDP, arbitrary JavaScript or a
   second automation route can act outside it.
2. **A grant names its scope.** Consider tab/window identity, browser context,
   top-level origin and frame scope, actions, observation data, budget and expiry.
   A read grant may still disclose authenticated information; navigation can
   cause server effects. Label powers by what happens, not by tool names alone.
3. **An action refers to observed state.** Consider a document/navigation epoch
   and a stable target reference. Between observation and execution, the human,
   page scripts, another tab or a redirect can change the meaning of a target.
   A stale operation should return a fresh-state requirement rather than quietly
   applying the old instruction to a replacement document.
4. **Human takeover revokes locally first.** Revoke the gateway's authority and
   invalidate queued operations at the browser, then request agent cancellation.
   An acknowledgement from the conversation transport is not a rollback of a
   browser event already dispatched or a server transaction already accepted.
5. **Approvals bind concrete work.** A pending approval needs action parameters,
   target identity, observed state, grant identity and expiry. A human navigation
   while the prompt is open should invalidate it. Receiving a late approval after
   revocation must not restore control.
6. **Progress reports distinguish outcome.** Separate proposed, authorized,
   dispatched, observed-complete, failed, cancelled-before-dispatch and
   outcome-unknown. Retrying a click after a lost reply can duplicate a payment,
   message or submission. Transport request IDs alone do not prove an operation
   is idempotent.
7. **Special powers remain explicit.** File upload/download, clipboard, dialogs,
   permissions, new tabs, cross-origin frames, authenticated data extraction and
   account-changing actions deserve separate study. A single general-purpose
   JavaScript tool can combine all of them.

The hardest case is human input during an awaited automation action. A
next-step pause permits too much overlap for a strict takeover guarantee. The
host needs a defined serialization point for revocation and dispatch, plus honest
reporting for operations beyond that point. Similarly, clicking a button and
making a same-origin `fetch` can cause the same external effect: neither action
names nor button text provide a complete semantic effect classifier. Site-native
tools, known workflows or human confirmation may offer stronger boundaries, but
that requires separate evidence.

## Next reading and experiments

Before implementation, compare three narrowly scoped experiments: a visible
browser with a browser-owned tool gateway; an existing browser with extension
and native host; and an App Server conversation client using the same gateway.
Keep their action contract identical so the experiment isolates connection and
engine behavior rather than accidentally testing three different products.

The useful adversarial cases are concrete: revoke between planning and click;
change the page while approval is pending; navigate a cross-origin iframe;
open DevTools during extension control; kill/restart the agent connection;
deliver duplicate or delayed replies; load an invalid policy; and attempt the
same forbidden effect through click, keyboard, JavaScript and a raw protocol
connection. Use an instrumented local site that records received mutations as
the direct oracle. No such experiments were run in this research pass.

Unresolved: App Server feature/version compatibility and distribution auth;
whether CEF exposes every selected adapter assumption; durable element identity
through navigation; exact human takeover semantics; semantic effect boundaries
on arbitrary sites; cancellation of work already sent; profile separation and
extensions; and visibility of browser/server changes initiated outside the
agent. Acquiring source is the beginning of those investigations.
