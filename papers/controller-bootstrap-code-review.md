# Controller bootstrap independent code review

2026-10-02. Reviewed the control-only Rust child, actual-process tests, Cargo
manifests/lock, dependency ledger, written bootstrap subplan and journal. Read
AGENTS/BLACKBIRD and the research/issue indices first. This review does not
certify native parent pipe supervision, grants, SQLite, browser observation or
OS effects. Detsim, mutation and heavier tiers remain explicitly deferred.

## CB-01 — Medium: closed object protocol accepts positional arrays

`crates/controller/src/main.rs` derives an internally tagged `Request` enum and
passes it directly to `serde_json::from_slice`. `deny_unknown_fields` rejects
unknown object fields, but does not restrict the outer JSON representation to
an object. The running executable accepts this entire positional-array trace:

```json
["initialize",1,"run-1"]
["ping",1,1]
["stop_all",1,2]
["shutdown",1,3]
```

Observed exit code: zero. Observed operations in order: `initialized`, `pong`,
`stopped`, `shutdown`; the Stop reply advances generation to one. This
contradicts the subplan's precise four closed request records. The existing
empty-array rejection does not exercise a valid Serde positional sequence.

The adopted library source explains the behavior: Serde 1.0.229
`src/private/de.rs`, `TaggedContentVisitor::visit_seq`, reads the first sequence
element as the tag and retains the rest as content. serde_derive 1.0.229
`src/de/struct_.rs` emits a sequence visitor for internally tagged struct
variants, then invokes `deserialize_any`. These implementations are from the
Cargo.lock-resolved registry source, not an inferred JSON-schema guarantee.

Enforce a map-only outer deserialization boundary, preserving duplicate keys
until the derived Request visitor checks them. A small `deserialize_map`
visitor that forwards `MapAccessDeserializer` to Request is one suitable
approach. Converting through `serde_json::Value` would lose duplicate-key
evidence and is unsuitable here. Add actual-process rejection traces for
positional initialization and post-initialization ping, Stop and shutdown;
require the exact terminal `invalid_message` reply and failure exit.

## Other reviewed behavior and evidence

Version and run-identity checks are explicit. IDs are positive u64 and strictly
increase; stale Stop requests terminate before another increment. Stop uses
checked arithmetic. Successful replies are bounded in size and contain no
delegated powers. Schema/framing/state violations return one fixed error and
stop; an output failure propagates without another write. Clean EOF and
shutdown have no outstanding effects in this construction unit.

Existing process tests compare complete decoded records, actual exit status
and bounded diagnostics. Their five-second supervisory deadlines cover the
finite tested traces; they do not establish responsive control under live pipe
backpressure, which the written subplan explicitly disclaims. The closed-output
case only claims failure termination, not a particular signal/error path.

Six additional direct executable probes passed for reordered initialization
fields and allowed identity punctuation, u64::MAX ping, duplicated version/op,
boolean and floating-point IDs, and an exactly 65,536-byte invalid JSON payload.
Read serde_json 1.0.151 `src/de.rs`: `from_slice` calls `from_trait`, which calls
`de.end()` after deserialization; trailing non-whitespace rejection is grounded
in the adopted implementation. No broad suite repetition was needed to expose
CB-01.

Cargo pins direct runtime packages, and the ledger identifies origins, selected
features, the resolved registry package set and locked restore commands. README,
ISSUES and docs/INVARIANTS still describe framing-only implementation/no adopted
runtime dependencies; the owning integration should update those statements.

Disposition: **CB-01 corrected and independently rechecked.** The owner added
`ObjectRequest`, whose `deserialize_map` visitor forwards directly through
`MapAccessDeserializer` to the derived Request decoder. It neither implements
a sequence visitor nor collapses keys through Value. Four actual-process
array rejection tests were added; the owner observed them red before the fix
and green afterward. Independent direct executable rechecks verified all four
array forms plus duplicate ID, operation and version keys: each produced the
exact terminal `invalid_message` record and unsuccessful exit, preserving the
initialized reply only where initialization had already succeeded. No
additional production finding was found within this bootstrap scope.
