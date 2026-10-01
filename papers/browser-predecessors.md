# Browser automation before autonomous agents

Reviewed 2026-10-01. This lane examined primary paper passages, author-hosted
retrospectives, original repository descriptions, and the acquired CoScripter
parser/runtime/sidebar manual-step path. Other source-level targets below are
a next pass; acquisition does not imply exhaustive code review.

Bow Shock inherits a substantial end-user programming tradition. The person can
teach a bounded procedure, inspect its representation, run parts of it, and
intervene where judgment is needed. LLM planning adds another way to propose
procedures; it does not remove the usefulness of demonstrations, visible targets,
explicit waits, or human-owned handoffs. This is our design inference.

## Sources and what they contribute

**Chickenfoot.** The author-hosted chapter describes automation embedded beside
the rendered page, with user-visible keywords, component types, and constrained
matches. Its matcher can report ambiguity rather than silently select a target.
Study this as a precedent for understandable action descriptions and page
annotations. Its JavaScript scripting privileges are broader than the delegation
boundary we want. Old Firefox extension interfaces are historical.
[Chapter](https://up.csail.mit.edu/other-pubs/rewriting-web-with-chickenfoot.pdf),
[original source](https://github.com/bolinfest/chickenfoot).

**CoScripter.** A primary reuse paper explicitly describes instructions that
pause execution while the person makes decisions or acts manually. This is a
close conceptual predecessor of semi-automatic browsing. The original extension
separates event recording (YULE), language/parser/execution machinery (Platform),
and the sidebar. That separation is worth studying. The reuse study uses
observational repository logs; reuse is not task correctness or safety.
[Paper](https://www.cs.cmu.edu/~Compose/paper_42.pdf),
[source](https://github.com/jeffnichols-ibm/coscripter-extension).

**CoScripter in the wild.** IBM's primary abstract reports a field study of over
1,400 scripts and highlights repetition, generalization, reuse, and workarounds.
It motivates studying what people actually delegate rather than judging only
synthetic task success. This entry is abstract-reviewed; the full paper is an
acquisition lead, not a read paper.
[IBM publication](https://research.ibm.com/publications/end-user-programming-in-the-wild-a-field-study-of-coscripter-scripts).

**Ringer.** Its actions/triggers/elements decomposition treats replay as
synchronized interaction with a changing page. Trigger inference examines
successful traces and corresponding responses; element identification and
faithful replay are separate concerns. Read the stated assumptions before
transferring the method: arbitrary timing dependencies and changing application
behavior can violate them. In Bow Shock, readiness, target identity, and
authorization need separate checks. Synchronization is not permission.
[Paper](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/12/oopsla16-web.pdf),
[original source](https://github.com/sbarman/webscript).

**Rousillon and Helena.** Rousillon uses demonstration of one output row to
generalize distributed, hierarchical scraping. Its reported user experiment
involved 15 CS graduate students with programming experience; do not extrapolate
its speed comparison to general browser users. Helena's original repository
offers a related Chrome extension and language; the dissertation develops the
larger automation program. The dissertation's introduction, structure, and
recovery passages were reviewed, not all 136 pages.
[Rousillon](https://schasins.com/assets/papers/rousillon.pdf),
[dissertation](https://schasins.com/assets/papers/dissertation.pdf),
[Helena source](https://github.com/schasins/helena).

**Skip Blocks.** The paper makes repeated collection and recovery depend on
previously collected entities and their freshness. Its results concern scraping
workloads. A history-aware observation cache could help Bow Shock, but this is
not an authorization to replay purchases, messages, or writes. The exact
recovery semantics must reflect the task's side effects.
[Paper](https://schasins.com/assets/papers/skipBlocks.pdf).

**WebRobot.** The primary abstract and problem formulation describe interactive
program synthesis from demonstrations, speculative rewriting, and a 76-task
benchmark. This is a lead for generating inspectable bounded procedures. Detailed
algorithm and evaluation review remains open. The author's page points to MIWA's
repository for code; it contains an implementation archive rather than a
separately verified WebRobot checkout. MIWA is covered in the tandem report.
[Paper](https://arxiv.org/abs/2203.09993),
[author's publication list](https://huangworld.github.io/),
[MIWA reference](https://github.com/ferranschen/MIWA).

## Code reading sequence

1. CoScripter: the acquired parser's `YouCommand` wraps a possible nested command.
   `YouCommand.execute` is a no-op, and `stepExecutedCallback` stops at a following
   manual step by emitting `YOU_COMMAND`. The sidebar listener calls
   `stopRunning`; Step/Run resumes through the execution engine. This path was
   directly read at revision `0ff0c7b60920592826e1d844fac4c24b423e8d1b`. The source files are
   `platform/modules/coscripter-strict-parser.js`, `coscripter-command.js`,
   `coscripter-execution-engine.js`, and
   `extension/xpi/chrome/coscripter/content/coscripter-sidebar.js`. Navigation and
   whether manual work can silently expand a recorded procedure remain audit
   questions.
2. Ringer: trace event recording, trigger inference, target matching, and replay
   monitoring. Compare DOM identity and event order with actual page changes.
3. Chickenfoot: inspect keyword matching, ambiguous matches, and page-bound
   script evaluation. Separate its understandable target language from its
   broad evaluation privileges.
4. Helena: follow demonstration-to-program translation and recovery history.
   Inspect missing submodules before claiming the archive is buildable.

## MIWA archive follow-up

The nested `Interactive-WebRobot-main.zip` in the acquired MIWA repository has
now been extracted separately, preserving the original ZIP and excluding
bundled `node_modules` and filesystem detritus. The restoration manifest records
that second extraction. A narrow source pass read `back_end/lib/interpreter.ts`
through its trace/state operations, the mode/focus logic in
`front_end/scripts/background.js`, and the request handlers in
`react_web/src/components/task/TaskDemo.js`.

The frontend names manual, semi-automation, and full-automation modes. Its
semi-automation instruction asks the person to accept/reject/iterate predicted
actions. TaskDemo exposes individual scraping and bulk activation, plus pause
and restart requests, and categorizes nonexistent, empty, wrong-format, and
duplicate entries. These are concrete interaction and extraction precedents.
Reading these controls does not establish that backend cancellation is prompt,
or that a race after takeover cannot execute another action; those paths remain
to trace.

## Questions carried into Bow Shock

- Can the person select one visible result, demonstrate a repeated operation,
  and authorize a finite set of repetitions with clear stopping conditions?
- Is the proposed procedure legible enough to edit before execution?
- When page identity or target meaning changes, does execution stop for review?
- Can manual steps be first-class parts of a workflow, with explicit resume?
- Is recovery a new proposal when the last action's result is uncertain?

These questions should inform the design and its direct behavioral oracles.
They do not yet constitute a selected architecture or implementation plan.
