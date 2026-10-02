# 2026-10-01 — Network environment and capture research

Expanded the outside-browser network research lane with 15 newly cataloged, fully pinned repositories, five papers, and eight documentation records in `papers/network-environment-sources.json`. Reused the existing Apple network_cmds catalog identity instead of duplicating its origin. Kept source acquisition and shared manifests with the root agent; no upstream code was executed, dependencies installed, permissions changed, packets injected, or host network configuration modified.

Resolved official repository HEAD pins through GitHub's API. For Wireshark, Apple XNU, and FreeBSD, verified bounded directory listings after recursive tree requests failed partway through transfer, then selected exact capture/PF/dummynet files and license records for study-only acquisition. The source snapshots do not identify running system binaries, and selected files are incomplete build trees.

Read targeted architecture and limitations in packetdrill, Mahimahi, Mininet, and the author draft of Dummynet Revisited. Reviewed netem's upstream manual, Apple reachability contract, Comcast's macOS backend and command tests, Toxiproxy's timeout implementation and connection tests, packetdrill's outbound packet verifier, and capture timing/statistics/offloading contracts. Marked README/API/source-path-only review separately from deep targeted reading and unresolved leads.

The most concrete finding is Comcast's macOS scope: fixed pipe 1, global PF reload/disable, and global dummynet flush on cleanup. Its target arguments are put into dynamic-flow masks rather than PF selection. Its command-string tests do not establish unaffected traffic or preservation of other owners' rules. This is a source-review finding, not an executed experiment.

Separated packet-delivery impairment, TCP stream faults, DNS failure, native path transitions, recorded HTTP replay, and passive packet observation. Proposed direct transport/path/page oracles and a separate confinement property, keeping privacy effectiveness a further measured question. The dedicated browser window alone does not identify which process group, socket, interface, or namespace receives a fault.

Recorded unresolved Apple sample-source download, the original dummynet PostScript reader limitation, scanned BPF text extraction, runtime macOS support and kernel identity, current browser process/path confinement, and absence of empirical tracking results in the report. Did not expand to unrelated scanning or offensive tooling collections.
