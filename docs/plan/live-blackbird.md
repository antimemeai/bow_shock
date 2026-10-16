# Live browsing with Blackbird

2026-10-16 operator direction supersedes fixture-only product gates and the
October 16 orientation's proposed fixture expansion/qualification sequence.
Develop against live sites. Exercise real outcomes and fix defects directly;
there is no owned-page acceptance ladder or release-certification exercise.
Keep meaningful internal protocol/state tests.

## Deliver this unit

Oxcart opens a live URL with ordinary native browser controls and a neighboring
Blackbird panel: current page, conversation, objective composer, send/steer and
Stop. Sending can include a fresh native rendered-page observation. Page data
and operator instructions travel as separate native fields. Browser navigation
continues while Blackbird works. Navigation retires an in-flight capture;
previously sent observations retain their original URL and document identity.
No browser actuation is invented by this interface.

The panel launches an explicit Blackbird executable using `--application`.
Blackbird owns model/provider/session/tool execution. Oxcart owns its browser,
page capture and presentation. One child/session uses a 32-bit big-endian frame
length and Blackbird BBM2 native values, capped at 4 MiB per frame. Commands are
open, turn, steer, cancel and close; events are ready, text, status, final, error
and closed. Strings identify requests. A turn has objective plus observations;
each observation carries URL/title/rendered text, origin/frame/document/capture
identity, capture interval, truncation and coverage. Streamed text is plain
conversation text. Native IPC does not stringify/reparse JSON.

Implementation units: live native observer; asynchronous binary Blackbird
client; Blackbird application host in an isolated worktree; root integrates the
native panel/launcher/build and reviews each boundary. No new dependency.
The existing installed Codex adapter is bumped directly to 0.162.1, as requested.
Historical experiments stay historical; the ordinary launcher starts no local
catalog server and the application compiles no fixture/table workflow.

## Direct checks

Compile the native application and exercise capture against public live sites
with visibly different structures, including a page with form controls. Read
actual native text/URL/coverage and verify clean shutdown. Exchange actual binary
commands/events with the Blackbird application host; exercise streaming,
cancel/steer, malformed/truncated frames and closure through direct internal
transport checks. Run a real Blackbird request with a live page observation and
inspect its actual answer. Run changed Rust checks for the Codex bump. Review
concrete source and fix findings once; no review of reviews or extra permission
gate. Preserve unrelated in-progress work in both repositories.

## Continue from live use

The native Python.org reading now reaches a real Blackbird answer, and Hacker
News capture passes. Live use exposed and repaired a false one-layout-row-per-node
assumption and a fragment limit that exhausted well before the text-byte budget.
Observations now include rendered link destinations alongside page text.

Next, let Blackbird request another native reading during a turn through the
existing application channel. Give host calls their own IDs and return the
actual capture or error; Stop retires pending calls. Then connect browser-action
proposals to the separate native OS executor. Keep working on real browsing
tasks, with ordinary human navigation and direct fixes for encountered failures.
There is no site-certification prerequisite for either unit.
