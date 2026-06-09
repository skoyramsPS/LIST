---
name: tdd
description: >-
  Test-driven development with red-green-refactor loop for the TheLIST backend.
  Use when building Edge Functions, migrations, or fixing bugs using TDD, or when
  the user mentions "red-green-refactor", "failing test first", or "test-first".
  Always runs make verify (or deno run --allow-all tool/verify.ts) as the
  definition of done.
---

# Test-Driven Development — TheLIST Backend

## Prime directive

**`make verify` is the only definition of done** (AGENTS.md §0). Every TDD
cycle ends with a green `deno run --allow-all tool/verify.ts` — all seven
stages: fmt → lint → grep-gates → schema-fresh → doc-honesty → doc-coverage → test.

Not just `deno test`. All seven.

## Layer 1 checkpoints — mandatory, not optional

### Checkpoint A — before writing a single line (pre-task baseline)

```
make verify
```

Run **before touching any code**. If red, stop and report. You must start from
green. Fix the baseline first.

### Checkpoint B — after every RED→GREEN cycle

```
make verify
```

Run after every single test passes. One test green, full verify green, then write
the next test. Never move forward while verify is red.

### Checkpoint C — task complete (final gate)

```
make verify
```

All seven stages green before handing back.

---

## This project's test seams — mock ONLY these two

| Seam | Production adapter | Test adapter |
|---|---|---|
| Time | — | `FakeClock` injected into service/repository layers |
| Supabase client | `@supabase/supabase-js` | `FakeSupabaseClient` in-memory adapter |

Never mock internal collaborators (services calling each other). Only mock at
these two seams. Integration tests use a real local Supabase (`supabase start`).

## Anti-pattern: horizontal slices

```
WRONG (horizontal):
  RED:   test1, test2, test3
  GREEN: service1, repository1, migration1

RIGHT (vertical tracer bullets):
  RED→GREEN→VERIFY: test1→service1→verify
  RED→GREEN→VERIFY: test2→repository1→verify
  RED→GREEN→VERIFY: test3→migration1+rls→verify
```

## Workflow

### Step 0 — Checkpoint A (pre-task baseline)

**Run `make verify` before writing anything.** Green → proceed. Red → stop.

### Step 1 — Plan

Read the active task in `docs/tasks/` and the relevant architecture doc.
Before writing any code:

- [ ] Identify which layer(s) the feature touches (index/handler/service/repository/migration)
- [ ] Confirm the public interface that tests will exercise
- [ ] Identify which seam(s) to inject (Clock? FakeSupabaseClient?)
- [ ] List behaviours to test (not implementation steps)
- [ ] Confirm whether a migration is needed and if `make gen` must be run
- [ ] Get user approval on the plan

### Step 2 — Tracer bullet

Write ONE failing unit test for the service layer. Run `make verify` — it
must fail at the `test` stage and pass all earlier stages. Write minimal code
to make it pass. Run `make verify` — all seven must be green (Checkpoint B).

### Step 3 — Incremental loop

For each remaining behaviour:

```
Write test → make verify (red at test, green elsewhere)
Write code → make verify (all seven green) ← Checkpoint B
```

One test at a time. No speculative features.

### Step 4 — Integration tests for RLS

After unit tests are green, write integration tests against the local Supabase
instance for any new RLS policies. These run with `supabase start` active.
Each policy needs at least:
- A test that an authorized user CAN perform the operation
- A test that an unauthorized user CANNOT

### Step 5 — Bugs are specs first

Write a regression test that reproduces the bug before writing any fix.

### Step 6 — Refactor

After all tests pass, look for refactor candidates. After each step:
`make verify` (Checkpoint B). Never refactor while red.

### Step 7 — Checkpoint C (task complete)

**Run `make verify` one final time.** All seven stages green.

Then: mark the task complete, update `docs/tasks/` status, update the relevant
architecture doc if any new `supabase/functions/...` path or symbol was introduced.

---

## Full checklist per task

```
[ ] Checkpoint A: verify green before starting
[ ] Plan approved by user
[ ] Tracer bullet: one failing test written first
[ ] Each RED→GREEN cycle followed by a full verify run (Checkpoint B)
[ ] RLS integration tests written for any new policy
[ ] No grep-gate violations introduced
[ ] make gen run if a migration was added
[ ] Architecture doc updated if a new path or symbol was introduced
[ ] Checkpoint C: final verify green before marking task done
```
