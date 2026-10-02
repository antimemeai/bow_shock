# Native tandem join independent review

2026-10-02. Read root's `main.mm`, `table_controls.h/.mm`, CMake addition,
`try-poc.py`, controlled peer and joined driver against the written agent join
plan and finalized closed native connection. This review owns no product edits
and launches no CEF app or inference. Root's canonical matching-payload build and
strict signed graph passed. Controlled actual joins now qualify the gates below;
live inference remains pending.

The startup path accepts agent configuration only from explicit native arguments,
requires complete runtime/workspace/home/model selections and optional expected
account, and supplies that trusted object to the reviewed closed connection.
The old constructor/launcher leaves it nil. Page/model output supplies no runtime,
parser or provider configuration. Named agent smoke requires smoke output plus
the validated owned loopback Amber URL. The new target adds the original panel;
it does not adopt a new dependency or broaden browser privileges.

Ordinary controls track both table work and panel busy state; Stop retains its
independent urgent slot. Retirement increments the table epoch and clears table
decision/source, then retires panel publication. Observe/Refresh/saved-selection
recheck reentrant Stop and occupied panel state before continuing. Explicit Save
consumes completed agent state and clears reusable draft correlation before
approval. Use accepts only a current guarded callback, requires the original
never-approved draft ID, calls revise rather than new stage, and requests a new
Review. It has no approval/commit path. The panel independently reconstructs and
revalidates the exact selected subset before that callback.

## AGJ-01 — Initial owned agent smoke can consume its dispatch while disabled

Found: table readiness starts metadata before `maybeSmoke`; the latter marked
smoke started and scheduled Observe100ms later without checking whether metadata
still occupied the ordinary slot. Observe could return disabled and never retry,
so the intended CEF/model oracle could time out before actual capture.

Root corrected scheduling and delayed dispatch to check actual Observe/Refresh
availability at both boundaries. A finite scheduled flag prevents duplicates;
started is consumed only at actual dispatch. Existing maintenance supplies retry.
Source recheck closes this race; actual controlled positive reached both gates,
Save and same-boot reopen.

## AGJ-02 — Independent-helper loss bypasses live Rust revocation

Found: helper disconnect set ready false and retired the panel, but its
revocation callback required the two-channel Stop button to be enabled. With
helper dead/Rust live it could clear UI while unsent provider projection retained
authority in Rust. Main-thread epoch retirement alone cannot retract queued bytes.

Root added a direct controller fault fence independent of unavailable helper ACK.
It marks stopping, retires data first, submits urgent Rust Stop and validates the
next generation; failure/counter exhaustion invalidates the live controller.
It keeps the workflow unavailable pending restart. Source correction closes the
delivered-fault gap. Final owned pre-export helper-death run-5q7mvp3y passed
actual Rust retirement, no exported fields, empty clean SQLite and owned-child
absence. The independent read-only result inspection found rows0/commits0/dirty0.
This is not a promise of immediate revocation while the whole UI is suspended.

## AGJ-03 — Close can wait behind Start before retiring export authority

Found: close set closing before panel retirement, whose revocation callback then
skipped Stop. Clean `table_close` is ordinary: an occupied Start/status slot
returns busy and is retried. Pending Start could hand off fields after UI close
while Rust had not yet received close. The plan's statement that close already
retired authority was not true at that entry boundary.

Required: submit urgent controller revocation at close entry before waiting for
the ordinary clean-close operation, or fail closed if it cannot be accepted.
Root now submits urgent Rust Stop at agent-enabled close entry, requires the
exact next-generation ACK before ordinary close, and invalidates/fails honestly
if it cannot be accepted. Helper authority also invalidates at close entry.
Actual pre-export Quit run-i1wtrw1u then exposed the pending-fence case as normal
active Quit: selected-browser OnBeforeClose started Stop before table close,
which submitted a duplicate urgent Stop and left SQLite dirty1. The earlier
review's accepted timing limit did not meet this normal Quit path.

Root refined ownership: normal/control-fault Stop tracks the actual pending Rust
ACK; close joins that fence rather than resubmitting it. The matching generation
continues ordinary close; wrong/missing ACK invalidates and fails honestly. If
Rust already ACKed and only helper reconciliation remains, that validated
retirement suffices. A helper fence callback arriving after close intentionally
retired that helper cannot invalidate the still-live Rust close. Source/callback
order recheck found no blocker. Actual run-dquo_8vo passed with both
close_joined_pending_stop and close_authority_stopped true, no export, healthy
close/CEF shutdown and owned-child absence. Independent SQLite inspection found
rows0/commits0/dirty0. This qualifies the actual active pre-export Quit trace;
other ACK failures retain honest unsuccessful-close semantics.

## AGJ-04 — Controlled export readiness is published before complete JSON

Found: the controlled peer creates/writes `peer-export.json` non-atomically,
while the driver parses as soon as it exists. It can observe an empty/partial
regular file instead of the intended complete actual exported projection.
Root now publishes a completed temporary file with atomic rename before
readiness. Source recheck closes the oracle defect; controlled positive and
post-handoff Stop observed the actual complete synthetic export.
This was a test-oracle availability defect, not a product export defect.

The positive driver has useful independent gates: actual SQLite zero rows/commits
before releasing Use and again before Save, same staging ID with incremented
Review version, unchanged original guard, exact durable displayed Review/batch/
row and clean same-boot reopen. Controlled mode inspects actual received fields
and excluded-marker absence; held post-handoff mode checks retirement, native
Stop generation, child absence and clean empty store. Those assertions are
passed in controlled run-fnd2sbm1 and final refinement run-2qf17vlu. Independent
retained-result inspection confirmed exact committed Review/batch, unchanged
original guard, stage/version relationship and SQLite dirty0. Root additionally reconstructs the
exact expected selected subset from original Review content before releasing
Use, including every state/source identity. Positive source retirement after
reconciled Stop now emits a clean failure rather than waiting for external kill.
Root's bounded named objective setter makes the joined two-field request explicit;
a generic useful-field objective alone would not necessarily require both IDs.
No physical input, external-site
fingerprint, network-effect, provider-copy recall or broad workload claim follows.

No source blocker remains in the corrected reviewed scope. Actual controlled
post-handoff Stop passed on the final refinement in run-cltuf9zb, with actual
export before Stop, cleared native task/publication, validated generation1,
empty clean store and owned-child absence. Live inference remains pending.
Python parse and diff checks pass. This review has not repeated
the old native transport suite or launched CEF/inference.

Availability remains unqualified. Retained run-dmiria9x/run-lu55hplp failed native
clock query supervision/freshness before the agent task, with truthful terminal
controller failure and SQLite dirty1. This does not diagnose the model/close
path or establish the startup-policy cause. A successful same-binary Stop recheck
and fast direct producer calls do not explain those failures. The first positive
fixed-value oracle also wrongly demanded raw USD12.00 as price value; the
existing projection stores normalized12.00 with raw source USD12.00 and
usd-decimal2-v1. Original field/provenance equality already passed; root corrected
that oracle and retained run-2q7x4u1f. It was not a product normalization defect.

The first live attempt run-q9x6mo21 did not reach Ask or inference. It exposed a
panel state defect: fresh valid Review replaced terminal metadata denial with
opening while metadataFinished prevented a new request. Root wrote the direct
original-class red and changed replacement to preserve unavailable; cached typed
ready metadata also restores its actual role/model/account caption. Direct
red/green logs are native-agent-panel-metadata-retire-{red,green}.log. Independent
source recheck accepts that correction (panel implementation SHA256
f7193cb7ced8a0728b5175e53d7b04cc157378710ce3d7dafd36fc4ff71c13fa).
The new owned-smoke transition trace is bounded to enum/boolean phase state,
with no page/account/configuration data. Actual metadata decoder/schema diagnosis
belongs to the independent Rust unit; no completed live inference is claimed.

The final controlled peer compatibility delta is source-accepted. Only notification
envelopes gain the pinned integer emittedAtMs; account/read workspaceRouting has
the three fixed string fields, with the owned account matching rateLimits.accountId.
The thread reply explicitly binds runtimeWorkspaceRoots to the owned cwd,
activePermissionProfile to null, multiAgentMode to explicitRequestOnly and
readOnly.networkAccess to false. Fixed model/provider/approval/reviewer/ephemeral
constraints and atomic export remain intact. These synthetic assertions qualify a
controlled protocol fixture, not real provider authentication or inference. The
separately reviewed Rust compatibility/reasoning correction is accepted; final
controlled results are recorded below, while the live gate remains pending.

The final fixture also emits all three closed reasoning notices, correlated to
its owned thread/turn, before the turn/start ACK: summaryPartAdded with integer
summaryIndex, summaryTextDelta with that index/string delta, and textDelta with
integer contentIndex/string delta. The intermediate deltas carry an excluded
marker; the later coherent final alone selects the copied field IDs. The driver
requires marker absence from the complete native result. Its exact displayed/
saved Review and SQLite equality extend that boundary to the persisted result.
Source and Python syntax checks accept this oracle; final controlled positive
execution also passes it. The independently reviewed Rust unit owns notice decoding.

Two newer startup stalls, run-n3965bi_ and diagnostic run-78d29_3g, stop after
browser_created and before main load. The exact PID45516 sample shows the AppKit
loop and native pipe workers servicing normally. Retained securityd evidence
at that process's launch directly records a keychain query and authorization
prompt for Bow Shock; the keychain was already unlocked and the logged app ACL
contained previous code-hash requirements. This identifies an observed per-item
OS authorization gate rather than a login-keychain unlock. It does not explain
the separate clock freshness failures or earlier CEF teardown watchdog. Root's
post-readiness controlled executions now succeed. No credential/item access,
signing, ACL, encryption or input change was performed by this review.

Final read-only source/build/document recheck found no new native blocker.
The separately reviewed reasoning unit is committed as 69e5693, with all 69 Rust
tests and basic rigor reported green. The canonical final build log records all
eight payloads matching before signing; its build script requires successful
strict verification of the entire signed graph and owned standalone executables.
The experiment distinguishes earlier controlled runs from this final
compatibility/reasoning tuple. Root obtained operator-local readiness before
the final executions below. No browser or model was launched by this recheck.

Final controlled positive run-i9lt9_nc is independently accepted from retained
native output and read-only SQLite: selected fields reconstruct exactly from
the original Review, Use preserves stage/deadline and increments version, actual
export equals those copied fields, and displayed/saved Review equals the one
committed durable row. Clean reopen preserves that exact Review. The intermediate
reasoning and private markers are absent; recorded owned controller/helper/peer
PIDs are absent. The driver independently checked zero rows/commits before Use
and Save. This executes the final pre-ACK reasoning-notice fixture through the
joined native task, without a live inference claim.

Final post-handoff Stop run-mqlrx9cz and pre-export helper death run-1i1otemh are
also independently accepted. Results attest validated authority retirement and
native source clearing; read-only SQLite confirms rows0/commits0/dirty0, with
recorded owned PIDs absent. Stop has the actual selected-field export; helper
death has no export and no proposal/Review publication.

Final pre-export Quit run-pt1lu6w2 is independently accepted: close joined the
pending owned Rust Stop and validated authority retirement; no export or
proposal/Review was published, table/CEF shutdown completed, and SQLite is
rows0/commits0/dirty0. All recorded native/fixture PIDs are absent. Thus all four
final controlled joins pass on the reviewed compatibility/reasoning tuple.

Installed-runtime run-ypmfldne reached opening then unavailable before Ask;
agent_failure is agent_unavailable and no inference success is claimed. It
closed the table/CEF normally and retained rows0/commits0/dirty0. The recorded
controller/control PIDs are absent; installed mode retained no provider PID
list, so this review cannot independently qualify provider-descendant absence
from those artifacts. Metadata diagnosis belongs to the Rust owner. Live
inference remains an open gate rather than a completed native-task milestone.

The subsequent installed driver observation closes the missing recorded-runtime
oracle for future successful runs at a precise scope: each read-only process
snapshot binds the actual owned app PID to the exact packaged controller path,
then its direct selected executable. Observed PIDs are retained even on failure;
success requires a nonempty set and their absence after native close. Source and
Python syntax checks accept this mechanism. Its 100 ms snapshots cannot identify
the command role from comm, guarantee discovery of short-lived processes or
cover arbitrary descendants/reparenting. The claim is cleanup of observed direct
selected-runtime processes, not exhaustive process containment. Actual execution
of this added oracle remains pending.

The observer's first actual run-q2b850c9 failed its new one-second ps timeout
before a native verdict. The revised source records TimeoutExpired/failed ps
exit as missed_samples with no PID evidence and continues within the unchanged
90-second driver deadline. Each snapshot remains individually timed out;
successful qualification still requires observed PIDs and post-close absence.
Source/syntax recheck accepts this test-only availability correction. It changes
no product budgets or runtime retry behavior; actual installed success remains
pending.
