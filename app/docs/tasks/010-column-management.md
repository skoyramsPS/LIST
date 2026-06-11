# 010: Column management + type immutability

**Type:** AFK
**Status:** pending
**Blocked by:** 006
**Harness stages exercised:** test / grep-gates

## What to build

Light column customization (master PRD §14; `data_model.md` §3/§3a):

- **Column settings bottom sheet:** rename, hide/show, reorder, add, remove,
  set default value, pick type (Checkbox, Text, Number, Currency, Date, Notes,
  Reminder, Link, Dropdown/status; Formula arrives in 012).
- **Type immutability:** the moment any cell under a column holds a non-null
  value, the type picker is disabled with an explanatory affordance; clearing
  every cell back to null unlocks it (the lock tracks live data, not history).
- **Inline editing for Number and Currency cells** (currency *code* lives on
  the Column; per-sheet default with override per master PRD §17).
- Column `config` JSON holds type-specific settings (dropdown options, currency
  code, …).

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Repository test: type change rejected once any cell holds data; allowed again when all cells are cleared
- [ ] Widget test: rename/hide/reorder/add/remove a column through the bottom sheet, all persisted
- [ ] Number and Currency cells edit inline and store into `value_number`; currency code stored on the Column, never the cell
- [ ] Removing a column soft-deletes it and its cells through the repository (cascade semantics stay inside `SheetRepository`)
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/`
- No raw colour hex or spacing literals in `lib/features/`
- No banned Material visual widgets in `lib/features/`

## Notes

The bottom-sheet shell component likely first lands here (single sheet, morphs,
never stacks — `ux_spec.md`). Enforce the immutability rule in the repository,
not just the UI — the UI affordance is a reflection of a repository-level
refusal.
