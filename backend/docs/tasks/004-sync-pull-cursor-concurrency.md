# 004: `sync_pull` + cursor-gap concurrency proof

**Workspace:** backend
**Type:** AFK
**Status:** pending
**Blocked by:** 003
**Harness stages exercised:** grep-gates / lint / test / doc-honesty

## What to build

The pull function (companion PRD §4 `sync_pull`) in the same four-layer shape
as 003, plus the advisory-lock serialization proof — which needs both push and
pull to exist before a cursor gap is observable:

- **`supabase/functions/sync_pull/`** — `index.ts` → `handler.ts` →
  `service.ts` → `repository.ts`, reusing `_shared/`.
- **Behaviour:** epoch check as in push (`409 epoch_mismatch`, lazy
  `sync_state` creation); then
  `SELECT … WHERE user_id = auth.uid() AND server_seq > :cursor
  ORDER BY server_seq LIMIT :batch_size` (`batch_size ≤ 500`, else
  `400 invalid_request`). Response
  `200 { changes: SyncItem&{server_seq}[], next_cursor, has_more, key_epoch }`.
- **Unit tests** (fakes, no Docker): exact batch boundaries (e.g. 500/500/201),
  `has_more` correctness at the boundary, `next_cursor` monotonicity, stale
  epoch rejected, empty result shape.
- **Concurrency integration tests** (local Supabase — the companion PRD §2
  obligation):
  - Two concurrent pushes for one user serialize on the advisory lock: a pull
    issued at any interleaving point never permanently misses a row (no cursor
    gap from out-of-order sequence commits).
  - Two different users push fully in parallel (the lock is per-user, not
    global).

## Acceptance criteria

- [ ] `make verify` is green in backend/ after this task
- [ ] At least one failing test existed before the implementation was written
- [ ] Wire shape matches the contract verbatim: `{ key_epoch, cursor, batch_size }` → `{ changes, next_cursor, has_more, key_epoch }`
- [ ] A client looping until `has_more = false` receives every row exactly once, in `server_seq` order
- [ ] The cursor-gap test fails when the advisory lock is removed (proving the test bites) and passes with it in place
- [ ] Pull returns only the caller's rows (RLS + `auth.uid()` predicate both proven)
- [ ] `functions.md` gains the `sync_pull` section with resolving source paths
- [ ] <!-- doc-update --> Architecture doc updated if any new function or schema path was introduced

## Schema and RLS obligations (if applicable)

No new tables. The pull path must be covered by an RLS-isolation test (user A
pulling never sees user B's rows).

## Notes

Pull itself takes no advisory lock — only writers (push/reset) serialize; the
gap-safety property is that a *reader* can trust `server_seq` ordering because
writers commit serially per user. The "lock removed → test fails" criterion is
the regression guard for exactly that property.
