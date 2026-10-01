# Agent connections research, 2026-10-01

Read project instructions and Blackbird, followed by the newly established
project/research READMEs. Applied the OpenAI Docs skill for native Codex
integration: official topic search, then opened the official App Server, MCP
removal, external MCP client and Sign in with ChatGPT documentation. No account
configuration or credentials were accessed.

Produced `papers/agent-connections.md` and `papers/agent-sources.json` with 25
primary documentation/repository leads. Inspected selected current source files
using raw upstream reads and GitHub tree inventory, not installation or builds.
The acquisition owner handles archived/pinned source restoration. This lane's
HEAD reads are explicitly preliminary and must be compared against acquired pins.

Material findings: the old Codex MCP-server hosting direction is removed;
App Server and external browser MCP are distinct directions; App Server remains
documented experimental; Playwright MCP's source moved to the Playwright
monorepo; its origin filters explicitly are not a security boundary; general
JavaScript evaluation can bypass narrow action policies; next-step pause is not
strict human takeover; and existing-profile attachment conflicts with some
containment assumptions in Agent Browser. Stagehand's Codex example illustrates
that read-only filesystem permissions do not stop external browser mutations.

Noted a source-audit lead in Agent Browser's policy helper: swallowed load errors
require examining the dispatcher before making an end-to-end enforcement claim.
The Browser Harness repository was inventoried rather than deeply reviewed.
The dated W3C BiDi draft fetch failed and remains a source acquisition task.

This is research, not a dependency selection or product implementation. Proposed
future local-site experiments use received mutations as the direct oracle for
revocation, stale approval, duplicate dispatch and bypass behavior.
