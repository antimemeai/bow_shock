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

Final initial-pass inventory: **62 acquired source collections, 57 PDFs, and 93 documentation/source snapshots**, from 232 catalog entries. Some collections share an upstream repository. Unresolved entries are in [the shopping list](SHOPPING_LIST.md).

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
| [min](https://github.com/minbrowser/min) | `c92079cde045` | full source archive | acquired | `quarantine/min` |
| [native-messaging-sample](https://github.com/GoogleChrome/chrome-extensions-samples) | `e01a67d830c5` | full archive; selected extracted paths (3 selected paths) | acquired | `quarantine/native-messaging-sample` |
| [network-chromium-code](https://github.com/chromium/chromium) | `faee0a28a27e` | listed individual files (6 selected paths) | acquired | `quarantine/network-chromium-code` |
| [network-pixelconfig-code](https://github.com/Yash-Vekaria/pixel-config) | `4426e5384893` | listed individual files (7 selected paths) | acquired | `quarantine/network-pixelconfig-code` |
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
| [ref-apple-network-cmds](https://github.com/apple-oss-distributions/network_cmds) | `97e27e6244c1` | full source archive | failed | `not acquired` |
| [ref-browsergym](https://github.com/ServiceNow/BrowserGym) | `c05d7f38f4f7` | full source archive | acquired | `quarantine/ref-browsergym` |
| [ref-camel](https://github.com/google-research/camel-prompt-injection) | `f083b6b39639` | full source archive | acquired | `quarantine/ref-camel` |
| [ref-cellmate](https://github.com/earlence-security/cellmate) | `07a99041a268` | full source archive | acquired | `quarantine/ref-cellmate` |
| [ref-hammerspoon](https://github.com/Hammerspoon/hammerspoon) | `23e387e2805a` | full source archive | failed | `not acquired` |
| [ref-injecagent](https://github.com/uiuc-kang-lab/InjecAgent) | `f19c9f2c79a4` | full source archive | acquired | `quarantine/ref-injecagent` |
| [ref-libpointing](https://github.com/INRIA/libpointing) | `ecb67da58145` | full source archive | failed | `not acquired` |
| [ref-mind2web](https://github.com/OSU-NLP-Group/Mind2Web) | `33bd95caeee7` | full source archive | acquired | `quarantine/ref-mind2web` |
| [ref-mind2web2](https://github.com/OSU-NLP-Group/Mind2Web-2) | `1fcbfda98bf5` | full source archive | acquired | `quarantine/ref-mind2web2` |
| [ref-miwa](https://github.com/ferranschen/MIWA) | `dd4f34cd603e` | full source archive | acquired | `quarantine/ref-miwa` |
| [ref-online-mind2web](https://github.com/OSU-NLP-Group/Online-Mind2Web) | `f0d805ee0e9e` | listed individual files (12 selected paths) | acquired | `quarantine/ref-online-mind2web` |
| [ref-osworld](https://github.com/xlang-ai/OSWorld) | `b138d3482560` | full source archive | acquired | `quarantine/ref-osworld` |
| [ref-seeact](https://github.com/OSU-NLP-Group/SeeAct) | `2434627b196b` | full source archive | acquired | `quarantine/ref-seeact` |
| [ref-visualwebarena](https://github.com/web-arena-x/visualwebarena) | `89f5af29305c` | full source archive | acquired | `quarantine/ref-visualwebarena` |
| [ref-wasp](https://github.com/facebookresearch/wasp) | `ffee6f41fde7` | full source archive | acquired | `quarantine/ref-wasp` |
| [ref-webarena](https://github.com/web-arena-x/webarena) | `dce04686a562` | full source archive | acquired | `quarantine/ref-webarena` |
| [ref-webarena-verified](https://github.com/ServiceNow/webarena-verified) | `6473f72db5dc` | full source archive | acquired | `quarantine/ref-webarena-verified` |
| [ref-weblinx](https://github.com/McGill-NLP/weblinx) | `9a7e814ffaac` | full source archive | acquired | `quarantine/ref-weblinx` |
| [ref-webvoyager](https://github.com/MinorJerry/WebVoyager) | `5a7896738c10` | full source archive | acquired | `quarantine/ref-webvoyager` |
| [ref-workarena](https://github.com/ServiceNow/WorkArena) | `e885130962f6` | full source archive | acquired | `quarantine/ref-workarena` |
| [ringer](https://github.com/sbarman/webscript) | `0ecafcbb238e` | full source archive | acquired | `quarantine/ringer` |
| [selenium-source](https://github.com/SeleniumHQ/selenium) | `68d2843e9d03` | full archive; selected extracted paths (8 selected paths) | acquired | `quarantine/selenium-source` |
| [servo](https://github.com/servo/servo) | `58fee6d54cf3` | listed individual files (13 selected paths) | acquired | `quarantine/servo` |
| [stagehand](https://github.com/browserbase/stagehand) | `5788121e60c2` | full source archive | acquired | `quarantine/stagehand` |
| [webkit](https://github.com/WebKit/WebKit) | `52387f678340` | listed individual files (8 selected paths) | acquired | `quarantine/webkit` |
| [webview2-samples](https://github.com/MicrosoftEdge/WebView2Samples) | `bd0048f4adb1` | full source archive | acquired | `quarantine/webview2-samples` |
| [wry](https://github.com/tauri-apps/wry) | `cab3eace9830` | full source archive | acquired | `quarantine/wry` |
