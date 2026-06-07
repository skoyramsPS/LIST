# Deep Modules — TheLIST

From "A Philosophy of Software Design" (Ousterhout). This principle drives the
architecture of every major subsystem in this project.

**Deep module** = small interface + lots of implementation

```
┌─────────────────────┐
│   Small Interface   │  ← Few methods, simple params
├─────────────────────┤
│                     │
│  Deep Implementation│  ← Complex logic hidden
│                     │
└─────────────────────┘
```

**Shallow module** = large interface + little implementation (avoid)

```
┌────────────────────────────────┐
│       Large Interface          │  ← Many methods, complex params
├────────────────────────────────┤
│  Thin Implementation           │  ← Just passes through
└────────────────────────────────┘
```

## Examples in this project

**Deep (aim for this):**

- `SyncEngine.sync()` — one method call triggers encrypt → push → pull →
  decrypt → merge → write. The caller knows nothing about the internal steps.
- `ReminderScheduler.replenish()` — one call triggers the nearest-N
  computation, diff against scheduled notifications, cancel/add. Caller never
  sees the iOS 64-cap budget logic.
- `SheetRepository.rowsForSheet(sheetId)` — returns a reactive stream. The
  caller doesn't know it's backed by a Drift `SELECT` with a `WHERE` clause
  and a position-based `ORDER BY`.

**Shallow (avoid):**

- A `SyncStepA`, `SyncStepB`, `SyncStepC` that each do one small thing and
  require callers to call them in the right order.
- A `CellMapper` that just calls `cell.toDrift()` with no logic inside.
- A `RepositoryHelper` that re-exports two Drift methods unchanged.

## When designing interfaces, ask

- Can I reduce the number of methods?
- Can I simplify the parameters?
- Can I hide more complexity inside?
- If I deleted this module, would complexity vanish (shallow) or reappear
  across all callers (deep — worth keeping)?
