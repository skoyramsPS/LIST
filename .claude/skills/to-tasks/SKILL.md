---
name: to-tasks
description: >-
  Break a monorepo-level PRD into independently-implementable tasks, saved into
  the correct workspace task folders. App tasks go to app/docs/tasks/, backend
  tasks go to backend/docs/tasks/. Cross-cutting PRDs produce tasks in both.
  Use when converting a PRD into implementation tasks or splitting work into
  vertical slices. Each task must be completable behind a green make verify in
  its workspace.
---

# To Tasks — TheLIST (Monorepo)

Break a PRD into independently-implementable tasks using vertical tracer-bullet
slices. Each task must be completable with a green `make verify` in its workspace.

## Process

### 1. Gather context

Work from whatever is in the conversation. If the user passes a PRD filename,
read it from `docs/planning/active/` (monorepo root). Always read:

- `AGENTS.md` (root) — universal constraints
- The workspace-specific `AGENTS.md`(s) the PRD touches — layering rules,
  grep gates, and verify pipelines differ between app and backend
- `docs/architecture/index.md` for each workspace in scope

### 2. Determine workspace routing

Read the PRD's **Workspace scope** field:

- **App-only** → all tasks go to `app/docs/tasks/`
- **Backend-only** → all tasks go to `backend/docs/tasks/`
- **Cross-cutting** → app tasks go to `app/docs/tasks/`, backend tasks go to
  `backend/docs/tasks/`; produce both lists and make cross-workspace dependencies
  explicit (e.g. backend schema must land before app sync can be tested)

### 3. Check app harness prerequisites (if app is in scope)

Before drafting app tasks, check PRD §22 prerequisites from
`docs/planning/active/the-list/PRD.md`:

- **§22a** Font assets — triggered by first List* widget. Font task must block
  the first UI task.
- **§22b** Wire gen_schema.dart — triggered by first Drift table. Must be in the
  same task as the first Drift schema file.
- **§22c** Activate riverpod_lint — triggered by first Riverpod provider. Must be
  in the same task as the first provider file.

### 4. Check backend prerequisites (if backend is in scope)

- Every new SQL table requires a migration file and an RLS policy. These must be
  in the same task — never split schema from policy.
- Every new Edge Function requires at least one integration test in the same task.
- If this is the first migration in the project, wire the migration runner in the
  same task.

### 5. Draft vertical slices

Each task is a thin vertical slice cutting through ALL required integration layers
end-to-end — not a horizontal slice of one layer.

Tasks are **HITL** (Human In The Loop — requires a decision before the agent can
proceed) or **AFK** (agent implements and verifies fully autonomously). Prefer AFK.

**Vertical slice rules:**
- Each task delivers a narrow but complete path through every layer it touches
- A completed task must leave `make verify` green in its workspace
- App tasks: at least one failing test before implementation (AGENTS.md §4)
- App tasks: update relevant `docs/architecture/*.md` if any new `lib/...` path
  or symbol is introduced
- Backend tasks: update relevant `backend/docs/architecture/*.md` if any new
  function or schema path is introduced

**Bad tasks (horizontal slices — reject these):**
- "Write all the Drift tables" (schema only)
- "Write all RLS policies" (policy layer only)
- "Write all the widget tests" (tests without implementation)
- "Write all Edge Function stubs" (stubs without behaviour)

### 6. Quiz the user

Present the proposed breakdown as a numbered list grouped by workspace. For each
task show:

- **Title:** short imperative name
- **Workspace:** app / backend
- **Type:** HITL / AFK
- **Blocked by:** which other tasks must complete first (use task numbers)
- **Harness obligation:** which verify stages this task primarily exercises
- **PRD sections covered:** which user stories or decisions this addresses

Ask:
- Does the granularity feel right?
- Are the cross-workspace dependency relationships correct?
- Should any tasks be merged or split?
- Are the correct tasks marked HITL vs AFK?

Iterate until the user approves.

### 7. Write the task files

For each approved task, save to the correct workspace:

- App tasks → `app/docs/tasks/<NNN>-<slug>.md`
- Backend tasks → `backend/docs/tasks/<NNN>-<slug>.md`

Use zero-padded three-digit numbers (`001`, `002`, …). Numbering is per-workspace
— both workspaces can have a `001`. Publish in dependency order (blockers first).

---

## App task file template

```markdown
# <NNN>: <Title>

**Workspace:** app
**Type:** HITL / AFK
**Status:** pending
**Blocked by:** <task number(s) or "None — can start immediately">
**Harness stages exercised:** format / analyze / grep-gates / schema-fresh / doc-honesty / doc-coverage / test

## What to build

A concise description of this vertical slice. End-to-end behaviour, not
layer-by-layer steps.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] <specific behaviour criterion 1>
- [ ] <specific behaviour criterion 2>
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or
  symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No `DateTime.now()` in `lib/sync/`, `lib/repositories/`, `lib/notifications/`
- No raw colour hex or spacing literals in `lib/features/`
- No banned Material visual widgets in `lib/features/`
- No Drift import outside `lib/repositories/`
- No Supabase import outside `lib/sync/`

## Harness prerequisites triggered (if any)

Reference PRD §22a / §22b / §22c if triggered. Describe what must be done in
the same commit.

## No-doc-impact (optional)

Only add if the task genuinely introduced no new `lib/...` paths or symbols:
**No-doc-impact:** <reason>

## Notes

Additional context, open questions, or links to relevant architecture docs.
```

---

## Backend task file template

```markdown
# <NNN>: <Title>

**Workspace:** backend
**Type:** HITL / AFK
**Status:** pending
**Blocked by:** <task number(s), or cross-workspace dependency e.g. "app/003", or "None">
**Harness stages exercised:** lint / typecheck / test / migration-check

## What to build

A concise description of this vertical slice. End-to-end behaviour, not
layer-by-layer steps.

## Acceptance criteria

- [ ] `make verify` is green in backend/ after this task
- [ ] <specific behaviour criterion 1>
- [ ] <specific behaviour criterion 2>
- [ ] <!-- doc-update --> Architecture doc updated if any new function or schema
  path was introduced

## Schema and RLS obligations (if applicable)

- New table requires: migration file + RLS policy in the same task
- RLS policy must be tested (deny unauthorised access, allow authorised access)
- Sync-contract columns required on synced tables: updated_at, deleted_at,
  sync_version, device_id, encrypted_payload

## No-doc-impact (optional)

Only add if no new functions or schema paths were introduced:
**No-doc-impact:** <reason>

## Notes

Additional context, open questions, or links to relevant architecture docs.
```
