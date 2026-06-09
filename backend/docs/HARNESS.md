# TheLIST Backend — Harness & Skill Library

**This document is live.** Every `supabase/functions/...`, `supabase/migrations/...`,
and `tool/...` path referenced here is verified by `make verify` (via
`tool/doc_honesty.ts`). If you add, move, or rename anything this document
points at, update this file in the same commit. A stale harness guide
misdirects agents on every session.

> **Who this is for.** Both coding agents (Claude and Codex) and the human
> working with them. Read this to understand what tools exist, when to invoke
> each one, and how they fit together. For machine setup, see `docs/SETUP.md`.
> For layering rules and build contract, see `AGENTS.md`.

---

## 1. The verify pipeline — the only definition of done

`deno run --allow-all tool/verify.ts` (or `make verify`) runs seven stages in
strict fail-fast order. A task is **not done** until all seven are green.

| Stage | Command | What it catches |
|---|---|---|
| **fmt** | `deno fmt --check .` | Unformatted code |
| **lint** | `deno lint` | Type errors, unused imports, Deno lint rules |
| **grep-gates** | `deno run --allow-all tool/grep_gates.ts` | Absence-invariant violations (see §2) |
| **schema-fresh** | `deno run --allow-all tool/gen_schema.ts --check` | `schema.md` fence out of sync with migrations |
| **doc-honesty** | `deno run --allow-all tool/doc_honesty.ts` | Dangling `supabase/...` or `tool/...` paths in docs |
| **doc-coverage** | `deno run --allow-all tool/doc_coverage.ts` | Completed tasks with unchecked doc-update criterion |
| **test** | `deno test --allow-all supabase/functions/` | Failing unit and integration tests |

**Never report a task complete without a green run.**

---

## 2. Grep gates — absence invariants

`tool/grep_gates.ts` scans the source tree for patterns that must *never*
appear in certain directories. Each gate accepts a `// gate-ok: <reason>`
inline marker to exempt a specific line.

| Gate name | Pattern forbidden | Where | Why |
|---|---|---|---|
| `no-datetime-in-service` | `Date.now()` / `new Date()` | `supabase/functions/` (service + repo layers) | Time must be an injected `Clock` for deterministic testing |
| `no-sql-outside-repository` | Raw SQL template literals | `supabase/functions/` (non-repository files) | All queries live in repository.ts |
| `no-supabase-client-outside-repository` | `createClient(` | `supabase/functions/` (non-repository files) | Client is injected; never instantiated in handlers |
| `no-hardcoded-secrets` | JWT tokens, service-role keys | `supabase/functions/`, `supabase/migrations/` | Secrets come from `Deno.env.get()` only |
| `no-console-log-in-production` | `console.log(` | `supabase/functions/` (non-test files) | Use structured logger in `supabase/functions/_shared/logger.ts` |
| `no-response-in-handler-or-service` | `new Response(` | `supabase/functions/` (non-index files) | Only `index.ts` builds HTTP responses |

**The gate tests themselves are tested.** `supabase/functions/_harness/grep_gates_test.ts`
plants deliberate violations in a sandbox and asserts each gate fires correctly.

---

## 2b. Doc-coverage gate — documentation rot by omission

`tool/doc_coverage.ts` catches the failure mode that `doc_honesty` cannot:
an agent that completes a task and updates the code but never touches the
architecture docs at all.

**The rule:** every task file in `docs/tasks/*.md` with `**Status:** complete`
must have its `<!-- doc-update -->` acceptance criterion checked (`- [x]`), or
carry a `**No-doc-impact:** <non-empty reason>` field.

**The marker line:**
```
- [ ] <!-- doc-update --> Architecture doc updated if any new path or symbol was introduced
```
When done, change `[ ]` to `[x]`.

**The escape hatch:**
```
**No-doc-impact:** <reason>
```
Legitimate reasons: `test-only change`; `tooling-only (tool/*.ts)`;
`config-only (deno.json/Makefile)`.

---

## 3. Schema fence

`tool/gen_schema.ts` reads `supabase/migrations/` in lexicographic order and
writes the concatenated DDL into the `<!-- SCHEMA -->` / `<!-- /SCHEMA -->`
fence in `docs/architecture/schema.md`. Never hand-edit inside the fence.

Run `make gen` after adding or modifying a migration. The `schema-fresh` stage
of `make verify` will catch a stale fence.

---

## 4. Skill sync — `.claude/skills/` ↔ `.agents/skills/`

Skills live in `.claude/skills/<name>/SKILL.md`. `.agents/skills/` is a
content-copy mirror for Codex. Run `tool/check_skill_links.ts --fix` after
adding or editing a skill. The `skill-links` stage of verify checks this.

Never create `.agents/skills/<name>/` manually — always use `--fix`.

---

## 5. Testing conventions

See `docs/architecture/testing.md` for full details. Summary:

| Seam | Production adapter | Test adapter |
|---|---|---|
| Time | — | `FakeClock` injected into service/repository layers |
| Supabase client | `@supabase/supabase-js` | `FakeSupabaseClient` in-memory adapter |
| HTTP | Deno serve | Direct `handler()` calls (no network) |

Unit tests live alongside their source (`<function>/<name>_test.ts`).
Integration tests live in `supabase/functions/_harness/` and require
`supabase start`.

---

## 6. Skill library

### .claude/skills/add-grep-gate/
When to invoke: a new architectural boundary needs a mechanical gate. Adds a
gate to `tool/grep_gates.ts`, writes its self-test, registers it in HARNESS.md §2.

### .claude/skills/add-skill/
When to invoke: a new `/skill-name` command is needed. Interviews, writes
SKILL.md, syncs to `.agents/skills/`, registers in HARNESS.md §6.

### .claude/skills/architect-review/
When to invoke: after writing a PRD (`review-prd`), after breaking into tasks
(`review-tasks`), or after implementing a feature (`review-implementation`).
Produces a findings report; never acts without approval.

### .claude/skills/grill-with-docs/
When to invoke: at the start of any new feature, before writing a PRD.
Challenges the idea against the architecture docs, RLS model, and layering
rules. Output feeds `to-prd`.

### .claude/skills/improve-codebase-architecture/
When to invoke: refactoring, architecture review, finding shallow modules.
Surfaces deepening opportunities without proposing AGENTS.md violations.

### .claude/skills/mentor/
When to invoke: human wants to learn and drive implementation. Coaches via
Socratic method; never writes production code. Escape hatch: `/just-tell-me`.

### .claude/skills/tdd/
When to invoke: building features or fixing bugs. Red-green-refactor with
`make verify` as the definition of done. Three checkpoints: A (baseline),
B (per cycle), C (task complete).

### .claude/skills/to-prd/
When to invoke: capturing a feature idea as a PRD. Synthesises from conversation
context; does not interview. Saves to `docs/planning/active/<slug>/PRD.md`.

### .claude/skills/to-tasks/
When to invoke: converting a PRD into implementation tasks. Vertical tracer-bullet
slices saved to `docs/tasks/<NNN>-<slug>.md`. Each task leaves `make verify` green.
