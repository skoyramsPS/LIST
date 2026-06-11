# 002: Supabase scaffold + sync schema migration + RLS

**Workspace:** backend
**Type:** AFK
**Status:** pending
**Blocked by:** 001
**Harness stages exercised:** schema-fresh / test / fmt / lint

## What to build

The complete persistence layer in one vertical slice: Supabase project
scaffolding, the **single binding migration** (companion PRD §1), RLS on both
tables, and SQL-level integration tests proving the policies and the sequence
trigger — never schema without policy, never policy without tests.

- **Scaffold:** `supabase init` (config + local stack); `make start` brings up
  the local Docker stack; document any first-run steps in `docs/SETUP.md` in
  the same commit if the toolchain story changes.
- **One migration** creating, exactly per the binding DDL:
  - `sync_entities` — `PRIMARY KEY (user_id, id)`, the
    `CHECK (encrypted_payload IS NOT NULL OR deleted_at IS NOT NULL)`
    constraint, and `idx_sync_entities_pull ON (user_id, server_seq)`.
    **No foreign-key constraints anywhere.**
  - `sync_state` — `user_id` PK, `key_epoch BIGINT NOT NULL DEFAULT 0`.
  - The per-user monotonic `server_seq` **trigger firing on INSERT and
    UPDATE** (plain `BIGSERIAL` fires only on insert and is insufficient).
  - RLS enabled on both tables; single policy pattern
    `auth.uid() = user_id` for SELECT / INSERT / UPDATE / DELETE.
- **Schema fence:** run `make gen` so the `<!-- SCHEMA -->` region in
  `docs/architecture/schema.md` regenerates from the migration head, committed
  together (first-migration wiring — the generator exists, it must now run).
- **Integration tests** (in `supabase/functions/_harness/`, against
  `supabase start`):
  - RLS isolation with two JWTs: user A cannot SELECT, upsert, or delete user
    B's rows in either table.
  - `server_seq` is per-user monotonic across INSERTs and UPDATEs; two users'
    sequences are independent.
  - The CHECK constraint rejects a live row (`deleted_at IS NULL`) with a NULL
    `encrypted_payload`.

## Acceptance criteria

- [ ] `make verify` is green in backend/ after this task
- [ ] At least one failing test existed before the implementation was written
- [ ] The migration DDL matches companion PRD §1 byte-for-byte in substance (table shapes, CHECK, index, defaults)
- [ ] RLS-isolation tests pass at the SQL level with two distinct JWTs, independent of any handler logic
- [ ] `server_seq` trigger test proves monotonic assignment on both INSERT and UPDATE
- [ ] The `<!-- SCHEMA -->` fence in `schema.md` is regenerated and `schema-fresh` passes
- [ ] <!-- doc-update --> Architecture doc updated if any new function or schema path was introduced

## Schema and RLS obligations (if applicable)

- New tables `sync_entities` and `sync_state`: migration file + RLS policy in
  this same task — never split.
- RLS policies tested both ways: authorised access allowed, unauthorised denied.
- Sync-contract columns on `sync_entities`: `updated_at`, `deleted_at`,
  `sync_version`, `device_id`, `encrypted_payload` — all present per the
  binding DDL.

## Notes

The advisory-lock concurrency rule (companion PRD §2) is *used* by the Edge
Functions, so it lands with them (003/005) — but the schema this task creates
is what makes the lock necessary: sequence values commit out of order under
concurrency. The serialization proof itself is task 004, once push and pull
both exist to observe a gap.
