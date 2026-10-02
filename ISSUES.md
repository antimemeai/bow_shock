# Work and open decisions

## Completed in the initial research pass

- Copy and read the workspace Blackbird doctrine; establish project guidance,
  literature, ignored reference/context stores, journals, and acquisition tools.
- Survey Chromium/CEF and embedding alternatives, native agent connections,
  human-agent tandem systems, historical end-user automation, evaluation, and
  browser-agent security. Preserve primary sources and source revisions.
- Operator scope: dedicated browser window; macOS first, Linux second.
- Follow-up research on native rendered DOM, OS input and behavioral models,
  deliberate external network interventions, request/response editing, Meta
  Pixel baselines, fingerprint consistency, and learned DOM extraction.

## Design phase

The [design set](docs/design/README.md) now specifies runtime/observation,
authority/input, native agent/provider integration, network control, and
evidence/tables. CEF, the language boundary and local storage remain proposals.
The [tribunal](papers/design-tribunal.md) records design findings and dispositions;
the [implementation plan](docs/plan/README.md) and
[plan tribunal](papers/plan-tribunal.md) are also complete at the contract level.
Seven distinct plan findings were integrated and rechecked. Concrete dependency
proposals are ready for discussion; native capability experiments still follow.
Written contracts do not close empirical issues.

Implementation has begun with bounded Rust controller-link framing and the
closed control-only controller process
and the [basic rigor stack](docs/plan/rust-basics.md). The operator explicitly
defers detsim, mutation runs and heavier tiers for the POC. Rust local checks
and independent code review follow each unit; actual CEF/runtime gates are open.

Provider-neutral local/hosted inference and page comparison/table extraction
are working assumptions pending optional operator preferences. The dedicated
window and platform order are operator decisions.

## Remaining decisions and experiments

| ID | Work | Completion evidence |
| --- | --- | --- |
| BS-001 | Define initial tandem tasks and delegation modes with the operator | Concrete workflows, useful partial outcomes, and allowed effects |
| BS-002 | Compare CEF and Qt WebEngine for macOS with a Linux path | Read startup/sandbox/UI/lifecycle APIs and explicit engine/language proposal |
| BS-003 | Specify grants, human takeover, stale actions, and reconnects | Reviewed state transitions and adversarial race traces |
| BS-004 | Define observation scope and origin provenance through agent context | Examples spanning frames, tabs, screenshots, summaries, and memory |
| BS-005 | Select native Codex connection direction and supported protocol version | App Server versus external MCP comparison against installed CLI schemas |
| BS-006 | Design controlled task/effect oracles and effort evaluation | Resettable sites and direct outcomes; monitoring/correction costs included |
| BS-007 | Finish deep reading of the acquired source corpus and missing literature | Specific source-path reading notes; shopping-list gaps reconciled |
| BS-008 | Pressure-test design, then implementation plan | Findings resolved before product code and dependencies |
| BS-009 | Define OS input executor and behavioral model | Native delivery, focus, takeover, and joint movement/timing evidence |
| BS-010 | Compare external network interventions on macOS/Linux | Actual browser/page/server signals for packet loss, routes, and interfaces |
| BS-011 | Specify request/response workbench and capture limits | Coverage matrix for headers/body, redirects, streams, caches, workers, uploads and WebSockets |
| BS-012 | Define tracker baselines and change alerts | Meta Pixel example, meaningful normalized changes, context, and false-alarm evidence |
| BS-013 | Define learned page-type extraction into tables | Reviewed examples, field/row semantics, provenance, ambiguity, and layout drift |
| BS-014 | Assess runtime fingerprint consistency and compatibility | Same-platform/version native browser comparison; no single undetectability score |
| BS-015 | Trace network-tool confinement, capture and teardown | Source-backed coverage/scope matrix and direct controlled endpoint outcomes |
| BS-016 | Evaluate Jev on ambiguous real capture differences and field candidates | Held-out reviewed examples, deterministic comparison arm, missed changes and review effort |

The matched CEF ARM64 runtime, minimal Serde JSON and local SQLite dependencies are now
adopted in [the dependency manifest](docs/dependencies.json). The original
native shell and control-only Rust child pass their construction/failure
oracles. Owned-fixture observation and the local reviewed-table library also
passed direct checks and independent review. The closed table service and
independent native control parent also pass their direct process checks and
independent reviews. The joined native catalog workflow now passes actual
capture/review/Save/SQLite/clean-reopen checks, and its two immutable catalog pages
meet the chosen capture/Stop servicing target. General native capture, coordinates,
input and network capabilities retain their later gates. See
[the POC experiment](docs/experiments/native-table-workflow.md).
The scoped Codex proposal service and native field-selection panel now pass
direct checks and independent review; required Rust basics pass all 69 tests.
The joined task keeps Use, fresh Review and Save distinct and copies original
native values/provenance. Final rebuilt controlled joins now pass exact
Save/reopen, Stop, helper-loss and Quit checks after operator readiness. The
installed Codex task remains pending runtime task diagnosis: the first final
run denied metadata readiness; a later run reached Ask and failed before a
proposal. Both closed cleanly with no saved rows. Prior launch stalls had an
exact owned-process securityd per-item
prompt; no ACL, encryption or signing identity was changed. See
[the agent task experiment](docs/experiments/native-agent-workflow.md).
Other dependencies remain candidates for study. The
operator's detailed requirements are in [the product brief](docs/product-intent.md).
