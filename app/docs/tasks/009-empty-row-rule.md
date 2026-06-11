# 009: Empty-row rule

**Type:** AFK
**Status:** pending
**Blocked by:** 006
**Harness stages exercised:** test

## What to build

The empty-row lifecycle rule (master PRD §12), end-to-end:

- A row with an **empty title and no other data** is auto-deleted when the user
  **navigates away from the Sheet or backgrounds the app** — never on
  keyboard-focus loss.
- A row with an empty title but other data is kept and shows a title-required
  warning affordance.
- Keyboard dismissal never triggers any destructive action.

Wire the trigger to route-leave (go_router) and app-lifecycle (background)
events; the decision logic lives in `SheetRepository` (it knows what "no other
data" means in EAV terms). Auto-deleted empty rows are exactly the
`sync_version == 0` hard-delete case from 008.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Test: empty-title, no-data row + navigate away → row gone (hard delete)
- [ ] Test: empty-title row **with** other cell data + navigate away → row kept, warning shown
- [ ] Test: keyboard dismissal with an empty row → row still present
- [ ] Test: app backgrounded → same cleanup as navigate-away
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No `DateTime.now()` in `lib/repositories/`
- No Drift import under `lib/features/` or `lib/state/`

## Notes

Small slice by design — it exists separately because the trigger conditions
(navigation/lifecycle, *not* focus) are exactly the kind of nuance that gets
lost inside a bigger ticket.
