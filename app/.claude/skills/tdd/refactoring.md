# Refactor Candidates — TheLIST

After a TDD cycle reaches GREEN, look for these opportunities. Always run
`dart run tool/verify.dart` after each refactor step — never refactor while RED.

## General candidates

- **Duplication** → extract a function, class, or provider
- **Long methods** → break into private helpers (keep tests on the public interface, not the helpers)
- **Shallow modules** → combine or deepen (see [deep-modules.md](deep-modules.md))
- **Feature envy** → move logic to where the data lives (e.g. merge logic belongs in the sync engine, not in the repository)
- **Primitive obsession** → introduce value objects (e.g. a `FractionalPosition` type rather than raw `String`)
- **Existing code** the new code reveals as problematic

## Project-specific candidates to watch for

- **`DateTime.now()` in the engine** — if you see one added during implementation, refactor to the injected `Clock` immediately. The grep gate will catch it, but fix it rather than adding a `// gate-ok` marker unless there is a genuine, reviewed reason.
- **Raw hex or spacing literals in `lib/features/`** — replace with `AppTokens.color.*` / `AppTokens.spacing.*` / `AppTokens.radius.*`.
- **Material visual widget in `lib/features/`** — replace with the corresponding `List*` component (see `docs/architecture/design_system.md`).
- **Drift import leaking into `lib/state/` or `lib/features/`** — move the Drift dependency down into `lib/repositories/` where it belongs.
- **Supabase reference outside `lib/sync/`** — move it in.
- **A new `lib/...` path referenced in an architecture doc but not yet existing on disk** — the doc-honesty gate will catch it; create the file or update the doc in the same commit.

## What NOT to refactor

- Don't refactor the `_human/decision_log.md` rationale — those are locked decisions.
- Don't introduce a new layer shortcut because a refactor "feels cleaner" — the layering rules in AGENTS.md §2 are enforced by the grep gates and are not negotiable.
