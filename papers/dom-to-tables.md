# Learning page types and extracting rendered DOM into tables

Reviewed 2026-10-01. This report connects the operator's requested extraction
workflow to primary literature. Reading scope: EXALG's problem statement and
method framing; WebFormer's introduction, structural attention description,
results and error-analysis passages; abstracts of MarkupLM, ExtractGPT, and
Schema-Driven Information Extraction. Acquired implementation files are study
material; none has been run or adopted.

The intended input is the document actually rendered in the shared browser
session. Fetching the same URL again can produce different authentication,
JavaScript, personalization, or transient state. Observation should therefore
retain document/frame identity, origin, time, and relevant layout/visibility
information. Native DOM access alone does not establish that a value was visible
to the person. See [native surfaces](native-browser-surfaces.md).

## Relevant methods and their limits

[EXALG, Extracting Structured Data from Web Pages (2003)](https://www.microsoft.com/en-us/research/publication/extracting-structured-data-from-web-pages/)
learns structure from pages produced by a shared template. Its problem framing
assumes the pages have already been grouped and does not supply semantic column
names automatically. Bow Shock still needs page-type recognition and the
person's interpretation of fields. Repeated structure is useful evidence,
not proof that two visually similar values mean the same thing.

[WebFormer (2022)](https://research.google/pubs/webformer-the-web-page-transformer-for-structure-information-extraction/)
models HTML structure alongside text with specialized attention relationships.
This supports retaining structure rather than flattening a whole page into
plain text. Its benchmark results are not evidence that it captures our live
session, handles every dynamic document, or solves drift in an approved schema.

[MarkupLM (2022)](https://arxiv.org/abs/2110.08518) represents text and markup,
including XPath information. The source subset includes SWDE and WebSRC
preparation and evaluation code, useful for studying grounding and evaluation
formats. No model weights or datasets were acquired with that subset.

[ExtractGPT (2024)](https://arxiv.org/abs/2310.12537) studies product attribute
extraction using large language models and schema/example information.
Its source exposes schema construction, prompts, and evaluation. Attribute
extraction is a useful component comparison, but it does not establish live
DOM provenance, repeated-row boundaries, or correctness on unseen values in
our workflows.

[Schema-Driven Information Extraction from Heterogeneous Tables (2024)](https://aclanthology.org/2024.findings-emnlp.600/)
studies structuring tables according to a target schema across four domains.
This helps separate semantic schema mapping from recognizing a page template.
Its input task is not equivalent to capturing changing, cross-frame browser
state.

The demonstration-based predecessors [Helena and Rousillon](browser-predecessors.md)
are particularly relevant to teaching repeated rows and multi-page patterns.
They offer interaction precedents alongside model-based extraction. Neither a
paper result nor acquisition chooses our dependency or inference mechanism.

## Candidate workflow to evaluate

1. Group observations into a page type and show examples to the person.
2. Agree on field meanings, row boundaries, types, and missing-value rules.
3. Learn an extractor from examples and corrections; version the pattern and
   schema together with their training observations.
4. Extract from a fresh native snapshot and retain grounding for every field:
   document/frame identity, source node or region, and observation time.
5. Normalize and validate typed rows. Surface ambiguity and template mismatch
   for review before committing them to the page-type table.

Distinguish missing, empty, inaccessible, and ambiguous values. Record units,
locale, normalization rules, and duplicate-row policy. Do not silently merge
values from observations separated by a navigation or document replacement.
The database can preserve raw evidence references alongside normalized rows;
storage technology remains undecided.

## Evaluation questions

Evaluate correct fields and rows against human-reviewed ground truth, including
duplicates, optional columns, hidden content, pagination, virtualized lists,
late-loaded fields, and changed templates. Measure review effort and incorrect
writes as well as recall. A plausible JSON object does not prove extraction
accuracy. Hold out page instances and template changes to test generalization.
Use explicit negative examples for adjacent but semantically different page
types.

This is a proposed research workflow, not an implemented extractor. The next
step is to pick representative page families and establish their observation
and schema contracts before choosing a model or database.

Acquisition: [extraction catalog](extraction-sources.json),
[predecessor catalog](predecessor-sources.json), and [ledger](acquisition.json).
