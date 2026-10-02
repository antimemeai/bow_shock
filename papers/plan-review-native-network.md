# Plan review: native runtime and network

2026-10-01. Reviewed [the integrated plan](../docs/plan/README.md),
[native runtime lane](../docs/plan/native-runtime.md) and
[network lane](../docs/plan/network-roadmap.md) against the reviewed design and
its tribunal. This reviewer principally authored the authority plan and is
reviewing other owners' native/network sequence. Findings concern planned
dependency and capability boundaries; no implemented browser is required to
resolve them.

## NN-1 — Capture gate depends on a helper created after that gate

**High; construction dependency cycle.**

Native N3's operational-capture experiment requires the independent helper
channel active while measuring Stop under native capture load. Native N4 says
to create the small input helper **only after N1–N3 and authority admission**.
The root first sub-plan instead creates a fixture receiver before the helper
and then implements one finite primitive. No task supplies the independent
channel required to finish N3.

Trace: N1 window and N2 reader work on owned fixtures. The implementer starts
N3, needs the independent helper to test Stop responsiveness during UI/native
capture pressure, and cannot create it until N3 completes. Either the lane
blocks, or it measures the shell's own responsive path and mistakenly calls
that evidence about the independent path. This matters precisely when the CEF
UI thread is busy and host timeout cannot cancel native work.

**Required sequence fix:** split the helper's local control/liveness channel
from OS delivery. Construct the minimal independent control-only owner before
the N3 capture gate, without enabling posting/listening or model-connected
actuation. N4 adds platform permission-sensitive primitives after the capture
and coordinate gates. State the shared-record/admission prerequisites needed
by the early control owner; it must not wait for the full persistent subsystem.

**Direct oracle:** before a native input capability is enabled, stress an actual
owned capture and issue Stop/expire the control lease through that independent
process. Measure receipt/processing at its owner and the shell's response
separately. A shell UI callback or simulated heartbeat alone cannot satisfy
the independent-path condition. OS receiver semantics still belong to N4.

## NN-2 — Native capture bounds gate delegation, but the human reader can ship first

**High; capability enablement is ordered too late.**

Native N2's exit is a working native reader; N3 explicitly introduces its two
measurements as gates **before delegation**. Root P3 depends on P1 observation
plus P2 and may expose ordinary person-operated pages with local extraction.
Neither statement makes N3's actual native-work gate a prerequisite for exposing
full snapshots in that human workflow. Host copy/parse limits in N2 do not bound
Blink traversal/DevTools serialization; the reviewed design explicitly rejects
that substitution.

Trace: N2 succeeds on its small correctness fixtures and P3 begins. The person
opens a very large or rapidly changing page and requests a rendered-page read.
The adapter starts the full native snapshot, rejects the oversized result only
after traversal/serialization, and stops waiting at the host deadline. The
native reader had passed the planned public exit without an operationally
supported workload or independent Stop experiment. The absence of delegated
input does not prevent capture from harming human browsing or stop handling.

**Required sequence fix:** N2 initially exposes only the fixture/development
reader. Split N3 into a capture-work gate before general human observation/P3
and a coordinate gate before input. Enable a full or partial production reader
only for the actually measured supported workload/mode; give any fallback reader
its own native-work and correctness oracle. If that gate fails, retain useful
manual browsing/metadata and unavailable full capture rather than silently
publishing the unmeasured reader. Reflect the dependency in root P1/P3, not only
the input task.

**Direct oracle:** start captures on actual progressively large trees and child
frames, with runtime copy/node/queue limits configured. Inspect native latency,
memory, Stop processing and delivery responsiveness, including a timed-out
capture that is still unresolved. The advertised mode must follow the measured
supported boundary; oversized native work cannot be called bounded because its
eventual callback was discarded. This is a future capability experiment, not a
request to run it during plan review.

## NN-3 — Complete-prototype exit lacks a mandatory supported body-edit case

**Medium; a core capability can remain a permanent optional branch.**

Network N7 correctly requires destructive-stream teardown before body editing,
and its failure branch keeps editing unavailable until the adapter is replaced.
N9 lists N7 only **for body-edit exercise** and permits a narrower labelled
walkthrough. Root P8 depends on the “relevant” P1–P7 capabilities and exits on
a useful tandem task and supported capability matrix. External packet/link
support has an explicit complete-prototype blocker, but no corresponding exit
requires even one supported human existing-response-body edit. The full
roadmap retains craftsmanship as a core requirement, so a partial milestone
and complete acceptance need distinguishable endings.

Trace: CEF interception supports a known synthetic response and narrow request
edit, but fails safe teardown after taking an existing body. N7 truthfully marks
that capability unsupported. N9 skips its optional body exercise and passes the
remaining walkthrough. P8 accepts the useful task/capability matrix. No unsafe
feature was enabled, but the plan can finish without an actual supported body
editor or an explicit product-scope/dependency decision about the failed adapter.

**Required sequence fix:** keep the partial walkthrough useful, but make complete
macOS acceptance require at least the reviewed finite existing-body editing
case with proved takeover/timeout/crash teardown, or an explicit operator-reviewed
scope/design amendment. N7 failure should return a concrete adapter study/
replacement sub-plan rather than silently disappear from P8. This does not
require supporting all trailers, ranges or endless bodies; their rejection is
already correct.

**Direct oracle:** the complete case starts from an actual controlled response,
takes its finite original body, edits bounded content/status/headers through the
supported operation, and compares original server bytes with the page-delivered
replacement. Repeat timeout/target loss/host loss at the destructive boundary;
the original cannot be silently continued and resources must resolve within the
advertised deadline or stay explicitly uncertain/unavailable. A known synthetic
response that never took an existing body cannot stand in for this case.

## Gates that are already honestly planned

No additional finding is issued for the candidate-specific OS queue drain:
native N4 refuses renewal based only on helper death or elapsed target time and
requires actual receiver/OS reconciliation, otherwise delegation stays unavailable.
The sandbox task likewise requires role-specific native evidence or an explicit
unverified stop before untrusted browsing. Their unresolved measurements are
empirical gates, not missing implementation demanded during planning.

The macOS topology decision is early and explicit. An owned macOS guest or Mac
requires deployment review plus joint runtime/input/control-path gates; it is
not silently substituted for the native session. Native packet/link blocking
already prevents a complete external-network claim. Pause/body ownership,
duplicate decision exclusion, host-loss expiry and exact peer/page outcomes are
sequenced before human interception. These strengths should remain after fixing
the dependencies and complete-body exit above.

## Integration recheck and closure

2026-10-01, subsequent pass. Re-read the revised native/network lanes, root
milestones/first sub-plan/full acceptance join, authority subtask boundaries and
[plan dispositions](plan-tribunal.md) against the original traces.

| Finding | Recheck |
| --- | --- |
| NN-1 | Resolved. Native N2a creates the independent control-only helper before N3, after minimal A1/A2 records and initial native identities. It neither waits for the full evidence store nor enables OS posting/listening. N4 extends that owner after the actual capture/coordinate and admission gates. Root subtask joins remove the whole-P1/P2 barrier. |
| NN-2 | Resolved. N2 is explicitly fixture/development-only. N3 capture work gates any general human full/partial reader and P3; coordinates separately gate delegated input. Failed capture modes remain unavailable or require their own measured partial-mode oracle. Root P1/P3 and first sub-plan agree with that order. |
| NN-3 | Resolved. Full P8 and complete network N9 now require N7's existing finite body-edit case, including its destructive-boundary teardown. A known synthetic response cannot satisfy it. Failed body support returns a concrete adapter study/replacement or reviewed scope amendment; a useful narrower walkthrough stays partial/blocked. |

The revised complete join also expressly requires packet-delivery and native
owned path-transition cases, native keyboard/mouse/wheel, scoped inference and
Codex collaboration, learned tables and traffic baselines. The two network fault
cases retain distinct actual native/page/peer oracles; no proxy or guest label
substitutes for their measured behavior. No new sequence contradiction was found
in this focused recheck. Input drain, capture workload, sandbox, body teardown
and macOS confinement/deployment remain empirical gates; closure is plan-level
only, with no implementation or runtime conformance claim.
