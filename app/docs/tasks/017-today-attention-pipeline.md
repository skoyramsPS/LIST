# 017: Today tab — the attention pipeline

**Type:** AFK
**Status:** pending
**Blocked by:** 015, 016
**Harness stages exercised:** test / grep-gates

## What to build

The Today tab as a read-time derivation (master PRD §6, §18; `data_model.md` §6):

- **`AttentionRepository`** (read-only): three native sources → one
  `List<AttentionItem>`:
  1. Due/overdue/upcoming reminders (`target_date <= :now AND is_enabled = 1`,
     plus the upcoming window).
  2. Overdue Waiting-On via `v_waiting_on` (`status = 'waiting' AND due_date < :now`).
  3. Trial Limbo via `v_subscriptions` (`status = 'trial' AND end_date < :now`).
- One Riverpod provider feeds the tab; `:now` is bound fresh on every read
  (midnight rollover needs no invalidation).
- **Trial Limbo card:** pinned to the top, unignorable, offering the three-way
  resolution *Converted to Active / Canceled / Expired* — the only pinning kind.
- Overdue Waiting-On and due reminders are normal items: tap →
  navigate-and-pulse (reusing 015's mechanism).
- No charts, analytics, or calendar views.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Repository test with `FakeClock`: advancing time across a due date moves an item into the list with **zero writes** (purely derived)
- [ ] Trial Limbo pins above all other items; resolving it writes the chosen status and the card disappears
- [ ] Overdue Waiting-On appears as a normal (non-pinned) item
- [ ] Tapping any item opens the sheet, scrolls to the row, pulses it
- [ ] Heavy lifting stays in SQL — no test hydrates all cells into Dart to filter
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No `DateTime.now()` in `lib/repositories/`
- No Drift import under `lib/features/` or `lib/state/`
- No raw colour hex or spacing literals in `lib/features/`

## Notes

`AttentionItem` carries a `kind` plus sheet/row link — Trial Limbo and overdue
Waiting-On are just kinds, never stored rows or fake reminders. "Upcoming"
window size is a product call surfaced in `ux_spec.md`; pick a named constant.
