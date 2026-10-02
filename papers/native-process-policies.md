# Matched macOS helper policies and process identity

2026-10-02. Independent BLACKBIRD research for native N1. This is a study of
the actual adopted CEF/macOS arm64 tuple, not a general Chromium sandbox
certificate. Runtime acquisition remains in
[the runtime manifest](../runtime/cef-macos-arm64.json); exact selected-source
origins, preserved HTTP responses, hashes and restoration instructions are in
[the matched-source manifest](native-matched-source-manifest.json). These
snapshots are reference material only. The earlier
[construction review](native-shell-code-review.md) covers original shell code.

## Result and actual scope

The original apparent GPU and utility escapes have different explanations.
The GPU policy intentionally permits the per-user Darwin temporary directory.
The utility was the macOS notification provider, explicitly assigned no sandbox
by upstream. The second, project-local sentinel and actual service metadata
now distinguish those cases. No tested sandboxed helper could open the project
sentinel. This establishes the tested bootstrap boundary for observed roles;
it does not establish universal confinement or coverage of every service.

The `process_requirement.cc` diagnostic is a separate signing-data problem.
An owned Foundation/Security test reproduces `-67030` when cached Info.plist
data is serialized differently from the bytes signed on disk. Canonicalizing
the test app's plist before signing removes that error. This packaging result
does not create a meaningful trusted signing identity for an ad-hoc build, and
does not establish a cause for the earlier teardown watchdog failure.

The matched CEF revision is
`682c378d70d5780061e96644dca16ddd8fd157a9`. The framework's own Info.plist reports
Chromium SCM revision `a654841425914cbb703a2931e07b70a83aedbafd`, branch-heads/8037
position1294, matching version154.0.8037.58. The study uses that framework
revision, rather than the repository's older general research Chromium pin.

## Where the macOS policy takes effect

The browser launcher selects the sandbox type from the child command line.
For sandboxed roles it combines the common profile with a role suffix, injects
canonical path parameters, serializes the policy, gives the child a policy-pipe
descriptor and appends `--seatbelt-client=<fd>`. It sends the serialized policy
after launching the child. Unsandboxed types bypass this policy delivery.
The process requirement is a separate launch option.
([launcher](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/content/browser/child_process_launcher_helper_mac.cc),
[profile selection](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/sandbox/policy/mac/sandbox_mac.mm),
[parameters](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/content/browser/sandbox_parameters_mac.mm))

CEF's helper entrypoint initializes the sandbox before loading the framework.
`cef_sandbox_initialize` creates a Seatbelt server from the arguments and,
when the client argument makes a sandbox required, reads and applies the
serialized policy. Failure then returns null, causing our helper to exit.
Without that argument CEF can return a non-null context without applying a
policy. A successful `CefScopedSandboxContext::Initialize` alone therefore
cannot certify confinement.
([CEF entrypoint](https://github.com/chromiumembedded/cef/blob/682c378d70d5780061e96644dca16ddd8fd157a9/libcef_dll/sandbox/sandbox_mac.mm),
[Seatbelt execution](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/sandbox/mac/seatbelt_exec.cc))

On macOS the later GPU `EnsureSandboxInitialized` path queries
`Seatbelt::IsSandboxed`; it does not install a deferred GPU policy. That query
uses the OS `sandbox_check` status operation. The source and direct file-access
oracle therefore resolve the bootstrap phase without assuming Linux's or
Windows' GPU startup sequence applies to macOS.
([GPU main](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/content/gpu/gpu_main.cc),
[status query](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/sandbox/mac/seatbelt.cc))

## Observed roles and policy meaning

The native owned-fixture smoke at this study's observation time passed with
the following direct `open(O_RDONLY | O_CLOEXEC)` results after helper sandbox
initialization and before framework loading. Both marker files existed and were
readable by the test parent. The first lived in a Python temporary directory
under the Darwin user temporary tree; the second lived in the project outside
the profile, app bundle and Darwin temporary/cache trees. No marker contents or
paths were disclosed by the helper. All helpers had uid/euid501. The current
ignored smoke log is `context/runtime/native-smoke.log`; later runs may replace
it. This table records the observations rather than relying on a mutable log.

| Observed role | Service sandbox | Seatbelt client argument | Darwin temp marker | Project marker |
| --- | --- | --- | --- | --- |
| Three renderers | renderer role | present | denied, EPERM | denied, EPERM |
| GPU | GPU role | present | opened | denied, EPERM |
| `network.mojom.NetworkService` | network | present | denied, EPERM | denied, EPERM |
| `storage.mojom.StorageService` | service | present | denied, EPERM | denied, EPERM |
| Two `unzip.mojom.Unzipper` instances | service | present | denied, EPERM | denied, EPERM |
| `mac_notifications.mojom.MacNotificationProvider` | none | absent | opened | opened |

The common policy defaults to denial but permits bundle/executable reads,
system resources, metadata and selected IPC. Runtime sandbox extensions can
convey additional access. A helper is not confined to the browser profile alone.
The service/utility suffix adds no extra resource rules on macOS.
([common policy](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/sandbox/policy/mac/common.sb),
[utility policy](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/sandbox/policy/mac/utility.sb))

GPU policy permits reads and selected writes throughout the Darwin user cache,
user directory and temporary directory. It also permits graphics-related
Mach/IOKit operations and grants Metal compiler read-extension issuance. The
first marker was consequently an allowed-path probe, not a valid negative GPU
test. Its successful open is consistent with a sandboxed GPU; the project
marker supplies the negative boundary actually observed.
([GPU policy](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/sandbox/policy/mac/gpu.sb))

Network policy permits its injected storage directories, certificate/keychain
and DNS resources, and TCP/UDP networking. Darwin temporary/cache access is
conditional on a parameter whose `kMacSandboxNetworkUserDirAccess` feature is
disabled by default at this revision. These necessary network and storage
permissions are not Bow Shock effect grants. The actual two-file denial does
not mean that all filesystem paths or all traffic are blocked.
([network policy](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/sandbox/policy/mac/network.sb),
[parameter defaults](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/content/browser/sandbox_parameters_mac.mm))

### The notification exception

The provider's Mojom explicitly declares `ServiceSandbox=kNoSandbox`, and the
service-launch template derives its sandbox type from that interface metadata.
The factory launches an alert provider as a UI utility process; banner
notifications use an in-process provider. Separate helper presentation supports
macOS notification alert styles. This is upstream service design, not a
failed Seatbelt initialization or an unidentified generic utility escape.
([interface](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/services/mac_notifications/public/mojom/mac_notifications.mojom),
[factory](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/browser/notifications/mac/mac_notification_provider_factory.cc),
[service launch](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/content/public/browser/service_process_host.h))

The browser owns the Mojo receiver/remote setup. The exposed service operations
display, enumerate and close notifications, ask whether the service can exit,
and return notification-action callbacks. They do not offer generic file reads
or an agent command channel. Web notification requests pass through browser
permission checks, including opaque-origin denial and document/worker origin
permission lookup, before display. Service creation is not evidence that a
page received notification permission. We did not request OS or site
notification permissions or exercise notification delivery in this study.
([provider binding](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/services/mac_notifications/mac_notification_provider_impl.mm),
[browser permission checks](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/content/browser/notifications/blink_notification_service_impl.cc))

Those interface limits do not turn the helper into an OS sandbox. A compromised
notification process retains ordinary same-user filesystem access. Bow Shock
must describe its native boundary as role-specific and exclude credentials,
models and agent authority from this service. This study recommends retaining
normal engine behavior for the owned POC, documenting the exception, and
reviewing it when general browsing policy is designed. It does not recommend
silently disabling notifications to make every row say denied.

## What the identity diagnostic does

The exact log originates in `FallbackValidationCategoryOfCurrentProcess`.
Its only caller in this matched unit is `ProcessRequirement::GatherMetrics`:
the fallback result feeds metrics and branding crash keys. The default-enabled
metrics task is BEST_EFFORT, MayBlock and CONTINUE_ON_SHUTDOWN. It is separate
from `SignedWithSameIdentity` construction, which reads team identity and
validation category through kernel `csops`. The diagnostic alone cannot prove
a helper launch, sandbox, or authenticated IPC failure.
([process requirements](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/base/mac/process_requirement.cc))

The fallback obtains a dynamic Security code object using the current process
and cached outer-bundle Info.plist. Chromium copies the NSBundle dictionary,
removes Foundation's inserted `CFBundleNumericVersion`, and serializes it as
XML. These bytes are passed as `kSecGuestAttributeDynamicCodeInfoPlist`; basic
signature validation subsequently fails with `-67030` when they differ from
the signed plist bytes. Static on-disk verification can succeed at the same
time because it validates the original signed bytes.
([cached plist](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/base/mac/info_plist_data.mm),
[Security guest attributes](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/base/mac/code_signature.cc))

The direct ignored experiment compiled original Foundation/Security code as
`context/review-native-shell/identity_probe.mm` into an owned `Probe.app`. It
used the product-style generated plist with the executable/name changed to
Probe, ad-hoc signed it, and called the same Security guest lookup and basic
validation with either raw or cached serialized bytes. It did not launch or
modify the product app, reference source or any unrelated process.

| Owned app condition | Strict static verify | Dynamic raw plist | Dynamic cached XML |
| --- | --- | --- | --- |
| Generated inline-key plist,665 bytes; XML694 bytes | passes | lookup0/basic0 | lookup0/basic-67030 |
| Same dictionary written as Foundation XML694 bytes before signing | passes | lookup0/basic0 | lookup0/basic0 |

This is a direct red/green packaging mechanism. The proposed product correction
is to serialize generated **own app/helper** plists using the same Foundation
XML format before signing, then retain strict verification and run the actual
native fixture to check the diagnostic. Do not rewrite the acquired framework's
plist, suppress the log, disable metrics, or relax process requirements.
The native owner then converted generated own app/helper plists with
`plutil -convert xml1` before signing. Actual product runs retained strict bundle
verification, persistent-profile checks and all shutdown-stage completions
without the -67030 diagnostic. The clock-red run failed only its newly required
missing clock-start record, after its diagnostic/profile assertions passed;
three subsequent owned N2 fixture runs also had no -67030. This closes the
observed dynamic plist diagnostic at this scope; ad-hoc identity remains below.

Ad-hoc signing is still not a trusted peer identity. The matched builder treats
missing team identity in ad-hoc code as expected. For validation category None,
`RequiresSignatureValidation` is false and `ValidateProcess` returns true; the
source explains that an ad-hoc signature can be created by anyone. There is no
claim here that this build authenticates same-user peers by certificate.
([requirement semantics](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/base/mac/process_requirement.cc))

Mach rendezvous identifies launched clients by the OS audit-token PID and
registered per-child port entries. At this revision requirement validation is
enabled by default but enforcement is disabled by default. Network utility
same-identity requirement construction is itself controlled by
`kValidateNetworkServiceProcessIdentity`, disabled by default; other utility
roles return no requirement there. These are source defaults, not a probe of
the final effective feature list. Owned launch handles and OS port transport
remain useful boundaries, but trusted distribution identity is a future
Developer ID/signing-policy decision.
([rendezvous](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/base/apple/mach_port_rendezvous_mac.cc),
[utility requirements](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/content/browser/service_host/utility_sandbox_delegate.cc),
[network identity feature](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/content/common/features.cc))

## Minimal remaining native observations

1. Retain the two owned markers and exact role/subtype/service-sandbox metadata.
   Require project-marker denial for the observed sandboxed roles; explicitly
   expect GPU temporary access and the notification exception. Require expected
   roles to actually appear. Keep exact owned helper/controller teardown checks.
2. Apply and test the plist packaging correction above. A successful strict
   static check alone was insufficient to catch the dynamic cached-plist error.
3. If a confinement status bit is needed, the existing Chromium `sandbox_check`
   status operation can be queried natively without permissions or policy
   changes. Label it a status bit, not evidence for every protected operation.

No generic public CEF callback establishes a fully initialized GPU or utility
service point. `OnBeforeCommandLineProcessing` occurs after framework loading
but before child main initialization; `OnRenderThreadCreated` is renderer-only.
A timer is not an initialization oracle. Since this macOS policy is applied
before loading CEF, the current direct bootstrap probe is meaningful at its
stated phase. Later service initialization and sandbox-extension access need
separate, targeted observations if future features depend on them.
([CEF app callback](https://github.com/chromiumembedded/cef/blob/682c378d70d5780061e96644dca16ddd8fd157a9/include/cef_app.h),
[CEF main delegate](https://github.com/chromiumembedded/cef/blob/682c378d70d5780061e96644dca16ddd8fd157a9/libcef/common/chrome/chrome_main_delegate_cef.cc),
[renderer callback](https://github.com/chromiumembedded/cef/blob/682c378d70d5780061e96644dca16ddd8fd157a9/include/cef_render_process_handler.h))

Not observed: audio/printing/proxy/model/translation and other unlaunched roles,
later dynamic extensions, notification permission/delivery, every filesystem
operation, network isolation, adversarial peer authentication, and arbitrary
sites. The subsequent full native-shell smoke now directly asserts GPU temporary
access/project denial, present network/storage correct service-policy/project
denial, the present notification none/no-client/project-access exception,
renderer denial, diagnostic absence, persistent profile and exact owned PID
teardown. It also checks the native clock's boot UUID against the external OS
and increasing nanoseconds. These close the stated minimal observed-role and
diagnostic regression oracles, without broadening their confinement claims.

One earlier teardown-watchdog exit2 remains unresolved and must remain
in the journal despite subsequent clean fixture shutdowns. This unit neither
proves causality nor closes the full N1 servicing/fault gates or N2 observation.
