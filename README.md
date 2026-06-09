# TheLIST

An **offline-first, local-first Flutter list app** with a **true end-to-end-encrypted, multi-device sync engine**.

You make flexible lists ("Sheets") — groceries, subscription/free-trial trackers, goals, habits — reorder them by hand, and attach reminders. Everything works fully offline with no account. When you choose to sign in, your data syncs privately across your own devices, end-to-end encrypted, where the server can never read it.

The headline isn't the list app — it's the **sync engine**: field-level last-write-wins convergence across offline devices, with E2EE, built so its correctness is *provable by deterministic test* (two in-memory clients, no network).

---

## Status

Early scaffold. The **product and architecture are fully specified**, and the **coding-agent harness is in place** for both the Flutter app and the Supabase backend. Feature implementation follows, test-first, behind `make verify` in each workspace.

---

## How the project is organised

This is a **monorepo** with two workspaces. Each has its own harness, contract, and `make verify` pipeline.

```
AGENTS.md                        ← monorepo-level contract (update once we finalise)
CLAUDE.md                        ← pointer stub → AGENTS.md
app/                             ← Flutter app (offline-first, E2EE, Riverpod + Drift)
  AGENTS.md                      ← Flutter-specific contract (layering, grep gates, verify)
  CLAUDE.md                      ← pointer stub → app/AGENTS.md
  Makefile                       ← app harness entrypoints (make verify, make test, …)
  pubspec.yaml
  lib/                           ← app code, strictly layered (see app/AGENTS.md §2)
  test/                          ← unit, widget, convergence matrix; harness self-tests
  tool/                          ← Dart harness scripts (verify, gates, generators)
  docs/
    planning/active/the-list/PRD.md   ← product spec: WHAT to build
    architecture/
      index.md                   ← routing map: which doc your task needs
      data_model.md              ← EAV, UUIDs, STRICT tables, SQLite Views
      sync.md                    ← dumb server, LWW merge, E2EE keys, scheduler
      design_system.md           ← List* components, AppTokens, typography
    tasks/                       ← TDD handoff checklists
  assets/                        ← fonts, images
  _human/                        ← rejected-alternative rationale; INVISIBLE to agents
backend/                         ← Supabase backend (Edge Functions, migrations, RLS)
  AGENTS.md                      ← backend-specific contract (layering, grep gates, verify)
  CLAUDE.md                      ← pointer stub → backend/AGENTS.md
  Makefile                       ← backend harness entrypoints (make verify, make test, …)
  deno.json
  supabase/
    functions/                   ← Edge Functions (index → handler → service → repository)
    migrations/                  ← SQL schema, RLS policies
  tool/                          ← Deno/TS harness scripts (verify, gates, generators)
  docs/
    architecture/
      index.md                   ← routing map
      schema.md                  ← generated schema fence
      functions.md               ← Edge Function contracts
      testing.md                 ← seams, fakes, integration harness
    tasks/                       ← TDD handoff checklists
```

**Read order for any contributor (human or agent):** start at the `AGENTS.md` for the workspace you're in → `docs/architecture/index.md` → the one doc your task points to. You should rarely need to load more than that.

---

## The harness: `make verify`

Each workspace has its own `make verify`. **Nothing is "done" until it is green in the relevant workspace.**

### Flutter app (`cd app && make verify`)

Runs in strict order, fail-fast:

1. `dart format --set-exit-if-changed .`
2. `dart analyze --fatal-infos --fatal-warnings`
3. **grep-gates** — absence-invariants (layering, no raw hex, no DateTime.now in sync, …)
4. **schema-fresh** — generated schema block in `data_model.md` is up to date
5. **doc-honesty** — every `lib/...` path in the architecture docs still exists
6. **test** — `flutter test` (unit, widget, sync convergence matrix, harness self-tests)

```bash
cd app
flutter pub get          # one-time setup
dart fix --apply && dart format .
dart run tool/verify.dart   # or: make verify
```

### Backend (`cd backend && make verify`)

Runs in strict order, fail-fast:

1. `deno fmt --check .`
2. `deno lint`
3. **grep-gates** — no SQL outside repositories, no Supabase client outside repositories, no hardcoded secrets, …
4. **schema-fresh** — `docs/architecture/schema.md` fence matches migration head
5. **doc-honesty** — every `supabase/functions/...` path in the architecture docs still exists
6. **test** — `deno test` (unit tests with fakes; integration tests against local Supabase)

```bash
cd backend
make verify              # or: deno run --allow-all tool/verify.ts
```

### What the Flutter gates enforce

| Gate | Rule | Why |
| --- | --- | --- |
| `no-datetime-now` | no `DateTime.now()` in `lib/sync`, `lib/repositories`, `lib/notifications` | time is an injected `Clock` — sync is deterministically testable |
| `no-raw-hex` / `no-raw-spacing` | no raw colours or spacing literals in `lib/features` | everything routes through `AppTokens` |
| `no-material-visual` | no banned Material widgets in `lib/features` | the UI uses scoped-bespoke `List*` components |
| `layer-no-drift-in-ui` | no `drift` import in `lib/features` or `lib/state` | only repositories touch the database |
| `layer-no-supabase-outside-sync` | no `supabase` import outside `lib/sync` | the sync engine is the only thing that talks to the backend |
| `no-human-ref` | nothing in `lib/` or `test/` references `/_human/` | rejected/dead context is quarantined |

### What the backend gates enforce

| Gate | Rule | Why |
| --- | --- | --- |
| `no-datetime-in-service` | no `Date.now()` / `new Date()` in service or repository layers | time is an injected `Clock` |
| `no-sql-outside-repository` | no raw SQL template literals outside `repository.ts` files | all queries live in the repository layer |
| `no-supabase-client-outside-repository` | no `createClient()` outside `repository.ts` files | client is injected, never instantiated in handlers |
| `no-hardcoded-secrets` | no JWT tokens or service-role keys in source files | secrets come from `Deno.env.get()` only |
| `no-console-log-in-production` | no `console.log` in non-test production code | use the structured logger |

---

## How work happens here

- **Greenfield.** Everything is built from scratch in both workspaces.
- **Test-first**, for features *and* bugs. A feature starts as a failing test; a bug starts as a failing regression. Then code, then `make verify`.
- **Docs stay honest by construction**: schema facts are generated, doc-referenced paths are checked by the harness.
- **All docs are Markdown; decisions are made by discussion.**

---

## Tech stack

**App:** Flutter · Riverpod 3 · Drift (SQLite) · `flutter_local_notifications` + `workmanager` · Plus Jakarta Sans. Local DB is plaintext (OS-sandbox); only synced data is E2EE.

**Backend:** Supabase (Postgres + Auth + Realtime) · Deno Edge Functions (TypeScript) · Row-Level Security. The server is a dumb, RLS-guarded encrypted blob store — it never decrypts user data.

## License

See [LICENSE](./LICENSE).
