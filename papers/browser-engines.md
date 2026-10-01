# Browser engines, embedding, and human–agent control

Research date: 2026-10-01. This is an engine and source-reading survey for Bow Shock, not a dependency decision or implementation plan. Origins and acquisition candidates are in [engine-sources.json](engine-sources.json); final pinned revisions and restoration commands belong to the unified acquisition manifests. Some references are selected source files rather than buildable checkouts. No engines were built and no SDKs were installed for this lane.

Scope update: the operator selected an owned window, macOS first and Linux
second, native DOM observation, and OS input execution. The focused
[native browser study](native-browser-surfaces.md) supersedes the initial
extension-versus-shell prioritization below; extension patterns remain references.

## Findings that change the decision

The strongest starting comparison is **a normal Chromium browser with a bounded extension/native host**, versus **a native CEF shell with browser-side control and in-process CDP**. These give substantially different control over the product, but both can retain a live human browsing surface. The next serious comparison is Qt WebEngine where native Qt integration matters. Electron is a useful shell reference and an accessible experiment platform, but its own security guidance warns about arbitrary untrusted web content and assigns the embedder substantial responsibility. This prioritization is an inference from the interfaces below, not a performance or security measurement.

The key architectural distinction is browser authority. Rendering a page, hosting a browser product, and delegating a task are separate jobs. Chromium's Content layer deliberately excludes several browser features, including extensions, sync, autofill and Safe Browsing. Acquiring an engine does not acquire Chrome's complete product or service integrations. [Chromium Content module](https://chromium.googlesource.com/chromium/src/+/main/content/README.md)

Three version traps deserve explicit attention:

- CEF's historical Alloy **bootstrap** was removed starting in M128. Chrome bootstrap supports both Chrome and Alloy window styles; older runtime descriptions cannot be read as current selection instructions. [CEF architecture](https://github.com/chromiumembedded/cef/blob/master/docs/architecture.md)
- CEF sandbox integration changed in M138. On macOS the sandbox library is dynamically loaded as `libcef_sandbox.dylib`; Windows uses new bootstrap executables. Advice to link the old static sandbox library applies to earlier branches. [CEF sandbox setup](https://github.com/chromiumembedded/cef/blob/master/docs/sandbox_setup.md)
- From Chrome 136, remote-debugging port and pipe switches require a non-default `--user-data-dir` when used with ordinary Chrome. Chrome for Testing is the documented automation exception. This is a Chrome product change; its exact consequences for an embedded build must be checked against that build. [Chrome remote-debugging change](https://developer.chrome.com/blog/remote-debugging-port)

## Comparison for the proposed browser

The judgments in the last column are research prioritization, inferred from cited API ownership and deployment constraints. They are not adoption recommendations.

| Setup | Human browsing surface | Native/agent connection to study | Principal constraint | Research priority |
| --- | --- | --- | --- | --- |
| Chromium extension + native host | Existing full browser UI and profile | Extension permissions, native messaging, optionally debugger transport | Restricted pages/domains; extension lifecycle and deployment; debugger is powerful | Primary baseline for explicit bounded access |
| CEF | Embedder owns native windows and browser instances | Browser-side callbacks, asynchronous renderer bridge, in-process DevTools methods | Host must supply product behavior, process/sandbox integration and runtime updates | Primary custom-browser baseline |
| Chromium Content or fork | Maximum source-level control | ContentBrowserClient, WebContents, Mojo, DevToolsAgentHost | Large update/build burden; engine APIs omit product features | Read deeply; defer fork decision |
| Electron | Host-controlled windows and WebContentsView | Main-process IPC, session hooks, debugger | Node/native powers increase consequence of host mistakes; remote-content warning | Valuable comparison and shell references |
| Qt WebEngine | Native widgets or Qt Quick | QWebEnginePage/Profile, isolated worlds, request and permission hooks | Chromium version/update cadence and Qt distribution choices | Serious native alternative |
| WebView2 | Windows native host | Web messages, host objects, DevTools methods | Windows-specific runtime; Evergreen/Fixed Version servicing | Windows comparison |
| WebKitGTK | GTK application | Script worlds, content manager, policy/permission signals, automation | GTK/Linux integration and separate WebKit automation surface | Independent-engine comparison |
| WPE WebKit + Cog | Embedder-controlled rendering/backend | WPE APIs and platform/backend integration | Embedded-device focus; human desktop shell must be supplied | Useful backend/shell study |
| WKWebView | Cocoa system web view | Navigation delegates, script messages, website data | Apple-specific APIs; different instrumentation availability | macOS comparison requiring further API reading |
| Servo | Embedding API and servoshell | WebView/Servo/delegates, embedder controls | Embedding is evolving; web compatibility must be established | Architecture comparison |
| Ladybird | Independent browser UI | LibWebView and IPC/process layout | README identifies pre-alpha developer use | Study separation, avoid parity assumptions |

Primary sources for the entries: [Chrome Native Messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging), [CEF usage](https://github.com/chromiumembedded/cef/blob/master/docs/general_usage.md), [Electron WebContentsView](https://www.electronjs.org/docs/latest/api/web-contents-view), [Qt overview](https://doc.qt.io/qt-6.10/qtwebengine-overview.html), [WebView2 process model](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model), [WebKitGTK WebView](https://webkitgtk.org/reference/webkit2gtk/stable/class.WebView.html), [WPE overview](https://wpewebkit.org/about/), [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview), [Servo Book](https://book.servo.org/), [Ladybird source README](https://github.com/LadybirdBrowser/ladybird).

## Chromium: the boundary worth understanding

Chromium separates the privileged browser process from renderer processes and additional services. Site Isolation makes the browser process enforce which sites a renderer may represent and what cross-site data it may receive; a tab is not necessarily one renderer. Out-of-process iframes and process changes during navigation make target/frame/document identity a first-class concern. A grant to “the current tab” cannot safely be implemented by retaining a stale renderer pointer or remembered URL. The last sentence is a Bow Shock inference from the process model. [Multi-process architecture](https://www.chromium.org/developers/design-documents/multi-process-architecture/), [Site Isolation design](https://www.chromium.org/developers/design-documents/site-isolation/)

Modern IPC reading should start with Mojo rather than old Chromium IPC explanations. Mojo defines typed interfaces and supports frame/document-scoped binders. Chromium's guidance also addresses sandbox selection and message ordering with navigation. For Bow Shock, this suggests keeping privileged delegation decisions in a broker that survives renderer changes, while invalidating document-scoped operations when their document ends. The broker proposal is an inference. [Mojo and services](https://chromium.googlesource.com/chromium/src/+/main/docs/mojo_and_services.md), [Mojo security style guide](https://chromium.googlesource.com/chromium/src/+/main/docs/security/mojo.md)

The acquired Chromium revision adds a particularly relevant lead beyond the Chrome 136 blog: `remote_debugging_server.cc` contains a feature-gated mode controlled by the `chrome://inspect` remote-debugging preference, where each incoming connection requires user approval. Command-line port/pipe switches take precedence. The HTTP handler accepts approved browser-target connections and rejects others. This is connection consent, not per-task/tab/action authorization: the accepted connection receives a browser DevTools agent. This survey does not establish release availability, default feature state or the complete approval UI/revocation flow. It does establish an upstream implementation worth studying before inventing a similar connection prompt. [Pinned remote-debugging server](https://github.com/chromium/chromium/blob/faee0a28a27e62768c53844d7a29a63d609315dd/chrome/browser/devtools/remote_debugging_server.cc), [Pinned HTTP approval handler](https://github.com/chromium/chromium/blob/faee0a28a27e62768c53844d7a29a63d609315dd/content/browser/devtools/devtools_http_handler.cc)

Selected source targets and the questions they answer:

| Source target | Reading question |
| --- | --- |
| `content/public/browser/web_contents.h`, `web_contents_observer.h` | What identifies a live tab/content instance, and which lifecycle events retire observations? |
| `render_frame_host.h`, `navigation_throttle.h` | What is tied to a frame/document; where can browser-side navigation be deferred or rejected? |
| `browser_context.h`; `content/shell/browser/shell_browser_context.cc` | What belongs to a profile and storage partition rather than a task? |
| `content_browser_client.h`; `shell_content_browser_client.cc` | How does an embedder supply browser policy without modifying renderer internals? |
| `devtools_agent_host.h`; `content/browser/devtools/devtools_agent_host_impl.cc` | How are DevTools clients attached and detached from targets? |
| `chrome/browser/devtools/remote_debugging_server.cc` | Where are debugging access and default-profile restrictions enforced in this revision? |
| `chrome/browser/extensions/api/messaging/native_message_process_host.cc` | How does Chromium launch, frame, terminate and authenticate a native-message host? |
| `docs/security/mojo.md`, `docs/security/compromised-renderers.md` | Which assertions must the browser independently validate against a compromised renderer? |

These are a source-reading agenda, not a claim that every implementation was audited. The public Content README explicitly identifies `WebContentsObserver`, `ContentBrowserClient`, `NavigationThrottle`, `BrowserContext`, and renderer security policy as relevant interfaces. [Content module](https://chromium.googlesource.com/chromium/src/+/main/content/README.md)

## CEF: native shell and local instrumentation

CEF presents C/C++ embedding interfaces and sample applications rather than requiring an embedder to understand every Chromium implementation detail. Its main process usually hosts the application, while Blink/V8 and DOM-facing integration run in renderer processes. `cefsimple` illustrates the minimum browser window; `cefclient` demonstrates a broad set of callbacks; `ceftests` provides API tests. Its docs also cover thread affinity and message-loop integration, which are important for maintaining responsive human input. [CEF general usage](https://github.com/chromiumembedded/cef/blob/master/docs/general_usage.md)

The especially relevant discovery is in `include/cef_browser.h`: `SendDevToolsMessage`, `ExecuteDevToolsMethod`, and `AddDevToolsMessageObserver` do **not** require an active DevTools front end or remote-debugging session. Results and events are asynchronous; submission success is not operation success. The observer registration has its own lifetime. A broker can therefore instrument an embedded browser locally without opening a debugging listener. That design possibility is an inference; CEF does not supply bounded delegation automatically. [CEF browser header](https://github.com/chromiumembedded/cef/blob/master/include/cef_browser.h)

The generic CEF message router is also relevant. It provides query/success/failure/cancel messages across renderer/browser processes, including persistent queries. Browser destruction, navigation and renderer termination can cancel work, but the application must wire the relevant lifecycle callbacks into the router. Treat the router as transport and lifetime machinery; authorization still belongs to the application. [CEF message-router contract](https://github.com/chromiumembedded/cef/blob/master/include/wrapper/cef_message_router.h)

Request contexts deserve careful reading. The header separates identity from shared storage: two distinct request-context objects can share storage. It also documents render-process separation between different contexts and propagation for popups. For Bow Shock, a task identity, a profile/storage identity, and an authorization grant should remain separate concepts. A private/ephemeral profile is not by itself a bounded task grant. [CEF request-context header](https://github.com/chromiumembedded/cef/blob/master/include/cef_request_context.h)

Concrete reading route:

1. `docs/architecture.md` and `docs/sandbox_setup.md`, then current runtime-style enums and `CefBrowserView`/window delegates. Confirm style-specific limitations in headers; the architecture prose includes older historical restrictions.
2. `tests/cefsimple/`, `tests/cefsimple/process_helper_mac.cc`, and `tests/shared/process_helper_mac.cc` for startup/helper ownership.
3. `include/cef_browser.h`, `cef_frame.h`, `cef_frame_handler.h`, `cef_request_context.h`, `cef_permission_handler.h` for browser/frame/context authority.
4. `include/wrapper/cef_message_router.h` and `libcef_dll/wrapper/cef_message_router.cc`, then `tests/ceftests/message_router_*` for cancellation and dispatch.
5. `tests/cefclient/browser/client_handler.cc`, `tests/shared/browser/base_client_handler.*`, and renderer-side shared handlers for actual callback plumbing.
6. `libcef/browser/chrome/` and `libcef/browser/alloy/` for how native callbacks are layered onto Chromium product/content behavior.

Samples must be read critically. The inspected `cefclient` handler continues media permission requests unless its demo configuration disables media handling; it also permits OS execution for `spotify:` URLs. These are explicit sample behaviors, not a sensible default delegation policy for Bow Shock. [CEF sample client handler](https://github.com/chromiumembedded/cef/blob/master/tests/cefclient/browser/client_handler.cc)

## Extension and native-host baseline

Chrome's `activeTab` offers a useful concrete precedent: user invocation grants temporary access to the active tab's main-frame origin; same-origin navigation may retain it, while cross-origin navigation or tab closure revokes it. Restricted browser pages remain inaccessible. Bow Shock can study this before deciding whether it needs broader host access. It is not equivalent to a comprehensive delegation policy. [activeTab permission](https://developer.chrome.com/docs/extensions/develop/concepts/activeTab)

Native Messaging connects an allowlisted extension ID to a separately launched native process over length-prefixed UTF-8 JSON on stdio. The host manifest's `allowed_origins` disallows wildcards. A long-lived `connectNative` port and one-shot `sendNativeMessage` have different host lifetime behavior. This is a plausible connection to an agent broker, but the extension's identity says nothing by itself about which page or task may receive agent powers. [Native Messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)

The debugger extension API supplies another CDP transport, with restricted protocol domains and target/session routing. Frames may be distinct targets or execution contexts depending on their process placement. Current docs also describe enterprise restrictions at debugger attach time. Therefore extension access must be feature-checked and a attach failure must leave manual browsing usable. [Extension debugger API](https://developer.chrome.com/docs/extensions/reference/api/debugger)

Read `GoogleChrome/chrome-extensions-samples` for Manifest V3 service workers, activeTab, side-panel and debugger patterns, and `ChromeDevTools/devtools-protocol` for versioned schema. Distinguish modern examples from archived Manifest V2 examples. CDP is broad instrumentation, not a task-safety contract; future design must separately constrain raw JavaScript, cookie/network access, frame targeting and generated input.

## Electron and Min: practical shell patterns with explicit caveats

Electron's `WebContentsView` places a `webContents` in a native view controlled by the host. `webContents` exposes navigation/window events, script execution and input mechanisms. It is a useful surface for comparing trusted browser chrome with remote page content. [WebContentsView](https://www.electronjs.org/docs/latest/api/web-contents-view), [webContents](https://www.electronjs.org/docs/latest/api/web-contents)

Electron's security guide explicitly warns about arbitrary untrusted content. It calls for disabling Node integration for remote content, using context isolation and process sandboxing, supplying permission handlers, validating IPC senders, and containing exposed Electron/native APIs. It also states that permission requests are automatically approved unless a custom handler is configured. This matters more for a browser than for an application displaying its own trusted interface. [Electron security](https://www.electronjs.org/docs/latest/tutorial/security)

Min gives us a small real browser shell rather than a “Hello, WebView” demonstration. Its inspected `main/permissionManager.js` keeps pending and granted requests, connects both Electron permission handlers, and removes grants on main-frame navigation or destruction. However, its `requestOrigin` is derived from `URL.hostname`, omitting scheme and port; it also reuses grants across tabs. Those behaviors should inform an adversarial review of authority scope rather than be copied. The permission-grant IPC handler also needs analysis in the context of the complete UI sender boundary. [Min permission manager](https://github.com/minbrowser/min/blob/master/main/permissionManager.js)

Study Min's `main/`, `js/` tab/task UI and session restoration together; study Electron's browser context, permission manager and debugger code separately. A usable shell is evidence about interaction and lifecycle patterns, not evidence of a complete arbitrary-web threat model.

## Qt WebEngine and WebView2

Qt WebEngine separates rendering/JavaScript from its GUI process and offers C++ widgets and QML integration. Pages belong to profiles with shared cookies, scripts and settings. Chromium networking is used rather than QtNetwork. The documentation describes a version selected at Qt feature freeze plus security patches from newer Chromium releases, so runtime web-platform version and security patch level are different questions. Unversioned `qt-6` links redirected to a development snapshot during this survey; the report uses 6.10 documentation where possible. [Qt 6.10 overview](https://doc.qt.io/qt-6.10/qtwebengine-overview.html)

Read `QWebEngineProfile` for storage and permission persistence, `QWebEnginePage` for lifecycle and script worlds, `QWebEngineScript` for injection, and request-interceptor APIs for network hooks. Current development headers deprecate older page permission methods in favor of `QWebEnginePermission`; do not infer release availability from `dev`. Qt's `simplebrowser` and `permissionbrowser` examples are concrete human-browser references. [Profile API](https://doc.qt.io/qt-6.10/qwebengineprofile.html), [Page API](https://doc.qt.io/qt-6.10/qwebenginepage.html), [Qt source page header](https://github.com/qt/qtwebengine/blob/dev/src/core/api/qwebenginepage.h)

WebView2 is a Windows comparison with a native host, browser-like process collection, and user-data-folder ownership. Microsoft specifically recommends origin checks before sending privileged data, validating web messages, avoiding generic proxies, restricting unnecessary host objects, and removing exposed objects across navigation. A previously trusted WebView may have navigated while a request was outstanding; that race is directly relevant to tandem browsing. [WebView2 security](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/security), [Process model](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model)

Evergreen shares an automatically updated runtime; Fixed Version makes the application responsible for bundled updates. A continuously running Evergreen application can retain an older runtime until restart/environment recreation. The update mechanism is part of a browser's practical security boundary. [Runtime distribution](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution)

Read `WebView2Samples/SampleApps/WebView2APISample/ScriptComponent.cpp`, permission scenarios, process-management scenarios and the WPF browser. The inspected ScriptComponent intentionally demonstrates `AddHostObjectToScript`; it should be compared with Microsoft's security restrictions rather than taken as an authority design.

## Independent WebKit and programmable-browser references

WebKitGTK's WebView supports asynchronous JavaScript evaluation in named worlds, snapshots, policy decisions, permission requests, process-termination signals, and automation-related state. Its UserContentManager registers page-to-host script-message handlers, including world-specific variants. These are relevant native control points, but must be compared carefully with Chromium/CDP functionality. The `stable` API pages served API 4.1 / library 2.42.5 during this survey, so they are not evidence of the newest available release. [WebView](https://webkitgtk.org/reference/webkit2gtk/stable/class.WebView.html), [UserContentManager](https://webkitgtk.org/reference/webkit2gtk/stable/class.UserContentManager.html)

WPE is an embedded WebKit port with a strong platform/backend focus. Cog is a compact launcher/shell reference. Read `core/cog-shell.c`, platform modules and MiniBrowser before deciding how much desktop browser behavior would need to be supplied. [WPE](https://wpewebkit.org/about/), [Cog source](https://github.com/Igalia/cog)

Nyxt is valuable because programmability is part of its human browser interface. Its renderer abstraction and command/mode system provide another way to think about explicit delegation units. The inspected GTK renderer handles permission prompts and installs user scripts with frame selection, injection timing, URL allow/block lists and optional named worlds. This suggests studying a human-visible command layer above rendering, while keeping privileges independent of customizable scripts. That suggestion is an inference. [Nyxt](https://github.com/atlas-engineer/nyxt), [GTK renderer](https://github.com/atlas-engineer/nyxt/blob/master/source/renderer/gtk.lisp)

WKWebView is a separate Apple-platform branch. Apple documentation was only partially readable through the web tool, so its detailed automation and isolated-world capabilities remain a targeted follow-up. The selected WebKit Cocoa header is a useful primary source. Do not claim GTK/WPE and Cocoa have identical bridge or automation APIs. [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview), [Cocoa header](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKWebView.h)

## Servo and Ladybird: source studies beyond mainstream engines

Servo's current Book says work on consumable webview embedding is ongoing, recommends servoshell for running the engine, and points to embedding projects. Its actual `components/servo/webview.rs` already makes a useful study: loading, custom requests, history, input handling, accessibility updates and an embedder delegate are explicit methods with asynchronous notifications. New embedding interfaces must be read in the pinned revision. [Servo Book](https://book.servo.org/), [Servo WebView](https://github.com/servo/servo/blob/main/components/servo/webview.rs)

Read `components/servo/webview_delegate.rs`, `components/shared/embedder/`, `components/constellation/`, C embedding interfaces and WebView tests. The investigation is how the embedder owns input/lifecycle decisions, not whether a smaller engine automatically makes automation safe. Compatibility, sandboxing, accessibility, credentials and update handling would each need independent evidence before consideration for normal browsing.

Ladybird's current README identifies pre-alpha developer use and describes separate UI, WebContent, image-decoder and network processes. Its IPC definitions and LibWebView are worthwhile architecture references. It should not be treated as a drop-in mainstream browser replacement based on an aspirational roadmap. [Ladybird README](https://github.com/LadybirdBrowser/ladybird)

## Questions to answer before a product plan

These are Bow Shock research questions inferred from the interfaces; existing engines do not settle them for us.

1. Does delegation authorize observation, navigation, typing, form submission, downloads and native protocol invocation independently?
2. What identifies the exact live target: browser instance, frame, document/navigation epoch, origin, profile and task?
3. Can the human always pause/revoke agent input while manually continuing to browse? What happens to already queued input and dispatched effects?
4. Which bridge endpoints are available only to trusted browser UI, and what hostile page claims must the broker ignore?
5. How do grants end on redirect, popup, same-document change, cross-origin navigation, renderer replacement, crash, reconnect and agent restart?
6. Which data leaves the browser: rendered text, DOM, accessibility tree, screenshots, network bodies, cookies or local files? How are hidden fields and cross-origin frames handled?
7. Is ordinary manual browsing preserved when debugger attach, agent authentication or runtime API availability fails?
8. What browser-product capabilities are indispensable: profiles, password manager, Safe Browsing, extensions, downloads, accessibility, media, device dialogs and restore?
9. What is the servicing strategy, including long-running sessions and extension/native-host version skew?
10. Which sources give a direct oracle for these claims? Start with CEF router/permission tests, Chromium navigation/security tests and native sample lifecycles; then derive Bow Shock-specific oracles once there is a spec.

## Scope and next reading

This survey inspected primary docs plus targeted code excerpts from CEF headers/client callbacks, Min permission management, Nyxt GTK integration, Servo WebView, Qt page headers and WebView2 ScriptComponent. It did not benchmark engines, audit all shells, validate sites, or decide a dependency. Selected source paths are reading targets and may move; the acquisition utility must record missing paths explicitly rather than silently invent replacements.

Initial source acquisition exposed moved files in three large-engine subsets. Verified replacement paths against the unified pinned revisions: WebKit's GTK-facing WebView/WebContext implementation is under `API/glib`; Servo's shell targets are `ports/servoshell/running_app_state.rs` and `ports/servoshell/window.rs`, with its delegate in `components/servo/webview_delegate.rs`; Ladybird's relevant documents are `Documentation/ProcessArchitecture.md` and `Documentation/BuildInstructionsLadybird.md`. The acquisition catalog now names those existing files. Chromium's acquired remote-debugging and HTTP-handler implementations were also read for the connection-approval lead above.

Next useful work is a side-by-side authority/lifecycle study of (a) Chromium extension + native host and (b) CEF local DevTools + native shell, using the same manual-interruption and navigation scenarios. Document the available hooks and gaps before specifying Bow Shock. Qt, WebKit and WebView2 provide independent comparisons; Min and Nyxt provide concrete human-browser interaction references. Full Chromium/CEF binary builds, complete Chromium/WebKit dependency trees and Apple documentation requiring a local SDK are separate acquisition tasks, not hidden prerequisites of this source survey.
