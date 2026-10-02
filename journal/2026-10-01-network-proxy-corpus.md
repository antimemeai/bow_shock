# Proxy/editor/protocol corpus, 2026-10-01

Expanded the network reference lane for the operator's substantial-quarantine request. Added `papers/network-proxies-and-protocols.md` and `papers/network-proxy-sources.json`:16 new upstream repositories and10 primary documentation/specification entries. Compared against existing catalogs before selecting IDs. Verified HEAD pins with git ls-remote and exact extraction scope against each pinned Git tree. Root owns archives/acquisition ledger and is downloading the catalog; no shared manifests were edited here.

Read focused source fragments for every listed repository: replay/streaming in mitmproxy; macOS NetworkExtension/process/Unix IPC and Linux eBPF overview in mitmproxy_rs; HTTP Toolkit send/breakpoint/local API/Chromium interceptor; Mockttp handlers and actual transform assertions; Atlantis URLSession observation/transport; Whistle transforms/cache; GoProxy HTTP2 example; Martian MITM/HAR; nghttp2 Sans-IO guide/proxy lifecycle; quiche H3 setup; aioquic stream completion; h2 padding-aware credit; h11 framing; curl redirect/protocol/keylog docs and experimental H3-proxy tests; rustls secret logging/0RTT example. Broader retained tests/source are future study, not read/review claims.

Curl/quiche were narrowed to exact-file ZIPs with failure/state tests while moderate repos retain original source archive and selected tree extraction. Root noted the first download pass loaded their earlier archive scopes and will reconcile those two selections. Catalog is stable thereafter. Open Proxyman source is Atlantis, not proprietary proxy core. Current curl direct-H3 docs differ from experimental H3-proxy test availability; report preserves backend/feature distinctions. No upstream execution, dependencies installed, proxy configuration, route changes or certificate trust changes.

Prepared an optional acquisition fallback after mitmproxy/rustls archive
timeout/incomplete-read failures: `context/network-proxy-fallback.json` contains
two catalog-shaped entries of20 exact files each, retaining the original pins.
Verified every path against its pinned Git tree. Includes licenses/README,
reviewed replay/streaming or key-log/early-data mechanisms, and relevant
replay/save/HTTP2/HTTP3 or client/server/resumption/QUIC test source. This is a
partial source-study ZIP scope, not a buildable checkout or test execution.
Root decides whether to apply it after ongoing archive retries; no active
catalog, ledger or acquired archive was changed here.
