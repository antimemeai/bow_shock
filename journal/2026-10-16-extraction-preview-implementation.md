# Native extraction preview and whole-recipe history

Implemented the operator's first extraction loop using the existing complete
reading archives and Blackbird application connection. No browser-input executor,
fitted behavior model, new dependency or Blackbird source change is included.

The native panel now has Extract and Preview. Explicit readings accumulate per
visit; navigation begins another collection. Extraction writes an immutable
attempt manifest and inputs, asks real Blackbird to write a binary-plist result,
retains exact submitted bytes even on validation failure, and renders headings,
paragraphs, lists, labeled records and tables with source/interpretation labels.
Native source links show saved text and highlight supplied UTF-8 byte ranges.
Source references must belong to the attempt and fit their actual reading;
reading capture identity is checked against its manifest.

The AppKit stage exports its actual displayed text, RTF, PDF and source map.
Blackbird receives those saved renderer paths for the one automatic tweak.
Further corrections create one new manual attempt and can include newly saved
readings from the same current visit. Correcting an older visit retains its
original source collection. Working model files, raw submissions, error previews,
corrections and previous results remain available. Operator correction text is
kept in the editor if another conversation is busy.

The recipe sheet edits a complete proposed approach. Each save creates a new
dated UUID document with the previous active recipe's ID, then a separate
activation event. Earlier recipes are never edited/deleted. Failed activation
keeps the old active choice and complete unactivated successor. Recipe-box
history loads across restarts; explicit selection can use an active/historical
recipe or generic pass. Attempts bind exact identities, including the automatic
tweak if the next-extraction selection changes in the meantime.

Worker-owned exclusive, synchronized publication preserves partial artifacts.
Stage events record visit/read/model/render/cancel/failure/recipe activity from
the beginning. Shutdown waits for queued workspace IO and Blackbird closure.
One review finding changed the older reading writer: IO/publication failures now
retain their staging directory and report its path rather than remove harvested
source data. Failed directories never enter completed extraction inputs.

Direct checks passed: native workspace/renderer, whole-recipe restart and failed
activation; invalid/foreign/out-of-bounds source data; retained malformed output;
actual native text/RTF/PDF/source-map export; initial/tweak/manual coordination,
newly captured same-visit inputs and Stop retaining a submitted second result.
The complete-reader native check passes with disk-full source retention.
Strict builds and Python utility compilation/diff checks pass. Visual inspection
of the actual PDF exposed dark source labels; explicit link color/underline fixed
them and the updated PDF is legible. No unchanged Rust/Blackbird suites reran.

Signed native build is `context/build/extraction-final/Bow Shock.app`. Separate
build/output flags avoid overwriting the previously open native bundle. An
actual Python.org extraction was launched from the preceding extraction build
as `context/runtime/live-checks/run-6bxs7zm1` (PID14882). macOS securityd at
08:55:01 local confirms its pending Chromium Safe Storage item-access prompt
after the new ad-hoc signing hash. Asked the operator asynchronously to choose
Allow; the run remains open without a timeout. No native live reading or real
model extraction from that run is claimed yet. The final build also includes
the subsequent source-identity, correction-retention and failed-reading changes.

The older Wikipedia reading run remains open. No Keychain ACL, encryption,
trust, signing identity or host networking was changed. Preserved unrelated
clock work and Blackbird's independent checkout. Metrics and bidirectional
traffic capture/editing remain the fast follows; empirical input precedes any
future delegated page gestures.
