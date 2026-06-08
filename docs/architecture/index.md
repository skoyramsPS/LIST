# Architecture Index — Routing Map

**Read this file first, then read only the one doc your task needs.** This map
exists so you never load the entire system's design into context to make a
localized change. The docs here are *immortal*: they describe the living system
and are kept honest by the doc-path resolution checks in `make verify`.

(The product spec — the "What" — lives separately and is *mortal*:
`/docs/planning/active/the-list/PRD.md`. It is archived to `/_human/` once the product is
built.)

---

## Route by task

| If your task touches… | Read | Source code lives in |
| --- | --- | --- |
| Database schema, tables, cells, columns, rows, EAV, `STRICT`, UUIDs, SQLite Views, the Today-tab attention pivot | [`data_model.md`](./data_model.md) | `lib/data/`, `lib/repositories/` |
| Sync engine, the dumb server, per-cell LWW merge, conflict resolution, encryption keys (recovery phrase + QR), E2EE payload boundary, the notification scheduler & recurrence | [`sync.md`](./sync.md) | `lib/sync/`, `lib/crypto/`, `lib/notifications/` |
| Any UI, components, colours, spacing, the `List*` design system, the Pulse interaction, typography, light/dark theme | [`design_system.md`](./design_system.md) | `lib/ui/` (tokens + components), `lib/features/` |
| Product behaviour, feature scope, what a screen should do | [`/docs/planning/active/the-list/PRD.md`](../planning/active/the-list/PRD.md) | — |
| Build rules, layering, what `make verify` enforces | [`/AGENTS.md`](../../AGENTS.md) | repo root |

---

## The three load-bearing ideas (one line each, so you orient fast)

1. **Storage is EAV with first-class cells.** `Sheet → Column → Row → Cell`,
   where a Cell holds one scalar and *is* the unit of both merge and encryption.
   → `data_model.md`

2. **The server is dumb; clients converge.** Supabase is an authenticated,
   RLS-guarded log of opaque encrypted blobs + plaintext LWW timestamps. All
   merge logic runs on-device. Only the user's devices can decrypt. → `sync.md`

3. **The UI is scoped-bespoke.** Custom `List*` components are the only visible
   widgets; Material is an invisible accessibility chassis. Everything routes
   through `AppTokens`. → `design_system.md`

---

## Layering (the spine everything hangs on)

```
UI (features)  →  State (Riverpod)  →  Repository  →  Drift DB
                                                  ↘   Sync engine  →  Supabase
```

One direction only. Only repositories touch Drift. Only `lib/sync/` touches
Supabase. Time is always an injected `Clock`. See `/AGENTS.md` for the
enforced rules.
