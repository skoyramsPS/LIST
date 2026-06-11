# 018: Goals template

**Type:** AFK
**Status:** pending
**Blocked by:** 012, 015
**Harness stages exercised:** test

## What to build

The Goals built-in template (master PRD §18), composed almost entirely from
existing machinery:

- `SheetFactory` definition: Current (Number), Target (Number), Progress %
  (Formula: `(Current ÷ Target) × 100` — operator chaining within one
  expression), Deadline (Date), Reminder. `template_kind: goals`.
- One-time goals only — no recurring goals, no milestones.
- Progress renders via the standard formula cell (override/recalculate
  behaviour comes free from 012).

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Instantiating Goals yields the five columns with the Progress formula wired
- [ ] Editing Current or Target recomputes Progress in the same transaction
- [ ] Target = 0 / empty produces the defined empty-cell result from 012, not a crash
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/`
- No raw colour hex or spacing literals in `lib/features/`

## Notes

Deliberately thin — it exists to prove the template + formula + reminder
machinery composes without special-casing. If this task needs new mechanism,
that is a smell; raise it.
