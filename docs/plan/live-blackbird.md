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
each observation now carries a complete local reading's file locator and format
instructions. URL/title, frame/document/capture identity, timing, full source
columns, per-document text/links and coverage live in the archive. Blackbird
chooses how much to read. Streamed text is plain conversation text. Native IPC
does not stringify/reparse JSON. See [complete readings](complete-readings.md).

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

The operator's subsequent clarification puts accumulated visit extraction first:
see [visit extraction](visit-extraction.md). One requested reading and its file
locator are inputs to that product, not the completed product. Capture successive
states, retain content that disappears from virtualized pages, and organize it
semantically with source references. Output need not match the DOM.

Human browsing can reveal content initially. Page-local delegated exploration
will need fresh native readings and the separate native OS executor, but general
Blackbird-driven navigation is advanced work. On-demand host calls remain a
possible mechanism serving extraction rather than the next milestone by default.
Keep working on real visits and fix encountered failures directly.
