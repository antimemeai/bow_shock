# Oxcart

The primary value is extracting and organizing information across a live page
visit, including successive scroll/expanded/lazy-loaded states. Output need not
match the DOM or be restricted to copying preselected fields. Preserve source
references and distinguish interpretation from observed facts. General
Blackbird-driven browsing comes later. Read `docs/plan/visit-extraction.md` and
the current clarification at the top of `docs/product-intent.md` before choosing
next work; these supersede earlier extraction/action sequencing.

Operator's implementation standard: a generic first attempt and one round of
tweaks are step zero. Render the extracted result in a preview stage so operator
and bot can evaluate it. If that still fails, operator and bot inspect the actual
page and iterate until useful. Save the working page-type approach as a dated,
reusable recipe. Do not require advance knowledge of every website. Read
`docs/plan/extraction-preview-recipes.md` before implementing this loop.

Recipe updates are whole new immutable recipes that supersede the previous
active recipe. Never delete or edit earlier recipes. Preserve activation history
and bind each attempt to the exact recipe it used. Preserve readings/blobs, all
attempts/results/previews and corrections for tracking and later study; no
automatic expiry or cleanup of this history. Historical retention defaults do
not govern the current extraction workflow. Preview/extraction ships first;
the recipe box follows directly.

Read [BLACKBIRD.md](BLACKBIRD.md) before working here. The project is a
semi-automatic browser: human and agent browsing together, with explicit,
bounded delegation and a native connection to an agent such as Blackbird.

Operator 2026-10-16: work on live sites throughout. The owned-page/catalog POC
and its capability-promotion gates are retired. Use direct checks of actual
behavior and fix encountered defects; do not invent certification work.
Readings must retain the whole harvested dataset in structured local files with
adjacent blobs; Blackbird chooses whole-file or ranged consumption. Do not add
content/count/time caps to harvests or inline a capped substitute. Read
`docs/plan/complete-readings.md`.
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
