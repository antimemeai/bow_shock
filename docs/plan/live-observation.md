# Read the live web

The observer supplies the current root page to Blackbird while the person browses
ordinary HTTP(S) sites. It has no fixture origin, known field IDs, or site-owned
markup contract. It executes only fixed DevTools reader commands, never page
JavaScript. Frame metadata identifies the loader and its security-origin metadata;
this field does not establish the effective JavaScript window origin. DOMSnapshot
supplies actual rendered text and layout.

Capture root-frame identity, capture its DOM/layout, then read frame identity
again. A changed root loader fails that capture; normal DOM updates do not.
Capture IDs and monotonic start/end timestamps describe the observation interval,
not an atomic page state. Decoding/projection run off the UI thread. A deadline,
callback byte bound, node/work bound and output bound stop runaway reads; errors
remain explicit and the next capture can retry.

Emit typed native page and text-block records. Only the DevTools boundary uses
JSON. Include root URL, title, origin, frame/loader/capture identity, bounded
rendered text, backend node IDs, element names, links and document CSS bounds.
State root-only coverage, offscreen inclusion, unknown occlusion, canvas/image
omission and truncation. Omit input/textarea values and password descendants;
do not claim to identify arbitrary secrets rendered by custom page code.

The native value passed to Blackbird and the live-run inspector includes up to
64 distinct HTTP(S) destinations from these rendered text blocks. Each carries
its first text fragment. Link-list truncation is reported independently from
text truncation; links outside the retained text blocks are not enumerated.
This gives Blackbird actual navigation destinations without inventing action
coordinates or granting browser execution.

Validation uses the native compiler and captures on public live pages through
the actual shell. Inspect returned text/identity/bounds and exercise repeat reads
and navigation. No owned web fixture or site certification gate is introduced.
