# Acquisition gaps and deferred material

This list separates failed retrieval, unread leads, and intentionally deferred
material. The catalogs record primary origins and the acquisition ledger records
actual attempts; a timeout does not establish a paywall. Retry ordinary acquisition
with `python3 scripts/acquire.py --id SOURCE_ID`. TLS certificate failures were
not bypassed. A downloaded login/JavaScript shell is not readable documentation.

## Scope intentionally deferred

- Full Chromium checkout/build and CEF binary SDK: acquisition here preserves
  focused engine source and interfaces, not a provisioned browser runtime.
- Online-Mind2Web's large dataset: a pinned source-only subset was acquired after
  an oversized incomplete download; model weights and benchmark data are separate
  decisions. Other references may already include published sample/benchmark data.
- BrowseSafe's linked Hugging Face data and weights: identified, not downloaded.
- CowPilot implementation source: the primary paper says it is not public.
  Author contact remains an operator decision; no message has been sent.
- WorkArena's ServiceNow instance and authenticated benchmark environments:
  reference source is not equivalent to service access or a reproducible task run.
- Submodules of WASP, Helena, Nyxt, DevTools MCP and other references: exact gaps
  are recorded per archive in the ledger. Acquire relevant gitlink-pinned modules
  before describing any tree as dependency-complete.
- Schema/extraction model weights, runtime dependencies, and a database: no
  selection or installation has been made.

## Readable vendor documentation

Current Meta Pixel reference/implementation/advanced-matching retrieval was
blocked, gated or incomplete through browser access. Some raw responses were
subsequently acquired, but they are not a verified current wire contract. The
PixelConfig primary paper and parser provide historical observed evidence;
confirm current vendor semantics before adopting field-specific assumptions.
Apple documentation snapshots can be rendering shells; original API descriptions
and independently read native code have separate provenance in the reports.

## Actual unresolved retrievals

The table below is generated after the final download pass. It includes leads
without a PDF URL. If a failed moving source has an acquired pinned counterpart,
that counterpart is stated rather than implying the source code is unavailable.

<!-- BEGIN ACQUISITION GAPS -->
| Source | Status / retrieval limit |
| --- | --- |
| [Beyond Fitts’ Law: Models for Trajectory-Based HCI Tasks](https://research.google/pubs/beyond-fitts-law-models-for-trajectory-based-hci-tasks/) (`accot-zhai-1997`) | ValueError: download is not a PDF |
| [Task interruption: Resumption lag and the role of cues](https://www.interruptions.net/literature/Altmann-CogSci04.pdf) (`altmann-interruption-2004`) | URLError: <urlopen error _ssl.c:1011: The handshake operation timed out> |
| [Apple archived pf.conf(5) manual](https://developer.apple.com/library/archive/documentation/Darwin/Reference/ManPages/man5/pf.conf.5.html) (`apple-pf-man`) | HTTPError: HTTP Error 404: Not Found |
| [net/base/network_change_notifier_apple.mm](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/net/base/network_change_notifier_apple.mm) (`chromium-apple-network-notifier`) | HTTPError: HTTP Error 503: Service Unavailable; pinned reviewed counterpart acquired as chromium-apple-network-notifier-reviewed |
| [net/base/network_change_notifier_linux.cc](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/net/base/network_change_notifier_linux.cc) (`chromium-linux-network-notifier`) | HTTPError: HTTP Error 503: Service Unavailable; pinned reviewed counterpart acquired as chromium-linux-network-notifier-reviewed |
| [End-user programming in the wild: A field study of CoScripter scripts](https://research.ibm.com/publications/end-user-programming-in-the-wild-a-field-study-of-coscripter-scripts) (`coscripter-field`) | No downloadable PDF URL in catalog |
| [The Out-of-the-Loop Performance Problem and Level of Control in Automation](https://doi.org/10.1518/001872095779064555) (`endsley-kiris-1995`) | HTTPError: HTTP Error 403: Forbidden |
| [The Information Capacity of the Human Motor System in Controlling the Amplitude of Movement](https://doi.org/10.1037/h0055392) (`fitts-1954`) | HTTPError: HTTP Error 404: Not Found |
| [The coordination of arm movements: an experimentally confirmed mathematical model](https://pubmed.ncbi.nlm.nih.gov/4020415/) (`flash-hogan-1985`) | TimeoutError: The read operation timed out |
| [Ten Challenges for Making Automation a Team Player in Joint Human-Agent Activity](https://ieeexplore.ieee.org/document/1363742/) (`klein-2004`) | URLError: <urlopen error [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: Hostname mismatch, certificate is not valid for 'cmapsconverted.ihmc.us'. (_ssl.c:1028)> |
| [Trust in Automation: Designing for Appropriate Reliance](https://doi.org/10.1518/hfes.46.1.50_30392) (`lee-see-2004`) | HTTPError: HTTP Error 404: Not Found |
| [HAR 1.2 author specification](https://www.softwareishard.com/blog/har-12-spec/) (`measurement-har-spec`) | URLError: <urlopen error [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: Hostname mismatch, certificate is not valid for 'www.softwareishard.com'. (_ssl.c:1028)> |
| [Zeek TLS visibility and logs](https://docs.zeek.org/en/current/reference/logs/ssl.html) (`measurement-zeek-tls`) | HTTPError: HTTP Error 429: Too Many Requests |
| [Optimality in human motor performance: ideal control of rapid aimed movements](https://pubmed.ncbi.nlm.nih.gov/3406245/) (`meyer-motor-1988`) | No downloadable PDF URL in catalog |
| [Meta Pixel implementation](https://developers.facebook.com/docs/meta-pixel/implementation/) (`network-meta-pixel-implementation`) | HTTPError: HTTP Error 404: Not Found |
| [A Model for Types and Levels of Human Interaction with Automation](https://doi.org/10.1109/3468.844354) (`parasuraman-2000`) | URLError: <urlopen error [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1028)> |
| [Hammerspoon native macOS automation](https://github.com/Hammerspoon/hammerspoon) (`ref-hammerspoon`) | TimeoutError: The read operation timed out |
| [libpointing transfer-function reference](https://github.com/INRIA/libpointing) (`ref-libpointing`) | IncompleteRead: IncompleteRead(16384 bytes read) |
| [Understanding Gaze and Scrolling Strategies in Text Consumption Tasks](https://www.microsoft.com/en-us/research/publication/understanding-gaze-scrolling-strategies-text-consumption-tasks/) (`turner-gaze-scroll-2015`) | TimeoutError: The read operation timed out |
| [WebArena Verified: Reliable Evaluation for Web Agents](https://openreview.net/forum?id=94tlGxmqkN) (`webarena-verified-2025`) | HTTPError: HTTP Error 403: Forbidden |
<!-- END ACQUISITION GAPS -->

For papers without accessible full text, lawful author/institutional copies are useful next acquisition candidates. Deep reading of already acquired artifacts remains an open task in [ISSUES.md](ISSUES.md); that is separate from retrieval failure.
