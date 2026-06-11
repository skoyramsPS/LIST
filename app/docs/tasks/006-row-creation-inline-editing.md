# 006: Row creation + inline editing

**Type:** AFK
**Status:** pending
**Blocked by:** 005
**Harness stages exercised:** test / grep-gates

## What to build

Rows become real: inside the sheet view the user adds rows and edits simple
cells inline (master PRD §12).

- **Bottom input bar** creates title-only rows; a `+` button creates an empty
  row.
- **Inline editing** for simple cells: Title (single-line, truncates while
  viewing, expands while editing), Checkbox toggle. (Number/Currency inline
  editing arrives with column management in 010.)
- `ListTextField` (wrapping Material `TextField` for IME/a11y, owning all
  decoration) and `ListCheckbox` land here.
- Title is required; search later checks the full title, so store it untruncated.
- Cell writes flow UI → provider → `SheetRepository` → typed slot.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Widget test: type in the bottom bar → row appears; tap title → edit inline → persisted via repository
- [ ] Checkbox toggle round-trips to `value_integer` 0/1
- [ ] Title truncates in view mode and expands in edit mode
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/`
- No raw colour hex or spacing literals in `lib/features/`
- No banned Material widgets — raw `TextField` only via `ListTextField`; `Checkbox` only via `ListCheckbox`

## Notes

The empty-row auto-delete rule is deliberately **not** in this slice (009) —
but design the row-creation path so an empty row is observable state, not a
special case. Keyboard dismissal must never delete or commit anything
destructive (master PRD §12).
