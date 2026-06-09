---
name: add-skill
description: >-
  Add a new skill to TheLIST harness at the correct scope. Asks whether the skill
  belongs at monorepo root, in app/, in backend/, or in multiple locations. Takes
  an idea from the human, interviews to pin down the skill's single responsibility,
  writes the SKILL.md to the project's quality bar, syncs it to .agents/skills/
  mirrors, and registers it in the relevant HARNESS.md. Invoke whenever a new
  skill is needed anywhere in the monorepo.
---

# Add Skill — TheLIST (Monorepo)

## Purpose

Write a new skill from scratch and land it in the harness correctly. The output
is a SKILL.md that a cold agent can read tomorrow and behave identically to one
briefed by hand.

## How skills are discovered and where they live

Skills live in `.claude/skills/<name>/SKILL.md` at the relevant scope:

- **Monorepo root** (`.claude/skills/`) — cross-cutting skills that apply when
  working at the root level or across both workspaces: `grill-with-docs`, `to-prd`,
  `to-tasks`, `architect-review`, `mentor`, `add-skill`
- **`app/.claude/skills/`** — app-specific skills that rely on Flutter/Dart
  toolchain: `tdd`, `add-grep-gate`, `improve-codebase-architecture`
- **`backend/.claude/skills/`** — backend-specific skills that rely on
  Supabase/Deno toolchain

`.agents/skills/` is a content-copy mirror of `.claude/skills/` at each scope level
so other coding agents (Codex, Cursor, etc.) can discover the same skills.
A symlink cannot be used because `core.symlinks=false` on Windows breaks Git.

## Position in the workflow

Invoked directly — does not feed into another skill. Produces a committed,
registered, verified skill file.

## Phase 1 — Pin the single responsibility

A skill must do exactly one thing. Establish what that one thing is. Ask:

1. **What is the trigger?** When should an agent invoke this skill? If the answer
   contains "or" more than once, this is probably two skills.

2. **What scope does this skill belong to?**
   - Works at monorepo root or across both workspaces → root scope
   - Relies on Flutter/Dart toolchain or `app/` layering rules → app scope
   - Relies on Supabase/Deno toolchain or `backend/` rules → backend scope
   - Needed in multiple scopes → write separate SKILL.md files per scope, each
     tuned to that workspace's conventions

3. **What does the agent do?** Interviewer (asks questions, writes no files),
   implementer (writes code/docs), reviewer (reads and reports), or coach
   (explains without acting)? One role per skill.

4. **What is the output?** Name the exact artifact: session summary in chat, a
   file at a specific path, a findings report, or nothing (conversation only).

5. **What does the agent read before acting?** Specific docs, codebase paths,
   conversation context.

6. **What does the agent never do?** Every skill needs a hard boundary — without
   one, agents drift.

If answers to 3 and 4 describe two distinct outputs or roles, split into two
skills and run this skill twice.

## Phase 2 — Write the SKILL.md

Create `.claude/skills/<name>/SKILL.md` at the determined scope.
Name: lowercase, hyphenated, describes the one thing (`grill-with-docs`, `to-prd`,
`tdd` — not `helper`, `utils`).

**Required structure:**

```
---
name: <name>
description: >-
  <3–5 sentences. When to invoke, what the agent does, what it outputs.
  No bullet points. This is what routing agents read — make it unambiguous.>
---

# <Title> — TheLIST

## Purpose
<One paragraph. What problem does this skill solve? Agent's role?>

## Position in the workflow
<One sentence or short diagram showing where this skill sits.>

## [Behavioural contract sections — vary by role]
```

**Quality bar — done when:**
- A cold agent reading only this SKILL.md behaves identically to one hand-briefed
- The description frontmatter alone lets a routing agent decide whether to invoke it
- Exactly one output format (or zero for conversational skills)
- Every invoke case covered; every out-of-scope action named

**Anti-patterns:**
- Description says "handles X, Y, and Z" — that is three skills
- Phase sections with no concrete procedure
- No hard rules / boundary section

**Model against existing skills:**
- Interviewer, no file output → `grill-with-docs`
- Implementer that writes files → `to-prd`, `to-tasks`
- Reviewer that reports findings → `architect-review`
- Coach that never writes the deliverable → `mentor`

## Phase 3 — Sync, register, verify

In this exact order:

1. **Sync to `.agents/skills/` at the same scope level:**

   For app-scope skills:
   ```
   dart run tool/check_skill_links.dart --fix
   ```
   This rebuilds `app/.agents/skills/` as a content copy of `app/.claude/skills/`.

   For root-scope or backend-scope skills, manually copy the SKILL.md to the
   corresponding `.agents/skills/<name>/SKILL.md` at the same level.
   Never create `.agents/skills/<name>/` manually without keeping it in sync —
   it will drift.

2. **Add entry to the relevant `docs/HARNESS.md`:**
   - Root skill → root `docs/HARNESS.md` (create if it doesn't exist)
   - App skill → `app/docs/HARNESS.md`
   - Backend skill → `backend/docs/HARNESS.md`

   Insert a `### .claude/skills/<name>/` subsection. Include: when to invoke,
   what it does, workflow summary, output. The path token
   `.claude/skills/<name>/` must appear verbatim — doc-honesty checks it.

3. **Run `make verify`** in the affected workspace(s). All stages must be green.

## Hard rules

- **One responsibility.** "Or" in the description more than once → split.
- **Write for a cold reader.** The SKILL.md must be fully self-contained.
- **Determine scope before writing.** A root skill written with app-specific
  toolchain assumptions is wrong; an app skill that should be root-level is
  undiscoverable when working at root.
- **Never add to HARNESS.md before the file exists.** doc-honesty will fail.
- **Always sync `.agents/skills/` after writing or editing.** The copy does
  not update itself.
- **Do not mark done until `make verify` is green.**
