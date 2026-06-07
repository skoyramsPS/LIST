---
name: add-skill
description: >-
  Add a new skill to TheLIST harness. Takes an idea from the human, interviews
  to pin down the skill's single responsibility, writes the SKILL.md to the
  project's quality bar, syncs it to .agents/skills/, and registers it in
  docs/HARNESS.md §6. Invoke whenever a new /skill-name command is needed.
---

# Add Skill — TheLIST

## Purpose

Write a new skill from scratch and land it in the harness correctly. The output
is a SKILL.md that a cold agent can read tomorrow and behave identically to one
that was briefed by hand.

## How skills are discovered

Skills live in `.claude/skills/<name>/SKILL.md`. `.agents/skills/` is a
content-copy mirror of `.claude/skills/` — a symlink cannot be used because
`core.symlinks=false` on Windows breaks Git operations. After writing a skill,
Phase 3 syncs the copy so Codex sees it too.

## Position in the workflow

Invoked directly — does not feed into another skill. Produces a committed,
registered, verified skill file.

## Phase 1 — Pin the single responsibility

A skill must do exactly one thing. Before writing a single line, establish what
that one thing is. Ask the human:

1. **What is the trigger?** When should an agent invoke this skill? Be specific.
   If the answer contains "or" more than once, this is probably two skills.

2. **What does the agent do?** Interviewer (asks questions, writes no files),
   implementer (writes code/docs), reviewer (reads and reports), or coach
   (explains without acting)? One role per skill.

3. **What is the output?** Name the exact artifact: session summary in chat, a
   file at a specific path, a findings report, or nothing (conversation only).

4. **What does the agent read before acting?** Specific docs, codebase paths,
   conversation context.

5. **What does the agent never do?** Name the explicit out-of-scope actions.
   Every skill needs a hard boundary — without one, agents drift.

If answers to 2 and 3 describe two distinct outputs or roles, split into two
skills and run this skill twice.

## Phase 2 — Write the SKILL.md

Create `.claude/skills/<name>/SKILL.md`. Name: lowercase, hyphenated, describes
the one thing (`grill-with-docs`, `to-prd`, `tdd` — not `helper`, `utils`).

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

1. **Sync to `.agents/skills/`:**
   ```
   dart run tool/check_skill_links.dart --fix
   ```
   This rebuilds `.agents/skills/` as a content copy of `.claude/skills/`.
   Never create `.agents/skills/<name>/` manually — it will drift.

2. **Add §6 entry to `docs/HARNESS.md`:**
   Insert a `### .claude/skills/<name>/` subsection. Include: when to invoke,
   what it does, workflow summary, output. The path token
   `.claude/skills/<name>/` must appear verbatim — doc-honesty checks it.

3. **Run `dart run tool/verify.dart`** — all seven stages must be green:
   - `skill-links` confirms the copy is in sync
   - `doc-honesty` confirms the new path resolves on disk

## Hard rules

- **One responsibility.** "Or" in the description more than once → split.
- **Write for a cold reader.** The SKILL.md must be fully self-contained.
- **Never add to HARNESS.md before the file exists.** doc-honesty will fail.
- **Always run `--fix` after writing or editing a skill file.** The copy in
  `.agents/skills/` does not update itself.
- **Do not mark done until `make verify` is green.**
