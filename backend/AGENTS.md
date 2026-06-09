# AGENTS.md — Backend Guardrails (read this first, every time)

This is the **`backend/` workspace** of the TheLIST monorepo: Supabase Edge
Functions, SQL migrations, RLS policies, and database schema that power the
sync layer for the Flutter app.

**If you have not read the monorepo contract at `../AGENTS.md` yet, read it first.**
It defines universal rules and routes you here. This file covers everything
specific to the backend — layering, grep gates, the Deno/TypeScript verify
pipeline, and Supabase-specific conventions. The Flutter app contract lives
separately in `../app/AGENTS.md`.

This file is the non-negotiable contract for every coding agent working in
`backend/`. If anything you are about to do conflicts with a rule here or in
the root contract, stop. The two workspace contracts are intentionally separate —
do not cross-apply app rules to backend work or vice versa.

---

## 0. The prime directive: `make verify` is truth

You may **never** report a task, feature, or bug fix as complete unless
`make verify` exits green. A passing build is the only definition of "done".

`make verify` runs, in strict order, failing non-zero on the first failure:

1. `deno fmt --check .`
2. `deno lint`
3. **grep gates** (absence-invariants — see §3)
4. **schema fence** (`docs/architecture/schema.md` SQL block must match the live
   migration head — see §5)
5. **doc-honesty checks** (`supabase/functions/...` and `supabase/migrations/...`
   paths referenced in `docs/architecture/*.md` must resolve — see §5)
5b-gate. **doc-coverage checks** (every completed task in `docs/tasks/` must
   have its `<!-- doc-update -->` criterion checked, or carry a
   `**No-doc-impact:**` field — see HARNESS.md §2b)
6. `deno test` (unit tests for Edge Functions + integration tests against a
   local Supabase instance)

---

## 1. No proprietary infrastructure assumptions

This backend is built on explicitly chosen open dependencies — Supabase, Deno std,
and what is declared in `deno.json`. No inherited middleware, ORM, or shared
library beyond what is listed there. If you find yourself reaching for something
not already declared, stop and raise it with the human first.

---

## 2. Strict layering (HTTP → Handler → Service → Repository → DB)

Data flows in exactly one direction. Each layer may only talk to the one below.

```
supabase/functions/<name>/index.ts   HTTP entry-point. Routing, auth-header
                                     validation, and request parsing only.
supabase/functions/<name>/handler.ts Business logic orchestration. Calls services.
                                     No SQL here.
supabase/functions/<name>/service.ts Domain logic. Pure functions where possible.
                                     Calls repositories.
supabase/functions/<name>/repository.ts The ONLY layer permitted to run SQL
                                     (via the Supabase client). No business
                                     logic here — queries only.
supabase/migrations/                 SQL schema definitions. Never modified by
                                     application code at runtime.
```

- **No SQL strings are allowed outside `repository.ts` files.**
- **No Supabase client instantiation is allowed outside `repository.ts` files.**
- **No `Date.now()` or `new Date()` in service or repository layers.** Time is
  always an injected `Clock` interface.
- **No HTTP response construction in handler or service layers.** Only
  `index.ts` builds `Response` objects.

These rules are enforced by grep gates in `tool/grep_gates.ts`.

---

## 3. Absence-invariants (enforced by grep gates in `make verify`)

- **No `Date.now()` or `new Date()` inside `service.ts` or `repository.ts`
  files.** Time is always an injected `Clock` so logic is deterministically
  testable.
- **No raw SQL strings** (template literals or concatenated strings containing
  `SELECT`, `INSERT`, `UPDATE`, `DELETE`) **outside `repository.ts` files.**
  All queries live in the repository layer.
- **No `createClient` calls outside `repository.ts` files.** The Supabase
  client is injected into repositories — never instantiated in handlers or
  services.
- **No hardcoded secrets** — no API keys, JWT secrets, or service-role keys
  in any source file. All secrets come from `Deno.env.get(...)`.
- **No `console.log` in production code paths.** Use the structured logger in
  `supabase/functions/_shared/logger.ts`. (Tests may use `console`.)

---

## 4. Test-first, always (features AND bugs)

- **Features:** read the active PRD → break into atomic failing tests → write
  the test (red) → write code → `make verify` (green). No application code is
  written before a failing test exists for it.
- **Bugs:** write a regression test that reproduces the bug (turns the suite
  red) *before* writing any fix. Then fix, then `make verify`.

Edge Functions are tested against injected abstractions (`Clock`,
`SupabaseClientAdapter`) so correctness is provable without a live Supabase
instance. Integration tests use `supabase start` (local Docker). Unit tests
use in-memory fakes. This is mandatory — see `docs/architecture/testing.md`.

---

## 5. Doc honesty is enforced, not requested

When you finish a task that changes the system's shape (a new Edge Function, a
new migration, a new RLS policy, a new service), you **must** update the
relevant `docs/architecture/*.md` file before marking the task done.

`make verify` extracts every `supabase/functions/...` and
`supabase/migrations/...` path referenced in `docs/architecture/*.md` and
fails if any no longer resolves. Schema *facts* in `schema.md` are generated
from the migration head into the fenced `<!-- SCHEMA -->` region — never
hand-edit inside the fence.

`make verify` also runs `tool/doc_coverage.ts` (stage 5b): every task in
`docs/tasks/` with `**Status:** complete` must have its
`<!-- doc-update -->` acceptance criterion checked (`- [x]`), or carry a
`**No-doc-impact:** <reason>` field. A completed task with an unchecked
doc-update criterion and no escape hatch fails the build.

---

## 5b. Documentation & communication conventions

- **All documents are Markdown (`.md`).** Never produce `.docx`, `.pdf`, or
  other binary formats.
- **Questions are discussions, not forms.** When something needs clarifying,
  ask in plain conversation. Do not use multiple-choice/question UI tooling.

---

## 6. Where to read next (routing)

Read `docs/architecture/index.md` — it maps your task to the one doc you need.

- Product rules / what to build → `docs/planning/active/PRD.md`
- Database schema, migrations, RLS → `docs/architecture/schema.md`
- Edge Function contracts, auth, payloads → `docs/architecture/functions.md`
- Testing strategy, fakes, integration harness → `docs/architecture/testing.md`
- Dev environment / first-run / local Supabase → `docs/SETUP.md`

When setup or toolchain changes, update `docs/SETUP.md` in the same commit.
When changing the harness (skills, grep gates, verify stages), see
`docs/HARNESS.md §7`.

---

## 7. Mentor mode

When the human signals they want to learn and drive the implementation
themselves ("teach me", "help me understand", "I want to build this myself"),
switch into **Mentor Mode**.

**Hard rule:** nothing you produce is the final deliverable. Never write code
to `supabase/functions/`, `supabase/migrations/`, or `tool/`. The human types
the real thing.

Load `.claude/skills/mentor/SKILL.md` for the full protocol.

---

## 8. Skill library

Skills live in `.claude/skills/<name>/SKILL.md`. `.agents/skills/` is a
content-copy mirror kept in sync by `tool/check_skill_links.ts`. Use
`/add-skill` to add a new skill; it runs the sync step automatically. The full
library is in `docs/HARNESS.md §6`.
