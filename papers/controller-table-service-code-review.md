# Controller table service independent review

2026-10-02. Independent review of the new closed Rust table service and its
native provenance/publication extensions. Read the service subplan, wire
contract, protocol/actor/evidence/SQLite clock paths and five direct owner
process tests. No production file, native adapter, CEF bundle or keychain path
was changed or launched. This review owns only this report, journal and ignored
actual-process/SQLite probes. The native table adapter remains a later unit.

The initial snapshot had one high finding and one medium provenance-contract
finding. Both are corrected and independently rechecked below; no concrete
service blocker remains at the stated trusted-native/sole-reap host scope.

## CT-01 — High: terminal actor faults orphan owned clock children

`service.rs:648–661` returns directly through `failed` on pending capacity or
worker/transport failure. `failed` stops Store but assumes that process exit
terminates probe threads. It does terminate those Rust threads; their separately
spawned OS children remain alive. `clock.rs:55–84` retains sole Child ownership
inside the clock-query worker and normally kills/reaps at its 500ms timeout.
Once the controller exits, that supervisor no longer exists. The SQLite worker
uses the same query implementation and needs the same ownership treatment.
Rust 1.94.1 explicitly leaves child kill/wait ownership to the application;
dropping a Child does not terminate or reap it. See the matched
[standard-library source](https://github.com/rust-lang/rust/blob/1.94.1/library/std/src/process.rs#L174-L193).

The ignored original probe `context/review-controller-table/orphan.py` configures
an owned clock executable that records its exact PID and execs `/bin/sleep 10`.
Initialize starts a real query; after observing that PID, the parent sends 19
valid table_status records. Pending exhaustion exits the actual controller with
status1. Independently observed ps output for all three trials reports the exact
clock PID as PPID1, state S, command /bin/sleep immediately and again 700ms later,
after the original query's 500ms timeout should have killed it. PIDs43896,43901
and43905 were explicitly cleaned by this probe; it did not signal unrelated
processes. Retained direct output is `context/review-controller-table/orphan.log`.

This is a process-ownership/availability defect, not a demonstrated input or
SQLite authorization escape. Terminal cleanup must cancel and reconcile every
owned query child before controller process exit, including an active SQLite
worker query, without putting blocking process waits back on the live authority
loop. Keep ownership until actual reap and prevent new query spawn after
terminal cancellation. Require a direct capacity/transport-fault process oracle
that checks exact probe PID disappearance and unsuccessful controller exit;
an acknowledgement or elapsed deadline alone does not establish child cleanup.

Also inspected the clock read sequence: bounded1025-byte `read_to_end` occurs
only after successful child exit, outside its 500ms timed wait. A descendant
retaining that stdout can stall the read despite the byte cap. This review did
not independently reproduce that different descendant fault; the cap alone is
not a whole-query time bound. The actual packaged producer does not spawn
children. Corrected ownership/transport documentation must retain that scope
unless the entire read phase is independently supervised.

## CT-02 — Medium: Ambiguous candidates are not grounded in supplied fragment

The original wire describes Ambiguous as retaining candidate fragments without
inventing a selected node fragment. `native_batch` checks Value/Invalid exact
fragments, Empty's actual fragment and Missing/Inaccessible fragment absence,
but leaves Ambiguous unconstrained. The independent actual process sends the
normal six states with Ambiguous candidates left/right plus
Source.fragment=`invented selected fragment`; neither candidate occurs in that
claimed raw source. It receives table_staged rather than table_error.

Root clarified that the new owned projection legitimately supplies the whole
price cell `USD 12.00 / USD 14.00`, its container native node, and both literal
candidates. That fragment is useful full source provenance, not a selected
value. The initial recommendation to forbid all Ambiguous fragments was too
broad and is withdrawn. Instead bind every literal candidate to the supplied
whole-cell raw fragment when present, rejecting candidates that are not grounded
there. Fragmentless alternatives remain explicit unknown source; preserve the
legitimate two-price cell. This applies to the new native admission, not changing
exact bytes of already retained legacy records. The corrected wire must state
whole-cell provenance clearly so the later native codec can match it.

The same shape probe observed that omitting Missing's Source.node_id is accepted
because serde Option defaults absence to None. The wire currently describes
node_id as required positive-i64-or-null. This is a smaller shape/documentation
mismatch: enforce the required field at the wire boundary, or explicitly
specify its optional absence rather than claiming stricter closure. Nested
state.kind duplicate and positional ObservationRef arrays correctly terminate
with invalid_message; unknown fields remain denied by derived closed records.

## Independent positive and failure-path evidence

Built the current Rust source with the pinned toolchain into a separate ignored
review target:

```sh
cargo +1.94.1 build --locked --bin bow-shock-controller \
  --target-dir context/review-controller-table/target
python3 context/review-controller-table/probe.py
python3 context/review-controller-table/orphan.py
python3 context/review-controller-table/handoff_close.py
```

The probes use the original actual native clock executable
`context/build/native/bow_shock_clock_probe`, private subprocess pipes and
independent Python SQLite connections. No fabricated clock, replacement
controller surrogate or second acknowledgement oracle is used. The first broad
probe's optional whole-parent-pause experiment completed four non-orphan trials
then hit its own PID-marker setup timeout; it does not earn a pause-ownership
conclusion. CT-01 instead has the separate deterministic capacity-fault trace.

Verified these concrete outcomes:

- Exact Review.content preserves all six field states, native IDs, raw fragments
  and capture interval. Actual SQLite review bytes equal that returned string;
  read/list PublicationGuard equals the actual persisted boot/deadline. A clean
  same-boot native restart under a new host run reopens the exact original batch
  and original unchanged deadline.
- An approval cached before Stop retains its correlation identity when committed
  afterward, but status is rejected/deleted, read is denied and actual SQLite
  rows remain zero. A later healthy close sets dirty0. table_committed therefore
  names a lifecycle correlation; it does not itself attest to row persistence.
- Six large review replies fill/block actual stdout while a short-lived computed
  read waits behind them. After its 1000ms retention expires, draining the prior
  writer yields publication_unavailable for that read, and independent SQLite
  has zero rows. An initial two-review attempt fit the OS pipe and returned an
  already-started read; it was insufficient backpressure, not a source failure.
- A real BEGIN IMMEDIATE lock across commit and close reaches SQLite failure.
  The process exits1, actual meta.dirty remains1 and rows remain zero; no clean
  close acknowledgement is emitted. Blocking native probe and SQLite IO remain
  off the authority loop, and the failed run does not become a clean reopen.

Source review finds single actor ordering, one clock job, bounded queues and
single writer handoff. Stop requires no native sample, advances one serialized
counter and invalidates older captured pending/gated work. Preparing approvals
are fenced; final-admitted effects, including pending admission persistence,
may complete and can require later status/cleanup. Publication rechecks managed content and
current generation only after writer readiness, while required native guards
allow the next UI adapter to withhold bytes that become stale after handoff.
Started bytes are not retractable. This review does not claim atomic native
clock sampling with SQLite COMMIT, fresh UI assignment, controller cleanup after
SIGKILL, all lifecycle schedules, N3 workload bounds or any input capability.

Initial reviewed source SHA-256:

- protocol.rs: cc83d4d124abd2ad4b87bf62da3adfecf3ed7c320eaecd4e62176df6ddcd9c31
- service.rs: 68785b882fe0aff400d517b01ace15702b9428e0a2b5c4389f229fa94fac0141
- evidence/lib.rs: 3af314156f3782a5159784d544d63c07f9fec95f633004cc04a1398faa0266eb
- evidence/clock.rs: 5f922c47f6cfe6eebbe6ed09a2bf86987824e26dde36e4471401c24d24dca3db
- evidence/worker.rs: aa5202898dd8c11e6889bbb8fdf76c3fd82977de9e48850fbd6eb7d7619b3b1d

## Independent correction recheck — CT-01/CT-02 closed

Read the correction subplan and final production diff, then rebuilt only the
separate pinned review target. Ran the original independent process/SQLite
traces through `context/review-controller-table/recheck.py` plus
`handoff_close.py`. Both final commands exited0. Retained final outputs are
`recheck-final-warmed.log` and `handoff-close-final.log` in that ignored directory.
No product source was changed by this reviewer.

CT-01 now has one shared ClockOwner across the actor's sampling worker and the
Store SQLite worker's actual queries. Active registration occurs before checking
cancellation, with sequentially consistent counters; terminal cancellation can
therefore wait for every already-started spawn without allowing a later accepted
query to escape a zero-count observation. The query's owned Child guard retains
its activity until actual kill/wait reconciliation, retries cleanup errors and
releases the count only afterward. All controller returns enter terminal
cancellation/quiescence outside the healthy authority loop; blocked private pipe
threads are not joined. A two-second diagnostic does not claim cleanup succeeded
or permit process exit while ownership is unresolved.

The original pending-overflow correction oracle finds exact PID51249 absent
when the actual controller exits1. The independent two-worker transport oracle
first makes startup return an actual original clock sample, then observes two
owned sleep probes simultaneously: one inside SQLite startup's clock gate and
one inside the serialized clock sampler. Breaking stdout and sending ping exits
the controller1 only after exact PIDs51261 and51262 disappear. This directly
covers both shared-owner query lanes and actual process cleanup, not merely a
counter, timeout or mocked supervisor.

CT-02 now requires every nonempty Ambiguous candidate to occur literally in a
supplied whole-cell fragment, accompanied by a positive container node. The
independent invented-fragment, missing-other-candidate and fragment-without-node
inputs return table_rejected with zero actual rows. The real-style
`USD 12.00 / USD 14.00` whole cell and both literal candidates stages successfully;
fragmentless alternatives remain explicit non-selected-source evidence. Required
nullable node_id omission now terminates with invalid_message. Duplicate kind
and positional observation still terminate. Exact six-state contents, cached
approval-after-Stop rejection/zero rows, persisted deadline/native clean reopen,
stale computed read withholding after actual blocked stdout and failed dirty
close under actual SQLite timeout all remain green on the corrected binary.

Two initial correction probe attempts failed their own newly written script
availability setup before a target query PID could be observed; one timed out a
three-second setup command. They establish no ownership result and are retained
as `recheck.log`/`recheck-final.log`. The final probe first executes the actual
script in a test-only availability branch that execs the original native clock,
checks its real output, then runs the fault branches. Its ten-second setup bound
is not a runtime supervisor change or reused clock sample: service queries still
have the unchanged500ms limit and take new actual native samples. The final
process/PID assertions passed, rather than treating setup denial as fault closure.

No concrete service blocker remains at the stated trusted-native scope. Host
configuration must keep the original no-descendant producer and Rust's sole
child-reap ownership, including a default SIGCHLD disposition. Native adapter
spawn will reset that disposition explicitly; this review did not exercise an
ignored-SIGCHLD host. An arbitrary descendant retaining stdout is still outside
this contract and the1025-byte read cap is not a general read-time bound. Forced
process termination bypasses Rust cleanup; this does not claim parent-wide
cleanup after SIGKILL/SIGTERM or unexpected kernel ownership loss. Native UI
publication, parent transport and later workload/input gates remain separate.
The owner reports the final47-case Rust basic gates green; this reviewer did not
repeat those whole gates because the changed direct branches above bear on the
identified defects.

Final independently compiled production SHA-256:

- protocol.rs: 5bde34fc047d8c2626f1200c0dae989b42a9d9e506ebc7aa985fc0346c3a78e6
- service.rs: 907f06ced73edcffd1d7060ef2f1c3ae74eb675bf3d102ab774b78fe25b2c14f
- evidence/lib.rs: bb493821e9b26697638d90e2beb6bc8ace45579406d98ac4d04ea62da8d23d13
- evidence/clock.rs: e40a90ad6c1b576bcc16f126ddf1e918ada77f0fac189384ba91ad5865b5aec4
- evidence/worker.rs: c30e1ba6eb2397f55bb292e769f30daf56c2c0d44321d8d344ebe2197818676e
