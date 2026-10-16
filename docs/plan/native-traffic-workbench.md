# Native traffic capture and editing

2026-10-16 implementation unit. Extend the existing native browser, without a
proxy dependency, TLS trust changes, or a model-controlled protocol console.
The CEF DevTools observer supplies Network events and explicitly armed Fetch
pauses. The matched CEF headers and the acquired Chromium Fetch/Network PDL and
URL loader interceptor are the implementation sources. Protocol JSON stops at
the CEF adapter; the coordinator, files and editor use native values/binary plists.

Passive mode records target events and requests incremental response content
through Network.streamResourceContent. Save each returned chunk in an adjacent
binary blob, with its order/representation in native metadata. Buffered data
precedes subsequent chunks even if callbacks arrive in a different order. A
failed streaming command falls back to the protocol's completed-body retrieval;
missing/evicted bodies and partial streams remain explicit. Never impose a
harvest size/count cap. Target-local coverage, protocol decoding, redirects,
cache/worker metadata and absent multipart bytes must remain visible.

The editor arms an explicit URL glob and request/response stages. Each paused
stage has its own immutable identity and originals. Edit request URL, method,
headers and optional binary body; edit response status, headers and optional
binary body. Preserve duplicate headers. Save edit instructions and body bytes
before issuing continue/fulfill, and save command acceptance separately from
later browser/network observations. Never call a proposal an observed delivery.

For selected response pauses, take the upstream body as a stream and read it
in 64 KiB chunks into files. This consumes the upstream body: forwarding after
EOF must fulfill from those saved bytes. Stop during consumption cancels that
exchange and closes its stream, preserving partial chunks. Stop at an ordinary
request/header pause forwards unchanged. Resolve outstanding stream-handle
requests before disabling Fetch; do not wait for inference or a UI decision.
Redirect/no-body responses retain their headers and explicit body availability.
Fulfillment itself requires a complete base64 protocol argument; this boundary
can use memory proportional to the selected edited response. Passive capture
must not buffer complete exchanges in the UI.

One serial coordinator owns protocol state and disk writes. CEF callbacks copy
external bytes, queue work and return. UI receives small pause summaries and
file locators. A narrow injected command transport permits direct checks of
request changes, binary response fulfillment, interleaved stream callbacks,
redirects, cancellation and failures against expected protocol commands and
retained actual artifacts. Build the signed native app afterward. Practical
live inspection/editing remains for the operator's return; no owned test page.
