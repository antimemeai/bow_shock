# Human-agent tandem browsing: literature and evaluation map

Research date: 2026-10-01. Scope: mixed initiative, delegation, shared browser control, browser-agent evaluation, and agent security. This is a first primary-source research pass, not an exhaustive survey or a hardened design. Engine choices are addressed in [browser-engines.md](browser-engines.md); transport and Codex integration in [agent-connections.md](agent-connections.md); historical implementation detail in [browser-predecessors.md](browser-predecessors.md).

The strongest immediate conclusion is that a semi-automatic browser needs to be designed and evaluated as a **joint activity with bounded authority**. The technical capability to drive a page, an operator's ability to notice trouble, and the browser's enforcement of a delegation are separate properties. The corpus provides precedents for each, but no reviewed system establishes all three for Bow Shock's intended same-session human-agent use.

## How much was read

The [source catalog](tandem-sources.json) contains 37 paper records and 21 official repository records, with original URLs and PDF acquisition candidates. Actual downloads, resolved revisions, archives, and failures belong in the repository acquisition manifest. A source URL in this catalog does not imply local acquisition or successful execution.

- **D — targeted deep read:** original manuscript sections covering the mechanism, evaluation, or limitations were inspected; exact sections and qualifications appear below. This does not claim every appendix or referenced work was read.
- **A — abstract or excerpt review:** the original abstract, author site, or selected manuscript excerpt was reviewed. Treat empirical details beyond those excerpts as unverified.
- **L — verified lead:** an original publication/artifact was located, but substantive reading remains outstanding or the paper was inaccessible.

Deep reads focused on Horvitz, Buçinca, CowPilot, MIWA, WebArena, WebLINX, SeeAct, BrowserGym, AgentDojo, CaMeL, ST-WebAgentBench, UW's agentic browser/SOP work, BrowseSafe, WASP, and ceLLMate. Several classic human-factors papers remain abstract/excerpt reviews pending full-text acquisition. Repository review here primarily means official README/artifact inspection; code-level architectural reviews remain separate work.

## The design tensions the literature exposes

**Automation changes the human's work.** Parasuraman, Sheridan, and Wickens distinguish acquisition, analysis, decision/action selection, and execution; each can have a different degree of automation. This gives Bow Shock a better starting vocabulary than a single global autonomy slider. For example, broad automatic collection of public pages can coexist with operator-controlled selection and a very narrow execution permission. That browser-specific allocation is our inference, not a prescription tested in the paper. [Original paper](https://doi.org/10.1109/3468.844354).

**Presence is weaker than preparedness.** Bainbridge explains how automation can leave the operator responsible for difficult abnormal cases; Endsley and Kiris associate reduced situation awareness with slower decisions after automated-system failure in a navigation task. Neither establishes an optimal browser intervention schedule. Together they motivate measuring whether an operator can reconstruct what happened and recover, rather than counting only how often they touched the mouse. [Bainbridge](https://doi.org/10.1016/0005-1098(83)90046-8), [Endsley and Kiris](https://doi.org/10.1518/001872095779064555).

**An explanation can persuade without improving collaboration.** Bansal and colleagues found that explanations increased acceptance of AI recommendations whether correct or incorrect, without improving complementary performance over their simpler baseline. Buçinca and colleagues found that cognitive forcing reduced overreliance, but did not establish better overall team performance; stronger interventions were less preferred and benefits varied with cognitive motivation. These are decision-support studies, not browser trials. Bow Shock should test explanations, target highlighting, and confirmation together with actual error detection and recovery. [Bansal](https://arxiv.org/abs/2006.14779), [Buçinca](https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca21trust.pdf).

**Efficient invocation and termination belong in the interaction model.** Horvitz's principles couple direct manipulation with automated reasoning, consider uncertain goals and interruption costs, and support refinement and direct termination. The LookOut example degrades to useful partial assistance when it cannot infer a precise meeting time. For Bow Shock, an analogous candidate is to prepare alternatives or fill a draft while leaving the consequential decision with the person. That is a design inference, not evidence of browser reliability. [Horvitz](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/11/chi99horvitz.pdf).

**Trust should track capability and context.** Lee and See distinguish appropriate reliance from simply increasing trust. Parasuraman and Riley distinguish use, misuse, disuse, and abuse of automation. Neither supplies a browser-specific threshold for when to ask. Candidate evaluation should separately measure acceptance of correct suggestions, rejection of incorrect suggestions, unnecessary interruptions, and abandonment of useful automation. [Lee and See](https://doi.org/10.1518/hfes.46.1.50_30392), [Parasuraman and Riley](https://doi.org/10.1518/001872097778543886).

## Closest tandem precedents

### CowPilot: take over and resume in the same task

CowPilot is the closest reviewed LLM-browser collaboration precedent. Its extension presents the next action and target, supports pause/reject/manual intervention/resume, and incorporates human actions into subsequent agent history. A critical qualification: the suggestion automatically executes after at most five seconds unless opposed. Its reported 95% collaborative success and 15.2% human action share come from 27 WebArena tasks, with three authors as human operators. This is promising small case-study evidence, not a general user study or proof of safe delegation. Its completion score can be self-marked by the agent and overridden by the user; the paper says the released extension is proprietary source. [Paper, §§2–4 and ethics](https://aclanthology.org/2025.naacl-demo.17.pdf), [author artifact page](https://oaishi.github.io/cowpilot.html).

Our design question is whether bounded blocks of authority can preserve that smooth handoff while removing the need to watch every five-second countdown. A veto timer must not silently become authorization for sending data or changing external state. The interaction mechanism is worth studying; the authority model needs its own specification.

### MIWA: inspect and repair a procedure without starting over

MIWA combines program-by-demonstration synthesis with a grammar-derived natural-language procedure, visual target correspondence, step-through debugging, incremental demonstration refinement, and anomaly checks. Its within-subject study used 24 participants and reported faster task completion than Rousillon; the study cannot isolate which individual feature caused the benefit. Limitations include heuristic anomaly detection, no support for some dynamic content such as infinite scrolling, and inadequate timing support. This is procedural data collection, not an unrestricted LLM agent. [Author manuscript, §§5–9](https://tianyi-zhang.github.io/files/uist2023-miwa.pdf).

The reusable idea is an inspectable task procedure that the operator can correct locally. There is a meaningful distinction between editing an explicit procedure and trying to correct an agent through conversation alone. [Official source](https://github.com/ferranschen/MIWA) ships React UI, backend, and extension inside `Interactive-WebRobot-main.zip`, including bundled dependency trees. Preserve the archive; study cleaned extracted source without running its installation scripts.

### Interaction-Driven Browsing: a useful hypothesis, untested

Yun and Jang propose an iterative loop in which goals and tasks become more specific through agent suggestions and user input, separating exploration and exploitation modules. The authors explicitly report no implementation or user study and identify interaction fatigue as an unresolved risk. It supports exploring evolving intent, but cannot substantiate productivity or cognitive-load claims. [Original manuscript, §6](https://arxiv.org/html/2509.12049v1).

Historical PLOW, CoScripter, Chickenfoot, Ringer, Helena, and WebRobot belong in the adjacent predecessor report. Their relevance is not restricted to old selectors: demonstration, visible procedures, personalization, pause points, and repair have a long research history.

## A catalog of the paper evidence

The concise entries below identify a role in the research, not an adoption recommendation. Numerical agent results from old papers describe those papers' configurations and should not be treated as October 2026 capability estimates.

### Human factors and mixed initiative

| Source | Review | Use in Bow Shock research |
| --- | --- | --- |
| [Bainbridge, Ironies of Automation (1983)](https://doi.org/10.1016/0005-1098(83)90046-8) | A | Allocation of abnormal work and recovery to the human. |
| [Endsley & Kiris, Out-of-the-Loop Performance (1995)](https://doi.org/10.1518/001872095779064555) | A | Situation awareness and performance after takeover. |
| [Parasuraman & Riley, Use/Misuse/Disuse/Abuse (1997)](https://doi.org/10.1518/001872097778543886) | A | Reliance failures and indicator/monitoring questions. |
| [Horvitz, Mixed-Initiative UI (1999)](https://www.erichorvitz.com/uiact.htm) | D | Uncertainty, partial assistance, interruption, direct invocation and termination. |
| [Parasuraman/Sheridan/Wickens, Types and Levels (2000)](https://doi.org/10.1109/3468.844354) | A | Separate automation allocation by function. |
| [Lee & See, Appropriate Reliance (2004)](https://doi.org/10.1518/hfes.46.1.50_30392) | A | Calibrate reliance rather than maximize trust. |
| [Klein et al., Team Player Challenges (2004)](https://ieeexplore.ieee.org/document/1363742/) | L | Joint activity and directability; full text pending. |
| [Amershi et al., Human-AI Interaction Guidelines (2019)](https://www.microsoft.com/en-us/research/publication/guidelines-for-human-ai-interaction/) | A | 18 design guidelines validated with design practitioners; useful review aid, not task outcome proof. |
| [Bansal et al., Whole Exceed Its Parts? (CHI 2021)](https://arxiv.org/abs/2006.14779) | A | Explanations and complementary human-AI performance. |
| [Buçinca et al., To Trust or to Think (2021)](https://arxiv.org/abs/2102.09692) | D | Selective friction, overreliance, usability tradeoffs; results/discussion/limitations. |

### Collaboration systems

| Source | Review | Use in Bow Shock research |
| --- | --- | --- |
| [MIWA (UIST 2023)](https://doi.org/10.1145/3586183.3606720) | D | Inspect, step, demonstrate corrections, resume a procedure. |
| [CowPilot (NAACL 2025 demo)](https://aclanthology.org/2025.naacl-demo.17/) | D | Same-task action interleaving; qualified small-study evidence. |
| [Interaction-Driven Browsing (2025)](https://arxiv.org/abs/2509.12049v1) | A | Conceptual evolving-intent loop; no implementation/user study. |

### Browser capabilities, data, and evaluation

| Source | Review | What its evidence can and cannot establish |
| --- | --- | --- |
| [WebArena (2023), v2](https://arxiv.org/abs/2307.13854v2) | D | 812 reproducible self-hosted tasks with outcome evaluators; not a live-site or human-agent handoff study. |
| [Mind2Web (2023), v3](https://arxiv.org/abs/2306.06070v3) | A | Diverse real-site demonstrations; offline action scoring does not show safe end-to-end execution. |
| [VisualWebArena (2024)](https://arxiv.org/abs/2401.13649) | A | Visual tasks that text alone cannot represent; builds on execution-based evaluation. |
| [SeeAct (2024), v2](https://arxiv.org/abs/2401.01614v2) | D | Separates action generation from grounding; oracle human grounding must remain labeled. |
| [WebVoyager (2024)](https://arxiv.org/abs/2401.13919) | A | Live-site navigation and multimodal judging; reported judge/human agreement is imperfect. |
| [WebLINX (2024), v1](https://arxiv.org/abs/2402.05930v1) | D | Multi-turn conversational demonstrations and evolving goals; turn similarity is not terminal task success. |
| [WorkArena (2024)](https://arxiv.org/abs/2403.07718) | A | ServiceNow knowledge-work tasks; needs hosted instance and exact paper/task version. |
| [WorkArena++ (2024)](https://arxiv.org/abs/2407.05291) | A | Compositional enterprise workflows; same official source family. |
| [OSWorld (2024)](https://arxiv.org/abs/2404.07972) | A | Adjacent desktop/web/file workflows and execution oracles; broader authority than browser-only scope. |
| [BrowserGym ecosystem (2024), v1](https://arxiv.org/abs/2412.05467v1) | D | Common observation/action/evaluation interfaces; its flexible research action space is not a security boundary. |
| [AgentTrek (2024)](https://arxiv.org/abs/2412.09605) | A | Tutorial-guided synthesized trajectories and VLM filtering; generated traces need independent judgment. |
| [Online-Mind2Web / An Illusion of Progress? (2025)](https://arxiv.org/abs/2504.01382) | A | Live tasks across 136 sites in the paper; task updates make exact dataset/date necessary. |
| [Mind2Web 2 (2025)](https://arxiv.org/abs/2506.21506) | A | Long-horizon information synthesis and agent-as-judge; inspect judge errors before relying on it. |
| [WebArena Verified (2025)](https://openreview.net/forum?id=94tlGxmqkN) | L | Official repository inspected; manuscript blocked. Current repo provides corrected deterministic trace evaluators. |

### Security and policy-aware evaluation

| Source | Review | Use in Bow Shock research |
| --- | --- | --- |
| [Greshake et al., Indirect Prompt Injection (2023), v2](https://arxiv.org/abs/2302.12173v2) | A | Remote attacker-controlled data can become agent instructions. |
| [InjecAgent (2024)](https://arxiv.org/abs/2403.02691) | A | Tool-output injection, direct harm and exfiltration cases. |
| [AgentDojo (2024), v1](https://arxiv.org/abs/2406.13352v1) | D | Adaptive attack environment; benign utility, utility under attack, attacker success. |
| [BrowserART (2024)](https://arxiv.org/abs/2410.13886) | A | Harmful user requests in browser settings; distinct from untrusted-page injection. |
| [ST-WebAgentBench (2024), v1](https://arxiv.org/abs/2410.06703v1) | D | Task completion conditioned on satisfying specified policies. |
| [CaMeL (2025), v1](https://arxiv.org/abs/2503.18813v1) | D | Enforced control/data separation and provenance/capability tracking; explicit limitations. |
| [WASP (2025), v3](https://arxiv.org/abs/2504.18575v3) | D | Realistic attacker placement and separate initiation/completed-harm metrics. |
| [BrowseSafe (2025), v1](https://arxiv.org/abs/2511.20597v1) | D | Realistic HTML injection/distractor corpus and detection tradeoffs. |
| [ceLLMate (2025), v1](https://arxiv.org/abs/2512.12594v1) | D | HTTP-layer semantic permissions; important scope and concurrency assumptions. |
| [Roesner & Kohlbrenner, Agentic Browsers and SOP (2026)](https://agent-security.cs.washington.edu/agentic_browsers_sop.html) | D | Origin-sensitive observations, cross-origin flows, secure UI and memory contamination. |

## What should be learned from the benchmark implementations

WebArena's useful contribution is outcome-based checking over resettable sites, allowing valid alternative paths. Its v2 evaluators include database/API/DOM locators and exact, substring, or LLM semantic matching, so “execution-based” does not mean every oracle is deterministic or equally strong. Its human baseline uses a sampled template set, not all agent task instances. Study the evaluators as specific programs with specific blind spots. [Paper, §§2–3 and appendix](https://arxiv.org/html/2307.13854v2).

BrowserGym provides DOM/AX-tree/screenshot/tab/chat observations, error feedback, and an action mapping layer. The underlying action mechanism permits executable Python with a Playwright page; the default high-level mapping restricts actions. This is a productive experimental interface, but safe execution cannot be inferred from the shape of a function name such as `click`. Inspect what the trusted executor actually exposes and whether any arbitrary-code path remains reachable. [Paper, §§3.1–3.3](https://arxiv.org/html/2412.05467v1), [official source](https://github.com/ServiceNow/BrowserGym).

WebLINX represents dialogue, actions, candidate elements, DOM, screenshots, viewport, and history. Because the objective evolves, it scores turns through intent and action-specific similarity instead of applying one fixed terminal goal. That makes it valuable for conversation/state synchronization research; it is not a replacement for testing the final external effects of a delegated action. Its BrowserGym integration changes evaluated steps and adds tab actions; distinguish WebLINX 1.0 from 1.1/BG. [Original paper, §§3–4](https://arxiv.org/html/2402.05930v1), [official repository](https://github.com/McGill-NLP/weblinx).

SeeAct's 51.1% online task success involves human oracle grounding; its automatic choice-grounding variant reports 37.8% in the same table. That separation is directly useful for locating where assistance helps: correct plan but wrong element, wrong plan, or execution failure. It does not show that an operator supplying all grounding is a low-effort collaborator. [Paper, §§2–4, table 4](https://arxiv.org/html/2401.01614v2).

WebVoyager uses an LMM judge over answers and recent screenshots and reports 85.3% agreement with human judgment. This can help triage open-ended information tasks, but still permits meaningful disagreement. The judge cannot alone establish that no unintended side effect occurred. [Paper](https://arxiv.org/abs/2401.13919), [evaluator source](https://github.com/MinorJerry/WebVoyager).

The current WebArena-Verified README specifies 812 full tasks, a 258-task hard subset, deterministic structural scoring, and offline HAR-based evaluation. The paper forum was inaccessible, and an earlier search-extracted manuscript excerpt had different counts. Keep repository-version facts separate from unverified manuscript findings. [Official repository](https://github.com/ServiceNow/webarena-verified).

## Security mechanisms and their limits

### Origin boundaries survive rendering only if the agent respects them

The UW study tests seven browser families/modes in January–February 2026. It demonstrates one complete cross-origin data-theft attack in Atlas Agent Mode and separately identifies preconditions in other systems; those are not the same claim. An agent that reads a sensitive frame and writes a summary into an attacker's form can bridge a boundary that page JavaScript cannot. The frame example depends on framing/cookie conditions; a malicious inner frame attacking its parent is another direction. The supplied fixtures require two distinct origins. Vendor behavior is a dated experimental snapshot, not verified current behavior. [Paper, §§3–6 and appendix](https://homes.cs.washington.edu/~franzi/pdf/roesner_kohlbrenner_2026_agentic_sop.pdf), [official fixtures](https://github.com/UWCSESecurityLab/agentic-browser-sop).

Our inference: both observations and action arguments need origin provenance. A screenshot, DOM dump, chat summary, or compressed memory can combine multiple origins. A native Codex bridge adds another destination for that information and another authority surface; it does not make provenance unnecessary.

### CaMeL: enforce a policy even when a model is fooled

CaMeL extracts a program/control structure from a trusted request, treats external content through an unprivileged model path, and tracks capabilities/provenance in a custom interpreter. It addresses control/data-flow attacks, not arbitrary factual corruption of an answer. Its discussion acknowledges policy burden, declassification fatigue, side channels, and capability adoption challenges. The released interpreter is a research artifact whose README warns it may contain bugs and may not be fully secure. [Paper, §§2–5 and 8](https://arxiv.org/html/2503.18813v1), [official artifact](https://github.com/google-research/camel-prompt-injection).

Our inference: the agent's plan is a proposal to an executor with bounded authority. Adopting the paper's interpreter is a separate decision and is not proposed here.

### ceLLMate: clicks are too low-level to express the user's permission

ceLLMate maps requests to semantic actions using trusted website-authored sitemaps, selects/instantiates policies from a trusted user task, and enforces them at HTTP interception. Its assumptions include trusted browser/extension environment, no developer-tool/local-file escape, single-turn tasks, sequential actions, and an agent-dedicated session. It leaves WebSocket interpretation and stateful policies to future work; browser lockout discussion assumes the agent is the sole actor. Restricting inter-action data/control flow is outside its scope. [Paper, §§III and VII](https://arxiv.org/html/2512.12594v1), [official artifact](https://github.com/earlence-security/cellmate).

Our inference: HTTP mediation is a useful enforcement experiment, but its assumptions conflict with concurrent human-agent operation. Bow Shock must decide how manual changes invalidate pending permissions, how the executor attributes network effects, and how much site-specific semantic knowledge it can realistically obtain.

### Attacks must be evaluated at the effect they can cause

AgentDojo distinguishes benign utility, legitimate utility under attack, and targeted attacker success, and emphasizes attacks adapted to the defense. WASP distinguishes beginning an injected instruction from successfully completing the attacker goal; limited agent capability can suppress completed harm without providing a reliable boundary. BrowseSafe contributes realistic HTML/distractor samples and layered detection, but classification quality and latency do not establish end-to-end authorization. BrowserART tests harmful user instructions, a separate threat from a malicious page. [AgentDojo](https://arxiv.org/html/2406.13352v1), [WASP](https://arxiv.org/html/2504.18575v3), [BrowseSafe](https://arxiv.org/html/2511.20597v1), [BrowserART](https://arxiv.org/abs/2410.13886).

ST-WebAgentBench makes completion count only when specified policies have no violations. Its v1 separates user consent, out-of-scope, and strict-instruction policies and includes explicit trajectory evaluators. This is a useful criterion; the actual policy oracles still need review for coverage of external side effects and ambiguous task language. [Paper, §3](https://arxiv.org/html/2410.06703v1).

## Candidate research design for Bow Shock

The following are our proposals, not claims proved by the reviewed systems. They should be pressure-tested with the operator before implementation.

1. Define delegation by task, visible browsing scope, allowed effects, destinations, resource limits, and termination conditions. Separate permission to observe, analyze, propose, and execute. Keep these decisions independent of which model or transport is attached.
2. Define who can act at each instant. A human input event can suspend agent execution and invalidate a pending plan; resumption should use a fresh observation. Investigate a simple serial ownership model before assuming truly simultaneous page actuation.
3. Bind a proposed action to the observation it was based on. Navigations, redirects, frame replacement, layout changes, manual edits, and session changes can make a target or payload stale. A confirmation that refers to an obsolete target should not authorize a new one.
4. Keep control status, next material effect, and takeover available in browser chrome. Page content must not spoof a grant or stop control. A request for help should show the concrete issue and allow a local correction or manual subtask.
5. Carry source identity through extraction and summarization. Test cross-origin frames, tabs, hidden DOM text, masked fields, private session content, and durable chat memory. Decide what content may cross into the connected agent's context before optimizing context size.
6. Evaluate useful partial completion. Reaching a draft, collecting alternatives, grounding a tricky element, or handing off authentication can be successful assistance even when full autonomous execution would be inappropriate.

For a first controlled study, compare manual browsing, agent-only execution in the test environment, one-action proposal/approval, and bounded delegation with takeover. Use the same tasks, browser/environment revisions, starting state, and agent/model configuration. Counterbalance task order; avoid using the implementers as the only operators. Include both well-specified tasks and preference changes delivered mid-task.

| Claim to assess | Direct evidence to collect | Failure cases to seed |
| --- | --- | --- |
| The tandem completes useful work | Task-specific final-state oracle, plus legitimate output completeness | Correct answer with incomplete form; duplicate or wrong-recipient submission |
| Delegation remains bounded | Actual executed effects checked against task permission | New origin, changed recipient, repeated transaction, timer expiry, delayed agent result |
| Takeover works | Agent effects after revocation and time to regain usable control | Human navigates/types while model is thinking; request completes after cancellation |
| The human can recover | Recovery accuracy/time from a specified agent error | Plausible wrong selection; hidden state change; long trajectory then failure |
| Assistance reduces effort | Active human time, monitoring time, intervention/correction effort, completion time | Many cheap clicks that require expensive supervision; excessive confirmations |
| Reliance is calibrated | Correct acceptance and incorrect rejection, with known seeded mistakes | Persuasive rationale for a wrong action; legitimate content resembling injection |
| Origin handling is sound | No prohibited disclosure or action across instrumented origins | Outer-to-inner and inner-to-outer frames, cross-tab summary, poisoned memory |

The test environment should make forbidden effects observable directly: a fake recipient mailbox, state-changing endpoint, external capture server, or database mutation. Merely logging that a tool call was allowed/denied is insufficient when page scripts can emit delayed requests. Use one suitable oracle per claim, with separate evidence for materially different failure classes.

Reported comparisons need task IDs/revision, paper/code versions, model identifiers, prompts, observation mode, action vocabulary, step/time limits, reset method, authenticated state, judge version if used, intervention policy, and run date. This is the minimum needed to interpret a result, not a separate certification exercise. Live-web checks add realism later but have mutable content, authentication, and availability; do not mix them into the same success-rate denominator as resettable fixtures.

## Acquisition gaps and further reading

The following belong in the operator shopping list or automated acquisition retry ledger until resolved:

- Bainbridge: the initial publisher path exposed only an abstract/purchase path.
  Acquisition subsequently recovered the full PDF from IFAC. Deep reading still
  remains separate from acquisition.
- Endsley/Kiris and Lee/See: publisher abstract verified; full manuscript reading remains pending. A university PDF candidate exists for Lee/See.
- Parasuraman/Sheridan/Wickens: university original-PDF open returned an internal error. Parasuraman/Riley PDF rendered with no extracted text; local text extraction/OCR may be needed.
- Klein author PDF and Amershi camera-ready PDF: direct browser opens initially
  failed despite searchable original excerpts. The acquisition ledger records
  subsequent recovery or failure; these are not established paywalls.
- WebArena-Verified manuscript: OpenReview browser verification blocked the forum. Retry the direct paper PDF/API through acquisition and reconcile versions before quoting manuscript results.
- CowPilot: public extension/user logs are linked, but the paper explicitly does not release implementation source. Obtain source from authors only if the operator wants it; do not invent a public source repository.
- MIWA: the nested implementation ZIP was subsequently extracted and sanitized.
  A narrow source pass is recorded in [the predecessor review](browser-predecessors.md).
  Backend interruption and cancellation semantics still need deeper tracing.
- WorkArena: source acquisition does not provide the ServiceNow instance needed to reproduce tasks. Assess access/setup before selecting it for an evaluation.
- WASP: official repository is archived and uses submodules. Pin and acquire submodule sources explicitly if studying a runnable complete tree.
- BrowseSafe: author-linked model and dataset are on Hugging Face; this pass identified them but did not acquire weights or dataset. Dataset size/licensing should be reviewed before acquisition beyond the paper/source corpus.

Useful next leads, not yet reviewed evidence: Plan-then-Execute (He, Demartini, Gadiraju, CHI 2025) on daily-assistant user trust/team performance; Progent and FIDES on runtime policy/information-flow enforcement; WebMCP proposals for semantic web actions; newer benchmark revisions including WebArena-Pro and OSWorld 2.0. Follow citations from the primary papers and inspect original artifacts before adding design claims.

The next research step is to read the locally acquired source paths that implement observation, pending action state, cancellation, human-event capture, effect checking, and policy enforcement. Then synthesize a narrow browser control/delegation specification and adversarially review it before product code or dependency selection.
