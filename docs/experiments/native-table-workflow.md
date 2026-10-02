# First joined catalog POC

2026-10-02, macOS ARM64, matched CEF
154.0.32+g682c378+chromium-154.0.8037.58, API15400, sandbox enabled.
The native window, original native reader/projection, reviewed private Rust table
service, independent control helper and SQLite now pass the joined catalog oracle.
This is the first person-operated POC. Full P1/P3 and subsequent model, input and
network capabilities retain their broader gates.

## Try it

```sh
python3 scripts/build-native.py
python3 scripts/try-poc.py
```

The second command starts the immutable loopback catalog and the dedicated app.
Click **Observe page**, inspect field states and literal source using the field
selector, choose retention, inspect the exact Review, then **Save reviewed table**.
**Refresh** discovers saved tables; selecting one shows original captured source.
**Stop all** retires review/display and fences both connections. **Quit Bow Shock**
or browser-window close lets the store close before the app exits.

For the ambiguous-price page:

```sh
python3 scripts/try-poc.py --page birch
```

Keep the default port 43177 and data directory `context/runtime/poc` for same-origin,
same-boot reopen. The profile and `tables.sqlite` are local ignored artifacts.
Retention choices are 10 minutes, 1 hour and 24 hours; at most 4 retained tables. Dirty
or unknown recovery is denied without automatic purge. A macOS keychain prompt
for this app's Chromium Safe Storage item is separate from sudo; rebuilding the
ad-hoc-signed app may prompt again. No signing identity or keychain ACL was changed.

## Actual joined evidence

`python3 tests/native_table_workflow.py` passed four real CEF app cycles against
one owned origin/profile/database: five observations and a retention change,
Amber Save, Birch Save, clean reopen. It required six successive immutable review
versions on one staging identity, both Stop acknowledgements and cleared display,
and independently found zero SQL commits/rows before Save. Amber preserved
value/value/empty/missing/invalid/inaccessible. Birch preserved value/ambiguous/
empty/value/value/inaccessible, both literal price candidates and normalized 7.

Independent SQLite queries required exact displayed Review.content equality
with stored review, matching retained row payloads, two distinct committed
identities and dirty=0. All app cycles required native panel visibility, clean
table close, CEF shutdown and absence of the exact original controller/helper
PIDs. Hidden source markers did not publish. Actual output and diagnostics are
retained under `context/runtime/native-table-workflow/run-ljhopkrs`; the driver
creates a new retained artifact directory each run.

The first joined run reached all four app cycles but failed the final displayed
text comparison: NSTextView.string's mutable backing object was stored without
copying, then cleared on display retirement. The diagnostic now copies the actual
view string at sampling. Production approval already used the immutable service
Review. The first failure and actual artifacts remain in
`context/runtime/native-table-workflow-first-join.log` and `run-v6s_xwkl`.

Canonical build and strict bundle verification passed after compiling all native
units. Rust basic rigor previously passed 47 cases in its reviewed service unit;
no Rust code changed during this native join. Direct table/control transport
reviews remain separate from this UI integration review.

## Supported capture workload and limits

Only the launcher's two immutable catalog responses qualify for this POC's
Observe mode. Its native controls label catalog-only, root-only partial coverage,
withheld children and absent delegated effects. The trusted development smoke can
probe growing owned workloads; those are not promoted to a general reader.

`python3 tests/native_capture_work.py` passed eight actual app runs with both
connections active. Delays are measured from the requested continuous-clock Stop
target; the same native Stop method serves the human button. Values below are
single-run observations, not worst-case guarantees.

| Workload | Result / configured boundary | Main callback max gap ms | Stop Rust / helper ACK ms | Stop during capture |
| --- | --- | ---: | ---: | --- |
| Amber | Partial root |17.495|8.461 /11.426|Yes|
| Birch | Partial root |18.313|8.889 /6.494|Yes|
|64 extra elements | Partial root |10.209|14.762 /6.086|No|
|1,024 extra elements | Partial root |11.928|8.827 /5.351|Yes|
|8,192 extra elements | callback_copy_or_queue_limit |30.696|6.292 /6.250|Yes|
|512KiB text | string_limit |15.655|11.989 /11.917|Yes|
|8 alternate-origin frames | Partial root; children withheld |14.530|9.342 /7.052|No|
|32 alternate-origin frames | Partial root; children withheld |11.055|28.468 /24.245|No|

Catalog handler delays were 0.869 ms and 0.313 ms. Both catalog captures met the chosen
100ms servicing target while a capture remained active. This measures AppKit
callbacks and actual acknowledgement delivery, not a physical keyboard listener,
OS-effect drain or native traversal cancellation. Cases finishing before Stop
establish servicing only. The host still permits one unresolved capture; its
three-second wait is not Blink cancellation or a renderer-work bound.

Sampling every 50 ms observed catalog app peaks 202480–203248 KiB and owned process-tree
peaks 854256–936368 KiB. Across growth, app peaks reached 221328 KiB and tree 1030544 KiB.
These are sampled process peaks, not worker-only measurements or hard allocation
bounds. Detailed capture results, timings, cleanup and stderr remain under
`context/runtime/native-capture-work/`; configured byte/string limits explain the
named oversized cases rather than any arbitrary failure being called a limit.

The immutable fixtures and reviewed native reader define the supported workload.
General observation, current coordinates, OS posting, model/Codex integration,
request/response editing, traffic baselines and external network effects remain
unavailable. Source-level lifecycle/late-callback defenses do not claim that this
four-cycle smoke exercised every navigation, wake, death or held-clock fault.
Earlier unexplained availability and CEF teardown failures remain documented in
their original unit reports; these successful joins do not establish their causes.

See [workflow review](../../papers/native-table-workflow-code-review.md),
[workflow plan](../plan/native-table-workflow.md),
[capture plan](../plan/native-capture-work.md), and
[native construction](native-shell.md).
