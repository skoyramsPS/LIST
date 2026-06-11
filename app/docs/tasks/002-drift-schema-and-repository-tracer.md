# 002: Drift schema + gen_schema wiring + repository tracer

**Type:** AFK
**Status:** pending
**Blocked by:** None — can start immediately
**Harness stages exercised:** schema-fresh / test / analyze

## What to build

The first vertical slice through the data layer: the five `STRICT` Drift tables
(`sheets`, `columns`, `rows`, `cells`, `reminders`) in `lib/data/`, each carrying
the sync contract columns (`id` UUIDv4 TEXT PK, `updated_at`, `deleted_at`,
`sync_version`, `device_id`; reminders additionally `field_timestamps`), plus
`AppDatabase` — **and behaviour to prove it**: a `SheetRepository` in
`lib/repositories/` that can create a sheet, add a column, add a row, write a
cell value into the correct typed slot, and read the whole thing back.

Not schema-only: the repository round-trip is the tracer bullet.

Schema rules (per `data_model.md` §1–§3, §8):
- Every table `STRICT`.
- `cells` keyed by `(row_id, column_id)` with
  `UNIQUE(row_id, column_id) WHERE deleted_at IS NULL` and a `CHECK` that at
  most one of `value_text` / `value_number` / `value_integer` /
  `value_datetime` is populated.
- Type authority on the Column (`data_type`); typed-slot mapping per
  `data_model.md` §3.
- `position TEXT` on sheets and rows (fractional index; behaviour lands in 007).

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] `SheetRepository.createSheet()` → add column → add row → write cell → read back round-trips under test
- [ ] A test proves `STRICT` + the single-slot `CHECK` reject a wrongly-typed write
- [ ] All `id`s are locally generated UUIDv4 strings; no autoincrement anywhere
- [ ] `_dumpSchema()` in `tool/gen_schema.dart` introspects the real `AppDatabase` DDL; `dart run tool/gen_schema.dart` regenerates the `<!-- DRIFT-SCHEMA -->` fence in `data_model.md` **in this same commit**
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No `DateTime.now()` in `lib/repositories/` — timestamps come from an injected `Clock`
- No Drift import outside `lib/repositories/` and `lib/data/`
- No Supabase import anywhere in this task

## Harness prerequisites triggered (if any)

Master PRD **§22b** — `gen_schema.dart` must be wired to the real Drift schema
in the same commit as the first Drift table. The schema-fresh stage fails
otherwise. Do not split the wiring into a follow-up.

## Notes

Repositories are per **aggregate**, not per table (companion PRD §6):
`SheetRepository` owns sheets + columns + rows + cells. Do not create a
`CellRepository`. Reminders get their own repository later (014). Inject
`Clock` from day one — every `updated_at` stamp flows through it.
