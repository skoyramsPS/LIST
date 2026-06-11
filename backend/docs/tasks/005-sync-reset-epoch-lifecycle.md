# 005: `sync_reset` + epoch lifecycle tests

**Workspace:** backend
**Type:** AFK
**Status:** pending
**Blocked by:** 004
**Harness stages exercised:** grep-gates / lint / test / doc-honesty

## What to build

The erase-cloud-and-start-over path (companion PRD §4 `sync_reset`; master PRD
§10) in the same four-layer shape, plus the cross-function epoch lifecycle
tests that need push, pull, and reset all live:

- **`supabase/functions/sync_reset/`** — `index.ts` → `handler.ts` →
  `service.ts` → `repository.ts`, reusing `_shared/`.
- **Behaviour** (single transaction, advisory lock held): request `{}` —
  identity comes from the JWT; delete **all** of the caller's `sync_entities`
  rows **and** increment `sync_state.key_epoch` atomically. Response
  `200 { key_epoch }` (the new epoch). The per-user `server_seq` counter is
  **not** reset (stale cursors held by offline devices stay behind the new
  rows; their next interaction 409s on the epoch anyway).
- **Unit tests** (fakes): atomicity — rows gone + epoch bumped, or neither;
  new epoch returned; reset of an account with no `sync_state` row creates it
  lazily and bumps from 0.
- **Epoch lifecycle integration tests** (local Supabase, cross-function — the
  offline-peer scenario app task 026 converges against):
  - Device A pushes → device B resets → device A's next push with the old
    epoch → `409 epoch_mismatch`, nothing written.
  - Same for device A's next pull with the old epoch.
  - After re-adopting the new epoch, push and pull succeed and echo it.
  - RLS: user A's reset deletes none of user B's rows.

## Acceptance criteria

- [ ] `make verify` is green in backend/ after this task
- [ ] At least one failing test existed before the implementation was written
- [ ] Wire shape matches the contract verbatim: `{}` → `200 { key_epoch }`
- [ ] Atomicity proven: a failed reset leaves both rows and epoch untouched
- [ ] Stale-epoch push **and** pull each 409 after a reset, with nothing written on the push path
- [ ] `server_seq` continues from its pre-reset value (not reset)
- [ ] `functions.md` gains the `sync_reset` section with resolving source paths
- [ ] <!-- doc-update --> Architecture doc updated if any new function or schema path was introduced

## Schema and RLS obligations (if applicable)

No new tables. Reset must be RLS-tested: it can never touch another user's
rows, even if handler logic were buggy.

## Notes

This completes the backend's entire function surface — three functions, no
more (companion PRD: "the complete surface"). The server never holds key
material; "reset" is purely data deletion + epoch bump. Key custody, the
recovery phrase, and re-encryption are app-side (app tasks 023/026).
