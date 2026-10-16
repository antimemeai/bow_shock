# Evidence, traffic baselines and learned tables

Current operator clarification, 2026-10-16: the extraction product accumulates
information across a live visit and organizes it independently of DOM shape.
The candidate-selection-only restrictions below describe the earlier table
design, not the current extraction boundary. Source references remain necessary;
semantic restructuring and synthesis are allowed. Complete requested readings
are retained without the earlier harvest caps. Current extraction data and
recipe history are preserved for tracking and later study; the automatic expiry
and deletion defaults below are historical and do not govern this workflow.
Recipe updates are whole new immutable documents with separate activation
history; earlier recipes remain intact. See
[visit extraction](../plan/visit-extraction.md) for the current direction.

Status: design proposal, 2026-10-01. This component turns native session evidence
into inspectable history, change alerts and reviewed rows. It does not grant
input, network or model-export authority. [Network control](network-control.md)
owns exchange interception; [runtime observation](runtime-observation.md) owns
DOM/AX capture and its coverage limits.

## Local evidence store

Proposal: an application-owned SQLite database for structured session events,
indexes, baselines, patterns and reviewed rows, with bounded content-addressed
blob storage for larger bodies/snapshots. WAL and schema migration policy need
implementation review. SQLite is proposed, not installed or adopted. Session
capture is local by default; sending evidence to a hosted model or coding agent
requires the independent export scope in [the bridge](agent-bridge.md).

Events record `eventId`, `sessionId`, source and source sequence, monotonic time,
wall time, correlation/causal references, document/exchange/execution identity
when known, capture policy version, context and coverage. Wall-clock corrections
must not reorder a source's monotonic sequence. Cross-process clocks are joined
with calibration uncertainty; the UI must not manufacture an exact total order
between overlapping measurements. Request, connection, frame and packet IDs
are different identities; their joins can be partial or unknown.

Preserve source observations as recorded and derive redacted/normalized views
with separate identities and transformation versions. A body labelled complete
must say complete at which layer: decoded browser bytes, proxy stream or wire
payload. Hash before text conversion where byte identity matters. A decoded
UTF-8 string cannot stand in for original binary or compressed bytes. Raw and
normalized hashes are separate. Provenance records source revision/build and
capture settings; it never calls a browser cache hit a packet receipt.

The store has capture and retention budgets for each class: metadata, DOM,
headers, body bytes, screenshots, input features and packet artifacts. Streaming
captures truncate visibly; no unbounded buffering. Events describe dropped
items, lost intervals, evictions and truncation. If even the gap record cannot
be persisted, the session's coverage is unhealthy until reconciled. Disk exhaustion
suspends delegated work requiring durable execution evidence and disables new
interceptions; ordinary human browsing can continue with a visible capture gap.
Do not claim all traffic or every input is logged when a surface cannot see it.

Raw sensitive capture is an explicit, session-scoped policy with retention and
access controls. Default model/alert views remove credentials and unnecessary
identifiers before inference. Authorization/Cookie headers are only part of
the problem: query/form/body fields, binary data, encoded nested content,
screenshots, HTML and sidecars can contain secrets. Unknown types are withheld
from model export until supported or specifically reviewed. Equality tokens,
hashes of contact data and normalized identifiers are still linkable data.
Different audiences may receive different views; a redacted alert must not link
through to an unauthorized raw blob. Local same-UID shell access is governed
by the trusted-peer boundary, not these model-facing redaction rules.

Deletion and retention expire raw blobs, indexes and derived descendants whose
policy requires it. A local append-only event history means source events are
not silently rewritten during analysis; it is not an undeletable archive.
An export/package must enumerate its actual evidence, gaps, transformations and
secret handling. HAR/WARC support is a later capability proposal, not proof of
complete capture or automatic replay correctness.

Every derived artifact carries a lineage policy at creation: source/effective
origins, data classes, audience/access intersection, allowed uses and expiry no
later than the most restrictive parent, unless a parent explicitly permits a
reviewed retention transition. This includes staged values, literal pattern
examples, equality tokens, baseline features and summaries. A model's claimed
anonymization or a source hash does not strip those restrictions.

Defaults: unsaved staging/examples/raw diagnostics expire at session close;
Save draft, baseline promotion and table commit each show the exact retained
data and choose an explicit local retention policy (working default 30 days,
adjustable only within source permissions). They do not silently preserve all
source blobs. An allowed extension requires a concrete human decision while
the affected source/derived content is still available. If a parent forbids the
transition, reject the save/commit rather than laundering it through a table.
Separately reviewed structural pattern/schema data can survive without private
examples only if the retained artifact actually excludes those values.

Input takeover preserves staging within its existing policy. Observation/export
revocation stops future collection/use/disclosure, not automatic deletion of
permitted local records. Delete/required expiry removes the specified artifact
and restricted descendants, updates saved-draft/pattern/baseline availability,
and marks expired dependencies as gaps. A staged value requiring expired evidence
becomes unreviewable and needs fresh capture; it is never an empty/validated
field. A committed row survives source deletion only under its separately
reviewed retention policy, with a provenance gap; required descendant
deletion removes it too. An incomplete baseline cannot keep claiming the old
sample count/coverage. Inspect actual survivors rather than treating a raw-blob
deletion as evidence that all linkable derivatives disappeared.

Required deletion/expiry supersedes ordinary scope-revocation grandfathering of
an admitted table commit. The lifecycle owner fences affected staging/commit
IDs and descendants immediately from application reads, review and exports,
including a writer's retained input. Cancel/roll back work where still safe;
if it already crossed the irreversible DB boundary or its result is unknown,
reconcile it and purge affected rows/blobs before publishing them as usable.
The lifecycle fence survives until all affected writers are quiescent and the
actual descendants have been removed; a later correction cannot revive them.
Deletion intent/fence must be durable before reporting processed deletion; if
storage is unhealthy, report requested/pending or failed while access stays denied.
Restart reconciles pending deletion and expired policies before serving data.
Deletion is complete only after in-flight persistence and cleanup are resolved,
not on UI acknowledgement or raw-source removal. Expiry immediately removes
availability; physical purge can remain pending with visible cleanup state.
This is not a promise of instantaneous disk erasure during a stalled transaction.

## Baselines describe comparable sessions

A baseline has an explicit version, page/task family, browser build, profile and
consent state, capture mode, workload, intervention policy and retained sample
set. It retains sample count, observation coverage, learned variability rules
and operator-reviewed semantic rules. A single capture is an example, not an
estimated timing distribution. A changed runtime or capture mode creates a
different stratum or makes comparison inconclusive.

Deterministic comparison precedes inference. Group requests using reviewed
recipient/method/path/event keys, then compare field presence/type/value where
permitted, data categories, recipients, counts, retry/redirect relations and
ordering constraints. Normalize a nonce only after deciding what its presence,
length/type and equality relationship still need to reveal. Do not globally
ignore order, duplicates or numeric differences. Timing uses repeated comparable
sessions with distributional spread, not a golden trace threshold.

Each alert contains concrete delta evidence, comparable baseline ID/sample
count, capture gaps, intervention context, and distinct change categories.
Intentional interruptions can explain retries without explaining a new recipient
or contact hash. An alert can therefore contain both expected variation and
new disclosure. Suppression rules are scoped/versioned and reversible; missing
coverage cannot silently become “unchanged.” Alerts initially appear in the local
UI; external messaging destinations are not configured or authorized by this
design task.

### Meta Pixel example

1. The person selects a page workflow and traffic associated with a reviewed
   recipient/event rule. “Meta Pixel” is a label supported by observed URLs and
   payload patterns, not an assertion of the remote physical server's location.
2. Capture multiple normal human sessions with known consent/session/build and
   coverage. Review varying IDs, event names, data categories, repeated requests
   and sequence constraints before promoting a baseline.
3. A later session repeats an event after an intentional path interruption.
   Record the intervention as context and compare retries separately.
4. If that session also adds an email-derived hash or a new recipient, preserve
   that distinct delta and alert despite the expected retry behavior.
5. If workers or bodies were not observed, report an inconclusive portion rather
   than claiming no change. The UI can show the precise raw bytes only within
   the person's permitted local raw-evidence scope.

This detects changes in observable behavior. It does not establish what Meta
inferred, which server received every byte, or that perturbation reduces tracking.

## Jev and other typed judgments

Jev can suggest a page family, select among grounded field candidates, prioritize
an ambiguous delta or supply independent semantic flags. Code maintains parsing,
counts, arithmetic, coverage, source identity and permission. Use Choice for
genuinely exclusive alternatives with a no-match/unknown option; use independent
Noul judgments for coexisting categories rather than forcing a single explanation.
Keep model version, supplied evidence scope, output probabilities and decision
threshold version beside the suggestion.

The existing constructed 12-case pilot establishes a working advisory tool,
not calibration or real-traffic accuracy. Hosted Jev consumes only an approved
redacted view; it is not assumed to be an onboard local model. High confidence
cannot approve a send, silence a concrete disclosure, or write a table. Use a
deterministic rule instead where it expresses the criterion directly. Compare
real reviewed ambiguous captures and candidate fields before adopting a model
SDK or tuning thresholds.

## Page-family patterns and table commits

A `PatternVersion` describes page family and allowed origins, positive and
negative examples, structural/semantic row boundaries, field candidate rules,
supported observation features, and its paired `SchemaVersion`. The schema
defines column meaning, type, units, locale, requiredness, normalization and
deduplication/update policy. A DOM pattern recognizes structure; it does not
decide semantic column meaning without reviewed examples.

The person teaches by selecting representative rows/fields in a current native
snapshot and naming their meaning. The model proposes a pattern/schema and
shows examples plus alternatives. Use positive and adjacent negative pages
to reveal false matches. Keep source evidence for training examples within its
retention/export policy; learning is not a permission to retain everything.

Extraction uses the actual rendered session, not a second fetch of the URL.
For each field, code supplies grounded candidates; a model can select a candidate
or no match, then code copies and normalizes that candidate. Generated replacement
values are suggestions, never extracted facts. Preserve source text/attribute,
snapshot/frame/document/origin, node/region identity, capture interval, visibility,
normalization rule and ambiguity. Native node IDs are transient; the retained
snapshot/evidence identity is the durable provenance.

| Field state | Meaning in review/storage |
| --- | --- |
| Value | A grounded source value, plus typed normalization result |
| Empty | Source exists and is empty under the field rule |
| Missing | Expected source was absent in the covered observation |
| Inaccessible | Required frame/region/content was outside coverage or scope |
| Ambiguous | Multiple candidates or uncertain row/meaning |
| Invalid | A grounded value failed the schema/normalization rule |

Rows enter a staging batch with extraction ID, pattern/schema versions, source
snapshots, scope and completeness. The person sees source highlights beside
the typed table, including unresolved states and conflicting duplicate keys.
Commit is a distinct human-controlled transaction over a staging ID and exact
immutable version/hash. A changed staged batch invalidates that approval.
The model can propose corrections; it cannot insert rows. Initial behavior
requires review for each commit; later standing table-write permissions would
be a separately designed and reviewed delegation mode.

An editable `StagingId` has content versions. Each approved immutable version
receives a host-issued `CommitId` bound to its staging version/hash, schema,
pattern, source scope and retention choice. Before enqueueing any write, the
authority owner serializes `commit_admission` against revocation: recheck all
origins/policies and approval, then either reject the whole batch or mark that
exact commit irrevocably `committing`. Preparation/queues remain cancellable
before this point. Revocation that wins the ordering commits zero rows; admission
that wins may finish its already-started DB transaction afterward. The UI shows
that distinction and never reports revoked/zero-write for a committing batch.
Stop cancels new/queued commits, not an admitted transaction that cannot safely
be withdrawn. Scope changes never silently remove a subset of reviewed rows.

This irrevocable-admission rule concerns ordinary future-use scope revocation.
Required deletion/expiry follows the lifecycle fence above and can suppress/purge
the resulting persistence instead of publishing a now-forbidden batch.

The DB transaction atomically writes the rows plus the unique `CommitId` and
its actual hash/version/result. Reconciliation reads that record after lost
acknowledgement; authority admission alone cannot be called durable success.
Ambiguous in-progress transactions stay `committing_unknown` until the writer/
database is reconciled. No automatic retry creates a new ID. Database uniqueness
and upsert rules are reviewed domain choices, not inferred from similar strings.
The staging version becomes terminal at admission. A later correction gets a
new staging/commit identity explicitly linked to the prior commit and reviewed
insert/update semantics. Old committed hash/version cannot satisfy a changed
approval. Conflicting reuse returns a conflict plus the actual committed record.
Preserve append/update history and provenance within the selected retention.

Virtualized lists, pagination, collapsed content and late loads make observed
rows a partial set. The table labels its captured range and cannot claim an
entire site collection. Additional scrolling/navigation requires the separate
input grant; each new document generates another snapshot. Cross-document
fields join only under an explicit schema join rule, never by accidental node
ID reuse. Drift invalidates the affected pattern: stage uncertain output and
request examples rather than silently learning a new rule while writing rows.

## Direct evaluation

| Fault class | Direct oracle |
| --- | --- |
| Capture loss, redirect/cache/worker/stream ambiguity | Owned endpoints' known bytes/events and browser capture coverage, with explicit partial outcomes |
| Baseline normalization hides a disclosure | Seed new field/recipient/contact hash alongside expected nonce/retry variation; distinct delta remains visible |
| Poor baseline comparability | Change build/consent/intervention/capture coverage; label mismatch or inconclusive comparison |
| Wrong row/field or hidden value | Reviewed rendered fixtures and source highlights; exact row/field grounding plus missing-state precision |
| False page-family match or layout drift | Held-out adjacent negative pages and changed templates; no unreviewed writes |
| Partial/virtualized collection | Known fixture row set and viewport states; correct partial-range label rather than invented completeness |
| Duplicate/crash/different reviewed content | Batch transaction oracle and resulting table state; one commit of exactly the reviewed rows |
| Redaction/export leak | Inspect the actual outgoing payload and evidence links across headers, bodies, screenshots and descendants |

Measure incorrect commits, field/row precision and recall, useful partial results,
review/correction time and missed meaningful changes. These are proposed
experiments, not completed product tests.

Source basis: [DOM extraction](../../papers/dom-to-tables.md),
[browser predecessors](../../papers/browser-predecessors.md),
[network measurement and logs](../../papers/network-measurement-and-logs.md),
[Jev pilot and primary documentation](../../papers/jev-network-judgments.md).
Primary grounding includes [EXALG](https://www.microsoft.com/en-us/research/publication/extracting-structured-data-from-web-pages/),
[WebFormer](https://research.google/pubs/webformer-the-web-page-transformer-for-structure-information-extraction/),
and [TypeSafe candidate selection](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook).
