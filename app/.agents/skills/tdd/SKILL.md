---
name: tdd
description: Test-driven development with red-green-refactor loop for TheLIST. Use when building features or fixing bugs using TDD, or when the user mentions "red-green-refactor", "failing test first", or "test-first". Always runs make verify (or dart run tool/verify.dart on Windows) as the definition of done.
---

# Test-Driven Development — TheLIST

## Prime directive

**`make verify` is the only definition of done** (AGENTS.md §0). Every TDD cycle
ends with a green `dart run tool/verify.dart` — all six stages:
format → analyze → grep-gates → schema-fresh → doc-honesty → test.

Not just `flutter test`. All six.

## Layer 1 checkpoints — mandatory, not optional

Layer 1 (the verify pipeline) runs at three fixed moments inside every task.
These are hard stops, not checklist suggestions:

### Checkpoint A — before writing a single line (pre-task baseline)

```
dart run tool/verify.dart
```

Run this **before touching any code**. If it is red, stop immediately and report
it — do not proceed. You must start from green. If you inherit a red baseline you
cannot know whether your changes caused the failure or whether it was already
broken. Fix the baseline first, with the human's awareness, before starting the
task.

### Checkpoint B — after every RED→GREEN cycle

```
dart run tool/verify.dart
```

Run after every single test passes — not just at the end of the task. One test
green, full verify green, then write the next test. This keeps the tree always
committable and makes failures trivially bisectable.

If verify goes red after your code change:
- Do NOT write the next test
- Do NOT continue implementing
- Fix the failure immediately — it is always easier to fix now than after three
  more changes have accumulated

### Checkpoint C — task complete (final gate)

```
dart run tool/verify.dart
```

The final run before handing back. If this is not green, the task is not done —
regardless of what the code looks like or what the agent believes about it. This
is the contract (AGENTS.md §0).

---

## Philosophy

**Core principle**: Tests verify behaviour through public interfaces, not
implementation details. Code can change entirely; tests shouldn't.

**Good tests** exercise real code paths through public APIs. They describe *what*
the system does, not *how*. A good test reads like a specification —
`"two offline devices converge to identical state after sync"` tells you exactly
what capability exists. These tests survive refactors because they don't care
about internal structure.

**Bad tests** are coupled to implementation. They mock internal collaborators,
test private methods, or verify through external means (querying Drift directly
instead of going through the repository interface). The warning sign: your test
breaks when you refactor, but behaviour hasn't changed.

See [tests.md](tests.md) for Dart/Flutter examples and [mocking.md](mocking.md)
for the project-specific mocking boundaries.

## This project's test seams — mock ONLY these three

| Seam | Production adapter | Test adapter |
|---|---|---|
| Time | — | `FakeClock` injected into `lib/sync/`, `lib/repositories/`, `lib/notifications/` — enforced by the `no-datetime-now` grep gate |
| Sync transport | Supabase (`lib/sync/` only) | `FakeMemoryTransport` — in-memory blob list |
| Database | Drift + SQLite | `InMemoryDrift` — same schema, no file I/O |

Never mock anything inside `lib/features/`, `lib/state/`, or `lib/repositories/`
against each other — those are your own modules. See [mocking.md](mocking.md).

## Anti-pattern: horizontal slices

**DO NOT write all tests first, then all implementation.** This produces tests
that test *imagined* behaviour and become insensitive to real regressions.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical tracer bullets):
  RED→GREEN→VERIFY: test1→impl1→verify
  RED→GREEN→VERIFY: test2→impl2→verify
  RED→GREEN→VERIFY: test3→impl3→verify
```

## Workflow

### Step 0 — Checkpoint A (pre-task baseline)

**Run `dart run tool/verify.dart` before writing anything.**

Green → proceed. Red → stop and report. Do not start from a broken tree.

### Step 1 — Plan

Read the active task in `docs/tasks/` and the relevant architecture doc
(routed by `docs/architecture/index.md`). Use the project domain vocabulary
(Sheet, Row, Cell, Column, Reminder, AttentionItem, SyncTransport, Clock) in
every test name and assertion.

Before writing any code:

- [ ] Identify which layer(s) the feature touches (UI / State / Repository / Data / Sync / Crypto)
- [ ] Confirm the public interface that tests will exercise
- [ ] Confirm which behaviours are most important to test
- [ ] Identify opportunities for [deep modules](deep-modules.md)
- [ ] Design interfaces for [testability](interface-design.md)
- [ ] List behaviours to test (not implementation steps)
- [ ] Get user approval on the plan

**You can't test everything.** Focus on critical paths — the sync convergence
matrix, recurrence engine, EAV cell merge, and deferred-tombstone semantics.

### Step 2 — Tracer bullet

Write ONE failing test. Run `dart run tool/verify.dart` — it must fail at the
`test` stage and pass all earlier stages. If an earlier stage fails, fix it
before proceeding.

Write minimal code to make it pass. Run `dart run tool/verify.dart` — **all six
stages must be green** (Checkpoint B). Only then write the next test.

### Step 3 — Incremental loop

For each remaining behaviour:

```
Write test → dart run tool/verify.dart (red at test, green elsewhere)
Write code → dart run tool/verify.dart (all six green) ← Checkpoint B
```

One test at a time. Only enough code to pass the current test. No speculative
features. Never move to the next test while verify is red.

### Step 4 — Bugs are specs first

Write a **regression test that reproduces the bug** (makes verify red at the
test stage) *before* writing any fix. Then fix. Then `dart run tool/verify.dart`
green. Same spine as features.

### Step 5 — Refactor

After all tests pass, look for [refactor candidates](refactoring.md). After each
refactor step: `dart run tool/verify.dart` (Checkpoint B). Never refactor while
red.

### Step 6 — Checkpoint C (task complete)

**Run `dart run tool/verify.dart` one final time.** All six stages green.

Then and only then: mark the task complete, update the task file status in
`docs/tasks/`, and update the relevant architecture doc if any new `lib/...`
path or symbol was introduced (AGENTS.md §5).

---

## Full checklist per task

```
[ ] Checkpoint A: verify green before starting (pre-task baseline)
[ ] Plan approved by user
[ ] Tracer bullet: one failing test written first
[ ] Each RED→GREEN cycle followed by a full verify run (Checkpoint B)
[ ] No verify stage skipped — all six must pass, not just flutter test
[ ] No grep-gate violations introduced
[ ] Architecture doc updated if a new lib/... path or symbol was introduced
[ ] Checkpoint C: final verify green before marking task done
```

## The convergence matrix (mandatory for sync work)

For any new sync rule or merge logic, the required test is the two-client
convergence matrix (`docs/architecture/sync.md §7`): two `InMemoryDrift`
databases sharing one `FakeMemoryTransport`, divergent edit sequences applied,
flush + pull, assert **identical final state regardless of order**. This is
architecture, not optional coverage.
