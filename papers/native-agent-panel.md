# Native selected-source proposal panel construction

2026-10-02. Implements the [panel plan](../docs/plan/native-agent-panel.md) as
`native/cef/agent_panel.h/.mm`, independent of root's CEF/table join. The compact
AppKit panel accepts one exact Review, its matching original native batch and
publication guard. Copies are immutable and bounded. Up to two six-field rows
generate native `r{row}f{field}` checkboxes; name/price are selected by default.
Preview copies only those selected states, fragments and native identities.
The private column must remain inaccessible without a fragment. Ask sends the
unchanged exact Review and explicit IDs through the reviewed named operation;
the controller owns provider projection and export.

Typed ready metadata gates Ask and names Codex, trusted coding peer, hosted
OpenAI, selected model and measured ChatGPT account reference. Objective is
bounded to2048 UTF8 bytes and task TTL to60000ms, with the actual original guard
still required. One metadata/Start/status call is outstanding at a time;
metadata requests and task polling keep ordinary controls busy without blocking
the native main loop through an inference turn. Between metadata opening polls,
ordinary controls can run; a table operation delays the next metadata request.
Metadata opening has a finite
native-clock budget. Connection response budgets remain unchanged.

A candidate must match the active task and its actual shortened guard, and its
IDs must be a unique nonempty subset of the explicitly selected native IDs.
Its batch must exactly equal fields reconstructed from the retained snapshot,
including all source provenance and states. Generated explanations remain
discussion text. Use rechecks these facts, consumes completed state and hands
root copied batch/guard/IDs for staging and a new exact Review; it cannot approve
or Save. Other completed terminal states can also be consumed without redundant
Stop. Active/in-flight consumption crosses normal revocation.

Retirement clears epoch, displayed source/proposal/task and timers before asking
the enclosing authority owner to revoke started or Start-in-flight work. Metadata
alone requests no Stop. Its occupied wire slot remains busy until the actual
callback, including across new-source assignment. Old callbacks cannot restore
retired publication or clear a reentrantly admitted next request's busy state.
Native guard maintenance runs independently of polling, so completed displays
and pending-call source can retire on actual expiry while wire ownership remains
truthful. Potential provider disclosure stays conservatively visible after data
clear; UI retirement cannot retract handed-off content.

`tests/native_agent_panel.py` strictly compiles the actual AppKit panel, actual
native clock and reviewed connection with a controlled closed-operation subclass.
It tests default/explicit/excluded preview, native ID and objective bounds,
immutable exact Review after caller mutation, typed metadata denial, occupied
slot/reentrant epoch cases, exact subset versus generated/unselected/task/guard
attacks, completed consumption, and actual native expiry before Use and during
Start. The initial construction red is retained in ignored
`context/review-agent-panel/construction-red.log`; final direct state results in
`context/review-agent-panel/final.log`. One too-short opening timer assumption and
one rebuilt-JSON exact-content oracle error were corrected and documented in the
[journal](../journal/2026-10-02-native-agent-panel.md).

This oracle qualifies original AppKit state, callbacks, grounding and native
guard behavior. Its controlled peer does not qualify wire framing/decoding,
provider export/inference, actual CEF lifecycle, durability or input effects.
Those belong to the independent decoder, Rust and root's joined actual tests.
Root independently reviews this source/result before landing the conceptual unit.

Final source SHA256: header
`747e403dfca7e4f277bf51ff8198ef442add84933398cc9cc5d87469999a1cb2`;
implementation `f7193cb7ced8a0728b5175e53d7b04cc157378710ce3d7dafd36fc4ff71c13fa`.
Root added the bounded named objective setter for the joined explicit two-field
task and independently reran the final actual-class oracle successfully; see
[the independent review](native-agent-panel-code-review.md).

The first live join exposed source replacement turning a terminal metadata denial
into opening with no remaining setup worker. A direct actual-class red earned
that correction; final denial remains unavailable, and new fields retain the
typed ready destination caption. The actual-class suite passes with this case in
`context/runtime/native-agent-panel-metadata-retire-green.log`; its earlier red
is retained separately. Independent recheck of this correction is recorded in
the panel review.
