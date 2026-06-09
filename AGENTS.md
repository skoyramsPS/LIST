# AGENTS.md — Monorepo Contract (read this first, every time)

This is **TheLIST** — a monorepo containing two independent workspaces:

- **`app/`** — offline-first, local-first Flutter app with a true E2EE multi-device sync engine
- **`backend/`** — Supabase Edge Functions, SQL migrations, and RLS policies that power the sync layer

This file is the monorepo-level contract: rules that apply everywhere, and routing
to the workspace you are actually working in. It is intentionally lean — workspace-
specific rules (layering, grep gates, verify pipelines) live in the workspace's own
`AGENTS.md`, not here.

**If anything you are about to do conflicts with a rule here or in the relevant
workspace contract, stop.**

---

## 0. Route to your workspace first

Before doing anything, identify which workspace your task lives in and read that
contract:

- Working in **`app/`** → read [`app/AGENTS.md`](app/AGENTS.md), then `app/docs/architecture/index.md`
- Working in **`backend/`** → read [`backend/AGENTS.md`](backend/AGENTS.md), then `backend/docs/architecture/index.md`
- Working **across both** (e.g. a cross-cutting change to the sync contract) → read both workspace contracts before acting

Do not apply `app/` rules to `backend/` work or vice versa. The toolchains,
layering rules, and verify pipelines are intentionally different.

---

## 1. Universal prime directive: `make verify` is truth

Every workspace has its own `make verify`. You may **never** report a task,
feature, or bug fix as complete unless `make verify` exits green **in the
workspace you changed**.

If your change touches both workspaces, both must be green before you are done.

---

## 2. No proprietary infrastructure assumptions

Both workspaces are built on explicitly chosen open dependencies — nothing hidden,
nothing assumed. If you find yourself reaching for an external proprietary library,
service, or framework that isn't already declared in `app/pubspec.yaml` or
`backend/deno.json`, stop and raise it with the human first.

---

## 3. Universal conventions

These apply in both workspaces and override any agent's default behaviour:

- **All documents are Markdown (`.md`).** Never produce `.docx`, `.pdf`, or other
  binary formats. Specs, plans, architecture, and notes are all `.md`.
- **Questions are discussions, not forms.** When something needs clarifying, ask
  in plain conversation. Do not use multiple-choice/question UI tooling.
- **Doc honesty is enforced, not requested.** When a task changes the system's
  shape, update the relevant architecture doc before marking the task done.
  Each workspace's verify pipeline checks this mechanically.
- **Test-first, always.** No production code is written before a failing test
  exists for it — for features and bugs alike.

---

## 4. Cross-workspace concerns

The two workspaces share a sync contract: the Flutter app writes E2EE blobs; the
backend stores and retrieves them. Changes to the sync protocol touch both sides.

When making a cross-workspace change:
1. Read both workspace contracts before writing anything
2. Coordinate schema changes in `backend/supabase/migrations/` with the Flutter
   sync engine in `app/lib/sync/`
3. Both `app/make verify` and `backend/make verify` must be green before the
   change is complete
4. Update both `app/docs/architecture/sync.md` and `backend/docs/architecture/schema.md`
   in the same commit

---

## 5. `_human/` is off-limits

`_human/` at the repo root contains rejected-alternative rationale and dead
context. It is invisible to agents by design and enforced by a grep gate in the
`app/` harness. Do not reference it from any code or doc.

---

## 6. Mentor mode

When the human signals they want to learn and drive the implementation themselves
("teach me", "help me understand", "I want to build this myself"), switch into
**Mentor Mode** for the relevant workspace.

Load `.claude/skills/mentor/SKILL.md` from the workspace you are in.

**Hard rule:** nothing you produce is the final deliverable. Never write code to
the workspace source directories. The human types the real thing.
