# Control-only Rust controller bootstrap

The native AppKit parent needs a real private-pipe child before integrating CEF.
Read AGENTS, BLACKBIRD, research/issue indices, Rust basics and the authority plan;
write [the concrete subplan](../docs/plan/controller-bootstrap.md) before code.
This unit owns only initialization, ping, monotonic Stop generation and graceful
shutdown. It does not create a grant, effect, database, browser session or model
connection, and it cannot establish timely Stop under pipe backpressure.

Checked live upstream crates.io metadata and primary Serde/from_slice docs.
Adopt serde 1.0.229 with derive and serde_json 1.0.151, as proposed in the reviewed
plan and within the operator's accepted Rust POC scope. Cargo resolved eleven
registry packages, all pinned with checksums in Cargo.lock. Origins, features
and restoration commands are tracked in docs/dependencies.json; source adoption
does not extend to any quarantined engine/reference code.

Wrote six integration tests against the actual controller process before
implementation. A deliberate unavailable stub exited 42: five tests failed on
missing exact replies/incorrect exits, while the closed-output negative case
passed (that case alone cannot distinguish a missing implementation). Then
implemented closed Serde requests over bounded FrameReader/FrameWriter and a
finite initialized state. Positive operation traces check exact identities,
incremented Stop generations, empty powers and replies. Negative traces check
malformed/unknown/duplicate/coerced fields, out-of-range IDs, bad run identity,
pre-init/re-init, version mismatch, stale IDs, framing/truncation, EOF and a
closed reply pipe. Errors never echo supplied input and are terminal.

Initial production integration run passed all six tests. Added two direct
positive/boundary traces for maximum IDs/run identity and terminal post-init
corruption. The baseline then passed formatting, strict Clippy, 22 tests
(14 framing + 8 process), one doctest, dependency policy and release compilation.
The first policy run caught an implicit wildcard on the local path dependency;
the manifest now explicitly pins its version too. One nextest run reported a
leak diagnostic on the existing in-memory fragmentation test; its exact isolated
rerun passed without that diagnostic. No controller process test was reported
leaky. Independent review remains the next step. No claim
that these bootstrap traces certify later authority admission, OS delivery,
storage durability or browser-observation behavior.

## Independent review correction CB-01

The reviewer demonstrated a genuine medium defect: internally tagged Serde
Request also accepts positional arrays, contrary to the object-only contract.
Read the review and wrote a correction subplan. Four new actual-process tests
for positional initialize/ping/stop/shutdown each failed red by observing an
incorrect successful exit. Added an outer `deserialize_map` visitor forwarding
`MapAccessDeserializer` into the existing derived enum. This rejects arrays
without collapsing maps through Value and losing duplicate-key evidence. All
twelve process tests then passed, including the existing duplicate-key cases.
Full rigor then passed formatting, strict Clippy, 26 tests, one doctest,
dependency policy and release build; no leak diagnostic occurred on this run.
Same-reviewer recheck closed CB-01 after independently executing all four
positional-array cases and three duplicate-field cases against the real child.
Each returned the exact terminal invalid_message reply and failure exit.
