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

`make verify` runs, in strict order, failing non-zero on the first failure:

1. `dart format --set-exit-if-changed .`
2. `dart analyze --fatal-infos --fatal-warnings`
3. **grep gates** (absence-invariants — see §3)
4. **schema fence** (`data_model.md` DDL block must match the live Drift schema)
5. **doc-honesty checks** (`lib/...` paths in `/docs/architecture/*` and `lib/...` + `skills/...` paths in `docs/HARNESS.md` must resolve — see §5)
5b-gate. **doc-coverage checks** (every completed task in `docs/tasks/` must have its `<!-- doc-update -->` criterion checked, or carry a `**No-doc-impact:**` field — see HARNESS.md §2b)
6. `flutter test` (unit + widget + the two-client convergence matrix)

---

## 1. This is a greenfield project

There is no pre-existing backend, app, design system, or shared widget library — everything is built here from scratch. If you find yourself importing or assuming external proprietary infrastructure, stop.

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

- **No `DateTime.now()` inside `lib/sync/`, `lib/repositories/`, or any
  recurrence/merge code.** Time is always an injected `Clock`.
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
- **Bugs:** write a regression test that reproduces the bug (turns the suite red)
  *before* writing any fix. Then fix, then `make verify`.

The sync engine is built against injected abstractions (`Clock`,
`SyncTransport`) so convergence is provable with two in-memory clients and no
network. This is mandatory — see `sync.md`.

---

## 5. Doc honesty is enforced, not requested

When you finish a task that changes the system's shape (a new table, View,
column, component, or sync rule), you **must** update the relevant
`/docs/architecture/*.md` file before marking the task done.

`make verify` extracts every `lib/...` path and symbol referenced in
`/docs/architecture/*.md` and fails if any no longer resolves. Schema *facts* in
`data_model.md` are generated from the Drift schema into the fenced
`<!-- DRIFT-SCHEMA -->` region — never hand-edit inside the fence.

`make verify` also runs `tool/doc_coverage.dart` (stage 5b): every task in
`docs/tasks/` with `**Status:** complete` must have its
`<!-- doc-update -->` acceptance criterion checked (`- [x]`), or carry a
`**No-doc-impact:** <reason>` field. A completed task with an unchecked
doc-update criterion and no escape hatch fails the build. Use the escape hatch
only for genuinely doc-neutral changes (test-only, tooling-only, config-only).

---

## 5b. Documentation & communication conventions

- **All documents are Markdown (`.md`).** Never produce `.docx`, `.pdf`, or other
  binary formats. Specs, plans, architecture, and notes are all `.md`.
- **Questions are discussions, not forms.** When something needs clarifying, ask
  in plain conversation. Do not use multiple-choice/question UI tooling.

---

## 6. Where to read next (routing)

Read `/docs/architecture/index.md` — it maps your task to the one doc you need.

- Product rules / what to build → `/docs/planning/active/the-list/PRD.md`
- Database, EAV, schema, Views → `/docs/architecture/data_model.md`
- Sync, encryption, keys, scheduler → `/docs/architecture/sync.md`
- UI, components, tokens, theme → `/docs/architecture/design_system.md`
- Dev environment / first-run / cross-machine → `/docs/SETUP.md`

When setup or toolchain changes, update `/docs/SETUP.md` in the same commit.
When changing the harness (skills, grep gates, verify stages), see
`/docs/HARNESS.md §7`.

`/_human/` is off-limits. You cannot see it; do not reference it.

---

## 7. Mentor mode

When the human signals they want to learn and drive the implementation themselves
("teach me", "help me understand", "I want to build this myself"), switch into
**Mentor Mode**.

**Hard rule:** nothing you produce is the final deliverable. Never write code to
`lib/`, `test/`, or `tool/`. The human types the real thing.

Claude: load the full contract from `skills/mentor/SKILL.md`.
Codex: apply the rule above; end every response with exactly one question or
concrete action; escape hatch is `/just-tell-me`.

---

## 8. Skill library

Skills live in `.claude/skills/<name>/SKILL.md`. `.agents/skills/` is a
content-copy mirror kept in sync by `tool/check_skill_links.dart` (a symlink
cannot be used — `core.symlinks=false` on Windows breaks Git). Use `/add-skill`
to add a new skill; it runs the sync step automatically. The full library is in
`docs/HARNESS.md §6`.
