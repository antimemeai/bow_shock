# Product intent

## Primary purpose — operator clarification 2026-10-16

Oxcart extracts and organizes information encountered during a live page visit
in a visible, ordinary browser session. A complex profile or feed is the motivating
example: nested scrolling, expansion, lazy loading and virtualization expose
information across successive states. Saving offline HTML or taking one DOM
snapshot does not accomplish this task.

The person arrives at the page. The agent interprets the available content and
produces useful organized output whose structure follows the information and
the operator's purpose. Output need not reproduce the DOM or select only existing
source fields. It can combine fragments, normalize, group, deduplicate and
summarize, while retaining source references and distinguishing inference from
observed facts. Tables are one possible output, not the required shape.

Preserve complete requested readings and accumulate them across the visit so
information remains available after the page removes or replaces its nodes.
Track what was actually observed, what remains collapsed/unloaded and where
collection encountered a gap. A complete reading of one state is not a complete
visit or all information the remote site could provide.

Page-local exploration serves extraction: scrolling the right nested region,
expanding text or sections, and collecting newly revealed content. Human browsing
can supply those transitions initially; delegated local exploration requires
the missing native action machinery. General Blackbird-driven navigation is
advanced work and is not the next product milestone. The next milestone is a
useful accumulated, organized extraction from a real visit. See
[visit extraction](plan/visit-extraction.md).

## Implementation standard: attempt, preview, adjust

Start with a naive generic extraction and one round of tweaks. Judge the actual
result in a preview renderer beside the live page. The operator and Oxcart bot
need that stage to inspect what was collected, how it was organized, what is
missing, and whether duplicates or misleading groupings remain. A conversation
answer saying extraction succeeded is insufficient.

If the first attempt and tweak do not work, operator and bot dissect the live
page together and adjust collection, interpretation or rendering until they do.
Preserve a dated recipe for the successful page type in a recipe box. Recipes
record the reusable approach, applicability and known limitations, separately
from the visit's extracted data. Try relevant recipes on later visits and revise
them when the page changes by writing whole new immutable recipes that become
active and supersede their predecessors. Never delete earlier recipes. Preserve
activation history and the exact recipe used by each attempt. Retain readings,
blobs, attempts, results, previews and corrections for tracking and later study;
no automatic expiry or destructive history cleanup. Preview/extraction ships
first, with the recipe box following directly. No all-sites implementation or advance-perfect
page model is required. See [preview and recipes](plan/extraction-preview-recipes.md).

Operator update 2026-10-16: Oxcart develops against live sites. Retire owned-page
workflows and site-certification gates. Investigate concrete problems as they
appear. Blackbird integration is the immediate priority: a native conversation
panel shares fresh page observations with a real Blackbird session, accepts
objectives/steering and streams replies. Ship the Blackbird interface through
an isolated worktree. See [the live integration plan](plan/live-blackbird.md).

The operator's direction as clarified on 2026-10-01. This brief guides research;
it is not a final implementation specification. It takes precedence over earlier
generic assumptions about an agent driving browser tools.

## Platform and compatibility

Own a dedicated browser window. macOS first, Linux second. Human and model share
the actual session. Keep ordinary site compatibility and avoid gratuitously
unusual fingerprints. Site acceptance, tracking resistance, and input realism
are distinct properties to measure.

## Native observation and agent pipe

Provide native access to the locally rendered DOM and a native pipe to a coding
agent such as Codex. The onboard model's local versus remote inference placement
is still open. The observation interface should not give the model arbitrary
page JavaScript execution.

Use the engine's real document/layout state, with document/frame/origin identity
and observation time. DOM, accessibility tree, and screenshot reveal different
information. Treat hidden nodes, offscreen content, sensitive values, shadow DOM,
cross-process frames, and stale observations explicitly. Native renderer handles
must not outlive their engine-defined scope.

## Model proposals and OS execution

The model does **not directly drive the page**. A separate executor produces
actual OS keyboard, mouse, and scroll events. It owns authority checks, target
window/focus verification, timing, and takeover behavior.

The operator wants statistically human trajectories and timing with correctly
shaped, adaptive noise. Study joint movement, correction, dwell, scrolling, and
pauses in context. Independent jitter is not automatically human behavior.
OS delivery and a browser's trusted-event flag do not prove human origin or
site acceptance. The person must remain able to take control.

## External network perturbation

Deliberately simulate network interruptions **outside the browser**, so Chromium
experiences them through its normal OS/network path. The intent is to perturb
inferences made by sophisticated page/tracking code, rather than merely adapt
timing to real network loss.

Study a separate environment controller with the narrowest practical scope.
Dropped packets, route changes, and interface loss can produce different effects
on requests, retries, caches, timing APIs, and online/offline events. Measure
browser and server observations. Whether perturbations reduce an inference or
create a distinctive pattern is an empirical question. Research has changed no
host network configuration.

## Request/response workbench

The person can inspect and handcraft requests and responses. Study capture,
intercept/pause, edit, replay, synthesize, and body transformation separately.
Read-only callbacks do not provide a general response editor. Streaming,
redirects, caches, service workers, uploads, compression, WebSockets, and
authenticated replay have different API limits.

Keep human diagnostic powers distinct from the model's normal OS-input path.
Model-assisted drafting does not itself authorize sending a request or applying
a response edit. The design must name the execution owner of each operation.

## Logs, baselines, and alerts

Maintain a shared timeline for useful browser, DOM, input, request/response,
environment, and agent events. The concrete example is watching Meta/Facebook
Pixel requests, collecting a baseline, and alerting when patterns or details
change. Attribute requests using observed destinations and initiators.

Compare destinations, event categories, parameter names/types, payload structure,
frequency, ordering, and page/input/environment context. Separate raw evidence
from normalized features. Timestamps, identifiers, nonces, and retry bursts
should not silently produce change alarms. Explain intentional interventions,
capture gaps, baseline windows, and parser/policy revisions in an alert.

## Learned page types and database extraction

Learn page-type patterns and extract locally rendered DOM into a table for each
type. Examples and human corrections teach field meanings and repeated rows.
Study classification, grounding, normalization, validation, and storage separately.

Rows should retain source-page/observation provenance and extraction-pattern
version. Distinguish missing, empty, ambiguous, and inaccessible values. Layout
changes should cause a reviewable mismatch instead of silently writing the wrong
content into a field. No database or inference mechanism has been selected.

## Next work

The feature list remains open. Turn representative workflows into a reviewed
control and observation specification, then an implementation plan under
Blackbird. See [the synthesis](research-synthesis.md),
[research index](../papers/README.md), and [ISSUES.md](../ISSUES.md).
