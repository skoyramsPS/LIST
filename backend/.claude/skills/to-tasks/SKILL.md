---
name: to-tasks
description: >-
  Break a backend PRD or plan into independently-implementable tasks saved as
  markdown files in docs/tasks/. Use when the user wants to convert a PRD into
  implementation tasks, create a task breakdown, or split backend work into
  vertical slices. Each task must be completable behind a green make verify.
---

# To Tasks — TheLIST Backend

Break a PRD or plan into independently-implementable tasks using vertical
tracer-bullet slices. Each task must be completable with a green `make verify`.

## Process

### 1. Gather context

Work from whatever is in the conversation. If the user passes a PRD filename,
read it from `docs/planning/active/`. Always read `AGENTS.md` and
`docs/architecture/index.md` first — task descriptions must respect the
layering rules, grep gates, and doc-honesty requirements.

### 2. Draft vertical slices

Each task is a thin vertical slice that cuts through ALL required layers
end-to-end — not a horizontal layer slice.

Tasks are either **HITL** (Human In The Loop — requires a decision or design
review) or **AFK** (agent can implement and verify fully autonomously).

**Vertical slice rules:**
- Each task delivers a narrow but complete path through every layer it touches
  (migration + repository + service + handler + index, as needed)
- A completed task must leave `make verify` green
- A completed task must have at least one failing test before implementation
- A completed task updates `docs/architecture/*.md` if any new path was introduced

**What makes a bad task (horizontal — reject these):**
- "Write all the migrations" (schema only, no behaviour)
- "Write all the repository interfaces" (interface only, no SQL)
- "Write all the RLS policies" (policy only, no test coverage)

### 3. Quiz the user

Present the proposed breakdown as a numbered list. For each task show:

- **Title**: short imperative name
- **Type**: HITL / AFK
- **Blocked by**: which tasks must complete first
- **Harness obligation**: which of the seven verify stages this task primarily exercises
- **PRD sections covered**: which stories or decisions this addresses

Ask:
- Does the granularity feel right?
- Are the dependency relationships correct?
- Should any tasks be merged or split?
- Are the correct tasks marked HITL vs AFK?

Iterate until the user approves.

### 4. Write the task files

For each approved task, save a file to `docs/tasks/<NNN>-<slug>.md` using the
template below. Zero-padded three-digit numbers (`001`, `002`, …).

---

## Task file template

```markdown
# <NNN>: <Title>

**Type:** HITL / AFK
**Status:** pending
**Blocked by:** <task number(s) or "None — can start immediately">
**Harness stages exercised:** fmt / lint / grep-gates / schema-fresh / doc-honesty / doc-coverage / test

## What to build

A concise description of this vertical slice. Describe end-to-end behaviour,
not layer-by-layer implementation steps.

## Acceptance criteria

- [ ] `make verify` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] <specific behaviour criterion 1>
- [ ] <specific behaviour criterion 2>
- [ ] RLS policy tested: authorized case passes, unauthorized case is rejected
      (include only if this task adds or modifies an RLS policy)
- [ ] <!-- doc-update --> Architecture doc updated if any new path or symbol was introduced

## Grep-gate obligations

List any gate this task must not violate:
- No `Date.now()` / `new Date()` in service or repository layers
- No raw SQL strings outside `repository.ts` files
- No `createClient` outside `repository.ts` files
- No hardcoded secrets in any source file
- No `console.log` in non-test production code
- No `new Response(` in handler or service files

## Schema obligations (if any)

If this task adds or modifies a migration:
- Run `make gen` after applying the migration
- The `schema-fresh` stage of `make verify` will catch a stale fence

## No-doc-impact (optional escape hatch)

Leave this section out entirely if you checked the <!-- doc-update --> criterion.
Only add it when the task genuinely introduced no new paths or symbols:

**No-doc-impact:** <reason>

## Notes

Any additional context, open questions, or links to relevant architecture docs.
```
