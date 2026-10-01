# Bow Shock

A semi-automatic browser: a person and an agent work in the same visible
browsing session, with deliberate limits on what the agent can do and a native
connection to an agent runtime such as Codex.

This repository starts with research and reference acquisition. There is no
browser implementation or selected engine yet. Chromium, CEF, and other
embedding approaches are candidates to study, not adopted dependencies.

Current scope: a dedicated window, macOS first and Linux second. The model reads
native rendered DOM and proposes work; a separate OS input executor supplies
keyboard/mouse/scroll events. Request/response editing, traffic baselines and
alerts, external network perturbation experiments, and learned DOM-to-table
extraction are core requirements. Read [the product brief](docs/product-intent.md).

Read [BLACKBIRD.md](BLACKBIRD.md) for the working doctrine,
[the research index](papers/README.md) for the corpus,
[the reference manifest](QUARANTINE.md) for acquired source, and
[ISSUES.md](ISSUES.md) for open decisions. Work history lives in [journal/](journal/).

The important design question is where the browser enforces the person's
delegation: which tab, page version, actions, destinations, and duration belong
to the agent, and how the person takes control back. Engine embedding,
observation, actuation, and agent conversation are distinct decisions.

## Local setup

Python 3.13+ and Git suffice for the research utilities; no package installation
is needed. `pdftotext` is optional for reading downloaded papers. Source archives,
clean reference trees, document snapshots, and paper PDFs are local ignored
artifacts. The source catalogs and acquisition records are tracked.

```sh
python3 scripts/acquire.py --kind all
```

The utility resolves source repositories to commits on the first acquisition,
then reuses those pins. It preserves archives and never executes acquired code.
Failures remain explicit in `papers/acquisition.json`; consult the shopping list.
Use `--id SOURCE_ID` to acquire one source and `--kind refs`, `papers`, or `docs`
to select a class. `--restore` rebuilds extracted trees from preserved archives
and retains previous trees under `context/retired-references/`. Full Chromium
checkout/build is a separate, future task. Archives omit submodule contents;
the ledger records those gaps explicitly.
