# Matched macOS process policy and identity research

Parent delegated one conceptual research unit before general browsing: resolve
the actual role/phase meaning of helper file probes and the ad-hoc process
validation diagnostic. Read BLACKBIRD, the native plan/source, matched CEF
682c378 and framework Chromium a6548414. Wrote the
[subplan](../docs/plan/native-process-policies.md) before further acquisition
and experiments. No product edits, policy relaxation, permission grants,
network changes, unrelated-process actions or new dependency adoption.

[Report](../papers/native-process-policies.md) records the findings and actual
scope. [Manifest](../papers/native-matched-source-manifest.json) preserves exact
revision URLs, original HTTP responses, decoded hashes/sizes and executable
restoration instructions. Included previously acquired teardown source in its
existing hierarchy, re-downloaded original responses and checked exact decoded
equality before preserving them. Selected-source responses are preserved
instead of a new duplicate full source archive; runtime distribution archive
retention/restoration remains governed by its existing runtime manifest.
Failed guessed paths are recorded and distinguished from actual source gaps.

The first GPU marker was under Darwin temporary storage, which GPU policy
explicitly allows. Asked native owner for a second owned project marker plus
subtype/service-sandbox/seatbelt-client and uid/euid metadata. Actual native
smoke then observed both markers denied by network, storage, unzip and three
renderers; GPU temporary access allowed/project denied; notification provider
both allowed with service sandbox none/no client argument. All were uid/euid501.
Every reported owned helper PID and controller PID disappeared after orderly
fixture shutdown. This supports only observed role/phase claims.

Traced notification Mojom's explicit kNoSandbox assignment, alert helper versus
in-process banners, typed notification IPC and browser origin/permission checks.
No generic file API appears in that interface, but a compromised notification
helper has same-user access. Keeping this upstream exception explicit is more
accurate than automatically disabling it to force uniform denial results.

Traced -67030 to fallback validation metrics, separate from kernel-derived
same-identity requirement construction. An original ignored Foundation/Security
probe reproduced the exact byte mismatch in an owned ad-hoc Probe.app. Strict
compilation used `clang++ -std=c++17 -Wall -Wextra -Werror -fobjc-arc`, linking
Foundation and Security. With generated inline-key plist665 bytes, raw dynamic
Security guest validation passed while cached XML694 bytes failed basic
validation -67030; strict on-disk signature verification passed. Writing the
same dictionary as Foundation XML before re-signing made raw and cached guest
checks both pass. Probe source/artifacts are under
`context/review-native-shell/identity_probe.mm` and `identity-format/Probe.app`.
Sent native owner the specific packaging correction and actual app oracle.
Product diagnostic closure belongs to that owner and is not claimed here.

Follow-up actual product result: native owner canonicalized generated own app/
helper plists with plutil XML before signing; actual clock-red run passed
diagnostic/profile assertions and all shutdown stages, failing only a missing
new clock-start marker. Three later actual N2 fixture runs also emitted no
-67030. Recorded this narrow packaging closure in the report. Trusted ad-hoc
authentication and watchdog causality remain unchanged/unproven.

Final full native-shell smoke also passed strengthened direct expected-role
presence/policy assertions, -67030 absence, profile persistence, Stop/controller
and helper PID absence, plus the new native boot UUID/continuous clock oracle.
Observed-role regression enforcement is now implemented by the native owner,
rather than printed metadata alone. Unlaunched roles and broad confinement
qualification remain outside this claim.

Ad-hoc signing still cannot authenticate certificate identity. Exact matched
defaults enable Mach rendezvous requirement validation but disable enforcement,
and disable network-service identity requirement construction. No effective
runtime feature-list authentication claim follows from those source defaults.
No generic CEF fully initialized GPU/utility callback exists; source applies
macOS Seatbelt before CEF load, and the current probe truthfully tests that
bootstrap point. Timers would not improve its initialization claim.

The previous single shutdown-watchdog exit2 remains open. Successful later
shutdowns and a reproducible plist diagnostic do not establish its cause.
The report leaves unlaunched roles, later extension grants, broader filesystem
and network behavior, notification delivery and trusted signing deployment
explicitly unverified. Detsim/mutants remain deferred by operator instruction.
