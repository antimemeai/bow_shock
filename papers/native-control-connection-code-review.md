# Independent native control parent review

2026-10-02. Root independently reviewed the original Foundation/POSIX parent
connection written by the native-shell owner, the helper's actual wire contract,
and the direct process probe/driver. This review covers a control-only private
child, not native input posting, physical shortcuts, quiescent OS effects or
capture responsiveness. No permissions, keychain records or signing identities
were changed.

The constructor has a two-second launch/initial-ACK budget; live requests have
100 ms, helper leases 250 ms, heartbeat due after 50 ms and poll waits 10 ms.
These are conditional scheduling requirements. The worker checks actual
continuous time and a nonblocking thread-safe authority provider independently
of AppKit callbacks. One ordinary request and one accepted caller fence/callback
slot are bounded. Stop cannot renew the old lease; the next heartbeat preserves
Fenced state. Exact 160-byte ACK equality verifies sequence, run, fence, status,
reserved bytes and absent input capability. Expiry/fault retires readiness before
main delivery and owned TERM/KILL/reap; final join stays outside the live UI.

Spawn moves sources above stdio, builds distinct private pipes, closes inherited
extras and supplies only LANG=C. Darwin pipe-buffer capacity permits one whole
160-byte nonblocking write. PID metadata is not reused for signalling after
reap. The worker retains ownership through uncommon uninterruptible cleanup;
no hard kernel exit deadline is inferred. The authority provider is trusted code
and must remain nonblocking. This is not a sandbox against the native parent.

## Actual independent runs and corrections

Root's first full ten-method run passed nine and failed the closed-parent-stdin
positive with `INIT nil`, PID46911, then disconnect/reap. It contained no terminal
phase diagnostic. Source inspection found no descriptor-collision explanation;
the nil availability cause remains unresolved. The owner added bounded static
failureReason and actual owned childExitCode, retained completed outputs before
assertions and sampled timeouts before killing only the still-owned process.
The production budgets and ownership contract did not change.

Root's next full eleven-method run passed ten and failed the Python idle peer:
`initialization_deadline`, PID53295, actual child exit137. This did not establish
the intended idle-exit path. Malformed peer checks also accepted any nil ACK,
allowing startup starvation to masquerade as a tested malformed frame.

The owner replaced the Python fault peer with an original compiled POSIX/C++
peer. Its wire offsets are independent of the production codec. Ready/request/
response phase markers and exact static reason assertions now require the
intended path. Idle services heartbeats until a positive main callback releases
it, then must exit0; TERM-ignore must install its handler before invalidate and
exit137. The probe also moves its deliberately inherited /dev/null above stdio,
and its ordinary live timeline starts at delivered initialization, separating
the explicit late-main authority-loss case from a presentation race.

Root independently read these final corrections and ran exactly the affected
idle/malformed/TERM-ignore methods. All three passed in12.998s. The malformed
method exercises six actual peer modes and requires noncanonical_reply,
unexpected_reply, reply_eof or the intended initialization deadline after its
record/ready phase. Exact child PIDs are absent after join. The retained direct
output is `context/runtime/control-connection-focused-review.log`; each probe's
completed output is under `context/runtime/control-connection-cases/`.

Earlier independent positive methods exercised actual helper heartbeats/fence7,
worker progression and reap while the main loop was stalled, no late successful
fence delivery after authority loss, closed stdio, constructor denial, whole-parent
SIGSTOP/helper independent expiry and minimal inherited descriptors/environment.
Root did not repeat the entire suite after only the peer correction: the affected
three direct methods bear on that finding. The owner also reports its prior
full eleven-method run and corrected focused native peer runs in the journal.

No concrete source blocker remains for the stated control-only contract.
The earlier real-helper nil startup and a separate sampled overall probe timeout
remain availability observations, not explained defects or successful gate
closure. Their honest record is retained; actual joined catalog servicing must
still earn its N3 scope. This review does not promise operation under arbitrary
host contention, OS suspension or blocked authority-provider callbacks.

Final reviewed SHA-256:

- control_connection.h: 20b170b3ab2338326cb8f649b60236944d5f3b7df6aa824ae3d65e34d432bd8a
- control_connection.mm: b8fe7922a9a9e0bf70e28d8262d9c57c6a8450e3cdbfca0e15bc7335ac132d3c
- independent fault peer: ddd90d420726addef99d63e3b4023105a7b0fa68d3b19ca8ce09c8f3a0a4b096
