# Native fixture table projection code review

2026-10-02. Independent BLACKBIRD review of
[the pure Foundation function](../native/cef/table_projection.mm),
[its declaration](../native/cef/table_projection.h),
[the subplan](../docs/plan/native-table-projection.md),
[journal](../journal/2026-10-02-native-table-projection.md),
[actual function oracle](../tests/table_projection.py) and its native probe.
Read the native reader's field/publication construction and the table domain's
Source/FieldState validation to assess the join. No product code was edited and
no CEF, Keychain, model, database or UI operation was launched by this reviewer.

## Finding and disposition

| ID | Severity | Finding | Disposition |
| --- | --- | --- | --- |
| TP-1 | Low | The native Text helper bounded copied identities but allowed NUL/CR/LF. Actual records carrying these characters in frame IDs returned a batch; LF also passed in surface/document/capture IDs. The evidence domain's small_id rejects them, contradicting the subplan's controller-contract alignment. | Closed: root added Identity validation for expected run/origin and every copied observation identity. Independent strict rebuild and all six methods passed; direct probes reject all three characters in each copied surface/frame/document/capture ID. The original downstream rejection made this a projection-contract mismatch rather than an authority bypass. |

No further concrete state-grounding or private-field disclosure was found in
the fixed owned-fixture pure function. Final native-to-service/database/UI
integration remains a separate gate.

## States and literal grounding

The output has one partial row in a fixed six-field order. Exactly six unique
known field IDs must arrive, each labeled observed or withheld. Reordering
incoming fields does not change the schema order. Duplicates, missing fields,
unknown fields and excess count reject the whole batch.

Value preserves literal source plus normalized value; Invalid preserves literal
source plus a fixed explanatory reason. Observed whitespace can become Empty
while retaining its actual fragment and backend node. Missing is reserved for
the native reader's covered-root missing_field reason. Other withheld fields
become Inaccessible and carry no fragment or node. The native reader separately
withholds zero-length observed text as text_unavailable; the projector rejects
an inconsistent observed empty-string record rather than inventing evidence.

Price accepts only explicit ASCII USD amounts with exactly two fractional
digits. Leading integral zeroes are removed using string operations; no decimal
passes through floating point. Two valid literal USD alternatives separated by
the fixed delimiter become Ambiguous, with their exact candidates and full raw
fragment preserved. Unknown currencies, signs, exponents, non-ASCII digits,
other separators and three alternatives are Invalid. This narrow fixture rule
does not discover currency or interpret arbitrary price widgets.

Quantity trims surrounding whitespace, accepts ASCII digits only and compares
the normalized decimal string to the exact u64 maximum. Zero and leading
zeroes are supported; overflow, negative numbers and non-ASCII digits are
Invalid. Text normalization trims whitespace without inventing replacements.
Private is always Inaccessible, even if mislabeled observed and supplied with
arbitrary text or malformed node/visibility metadata. That branch never copies
the private text. Withheld raw material is likewise ignored rather than logged
or forwarded. This is fixed-field exclusion, not a general secret classifier.

## Provenance, types and work limits

The function requires partial/fixture-only status, general observation disabled,
root-only coverage, child withholding and explicit non-atomic/non-actionable
flags. Actual CFBoolean values are required, preventing NSNumber1/0 confusion.
Origin must be a tuple equal to the trusted expected origin and carry the exact
Runtime.executionContextCreated.defaultContext provenance label. Run must
match the trusted expected run. Failed/opaque/URL-derived/wrong-scope records
cannot become ordinary rows.

Observation identities have byte limits; generations, timestamps and observed
backend nodes require positive NSNumber integers within signed64 range, with
CFBoolean and floating types rejected. Capture end must follow start with at
most3s duration. Nodes remain evidence-only: visibility stays
layout-present-occlusion-unknown, and no bounds, screen position or actionable
geometry is exported.

This function checks the trusted native producer's shape and copies provenance.
It does not independently authenticate a forged NSDictionary, repeat the
reader's live frame/context checks, compare time with the current OS clock, or
establish that a capture is still current. The table service/domain must bind
the actual host run, granted scope, live clock, capture interval and review
transaction. CEF/CDP namespace details are not projected into this table Source;
the existing reader's root-browser association must not be promoted into ID
equivalence or a child-frame join.

Input field count is fixed, each observed fragment is at most2048 UTF-8 bytes,
identities are at most128 bytes, and serialized output is at most16KiB. Bounds
are byte-based rather than UTF-16 character counts. Over-budget batches return
unavailable; they do not truncate into a seemingly complete row. The function
does not impose a budget on acquiring/parsing an arbitrary caller's input
dictionary before invocation; the bounded native producer remains its caller.

## Independent actual evidence

Compiled the actual function/probe with Foundation, ARC, C++20 and
Wall/Wextra/Werror into a private ignored path. Independently ran the six
committed methods: passed1.041s including compilation. They assert all six
states, literal candidates/fragments, exact decimal above binary-float integer
precision, exact u64 normalization, private marker exclusion, wrong identity/
origin/provenance, boolean confusion, shape/count and interval rejection.
After TP-1, independently rebuilt the revised actual source and ran all six
methods again: passed1.394s including compilation. Repeated supplemental
privacy/type/UTF-8/interval probes passed, along with all12 combinations of
NUL/CR/LF in surface/frame/document/capture IDs. Source inspection confirms the
same validation also applies to the trusted expected run/origin and copied run.
These are direct function results, not a mock or source-text receipt.

Supplemental actual probes verified: fractional and integral floating NSNumber
metadata denied; null/string/bool/negative/zero/oversized metadata denied;
2048-byte multibyte fragments accepted and2050/2052 bytes denied;128-byte
multibyte identities accepted and130 bytes denied; a five-observed-field batch
whose individually valid fragments exceed the16KiB serialized budget denied;
private oversized raw marker and malformed metadata excluded; reordered fields
preserved fixed output order; exact3s duration accepted and3s+1ns denied;
backwards intervals denied and zero-duration intervals allowed. TP-1 was
reproduced directly, including NUL/CR/LF, and then rejected after correction.

All probes use ignored context/review-table-projection/ and the actual source.
The original compiled-nil red and native producer evidence were supplied by
the owner and earlier reader work; this review does not recast them as a new
end-to-end result. Reviewed final table_projection.mm SHA256 is
`9de6936130d9a70163a5d0dd53f471712deb2455330a3109f57dfcc629eff2e5`.
Store persistence, review/reopen behavior, native UI and
control/capture-work gates remain pending. No dependency, detsim or mutation
work is introduced.
