# Data Model — EAV, UUIDs, STRICT tables, and Views

This document explains **why** the local database is shaped the way it is. The
**facts** (the actual table DDL) are generated from the Drift schema into the
fenced region below and must not be hand-edited. Hand-write only rationale.

Source code: `lib/data/` (tables, DAOs, Views), `lib/repositories/` (the only
layer that touches Drift).

---

## 1. Why EAV with first-class cells

The product lets users build arbitrary lightly-typed lists ("Sheets") with
custom columns. A fixed relational schema can't express user-defined columns, so
storage is **Entity–Attribute–Value**:

```
Sheet  ──<  Column (the schema definition for that sheet)
Sheet  ──<  Row
Row × Column  →  Cell   (keyed by (row_id, column_id); exactly one scalar value)
```

A **Cell holds exactly one scalar** and is therefore a degenerate
**LWW-Register**: merging two versions is simply "higher timestamp wins", with no
merge function to write. This single fact is what makes the sync engine simple
(see `sync.md`). The Cell is simultaneously the unit of **storage**, the unit of
**conflict resolution**, and the unit of **encryption** — one boundary, three
jobs.

One concern is *not* scalar and so is pulled into its own first-class table
rather than crammed into cells:

- **Reminders** — recurrence + multiple alerts + status (multi-field).

## 2. Why UUIDv4 primary keys (not autoincrement)

Rows are created offline on multiple devices with no coordinator. An
autoincrementing integer would collide across devices. **Every `id` is a
locally-generated UUIDv4 string.** Two devices never generate the same key, so
offline-created rows merge into the cloud and into each other with zero identity
collisions. The only possible collision is *semantic* (two sheets both named
"Grocery"), which no app can or should auto-resolve.

UUID foreign keys also give us **schema privacy for free**: the server sees a
graph of opaque UUIDs with timestamps and never learns what a column *means*,
because column names live inside the encrypted payload (see `sync.md`).

## 3. Why typed slots + `STRICT`

Each cell stores its scalar in exactly one native slot — `value_text`,
`value_number` (REAL), `value_integer`, `value_datetime` (epoch ms) — chosen by
the owning Column's `data_type`. Native typed storage preserves SQLite's sort and
index power for the future (users will want to sort by Price/Total) and gives
DB-level integrity.

Plain SQLite uses type *affinity*, not strict typing, so a `REAL` column will
silently accept `"banana"`. **Every table is declared `STRICT`**, and cells
additionally carry a `CHECK` that at most one value slot is populated. Without
`STRICT` the typed-slot guarantee is fiction.

**Type authority lives on the Column** (`data_type` is the single source of
truth). Logical → storage mapping:

| Column type | Storage slot |
| --- | --- |
| Checkbox | `value_integer` (0/1) |
| Text / Notes / Link | `value_text` |
| Number | `value_number` |
| Currency | `value_number` (currency **code** on the Column, not the cell) |
| Date | `value_datetime` (epoch ms) |
| Dropdown/status | `value_text` (option set on the Column) |
| Formula | `value_number` — engine-owned materialized cache + `is_overridden` |

### 3a. Column types are immutable once populated

There is **no type-coercion engine**. The moment any cell under a `column_id`
holds a non-null value, that Column's `data_type` becomes immutable; the type
dropdown in column settings is disabled with an explanatory affordance. To
"change type", the user adds a new column, retypes, and hides/deletes the old one
— migration stays in the user's hands ("user-controlled data"). If every cell in
a column is later cleared back to null, the type unlocks again (the lock tracks
*live data*, not history). This dissolves an entire class of lossy-conversion and
bulk-rewrite-sync problems.

## 4. Formulas (materialized, flat, no inter-formula refs)

A formula's operands are **input columns or constants only — never another
formula column**. This collapses the dependency graph to a flat one-level
fan-out: no cycles, no transitive recompute, no cycle detection. Operator
chaining within one expression (e.g. `(Current / Target) × 100`) is fine.

The result is **materialized** into the formula cell's `value_number` so
`ORDER BY` works and a manual override has a slot (`is_overridden = 1` pins a
value; the engine skips it on recompute until the user hits "Recalculate").
**Recompute runs inside the repository transaction** that triggered it — in the
same transaction as the cell write — never reactively in the UI, so values are
correct even with no UI mounted (background sync, pull from another device).

**Sheet-level aggregates** (Grocery "Estimated total", sheet-card summaries) are
a *separate* mechanism: SQL aggregates (`SUM(value_number)`) behind a reactive
provider — **not** cell formulas.

## 5. Ordering (fractional indexing with jitter)

Manual drag-and-drop order is a core product value. Order is stored as a
**fractional index** in a `position TEXT` column, with a **random jitter
suffix** (Figma-style), *not* LexoRank buckets (buckets need a central
coordinator; offline/multi-device has none). The jitter makes two offline
devices generating an identical key for the same gap effectively impossible.

- A reorder rewrites only the **moved** row's `position`.
- Deterministic tiebreaker: order by `(position, id)` — identical keys degrade to
  a stable total order, never an error.
- `position` is one field → concurrent reorder is plain LWW (harmless).
- **No rebalancing in MVP** (key-length growth is negligible at list scale;
  rebalancing would cause a sync storm). Documented as an optional later op.
- Sheets reuse the identical mechanism plus an `is_pinned` flag:
  `ORDER BY is_pinned DESC, position ASC, id ASC`.

## 6. The Today-tab attention pipeline (SQLite Views, derived at read time)

The Today tab surfaces everything "needing attention" across *all* sheets:
due/upcoming reminders, overdue waiting-on items, and subscriptions in **Trial
Limbo**. None of this is stored as state — storing it would mean fake reminders
and staleness bugs. Instead it is **derived at read time**, and the heavy lifting
stays inside SQLite (never hydrate thousands of EAV cells into Dart to filter
them).

**Principle: store the facts, compute the clock.** Facts come from indexed tables
and Views (always consistent, nothing to invalidate); the time comparison is
bound fresh (`:now`) on every read, so midnight rollover needs no cache
invalidation.

Three native sources feed one `List<AttentionItem>` behind one Riverpod provider:

1. **Reminders** — first-class table:
   `SELECT * FROM reminders WHERE target_date <= :now AND is_enabled = 1`.
2. **Waiting-On** — an **EAV-pivot View** (`v_waiting_on`) that pivots waiting-on
   cells back into relational columns, then:
   `WHERE status = 'waiting' AND due_date < :now`.
3. **Trial Limbo** — an **EAV-pivot View** (`v_subscriptions`) that pivots
   subscription cells back into relational columns, then:
   `WHERE status = 'trial' AND end_date < :now`.

Both pivots key off a stable **`semantic_role`** on each column (e.g.
`sub_status`, `sub_end_date`, `sub_cost` for subscriptions; `wait_status`,
`wait_due_date`, `wait_from` for waiting-on), assigned at template instantiation
— **not** the user-facing column name, which is cosmetic and renameable. The role
is the contract.

Overdue Waiting-On and Trial Limbo are therefore just `kind`s of `AttentionItem`,
derived by predicate, never stored rows. Each item links back to its sheet+row
for tap-to-navigate-and-pulse. (Trial Limbo additionally pins itself to Today and
demands a resolution; overdue Waiting-On is a normal, non-pinning item.)

## 7. Templates

Built-in templates (Simple List, Grocery, Subscription, Goals, Waiting On,
Custom) are **declarative Dart code**, not database rows — so they are
automatically protected, version with app releases, and never sync. Instantiating
one runs a `SheetFactory`.

**Custom templates** are ordinary Sheets flagged `is_template = 1`, so they
inherit the entire sync/encryption/ordering pipeline for free. Instantiation is a
single **atomic deep-copy transaction** that carries a `source_column_id →
new_column_id` map (so copied cells point at the new columns, not the
template's), assigns **fresh `position` keys**, and brings any copied reminders in
as `is_enabled = 0` (Draft/Paused). Every instantiated sheet carries a
`template_kind` (`generic`, `grocery`, `subscription`, `waiting_on`, …) that routes the
UI to the correct specialized renderer.

## 8. The sync contract (every synced table carries it)

Single-scalar entities (cells, sheets, columns, rows) use `updated_at` as their
field-timestamp. The multi-field entity (reminders) additionally carries
a `field_timestamps` JSON map for per-field LWW. Tombstones are `deleted_at` and
are retained forever (a hard-deleted tombstone would let a stale device resurrect
the row). See `sync.md` for the full merge and deletion semantics.

---

## Generated schema (DO NOT hand-edit inside the fence)

The block below is regenerated from the live Drift schema by the pre-verify
script. Hand-written rationale belongs *above* this line, never inside.

<!-- DRIFT-SCHEMA:START -->
```sql
-- No Drift schema defined yet (lib/data is empty).
-- This block is generated by tool/gen_schema.dart and must not be
-- hand-edited. It will fill in automatically once the Drift schema
-- exists and _dumpSchema() is wired to it.
```
<!-- DRIFT-SCHEMA:END -->

> Reference blueprint (illustrative — the generated block above is authoritative
> once the schema exists): tables `sheets`, `columns`, `rows`, `cells`,
> `reminders`, each `STRICT`, each carrying
> the sync contract. `cells` has `UNIQUE(row_id, column_id) WHERE deleted_at IS
> NULL` and the single-slot `CHECK`.
