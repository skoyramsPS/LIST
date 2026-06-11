# 008: Row deletion, undo, long-press menu

**Type:** AFK
**Status:** pending
**Blocked by:** 006
**Harness stages exercised:** test / grep-gates

## What to build

The full deletion story (master PRD §12; `sync.md` §6):

- **Long-press row menu** (bottom sheet, minimal): Copy title · Delete.
  (Duplicate joins this menu in 019.)
- **Deferred tombstone:** on Delete, the provider hides the row immediately and
  shows the snackbar ("Milk deleted · Undo"); the Drift write of `deleted_at`
  (+ dirty flag) fires **only when the 5 s timer completes**. Undo within the
  window is pure UI state — no DB op ever happened.
- **`sync_version == 0` optimization:** a row the server has never seen is
  hard-`DELETE`d instead of tombstoned.
- Tombstones are retained forever locally — no purge path.
- **Sheet deletion:** confirmation via the destructive morph of the Sheet
  Settings bottom sheet (the one sanctioned `danger` usage) — may land as a
  minimal version here or with sheet settings in 019; either way sheet delete
  requires confirmation.

The 5 s window comes from a named constant; the timer runs on the injected `Clock`.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Test with `FakeClock`: delete → row hidden, DB untouched; advance 5 s → `deleted_at` written
- [ ] Test: delete → Undo before 5 s → row visible, DB never wrote a tombstone
- [ ] Test: app killed mid-window (simulated by dropping the pending op) leaves the row alive
- [ ] Test: `sync_version == 0` row is hard-deleted; `sync_version > 0` row gets `deleted_at`
- [ ] Long-press menu offers Copy title and Delete with a discoverable alternative path
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No `DateTime.now()` in `lib/repositories/` (the deferred-commit timer uses the injected `Clock`)
- No Drift import under `lib/features/` or `lib/state/`
- `danger` red only on the final permanent-delete confirmation — never on the snackbar or swipe affordances

## Notes

Undo is local-only and ephemeral by design — never a resurrection op. The
dirty-flag mechanism this task introduces is the same one the sync engine
consumes in 024; keep it in the repository layer.
