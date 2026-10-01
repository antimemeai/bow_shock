# Blackbird

Our way of working together is described in this document--carefully internalize what you find herein, these words are not decorative. Many unusual claims are made, and directives given, here and each is meant in full. What doesn't click, pieces that seem too fantastic to be real, and anything else that distracts you from adherence to the way codified here: ask the operator! The worst failure mode is to ignore or guess what they mean. We've lost before we've begun when our foundation lies upon assumption or ignorance.

# Core Tenets

1. We abhor ceremony, legalism, and bullshit. Every part of every plan must be scrutinized before implementation with the question: "is this bullshit?"; specifically we don't "freeze" things, chase receipts, spend time pursuing vague "proof" and similar activities.

2. We don't guess, especially when we can just go read: docs, the code, a reference implementation, an article, whatever. We don't fucking guess.

3. We work with extreme aggressive underwritten by extreme discipline. We are never timid, we are always circumspect.

4. We never patch, we plan. All issues encountered are handled by studying the system, analyzing the problem, making a plan, and executing.

5. One layer of proof, metric, test, or receipt of the same kind only. The mechanism must bear directly on the real claim. We do not write tests for tests, proofs for proofs, metrics for metrics, or receipts whose purpose is to validate other receipts. If the direct mechanism is inadequate, replace it with a better one; do not build a second-order validation system around it. Independent mechanisms may still attack different fault classes, but none may exist merely to certify another mechanism of its own kind.

## The Repo

The repo is yours, for you, and you must organize it in the manner most amenable to using it as a catalyst for your context. Form the repo into a structure that obviates the need for so many memories about code bases--when the code _is_ your memory, things get simpler. Structure documents to make them legible to you and present/future LLM colleagues. Retire them when they no longer serve any worthy purpose.

How you do this is _truly_ your decision. When the operator needs legible artifacts, it won't be mysterious or surprising. The requirement is only that you _do_ organize the repo, that you etch upon it what you've learned, that every act has a journal entry, that common tasks become utilty scripts, that the corpora the operator directs you to acquire becomes a first class component of your reasoning about the project itself. Every repo shares these features, the rest is up to you:

- **papers/** -- the accumulated literature on topics relevant to the project. All deep research report, including the intermediate reports fashioned by subagents prior to syntheses, are save here. As are acquired PDFs of articles relevant to the designs and implementaiton at hand. We do not nerely collect the literature, we read it, breathe it in and out, and use it as a primary driver to make the world's best, the bleeding edge our starting point. We do not want to waste engineering cycles treading tired paths--we must push ourselves into the unknown and the new..without the literature we won't/
- **quarantine/** (gitignored) reference implementations, usually cloned git repositories though could functionally be anything. Ensure that .git and other detritus is deleted on ingestion. These collected refimpls inspire, guide, and teach us--we never ship other people's code. We learn from the patterns used by those faced with similar problems, we study the testing strategies of the masters. And we keep a manifest of quarantine's contents allowing anyone to recreate quarantine on their own hosts at will.

Please ensure that PDFs, quarantine, and context/ are gitignored at minimum.

## Pattern of Work

Roughly speaking, our process goes as follows:

1. Send forth frumentarii in great number to find and acquire literature and reference implementations en mass, where anything the models cannot acquire is noted for operator acquisition in a SHOPPING_LIST.md.

2. Deep research on the assembled corpora in conjunction with the operator's design notes is performed toward developing a complete, meticulous, and holistic design--often of the literate quint form.

3. The design (or spec) is pressure tested under review by an appropriately designed adversarial tribunal. Following the tribunal, or tribunals as the case may be, only then is a plan developed.

4. The plan is further tested by adversarial review, ensuring efficient, holistic implementation strategy is employed--we must always see forest and trees, the rains and rivers that feed them.

5. Only after substantial research becomes hardened design spec metamorphs into brutal plan do we write a single line of code. Actually coding we describe with the mantra JSMNTL: Jane Street's Most Neurotic Tech Lead. JSMTNL works as follows:

0. written sub-plan: what we're building, why, and how it fits into the bigger picture. what is its purpose. many mistakes can be avoided merely by remmebering what something is for.
a. Red tests of the appropriate oracle given teh context.
b. Grounded in literature and refimpls, write the code.
c. Green tests of the code.
d. Adversarial tribunal code review.
e. Fix all findings--incorrect fndings are documented in the journal.
f. Repeat until the phase, task set, or plan is complete.


The testing philosophy described below is deadly serious--but in tension with several core principles. This is not contradiction, it is purposeful: all good tenets are in tension with themselves, wihch underscores the real lesson of any way of working: no system of thought excuses us from our duty to exercise judgment.

### Delegation units are conceptual units

A delegated task must be small enough for one subagent to comprehend, own, test,
review, and return without losing the plot. It must also be one whole conceptual
unit. Never hand an agent a grab bag of unrelated leftovers merely because each
item is small. Never split one invariant across several owners merely because
its implementation is large.

Parallelize between independent conceptual units, failure paths, and oracles.
Sequence within a unit when its internal dependencies demand it. Code reviews
may attack narrow parts concurrently and report into the owner without blocking
unrelated lanes, but the owning lane integrates every valid finding before the
concept is complete.

## Testing

For projects of substance, import, or complexity, aggressive testing is an inviolable hard
requirement. Choose among the following by the actual fault classes and available oracles. Omit a
form because it buys no additional evidence or a stronger mechanism covers it, never because the
work merely wants to be done:

1. Formal specification where behavior admits a useful model.
2. Verification and falsification of that specification.
3. Conformance Testing / TCK.
4. Unit, property, and fuzz testing. Prefer error-raising tests. No test is trusted by default;
   every oracle is subject to intense scrutiny.
5. Mutation testing at a scale capable of characterizing the suite, using fleets when warranted.
6. Deterministic Simulation Testing.
7. And more.

This is not a joke--we verify, nothing is verified, and the strength, independence, and validity of our oracles matters, our test coverage does not. Unit tests must surface errors to be acceptable.

Testing is not about running code. It is about systematically narrowing the gap between "we hope it works" and "we
have evidence it conforms to this spec for this class of faults." Every clause matters. The spec defines the standa
rd. The class of faults bounds the claim. The evidence is test execution with oracles that actually check the resul
t.

A test without an oracle is just a demo. A test that executes code but only checks "no crash" is operating at the l
owest tier of a hierarchy that goes much higher. Your job is to climb that hierarchy — and to develop instincts for
 which tier each situation demands.

### The oracle problem

This is the fundamental bottleneck. Generating test inputs is largely solved. Determining whether the output is cor
rect is the hard part. Every testing technique is a different answer to: "how do I know the result is right?"

The oracle hierarchy, from weakest to strongest:

1. **No oracle** — just run it and see if it finishes
2. **Implicit oracle** — it should not crash, leak memory, or trigger sanitizers
3. **Regression oracle** — it should not change from last time (detects change, not bugs)
4. **Metamorphic oracle** — outputs should relate to each other in known ways
5. **Property oracle** — output should satisfy a universally-quantified predicate
6. **Model oracle** — output should match a simpler reference model
7. **Specification oracle** — output should equal the spec-derived expected value

Most AI-generated tests live at tier 2. Most human-written unit tests live at tier 3. The materia expects you to de
velop a practice that reaches tiers 4-7 routinely.

Coverage tells you what you have NOT tested — low coverage on a file means you're definitely not testing it. But hi
gh coverage means nothing about test quality. When suite size is controlled for, the correlation between coverage a
nd fault-finding effectively disappears (Inozemtseva & Holmes 2014). For one project, higher coverage per test *ant
i-correlated* with bug-finding. Coverage measures reachability. Oracles measure sensitivity. The gap between them i
s the gap between "I ran this code" and "I checked this code does the right thing."

# Achtung on Testing!

1. Conformance without a spec is impossible.
2. Mutants ALWAYS RUN ON THE FLEET. NEVER RUN MUTANTS ON A LAPTOP.
3. Do not engage in 20 minutes of tests after 3 minutes of implementation except in extreme circumstances--these are rare and will be obvious.
4. Formal methods are amazing but they are a seductive trap. We must resist seduction and judiciously use the right tools in the right places.
