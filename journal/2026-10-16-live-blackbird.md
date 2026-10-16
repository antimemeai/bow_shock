# Live sites and the Blackbird interface

Operator direction: leave owned-page development entirely, work on live sites,
fix actual issues with rigor rather than conservatism/certification, bump Codex
directly, and deliver Blackbird integration using an away-team worktree.
This supersedes the orientation's fixture-expansion/qualification sequence.

The [written unit](../docs/plan/live-blackbird.md) describes the interface and
work split. Three conceptual collaborators own live observation, the native
Blackbird transport and the Blackbird application host. Root owns the native
conversation UI, launcher/build integration and boundary review. No new library
was adopted. Existing dirty clock changes are preserved.

## Application changes

The normal launcher opens a real HTTP(S) URL and a native Blackbird conversation
panel. It starts no web server, constructs no product fields and applies no
catalog-origin restriction. The active native CMake target compiles only the
live application/reader/panel/binary client; old catalog/table/controller modules
and independent control helper are no longer packaged. Their earlier source and
in-progress changes remain historical, rather than being deleted out from under
the existing worktree. CEF keeps its sandbox and no public debugging port.

The panel lets the person read the page locally, include a fresh reading with
an objective, receive streamed assistant text, steer with a replacement objective
and stop. Native browsing continues independently. The visible UI uses Oxcart;
the existing bundle/executable filename is retained. `scripts/oxcart` is the
short launcher. `scripts/check-live.py` inspects actual live native runs and can
also send the captured page to a real Blackbird turn.

The observer uses fixed native DOMSnapshot/frame reader commands, projects on a
worker and emits typed page/text records. It captures root text from unfamiliar
pages, accepts forms, omits input/textarea values and hidden/password regions,
and reports truncation/coverage and loader metadata honestly. It does not call
arbitrary JavaScript or provide action coordinates. Current root text bounds
are 256 blocks, 2,048 UTF-8 bytes/block and 32,768 bytes combined. Native input,
network tooling and learned extraction are subsequent product features.

The native client launches an explicit Blackbird executable with `--application`
and exchanges length-prefixed BBM2 values. Commands: open, turn, steer, cancel,
close. Events: ready, text, status, final, error, closed. Each turn carries the
operator objective separately from live observations and their original
URL/document/capture metadata. IO and process cleanup run off the main thread.
Request IDs distinguish active/replacement turns, and pending command/event
storage is bounded. The ordinary Blackbird tools retain their agency.

The existing Codex adapter and corresponding descriptor/test expectations were
changed directly from 0.160.0 to 0.162.1. No release-schema study was performed.
The app's current conversation path is Blackbird.

## Review and direct results

Root's review caught a server/client text-field mismatch, process lifetime
mistaken for active-turn state, rejected-steer UI identity restoration, unbounded
main-queue event delivery and unbounded final-result assembly. The respective
owners fixed these. The live-observer owner caught uncancelled host captures
after Stop/navigation and stale loading state when switching browser selection;
root fixed those. Root also caught loader-origin metadata labeled as effective
origin; the reader now states its actual source/uncertainty. No review-of-review
or site-certification layer was introduced.

Fresh Oxcart build/signing succeeded, including all live native units and matched
CEF helpers. The checkout's move/symlink resolution caused the old wrapper inputs
to rebuild. Two changed Rust agent tests passed after the Codex bump. Native
packet/process checks pass golden BBM2 vectors, malformed/truncated packets,
streaming, ordinary cancellation, steer/rejection, Stop-after-Steer, queue overflow,
close/forced termination/reap and missing executable. Live-observer projection
checks pass real native parser inputs for form adjacency, hidden/password/editor
omission, Unicode/limits, identity/layout/link handling and malformed tables.

The first actual native Python.org run reached the rebuilt application's macOS
Keychain prompt. A specific securityd event identifies that app/PID and its
Safe Storage item authorization request. The request was sent to the operator
asynchronously while independent Blackbird work continued. That run later exited
with Chromium's teardown watchdog; no successful native capture is claimed.
No Keychain ACL, encryption or signing identity was changed to suppress it.

Separately, the actual Blackbird application preview accepted a live HTTP
Python.org document (gzip decoded, actual HTML text, explicit HTTP-only coverage)
over the new binary interface. It streamed: “The website is Python.org, and one
short heading is ‘Get Started.’” The final outcome was completed and close exited
zero. Artifacts live in the Blackbird worktree's ignored
`context/oxcart-live-wire/`. This establishes a real model/transport result with
live evidence; it is not a native browser-capture result.

## Blackbird away team

The isolated worktree is `~/projects/blackbird-oxcart`, branch
`work/oxcart-interface-2026-10-16`, based on committed `84f5ea8`. Its main checkout's
staged/uncommitted TUI work was not copied, reset or edited. The application host
reuses ordinary Blackbird session boot/recovery, original retention, provider and
CodingEngine/workflow/tools. Its wire contract is in
`../blackbird-oxcart/docs/APPLICATION_INTERFACE.md`. Blackbird owns its issue,
journal, required source checks and branch publication. Current delivery results
are appended below when complete.

Oxcart's delivery branch is `work/live-blackbird-2026-10-16`. Source staging
separates this unit from the preexisting clock implementation: files rewritten
for the live app are staged normally; the Codex string changes and new status
introductions are staged over HEAD for mixed files, leaving the older clock
changes in the working tree. The orientation journal from the preceding request
is included as work history. No unrelated clock source is discarded or committed.

Oxcart checkpoint `c4e0c27` was pushed to its feature branch. The normal live app
was opened on Python.org with the worktree's actual `build/debug/blackbird` and
its own session. It remains open for operator inspection/Keychain response.
Blackbird's complete 162-test Debug run and corrected-source Linux interface
checks passed; its required lint/publication work follows independently.

A final composer fix binds the include-page checkbox to button refresh, allowing
conversation without a page while navigation is loading. The changed native
panel passes strict source compilation. The already-open preview predates this
small binding change; the next ordinary build/restart activates it.

## Delivered

Both Oxcart checkpoints (`c4e0c27`, `4d57e84`) are pushed to
`origin/work/live-blackbird-2026-10-16`. Blackbird source checkpoint `b84da24`
and results checkpoint `2c3ca4c` are pushed to
`origin/work/oxcart-interface-2026-10-16`; that worktree is clean. The required
Blackbird source gate passed all 162 Debug tests and all owned C++/Lua lint.
Corrected-source Linux Debug and ASan application/CLI checks also passed.
Blackbird issue `arconaut-ums` is closed and its issue backup completed. Neither
branch was merged into the repositories' ongoing main-checkout work.

The normal native app remains open on Python.org. Native capture still awaits
the operator's macOS Safe Storage response; no successful native capture or
combined native-page/model turn is reported. The separate actual live-HTTP/model
turn above succeeded. The next product work is using this live interface and
fixing concrete reader/browser/model issues encountered on actual sites.
