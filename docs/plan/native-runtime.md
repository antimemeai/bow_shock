# Native runtime and input implementation lane

Implementation proposal, 2026-10-01. This lane implements the reviewed
[native observation](../design/runtime-observation.md) and
[input contract](../design/control-and-input.md), in the order below. It does
not select a shipped engine, download a runtime, request macOS permissions,
inject input or adopt a dependency. The integrated plan owns phase entry and
dependency discussion. The initial useful result is a person-operated native
window with a local, scoped rendered-page reader; delegation is a later,
separately earned capability.

## Minimal boundary

Use one original Objective-C++ AppKit/CEF application for the window and C++
engine adapter. Use an owned Rust child process for authority, observation
processing and the subsequent evidence services. Exchange bounded framed
messages over inherited private pipes; do not introduce a general CEF Rust
binding or Swift bridge to prove startup. The shell owns AppKit and CEF UI-thread
lifetime, the Rust host owns serialized admission, and a later small native
input helper owns permission-sensitive OS delivery and independent stop/liveness.
These are proposed implementation choices, not adopted packages.

The first app has one content surface and native session/Stop controls. It
does not require tabs, a custom address-bar automation surface or the whole
side-panel layout. Human URL entry and ordinary browser interaction are
available. Native dialogs/popups are distinct surfaces without delegated
authority. Normal browser permission decisions remain human decisions; sample
permission/external-protocol permissiveness is never copied. Keep engine
isolation and defaults, and expose no remote debugging listener or model-facing
CDP relay. Source interfaces and CEF's examples guide integration; quarantine
source is not copied into the product.

## N0 — Read-only host preflight and proposed distribution

The planning preflight found macOS **26.6**, build **25G72**, **arm64**, Xcode
**26.2** build **17C52**, Apple Clang **17.0.0**, macOS SDK **26.2**, CMake
**4.3.0**, Rust/Cargo **1.94.1**, and **306 GiB** available on the workspace
volume. These are observations of this host, not a support matrix or a successful
build. Version probes and SDK-header reads changed no configuration.

The [CEF automated-build index](https://cef-builds.spotifycdn.com/index.json)
read during planning offered this matching macOS-arm64 stable candidate:

| Item | Proposed value |
| --- | --- |
| CEF | `154.0.32+g682c378+chromium-154.0.8037.58` |
| Chromium | `154.0.8037.58` |
| Archive | `cef_binary_154.0.32+g682c378+chromium-154.0.8037.58_macosarm64.tar.bz2` |
| Type/size | Standard distribution; 307,024,202 bytes |
| Index publication | 2026-09-29 04:18:14.274 UTC |
| Publisher index SHA-1 | `8147f08ca0a65b21227962c7273fcb3ef7174cae` |
| Index sandbox compatibility | `265fca9293e6b6ef` |

The [distribution page](https://cef-builds.spotifycdn.com/index.html) is the
publisher-linked acquisition entry. No archive was downloaded. The choice is
the standard distribution so the first integration uses its matching headers,
wrapper/build files and resources; a minimal package is an optimization after
those contents are inspected. This proposal must be rechecked at adoption for
availability and newer security fixes. A different version is a deliberate
replacement tuple, never a floating `latest` download.

After dependency discussion, the acquisition task records the exact URL,
origin, publication, size, publisher digest and local SHA-256 in a tracked
runtime acquisition manifest, preserving the untouched archive outside tracked
source. An index SHA-1 is an integrity comparison with that index, not an
independent authenticity guarantee. Inspect archive paths before extraction,
and preserve publisher notices when packaging an adopted runtime. Obtain full
CEF revision, shipped API range/hash, minimum deployment target and wrapper
configuration from the actual distribution. Obtain the matching Chromium
DevTools schema from that Chromium revision or candidate runtime. The three
existing quarantine pins are independent study pins and supply none of these
matching guarantees.

Choose an explicit supported stable `CEF_API_VERSION` providing the needed
interfaces; compile adapter and distribution wrapper with the same setting.
Do not let the default experimental API become an accidental choice. If an
essential interface requires experimental API, record and discuss that narrow
requirement, then bind the whole adapter to the exact binary until recompiled.
CEF distinguishes ABI compatibility from behavior; even a stable API update
must rerun the native conformance scenarios. [CEF API versioning](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/docs/api_versioning.md).

**Exit:** adoption discussion has named a concrete distribution and build
boundary; matching headers/resources/API configuration are known. An unavailable
candidate, incompatible SDK or missing necessary interface stops this lane for
a revised candidate. It does not trigger an installer, full Chromium build or
sandbox-off fallback.

## N1 — Build, package, lifecycle and servicing

1. Inspect the adopted distribution's build instructions and macOS bundle
   layout. Build the original shell against its wrapper, using CMake and Clang;
   do not build the entire quarantine or run its samples as product code.
2. Package the complete matching framework/resources, sandbox library and
   process-type helper bundles. Load CEF dynamically in the browser process.
   In helper `main`, initialize the sandbox **before** loading CEF. Current
   CEF uses `libcef_sandbox.dylib` from M138 onward; old static-link instructions
   are not a substitute. Inspect the candidate's actual signing/entitlement
   requirements before building the local bundle, and before any distributed
   signing/notarization step. [Current sandbox requirements](https://github.com/chromiumembedded/cef/blob/master/docs/sandbox_setup.md),
   [pinned loader](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/wrapper/cef_library_loader.h),
   [pinned helper](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/tests/cefsimple/process_helper_mac.cc).
3. Establish Chrome bootstrap/Chrome-style windowed content, engine-managed
   subprocesses, isolated dedicated profile directory and one owned window.
   Wire `CefAppProtocol`, event-loop integration and browser-close callbacks
   before introducing worker services. AppKit quit returns through the CEF
   lifecycle; it does not exit directly with browsers alive.
   [Architecture](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/docs/architecture.md),
   [macOS event-loop study](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/tests/cefsimple/cefsimple_mac.mm).
4. On owned local fixtures, test open/load/back/close, renderer termination,
   helper death and host disconnect. Read actual process types and the OS
   sandbox status/denials available for each role; an `Initialize` success or
   absent `--no-sandbox` flag alone does not demonstrate confinement. If those
   observations cannot settle a role's confinement, keep it unverified and
   resolve a candidate-specific native oracle before browsing untrusted sites.
5. Treat servicing as part of viability: initially rebuild and replace the
   complete versioned app bundle after all browser/helpers exit. Keep profiles
   outside the bundle. Test one matched older-to-newer supported candidate
   transition on a disposable profile, with rollback only to a compatible
   profile copy. Do not mix old helpers/new frameworks or promise rollback of
   Chromium profile migrations. A production automatic updater is separate
   work; do not imply CEF's Windows installer implements macOS servicing.

**Exit:** actual owned window, correct process lifecycle, sandbox status settled
for the required roles and a viable whole-bundle servicing procedure. If native
Chrome-style embedding prevents the required content/controls boundary, study
its supported native host surface; do not silently change runtime style.
If CEF remains unsuitable, return a measured reason and plan a Qt WebEngine
comparison before dependency substitution.

## N2 — Native reader, identity and projection

Implement a fixed operation table first: frame/target metadata, lifecycle
subscriptions, minimal native DOMSnapshot, AX reads and target geometry reads.
Construct all protocol envelopes in the native broker. Copy bounded callback
bytes while valid and parse them off the CEF UI thread. Route child-target
requests through broker-owned raw envelopes preserving `sessionId`; CEF's
typed result/event callbacks alone cannot identify the child session.
[Controller study](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/libcef/browser/devtools/devtools_controller.cc),
[observer contract](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/cef_devtools_message_observer.h).

One component owns target attachment and the complete freshness tuple: host
run, surface, attachment, document, BFCache activation and native node-reference
generation. Emit effective origins from native engine metadata, never from
page strings or URL alone. One capture plus one coalesced refresh is permitted
per browser; bounded child fan-out belongs to that capture. Model export is
not needed to measure this reader.

Use a small controlled fixture family served from different local origins:
ordinary DOM/text/AX; hidden/offscreen/occluded content; shadow/generated/canvas
content; same-origin and cross-origin OOPIF children; inherited and sandboxed
opaque frames; redirects; frame removal; node replacement; BFCache activation.
Fixture source and server-known configuration supply the expected records and
coverage, while the visible native window checks presentation. Ordinary page
JavaScript may instrument the **fixture oracle**; it is not the product reader.
Assert explicit expected fields/coverage and the absence of stale actionable
references. Never compare two copies of our normalized output as the oracle.

Sensitive projections precede consumer wiring. Fixture password/payment values,
header/form markers, echoes in text/ARIA/URLs and denied frame content check the
actual published payload. Unsupported pixel/semantic exclusions yield withheld
modality or unknown sensitivity, following the design's reviewed projection
policy. Full raw snapshots are not the default persisted output.

**Exit:** fixture/development native reader works with typed complete/partial/withheld results,
origin provenance and lifecycle invalidation. Missing OOPIF routing or uncertain
origin/frame mapping leaves those frame operations unavailable; no JS extractor,
site-isolation relaxation or URL-inferred origin fills the gap.
General human observation waits for N3's native capture-work gate; correctness
on these small fixtures does not promote an operational reader.

## N2a — Independent control owner before overload testing

Construct a control-only native helper with its own IPC/continuous expiry and
Stop/liveness processing before N3. It can acknowledge cancellation/fences and
report liveness without posting/listening to OS input. Agree minimal host-run/
generation/control records with A1/A2; it does not wait for the DB subsystem or
confer an input capability. The receiving fixture can also be built now.
Native helper actuation and its permission checks remain N4, after minimal A2
authority and the native reader/coordinate gates.

## N3 — Native work and coordinate gates

N2 initially exposes only the fixture/development reader. Two independent
fault classes have different enablement boundaries: capture work gates any
general human full/partial reader; current coordinates gate delegated input.
No P3 production observation mode enables before its native capture-work gate:

| Claim | Task and direct oracle | Failure branch |
| --- | --- | --- |
| Bounded operational capture | Grow actual fixture trees/text and OOPIF count until configured capture limits or responsiveness limits fail. Measure native callback/UI latency, worker memory and human Stop handling, with the independent helper channel active. Keep a single unresolved capture; host timeout is not native cancellation. | Disable full snapshots when they cannot meet the recorded supported workload. A partial reader needs its own verified fixture oracle; host discard never becomes a renderer-work bound. |
| Correct current screen target | Compare native target quad/hit-test with known fixture targets and actual receiver coordinates under zoom, backing scale, scrolling, nested frames, overlay, window movement/resize and display change. Revalidate immediately before native down and invalidate after relevant changes. | Disable input for unsupported transformations/displays or unresolved hit target. An old DOM rectangle never becomes a click coordinate. |

Record the supported workload/display assumptions and measured limits in the
runtime capability record used by the UI. For the first native spike, review
an operational target of Stop processing within 100 ms under the supported
capture workload. This is a chosen usability target, not a literature-derived
guarantee. Failing it revises the mode or capability; it does not motivate
unbounded retries. Offscreen/hidden/occluded semantic states remain different.

## N4 — Native input feasibility, before a model drives a task

Extend the N2a control-only helper with OS primitives only after N1–N3 and minimal
A2 authority admission are available. No actual posting occurs in the earlier
P1/control-only stage. Start with a hand-authored bounded intent against owned fixtures;
no model, live account, credential/payment task or environment intervention is
required to decide OS delivery viability.

1. Use separate non-prompting checks for posting, event listening and any
   required Accessibility access. Surface missing capabilities; the runtime
   setup may ask the person for the necessary OS permission after its purpose
   and scope are concrete. Do not infer success from a prompt invocation.
   [Posting preflight](https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess()),
   [listening preflight](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess()),
   [Accessibility trust](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions).
2. Prefer `CGEventPostToPid` as the candidate application routing path. Test it
   against the **actual CEF window**, native shell controls, a second owned
   native receiver window and an unrelated controlled receiver application.
   It targets a process, not a guaranteed page/window; do not accept documented
   availability as the confinement result. No silent switch to global posting.
   [Quartz process posting](https://developer.apple.com/documentation/coregraphics/cgevent/posttopid(_:)).
3. Measure pointer movement/down/up, line/pixel wheel, literal content typing,
   and the allowed content-focus commands. Combine native receiver events with
   controlled page outcomes: actual focused recipient, event order/buttons,
   coordinates, resulting value, scrolling and click count. `isTrusted` is only
   an observed browser field, not the oracle for human origin or safe routing.
4. Interleave cancellation/physical takeover with move, down, up and wheel
   segments; switch tabs/windows/dialogs; change layouts and Secure Input;
   revoke listening access; kill host/helper after down; suspend/resume the
   machine. Helper leases use continuous time, generation fences and host
   liveness. Receiver events decide what happened; a helper log cannot claim
   that an event it posted was delivered to the intended target.
5. Establish the no-ordinary-enqueue-after-helper-cancel boundary, exception
   for attributed executor-owned releases, recipient behavior and a finite
   already-posted delivery horizon under the recorded supported conditions.
   Begin with a 100 ms receiver-side takeover-horizon usability target and a
   250 ms maximum local liveness lease, then revise from native results before
   enabling any workflow. Do not renew input after helper death by merely
   waiting those times: prior posted-event drain and held-state resolution
   need the candidate-specific receiver/OS reconciliation mechanism. If that
   mechanism cannot establish quiescence, remain `recovery_uncertain` and
   delegation unavailable. Fresh DOM and process termination are insufficient.

**Exit:** each primitive gets its own measured recipient, lease, takeover,
held-state and recovery capability. A successful click does not enable keyboard
entry; failed IME/text routing does not disable a separately valid reader. A
single supported click/scroll workflow is enough to begin integration. Unknown
effects consume the authority reservation and are not automatically repeated.

## N5 — Behavior and site compatibility, after useful native input

Deliver the finite task using calibrated, bounded geometry-aware gesture
generation before claiming statistical human similarity. Then opt-in ordinary
owned-window sessions provide task/device-conditioned motion and wheel features;
exclude private text/key contents and secure fields. Split calibration and
held-out sessions, and compare complete sequences, velocity/corrections,
scroll bursts, successful targets, false takeovers and operator corrections.
Keep wheel and trackpad modes separate until measured. Operator update
2026-10-16: include empirically modeled typing errors and correction sequences;
the earlier blanket exclusion of deliberate typos is superseded. Ground mistaken
keys and timing in real data and preserve all actual page triggers, including
intermediate edits; see [empirical input](empirical-input.md). Stop remains
responsive throughout. [Native-input research and behavioral sources](../../papers/os-input-and-behavior.md).

Run engine-default comparison before any fingerprint overrides: same machine,
network, fixture and comparable Chromium build; CEF without observation, then
CEF observation enabled. Inspect known UA/client-hint/API/network differences,
not just a single detector verdict. Manually inspect selected ordinary sites
for compatibility. Do not deliberately stress, bypass blocks or infer universal
site acceptance. Engine versions, inspector/AX overhead, codecs and Chromium
versus branded-Chrome differences remain explicit context. User-approved
compatibility changes receive their own proposal and direct effect comparison.

## Linux successor

Keep platform-neutral authority and observation records reusable, but do not
delay the first macOS reader for Linux input. The subsequent Linux lane repeats
distribution/sandbox and display-mapping gates on its actual compositor.
Wayland portal/libei routing and takeover are a new capability experiment;
X11 XTEST is a distinct mode. Neither uinput nor global OS injection is an
automatic fallback. See [native-input research](../../papers/os-input-and-behavior.md)
for the pinned reference sources and known monitoring limitations.

## Lane handoff and review

Native tasks are sequenced because each owns one lifecycle/confinement claim.
The authority/evidence lane can develop its state-machine and fixture server
independently after shared records are agreed; it does not need a working CEF
binary to exercise deterministic admission races. At N2 the handoff is a scoped
observation record; at N4 it is a measured capability and execution outcome,
never a raw OS handle. Every implementation unit follows Blackbird's written
sub-plan, direct failing oracle, implementation, green oracle and independent
code review. Repeat checks only for changes or unresolved fault classes; no
test framework exists to certify another framework's output.

The direct native cases above replace unsupported claims with unavailable
capabilities; they do not downgrade the user's requirements. Linux, multi-tab
delegation, production updater and broader gesture classes remain ordered
follow-up work rather than hidden scope in the first native spike.
