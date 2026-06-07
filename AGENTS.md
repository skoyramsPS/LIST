# AGENTS.md — Project Guardrails (read this first, every time)

This is **TheLIST**: an offline-first, local-first Flutter list app with a true
end-to-end-encrypted multi-device sync engine. This file is the non-negotiable
contract for **every coding agent** (Codex, Grok Build, and Claude Code — which
is redirected here by its `CLAUDE.md` stub). It is the single source of truth; do
not maintain a forked copy. If anything you are about to do conflicts with a rule
here, stop.

---

## 0. The prime directive: `make verify` is truth

You may **never** report a task, feature, or bug fix as complete unless
`make verify` exits green. A passing build is the only definition of "done".
The green checkmark is the contract between you and the human.

`make verify` runs, in strict order, failing non-zero on the first failure:

1. `dart format --set-exit-if-changed .`
2. `dart analyze --fatal-infos --fatal-warnings`
3. **grep gates** (absence-invariants — see §3)
4. **schema fence** (`data_model.md` DDL block must match the live Drift schema)
5. **doc-honesty checks** (`lib/...` paths in `/docs/architecture/*` and `lib/...` + `.claude/skills/...` paths in `docs/HARNESS.md` must resolve — see §5)
6. `flutter test` (unit + widget + the two-client convergence matrix)

---

## 1. This is a greenfield project

There is **no pre-existing backend, app, design system, or shared widget
library** to inherit, reference, or import. Everything is built here, from
scratch. If you find yourself about to import, reference, or assume any external
proprietary infrastructure, you are hallucinating. Stop and re-read the
architecture docs.

---

## 2. Strict layering (UI → State → Repository → DB)

Data flows in exactly one direction. Each layer may only talk to the one below.

```
lib/features/**      UI. Riverpod consumers + List* components only.
lib/state/**         Riverpod providers/notifiers. Orchestration only.
lib/repositories/**  The ONLY layer permitted to touch Drift.
lib/data/**          Drift database, DAOs, tables, Views.
lib/sync/**          The sync engine. The ONLY layer permitted to touch Supabase.
lib/crypto/**        Key management + payload encryption.
```

- **No `drift` import is allowed under `lib/features/` or `lib/state/`.**
- **No `supabase` import is allowed outside `lib/sync/`.**
- UI talks to providers; providers talk to repositories; only repositories touch
  the database. No shortcuts, ever.

These rules are enforced by banned-imports config in `analysis_options.yaml`.

---

## 3. Absence-invariants (enforced by grep gates in `make verify`)

These are *absence* properties — "this never appears where it must not". Static
checks scan the whole tree, so they cannot be defeated by an untested code path.

- **No `DateTime.now()` inside `lib/sync/`, `lib/repositories/`, or any
  recurrence/merge code.** Time is always an injected `Clock`. (Testability of
  the sync engine depends entirely on this.)
- **No raw color hex** (e.g. `#FFD1DC`, `0xFFD1DC`, `Color(0x...)`) and **no raw
  numeric padding/radius literals** in `lib/features/`. Everything routes through
  `AppTokens`.
- **No banned Material visual widgets in `lib/features/`** (see
  `design_system.md` for the denylist). Use the `List*` components.
- **No reference under `lib/` or `test/` that resolves into `/_human/`.** That
  directory is dead/rejected context and is invisible to you by design.

---

## 4. Test-first, always (features AND bugs)

- **Features:** read the active PRD → break into atomic failing tests → write the
  test (red) → write code → `make verify` (green). No application code is written
  before a failing test exists for it.
- **Bugs:** a bug report is a failing specification. Write a **regression test
  that reproduces the bug** (turns the suite red) *before* writing any fix. Then
  fix, then `make verify`. Same spine, different spec source.

The sync engine is built against injected abstractions (`Clock`,
`SyncTransport`) so convergence is provable with two in-memory clients and no
network. This is mandatory, not optional — see `sync.md`.

---

## 5. Doc honesty is enforced, not requested

When you finish a task that changes the system's shape (a new table, View,
column, component, or sync rule), you **must** update the relevant
`/docs/architecture/*.md` file before marking the task done.

This is checked: `make verify` extracts every `lib/...` path and symbol
referenced in `/docs/architecture/*.md` and fails the build if any no longer
resolves. Schema *facts* in `data_model.md` are generated from the Drift schema
into the fenced `<!-- DRIFT-SCHEMA -->` region — never hand-edit inside the
fence; hand-write only rationale outside it.

---

## 5b. Documentation & communication conventions

- **All documents are Markdown (`.md`).** Never produce `.docx`, `.pdf`, or other
  binary document formats for this project. Specs, plans, architecture, and notes
  are all `.md` so they diff, review, and route cleanly.
- **Questions are discussions, not forms.** When something needs clarifying, ask
  in plain conversation. Do not use multiple-choice/question UI tooling — design
  and scope decisions are resolved by discussion and recorded in the docs.

---

## 6. Where to read next (routing)

Read `/docs/architecture/index.md`. It maps your task to the *one* doc you need,
so you don't load the whole system into context to change a button. (This file,
`AGENTS.md`, is that root contract; `CLAUDE.md` is only a pointer stub to it.)

- Product rules / what to build → `/docs/planning/active/PRD.md`
- Database, EAV, schema, Views → `/docs/architecture/data_model.md`
- Sync, encryption, keys, scheduler → `/docs/architecture/sync.md`
- UI, components, tokens, theme → `/docs/architecture/design_system.md`
- Dev environment / first-run / cross-machine → `/docs/SETUP.md`

When the setup, toolchain, or harness changes, update `/docs/SETUP.md` in the
same commit (same maintenance rule as §5).

When a skill is added, renamed, or removed, update `/docs/HARNESS.md §6` and
`AGENTS.md §8` in the same commit. The doc-honesty gate verifies every
`.claude/skills/...` path listed in `docs/HARNESS.md` — a stale entry fails
`make verify`.

`/_human/` is off-limits. You cannot see it; do not reference it.

---

## 7. Mentor mode (Socratic coaching — both agents)

When the human signals they want to **learn and drive the implementation
themselves** ("teach me", "help me understand", "I want to build this myself",
"walk me through why"), switch into **Mentor Mode**. This section is the contract
for both Claude and Codex; Claude additionally loads the full skill from
`.claude/skills/mentor/SKILL.md`.

**The deliverable boundary (hard rule).** Nothing you produce in Mentor Mode is
the final deliverable. You may write small illustrative snippets in chat to
explain a mechanism. You must never write code to `lib/`, `test/`, or `tool/`,
and never hand over a complete copy-paste feature. The human types the real thing.

**Teach then interrogate.** Calibrate to the novelty of the concept:
- Applying a known pattern → question first; let them reason to the answer.
- Deep/novel systems (LWW CRDT convergence, E2EE key model, dumb-server merge,
  fractional-index ordering, the nearest-N scheduler) → explain the core
  mechanism clearly first, then shift to Socratic questions on how to apply it.

**Anchor every lesson to repo artifacts** — the gates in `tool/grep_gates.dart`,
the architecture docs, and (for Claude) the decision log in `/_human/`.

**End every Mentor Mode response with exactly one** specific question or concrete
action. Never end flat.

**Escape hatch.** If the human types `/just-tell-me`, give the direct answer once
(in chat, not to the repo), then automatically resume coaching on the next turn.

**Standards stay strict.** Mentor Mode changes pedagogy, never correctness. Never
coach toward something that would fail a gate or contradict a locked decision.

---

## 8. Skill library (both agents)

Claude loads skills from `.claude/skills/<name>/SKILL.md` automatically.
Codex reads this section as the equivalent contract. All skills share the same
rules: `make verify` must be green when the skill's work is done, and every
skill respects the layering (§2), grep gates (§3), and doc-honesty (§5) rules.

### `grill-with-docs` — Requirements interview before a PRD

Use at the start of any new feature, major change, or significant update —
**before** `to-prd`. Do not skip for anything non-trivial.

Runs a structured challenge interview: one question at a time, agent gives its
recommended answer, probes the idea against architecture docs, locked decisions
in `_human/decision_log.md`, domain vocabulary, layering rules, and sync/E2EE
implications. No files are written during the session.

Output: a session summary covering scope boundary, sync/E2EE implications,
layering implications, testing implications, and open questions. This feeds
directly into `to-prd`.

Full details: `.claude/skills/grill-with-docs/SKILL.md`.

### `tdd` — Test-driven development

Use when building any feature or fixing any bug. The workflow is:

1. Read the active task in `docs/tasks/` and the relevant architecture doc.
2. Plan: identify layers, public interface, behaviours to test.
3. Tracer bullet: one failing test → minimal code → `dart run tool/verify.dart` green.
4. Incremental loop: one test at a time until the feature is complete.
5. Refactor: only after all tests are green; run verify after every step.

**The three mock seams — nothing else gets mocked:**
- Time → `FakeClock` (injected; `DateTime.now()` banned in engine by grep gate)
- Sync transport → `FakeMemoryTransport`
- Database → `InMemoryDrift`

For sync work, the convergence matrix is mandatory: two `InMemoryDrift`
databases sharing one `FakeMemoryTransport`, divergent edits, flush + pull,
assert identical final state regardless of order (`docs/architecture/sync.md §7`).

Full details: `.claude/skills/tdd/SKILL.md` and its supporting files
(`tests.md`, `mocking.md`, `interface-design.md`, `deep-modules.md`, `refactoring.md`).

### `to-prd` — Create a PRD from conversation context

Use when the user wants to capture a feature as a formal product requirement doc.
Do NOT interview the user — synthesise from existing context.

Process: explore the codebase → sketch modules → write PRD using the project
template → save to `docs/planning/active/<feature-slug>.md`.

The PRD template requires: Problem Statement, Solution, User Stories, Implementation
Decisions (layers, interfaces, schema changes, sync contract), Testing Decisions,
Harness Prerequisites (PRD §22a/b/c if triggered), Out of Scope, Further Notes.

Full details: `.claude/skills/to-prd/SKILL.md`.

### `to-tasks` — Break a PRD into implementation tasks

Use when converting a PRD or plan into independently-implementable task files.

Process: read AGENTS.md + architecture index → check PRD §22 prerequisites →
draft vertical tracer-bullet slices → quiz the user → save approved tasks to
`docs/tasks/<NNN>-<slug>.md`.

Each task must: be completable with a green `dart run tool/verify.dart`, include
at least one failing test written before implementation, and update the relevant
architecture doc if any new `lib/...` path or symbol was introduced.

Tasks are HITL (human decision needed) or AFK (agent implements autonomously).

Full details: `.claude/skills/to-tasks/SKILL.md`.

### `improve-codebase-architecture` — Find deepening opportunities

Use when the user wants to improve architecture, find refactoring opportunities,
or make the codebase more testable and AI-navigable.

Process: explore the codebase organically for friction → apply the deletion test
→ present numbered deepening candidates → user picks one → explore alternative
interfaces → land refactor behind a green `dart run tool/verify.dart`.

Never propose anything that violates the layering (§2), the grep gates (§3), or
a locked decision in `_human/decision_log.md`. Mark ADR conflicts explicitly.

Vocabulary: module, interface, implementation, depth, seam, adapter, leverage,
locality. Full definitions in `.claude/skills/improve-codebase-architecture/LANGUAGE.md`.

Full details: `.claude/skills/improve-codebase-architecture/SKILL.md` and
`LANGUAGE.md`, `INTERFACE-DESIGN.md`.

### `architect-review` — Senior architect gap review (three modes)

A Senior Software Architect and Designer with ADHD reviews the work at three
gates. Invoke with a mode argument:

- `architect-review review-prd` — after a PRD is written
- `architect-review review-tasks` — after a PRD is broken into tasks
- `architect-review review-implementation` — after a feature is implemented

**Persona:** hyperfocuses on real structural problems, not surface noise. Fast,
opinionated, not a rubber stamp. Values simple design, deep modules, SOLID where
it reduces actual complexity. Stops when the work is genuinely good.

**Hard constraints the agent always respects:**
- Locked decisions in `_human/decision_log.md` are closed — not re-litigated
- "Industry trends" are filtered through the project thesis (local-first, E2EE,
  offline-first sync engine) — trends that conflict with the thesis are wrong
  here regardless of general popularity
- Non-goals in PRD §4 are not gaps
- `make verify` is the mechanical truth; soft concerns are lower priority

**Output:** a structured findings report (CRITICAL / MAJOR / MINOR) plus
strengths and a verdict. The agent proposes fixes but does **not** modify any
file until the human approves a specific finding.

Full details: `.claude/skills/architect-review/SKILL.md`.
