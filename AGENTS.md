# Oxcart

Read [BLACKBIRD.md](BLACKBIRD.md) before working here. The project is a
semi-automatic browser: human and agent browsing together, with explicit,
bounded delegation and a native connection to an agent such as Blackbird.

Operator 2026-10-16: work on live sites throughout. The owned-page/catalog POC
and its capability-promotion gates are retired. Use direct checks of actual
behavior and fix encountered defects; do not invent certification work.
Internal protocol/state/decoder tests remain useful. Blackbird integration is
the current priority: read `docs/plan/live-blackbird.md`. Blackbird-side changes
use an isolated worktree; preserve its active main checkout. Bump the existing
Codex adapter directly when requested rather than studying release minutiae.

Research comes before product implementation. Start at [README.md](README.md),
then [papers/README.md](papers/README.md) and [ISSUES.md](ISSUES.md).

Keep literature and research reports in `papers/`. PDFs, `quarantine/`, and
`context/` are ignored. Reference source is for study, not shipment or automatic
adoption as a dependency. Record origins, pinned revisions, and restoration
commands in the tracked acquisition manifests. Preserve source archives; remove
nested Git metadata and filesystem detritus from extracted references.

Journal substantive work in `journal/`. Discuss dependency adoption with the
operator; studying a reference does not adopt it. Do not initialize Git above
this project. Never copy the parent `.env` or credentials into the repo.
