# 020: Search + paste-to-create + copy

**Type:** AFK
**Status:** pending
**Blocked by:** 006, 010
**Harness stages exercised:** test

## What to build

Text in and text out (master PRD §13, §19):

- **Search:** narrows visible rows by full title (including the truncated part)
  and visible text fields; never alters saved manual order; clearing the query
  restores the full list in manual order. No sorting/filtering/grouping.
- **Paste-to-create:** pasting multi-line text into the bottom input bar
  inserts one row per line, **below the selected row, in order**; tab-separated
  pastes map fields to **visible columns** left-to-right.
- **Copy title** (already a long-press menu item from 008 — wire it to the real
  clipboard if stubbed).

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Search test: match on the non-visible (truncated) part of a title still hits; saved `position` keys untouched by searching
- [ ] Paste test: three-line paste → three rows below the selected row, in paste order, with correctly ordered fresh position keys
- [ ] TSV paste test: fields map to visible columns; hidden columns are skipped
- [ ] Search narrows across visible text fields, not just titles
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/`
- No raw colour hex or spacing literals in `lib/features/`

## Notes

Search is a view-layer predicate over provider state — no FTS table, no stored
index needed at list scale. No CSV import/export (non-goal).
