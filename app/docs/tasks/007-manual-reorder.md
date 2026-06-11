# 007: Manual reorder — rows and sheets

**Type:** AFK
**Status:** pending
**Blocked by:** 006
**Harness stages exercised:** test / grep-gates

## What to build

Fractional-index ordering end-to-end (`data_model.md` §5):

- A position-key generator (fractional index + random jitter suffix,
  Figma-style — no LexoRank buckets, no rebalancing) used by row creation and
  reorder.
- **Row reorder:** drag handle on every row; a reorder rewrites **only the
  moved row's** `position`.
- **Sheet pin + reorder:** pin toggle on sheet cards; pinned group first, then
  unpinned; strictly manual order within each group
  (`ORDER BY is_pinned DESC, position ASC, id ASC`).
- Deterministic tiebreak `(position, id)` everywhere an order is read.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Repository test: moving a row between two others writes exactly one row's `position`
- [ ] Generator test: keys between any two neighbours always sort strictly between them; jitter makes repeated generations for the same gap distinct
- [ ] Identical position keys degrade to a stable `(position, id)` order, never an error
- [ ] Widget test: drag a row, order persists across re-open; pin a sheet, it moves to the pinned group
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No `DateTime.now()` in `lib/repositories/`
- No Drift import under `lib/features/` or `lib/state/`
- No raw colour hex or spacing literals in `lib/features/`

## Notes

`position` is a single field, so concurrent reorder is plain LWW later —
nothing sync-specific to do here, but keep the generator pure and injectable
(seeded RNG in tests) so jitter is testable.
