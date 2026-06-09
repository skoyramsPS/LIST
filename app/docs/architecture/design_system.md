# Design System — scoped-bespoke, calm, pastel

The product's identity is **modern, stylish, simple, calm, pastel** — and every
option must feel **obvious and meaningful**. This document turns those adjectives
into enforceable rules. The vibe is not decoration here; it is a set of build
constraints the harness checks.

Source code: `lib/ui/tokens/` (`app_tokens.dart`), `lib/ui/components/` (the
`List*` library), consumed by `lib/features/`.

---

## 1. Scoped-bespoke: custom skin, Material chassis

We build a **bespoke design system for everything the user sees and touches**,
while keeping **Material as the invisible chassis** for the things Material has
correctly solved: accessibility/semantics, focus traversal, text input/IME,
minimum touch targets, navigation plumbing, `Scaffold`.

The reason: a fully primitives-only UI would force us to re-implement
accessibility from `CustomPaint`, shipping a beautiful but inaccessible app and
spending effort that belongs on the sync engine. Scoped-bespoke gets the premium,
non-Material *look and feel* where it counts and keeps solved problems solved.

### The Material denylist (grep-/lint-gated in `lib/features/`)

These **visual/decorative** Material widgets are banned in `lib/features/`. Use
the `List*` component instead.

```
Card            → ListCard
ElevatedButton  → ListButton
TextButton      → ListButton (variant)
InkWell         → ListTouchable
ListTile        → ListCard / bespoke row
Checkbox        → ListCheckbox
Switch          → ListCheckbox / bespoke toggle
FloatingActionButton → ListButton (variant)
AppBar          → bespoke header
Divider         → borderSoft on the container
TextField (raw) → ListTextField   (wraps Material TextField for IME/a11y, owns decoration)
```

**Allowed Material in features (the chassis allowlist):** `Scaffold`,
`Navigator`/`go_router` surfaces, `Semantics`, `EditableText`/`TextField`
**only via `ListTextField`**, and the bottom-sheet host. The rule is a *named
denylist*, not a blanket ban on `package:flutter/material.dart` — banning the
whole package would break the chassis and accessibility.

### The core `List*` components (~7–9 widgets)

`ListTouchable` (the universal tap wrapper — replaces InkWell everywhere),
`ListCard`, `ListButton`, `ListCheckbox`, `ListTextField`, the bottom-sheet
shell, `ListChip` / `CapsuleSegmentedControl` (status selectors). These are where
the Pulse, borderSoft, radii, and token colours live.

## 2. AppTokens is a hard boundary

`lib/ui/tokens/app_tokens.dart` is the single source of truth for every colour,
spacing, radius, elevation, and text style. Tweaking "calmness" globally must be a
one-file change.

**Grep-gated rules (fail the build):** no raw colour hex (`#...`, `0xFF...`,
`Color(0x...)`) and no raw numeric padding/radius literals anywhere in
`lib/features/`. Padding is `AppTokens.spacing.md`; a background is
`AppTokens.color.surfaceMuted`; a corner is `AppTokens.radius.xl`.

Token groups: semantic colours (`surface`, `surfaceMuted`, `accent`,
`accentMuted`, `success`, `warning`, `danger`, plus per-`category` pastel accents
for Shopping/Money/Health/Work/Personal), `borderSoft` (~10% opacity of primary
text colour), spacing scale, radii (calm = generous), elevation (calm = mostly
flat), and the text theme. Light / Dark / System per Settings.

## 3. "Calm" = concrete restraint rules

- **One accent per screen.** Only a single `accent` colour appears on screen at a
  time. No rainbow.
- **The Pulse, not the ripple.** Every tap uses `ListTouchable`'s Pulse: a slight
  scale-down (~0.98×) plus a soft background tween toward `surfaceMuted` over
  ~150ms with a custom ease-out — never an ink ripple, never a flash, never a
  scale jump. The tap-to-row navigation pulse (reminder → open sheet → scroll to
  row) is a soft background tween over ~400ms.
- **Borders over shadows.** Separation uses fine 1px `borderSoft` lines with
  generous radii, not elevation or stark colour blocks. Shadows are banned except
  for a genuinely floating bottom sheet.
- **`danger` red is reserved** exclusively for the final confirmation of a
  permanent delete — never for soft-deletes or initial swipe affordances.
- **Restrained motion.** Transitions ~150–250ms, gentle easing. No bounce, no
  springy overshoot.

## 4. "Obvious & meaningful" = prohibitions

Encoded as anti-patterns the agent must not produce:

- No naked icons without labels for primary actions.
- No hidden gesture as the *only* path to a feature — long-press menus must have a
  discoverable alternative.
- No modal stacking; prefer bottom-sheet editors over nested screens.
- Destructive actions are always confirmed or undoable (see `sync.md` §6).

## 5. Typography — Plus Jakarta Sans

The app loads and mandates **Plus Jakarta Sans**. (Inter has become the default
SaaS/tech font and reads slightly utilitarian; Satoshi leans editorial/brutalist
and has licensing constraints. Plus Jakarta Sans has geometric proportions, high
legibility, and a subtle warmth that pairs with pastels and generous radii.)

The text theme in `app_tokens.dart` maps exclusively to this family. **Weights are
restricted** — Medium 500 for body, SemiBold 600 for headers — to keep the look
clean and uncluttered.
