# Jev as an advisory network-observatory primitive

Research date: 2026-10-01. Read the installed TypeSafe skill, workspace JEV guide,
owned stdlib client, live model/API/Choice/confidence documentation, and the
candidate-selection and citation-check cookbooks. This research uses the existing
workspace tool; it does not adopt an SDK or integrate a product runtime.

Jev supplies typed judgments over supplied state. The current documented version
is `jev-1.13.0`; this experiment pins it and retains the returned model ID.
The API evaluates named questions in a batch and returns their answer map.
[Model reference](https://docs.typesafe.ai/models),
[API contract](https://docs.typesafe.ai/api).

## Useful boundaries for Bow Shock

Code should parse traffic, correlate exchanges, compute differences, track
capture coverage, select comparable baseline strata, and maintain source
identity. Jev can then interpret a bounded ambiguous difference, suggest a
page-type label, select a grounded candidate field, or rank relevant research
passages. These are candidate uses, not implemented features.

The pre-parsed extraction cookbook is especially relevant: find candidates,
ask for a selection with a no-match outcome, then copy and normalize the selected
source in code. That avoids generating a replacement value while preserving
the real limitation: omitted candidates cannot be selected. It fits native DOM
field grounding as well as network-field interpretation.
[Candidate extraction](https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook).

For literature work, the citation cookbook separates deterministic quote
location from semantic claim support. A typed judgment can assist a reviewer;
it cannot establish that an unfound quotation exists.
[Citation checks](https://docs.typesafe.ai/cookbooks/citation_check).

For tracker alerts, keep new recipients, data categories, and fields visible
even when an interruption also explains repeated requests. Missing worker
coverage or a truncated body should remain missing evidence. Payload text can
contain instructions; it remains untrusted observed data. No Jev result grants
browser, input, network-send, response-substitution, or database-write authority.

Choice confidence describes distribution concentration. Retain the probabilities
and evaluate thresholds against the actual workflow; one confident answer is
not a calibration result. The vendor also documents sensitivity to indirection,
arithmetic, context and adversarial state. Keep arithmetic and authority in code.
[Confidence](https://docs.typesafe.ai/confidence),
[known model limitations](https://docs.typesafe.ai/model-jaggedness/jev-1.13).

## Executed research pilot

One call through `/Users/patrickbeam/projects/codex-tools/jev.py` asked 12
independent Choice questions over constructed, nonprivate network-difference
fixtures. Expected labels were retained separately and were not sent to Jev.
The alternatives were substantive change, expected contextual variation, and
insufficient evidence. Each question names its own case and grants no action.

All **12/12** labels matched the construction-based expectations. Cases included
opaque session-value changes, expected retries, a new contact hash alongside
retries, missing worker capture, an unmatched page type, an approved event alias,
truncation, and an instruction-shaped string in observed payload text.
The returned model was **jev-1.13.0**. Reported usage was **3,394 input tokens**
and **628 output tokens**, with a **0.334-second** client round trip. At the
documented input price and free output, the illustrative list-price input cost
is **$0.000142548**; account billing was not measured.
[Pricing](https://docs.typesafe.ai/models).

The [fixtures and request](experiments/jev-network-cases.json) and
[result with full probabilities](experiments/jev-network-result.json) are tracked.
Raw request/response copies are in ignored `context/`. Credentials stayed within
the owned client's existing lookup; no environment file was copied or printed.

To repeat explicitly from the project root:

```sh
python3 -c 'import json; print(json.dumps(json.load(open("papers/experiments/jev-network-cases.json"))["request"]))' | python3 /Users/patrickbeam/projects/codex-tools/jev.py -
```

This small, deliberately specified sample establishes these outputs and the
working tool connection. It does not establish real-traffic accuracy, calibration,
privacy, robustness to arbitrary payload instructions, or baseline false-alarm
rates. Several controls are simple enough for deterministic rules; compare those
rules before spending inference on them. The useful next experiment is held-out,
reviewed capture differences with ambiguous semantics, coverage gaps, mixed
changes, and a deterministic comparison arm.
