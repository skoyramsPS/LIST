# 011: Complex cell editors — Date, Notes, Link, Dropdown

**Type:** AFK
**Status:** pending
**Blocked by:** 010
**Harness stages exercised:** test / grep-gates

## What to build

Tapping a complex cell opens a **cell-level bottom sheet** (master PRD §12, §16
— no full detail screens):

- **Date:** picker writing epoch ms into `value_datetime`.
- **Notes:** plain-text editor (no formatting, no attachments) into `value_text`.
- **Link:** sheet with Open (device browser) / Edit / Copy; basic validation
  only; stored in `value_text`.
- **Dropdown/status:** option list from the Column's `config`; selection into
  `value_text`. `ListChip` / `CapsuleSegmentedControl` lands here as the
  selector component.

All writes flow through `SheetRepository` into the correct typed slot.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Widget test per editor: open sheet → edit → value persisted to the correct typed slot
- [ ] Link sheet offers Open / Edit / Copy; invalid URLs rejected with the basic validation rule
- [ ] Dropdown options are read from column `config` and editable via column settings
- [ ] Bottom sheets never stack — one sheet morphs (`ux_spec.md`)
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/`
- No raw colour hex or spacing literals in `lib/features/`
- No banned Material visual widgets in `lib/features/`

## Notes

The Reminder cell editor is deliberately **not** here — it needs the reminder
machinery and lands in 015. Opening links requires the URL-launcher capability
already declared in `pubspec.yaml`; if it is not declared, stop and raise
(raise-first rule, `AGENTS.md` §1).
