# Read the live web

Operator2026-10-16 requires complete file-backed readings. The implementation and
format are described in [complete readings](complete-readings.md). This supersedes
all earlier per-text, fragment, link, node, response-size and elapsed-time caps.

Fixed native reader commands harvest the current target's entire DOMSnapshot
and frame trees. Every returned document and every source column/string remains
in the structured local capture. Each document has an indexed full text view;
large strings live beside the native binary tables as referenced blobs.

Read frame identity, harvest the snapshot, then read identity again. The saved
metadata contains both frame trees and records changes. Capture IDs and monotonic
timestamps describe an interval, not atomic page state. The typed CEF result
callback routes by ID before copying; unrelated events do not queue data. Disk
writing and projection run on the worker. Stop/navigation retire pending UI
callbacks. Completed readings remain available on disk.

The full source retains hidden nodes and form fields. Text views omit hidden,
input/textarea and password regions, while including offscreen and CSS-generated
layout text. Their byte indexes reference the complete UTF-8 view, with backend
node IDs, element names, all resolved HTTP(S) links and document CSS bounds.
Text-view errors are explicit without discarding the full source.

The reader retains all documents returned by this Chromium target. Separately
attached out-of-process targets, network/image/media bodies, pixels and AX are
not supplied by these commands. Loader securityOrigin is metadata rather than
verified effective JavaScript window origin. Coverage is stored with the reading.

Blackbird receives file paths and chooses its own whole/range/programmatic access.
Validation uses native format/IO checks and actual live captures; there is no
owned web fixture or site-certification gate.
