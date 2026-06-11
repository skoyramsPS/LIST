# 022: Onboarding

**Type:** AFK
**Status:** pending
**Blocked by:** 004
**Harness stages exercised:** test

## What to build

The first-launch experience (master PRD §9; companion §7 — one screen, ≤3 pages):

- Max 3 pages: offline Sheets · reminders · private sync when you want it.
  Skippable; **no account wall** — the app is fully usable without signing in.
- Notification permission: in-app explanation page → "Enable Notifications" →
  OS prompt (never the raw OS prompt cold).
- Lands on the **Sheets tab with template suggestions**; no pre-loaded demo
  sheets.
- Shows only on first launch (persisted seen-flag).

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Widget test: first launch shows onboarding; completing or skipping lands on the Sheets tab with template suggestions and no demo data
- [ ] Second launch skips onboarding entirely
- [ ] Declining the permission explainer proceeds without the OS prompt and without blocking anything
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No raw colour hex or spacing literals in `lib/features/`
- No banned Material visual widgets in `lib/features/`

## Notes

Reuses the permission service from 015/021 if already landed; otherwise
introduce the injected permission abstraction here and they reuse it. Keep the
pages static `List*` compositions — no animation framework.
