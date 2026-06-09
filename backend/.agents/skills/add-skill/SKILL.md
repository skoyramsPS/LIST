---
name: add-skill
description: >-
  Add a new skill to the TheLIST backend harness. Takes an idea from the human,
  interviews to pin down the skill's single responsibility, writes the SKILL.md
  to the project's quality bar, syncs it to .agents/skills/, and registers it
  in docs/HARNESS.md §6. Invoke whenever a new /skill-name command is needed.
---

# Add Skill — TheLIST Backend

## Purpose

Write a new skill from scratch and land it in the harness correctly. The output
is a SKILL.md that a cold agent can read tomorrow and behave identically to one
briefed by hand.

## How skills are discovered

Skills live in `.claude/skills/<name>/SKILL.md`. `.agents/skills/` is a
content-copy mirror — a symlink cannot be used because `core.symlinks=false`
on Windows breaks Git. After writing a skill, Phase 3 syncs the copy so Codex
sees it too.

## Position in the workflow

Invoked directly. Produces a committed, registered, verified skill file.

## Phase 1 — Pin the single responsibility

A skill must do exactly one thing. Establish it before writing a line:

1. **What is the trigger?** When should an agent invoke this skill? If the
   answer contains "or" more than once, this is probably two skills.

2. **What does the agent do?** Interviewer (asks, writes no files), implementer
   (writes code/docs), reviewer (reads and reports), or coach (explains without
   acting)? One role per skill.

3. **What is the output?** Name the exact artifact: chat summary, a file at a
   specific path, a findings report, or nothing (conversation only).

4. **What does the agent read before acting?** Specific docs, codebase paths,
   conversation context.

5. **What does the agent never do?** Name the explicit out-of-scope actions.
   Every skill needs a hard boundary.

## Phase 2 — Write the SKILL.md

Create `.claude/skills/<name>/SKILL.md`. Name: lowercase, hyphenated, describes
the one thing.

**Required structure:**

```
---
name: <name>
description: >-
  <3–5 sentences. When to invoke, what the agent does, what it outputs.
  No bullet points. This is what routing agents read.>
---

# <Title> — TheLIST Backend

## Purpose
## Position in the workflow
## [Behavioural contract sections]
## Hard rules
```

**Quality bar — done when:**
- A cold agent reading only this SKILL.md behaves identically to one hand-briefed
- The description frontmatter alone lets a routing agent decide whether to invoke it
- Exactly one output format
- Every out-of-scope action named

## Phase 3 — Sync, register, verify

In this exact order:

1. **Sync to `.agents/skills/`:**
   ```
   deno run --allow-all tool/check_skill_links.ts --fix
   ```

2. **Add §6 entry to `docs/HARNESS.md`:**
   Insert a `### .claude/skills/<name>/` subsection. Include: when to invoke,
   what it does, workflow summary, output. The path token
   `.claude/skills/<name>/` must appear verbatim — doc-honesty checks it.

3. **Run `make verify`** — all seven stages must be green.

## Hard rules

- **One responsibility.** "Or" in the description more than once → split.
- **Write for a cold reader.** Fully self-contained.
- **Never add to HARNESS.md before the file exists.** doc-honesty will fail.
- **Always run `--fix` after writing or editing a skill.**
- **Do not mark done until `make verify` is green.**
