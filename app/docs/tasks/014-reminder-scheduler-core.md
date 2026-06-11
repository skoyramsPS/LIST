# 014: Reminder scheduler core

**Type:** AFK
**Status:** pending
**Blocked by:** 002
**Harness stages exercised:** test / grep-gates

## What to build

The deterministic notification machinery (`sync.md` §8), with no UI:

- **`ReminderRepository`** — CRUD over the first-class `reminders` table
  (target_date, recurrence rule, alert offsets, is_enabled).
- **Recurrence generator:** a lazy Dart `sync*` generator over the grammar
  (`freq`, `interval`, `byWeekday`, `anchor`) enforcing, each as its own test:
  1. **Clamp, never skip** (Jan 31 → Feb 28/29 → Mar 31).
  2. **Clamp from the anchor, never the prior result.**
  3. **Civil-time rule** — civil date+time extracted in the current timezone,
     re-applied per occurrence, then converted to UTC (DST-safe).
  4. **Never enumerates to infinity** — stops at budget/horizon.
- **`ReminderScheduler.reconcile()`** (sole public method,
  `lib/notifications/`): recomputes the soonest **N = 60** alert-instances
  (`reminder × offset × occurrence`) across all reminders within the 12-month
  safety horizon, then **diffs** against what is scheduled (cancel stale, add
  missing, keep matches). Notification IDs are deterministic =
  `hash(reminder_id, offset, occurrence_date)`.
- The OS notification plugin sits behind an injected interface; tests use a fake.
- Foreground/resume is the replenish trigger; background is best-effort only.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] All four recurrence enforcement rules pass against `FakeClock` (incl. a DST-transition case)
- [ ] Budget test: enumeration stops at 60 instances / 12-month horizon, whichever first; a lone far-future daily reminder does not enumerate past the horizon
- [ ] Reconcile is idempotent: running it twice with no changes schedules/cancels nothing the second time
- [ ] Deterministic-ID test: same (reminder, offset, occurrence) always yields the same ID across runs
- [ ] N = 60 and the horizon are named constants referenced by the tests
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- **No `DateTime.now()` in `lib/notifications/`, `lib/repositories/`, or any recurrence code** — `Clock` is injected everywhere
- No Drift import outside `lib/repositories/` / `lib/data/`

## Notes

Notification IDs and the scheduled slice are device-local and never synced —
each device materializes its own slice from synced `reminders` rows. This task
is pure machinery; the reminder editing UI and tap-to-navigate land in 015.
