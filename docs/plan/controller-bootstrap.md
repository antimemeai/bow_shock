# Controller bootstrap subplan

2026-10-01. Build one parent-owned private-pipe child process before attaching
CEF. This is the next portable construction unit after controller-link, not
the complete authority owner. The parent supplies a run identity. No sessions,
grants, native effects, database, provider or delegated powers exist yet.

Use the existing bounded UTF-8/LF framing for stdin/stdout and a closed Serde
protocol. Read current Serde container attributes and serde_json from_slice
contracts: unknown fields must explicitly be denied and the entire record must
deserialize. Version 1 accepts precisely these records:

```json
{"version":1,"op":"initialize","run_id":"parent-generated-run"}
{"version":1,"op":"ping","id":1}
{"version":1,"op":"stop_all","id":2}
{"version":1,"op":"shutdown","id":3}
```

Run IDs contain 1–128 ASCII letters, digits, hyphens, underscores or dots.
Request IDs are positive u64 values and strictly increase. Duplicate/stale IDs
are terminal `stale_request_id` errors; this bootstrap never replays an action.
Every record carries version 1, initialization occurs exactly once and must
precede the other operations. Version 1 accepts no unknown operations, fields,
duplicate fields, nulls, coercions or trailing non-whitespace data.

Success replies contain `version`, `op`, `run_id`, `stop_generation` and
`active_powers` (always `[]`). Replies to operations after initialization also
contain their `id`. Reply op names are `initialized`, `pong`, `stopped` and
`shutdown`. Stop increments its checked u64 generation once. Shutdown sends
its reply then exits successfully without reading further input. Clean EOF
also closes successfully; there are no outstanding effects to reconcile.

Any framing, parsing, identity, ordering or version violation sends exactly one
closed `{ "version":1, "op":"error", "code":"..." }` record and exits
unsuccessfully. Messages never reflect attacker input. Output IO failure exits
unsuccessfully without attempting another write. Protocol-only stdout is
bounded through FrameWriter; diagnostics go to stderr. Framing corruption is
never resynchronized. The future authority owner must keep IO on bounded
workers; this deliberately control-only synchronous bootstrap cannot promise
timely Stop while blocked on stdin or an undrained stdout pipe.

First write integration tests that spawn the actual executable and compare exact
decoded replies and exit codes for permitted traces, malformed JSON/fields,
framing limits/truncation, stale IDs, version/initialization violations, clean
EOF and a closed reply pipe. Run them red against a deliberate unavailable
bootstrap, then implement the finite-state protocol. Run the rigor baseline,
obtain independent review and integrate valid findings before committing.
Serde 1.0.229/serde_json 1.0.151 are the live crates.io stable versions checked
at adoption; pin versions and resolve their actual graph into Cargo.lock.

Primary contracts: [Serde attributes](https://serde.rs/container-attrs.html),
[serde_json from_slice](https://docs.rs/serde_json/1.0.151/serde_json/fn.from_slice.html).

## CB-01 correction subplan

The independent review demonstrated that Serde's internally tagged enum also
accepts positional arrays, despite denied unknown object fields. Require an
outer map visitor before the derived enum: call `deserialize_map` and forward
the untouched `MapAccessDeserializer` into Request so duplicate keys remain
visible to its existing checks. First add actual-process rejection traces for
all four positional operations; then change only the decoder boundary. Repeat
the process suite and baseline checks, then ask the same reviewer to recheck.
