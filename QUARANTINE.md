# Reference acquisition and restoration

The source catalogs in `papers/*-sources.json` record origins and intended scope.
[The acquisition ledger](papers/acquisition.json) records actual local status,
repository pins, download URLs, byte sizes, SHA-256 identities, extraction paths,
and omitted submodules. [Nested references](papers/nested-references.json)
records the second extraction of MIWA's packaged implementation.

`quarantine/`, `context/`, and paper PDFs are ignored local research artifacts.
Reference code is for study. Nothing in this collection adopts a dependency or
licenses it for redistribution; consult each upstream license before adoption.
No acquired implementation has been built or executed.

The 2026-10-16 [human-input acquisition](papers/human-input-manifest.md) has its
own binary-plist ledger and preserved original typing/mouse archives, papers,
capture source and standards snapshots. Restore with
`python3.13 scripts/acquire-human-input.py`. These additions are separate from
the older generated inventory below; no reference code was executed.

## Restore

From the project root, with Python 3.13+ and Git:

```sh
python3 scripts/acquire.py --kind refs
python3 scripts/acquire.py --kind papers
python3 scripts/acquire.py --kind docs
```

Retain the tracked acquisition ledger when restoring: it carries resolved commits
for catalogs that originally requested HEAD. Existing artifacts are checked
against their recorded digest. Missing repository trees are reconstructed from
preserved archives; missing archives are downloaded from the recorded commit.
`--id SOURCE_ID` selects an entry. `--restore` rebuilds an existing tree and
retains its previous copy in `context/retired-references/`. A nonzero exit reports
failed entries; it does not undo successful acquisitions.

Full GitHub source archives omit gitlink/submodule payloads. Those gaps are listed
in the ledger, without claiming that each reference is a complete runnable
checkout. Selected extraction paths further limit some trees. Very large
monorepos also have exact-file subsets: their preserved ZIP contains only the
listed source files, with fixed timestamps and ordinary file modes, rather than
an original upstream release archive or a complete checkout. No full Chromium
checkout, browser binary, model weights, or benchmark service was provisioned.

Extraction rejects path traversal and removes nested Git metadata, bundled
node_modules, Python caches, macOS metadata and common filesystem detritus.
Original acquired archives remain intact. Reference trees should be restored,
rather than edited as product code.

MIWA's implementation requires a second extraction after restoring `ref-miwa`:

```sh
python3 -c 'from pathlib import Path; from scripts.acquire import extract; extract(Path("quarantine/ref-miwa/Interactive-WebRobot-main.zip"), Path("quarantine/miwa-implementation").resolve(), [], rebuild=True)'
```

The nested manifest records that ZIP's independent digest and size. Extraction
is a file operation; it does not install or execute the extension/backend.

Documentation snapshots are HTTP response bodies, sometimes HTML shells,
redirect/login pages, or non-HTML source. Successful download does not establish
that a vendor page was readable. Reports and catalog notes state those limits,
particularly for Meta and Apple documentation. Papers are verified as PDF files;
acquisition is not evidence of full-text reading.

## Local reference inventory

The table below is generated from the ledger. Exact full revisions, archive
paths/checksums, selected paths and submodule gaps remain authoritative there.
Counts describe acquisition entries, including separate snapshots/subsets of
some repositories, rather than unique upstream projects.

Refresh the inventory and shopping-list gap table with
`python3 scripts/research_inventory.py` after acquisition. The network expansion
has [a layer-by-layer reading map](papers/network-quarantine.md).
Where a full archive was acquired before narrowing to a file subset, its origin
and byte identity remain in that record's `retained_artifacts`; both are preserved.

<!-- BEGIN ACQUISITION INVENTORY -->
Current local inventory: **108 acquired source collections, 66 PDFs, and 123 documentation/source snapshots**, from 317 recorded catalog entries. Some collections share an upstream repository. Unresolved entries are in [the shopping list](SHOPPING_LIST.md).

| Source | Revision | Scope | Status | Local tree |
| --- | --- | --- | --- | --- |
| [agent-browser](https://github.com/vercel-labs/agent-browser) | `39a74c70d775` | full source archive | acquired | `quarantine/agent-browser` |
| [browser-harness](https://github.com/browser-use/browser-harness) | `afbcc381b963` | full source archive | acquired | `quarantine/browser-harness` |
| [browser-use](https://github.com/browser-use/browser-use) | `4cbe921673b4` | full source archive | acquired | `quarantine/browser-use` |
| [cdp-native-surfaces](https://github.com/ChromeDevTools/devtools-protocol) | `8b7f1d955017` | listed individual files (7 selected paths) | acquired | `quarantine/cdp-native-surfaces` |
| [cdp-protocol](https://github.com/ChromeDevTools/devtools-protocol) | `8b7f1d955017` | full source archive | acquired | `quarantine/cdp-protocol` |
| [cef](https://github.com/chromiumembedded/cef) | `ff57d4eae16d` | full source archive | acquired | `quarantine/cef` |
| [cef-native-surfaces](https://github.com/chromiumembedded/cef) | `ff57d4eae16d` | listed individual files (13 selected paths) | acquired | `quarantine/cef-native-surfaces` |
| [cef-project](https://github.com/chromiumembedded/cef-project) | `3aec7049cf63` | full source archive | acquired | `quarantine/cef-project` |
| [cef-rust](https://github.com/tauri-apps/cef-rs) | `a712ad9bacd2` | full source archive | acquired | `quarantine/cef-rust` |
| [chickenfoot](https://github.com/bolinfest/chickenfoot) | `97fcf004a2cc` | full source archive | acquired | `quarantine/chickenfoot` |
| [chrome-extension-samples](https://github.com/GoogleChrome/chrome-extensions-samples) | `e01a67d830c5` | full source archive | acquired | `quarantine/chrome-extension-samples` |
| [chromium](https://chromium.googlesource.com/chromium/src/) | `faee0a28a27e` | listed individual files (19 selected paths) | acquired | `quarantine/chromium` |
| [chromium-native-surfaces](https://github.com/chromium/chromium) | `faee0a28a27e` | listed individual files (8 selected paths) | acquired | `quarantine/chromium-native-surfaces` |
| [codex-source](https://github.com/openai/codex) | `59f18e8133f2` | full archive; selected extracted paths (6 selected paths) | acquired | `quarantine/codex-source` |
| [cog](https://github.com/Igalia/cog) | `92ca8c4f32b1` | full source archive | acquired | `quarantine/cog` |
| [coscripter](https://github.com/jeffnichols-ibm/coscripter-extension) | `0ff0c7b60920` | full source archive | acquired | `quarantine/coscripter` |
| [devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) | `648a6676e7ed` | full source archive | acquired | `quarantine/devtools-mcp` |
| [devtools-protocol](https://github.com/ChromeDevTools/devtools-protocol) | `8b7f1d955017` | full source archive | acquired | `quarantine/devtools-protocol` |
| [electron](https://github.com/electron/electron) | `df79406cecfd` | listed individual files (13 selected paths) | acquired | `quarantine/electron` |
| [extractgpt-source](https://github.com/wbsg-uni-mannheim/ExtractGPT) | `3f96461b28bd` | listed individual files (46 selected paths) | acquired | `quarantine/extractgpt-source` |
| [helena](https://github.com/schasins/helena) | `439b979118c4` | full source archive | acquired | `quarantine/helena` |
| [jcef](https://github.com/chromiumembedded/java-cef) | `17e805ad387d` | full source archive | acquired | `quarantine/jcef` |
| [ladybird](https://github.com/LadybirdBrowser/ladybird) | `cb77ef11c55a` | listed individual files (9 selected paths) | acquired | `quarantine/ladybird` |
| [markuplm-source](https://github.com/microsoft/unilm) | `31c5b904ca1b` | listed individual files (22 selected paths) | acquired | `quarantine/markuplm-source` |
| [measurement-browsertrix-crawler-code](https://github.com/webrecorder/browsertrix-crawler) | `663cd8c41f1e` | listed individual files (6 selected paths) | acquired | `quarantine/measurement-browsertrix-crawler-code` |
| [measurement-deepdiff-code](https://github.com/qlustered/deepdiff) | `79e4379278b1` | full archive; selected extracted paths (8 selected paths) | acquired | `quarantine/measurement-deepdiff-code` |
| [measurement-go-httpbin-code](https://github.com/mccutchen/go-httpbin) | `34888fd21d66` | full archive; selected extracted paths (2 selected paths) | acquired | `quarantine/measurement-go-httpbin-code` |
| [measurement-har-schema-code](https://github.com/ahmadnassri/har-schema) | `c01b2e49edc3` | full archive; selected extracted paths (6 selected paths) | acquired | `quarantine/measurement-har-schema-code` |
| [measurement-haralyzer-code](https://github.com/haralyzer/haralyzer) | `29ffe0d2e26d` | listed individual files (11 selected paths) | acquired | `quarantine/measurement-haralyzer-code` |
| [measurement-http-echo-code](https://github.com/hashicorp/http-echo) | `767bbd9c3d19` | full archive; selected extracted paths (3 selected paths) | acquired | `quarantine/measurement-http-echo-code` |
| [measurement-httpbin-code](https://github.com/postmanlabs/httpbin) | `f8ec666b4d1b` | full archive; selected extracted paths (2 selected paths) | acquired | `quarantine/measurement-httpbin-code` |
| [measurement-openwpm-code](https://github.com/openwpm/OpenWPM) | `ae85559ac9c5` | full archive; selected extracted paths (6 selected paths) | acquired | `quarantine/measurement-openwpm-code` |
| [measurement-pywb-code](https://github.com/webrecorder/pywb) | `55cf079c80fe` | full archive; selected extracted paths (6 selected paths) | acquired | `quarantine/measurement-pywb-code` |
| [measurement-tracker-radar-code](https://github.com/duckduckgo/tracker-radar) | `c958f33e5d89` | listed individual files (6 selected paths) | acquired | `quarantine/measurement-tracker-radar-code` |
| [measurement-tracker-radar-collector-code](https://github.com/duckduckgo/tracker-radar-collector) | `4ad2472b346b` | full archive; selected extracted paths (4 selected paths) | acquired | `quarantine/measurement-tracker-radar-collector-code` |
| [measurement-warcio-code](https://github.com/webrecorder/warcio) | `2a797aa8c6d6` | full archive; selected extracted paths (3 selected paths) | acquired | `quarantine/measurement-warcio-code` |
| [measurement-wiremock-code](https://github.com/wiremock/wiremock) | `fafa0a9f76c7` | full archive; selected extracted paths (3 selected paths) | acquired | `quarantine/measurement-wiremock-code` |
| [measurement-zeek-code](https://github.com/zeek/zeek) | `82d9bcbe7756` | listed individual files (8 selected paths) | acquired | `quarantine/measurement-zeek-code` |
| [min](https://github.com/minbrowser/min) | `c92079cde045` | full source archive | acquired | `quarantine/min` |
| [native-messaging-sample](https://github.com/GoogleChrome/chrome-extensions-samples) | `e01a67d830c5` | full archive; selected extracted paths (3 selected paths) | acquired | `quarantine/native-messaging-sample` |
| [network-aioquic](https://github.com/aiortc/aioquic) | `6d36838d008c` | full archive; selected extracted paths (6 selected paths) | acquired | `quarantine/network-aioquic` |
| [network-atlantis](https://github.com/ProxymanApp/atlantis) | `6427600ec87d` | full archive; selected extracted paths (6 selected paths) | acquired | `quarantine/network-atlantis` |
| [network-chromium-code](https://github.com/chromium/chromium) | `faee0a28a27e` | listed individual files (6 selected paths) | acquired | `quarantine/network-chromium-code` |
| [network-curl](https://github.com/curl/curl) | `39ad9b077170` | listed individual files (29 selected paths) | acquired | `quarantine/network-curl` |
| [network-goproxy](https://github.com/elazarl/goproxy) | `a05e9220be0b` | full archive; selected extracted paths (14 selected paths) | acquired | `quarantine/network-goproxy` |
| [network-h11](https://github.com/python-hyper/h11) | `62c5068c9715` | full archive; selected extracted paths (5 selected paths) | acquired | `quarantine/network-h11` |
| [network-h2](https://github.com/python-hyper/h2) | `bc239af1d1b8` | full archive; selected extracted paths (6 selected paths) | acquired | `quarantine/network-h2` |
| [network-httptoolkit-server](https://github.com/httptoolkit/httptoolkit-server) | `14665bbcc39d` | full archive; selected extracted paths (4 selected paths) | acquired | `quarantine/network-httptoolkit-server` |
| [network-httptoolkit-ui](https://github.com/httptoolkit/httptoolkit-ui) | `c8e9f7e0b238` | full archive; selected extracted paths (4 selected paths) | acquired | `quarantine/network-httptoolkit-ui` |
| [network-martian](https://github.com/google/martian) | `0f7e6797a04d` | full archive; selected extracted paths (15 selected paths) | acquired | `quarantine/network-martian` |
| [network-mitmproxy](https://github.com/mitmproxy/mitmproxy) | `1ef9cec94a53` | listed individual files (20 selected paths) | acquired | `quarantine/network-mitmproxy` |
| [network-mitmproxy-rs](https://github.com/mitmproxy/mitmproxy_rs) | `51fe2b7c5aa8` | full archive; selected extracted paths (9 selected paths) | acquired | `quarantine/network-mitmproxy-rs` |
| [network-mockttp](https://github.com/httptoolkit/mockttp) | `7d03b2d97d1e` | full archive; selected extracted paths (4 selected paths) | acquired | `quarantine/network-mockttp` |
| [network-nghttp2](https://github.com/nghttp2/nghttp2) | `19d06e62185d` | full archive; selected extracted paths (8 selected paths) | acquired | `quarantine/network-nghttp2` |
| [network-pixelconfig-code](https://github.com/Yash-Vekaria/pixel-config) | `4426e5384893` | listed individual files (7 selected paths) | acquired | `quarantine/network-pixelconfig-code` |
| [network-quiche](https://github.com/cloudflare/quiche) | `77d50358f986` | listed individual files (18 selected paths) | acquired | `quarantine/network-quiche` |
| [network-rustls](https://github.com/rustls/rustls) | `7dcbe4c1ae12` | full archive; selected extracted paths (9 selected paths) | acquired | `quarantine/network-rustls` |
| [network-whistle](https://github.com/avwo/whistle) | `33820c617df1` | full archive; selected extracted paths (6 selected paths) | acquired | `quarantine/network-whistle` |
| [nyxt](https://github.com/atlas-engineer/nyxt) | `aeb6c72cf1ef` | full source archive | acquired | `quarantine/nyxt` |
| [playwright-mcp](https://github.com/microsoft/playwright-mcp) | `f183dad4a529` | full source archive | acquired | `quarantine/playwright-mcp` |
| [playwright-source](https://github.com/microsoft/playwright) | `ec17ddf9cd2f` | full archive; selected extracted paths (6 selected paths) | acquired | `quarantine/playwright-source` |
| [puppeteer-source](https://github.com/puppeteer/puppeteer) | `f891aaa1f64f` | full archive; selected extracted paths (6 selected paths) | acquired | `quarantine/puppeteer-source` |
| [qtwebengine](https://github.com/qt/qtwebengine) | `1c8944d4e038` | full archive; selected extracted paths (12 selected paths) | acquired | `quarantine/qtwebengine` |
| [qutebrowser](https://github.com/qutebrowser/qutebrowser) | `2bd75916a372` | full source archive | acquired | `quarantine/qutebrowser` |
| [ref-agentdojo](https://github.com/ethz-spylab/agentdojo) | `089ed468cf3e` | full source archive | acquired | `quarantine/ref-agentdojo` |
| [ref-agentic-sop](https://github.com/UWCSESecurityLab/agentic-browser-sop) | `de27d0cabe12` | full source archive | acquired | `quarantine/ref-agentic-sop` |
| [ref-agentlab](https://github.com/ServiceNow/AgentLab) | `cbc35a9bc0fa` | full source archive | acquired | `quarantine/ref-agentlab` |
| [ref-agenttrek](https://github.com/xlang-ai/AgentTrek) | `a8924dc31aab` | full source archive | acquired | `quarantine/ref-agenttrek` |
| [ref-apple-configd-reachability](https://github.com/apple-oss-distributions/configd) | `585b7f2fca29` | full source archive | acquired | `quarantine/ref-apple-configd-reachability` |
| [ref-apple-network-cmds](https://github.com/apple-oss-distributions/network_cmds) | `97e27e6244c1` | full source archive | acquired | `quarantine/ref-apple-network-cmds` |
| [ref-apple-xnu-network](https://github.com/apple-oss-distributions/xnu) | `f6217f891ac0` | listed individual files (12 selected paths) | acquired | `quarantine/ref-apple-xnu-network` |
| [ref-browsergym](https://github.com/ServiceNow/BrowserGym) | `c05d7f38f4f7` | full source archive | acquired | `quarantine/ref-browsergym` |
| [ref-camel](https://github.com/google-research/camel-prompt-injection) | `f083b6b39639` | full source archive | acquired | `quarantine/ref-camel` |
| [ref-cellmate](https://github.com/earlence-security/cellmate) | `07a99041a268` | full source archive | acquired | `quarantine/ref-cellmate` |
| [ref-comcast-network](https://github.com/tylertreat/comcast) | `145d02155cff` | full source archive | acquired | `quarantine/ref-comcast-network` |
| [ref-core-emulator](https://github.com/coreemu/core) | `a5cff7f99e02` | full source archive | acquired | `quarantine/ref-core-emulator` |
| [ref-freebsd-dummynet](https://github.com/freebsd/freebsd-src) | `43b0384bc7e8` | listed individual files (9 selected paths) | acquired | `quarantine/ref-freebsd-dummynet` |
| [ref-hammerspoon](https://github.com/Hammerspoon/hammerspoon) | `23e387e2805a` | full source archive | failed | `not acquired` |
| [ref-injecagent](https://github.com/uiuc-kang-lab/InjecAgent) | `f19c9f2c79a4` | full source archive | acquired | `quarantine/ref-injecagent` |
| [ref-iperf3](https://github.com/esnet/iperf) | `49f21b478b1a` | full source archive | acquired | `quarantine/ref-iperf3` |
| [ref-iproute2-netem](https://github.com/iproute2/iproute2) | `ac0b672924c8` | full source archive | acquired | `quarantine/ref-iproute2-netem` |
| [ref-libpcap](https://github.com/the-tcpdump-group/libpcap) | `e2fe69377b84` | full source archive | acquired | `quarantine/ref-libpcap` |
| [ref-libpointing](https://github.com/INRIA/libpointing) | `ecb67da58145` | full source archive | failed | `not acquired` |
| [ref-mahimahi](https://github.com/ravinet/mahimahi) | `f1346c38c415` | full source archive | acquired | `quarantine/ref-mahimahi` |
| [ref-mind2web](https://github.com/OSU-NLP-Group/Mind2Web) | `33bd95caeee7` | full source archive | acquired | `quarantine/ref-mind2web` |
| [ref-mind2web2](https://github.com/OSU-NLP-Group/Mind2Web-2) | `1fcbfda98bf5` | full source archive | acquired | `quarantine/ref-mind2web2` |
| [ref-mininet](https://github.com/mininet/mininet) | `6eb8973c0bfd` | full source archive | acquired | `quarantine/ref-mininet` |
| [ref-miwa](https://github.com/ferranschen/MIWA) | `dd4f34cd603e` | full source archive | acquired | `quarantine/ref-miwa` |
| [ref-online-mind2web](https://github.com/OSU-NLP-Group/Online-Mind2Web) | `f0d805ee0e9e` | listed individual files (12 selected paths) | acquired | `quarantine/ref-online-mind2web` |
| [ref-osworld](https://github.com/xlang-ai/OSWorld) | `b138d3482560` | full source archive | acquired | `quarantine/ref-osworld` |
| [ref-packetdrill](https://github.com/google/packetdrill) | `83f72d3f9085` | full source archive | acquired | `quarantine/ref-packetdrill` |
| [ref-seeact](https://github.com/OSU-NLP-Group/SeeAct) | `2434627b196b` | full source archive | acquired | `quarantine/ref-seeact` |
| [ref-tcconfig](https://github.com/thombashi/tcconfig) | `ee55d275603f` | full source archive | acquired | `quarantine/ref-tcconfig` |
| [ref-tcpdump](https://github.com/the-tcpdump-group/tcpdump) | `eebca9915dc3` | full source archive | acquired | `quarantine/ref-tcpdump` |
| [ref-toxiproxy](https://github.com/Shopify/toxiproxy) | `40f7fd31bee5` | full source archive | acquired | `quarantine/ref-toxiproxy` |
| [ref-visualwebarena](https://github.com/web-arena-x/visualwebarena) | `89f5af29305c` | full source archive | acquired | `quarantine/ref-visualwebarena` |
| [ref-wasp](https://github.com/facebookresearch/wasp) | `ffee6f41fde7` | full source archive | acquired | `quarantine/ref-wasp` |
| [ref-webarena](https://github.com/web-arena-x/webarena) | `dce04686a562` | full source archive | acquired | `quarantine/ref-webarena` |
| [ref-webarena-verified](https://github.com/ServiceNow/webarena-verified) | `6473f72db5dc` | full source archive | acquired | `quarantine/ref-webarena-verified` |
| [ref-weblinx](https://github.com/McGill-NLP/weblinx) | `9a7e814ffaac` | full source archive | acquired | `quarantine/ref-weblinx` |
| [ref-webvoyager](https://github.com/MinorJerry/WebVoyager) | `5a7896738c10` | full source archive | acquired | `quarantine/ref-webvoyager` |
| [ref-wireshark-capture](https://github.com/wireshark/wireshark) | `65d2cd5be485` | listed individual files (8 selected paths) | acquired | `quarantine/ref-wireshark-capture` |
| [ref-workarena](https://github.com/ServiceNow/WorkArena) | `e885130962f6` | full source archive | acquired | `quarantine/ref-workarena` |
| [ringer](https://github.com/sbarman/webscript) | `0ecafcbb238e` | full source archive | acquired | `quarantine/ringer` |
| [selenium-source](https://github.com/SeleniumHQ/selenium) | `68d2843e9d03` | full archive; selected extracted paths (8 selected paths) | acquired | `quarantine/selenium-source` |
| [servo](https://github.com/servo/servo) | `58fee6d54cf3` | listed individual files (13 selected paths) | acquired | `quarantine/servo` |
| [stagehand](https://github.com/browserbase/stagehand) | `5788121e60c2` | full source archive | acquired | `quarantine/stagehand` |
| [webkit](https://github.com/WebKit/WebKit) | `52387f678340` | listed individual files (8 selected paths) | acquired | `quarantine/webkit` |
| [webview2-samples](https://github.com/MicrosoftEdge/WebView2Samples) | `bd0048f4adb1` | full source archive | acquired | `quarantine/webview2-samples` |
| [wry](https://github.com/tauri-apps/wry) | `cab3eace9830` | full source archive | acquired | `quarantine/wry` |
<!-- END ACQUISITION INVENTORY -->
