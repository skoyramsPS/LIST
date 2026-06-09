---
name: to-tasks
description: Break a PRD or plan into independently-implementable tasks saved as markdown files in docs/tasks/. Use when the user wants to convert a PRD into implementation tasks, create a task breakdown, or split work into vertical slices. Each task must be completable behind a green make verify.
---

# To Tasks — TheLIST

Break a PRD or plan into independently-implementable tasks using vertical
tracer-bullet slices. Each task must be completable with a green
`dart run tool/verify.dart`.

## Process

### 1. Gather context

Work from whatever is in the conversation. If the user passes a PRD filename,
read it from `docs/planning/active/`. Always read `AGENTS.md` and
`docs/architecture/index.md` first — task descriptions must respect the layering
rules, grep gates, and doc-honesty requirements.

### 2. Check the harness prerequisites (PRD §22)

Before drafting any tasks, check whether this work triggers any of the three
harness prerequisites captured in the master PRD `docs/planning/active/the-list/PRD.md §22`:

- **§22a** Font assets — triggered by the first List* widget or any widget using
  Plus Jakarta Sans. If triggered, the font task must be its own task that
  **blocks** the first UI task.
- **§22b** Wire gen_schema.dart — triggered by the first Drift table. Must be in
  the same task as the first Drift schema file, not a separate follow-up.
- **§22c** Activate riverpod_lint — triggered by the first Riverpod provider.
  Must be in the same task as the first provider file.

### 3. Draft vertical slices

Break the work into **tracer bullet** tasks. Each task is a thin vertical slice
that cuts through ALL required integration layers end-to-end — not a horizontal
slice of one layer.

Tasks are either **HITL** (Human In The Loop — requires a decision or design
review before the agent can proceed) or **AFK** (agent can implement and verify
fully autonomously). Prefer AFK where possible.

**Vertical slice rules:**
- Each task delivers a narrow but complete path through every layer it touches
- A completed task must leave `dart run tool/verify.dart` green
- A completed task must have at least one failing test written before implementation (AGENTS.md §4)
- A completed task updates the relevant `docs/architecture/*.md` file if any new `lib/...` path or symbol was introduced (AGENTS.md §5)

**What makes a bad task (horizontal slice — reject these):**
- "Write all the Drift tables" (schema only, no behaviour)
- "Write all the repository interfaces" (interface only, no implementation)
- "Write all the widget tests" (tests without implementation)

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each task show:

- **Title**: short imperative name
- **Type**: HITL / AFK
- **Blocked by**: which other tasks must complete first (use task numbers)
- **Harness obligation**: which of the seven verify stages this task primarily exercises
- **PRD sections covered**: which user stories or decisions this addresses

Ask:
- Does the granularity feel right?
- Are the dependency relationships correct?
- Should any tasks be merged or split?
- Are the correct tasks marked HITL vs AFK?

Iterate until the user approves.

### 5. Write the task files

For each approved task, save a file to `docs/tasks/<NNN>-<slug>.md` using the
template below. Use zero-padded three-digit numbers (`001`, `002`, …) so
directory listing gives natural order.

Publish in dependency order (blockers first).

---

## Task file template

```markdown
# <NNN>: <Title>

**Type:** HITL / AFK
**Status:** pending
**Blocked by:** <task number(s) or "None — can start immediately">
**Harness stages exercised:** format / analyze / grep-gates / schema-fresh / doc-honesty / doc-coverage / test

## What to build

A concise description of this vertical slice. Describe end-to-end behaviour, not
layer-by-layer implementation steps.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] <specific behaviour criterion 1>
- [ ] <specific behaviour criterion 2>
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

List any gate this task must not violate (copy from AGENTS.md §3 as relevant):
- No `DateTime.now()` in `lib/sync/`, `lib/repositories/`, `lib/notifications/`
- No raw colour hex or spacing literals in `lib/features/`
- No banned Material visual widgets in `lib/features/`
- No Drift import outside `lib/repositories/`
- No Supabase import outside `lib/sync/`

## Harness prerequisites triggered (if any)

Reference PRD §22a / §22b / §22c if this task triggers one of the three
infrastructure obligations. Describe exactly what must be done in the same commit.

## No-doc-impact (optional escape hatch)

Leave this section out entirely if you checked the <!-- doc-update --> criterion above.
Only add it when the task genuinely introduced no new `lib/...` paths or symbols
(e.g. test-only, tooling-only, or config-only changes):

**No-doc-impact:** <reason>

## Notes

Any additional context, open questions, or links to relevant architecture docs.
```
