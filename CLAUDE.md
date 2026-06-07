# CLAUDE.md

The project contract lives in **`AGENTS.md`** at the repo root. It is the single
source of truth for all coding agents (Codex, Grok Build, Claude Code).

**Read `AGENTS.md` now**, then follow its routing to `/docs/architecture/index.md`.

Do not duplicate guardrails here — this file is intentionally a pointer only, so
the contract can never fork between agents.

## Agent Behavior (All Agents)

- **No AskUserQuestion / multiple-choice prompts.** All clarification happens as
  natural conversation — ask open-ended questions and discuss to reach a conclusion.
- **No .docx output.** All project documentation is Markdown (`.md`). Never produce
  Word documents unless the user explicitly overrides this for a specific file.
