# Research corpus

The corpus supports Bow Shock's human-agent tandem browser. Primary sources
include engine documentation, source implementations, human-computer interaction
research, browser-agent systems, and their evaluation methods.

Start with [the synthesis](../docs/research-synthesis.md), then:

- [Browser engines and embedding](browser-engines.md).
- [Additional native shells and language bindings](native-shells.md).
- [Human-agent tandem literature](tandem-browsing.md).
- [Agent connections and automation plumbing](agent-connections.md).
- [Installed Codex 0.160.0 protocol/configuration preflight](codex-0.160.0-preflight.md).
- [Native trusted agent startup configuration review](native-agent-configuration-code-review.md).
- [Closed native proposal connection review](native-agent-connection-code-review.md).
- [Controller scoped agent proposal review](controller-agent-proposals-code-review.md).
- [Native clock startup source and observer review](native-clock-startup-source-review.md).
- [Direct native clock simplification review](native-clock-simplification-review.md).
- [Native selected-source proposal panel review](native-agent-panel-code-review.md).
- [Native tandem join review](native-agent-join-code-review.md), with
  [the joined agent task experiment](../docs/experiments/native-agent-workflow.md).
- [End-user browser automation predecessors](browser-predecessors.md).
- [Native DOM and runtime identity](native-browser-surfaces.md).
- [OS input and external network interventions](os-input-and-behavior.md).
- [Empirical typing/error/pointer data and browser triggers](empirical-human-input.md),
  with [original-artifact hashes and restoration](human-input-manifest.md).
- [Network observation, editing, and tracker alerts](network-observatory.md).
- [Matched Chromium 154 traffic streaming/editing implementation](native-traffic-154.md).
- [Expanded network quarantine and reading map](network-quarantine.md).
- [Jev for advisory network and extraction judgments](jev-network-judgments.md).
- [Fingerprint consistency and privacy experiments](fingerprints-and-privacy.md).
- [Learned rendered-DOM extraction](dom-to-tables.md).
- [Design tribunal and integrated dispositions](design-tribunal.md).
- [Implementation-plan tribunal and dispositions](plan-tribunal.md).
- [First Rust foundation code review](rust-basics-code-review.md).
- [Controller process bootstrap review](controller-bootstrap-code-review.md).
- [Native shell and private connection review](native-shell-code-review.md).
- [Owned-fixture native observation review](native-observation-code-review.md).
- [Independent control helper review](native-control-helper-code-review.md), and
  [its app packaging review](native-control-packaging-code-review.md).
- [Independent native control parent review](native-control-connection-code-review.md).
- [Closed Rust table service review](controller-table-service-code-review.md).
- [Native table parent review](native-table-connection-code-review.md).
- [Native table workflow review](native-table-workflow-code-review.md), with
  [actual catalog join and capture results](../docs/experiments/native-table-workflow.md).
- [Owned native lifecycle qualification](native-table-lifecycle.md) and
  [independent lifecycle review](native-table-lifecycle-code-review.md).
- [Native source-to-table projection review](native-table-projection-code-review.md).
- [Matched macOS process policies and identity](native-process-policies.md), with
  [selected-source acquisition manifest](native-matched-source-manifest.json).
- [Reviewed-table authority findings](table-evidence-code-review.md).

The resulting [design specifications](../docs/design/README.md) live in `docs/design/`.
Independent design reviews and their integrated research conclusions stay here.
The [implementation plan](../docs/plan/README.md) follows that design; its
independent plan reviews likewise remain in this corpus.

The `*-sources.json` files are the acquisition catalogs; `acquisition.json`
records actual local acquisition, pinned commits, byte identities, and failures.
PDFs are in ignored `pdfs/`, source archives and trees in ignored
`../quarantine/`, and documentation snapshots in ignored `../context/docs/`.
Read the [reference manifest](../QUARANTINE.md) for restoration and scope.

Reports distinguish reviewed evidence from research leads. Downloading a paper
or repository is acquisition, not evidence that every page/file was read.
Find inaccessible or deliberately deferred material in
[SHOPPING_LIST.md](../SHOPPING_LIST.md).
