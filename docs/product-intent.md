# Product intent

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
