# Implementation-plan tribunal: integration and bootstrap

2026-10-01. Independent review of the integrated plan,
[authority/evidence lane](../docs/plan/authority-conformance.md),
[agent/extraction lane](../docs/plan/agent-and-extraction.md) and native milestones.
The reviewer authored the network lane and does not review its principal
implementation choices here. These are plan counterexamples, not executed bugs.

## Findings

### PI-1 — High: durable table admission can block global control processing

**Trace.** A P2 table commit reaches admission. The owner dispatches the durable
registry write and, as specified, waits for that operation before processing
the competing revocation. SQLite is stalled in disk IO/fsync. A Global Stop or
required expiry arrives while another power has a pending effect. An application
timeout does not terminate an already-running native storage call. The owner
either stops processing control until IO completes, or calls its timeout a
finished denial even though the old admission write remains live. Both undermine
the shared ordering/recovery boundary. The helper's finite input lease limits
one native effect; it does not resolve the blocked authority or lifecycle owner.

**Plan change.** Specify a nonblocking authority-to-writer admission protocol.
The owner must make the irrevocable admission versus revocation decision in its
own serialized state without holding the entire control loop for storage. Track
pending durability/writer ownership explicitly, dispatch rows only under the
actual approved admission and live lifecycle fences, and reconcile unknown
storage work rather than assuming a timeout canceled it. Alternatively choose a
precise equivalent protocol that isolates stalled storage from other-power Stop
and preserves the design's admitted-before-revoke versus revoke-before-admit
outcomes. A phrase such as “bounded durable operation” cannot establish the
native bound. A timed-out write is not a durable-success or quiescence oracle.

**Direct oracle.** Stall the real admission writer at its persistence boundary,
issue Global Stop and expiry, and exercise the actual independent native/export
receivers. The control owner processes their fences within the chosen supported
control target while the write remains stalled. Then release/kill the writer:
exact rows/admission state reconcile, required expiry keeps restricted values
unusable and no stale result revives an effect. This replaces a supposed storage
bound with outcomes at the actual owner/store/receivers.

### PI-2 — Medium: two different prerequisites for the first input probe

**Trace.** The integrated P1 milestone and first native sub-plan permit a
human-armed finite input primitive after the runtime/receiver exist. The native
N4 task requires N1–N3 **and authority admission** first, and integrated P2 owns
that production admission. An implementer following the P1 paragraph can post
events through a special bootstrap helper without shared generation/liveness/
revocation ownership; an implementer following N4 waits until P2. The plan has
not chosen which probe's authority and capability contract are required.

**Plan change.** Choose one sequence across both documents. Prefer P1 receiver,
permission/read-only routing feasibility work, with actual human-armed injection
after minimal A2 authority plus the native N1–N3 prerequisites. If an earlier
isolated probe is needed, specify its separate disposable scope and complete
local lease/fence/Stop owner, explain which production claim it cannot enable,
and do not treat it as the N4 passed capability. It must not become an actuator
that the later model bridge accidentally inherits.

**Direct oracle.** A bootstrap trace with no current authority session or after
host-run replacement dispatches zero ordinary OS events through the production
helper. The first allowed fixture primitive has an identified finite authority,
receives Stop and is evaluated at the actual controlled receiver. The phase/task
dependency graph names that same transition.

### PI-3 — Medium: full macOS acceptance needs a required-capability join

**Trace.** Integrated P6 permits an “explicit unresolved deployment decision”
as one branch of its exit. P7 can finish baselines using bounded metadata while
N7 body editing and N8 packet/link remain unavailable. P8 then accepts “relevant
P1–P7 capabilities” and a supported capability matrix. That can be interpreted
as complete macOS acceptance of a useful table/input/browser even though the
operator's human response-body editing or native packet/link experiment is still
blocked. The network lane correctly calls that a partial outcome; the root
milestone needs an equally concrete completion join.

**Plan change.** Separate useful partial prototype exits from full-scope macOS
acceptance. Name the required N7/N8 measured capabilities and the actual human
request/response, external packet/link, baseline and learned-table walkthroughs
that P8 must join. An unresolved topology branch is a decision/blocked status,
not an alternative completion condition. If a requirement must be renegotiated,
record the explicit operator decision rather than declaring every unavailable
capability acceptable solely because the matrix is honest.

**Direct oracle.** The acceptance task exercises each named core workflow on
the selected exact build and observes the direct page/peer/native/DB outcomes.
A missing required capability labels the outcome partial/blocked; it cannot
produce a full acceptance result. This is a milestone rule, not a new receipt
system or a test that certifies another test.

## Considered boundaries without additional findings

The first deterministic human table slice can proceed before inference or native
input, which is coherent. The live bridge waits for actual disclosure transport
tests; a provider switch is explicit and unavailable providers preserve human
work. Jev is advisory and its fixture evaluation is distinguished from a product
SDK/provider choice. Shell-capable Codex is named as a trusted peer rather than
mistakenly constrained by its output schema. Exact CEF/header/API/protocol tuple
resolution occurs at adoption and native compatibility testing, rather than
using independent quarantine pins as a binary compatibility claim.

Review status: findings submitted for owner integration; no product code,
dependency install, actuator or host network experiment was run.

## Integration recheck

2026-10-01. Re-read the changed integrated milestones/first sub-plan, authority
admission protocol, network acceptance join and tribunal dispositions against
the original traces above.

| Finding | Recheck result |
| --- | --- |
| PI-1 | Closed at plan level. Durable preparation is explicitly non-authority; live final admission is serialized without blocking the owner; admission persistence and row handoff are asynchronous and distinct. Stalled/unknown IO cannot dispatch speculative rows or delay other-power Stop/expiry. Required lifecycle fences still supersede prior ordinary admission. Actual DB/receiver stall experiments remain required. |
| PI-2 | Closed at plan level. P1 is receiver/control-only with no posting/listening; initial native identities and minimal A1/A2 precede the independent helper. Actual N4 injection follows minimal A2 and native N1–N3. Root text names subtask joins rather than introducing a full P1/P2 bootstrap cycle. |
| PI-3 | Closed at plan level. Full P8 explicitly requires finite existing-body editing and both confined packet-delivery and native owned-path transition cases, alongside keyboard/mouse/wheel, provider/Codex, baselines and learned tables. Unsupported or unresolved required capabilities remain partial/blocked unless the operator explicitly reviews a scope amendment. |

No new contradiction found in these integration changes. Closure concerns the
written construction sequence only: native/storage/deployment behavior is still
unmeasured, and no product capability is promoted by this recheck.
