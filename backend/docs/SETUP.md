# Dev Setup — TheLIST Backend

Cross-platform setup guide for the backend. Keep this file current whenever
the toolchain or first-run steps change (AGENTS.md §6).

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Deno | ≥ 1.44 | https://deno.land/#installation |
| Supabase CLI | ≥ 1.170 | `brew install supabase/tap/supabase` or https://supabase.com/docs/guides/cli |
| Docker Desktop | latest | Required for `supabase start` (local instance) |

---

## First run

```bash
# 1. Clone and enter the backend directory
cd LIST/backend

# 2. Verify toolchain
deno --version
supabase --version
docker --version

# 3. Run the full verify pipeline (should be green on a clean clone)
make verify

# 4. Start the local Supabase stack (for integration tests)
make start
# Access the local Studio at: http://localhost:54323
```

---

## Environment variables

Edge Functions read secrets from `Deno.env.get()`. For local development,
create a `.env.local` file (gitignored) in `backend/`:

```
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=<from supabase start output>
SUPABASE_SERVICE_ROLE_KEY=<from supabase start output>
```

Never commit secrets. The `no-hardcoded-secrets` grep gate will catch any
accidental commit of key material.

---

## Useful commands

```bash
make verify     # full gate — the only definition of done
make fmt        # auto-format
make lint       # static analysis
make gates      # grep gates only
make gen        # regenerate schema fence in docs/architecture/schema.md
make test       # unit tests only (no Docker needed)
make start      # start local Supabase stack
make stop       # stop local Supabase stack
```

---

## Adding a migration

1. Create `supabase/migrations/<timestamp>_<description>.sql`
2. Apply it: `supabase db reset` (local) or `supabase db push` (remote)
3. Regenerate the schema fence: `make gen`
4. Run `make verify` — the `schema-fresh` stage will catch a stale fence
