# 012: Formula columns

**Type:** AFK
**Status:** pending
**Blocked by:** 010
**Harness stages exercised:** test / grep-gates

## What to build

The formula system (master PRD §15; `data_model.md` §4):

- **Builder bottom sheet:** `Output = Field/Value Operator Field/Value` with
  `+ − × ÷`, operator chaining within one expression. Operands are **input
  columns or constants only — never another formula column** (the builder must
  not offer formula columns as operands).
- **Materialized recompute:** results write into the formula cell's
  `value_number` **inside the repository transaction** that changed an operand
  — never reactively in the UI — so values are correct with no UI mounted.
- **Manual override:** `is_overridden = 1` pins a value, shows an edited
  indicator, and is skipped on recompute until the user taps "Recalculate".
- Formula definition serialized into the Column's `config`.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Repository test: editing an operand cell recomputes dependent formula cells in the **same transaction**
- [ ] Test: a formula column is never offered (and is rejected by the repository) as an operand
- [ ] Test: overridden cell survives recompute; "Recalculate" clears the override and re-materializes
- [ ] Widget test: build a formula through the bottom sheet, values update live in the sheet view
- [ ] Division by zero / null operands produce a defined, tested result (empty cell, not a crash)
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/`
- No `DateTime.now()` in `lib/repositories/`
- No raw colour hex or spacing literals in `lib/features/`

## Notes

The flat one-level fan-out (no inter-formula refs) means no dependency graph,
no cycle detection — keep it that way. Sheet-level aggregates are a *separate*
mechanism (SQL `SUM` behind a provider) and land with Grocery in 013.
