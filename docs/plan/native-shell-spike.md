# First native shell construction

2026-10-01. Execute native N0/N1 from the reviewed plan. The operator accepted
the AppKit/CEF parent and Rust controller arrangement and asks us to execute to
a first usable POC. The Rust basic gates are active; detsim and mutants remain
deferred. This unit earns only matched packaging, manual browser lifetime and
the private controller connection. The following native reader/table units
still require their own direct oracles before a POC observation workflow.

Adopt the previously discussed CEF standard macOS ARM64 distribution now that
the live publisher index still identifies
`154.0.32+g682c378+chromium-154.0.8037.58` as its latest stable entry. Preserve its
archive in ignored `context/runtime/archives/`; record the actual download URL,
publisher metadata and locally computed digest in `runtime/cef-macos-arm64.json`.
Inspect archive paths before extraction. Build against only that distribution's
matching wrapper, headers and framework, with an explicit supported stable API.
Quarantine examples remain reading material and are not copied.

The owned Objective-C++ AppKit application implements CefAppProtocol and uses
Chrome-style windowed content with normal native URL entry. It owns a small
native control panel for status/Stop/close, launches the Rust controller as an
owned child, and exchanges bounded closed records on private inherited pipes.
Dedicated IO workers handle pipes; UI callbacks never block on them. Child
channels are close-on-exec and CEF helpers do not inherit controller authority.
No model, agent, OS posting, HTTP editing or external fault is enabled here.

Package the framework/resources, dynamic sandbox and correctly named helper
bundles. Helpers initialize sandbox before loading CEF. Browser close callbacks
precede CefShutdown and app exit. Controller disconnect disables the controller
connection without breaking manual browsing; reconnect cannot reuse a prior run.
No `no-sandbox`, certificate bypass, public CDP listener or site-isolation
relaxation is permitted as a feasibility shortcut.

Red oracle: the native smoke command fails before an app exists. Its owned local
fixture checks a specific navigation marker/load outcome, browser creation and
orderly close, and observes actual renderer/helper processes. A test-only
outside-profile file probe in helper startup checks sandbox denial per role;
unsettled roles remain explicitly unverified. Controller integration checks the
actual child/replies and Stop generation, with EOF/child-death cases. The smoke
does not certify native observation, storage durability or arbitrary sites.

Green: original app builds and packages against the actual matched tuple; owned
fixture loads in a visible native window; direct per-role observations and
ordered shutdown succeed. Independent adversarial review examines source,
bundle boundaries and the direct oracle, and all valid findings are resolved.
Record exact runtime/build and gaps in `docs/experiments/` and journal. Follow
with native observation/capture-work and the reviewed table slice; an empty
window alone does not complete the first POC goal.

Incremental packaging correction: strict final-bundle verification directly
fails after relinking into an existing app. The distribution's framework macro
uses `ln -sf` on existing directory symlinks, creating nested broken links.
Remove only the staged framework before invoking that macro on each native
relink. Preserve the adopted runtime tree/archive. Compare staged controller and
helper bytes before signing, then require strict deep signature verification.
Exercise another native relink and the actual fixture smoke; successful signing
alone is not the packaging oracle.

Profile correction: the actual disposable `/var` profile failed CEF's
root/cache containment check after the engine canonicalized only the root to
`/private/var`. Create and resolve the selected profile once before deriving
all CEF paths with POSIX realpath; Foundation's path resolution normalizes some
`/private` aliases back to `/var` and failed the same direct oracle. The oracle
requires the actual on-disk Default profile and
rejects in-memory fallback diagnostics. A subsequent teardown-watchdog failure
remains a separate unresolved lifecycle result until directly diagnosed.

For role attribution, the current Darwin-temporary sentinel is inside explicit
GPU/network policy exceptions. Add a second owned marker under project runtime
context, outside bundle/profile/temp/cache, and record fixed utility/service
subtype tokens, seatbelt-client presence and uid/euid. Never read marker contents
or print paths. Check actual known helper PID disappearance after shutdown;
refuse a bundle rebuild while its app/helpers are live, as required by the
whole-bundle servicing contract.

Signing metadata correction: an owned Foundation/Security probe independently
reproduced dynamic validation -67030 for our handcrafted-style XML plist while
disk verification passed. Canonical Foundation XML followed by re-signing made
both dynamic and disk checks succeed. Canonicalize only generated owned app/
helper Info.plists with the platform plist writer before signing. Preserve
upstream framework metadata. Require actual smoke diagnostic absence as the
direct product check; this does not confer authenticated identity on ad-hoc code.
