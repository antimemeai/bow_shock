# Closed controller agent proposal wire, version 1

Extension of the existing private table controller wire. Common replies retain
`version`, `run_id`, `id`, `stop_generation`; table replies serialize sorted keys.
Bootstrap ordering stays unchanged. Existing object-only typed request decoding
rejects unknown fields, duplicate nested keys and positional arrays.

Trusted optional startup: `--agent-executable PATH`, then named options
`--agent-cwd PATH`, `--agent-user-home PATH`, `--agent-home PATH`,
`--agent-model ID`, `--agent-provider openai`, optional `--agent-account ID`.
Exactly one each; named options are order independent after executable. Paths
are absolute. Model/account strings are nonempty, at most 128 bytes, no CR/LF/NUL.
Omitting agent options preserves original mode. HOME/CODEX_HOME are passed to the
owned child, without reading or relocating credentials. Records cannot configure
executables, homes, models or providers.

All requests include version 1 and a globally increasing positive `id`:

| Request | Additional fields | Reply payload |
|---|---|---|
| agent_metadata | none | state, descriptor |
| agent_start | review, candidate_ids, objective, ttl_ms | agent_started: task_id, candidate_ids, publication_guard |
| agent_status | task_id (string or null) | task_id, state, export_disposition, publication_guard, proposal, code |
| agent_cancel | task_id | agent_canceled: task_id, export_disposition |

Metadata/status are immediate cached replies. Metadata state is unavailable,
opening or ready; descriptor is null except ready. Start requires an exact
current unapproved Review, 1–12 distinct existing whole-field IDs (`r0f0` etc.),
objective 1–2048 UTF-8 bytes, TTL 1–60000 milliseconds capped by original source
expiry. Errors are `agent_error` with code `agent_rejected` or `unknown_task`.
Existing table/generation errors remain possible. No automatic retry or write.

The descriptor has exactly fourteen fields:

| Field | Value |
|---|---|
| runtime / version | codex / 0.160.0 |
| role / placement | trusted_coding_peer / hosted |
| model / provider | selected model / openai |
| account_ref / account_type | measured backend reference / chatgpt |
| protocol_version | integer 1 |
| account_verification | measured_backend_reference |
| structured_output | unverified |
| history / steer | fresh_only / unsupported |
| cancellation | host_retirement_and_owned_child_kill |

Model/account reference are nonempty ≤128-byte strings without CR/LF/NUL. The
measured baseline does not establish authentication against a hostile same-UID
peer, containment or entitlement. Every fresh owned child/thread must match its
actual home/account/effective settings before selected source disclosure.

States: idle, running, candidate, no_match, canceled, expired, failed. Idle has
null task_id; all other states retain correlation. Only candidate/no_match have
nonnull PublicationGuard; only candidate has a proposal. Only failed has code
provider_unavailable; otherwise code is null. Export disposition is
not_transmitted, transport_handoff_started, partially_transmitted or
provider_retained_unknown. Serialization and unsuccessful writes do not imply
disclosure; cancellation cannot recall accepted bytes.

Proposal is exactly candidate_ids, batch, explanation. Final structured text
≤4096 bytes; explanation ≤2048. The batch copies only selected retained source
fields in original order and marks partial true. The model cannot generate a
row value/source. Human Use explicitly revises the original draft; fresh exact
Review and explicit Save remain required.

Guard uses original source boot/deadline capped by task TTL. Receipt never renews
retention. Final publication rechecks original Review/version/scope/generation
under an actual native witness. Native UI rechecks guard before assignment/Use.
