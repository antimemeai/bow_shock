# Native owned-table lifecycle hardening

2026-10-02. Keep the accepted Amber/Birch POC available while qualifying the
native UI's retirement paths. This unit owns `main.mm`, `table_controls.h/.mm`
and a narrow owned-CEF lifecycle driver. It introduces no model, general reader,
input, permissions, dependency or network feature. Root independently reviews
the source/results before commit.

The existing reviewed source already requests both Stop channels immediately,
rejects mismatched acknowledgements, checks the selected browser on load/crash/
close, clears guarded display on activation/wake/session events and uses fresh
actual guards. Their first joined acceptance did not execute the fault paths.
Study those mechanisms, then add three owned-loopback smoke traces invoking
the real native actions and actual Rust/control processes:

1. Browser lifecycle: show Amber, create a separate actual Birch browser, prove
   its load does not change the selected capture; navigate the selected browser
   to Birch and require changed document provenance and retired old display.
   Crash its actual renderer via a fixture-only native command, require the
   selected workflow disabled/empty, then close it while another browser stays
   open. Create a later third browser and require it remains manual rather than
   silently taking over the retired selection. The selected browser is pinned
   once per POC run; restart is the explicit replacement path.
2. Stop: obtain an actual validated ordinary revision acknowledgement and defer
   only its original UI continuation at a smoke barrier. Keep the app serving
   heartbeats while the driver checks PID/PPID/owned database arguments, suspends
   only its live Rust child and writes the owned release artifact. Invoke the
   real Stop action, then release the old ordinary
   continuation while Rust remains held. Require empty source/review and all
   ordinary controls disabled; independently require the actual native helper
   acknowledges generation1 while Rust's generation remains0. Resume Rust before
   its unchanged two-second transport limit, require exact two-channel agreement,
   and cleanly close. SQLite must still have zero rows/commits. This is neither a
   fake reply nor an OS input listener/effect-quiescence oracle.
3. Managed display: save an actual short-lived table using a fixture-only real
   retention choice, read/list it, and post the registered AppKit activation and
   workspace session notifications through their real centers. Require actual
   view/list retirement and disabled empty selection. Restore the original saved
   row, delay only the maintenance timer, wait past its actual persisted native
   deadline, then post workspace wake and require immediate retirement without
   a new lease. This exercises notification delivery; it does not claim a real
   machine sleep/wake or that paused cached window pixels erase instantaneously.
   Healthy close and SQLite dirty0/expired-row absence are independent oracles.

Smoke entry is accepted only with smoke output, a named lifecycle case and an
owned HTTP loopback origin/catalog URL. Additional browser URLs are fixed owned
catalog paths. Hooks observe actual view/button states, native identity and real
clock guards; they cannot create replies or clock values. Test barriers and
callback deferral are inactive in normal POC use. The driver owns one app at a
time, records exact process identities, resumes its stopped processes on failure
and preserves profiles, stderr/results/database. No unrelated process is signaled.

Before production corrections, run the new actual browser and display oracles
against existing lifecycle behavior. Expected defects from source study: after
selected close, `attachBrowser` can implicitly select a later-created browser;
`clearList` can leave the saved popup enabled until maintenance updates buttons.
Navigation/renderer retirement must increment the UI epoch before asking the
reader to invalidate, because reader failure can synchronously call its actual
completion. Keep received commit correlation/outcome uncertainty honest; an old
callback cannot restore content or availability during Stop/close.

After direct red evidence, correct only the demonstrated lifecycle mechanisms
and run affected traces to green. Do not repeat the broad catalog/workload suite
unless changes or failures warrant it; run a single catalog save/reopen regression
for the shared action path. Report individual fault qualifications and unresolved
startup/teardown availability separately from source correctness. Mid-write
transport suspension, physical Stop, general renderer work and delegated effects
retain their existing later gates.
