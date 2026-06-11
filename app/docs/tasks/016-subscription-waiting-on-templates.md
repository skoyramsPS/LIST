# 016: Subscription + Waiting On templates + pivot Views

**Type:** AFK
**Status:** pending
**Blocked by:** 011, 014
**Harness stages exercised:** test / schema-fresh

## What to build

The two status-driven templates and the EAV-pivot Views that make their derived
states queryable (master PRD §18; `data_model.md` §6):

- **`semantic_role` on columns**, assigned at template instantiation
  (`sub_status`, `sub_end_date`, `sub_cost`, `wait_status`, `wait_due_date`,
  `wait_from`, …). The role is the contract; the user-facing name is cosmetic.
- **`v_subscriptions` and `v_waiting_on`** SQLite Views in `lib/data/` that
  pivot cells back into relational columns keyed by role.
- **Subscription template:** statuses Trial/Active/Paused/Canceled/Expired
  (status capsule via `ListChip`); cycles Weekly/Monthly/Yearly × interval;
  only Trial and Active send reminders; **renewal dates never auto-advance** —
  a "Mark renewed" action advances them explicitly; trials never auto-convert
  or auto-expire (Trial Limbo itself is *derived* and surfaces in 017).
- **Waiting On template:** columns Item/From/Due Date/Reminder/Status; user
  sets only Waiting/Received; **Overdue is derived, never stored**; marking
  **Received auto-disables the active follow-up reminder in the same write**;
  reverting to Waiting does not re-arm it.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] View test: `v_subscriptions` returns trial rows past end date under a `:now` bound; `v_waiting_on` returns waiting rows past due date — no stored overdue/limbo state anywhere
- [ ] Renaming a column does not break the pivot (role, not name, is the key)
- [ ] Test: "Mark renewed" advances the renewal date; nothing advances it automatically under `FakeClock` time travel
- [ ] Test: setting Received disables the row's enabled reminder atomically in the same repository transaction; revert does not re-enable
- [ ] Schema fence regenerated (new Views change the Drift schema dump)
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No `DateTime.now()` in `lib/repositories/` or `lib/data/` — `:now` is bound at read time from the injected `Clock`
- No Drift import under `lib/features/` or `lib/state/`
- No raw colour hex or spacing literals in `lib/features/`

## Notes

Dense slice (two templates + two Views) — kept together because the
`semantic_role`/pivot mechanism is one piece of machinery and splitting it
would make the first half horizontal. If it runs long, the sanctioned split
line is: Subscription + role/View machinery first, Waiting On second.
