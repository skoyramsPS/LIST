# TheLIST — Product Requirements (the "What")

**Status:** active product spec
**Platform:** Flutter mobile (iOS + Android)
**Mode:** Offline-first, local-first; true E2EE multi-device sync
**Version:** v1.0 (greenfield)

> **Scope of this document.** This is the *product* spec — what to build and why,
> from the user's point of view. It is **mortal**: when the product is built it is
> archived to `/_human/`. The *how* (database, sync, encryption, UI system) lives
> in the **immortal** `/docs/architecture/*` docs, which are kept honest by
> `make verify`. Build rules live in `/AGENTS.md`. When a product rule below has a
> binding implementation, this doc points to the architecture doc rather than
> restating it.

---

## 1. Product summary

TheLIST is a simple, fast, private, offline-first app for creating flexible
**Sheets** — lightly customizable lists/tables. Users add rows, reorder them by
hand, edit them quickly, and attach reminders when needed. One generalized
list-and-reminder system spans a zero-bloat grocery list, a manual
subscription/free-trial tracker, and a lightweight habit/goal tracker.

**Core sentence:** *Users create offline Sheets, add rows, manually reorder them,
and attach reminders when needed* — and their data syncs privately across their
own devices, end-to-end encrypted, when they choose to sign in.

## 2. Why this project exists (the thesis)

This is a portfolio-grade demonstration of a **local-first app with a real,
offline-capable, end-to-end-encrypted multi-device sync engine**. A local-only
list app would only prove basic CRUD. The value here is correct distributed
state: conflict resolution, convergence across offline devices, and a genuine
E2EE trust model where only the user's devices can read the data. The sync engine
is a first-class deliverable, not a deferred phase. (See `architecture/sync.md`.)

## 3. Product principles

- **Simplicity first.** It feels like a list app, not a spreadsheet/finance/
  calendar/dashboard. Advanced capability exists only when it directly serves the
  core list/reminder workflow.
- **Offline-first, local-first.** Fully usable offline with no account. Sync is
  opt-in, switched on by signing in; until then everything is local-only.
- **User-controlled data.** Users enter information manually. The app never
  scrapes, links banks, or auto-detects subscriptions. It does not assume reality;
  it requires user confirmation.
- **Manual order matters.** Drag-and-drop order is core. Rows stay exactly where
  the user puts them. (See ordering in `architecture/data_model.md`.)
- **Shared modules, not feature islands.** Reminders, notes, links, formulas,
  dates, and bottom-sheet editors are reused across templates.
- **Private by construction.** When synced, data is end-to-end encrypted; the
  server cannot read it. (See `architecture/sync.md`.)

## 4. Goals & non-goals

**Goals:** multiple Sheets; Sheets from protected built-in templates; manual row
reorder; reminders on rows; full offline use; track lists, groceries,
subscriptions, one-time goals, habits; light column customization; custom
templates from existing Sheets; opt-in E2EE multi-device sync with account.

**Non-goals (MVP):** bank linking / auto subscription detection; Sheet sharing
*between users*; full calendar/charts/dashboards/analytics; bulk actions;
advanced spreadsheet formulas; full task-management; AI suggestions; store
layouts/coupons/recipes; CSV import/export; a Trash bin; cross-device undo.

## 5. App structure

Three bottom-navigation tabs: **Today**, **Sheets**, **Settings**.

## 6. Today tab

A lightweight command center for items needing attention — **not** an analytical
dashboard. Shows: due reminders; overdue items (e.g. unresolved expired trials);
habit check-ins scheduled for today; upcoming reminders. Does **not** show charts,
analytics, AI recommendations, or full calendar views.

All of this is **derived at read time** across all sheets, never stored as state.
(Implementation: the attention pipeline in `architecture/data_model.md` §6.)

## 7. Sheets tab

Create, view, pin, reorder, and open Sheets. Compact cards show name, icon, a
summary line, and pin state (e.g. "Grocery · 12 items · $48.20 estimated";
"Subscriptions · 8 active · next renewal in 3 days"). Pinned first, then
unpinned; within each group, strictly manual order. Optional single category
(Shopping, Money, Health, Work, Personal, Custom) — no folders, no nesting, not
grouped by category by default.

## 8. Settings tab

Theme (Light/Dark/System), notification-permission status, default currency
(per-Sheet override; no conversion in MVP), manage templates, and **account &
sync** (sign in/out, show recovery phrase, device-to-device key transfer QR).
Excluded: analytics, backup-to-file.

## 9. Onboarding

Max 3 screens: offline Sheets, reminders, private sync when you want it. No
account wall — the user can use the app fully without signing in. Notification
permission: first launch shows an in-app explanation → "Enable Notifications" →
OS prompt; if denied and later needed, ask again with a non-blocking warning.
User lands on the Sheets tab with template suggestions; no pre-loaded demo sheets.

## 10. Account & sync (user-facing behavior)

Sync is **opt-in**. Until the user signs in, the app is purely local. Signing in
turns on private, end-to-end-encrypted sync across the user's own devices. The
user is shown a one-time 24-word recovery phrase ("write it down — it cannot be
reset"), and can move their key to another device by scanning a QR from their
first device. The full key model, the four sign-in/merge lifecycle phases, and the
"two histories merge" behavior are specified in `architecture/sync.md`.

## 11. Templates

Six templates, frozen for MVP: **Simple List · Grocery · Subscription · Goals ·
Habit Grid · Custom**. Built-ins are protected (cannot be edited directly, can be
duplicated). Custom templates are created by saving an existing Sheet — structure
only, or structure + entries. Templates may define default reminder presets.
(Representation and instantiation: `architecture/data_model.md` §7.)

## 12. Rows — model, editing, creation, deletion

- Every normal row has a drag handle and a required **Title** (single-line;
  truncate while viewing, expand while editing; search checks the full title).
- **Empty-row rule:** a row with empty title and no other data is auto-deleted
  **when the user navigates away from the Sheet or backgrounds the app** — never
  on keyboard-focus loss. If the title is empty but other data exists, show a
  title-required warning. *Keyboard dismissal never triggers destructive actions.*
- **Editing (no full detail screens):** tap a simple cell to edit inline
  (Checkbox, Title, Quantity, Price); tap a complex cell for a cell-level bottom
  sheet (Date, Reminder, Notes, Formula, Dropdown); long-press a row for a minimal
  menu (Duplicate, Copy title, Delete); drag the handle to reorder.
- **Creation:** a bottom input bar (title-only rows) or a `+` button (empty row).
  Pasted multi-line text inserts rows below the selected row, in order.
- **Deletion:** soft-delete snackbar ("Milk deleted · Undo"); final when the
  snackbar expires; no Trash. Sheet deletion requires confirmation. (Sync &
  tombstone semantics: `architecture/sync.md` §6.)
- **Duplication:** row-duplicate copies fields and reminder *rules* (not active
  scheduled notifications); sheet-duplicate copies columns, rows, manual order,
  settings; copied active reminders default to **Draft/Paused** and must be
  re-enabled.

## 13. Search & order

Manual reorder only — no sorting/filtering/grouping in MVP. Search narrows
visible rows by title and visible text fields without altering saved manual order.

## 14. Columns

Types: Checkbox, Text, Number, Currency, Formula, Date, Notes, Reminder, Link,
Dropdown/status. Editing: rename, hide/show, reorder, add, remove, set defaults,
basic formulas. No conditional logic, validation rules, or advanced functions.
**A column's type is immutable once any of its cells holds data** — to change
type, add a new column and migrate by hand. (Rationale:
`architecture/data_model.md` §3a.)

## 15. Formulas

Simple builder: `Output = Field/Value Operator Field/Value` with `+ - × ÷`
(operator chaining within one expression allowed). Operands are input columns or
constants only — **never** other formula columns. Values update live; per-column
manual override shows an edited indicator and can be recalculated. Sheet-level
totals (e.g. Grocery "Estimated total") are aggregates, not cell formulas.
(`architecture/data_model.md` §4.)

## 16. Reminders, notes, links

- **Reminders:** date-linked or standalone. Recurrence None/Daily/Weekly/Monthly/
  Yearly with interval (so quarterly = monthly × 3) and multiple alerts (e.g. 7
  days before, 1 day before). Standard OS notifications only — no snooze, action
  buttons, or urgency modes. Tapping opens the Sheet, scrolls to the row, pulses
  it. (Scheduler & recurrence grammar: `architecture/sync.md` §8.)
- **Notes:** plain text, cell-level bottom sheet. No formatting/attachments.
- **Links:** tap → bottom sheet (Open, Edit, Copy). Stored locally, opened in the
  device browser. Basic validation only.

## 17. Currency

Per-Sheet currency (app default with override). Currency *code* lives on the
Column. No conversion, tax, or coupons in MVP.

## 18. The templates in detail

- **Simple List:** basic checklist; checked rows stay visible; manual reorder;
  title-only quick add.
- **Grocery:** 4-column zero-bloat list; per-row `Total = Quantity × Unit Price`;
  **Estimated total** sums all rows (checked + unchecked) as a sheet aggregate;
  checked items auto-hide by default (temporarily revealable); duplicating resets
  checkboxes to unchecked.
- **Subscription:** manual subscription/free-trial tracker. Statuses Trial,
  Active, Paused, Canceled, Expired (only Trial and Active send reminders); cycles
  Weekly/Monthly/Yearly (× interval). **Trial Limbo (strict manual):** trials never
  auto-convert or auto-expire; at end date the row enters an unignorable "Needs
  Action / Overdue" state, pinned to Today until the user picks *Converted to
  Active* / *Canceled* / *Expired*. Renewal dates never auto-advance — the user
  taps "Mark renewed". (Trial Limbo is derived, never a stored reminder:
  `architecture/data_model.md` §6.)
- **Goals:** one-time goal tracker — Current, Target, Progress %, Deadline,
  Reminder. No recurring goals or milestones in MVP.
- **Habit Grid:** sticky habit-name column; date cells scroll horizontally; opens
  on the current week. Tap toggles Done/Empty; long-press → Partial, Skipped,
  Missed, Note. Future cells may only be marked Skipped; past cells editable
  forever. Tracking-rule changes (e.g. Daily → 3×/week) prompt "apply to past vs
  forward only". Grace period defaults to 24h; count-based tracking supported (e.g.
  5/8 cups); auto-missed is derived, manual-missed is stored. (Effective-dated
  rules and the two-clock civil-date model: `architecture/data_model.md` and
  `architecture/sync.md`.)

## 19. Import & copy

Paste-to-create rows (plain text); tab-separated pastes map to visible columns;
copy Title only. No CSV import/export.

## 20. Data, permissions, loss

Local data lives in a plaintext Drift/SQLite database protected by the OS app
sandbox (not SQLCipher); synced data is end-to-end encrypted in transit and at
rest on the server. The app transparently states that *un-synced* local data is
lost if the user uninstalls or loses the device before signing in. Notification
permission is required for reminders; internet is required only for opening
external links and for sync.

## 21. Acceptance

Strict adherence to offline-first, local-first, manual-order, and privacy
principles. Every feature ships test-first; "done" means `make verify` is green
(see `/AGENTS.md`).
