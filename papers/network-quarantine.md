# Network reference collection

Expanded 2026-10-01 at the operator's request. This is a source-study collection
for Bow Shock's network workbench, external environment controller, and traffic
observatory. Acquiring tools does not install them, route browser traffic through
them, grant them host privileges, or select a dependency.

## Reading map

| Layer | Reference families | Study and intended evidence |
| --- | --- | --- |
| Native browser observation | Existing Chromium/CDP/CEF sources | Target/frame coverage, body retention, workers/cache, cancellation and replacement-response ownership |
| HTTP inspection and editing | mitmproxy, HTTP Toolkit/Mockttp, Whistle, GoProxy, Martian | Paused flows, streaming, edit/replay semantics, credentials and proxy-visible representations |
| Native capture bridges | mitmproxy_rs and its platform helpers; Atlantis application instrumentation | Process/flow attribution, platform entitlements, capture scope and where instrumentation changes the environment |
| Protocol implementations | nghttp2, quiche, aioquic, h2, h11, curl, rustls | HTTP/TLS/QUIC state machines, multiplexing, shutdown, retries, authentication and tests for actual failure behavior |
| External network conditions | Packet shaping, TCP fault proxies, packetdrill and topology references | Real transport/link/route effects, OS reachability, confinement, cleanup and server-visible consequences |
| Packet capture and measurement | libpcap/tcpdump/Wireshark and measurement references | Capture location, encryption, packet drops, timestamps and evidence lost before application logging |
| Tracker research | OpenWPM, TrackerRadar/collector and existing PixelConfig | Initiators, data categories, coverage, structural differences and measurement-version provenance |
| Archives and offline replay | HAR schema/parsers, warcio/pywb, Browsertrix | Representation limits, reproducible browsing evidence and differences between archive replay and live traffic |
| Owned endpoints and comparison tools | HTTPBin/go-httpbin, HTTP echo, WireMock, DeepDiff, focused Zeek source | Controlled request/response fixtures, concrete effect checks and explicit normalization |
| Semantic assistance | Existing Jev tool and typed judgment research | Advisory interpretation of bounded differences and field candidates with deterministic ownership |

The detailed reports contain primary citations, exact reading scope and
implementation findings:

- [Proxies and protocol implementations](network-proxies-and-protocols.md).
- [External environments and packet capture](network-environments-and-capture.md).
- [Measurement, logging, and replay](network-measurement-and-logs.md).
- [Native network observatory](network-observatory.md).
- [OS input and reachability](os-input-and-behavior.md).
- [Jev judgment pilot](jev-network-judgments.md).

## Keep the evidence boundaries explicit

A native observer, an HTTP proxy and a packet capture describe different parts
of an exchange. Local cache/worker responses can exist without a server request;
encrypted packet capture can lack application plaintext; an archive or HAR can
omit data even when its serialization is valid. Use each implementation to study
its precise boundary rather than call one view the complete network truth.
The [observatory report](network-observatory.md) develops these distinctions.

Likewise, a TCP fault injector, a packet shaper, a virtual interface and a host
route change cause different conditions. The operator's requirement is deliberate
intervention outside Chromium. Choosing a mechanism still requires observing
the OS, browser, page and server, including the signals that did **not** occur.
Process/window ownership alone does not prove the intervention is confined to
that browser. The environment report traces concrete control and cleanup paths.

For trackers, preserve raw evidence and declared feature normalization together.
A retry burst can be explained by our intervention while a newly transmitted
contact field remains a meaningful change. Read capture schemas before designing
baselines: omitted fields cannot be recovered from an absent transcript. Jev can
assist with ambiguous interpretation once scope and evidence are established;
it supplies no authority to execute an intervention or dismiss evidence.

## Acquisition and next source work

The three new network catalogs plus the earlier network/OS catalogs describe
origins and intended scopes. [The ledger](acquisition.json) records actual
downloads, complete pins and byte identities. Moderate repositories preserve
upstream source archives with selected extracted paths. Large source/data
repositories use explicit individual-file subsets; relevant test paths are
included for study. Tests were acquired as source, not executed here.

The [reference manifest](../QUARANTINE.md) gives restoration commands and current
inventory. [The shopping list](../SHOPPING_LIST.md) records retrieval failures,
proprietary components and deferred data/runtimes. Downloaded artifacts and
specific files read are separate claims.

Next trace one complete exchange through observation, optional editing,
cancellation, storage and comparison; then trace one external intervention
through application, observed signals and teardown. Use the acquired tests to
identify direct outcomes and failure cases before writing our implementation.
Language, engine, libraries, execution grants and storage remain open decisions.
