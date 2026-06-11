# 004: App shell — three tabs, go_router, Riverpod activation

**Type:** AFK
**Status:** pending
**Blocked by:** 003
**Harness stages exercised:** analyze / test / grep-gates

## What to build

The navigable app skeleton: a `Scaffold`-based shell with a bespoke bottom
navigation bar (Today / Sheets / Settings — built from `List*` components, not
Material `BottomNavigationBar`), `go_router` routes for the three tabs,
`ProviderScope` at the root, and the first Riverpod provider (e.g. the selected-
tab or router provider) in `lib/state/`.

Bottom sheets are local UI state, never routes (companion PRD §7); only tabs and
full-screen views are routes. Each tab shows its empty state per `ux_spec.md`.

Tracer bullet: app boots, all three tabs render their empty states, tab
switching works under widget test.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Widget test navigates across all three tabs and asserts each empty state renders
- [ ] `go_router` defines routes for tabs and full-screen views only — no bottom-sheet routes
- [ ] The `custom_lint:` activation block exists in `analysis_options.yaml` **in this same commit** and `dart analyze` runs `riverpod_lint` clean
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No raw colour hex or spacing literals in `lib/features/` — everything through `AppTokens`
- No banned Material visual widgets in `lib/features/` (`Scaffold` and the bottom-sheet host are chassis-allowlisted)
- No Drift import under `lib/features/` or `lib/state/`

## Harness prerequisites triggered (if any)

Master PRD **§22c** — the first Riverpod provider lands here, so the
`custom_lint:` / `riverpod_lint` activation must land in the same commit.

## Notes

Keep the shell dumb: no data wiring yet (Sheets tab content arrives in 005,
Today in 017, Settings in 021). The bespoke header replaces `AppBar` per the
denylist in `design_system.md` §1.
