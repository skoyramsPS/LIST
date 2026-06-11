# 003: `sync_push` Edge Function end-to-end

**Workspace:** backend
**Type:** AFK
**Status:** pending
**Blocked by:** 002
**Harness stages exercised:** grep-gates / lint / test / doc-honesty

## What to build

The first Edge Function as a full four-layer vertical slice (companion PRD §4
`sync_push`, §2 advisory lock, §5 prohibitions), plus the `_shared/` utilities
— created here with their first consumer, never as a stub batch:

- **`supabase/functions/_shared/`:** `logger.ts` (structured logger),
  `clock.ts` (`Clock` interface + `RealClock`/`FakeClock` per `testing.md`),
  `errors.ts` (typed errors + the `{ error, code }` envelope), `auth.ts`
  (JWT verification used by `index.ts`).
- **`supabase/functions/sync_push/`** — `index.ts` (HTTP + JWT validation +
  request parsing + Response construction only) → `handler.ts` (orchestration,
  no SQL) → `service.ts` (pure domain logic, injected `Clock`) →
  `repository.ts` (the only SQL/Supabase-client layer).
- **Behaviour** (single transaction, `pg_advisory_xact_lock(hashtext(user_id))`
  held):
  1. Lazily create the user's `sync_state` row; compare `key_epoch` —
     mismatch → `409 { error, code: 'epoch_mismatch' }`, nothing written.
  2. Per item: conditional upsert — write only if new or
     `incoming.updated_at >= existing.updated_at`; stale items **silently
     skipped**, never failing the batch. `deleted_at` set → store
     `encrypted_payload = NULL`.
  3. Accepted writes get the next per-user `server_seq` via the trigger.
  4. `200 { applied_count, key_epoch }` — no per-row applied/stale statuses.
     >500 items → `400 batch_too_large`; malformed → `400 invalid_request`;
     no/bad JWT → `401 unauthorized`.
- **Unit tests** with `FakeSupabaseClient` + `FakeClock` (no Docker): LWW guard
  (older skipped, equal applied, newer applied, mixed batch commits non-stale
  items), epoch mismatch writes nothing, lazy `sync_state` creation, tombstone
  nulls payload, 501-item batch → 400, missing fields → 400.
- **Integration tests** against local Supabase: full HTTP round-trip with a
  real JWT; no-JWT → 401; the function runs with the **user's JWT** (anon key
  + Authorization header) so RLS is the backstop — no service-role usage.

## Acceptance criteria

- [ ] `make verify` is green in backend/ after this task
- [ ] At least one failing test existed before the implementation was written
- [ ] Wire shape matches the contract verbatim: `{ key_epoch, items: [≤500] }` → `200 { applied_count, key_epoch }`; error envelope `{ error, code }` with the four codes
- [ ] The service layer never reads `encrypted_payload` contents and never branches on `sync_version` or `table_name` semantics (companion PRD §5)
- [ ] Advisory lock is taken at the top of the push transaction
- [ ] `functions.md` gains the `sync_push` section with resolving source paths
- [ ] <!-- doc-update --> Architecture doc updated if any new function or schema path was introduced

## Schema and RLS obligations (if applicable)

No new tables. The function authenticates with the user's JWT so the task-002
RLS policies apply as the backstop; at least one test proves a request cannot
touch another user's rows even through the function path.

## Notes

Grep gates bind hard here: no SQL or `createClient` outside `repository.ts`,
no `Date.now()`/`new Date()` in service/repository (injected `Clock`), no
`console.log` (use `_shared/logger.ts`), no hardcoded secrets
(`Deno.env.get(...)` only), no `Response` construction outside `index.ts`.
If task 001 deferred any path-bearing `functions.md` lines, land them now.
