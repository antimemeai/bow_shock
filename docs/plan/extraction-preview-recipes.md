# Extraction preview and recipe box

Operator direction, 2026-10-16: do not attempt to know how to extract every
website perfectly in advance. Step zero is a naive pass and one round of tweaks.
If that fails, operator and Oxcart bot dissect the page together and adjust until
it works. Save a dated recipe for the page type. A preview renderer is the stage
for evaluating the actual attempt.

## Working loop

1. The person opens a real page and asks for an organized extraction. Use the
   complete saved reading(s) as inputs. A matching saved recipe can supply a
   known approach on subsequent visits; a new type starts generically.
2. The bot makes an initial extraction and writes an actual result artifact.
   Render it in the preview stage alongside the browser. Keep the attempt and
   its input reading references available for inspection.
3. Evaluate that result against the page and collected sources. Make one round
   of tweaks to the generic attempt and render the revised result. This is the
   whole automatic step-zero allowance, not an unbounded background retry loop.
4. If it still fails, show concrete problems and bring operator and bot into
   page dissection: missing content, nested scroll region, collapsed section,
   mistaken entity boundaries, duplicate records, or poor output organization.
   Continue their directed adjustments until the result is useful.
5. Save the working approach as a dated page-type recipe. Later failures revise
   that approach with a new dated revision and preserve what changed.

The naive pass is allowed to fail. Failure supplies the next concrete problem;
it does not require a site-certification process or an all-sites abstraction.
One tweak limits automatic initial attempts; it does not limit operator-led
iteration or truncate content in any reading.

## Preview stage: first implementation unit

The active native application has a browser and conversation panel, but no
extraction-result renderer. Add a separate result stage with the browser still
available for comparison. The stage displays organized extraction output, not
the source DOM or a stream of model commentary. Support useful combinations of
sections, records, text and references rather than requiring a single table.

Use a persisted structured result artifact as the renderer's input. The bot and
operator evaluate the same attempt: an attempt identity binds input readings,
extraction instructions/recipe revision, the structured output and its rendered
preview. The bot must be able to inspect the actual preview representation;
reading only its own success message is not evaluation. Decide the native
rendering/inspection mechanism from the current UI and engine source before
implementation; no new library is selected here.

Keep earlier attempt output available when a revision fails, and make clear
which attempt is displayed. Show missing/unresolved content and let the operator
point to a bad or absent item and send a correction. Link factual output to its
supporting reading/fragment; identify summaries, normalization and inference.
The stage must make empty output, lost sections, duplicate records and broken
rendering visible rather than hiding them behind a finished-turn status.

Wire the first generic pass to the complete-reading archive already implemented.
Do not block the preview on continuous capture, every media type, a universal
page schema or automatic browser navigation. Add successive readings and needed
page-local exploration while investigating real extraction failures. Preserve
all harvested content; preview display choices are not capture limits.

## Recipe box

Each recipe records a stable identity and dated revision, a descriptive page
type and applicability cues, collection/exploration instructions, extraction
and organization instructions, useful output expectations, known problems and
the successful attempt that informed it. Record changes on revision. A recipe
describes how to handle a class of pages; the visit's profile details and other
extracted values belong in the result, not copied into the reusable instructions.

Store recipes locally using owned native/binary formats with adjacent files as
needed. Keep them inspectable and editable through Oxcart. Recipe matching is a
working hypothesis: apply, preview and adjust when a site's layout changes.
Save the approach that actually worked, including manual discoveries; do not
replace it with a claim that a page type is permanently supported.

## Direct live evaluation

On one actual page, produce and render a generic extraction; inspect source and
preview, make a meaningful correction and render the next attempt. If the page
needs further work, use the collaborative loop rather than silently adding more
automatic attempts. Save the successful dated recipe and use it on another
instance of that page type. Inspect whether the result carries the new page's
information, its sources and remaining gaps. A recipe run that fails simply
reopens the same troubleshooting loop.
