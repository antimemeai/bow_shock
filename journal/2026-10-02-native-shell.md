# Native shell and controller connection

Continue the active goal: execute the reviewed plan faithfully to a first POC
the operator can try. Read project guidance and current state. Previous work
implemented only bounded framing. The operator accepted the native AppKit/CEF
parent plus Rust controller and requires basic Rust rigor, deferring detsim and
mutants. This turn starts native N0/N1 and a control-only child process; a bare
browser window will not be substituted for the goal's scoped observation/table
workflow.

Rechecked the live CEF build index, preserving it in ignored context storage.
The previously discussed latest stable ARM64 standard tuple remains
154.0.32+g682c378+chromium-154.0.8037.58. Acquired its 307,024,202-byte archive;
publisher SHA-1 matches and local SHA-256 is
7371ac1d8b17900e11ab37b8d22505a602336bd7408ad7330104fe532cc2b9b9.
Preserved untouched archive and inspected member paths before data-filtered
extraction. `runtime/cef-macos-arm64.json` contains actual source/revision/API
metadata and restoration command. The shipped header's sandbox compatibility
macro is empty although the publisher index has a value; preserve this difference.

Read candidate distribution build instructions, wrapper/loader/sandbox source,
API headers and macOS helper packaging. Adopted stable API15400 for both original
adapter and matching distribution wrapper. CEF full revision is
682c378d70d5780061e96644dca16ddd8fd157a9. No sample/reference application source
was copied or executed. The original native shell uses an AppKit CefAppProtocol
application, CEF's Chrome-style window, dedicated profile, small native controls,
and normal engine isolation/defaults. Generic browser command-line arguments
are disabled so incidental CLI flags cannot override the reviewed sandbox/debug
settings. The browser app is locally ad-hoc signed after matched packaging.

Wrote native sub-plan and owned-page lifecycle smoke before implementation;
the smoke failed directly because no app existed. Initial build exposed the
need to explicitly select C++20 for Objective-C++ as well as C++, then the full
CEF callback include before BindOnce. Corrected the configuration against actual
headers. The owned fixture subsequently loaded with exact title and HTTP200,
and the app recorded browser close and CefShutdown. Full smoke remains red
because its initial Foundation controller read waited for a full 4096-byte
reply instead of available pipe bytes. The native reader and table workflow
remain unimplemented.

Parallel conceptual controller construction and independent review followed
Blackbird. Actual-process parser review found CB-01: Serde's internally tagged
enum accepted positional arrays. Four negative executable cases went red;
the owner added a map-only visitor without collapsing duplicate keys. All
twelve controller process tests now pass; basic rigor passes 26 tests plus
the doctest/Clippy/dependency checks/release. The reviewer rechecked arrays and
duplicate fields and closed the finding. Runtime Serde adoptions and actual
lockfile graph are tracked separately from the engine archive.

Independent native review used the actual connection class with an owned fake
child. It found short replies blocked, timeout cleanup could block the UI when
the child ignored TERM, idle death was not supervised, NSNumber coercion/duplicate
keys weakened reply validation, closing callbacks could mutate vector iteration,
and POST_BUILD-only staging could leave a stale bundled controller/helper.
The native connection is being replaced as one conceptual unit with owned
nonblocking pipes, finite worker supervision, strict wire validation, and
TERM/KILL/reaping. Root fixed browser iteration/creation failure and moved actual
component staging after all builds on every invocation. Direct native fault
oracles and review rechecks will decide closure; no green native gate is claimed
yet. No OS input, model export, network mutation, or raw page capture is enabled.

The replacement native connection passed the independent actual-class suite and
the integrated native window smoke: exact title/HTTP200, visible window,
initialize/Stop generation1/shutdown, ordered browser close/CefShutdown, and
actual owned controller PID absence. Final app exit joins worker reconciliation
only after the live CEF loop has returned. This does not block the live UI.

Stricter actual bundle verification uncovered an incremental packaging defect
in the distribution macro: ln -sf followed existing directory symlinks, creating
broken nested framework links. Wrote the correction into the subplan, then
remove only the staged framework before invoking the adopted copy macro. Exact
controller/helper byte comparison occurs before signing because signing changes
Mach-O metadata. Actual incremental native relinks now pass strict deep bundle
verification. The untouched adopted distribution and archive are preserved.

The disposable profile oracle then exposed a real /var vs /private/var root/cache
containment failure; CEF fell back to in-memory storage. Foundation resolution
still failed the direct oracle. POSIX realpath, with every CEF path derived from
its bytes, now yields actual Default/Preferences persistence and no fallback
diagnostic. One intermediate run also hit a Chromium teardown watchdog. Its
cause remains unproven; later instrumented runs reached join end and CefShutdown
end. Preserve this as an open lifecycle result, with exact owned process
sampling/failure-profile retention available for a recurrence.

The construction findings and bounded role observations are recorded in
[the native experiment](../docs/experiments/native-shell.md). Renderer outside-
profile file reads were denied; utility/GPU policies remain incompletely
attributed. Full N1, native observation/work limits and the reviewed retained
table workflow remain open. Continue N2 fixture-reader and the minimal shared
authority/SQLite lane in independent conceptual units; this window is not the
first useful POC goal's completion.
