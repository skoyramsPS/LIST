# Architecture Index — Backend Routing Map

**Read this file first, then read only the one doc your task needs.** This map
exists so you never load the entire system's design into context to make a
localized change.

---

## Route by task

| If your task touches… | Read | Source code lives in |
| --- | --- | --- |
| Database schema, tables, columns, RLS policies, migrations | [`schema.md`](./schema.md) | `supabase/migrations/` |
| Edge Function contracts, request/response shapes, auth, payloads | [`functions.md`](./functions.md) | `supabase/functions/` |
| Testing strategy, fakes, local Supabase, integration harness | [`testing.md`](./testing.md) | `supabase/functions/_harness/` |
| Product behaviour, feature scope, what an endpoint should do | [`/docs/planning/active/PRD.md`](../planning/active/PRD.md) | — |
| Build rules, layering, what `make verify` enforces | [`/AGENTS.md`](../../AGENTS.md) | repo root |

---

## The three load-bearing ideas

1. **The server is dumb; clients converge.** This backend is an authenticated,
   RLS-guarded log of opaque encrypted blobs with plaintext LWW timestamps.
   All merge logic runs on-device. Supabase never sees plaintext user data.
   → `schema.md`, `functions.md`

2. **Layering is enforced mechanically.** HTTP entry-points (`index.ts`) only
   parse requests and build responses. Handlers orchestrate. Services hold
   domain logic. Repositories hold SQL. No shortcuts — grep gates enforce this.
   → `AGENTS.md §2`

3. **Time is injected, not read.** `Date.now()` is banned in service and
   repository layers. A `Clock` interface is injected so all logic is
   deterministically testable without mocking the system clock.
   → `testing.md`

---

## Layering (the spine everything hangs on)

```
index.ts (HTTP)  →  handler.ts (orchestration)  →  service.ts (domain logic)
                                                  ↘  repository.ts (SQL + Supabase)
                                                                   ↓
                                                          supabase/migrations/ (schema)
```

One direction only. Only `repository.ts` files run SQL or touch the Supabase
client. See `AGENTS.md §2` for the enforced rules.
