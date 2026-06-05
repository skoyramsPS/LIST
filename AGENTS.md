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
4. **doc-honesty checks** (paths in `/docs/architecture/*` must resolve — see §5)
5. `flutter test` (unit + widget + the two-client convergence matrix)

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

`/_human/` is off-limits. You cannot see it; do not reference it.
