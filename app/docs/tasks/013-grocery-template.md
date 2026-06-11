# 013: Grocery template

**Type:** AFK
**Status:** pending
**Blocked by:** 012
**Harness stages exercised:** test

## What to build

The Grocery built-in template end-to-end (master PRD §18):

- `SheetFactory` definition: 4 columns (Checkbox, Title, Quantity, Unit Price)
  plus a per-row formula `Total = Quantity × Unit Price`; `template_kind:
  grocery`.
- **Estimated total** — a sheet-level **SQL aggregate** (`SUM` over the Total
  column's `value_number`, checked + unchecked rows) behind a reactive
  provider; rendered in the sheet view and in the sheet card's summary line
  ("Grocery · 12 items · $48.20 estimated"). **Not** a cell formula.
- **Checked auto-hide:** checked rows hide by default with a temporary reveal
  affordance.
- Currency formatting from the sheet/column currency code.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Instantiating Grocery yields the 4 columns + Total formula wired
- [ ] Aggregate test: estimated total sums all rows including checked ones and updates reactively on cell edits
- [ ] Widget test: checking a row hides it; the reveal affordance shows it again without altering saved order
- [ ] Sheet card summary line shows item count + estimated total
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/` — the aggregate query lives in `SheetRepository`
- No raw colour hex or spacing literals in `lib/features/`

## Notes

The duplicate-resets-checkboxes rule (master PRD §18) is asserted in 019 where
sheet duplication lands — note it in the factory's column semantics now if it
costs nothing. Auto-hide is a view predicate, never a stored state mutation.
