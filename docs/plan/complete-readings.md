# Complete file-backed readings

Operator 2026-10-16: harvest the whole reading, write it in an efficient structured
format with adjacent blobs, and let Blackbird decide how to consume it. This
supersedes text, fragment, link, snapshot-size, node-count and elapsed-time caps.
Keep structural validation and explicit capture/IO failures. Stop still cancels.

Each requested reading writes a private directory under the browser data area's
`readings/`. `reading.bplist` contains versioned native metadata, before/after
frame trees, all DOMSnapshot documents/columns and its indexed string table.
Large string-table entries move to `blobs/` with encoding/byte-count references;
the placement threshold changes storage, never content. Every returned document
gets a complete UTF-8 rendered-text view and columnar block index with byte ranges,
backend IDs, element names, link destinations and CSS bounds. Full DOM data,
including hidden nodes and form fields returned by Chromium, stays in the
structured reading. Text views describe their filtering separately. No images,
network-response bodies or out-of-process targets are invented as captured.

The writer stages beside the final directory and publishes only after all writes
and metadata succeed. A failed write never advertises a prefix as a complete
reading. All disk work/projection runs on the existing worker. CEF's typed
method-result callback filters by request ID before copying; only one reader
command is outstanding, so there is no size-based response rejection or event
backlog. Browser navigation/Stop retire the UI callback; complete harvested files
can remain independently useful. No automatic deletion of successful readings.

Blackbird receives a small native observation describing file paths and the
format, through the existing application interface. It can use its ordinary
file/range/program tools; neither forced prompt chunking nor a new agent server
is needed. The panel displays capture paths/counts instead of appending whole
documents into its conversation widget.

Direct checks: native round trips exceeding every previous text/link/node/message
bound, Unicode and blob exactness, all-document retention, complete final records,
malformed columns, failed writes and publication. Rebuild once, exercise a real
large live page and a real Blackbird request reading the saved artifact. Preserve
existing clock work and Blackbird's independent TUI checkout.
