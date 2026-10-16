# Native traffic capture/editor while operator is AFK

The operator asked to keep moving through a chunk of work and leave practical
testing until their return. At the start, the previous Python.org extraction and
complete reading runs were open at macOS Safe Storage access prompts; no OS access
was automated and neither live run was reported as complete. Implemented the fast
follow that can be checked directly without that dialog: an owned native traffic
capture/editor, archive and inspection utility. No new dependency, TLS trust
change, routing change, Blackbird checkout change or owned test website.

Read current project doctrine, extraction intent, instrumentation/proxy and
empirical-input plans, existing network studies and actual CEF 15400 headers.
Downloaded and read matched Chromium 154.0.8037.58 Fetch/Network protocol,
interceptor, Fetch handler and stream pipe, preserving originals/hashes/license
and restoration details in `papers/native-traffic-154.md`. Wrote the implementation
unit before coding in `docs/plan/native-traffic-workbench.md`.

`traffic_session` owns protocol state and immutable binary storage on a serial
worker. Passive Network responses request incremental content; initial buffered
data is ordered before later chunks even when its callback is delayed. Unavailable
streams fall back to completed-body retrieval with explicit errors. Reported
request bytes, original headers/events, redirect identity and cache/worker fields
remain retained. `traffic_browser` supplies the actual CEF native dictionary
adapter and AppKit window: explicit URL-glob/request/response arming, selected
pause editing, duplicate headers, arbitrary binary body files, original forward,
cancel, Stop/disarm, archive inspection and passive resume after detach.

Selected response pauses consume an upstream stream into 64 KiB blobs without a
total harvest cap. Subsequent fulfillment uses those exact bytes or a separately
retained replacement. Instructions are saved before edits are submitted; command
acceptance and observed Network events remain different records. Stopping an
ordinary request forwards unchanged; stopping during stream consumption cancels
that exchange and retains partials. A failed original publication forwards
unchanged instead of editing unretained data. Browser close drains protocol
decoding and queued disk work. The global conversation Stop now stays enabled
when browsing, covering traffic even when no model turn is running. Closing the
editor stops/disarms its pauses while passive capture continues.

Review found and fixed a command-ID collision hazard between independent page
and traffic observers: one shared non-reusing atomic allocator now serves both.
Traffic filters IDs before copying results, so the reader's complete DOM reply
is not copied again. Also fixed cancel-before-stream-handle delivery, late read
results after cancel, callback retirement on detach, old Network-ID fallback
attribution, missing upload entry bytes being mistaken for empty data, duplicate
popup titles collapsing distinct exchanges, navigation context replacement and
storage failures disappearing behind later success messages.

Matched source additionally reveals a fatal Chromium fulfillment check above
UINT32_MAX response bytes. The editor checks this selected send before assembling
its whole argument; collection and retention remain uncapped. A different response
loader is needed to serve larger edited responses. Fulfillment and the passive
completed-body fallback use memory proportional to their complete protocol
argument; normal capture writes chunks. The matched stream pipe preserves invalid
UTF-8 via base64, including split multibyte fragments. Response fulfillment removes
stale encoding/transfer/length headers when supplying decoded bytes.

`scripts/traffic-inspect.py` reads native events and reports actual command
acceptance/rejection, counts and stored bytes. It reconstructs complete or
explicitly requested partial bodies through streamed file copies, refuses
overwrites and unavailable chunks, and creates private export files. UI recent
history is a 150-entry viewport only; the full event/blob history stays on disk.

Native checks cover exact ordered binary streaming with delayed initial bytes,
complete >1 MiB fallback bytes, request URL/method/header/body delivery to the
protocol adapter, response status/header/body fulfillment, duplicate response
cookies, exact original preservation, rejected edits staying paused, original
forward after a rejected edit, sparse >4 GiB replacement refusal before allocation,
Stop at request and mid-stream, redirect pauses, cancel before handle delivery,
detach with pending reads, session metadata preservation on resume, and an actual
filesystem failure forwarding unchanged. The Python utility is checked against
these emitted files, including original/partial reconstruction and refusal to
overwrite. Native signed build also passes. Final validation paths/results are
recorded at closeout below.

Practical follow-up: launch the new bundle, grant its normal Safe Storage access,
browse/reload a real site, inspect passive exchanges, arm a specific request and
response and check actual upstream/page effects. Current target scope does not
attach additional OOPIF/worker targets. No ad classifier, external wire proxy,
replay, reusable edit rules or OS input executor is claimed. The archived human
traces remain the source for the subsequent input calibration/trace work.

Closeout: native traffic/inspection checks passed under
`context/build/traffic-checks/87592d30-7a96-4a30-9574-ba1f720c6390`, the complete
native reading archive/projection check passed, Python compile/scoped diff checks
passed, and the signed bundle is `context/build/extraction-final/Bow Shock.app`.
During final inspection, the old live runs had ended: Safe Storage reported
userCanceledErr and Python.org nevertheless captured one document, 299 blocks,
4038 UTF-8 bytes. Both real model turns then failed with `invalid_range`; the
retained provider response shows an exec call with `task_id=""`. Blackbird treats
any present task binding as an existing task, including the empty optional
placeholder. Following this concrete failure in an isolated Blackbird worktree;
also correcting Oxcart's premature handling of nonfatal errors before final.

The matched macOS 26.2 SDK dispatch/queue.h states that manually created queues
inherit their target's autorelease behavior and global queues do not create a
pool per item. Set both traffic disk/state and protocol-decoding queues to the
SDK's serial-with-autorelease-pool attribute. Temporary decoded objects now drain
after each chunk/callback rather than depending on the lifetime of a busy worker
thread. This leaves retained chunks/metadata and capture size unchanged. The
existing direct traffic command/storage check and native build cover the change;
no separate test merely asserts the chosen queue flag.
