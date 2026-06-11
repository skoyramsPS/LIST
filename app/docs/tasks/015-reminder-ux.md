# 015: Reminder UX

**Type:** AFK
**Status:** pending
**Blocked by:** 011, 014
**Harness stages exercised:** test / grep-gates

## What to build

Reminders become visible and tappable (master PRD §9, §16):

- **Reminder cell bottom sheet:** date-linked or standalone; recurrence
  None/Daily/Weekly/Monthly/Yearly with interval (quarterly = monthly × 3);
  multiple alert offsets (e.g. 7 days before, 1 day before); enable/disable.
  Writes through `ReminderRepository`; every write ends with
  `ReminderScheduler.reconcile()`.
- **Notification tap → navigate-and-pulse:** opens the app to the Sheet,
  scrolls to the row, pulses it (soft background tween ~400 ms per
  `design_system.md` §3).
- **Permission flow:** first-launch in-app explanation → "Enable Notifications"
  → OS prompt; if previously denied and a reminder is created, re-ask with a
  non-blocking warning (no nagging, no blocking).

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Widget test: build a quarterly reminder (monthly × 3) with two alert offsets through the sheet; persisted and reconciled
- [ ] Test: notification-tap payload routes to the correct sheet + row and triggers the pulse
- [ ] Test: denied permission → creating a reminder shows the non-blocking warning, never blocks the write
- [ ] Standard OS notifications only — no snooze, action buttons, or urgency modes
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/`
- No raw colour hex or spacing literals in `lib/features/` — the pulse tween uses token colours
- No banned Material visual widgets in `lib/features/`

## Notes

Permission status display in Settings is 021; the onboarding explainer screen
is 022 — this task owns the in-sheet flow and the deep-link/pulse path. The
pulse here is the same mechanism Today-tab taps reuse in 017.
