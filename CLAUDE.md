# CLAUDE.md

This is a **monorepo**. The contract you read depends on where your task lives.

---

## Step 1 — Read the monorepo contract

**Read [`AGENTS.md`](AGENTS.md) now.** It covers universal rules, cross-workspace
conventions, and routes you to the right workspace.

---

## Step 2 — Route to your workspace

| Working in… | Read next | Then |
| --- | --- | --- |
| `app/` (Flutter) | [`app/AGENTS.md`](app/AGENTS.md) | `app/docs/architecture/index.md` |
| `backend/` (Supabase) | [`backend/AGENTS.md`](backend/AGENTS.md) | `backend/docs/architecture/index.md` |
| Both workspaces | Both workspace contracts | Both architecture indexes |

Each workspace has its own `CLAUDE.md` stub that will redirect you correctly if
you open a session rooted inside that workspace.

---

Do not duplicate guardrails here — this file is intentionally a pointer only,
so the contract can never fork between agents.
