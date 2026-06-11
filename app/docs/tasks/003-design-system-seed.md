# 003: Design-system seed — fonts, AppTokens, ListTouchable

**Type:** AFK
**Status:** pending
**Blocked by:** None — can start immediately
**Harness stages exercised:** grep-gates / test / format

## What to build

The foundation every screen sits on, as one slice with a rendered, tested
widget at the end:

1. **Font assets (§22a):** download the OFL-licensed Plus Jakarta Sans
   `PlusJakartaSans-Medium.ttf` (weight 500) and `PlusJakartaSans-SemiBold.ttf`
   (weight 600) into `assets/fonts/` (currently only `.gitkeep`). Add a
   `FontLoader`-based `flutter_test` bootstrap so widget tests resolve the
   family without depending on the host filesystem.
2. **`AppTokens`** in `lib/ui/tokens/app_tokens.dart`: semantic colours
   (`surface`, `surfaceMuted`, `accent`, `accentMuted`, `success`, `warning`,
   `danger`, per-category pastel accents), `borderSoft`, spacing scale, radii,
   flat elevation, and the text theme (Plus Jakarta Sans only; Medium 500 body,
   SemiBold 600 headers). Light and Dark variants.
3. **`ListTouchable`** in `lib/ui/components/`: the universal tap wrapper with
   the Pulse (~0.98× scale + soft tween toward `surfaceMuted` over ~150 ms,
   ease-out — never an ink ripple).

The tracer bullet: a widget test renders `ListTouchable` containing text in the
custom font, taps it, and asserts the Pulse animation runs and the callback fires.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Both `.ttf` files exist in `assets/fonts/` and `flutter test` renders the family via the `FontLoader` bootstrap
- [ ] `AppTokens` exposes light + dark token sets; no other file defines a colour or spacing value
- [ ] `ListTouchable` pulses on tap (scale + background tween, no ripple) under widget test
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No raw colour hex or spacing literals in `lib/features/` (tokens themselves live in `lib/ui/tokens/` where literals are the point)
- No banned Material visual widgets in `lib/features/`

## Harness prerequisites triggered (if any)

Master PRD **§22a** — the font assets land here, in the same commit as the
first `List*` component (`ListTouchable`). This task **blocks the first UI
task (004)**.

## Notes

Per user decision: fetching the fonts is AFK — Plus Jakarta Sans is OFL-licensed
(source: github.com/tokotype/PlusJakartaSans or Google Fonts). Verify weights
500/600 specifically. The remaining `List*` components (`ListCard`,
`ListButton`, `ListCheckbox`, `ListTextField`, bottom-sheet shell, `ListChip`)
land with the features that first need them — do not build them speculatively
here. See `design_system.md` for the denylist and Pulse spec.
