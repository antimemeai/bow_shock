# Native extraction preview implementation

2026-10-16. Implement the operator's generic pass, one automatic tweak, then
operator-led corrections with an actual result preview and immutable recipes.
Use complete reading archives already available; no browser action executor or
universal page-type classifier is needed for this unit.

Own a Foundation binary-plist workspace for visits, source-reading references,
attempt manifests, exact model submissions, rendered previews, full recipes and
activation events. New files are exclusive, private and never overwrite older
artifacts. A serial worker performs disk IO. Attempts bind their input readings,
predecessor, objective/correction and exact selected recipe. A recipe successor
is completely saved before a separate activation event changes the active choice.
Record stage events from the beginning; the richer metrics/proxy fast follow
can consume them later.

The agent writes a declarative binary-plist document with headings, paragraphs,
lists, arbitrary labeled records and tables, source references, interpretation
labels, coverage/issues and a proposed reusable recipe. Render with existing
AppKit text/layout machinery. Source page/model strings remain text, not executable
markup. The preview shows the result, supports source inspection and correction,
and retains actual renderer text/RTF/PDF plus source mappings. Blackbird can read
that representation for the single automatic tweak; pixel-level model inspection
is not added to its current file-tool interface.

Add Extract/Preview controls without replacing ordinary conversation. Human
readings accumulate per visit; navigation begins a new collection and does not
delete earlier attempts. Explicit recipe selection/use and full successor saves
come through the preview/recipe UI. Stop retires automation and preserves files.

Direct checks: native round trips/restart of whole recipe history and activation;
failed publication leaves the prior active recipe; invalid/missing output is
retained and stops after the one allowed tweak; renderer/source ranges preserve
actual content; a real live reading reaches model output and a rendered result.
Preserve unrelated clock work and Blackbird's independent checkout. Build in a
separate output directory while the earlier native run remains open.
