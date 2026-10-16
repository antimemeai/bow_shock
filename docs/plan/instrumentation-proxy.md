# Fast follows: instrumentation and bidirectional proxy

Operator direction, 2026-10-16: fast-follow the extraction/preview/recipe loop
with metrics and instrumentation, plus a bidirectional proxy for capture and
editorial work on traffic, including ads. The earlier interpretation that
"fast follow" meant only the recipe box was incorrect.

## Instrumentation and useful metrics

First implementation is available: the native extraction workspace records
stage events and `scripts/extraction-metrics.py WORKSPACE` writes a new immutable
metrics snapshot. It reports stage intervals within the same host run, reading
text bytes, phases, model outcomes, validation errors, previews, cancellation
and recipe activation. Raw and derived data stay distinct. Malformed result
fields remain explicit rather than crashing aggregation. Native controlled-
outcome checks cover initial/tweak/manual, missing/invalid output and Stop, with
metrics checked against those actual emitted events/artifacts. See
[workspace usage](../extraction-workspace.md). The native bidirectional traffic
workbench is now implemented: [controls, archive and limits](../traffic-workbench.md).
It streams passive bodies, supports explicitly armed request/response edits and
preserves original/edit/command outcome artifacts. Native protocol/storage checks
and the signed build pass; practical live editing remains for the operator's
return. A richer in-app metrics view remains follow-on work.

Join visit, document/capture, extraction attempt, preview and exact recipe
identities in a local timeline. Record stage start/end/failure, cancellations,
collection gaps, bytes retained, newly observed content, repeated/conflicting
records, corrections, and the operator/bot evaluation outcome. Keep the original
events and the version of any derived metric so later study can recompute it.
Basic correlation belongs in the initial extraction artifacts; a comprehensive
dashboard is not a prerequisite to the first useful preview.

Show time spent collecting/interpreting/rendering, what each attempt changed,
and which recipe produced it. Treat counts as observed quantities, not claims
of complete collection. Failed and superseded attempts remain in comparisons;
do not silently measure only the successful run. Explicitly distinguish an
operator judgment from a bot judgment and an unreviewed result.

For native interaction, join intended actions, generated OS events, actual
browser-received events and resulting page/network changes. Retain the exact
empirical behavior-profile revision and source data used; see
[empirical input](empirical-input.md). Key-triggered requests can happen during
typing and corrections, before a field reaches its final intended value.

## Bidirectional capture and editorial work

Provide a proxy/workbench that captures traffic in both directions and supports
editing outbound requests and inbound responses: status/method/URL as applicable,
headers and bodies. Ads and tracker flows are concrete initial uses alongside
page content traffic. Passive capture and armed editing are visible modes;
opening an inspector must not silently pause or modify every request.

Retain four distinct artifacts when an edit occurs: the original page request,
the request actually sent upstream, the upstream response and the response
actually delivered to the browser. Retain the edit instructions, exact applied
revision and outcome. A response change does not rewrite what the upstream
server already received. Keep original binary bodies in adjacent blobs and
derive decoded/editable views separately; display choices do not truncate the
retained originals. Stream captured data to storage rather than accumulating
whole exchanges in UI memory. Storage failures and incomplete streams stay
explicit; preserve the data already collected.

Join traffic to visits, documents, source readings, attempts and recipes where
the observed identities support that relationship. Redirect hops, frame/worker
traffic and ambiguous attribution stay distinguishable. Ad/tracker labels are
derived annotations, not replacements for the underlying traffic. Preserve
their rule versions so a later study can revisit classification and changes.

Provide inspect, pause, edit, forward and cancel with visible original/modified
views. Edited requests and responses must reach their actual recipients; a
text editor alone is not a bidirectional proxy. Resolve pending exchanges on
Stop/close without waiting for model inference. Add replay, reusable edit rules
and baseline/change comparisons as direct follow-on work on real traffic.

## Implementation approach and direct live checks

The active native target now includes an owned CEF Network/Fetch capture/editor.
See [the implementation unit](native-traffic-workbench.md) and
[matched runtime source study](../../papers/native-traffic-154.md).
The older network studies contain useful CEF/protocol/proxy source findings,
but their broad experimental topology and certification sequence are superseded.
The matched runtime supplies request changes and response fulfillment. No proxy
library, system routing change or TLS trust configuration was introduced.

Start with live browsing: inspect actual exchanges, correlate them with the
visit, change a selected request and a selected response, and inspect what was
actually sent and displayed. Address redirects, encodings, cache/worker paths
and stream behavior as the chosen site exposes them, recording specific gaps.
Check metrics against those same events and stored artifacts; do not add a
second certification system around the timeline. Preserve original traffic,
edits, attempts and recipe history for tracking and later study.
