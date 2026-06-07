# TheLIST — Harness & Skill Library

**This document is live.** Every `lib/...` path and `.claude/skills/...` path
referenced here is verified by `make verify` (via `tool/doc_honesty.dart`). If
you add, move, or rename anything this document points at, update this file in
the same commit. A stale harness guide is worse than none — it misdirects agents
on every session.

> **Who this is for.** Both coding agents (Claude and Codex) and the human
> working with them. Read this to understand what tools exist, when to invoke
> each one, and how they fit together. For machine setup, see `docs/SETUP.md`.
> For layering rules and build contract, see `AGENTS.md`.

---

## 1. The verify pipeline — the only definition of done

`dart run tool/verify.dart` (or `make verify`) runs seven stages in strict
fail-fast order. A task is **not done** until all seven are green.

| Stage | Command | What it catches |
|---|---|---|
| **format** | `dart format --set-exit-if-changed .` | Unformatted code |
| **analyze** | `dart analyze --fatal-infos --fatal-warnings` | Type errors, unused imports, strict-mode violations |
| **grep-gates** | `dart run tool/grep_gates.dart` | Absence-invariant violations (see §2) |
| **skill-links** | `dart run tool/check_skill_links.dart` | `.agents/skills/` out of sync with `.claude/skills/` (see §4b) |
| **schema-fresh** | `dart run tool/gen_schema.dart --check` | `data_model.md` schema fence out of sync with Drift |
| **doc-honesty** | `dart run tool/doc_honesty.dart` | Dangling `lib/...` or `.claude/skills/...` paths in docs |
| **test** | `flutter test` | Failing unit, widget, and convergence tests |

**Windows note:** `make` is optional. `dart run tool/verify.dart` is identical
and always works. Individual stages can be run separately — see `Makefile` for
the single-command equivalents.

**Never report a task complete without a green run.** The green checkmark is the
contract between you and the human (AGENTS.md §0).

---

## 2. Grep gates — absence invariants

`tool/grep_gates.dart` scans the entire source tree for patterns that must
*never* appear in certain directories. These are structural guarantees, not style
preferences — they enforce the architecture mechanically.

Each gate accepts a `// gate-ok: <reason>` inline marker to exempt a specific
line. Use this sparingly and only with a genuine, reviewed justification.

| Gate name | Pattern forbidden | Where | Why |
|---|---|---|---|
| `no-datetime-now` | `DateTime.now()` | `lib/sync/`, `lib/repositories/`, `lib/notifications/` | Time must be an injected `Clock` for deterministic testing of the sync engine |
| `no-raw-hex` | Raw colour literals (`Color(0x...)`, `0xFF...`, `#...`) | `lib/features/` | All colours route through `lib/ui/tokens/app_tokens.dart` |
| `no-raw-spacing` | Raw numeric `EdgeInsets` / `BorderRadius` literals | `lib/features/` | All spacing and radii route through `AppTokens.spacing.*` / `AppTokens.radius.*` |
| `no-material-visual` | Banned Material widgets (`Card`, `ElevatedButton`, `InkWell`, `ListTile`, `Checkbox`, `Switch`, `FloatingActionButton`, `AppBar`, `Divider`) | `lib/features/` | Use the `List*` components from `lib/ui/components/` instead |
| `no-human-ref` | Any `_human` path reference | `lib/`, `test/` | `/_human/` is quarantined dead context — never visible to agents |
| `layer-no-drift-in-ui` | `import 'package:drift` | `lib/features/`, `lib/state/` | Only `lib/repositories/` may touch Drift |
| `layer-no-supabase-outside-sync` | `import 'package:supabase` | Every `lib/` directory except `lib/sync/` | Only `lib/sync/` may touch Supabase |

**The gate tests themselves are tested.** `test/harness/grep_gates_test.dart`
plants deliberate violations in a sandbox and asserts each gate fires correctly.
A gate that silently never matches would give false confidence — the worst
failure mode for a guardrail.

---

## 3. Schema fence — generated facts

`tool/gen_schema.dart` maintains the `<!-- DRIFT-SCHEMA:START / END -->` fence in
`docs/architecture/data_model.md`. The DDL inside the fence is always generated
from the live Drift schema — never hand-edited.

```
# To regenerate after changing a Drift table:
dart run tool/gen_schema.dart

# To check whether the fence is current (run by make verify):
dart run tool/gen_schema.dart --check
```

**Critical:** when the first Drift table lands under `lib/data/`, the
`_dumpSchema()` function in `tool/gen_schema.dart` must be wired to the real
`AppDatabase` in the same commit. See `PRD.md §22b`.

---

## 4b. Skill-sync — copy mirror

`.agents/skills/` must be an exact content copy of `.claude/skills/`. Both
Claude and Codex read from their respective paths; keeping them in sync ensures
both agents see the same skills.

**Why copies, not a symlink:** `core.symlinks = false` on Windows means Git
stores symlinks as plain text files, which breaks VS Code Git operations. Copies
are the only approach that works reliably across platforms.

**When this gate fires:** a SKILL.md was added or edited under `.claude/skills/`
but `.agents/skills/` wasn't updated, or vice versa.

**How to fix:**
```
dart run tool/check_skill_links.dart --fix
# or
make links
```

`--fix` deletes `.agents/skills/` and rebuilds it from `.claude/skills/`. Always
use `/add-skill` to add skills — it handles the sync step.

---

## 4c. Doc honesty — live path verification

`tool/doc_honesty.dart` extracts every `lib/...` filesystem path mentioned in
`docs/architecture/*.md` and every `lib/...` and `.claude/skills/...` path
mentioned in `docs/HARNESS.md`, then fails the build if any does not exist on
disk.

This means:
- If you add a new `lib/` module and mention it in an architecture doc, the path
  must exist before `make verify` can pass.
- If you rename or move a module, update every architecture doc and this file
  in the same commit.
- If you add a new skill to `.claude/skills/`, add it to §6 of this document.

The gate checks paths, not prose. English descriptions are not verified —
only tokens matching `lib/[A-Za-z0-9_/]+` or `.claude/skills/[A-Za-z0-9_/-]+`.

---

## 5. The three test seams

The entire test strategy hinges on three injectable boundaries. Mock *only* these.
Never mock your own modules, internal collaborators, or Riverpod providers directly.

### Time → `FakeClock`
`DateTime.now()` is banned in `lib/sync/`, `lib/repositories/`, and
`lib/notifications/` by the `no-datetime-now` grep gate. Every module in those
layers accepts an injected `Clock`. In tests, pass a `FakeClock` you control.

### Sync transport → `FakeMemoryTransport`
`lib/sync/` is the only layer that imports Supabase (enforced by
`layer-no-supabase-outside-sync`). Tests use `FakeMemoryTransport` — an
in-memory list of encrypted blobs shared between two `SyncClient` instances,
simulating the server with no network.

### Database → `InMemoryDrift`
Tests that need a real schema use `InMemoryDrift` — the full Drift schema
running against an in-memory SQLite instance with no file I/O.

**The convergence matrix** (mandatory for any new sync or merge logic): two
`InMemoryDrift` databases sharing one `FakeMemoryTransport`, divergent edit
sequences applied in varying order, flush + pull, assert identical final state.
See `docs/architecture/sync.md` §7.

---

## 6. Skill library

Skills live in `.claude/skills/`. Claude loads them automatically by name. Codex
reads the summaries in `AGENTS.md §8`. Both agents have the same behavioural
contract — the skill files are the full specification; `AGENTS.md §8` is the
dense summary Codex reads.

**Maintenance rule:** when a skill is added, renamed, or removed, update this
section and `AGENTS.md §8` in the same commit. The doc-honesty gate verifies
that every `.claude/skills/...` path listed here resolves on disk.

### `.claude/skills/grill-with-docs/`

**When to invoke:** at the very start of any new feature, major change, or
significant update — before `to-prd`. Do not skip for anything non-trivial.

**What it does:** a structured requirements interview that challenges the idea
against the existing architecture docs, locked decisions in
`_human/decision_log.md`, domain vocabulary, layering rules, and sync/E2EE
implications. One question at a time; the agent gives its recommended answer
for each. No files are written during the session.

**Output:** a session summary (What we're building / Scope boundary / Sync and
E2EE implications / Layering implications / Testing implications / Locked
decisions touched / Open questions). This summary is the direct input to
`to-prd` — the PRD is written from it.

---

### `.claude/skills/tdd/`

**When to invoke:** every time a feature is built or a bug is fixed. TDD is not
optional — AGENTS.md §4 requires a failing test before any implementation code.

**Workflow summary:**
1. Read the active task in `docs/tasks/` and the relevant architecture doc.
2. Plan: identify layers, public interface, which behaviours to test.
3. Tracer bullet: one failing test → minimal code → full verify green.
4. Incremental loop: one test at a time.
5. Refactor only after all tests are green; run verify after each step.

**Supporting files:**
- `.claude/skills/tdd/tests.md` — Dart/Flutter good/bad test examples
- `.claude/skills/tdd/mocking.md` — the three seams, what not to mock
- `.claude/skills/tdd/interface-design.md` — designing for testability in Dart
- `.claude/skills/tdd/deep-modules.md` — small interface / large implementation
- `.claude/skills/tdd/refactoring.md` — post-green refactor candidates

### `.claude/skills/to-prd/`

**When to invoke:** when a feature idea needs capturing as a formal PRD.

**Workflow summary:** synthesise from conversation context (no user interview) →
explore codebase → sketch modules → write PRD to `docs/planning/active/<slug>.md`
using the project template (Problem, Solution, User Stories, Implementation
Decisions, Testing Decisions, Harness Prerequisites, Out of Scope).

The template's **Harness Prerequisites** section explicitly surfaces PRD §22a/b/c
obligations so they are never dropped during task breakdown.

### `.claude/skills/to-tasks/`

**When to invoke:** after a PRD is approved, to break it into implementation tasks.

**Workflow summary:** read AGENTS.md + architecture index → check PRD §22
prerequisites → draft vertical tracer-bullet slices → quiz the user on
granularity and dependencies → save approved tasks to `docs/tasks/<NNN>-<slug>.md`.

Each task file includes: type (HITL/AFK), status, blockers, acceptance criteria
(including a green verify requirement), grep-gate obligations, and any harness
prerequisites triggered.

### `.claude/skills/architect-review/`

**When to invoke:** at three specific gates — never during implementation.

| Mode | Trigger | Goal |
|---|---|---|
| `review-prd` | PRD written | Completeness, architecture alignment, design quality, testability |
| `review-tasks` | Tasks created | Slice quality, dependency graph, coverage, gate awareness |
| `review-implementation` | Feature complete | Verify green, layering integrity, design quality, sync/E2EE correctness, doc honesty |

**Output:** structured findings report (CRITICAL / MAJOR / MINOR) + proposed
fixes. Nothing is modified until the human approves a specific finding.

**Persona:** Senior Architect with ADHD — hyperfocuses on real structural
problems, not surface noise. Respects locked decisions in `_human/decision_log.md`.
Filters "industry trends" through the project thesis (local-first, E2EE, offline
sync). A clean PASS is a valid and good outcome.

### `.claude/skills/improve-codebase-architecture/`

**When to invoke:** when the user wants to find architectural friction, deepening
opportunities, or testability improvements in existing code.

**Workflow summary:** explore the codebase organically for friction → apply the
deletion test → present numbered deepening candidates → user picks one → explore
alternative interfaces → land refactor behind a green verify.

**Supporting files:**
- `.claude/skills/improve-codebase-architecture/LANGUAGE.md` — exact vocabulary (module, interface, depth, seam, adapter, leverage, locality)
- `.claude/skills/improve-codebase-architecture/INTERFACE-DESIGN.md` — Design It Twice process for alternative interface exploration

### `.claude/skills/mentor/`

**When to invoke:** when the human wants to learn and drive the implementation
themselves ("teach me", "walk me through", "I want to build this myself").

**Workflow summary:** Socratic coaching mode — explains, asks questions, validates
against the harness and architecture docs, never writes the deliverable. Ends
every response with exactly one question or concrete action. Escape hatch:
`/just-tell-me` for a direct answer, then coaching resumes.

### `.claude/skills/add-skill/`

**When to invoke:** when a new `/skill-name` command is needed in the harness.

**What it does:** interviews the human to pin the skill's single responsibility,
writes the SKILL.md to the project's quality bar, hardlinks it into
`.agents/skills/`, registers it in this document and `AGENTS.md §8`, and
verifies green.

**Workflow summary:** interview → write SKILL.md → `--fix` hardlinks → update
HARNESS.md §6 → update AGENTS.md §8 → `dart run tool/verify.dart` green.

**Output:** a committed, registered, verified SKILL.md in `.claude/skills/<name>/`.

### `.claude/skills/add-grep-gate/`

**When to invoke:** when a new absence-invariant must be mechanically enforced
across the codebase — typically after `architect-review` flags a structural risk,
after a recurring violation is spotted in code review, or when a new
architectural boundary is introduced.

**What it does:** pins the gate's pattern, scope, and invariant; adds it to
`tool/grep_gates.dart`; writes its self-test in
`test/harness/grep_gates_test.dart`; adds a row to this document's §2 table;
and verifies green.

**Workflow summary:** define gate → scan for existing violations → add to
grep_gates.dart → write self-test → update HARNESS.md §2 →
`dart run tool/verify.dart` green.

**Output:** gate entry in `tool/grep_gates.dart`, self-test in
`test/harness/grep_gates_test.dart`, new row in §2 table.

---

## 7. Typical session flows

Layer 1 (`dart run tool/verify.dart`) is shown explicitly at every gate below.
It is never implicit — if it is not shown, it does not run.

### Starting a new feature

```
0. /grill-with-docs
   → structured interview against architecture docs + locked decisions
   → produces session summary (scope, sync/E2EE implications, open questions)

1. /to-prd  (works from the grill session summary)
   → docs/planning/active/<slug>.md

2. architect-review review-prd
   → findings report
   → for each approved fix: apply fix → dart run tool/verify.dart (must be green)

3. /to-tasks
   → docs/tasks/<NNN>-<slug>.md files

4. architect-review review-tasks
   → findings report
   → for each approved fix: apply fix → dart run tool/verify.dart (must be green)

5. For each task in docs/tasks/:
   a. dart run tool/verify.dart          ← Checkpoint A: baseline must be green
   b. /tdd
      → write failing test
      → write minimal code
      → dart run tool/verify.dart        ← Checkpoint B: after every RED→GREEN
      → repeat until task acceptance criteria met
   c. dart run tool/verify.dart          ← Checkpoint C: final gate before marking done
   d. mark task status = complete in docs/tasks/<NNN>-<slug>.md

6. architect-review review-implementation
   → findings report
   → for each approved fix: apply fix → dart run tool/verify.dart (must be green)
```

### Fixing a bug

```
1. dart run tool/verify.dart             ← Checkpoint A: confirm baseline state

2. /tdd
   → write regression test (makes verify red at test stage)
   → write minimal fix
   → dart run tool/verify.dart           ← Checkpoint B: all six stages green

3. architect-review review-implementation
   → findings report
   → for each approved fix: apply fix → dart run tool/verify.dart (must be green)
```

### Improving existing architecture

```
1. dart run tool/verify.dart             ← Checkpoint A: confirm baseline is green

2. /improve-codebase-architecture
   → findings report; user picks a candidate

3. /tdd
   → write failing test that captures current behaviour
   → apply the refactor
   → dart run tool/verify.dart           ← Checkpoint B: all six stages green
```

### Learning while building

```
1. /mentor              → Socratic coaching throughout any of the above flows
   (use /just-tell-me to drop into direct mode when stuck)
```

### Updating the AI coding harness

```
/add-skill        ← adding a new skill to the library
/add-grep-gate    ← adding a new absence-invariant gate
```

For anything else (renaming/removing a skill, adding a verify stage, editing a
tool script), follow the maintenance rules in §8 — those changes are
infrequent enough that a dedicated skill adds no value over a clear checklist.

---

## 8. Maintenance rules (keeping this document live)

When you do any of the following, update this document **in the same commit**:

| Change | What to update here |
|---|---|
| Add a new `lib/` module mentioned in an architecture doc | Add the path to §4c or §5 if it's a seam adapter |
| Add a skill | Use `/add-skill` — it handles §6 and verify |
| Rename or remove a skill | Update §6 section header and prose; verify doc-honesty passes |
| Add a new grep gate | Use `/add-grep-gate` — it handles §2 and verify |
| Change the verify pipeline stages | Update the §1 table |
| Add a new verify tool (`tool/*.dart`) | Add a row to §1; add a `make <target>` entry to the Makefile |
| Add a new test seam (new injectable boundary) | Add it to §5 |
| Change the Flutter or Dart SDK version | Update §1 (Windows note) and `docs/SETUP.md` |

The doc-honesty gate enforces path references mechanically. English prose is your
responsibility — no tool verifies it. Write it for the next agent reading cold,
not for yourself reading warm.
