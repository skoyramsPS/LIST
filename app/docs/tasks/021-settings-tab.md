# 021: Settings tab

**Type:** AFK
**Status:** pending
**Blocked by:** 004
**Harness stages exercised:** test / grep-gates

## What to build

The local-only Settings surface (master PRD §8, §17):

- **Theme:** Light / Dark / System, applied live via `AppTokens`' light/dark
  sets, persisted locally.
- **Default currency:** app-wide default; per-Sheet override happens in sheet
  settings (019) — this is the default the override falls back to. No
  conversion.
- **Notification permission status:** current OS permission state with a path
  to re-request / open OS settings.
- Entry points (rows only, targets land later): Manage templates (019),
  Account & sync (027/028).

Excluded: analytics, backup-to-file.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Widget test: switching theme re-renders with the other token set and persists across restart
- [ ] Default currency persists and is what new sheets inherit
- [ ] Permission row reflects granted/denied state (faked permission service under test)
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Drift import under `lib/features/` or `lib/state/`
- No raw colour hex or spacing literals in `lib/features/`
- No banned Material visual widgets in `lib/features/`

## Notes

Settings persistence (theme, default currency) is app-config, not synced sheet
data — a simple local store is fine; do not put it in the EAV tables. The quiet
sync indicator (companion §7) joins this screen in 028.
