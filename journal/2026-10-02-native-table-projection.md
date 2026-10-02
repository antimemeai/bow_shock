# Native fixture projection to table

The next useful join needs literal evidence and honest field states rather
than replacing withheld values with empty strings. Root wrote the native
projection sub-plan and compiled the actual Foundation entry scaffold. The
first direct expected-row oracle failed with unavailable/schema_version absent;
that red preceded the implementation.

The pure native function now maps the six fixed owned-product fields into the
existing table domain. USD is explicit; decimal digits never pass through
floating point. Quantity uses bounded ASCII u64 semantics. Whitespace source
can be Empty, covered-root absence Missing, withheld/private Inaccessible,
two literal USD alternatives Ambiguous, and failed schema text Invalid.
Every present source retains its literal fragment, native observation identity,
capture interval and evidence-only backend node. Private text is discarded
even if a caller mistakenly labels it observed. The batch stays partial.

This exposed a persistence contract gap: Empty and Ambiguous need their source
fragment, and all states need actual capture intervals after reopening. The
controller service owner is integrating optional backward-compatible domain
fields with exact older bytes preserved and mandatory actual provenance for
new native staging. Root does not independently alter that owner's schema.

Six actual Foundation probe methods pass, including all six states, exact large
decimal/integer values, unknown currency rejection, private marker omission and
native identity/shape/type/interval bounds. Compilation denies warnings. These
are native function oracles; no actual CEF/DB/UI end-to-end result is claimed.
Independent review, app wiring and capture-work/control qualification follow.

Independent review reproduced a native/domain identity mismatch: the initial
native function accepted CR/LF/NUL in copied IDs although the evidence library
rejects those identities. This was a downstream-denied contract failure, not
an admitted write. Root accepted it and now validates copied IDs and expected
run/origin without those control characters. The actual native probe includes
the reproduced bad surface/frame/document/capture cases. Final independent
recheck follows; no additional capability is enabled by this correction.

Root added two original static catalog fixtures for the upcoming joined
workflow. Amber supplies Value/Empty/Missing/Invalid/Inaccessible; Birch adds
literal-price Ambiguous and a valid normalized quantity. Both declare USD in
the source, have six fixed schema fields (with absent SKU on Amber), preserve
visible whitespace for the optional note, and carry only an artificial hidden
private marker. There are no forms, scripts, external resources or automated
page controls. The fixtures have not yet earned an actual native/UI workflow.

Final independent review in papers/native-table-projection-code-review.md
closed TP-1 after its own strict build, six-method suite and twelve direct
control-character identity probes. Additional type/UTF8/private/interval
oracles passed. The reviewed pure function is ready for native integration;
neither a CEF capture-work gate nor a saved-table UI is claimed by these results.
