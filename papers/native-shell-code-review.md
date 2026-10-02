# Native shell code review

2026-10-02. Independent adversarial review of the original native N0/N1 shell,
its private Rust-controller connection, matched CEF distribution acquisition,
packaging, and direct native smoke oracle. Reviewed against
[the written construction sub-plan](../docs/plan/native-shell-spike.md) and
BLACKBIRD. Detsim and mutation work remain deferred by operator direction.

This is a construction review, not approval of observation, tables, model access,
OS-input delegation, HTTP mutation, or external fault injection. None of those
powers is enabled in this unit.

## Findings reported to the integration owner

| ID | Severity | Finding and direct evidence | Required disposition |
| --- | --- | --- | --- |
| NS-1 | High | `readDataOfLength:4096` waits for the requested length or EOF. An owned Foundation executable linked to the actual `BSControllerConnection` rejected a small initialized reply from a child that kept stdout open; the same child exiting immediately made the reply succeed. A live Rust controller necessarily waits for its next command. | Read available bounded bytes with worker-owned raw descriptors/polling; retain finite framing and an actual live-child round-trip oracle. |
| NS-2 | High | Timeout runs on the main queue and calls `closeFile` concurrently with the worker's blocking read. An owned child wrote a valid small reply, ignored SIGTERM, and held stdout open. A main-queue heartbeat due at three seconds did not execute by seven seconds. `terminate` alone also cannot establish finite child exit/reaping. | Keep descriptor shutdown and terminate/kill/reap off the UI queue. Prove the actual UI heartbeat, finite callback completion, and disappearance of the exact owned child for a stalled TERM-ignoring child. |
| NS-3 | Medium | Idle child termination has no handler and no continuous read/EOF watch. Main-window status and Stop availability change only on operation completion, so successful initialization followed by child death leaves the UI reporting connected until another request. | Observe actual idle child death and report a disconnected state on the UI queue without waiting for a new request. Keep manual browsing available. |
| NS-4 | Medium | Reply validation accepts NSNumber coercions: the actual connection accepted an initialized reply containing `version:true` and `stop_generation:0.5`. Foundation's dictionary decoding also loses duplicate-key evidence before the closed-key check. | Enforce the closed wire object and exact unsigned integer lexemes/types, preserving duplicate-key rejection. Directly reject malformed booleans, fractions, duplicates, wrong identity, oversized/unsolicited output, and stale replies. |
| NS-5 | Medium | `CloseAll` iterates `browsers_`, while `OnBeforeClose` erases the same vector. The acquired tuple's `include/cef_browser.h` explicitly permits close completion to be synchronous or asynchronous. | Iterate a retained snapshot so synchronous callbacks cannot invalidate traversal. Handle `CreateBrowser`'s false return without leaving an indefinitely live empty app. |
| NS-6 | Medium | Controller and helper copies occur only in the main application's POST_BUILD commands. A Rust-controller-only change can rebuild the Rust binary without relinking the unchanged native executable; a helper-only change likewise need not relink it. The resulting bundle can retain the prior executable. | Package after all component builds even when the main target is unchanged. Compare the built controller/helper byte identities with their actual bundle counterparts after an incremental run. |
| NS-7 | Medium | The initial native smoke exercises only successful initialization, Stop and shutdown. It does not observe native idle death, stalled child supervision, malformed output, or child reaping. Portable Rust-process tests do not exercise the Objective-C++ adapter. | Add direct actual-class native fault oracles, and observe exact child exit in the full native shutdown smoke. Do not substitute source-text checks or absence of crash. |
| NS-8 | Medium | The first raw-descriptor replacement checked child exit after one read, even if a valid terminal response remained buffered. Rust writes payload/newline separately and can exit immediately after shutdown. Reaping then failing before draining the remaining bytes can reject a successful reply. | Preserve terminal-process ownership while draining the pending response to its complete frame/EOF/deadline; directly test a reply buffered before child exit. |
| NS-9 | Medium | A direct probe with its parent stdin closed failed initialization, while its otherwise identical normal-stdio run succeeded. `pipe` assigned fd0; spawn actions duplicated fd0 onto itself and then closed it. The child received no stdin. | Allocate source pipe descriptors above the standard streams, or handle all collisions correctly; test actual closed-parent-stdio cases. |
| NS-10 | Medium | Strict signature verification exposed broken links after an incremental native relink. The adopted framework-copy macro uses `ln -sf` against existing directory symlinks, creating self-links such as `Versions/A/A`. Independent inspection observed that link and verification failed at the CEF framework. | Remove only the owned staged framework immediately before the adopted macro recopies the pristine distribution. Verify the actual signed bundle after each packaging run and exercise an actual incremental relink. |
| NS-11 | Medium | CEF canonicalized root_cache_path from `/var/...` to `/private/var/...`, while cache_path retained the first spelling, rejected the disk profile and fell back to memory. A direct Foundation probe showed both NSString/NSURL symlink-resolution APIs retained `/var/tmp`; libc `realpath` returned `/private/var/tmp`. | Canonicalize the already-created profile with checked POSIX realpath and derive every CEF path from that native string. Assert actual Default/Preferences and absence of invalid-cache fallback in the native fixture. |

The owned red-probe harness is an ignored local development artifact under
`context/review-native-shell/Probe.app/`. It links the real connection class;
its child supplies controlled stdio and lifetime behavior. The probes do not
start CEF or touch another application's processes. Cleanup targets only probe
processes. The integration owner received the precise red outcomes before fixes.

## Source-grounded boundaries

The runtime manifest pins the original publisher archive, SHA-1 metadata, local
SHA-256, CEF/Chromium version and stable API. Acquisition checks archive integrity
before extraction, checks each member's top-level distribution root, rejects
traversal/device/FIFO/nested Git members, and uses Python's data extraction
filter. This review found no release blocker in the pinned acquisition path.
The archive and extracted code are kept in ignored runtime storage.

The app uses its adopted distribution's wrapper/build macros, `api_version=15400`,
Chrome-style browser window, AppKit `CefAppProtocol`, sandbox initialization
before helper library loading, and full framework copying. This legitimately
adopts the explicitly discussed distribution's support code; it does not copy
quarantined example application source. No deliberate certificate, site-isolation
or sandbox relaxation is present in the reviewed original code. Runtime loading
and sandbox behavior still require the actual app oracle.

The initial helper file probe directly attempts opening an owned, nonsecret file
outside the selected profile after sandbox initialization. The smoke requires
renderer-role denial only. A GPU or utility helper's different result does not
prove its wider policy, and renderer denial for this one operation does not
certify every renderer privilege. Preserve per-role results and unknown scopes.

Pipe endpoints are explicitly marked close-on-exec before child startup; only
the Rust child's assigned stdio receives the private channels. The child has a
small replacement environment. No model/executor credentials or general agent
protocol are passed here. Future renderer-channel and provider isolation require
their own later gates.

## Recheck status

NS-1–NS-4, NS-7–NS-9 are resolved. The independent actual-class suite passed
11 test methods in 61.494 seconds, including six malformed-response subcases.
A focused rerun of the corrected buffered-exit oracle passed in 5.040 seconds.
The final strengthened deadline oracle passed independently in 5.238 seconds: it
requires failure/disconnection before the probe's late manual invalidation,
which previously could mask a missing deadline. The windowless CLI probe holds
a test-only NSProcessInfo activity to prevent App Nap from coalescing its
fixture timers; no production browser behavior is changed.
The latter observes the exact owned child in zombie state and probe parent
stopped before resuming it. It tests an already buffered terminal response;
it does not reproduce the narrow partial-read/exit race. The source's refusal
to reap while a response remains pending resolves that race.

The revised connection owns spawn, nonblocking descriptors, bounded polling,
continuous request deadlines and process reconciliation on one worker. UI
invalidation changes flags only. Disconnect notification precedes process
reaping, so a rare uninterruptible kernel exit cannot delay known connection
state. The worker owns the PID until actual reap. The application's final join
occurs only after the live CEF message loop returns. The wire comparison is a
documented exact compact serialization contract with the owned Rust child,
not a general JSON/provider protocol. The real Rust four-operation trace passed.

NS-5 is resolved at source: `CloseAll` retains a separate vector, and failed
browser creation records the failure and exits the message loop. NS-6 is
resolved at source: the build script stages the controller and helper bundles
after every successful component build, checks their actual copied hashes
before signing, and signs/verifies the resulting application. Whole Mach-O
hashes change under signing, and removing signatures does not restore identical
layout; this is why the direct copy check occurs before signing. Independent
read-only comparison found matching UUIDs and all file-backed section payloads
for the built and signed controller/renderer helper; this diagnosis is not a
second release verifier.

The actual owned-page smoke in `context/runtime/native-smoke.log` passed:
visible native browser, exact fixture title, HTTP 200, initialized child, Stop
generation 1, browser close, CEF shutdown and absence of the exact controller
PID. Its renderer probes denied the sentinel open with EPERM. GPU and one
utility probe could open it; no universal helper policy is claimed.

NS-10 is resolved: only the owned staged framework is removed before the
adopted macro copies it. The actual incremental relink/package passed six
pre-sign component comparisons and strict final bundle signature verification.
NS-11 is resolved: checked POSIX realpath supplies one canonical native profile
string, from which root/cache/log paths are derived. The final full native smoke
passed the actual Default/Preferences and no-fallback assertions, all lifetime
stage markers and exact-child absence. The pristine runtime distribution is
unchanged by packaging corrections.

## Open empirical limits

One earlier native run exited 2 with Chromium's teardown watchdog message.
This remains an unexplained observed failure, despite subsequent instrumented
and final canonical-profile runs reaching the end of CefShutdown. Do not infer
that profile canonicalization fixes that watchdog or erase the failed run from
lifetime qualification. Future native lifetime work must retain stage/stack
information for a recurrence; the smoke samples only its exact owned process
if it remains alive past eight seconds. This construction milestone does not
close broader N1 role/isolation, servicing, shutdown-fault or full-runtime gates.

The final ad-hoc build also emits `base/mac/process_requirement.cc` validation
error -67030. The macOS `security error -67030` tool describes an invalid
Info.plist/signature. Static strict bundle verification passes, but that does
not establish current-process validation or peer authentication. Its cause and
impact remain unqualified; record it before any later feature depends on that
process requirement. No entitlement/sandbox/fingerprint override was introduced
to hide either diagnostic.

All eleven concrete construction findings have corrections and corresponding
source/direct-oracle evidence at the stated scope. This is a reviewed browser
shell and control-only connection milestone; native observation, capture-work,
grounded tables, full role coverage, network effects, OS input and an actual
first user-facing POC remain outside this unit.

## Matched-source teardown reading

The shutdown study used CEF revision
`682c378d70d5780061e96644dca16ddd8fd157a9` and Chromium SCM revision
`a654841425914cbb703a2931e07b70a83aedbafd`, read from the acquired framework's
Info.plist. Exact selected files are saved under ignored
`context/review-native-shell/teardown/`; these are reference snapshots, never
compiled into Bow Shock.

- [CEF main runner](https://github.com/chromiumembedded/cef/blob/682c378d70d5780061e96644dca16ddd8fd157a9/libcef/browser/main_runner.cc): APP_CONTROLLER keepalive, quit closure, pending-task drain and runner shutdown.
- [CEF context](https://github.com/chromiumembedded/cef/blob/682c378d70d5780061e96644dca16ddd8fd157a9/libcef/browser/context.cc): same-thread shutdown and blocking context cleanup.
- [CEF Chrome main delegate](https://github.com/chromiumembedded/cef/blob/682c378d70d5780061e96644dca16ddd8fd157a9/libcef/common/chrome/chrome_main_delegate_cef.cc) and [extra parts](https://github.com/chromiumembedded/cef/blob/682c378d70d5780061e96644dca16ddd8fd157a9/libcef/browser/chrome/chrome_browser_main_extra_parts_cef.cc).
- [Chromium browser process](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/browser/browser_process_impl.cc): Unpin invokes quit and shutdown-if-needed; StartTearDown arms the macOS watchdog and destroys profiles.
- [Chromium browser main](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/browser/chrome_browser_main.cc): StartTearDown call in PostMainMessageLoopRun and watchdog disarm in the ChromeBrowserMainParts destructor.
- [Matched macOS watchdog](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/browser/shutdown_watchdog_mac.cc): emergency termination is a backstop, not a diagnosis of the blocked phase.
- Matched [application lifetime](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/browser/lifetime/application_lifetime_desktop.cc), [browser shutdown](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/browser/lifetime/browser_shutdown.cc), and [macOS main parts](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/browser/chrome_browser_main_mac.mm) were read for call ordering. CEF's chrome_runtime patch must also be considered; the unpatched Chromium macOS AppController wiring is not the shipped CEF wiring.

Restore a CEF snapshot from the corresponding raw GitHub URL with the exact
revision above. For Chromium, request the corresponding googlesource URL with
`?format=TEXT`, base64-decode it, and save at its relative path under the ignored
snapshot root. These pins and links preserve the exact source origins for
research-manifest reconciliation.

The subsequent [matched process-policy/identity study](native-process-policies.md)
attributes the observed helper roles and reproduces the dynamic plist-signature
diagnostic. All teardown and policy source snapshots now have exact origins,
preserved responses, sizes, hashes and restoration commands in the
[selected-source manifest](native-matched-source-manifest.json). Earlier open
diagnostic statements above describe this construction review's observation
point; consult that study for the later evidence. The watchdog remains open.
