# 005: Sheets tab + Simple List template

**Type:** AFK
**Status:** pending
**Blocked by:** 002, 004
**Harness stages exercised:** test / grep-gates

## What to build

The first full UI→State→Repository→DB slice: from the Sheets tab the user opens
the template picker, instantiates a **Simple List** sheet, sees it as a card in
the Sheets list, and opens it to an (empty) sheet view.

- Built-in templates are **declarative Dart code** (a `SheetFactory`), not DB
  rows (`data_model.md` §7). Implement the factory mechanism and the Simple
  List definition only — the other built-ins land with their feature slices
  (013, 016, 018).
- Sheet cards (`ListCard`) show name, icon, and a summary line; ordered
  `is_pinned DESC, position, id` (pin/reorder interactions land in 007).
- Template picker is a full-screen view per `ux_spec.md`; instantiated sheets
  carry `template_kind` to route the UI renderer.
- Sheet view renders the sheet's columns/rows from the repository (empty for
  now; row creation is 006).

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Widget test: create a Simple List from the picker → card appears in the Sheets tab → tap opens the sheet view
- [ ] `SheetFactory` instantiation writes sheet + columns through `SheetRepository` in one transaction
- [ ] Built-in templates cannot be edited (no edit affordance; protection per master PRD §11)
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/` — UI talks to providers, providers to `SheetRepository`
- No raw colour hex or spacing literals in `lib/features/`
- No banned Material visual widgets in `lib/features/` (`ListCard`, not `Card`/`ListTile`)

## Notes

`ListCard` and `ListButton` likely first land here — they belong in
`lib/ui/components/` and `design_system.md`'s component list should be kept
honest. Category (optional, single) can be set at creation; no folders, no
grouping by category (master PRD §7).
