# Native traffic implementation source study

2026-10-16. Read the adopted CEF 15400 `cef_browser.h` and
`cef_devtools_message_observer.h`, plus the **matched Chromium 154.0.8037.58**
Fetch/Network PDL and URL loader interceptor. The existing network study's
sources remain useful history; the new implementation does not assume their
later/earlier revisions describe the adopted browser.

The source files below are retained intact in ignored
`quarantine/network-chromium-154/`, with exact acquisition metadata in
`acquisition.bplist`. These are individual Chromium source originals, not an
extracted archive; no Git metadata or filesystem detritus is present. Chromium
authors, Chromium BSD license, acquired 2026-10-16. No source is copied into the
product, and no library is adopted.

| Relative source | SHA-256 | Bytes |
| --- | --- | ---: |
| `third_party/blink/public/devtools_protocol/domains/Fetch.pdl` | `bb280686ab4e602a56f3abfc24c47f141b62da387d0ba7d7aa7cf23f7f2111e6` | 11003 |
| `third_party/blink/public/devtools_protocol/domains/Network.pdl` | `ef29bf4819ecab18e31c11a1e2ea4912867e7845b6af04c8165e9af45758b7e5` | 88115 |
| `content/browser/devtools/devtools_url_loader_interceptor.cc` | `1c81a274bc916efc59fac849b0cb427ce256dbac61faa090b976788be84ef526` | 88310 |
| `content/browser/devtools/devtools_stream_pipe.cc` | `32c84d643c65e31ba31baf1e638543fed725f8c163c5bf58ca98000a4673bd21` | 4654 |
| `content/browser/devtools/protocol/fetch_handler.cc` | `b64025e0261b3b9b866c2232dd024058e393237f52a8dc88ae71fea4832aa55b` | 23906 |
| `LICENSE` | `368cca1106be99d39ecd32a38d8305585d802a475effb66380b91ffc9bcf709b` | 1536 |

Restore each with `curl --fail --location --output PATH URL`, making its parent
directory first. URL is
`https://raw.githubusercontent.com/chromium/chromium/154.0.8037.58/RELATIVE_SOURCE`;
check the SHA-256 above. Restore the CEF headers through
`python3.13 scripts/cef-runtime.py acquire` (tracked runtime manifest).

The [matched Fetch PDL](https://github.com/chromium/chromium/blob/154.0.8037.58/third_party/blink/public/devtools_protocol/domains/Fetch.pdl)
allows both stages, exact request overrides and response fulfillment. Request
overrides do not automatically carry across redirects. Taking a response stream
consumes it; an ordinary unchanged continuation afterward is invalid. A response
body cannot be requested for a redirect. The implementation therefore keeps each
pause/hop identity and preserves originals before submitting edits.

The [matched interceptor](https://github.com/chromium/chromium/blob/154.0.8037.58/content/browser/devtools/devtools_url_loader_interceptor.cc)
sets `kResponseTaken` before handing out the body pipe; error completion is
handled before ordinary continuation, so cancellation remains possible during
stream reads. `StartLoadingResponseBody` applies the network-service content
decoding interceptor when client-side content decoding is active. Forwarding
saved bytes must fulfill a body and remove stale compression/transfer/length
metadata. These are protocol-level bytes, not original wire framing.
`SendResponse` fatally checks `bytes_to_write.size() <= UINT32_MAX` before making
its Mojo pipe. The coordinator therefore checks only selected fulfillment size,
before whole-body assembly, and leaves larger original data intact. A streaming
custom response loader is required to forward such bodies through this editor.

`FetchHandler::OnResponseBodyPipeTaken` wraps the pipe in `DevToolsStreamPipe`.
Its `DispatchResponse` returns valid UTF-8 bytes as protocol text and base64
encodes every non-UTF-8 chunk. Parsing text then re-encoding as UTF-8 therefore
retains the same stream bytes, including when a read splits a multibyte sequence
(the split fragment takes the base64 path). This finding comes from the matched
source, not a guess based on the response's MIME type. It does not make the
already decoded stream equivalent to original compressed/TLS wire bytes.

The [matched Network PDL](https://github.com/chromium/chromium/blob/154.0.8037.58/third_party/blink/public/devtools_protocol/domains/Network.pdl)
provides incremental `streamResourceContent`: initial buffered bytes plus
subsequent `dataReceived.data`. Native storage puts buffered bytes first rather
than depending on callback arrival order. If unavailable, completed retrieval
can return base64 or text; errors stay unavailable. `getRequestPostData` excludes
multipart files. Extra-info/redirect/cache/worker fields remain events with their
own IDs; the archive does not invent cross-target attribution.

CEF observers share a command namespace. A single owned atomic ID allocator
serves the page reader and traffic adapter; traffic filters IDs before copying
results, so a DOM snapshot is not copied again by an unrelated observer. Typed
CEF dictionaries format only the external commands, and incoming protocol JSON
is parsed on serial workers into native values. Production persistence is
binary plists with adjacent byte blobs.
