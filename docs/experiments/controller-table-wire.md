# Trusted native controller table wire

Construction unit, 2026-10-02. The private inherited pipe accepts only the owned
native parent; it is not an agent/model endpoint. The controller CLI is either
empty (bootstrap only), or exactly `--table-db PATH --clock-probe PATH
--owned-origin ORIGIN`. Paths and origin are trusted host configuration, never
incoming commands. Table scope must equal that configured origin. This does not
reverify CEF; native provenance and effective origin come from the reader.

Every record is UTF-8 JSON followed by one LF, ≤65,536 payload bytes. Empty,
truncated, CR-containing, duplicate/unknown-field, positional object or malformed
records terminate the process. Requests use version 1, a first initialize with
run_id, then a strictly increasing positive u64 id shared across all operations.
Bootstrap replies preserve the original serialization and active_powers: [].
Table operations require explicit table mode and initialization.

Table replies are flat closed objects with exactly the common keys `version`,
`run_id`, `id`, `stop_generation`, plus `op` and the variant fields below. They
serialize recursively in lexicographically sorted object-key order through
serde_json's default Map, without formatting whitespace. Integers are exact JSON
integers; no floating-point conversion is permitted. Review.content remains an
opaque exact string, including its original inner JSON order; sorting the outer
reply does not parse/reencode that string. The native UI displays its semantic
content and sends the identical Review object back for approval.

| Request op | Additional request fields | Success op | Additional reply fields |
| --- | --- | --- | --- |
| table_scope | origin: string | table_scoped | none |
| table_stage | batch: Batch | table_staged | staging_id: string |
| table_revise | staging_id: string, batch: Batch | table_revised | staging_id: string |
| table_review | staging_id: string, retention_ms: u64 | table_reviewed | review: Review, publication_guard: PublicationGuard |
| table_approve | review: Review | table_approved | approval_id: string |
| table_commit | approval_id: string | table_committed | commit_id: string |
| table_status | commit_id: string or null | table_status | health: string, state: string or null |
| table_list | none | table_listed | commit_ids: string array, publication_guard: PublicationGuard |
| table_read | commit_id: string | table_read | batch: Batch, publication_guard: PublicationGuard |
| table_delete | commit_id: string | table_deleted | commit_id: string |
| table_close | none | table_closed | none |

Any table operation may instead return `table_error` with `code` (a closed static
code, currently table_rejected/not_ready/stopped/publication_unavailable). That
is an application rejection; the monotonic request ID remains consumed. Framing,
ordering, clock and IO faults are terminal. Protocol errors retain the original
bootstrap error object `{version:1,op:"error",code:...}`. Table status reports
Opening/Ready/RestrictionUnknown/Failed/Closing/Closed in snake_case. Commit
states are preparing/admission_pending/admitted/writing/committed/rejected/
purging/deleted/unknown. table_deleted means immediate managed denial and queued
purge, not completed forensic deletion; query status for actual lifecycle outcome.

Review is `{staging_id:string,version:u64,content:string}`. Approval identities
are correlation tokens for a private Rust handle, not deserializable authority.
Duplicate exact approval/commit reuses identity. Different content, retention
or version cannot silently change an approval. List returns only currently
acknowledged permitted commit IDs; it never reconstructs an approval or retries
an unknown commit. Clean same-boot reopen loads exact saved identity/content.

Batch is `{schema_version:string,pattern_version:string,partial:bool,rows:[Row]}`;
Row is `{fields:[Field]}`; Field is `{name:string,state:FieldState,source:Source}`.
The six state objects are `value{source,value}`, `empty`, `missing`,
`inaccessible`, `ambiguous{candidates:[string]}`, `invalid{source,reason}`, each
with its corresponding `kind` string. Source is `{observation:ObservationRef,
node_id:positive i64 or null,visibility:string,normalization:string}` plus
optional `fragment:string`. ObservationRef holds run_id/surface_id/frame_id/
document_id/capture_id/security_origin strings and positive attachment_generation/
activation_generation/node_generation u64s, plus optional capture_start_ns and
capture_end_ns u64s. Native staging requires both actual interval values with
0 < start ≤ end ≤ the newly sampled native clock. Value/Invalid raw fragment
matches state.source; Empty retains its actual fragment (including whitespace).
Missing/Inaccessible omit fragment and have null node_id; the nullable node_id
key is required in every native Source. Ambiguous retains explicit literal
candidates. It may also retain the actual whole-cell fragment and positive
container node when every nonempty candidate occurs literally in that fragment;
this records container provenance without selecting an alternative. A supplied
fragment contradicting its candidates is rejected. Fragmentless legacy
alternatives remain compatible and do not claim a selected raw-source fragment.
Legacy retained records may omit intervals/fragments; the native UI must mark
that provenance unavailable, never guess it.

Controller limits: two rows, six fields each, 16 KiB canonical Batch bytes,
24 KiB exact Review.content, retention at most 24 hours and the source policy.
Encoded frames are also checked against the 64 KiB bound. The library's four
stage/four commit limits remain in force. Incoming/pending/outgoing queues each
hold at most eight records; the writer holds one frame and clock worker one job.
IO handoff has a two-second conservative deadline. Capacity exhaustion/blocked
writer fails closed, stops preparation and leaves the DB dirty. An explicit
healthy table_close returns only after SQLite marks clean; shutdown follows.

PublicationGuard is `{boot_id:string,valid_until_ns:u64}` and is required on
read/review/list data replies. Read uses the actual persisted retained deadline;
review uses actual staging source expiry; list uses the minimum deadline of
permitted survivors (an empty list uses a 250ms actual-clock lease). Native UI
compares a new actual OS witness immediately before assignment, requiring the
same boot and now < valid_until_ns, and clears displayed data at expiry or an
invalidating activation/generation. It does not infer expiry from capture time.
The native approval adapter checks its retained review guard locally before
sending approval; that guard is not an incoming approval field. The service
rechecks source policy and exact Review under a new actual witness independently.
The service refreshes and revalidates those replies only after writer readiness;
started/partially delivered bytes remain uncertain if transport later fails.

Terminal clock ownership uses one ClockOwner across control and SQLite queries.
Cancellation is nonblocking; no later spawn is permitted. Each query retains
its active registration until its owned child is actually killed/reaped on
cancellation/error/unwind. Terminal service drain waits outside the healthy
authority loop for all such queries to quiesce before exiting. An unresolved OS
reap after two seconds logs a bounded diagnostic and remains terminal; it does
not exit and orphan the child. No blocked pipe/SQLite thread join is required.
The original configured producer must not fork descendants retaining stdout;
that read phase is not a general descendant-tree containment contract. Forced
SIGKILL/abort/OS death bypasses Rust cleanup and remains a native-parent safety
limitation, not an earned zero-orphan guarantee for arbitrary termination.
