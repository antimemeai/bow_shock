# Native owned-table lifecycle qualification

2026-10-02. This unit follows the [workflow review](native-table-workflow-code-review.md)
and [written plan](../docs/plan/native-table-lifecycle.md). It owns the original
AppKit/CEF lifecycle join and three owned-loopback fault traces. It introduces
no general reader, model, input, delegated effect, permission or dependency.
Root's independent source/result review remains the next gate.

The first browser selected in a run now stays selected permanently. Closing it
retires its reader and leaves later browser windows manual; restart selects a
new browser. Navigation and renderer termination retire the UI epoch before
reader invalidation, which can synchronously complete an old capture. Clearing
the saved list now recomputes button availability immediately. Retention,
refresh and saved-selection methods also explicitly reject pending Stop.

Two actual pre-fix defects were observed. The display trace cleared saved data
on activation but left the empty saved popup enabled. The browser trace kept
the selected Amber browser through a second Birch window, navigated it to Birch,
received the real renderer-crash callback and closed it, but then implicitly
selected a later third browser. The first browser test incorrectly demanded
that cached Amber survive app activation caused by a new window. Selection had
remained correct; the oracle was corrected to make a fresh actual capture.
That first failure was an oracle error, not a product defect.

| Direct trace | Actual result and bounded claim |
| --- | --- |
| Browser | Three distinct visible CEF browsers. Fresh capture remained Amber in selected browser A after Birch browser B opened. Navigation captured actual Birch with the same surface and a different native document ID. An outstanding old capture completed with partial status and was discarded by the retired UI epoch. Fixed owned `Page.crash` produced the actual CEF crashed-renderer callback. Closing A disabled its workflow; later browser C remained manual. |
| Stop | The original UI continuation of a validated `table_revised` ACK was held. The driver checked actual Rust PID, parent and owned DB arguments, suspended only that child, then invoked the same native Stop action. The old continuation ran while Stop was pending. All ordinary controls stayed disabled and source/review remained empty; the independent actual helper had generation1 while suspended Rust remained generation0. Rust resumed and both channels reconciled generation1. |
| Managed display | An actual current Review and enabled Save retired on application activation. A real saved row was read/listed, then registered activation and workspace-session handlers retired source/list and disabled the empty popup. Four saved reads retained exactly the original boot/deadline guard. With only the fixture maintenance timer delayed, an actual expired display remained cached before the registered wake notification and retired immediately on delivery. |

All three traces completed healthy table close and CEF shutdown. The driver
checked that the original controller and control-helper PIDs were absent after
app exit. Independent read-only SQLite queries found clean dirty markers and
zero rows/commits. The display row actually existed during its guarded reads;
its final absence followed real expiry and healthy close. A separate ordinary
Amber Save/reopen regression retained one committed row whose stored Review
exactly equalled the displayed immutable Review and whose batch equalled the
native saved batch, with clean SQLite shutdown.

The crash command is the matched Chromium `Page.pdl` fixed `Page.crash` command,
already captured in `runtime/observation-primary.json`; it crashes the owned
renderer and may generate a minidump. It is reachable only through a named
lifecycle smoke case with smoke output and the validated owned HTTP loopback
catalog URL. The normal UI has no crash, pause, arbitrary DevTools or synthetic
reply operation. The Stop barrier defers a received real callback rather than
inventing a wire reply. The app stays live throughout the suspended Rust phase,
so unchanged 250ms helper lease and two-second table transport budgets remain
meaningful. Fixture failure teardown cannot create a replacement browser.

Evidence is retained in ignored `context/runtime/native-table-lifecycle/` and
the red/green/build/catalog logs under `context/runtime/`. Final source is
`main.mm` SHA256 `84328661d7db761551031e559cf8bafebd45bd71310828ab8dfc2896d88a665e`,
`table_controls.mm` `ab2144d9d5bdb990aad78ea0b7501810f90a83a97e3543c24f7cdc348c322062`,
header `5c569be6a0bfbb8599c3fed792f049af1508e5a1580085e58b3161f346a74045`,
and driver `5db96cf5bbe1dd3e54275502456011d35f037d25a9fe51e77e7d7bb76894fdd7`.
The isolated CMake relink restored the reviewed original packaged controller,
helper and clock payloads while another conceptual unit changed Rust sources;
canonical plists and the signed graph passed strict verification. This is not
acceptance of that concurrent new service or the future canonical whole build.

Limits remain explicit. Notifications were posted through the actual registered
centers; the test does not physically sleep/wake the machine. Cached window
pixels cannot be promised to erase while the whole app is suspended. The held
ordinary ACK is a revision, not a commit: zero-write evidence here cannot decide
an already admitted commit. The old capture was retired from UI publication,
not proven cancelled inside the renderer. This is a control-only Stop oracle,
not physical Stop delivery or OS-effect quiescence. Mid-write transport stalls,
arbitrary renderer workloads, all-helper descendant containment and physical
input retain their separate gates. Earlier unexplained startup/teardown
availability failures remain open; these successful traces do not explain them.
