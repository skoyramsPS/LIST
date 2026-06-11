# 019: Duplication + custom templates

**Type:** AFK
**Status:** pending
**Blocked by:** 013, 015
**Harness stages exercised:** test / grep-gates

## What to build

Everything that copies structure (master PRD §11, §12; `data_model.md` §7):

- **Row duplicate** (joins the long-press menu from 008): copies fields and
  reminder *rules* — never active scheduled notifications; the copy's reminder
  is `is_enabled = 0` (Draft/Paused).
- **Sheet duplicate:** copies columns, rows, manual order, settings; Grocery
  duplicates reset checkboxes to unchecked; copied active reminders default to
  Draft/Paused.
- **Save-as-template:** an ordinary Sheet flagged `is_template = 1` (structure
  only, or structure + entries) — inheriting sync/encryption/ordering for free.
- **Atomic deep-copy transaction** powering all of the above: carries a
  `source_column_id → new_column_id` map (copied cells point at the new
  columns), assigns fresh `position` keys, fresh UUIDs throughout.
- **Template picker integration** (custom templates appear alongside built-ins;
  built-ins are duplicable but not editable) and the **Manage templates**
  screen (rename/delete custom templates) reachable from Settings.
- **Sheet settings bottom sheet** (name/icon/category/currency) with the
  destructive Sheet-Deletion morph, if not already landed in 008.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Deep-copy test: copied cells reference the **new** column ids, never the source's; all ids fresh UUIDs; one transaction (failure mid-way leaves nothing)
- [ ] Test: duplicated sheet preserves manual order with fresh position keys
- [ ] Test: Grocery duplicate resets all checkboxes; any duplicate sets copied reminders to `is_enabled = 0`
- [ ] Widget test: save a sheet as template (structure ± entries) → instantiate it from the picker → independent copy
- [ ] Built-in templates expose Duplicate but no Edit
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/` — the deep-copy lives in `SheetRepository`
- `danger` red only on the final Sheet-Deletion confirmation morph
- No raw colour hex or spacing literals in `lib/features/`

## Notes

The deep-copy is the heart — implement it once in `SheetRepository` and express
row-duplicate, sheet-duplicate, save-as-template, and instantiate-template as
parameterizations of it.
