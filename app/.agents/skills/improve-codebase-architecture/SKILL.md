---
name: improve-codebase-architecture
description: Find deepening opportunities in TheLIST codebase — refactors that turn shallow modules into deep ones for better testability and AI-navigability. Use when the user wants to improve architecture, find refactoring opportunities, consolidate tightly-coupled modules, or make the codebase more testable. Always respects AGENTS.md layering rules and locked decisions.
---

# Improve Codebase Architecture — TheLIST

Surface architectural friction and propose **deepening opportunities** — refactors
that turn shallow modules into deep ones. The aim is testability (exercisable
through the three project seams: FakeClock, FakeMemoryTransport, InMemoryDrift)
and AI-navigability (an agent reading one module understands its full contract).

## Vocabulary

Use these terms exactly in every suggestion. Full definitions in [LANGUAGE.md](LANGUAGE.md).

- **Module** — anything with an interface and an implementation (function, class, provider, repository, layer slice).
- **Interface** — everything a caller must know: types, invariants, error modes, ordering, config. Not just the type signature.
- **Implementation** — the code inside.
- **Depth** — leverage at the interface: a lot of behaviour behind a small interface. **Deep** = high leverage. **Shallow** = interface nearly as complex as the implementation.
- **Seam** — where an interface lives; a place behaviour can be altered without editing in place.
- **Adapter** — a concrete thing satisfying an interface at a seam.
- **Leverage** — what callers get from depth.
- **Locality** — what maintainers get from depth: change, bugs, knowledge concentrated in one place.

Key principles:
- **Deletion test**: imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep.
- **The interface is the test surface.**
- **One adapter = hypothetical seam. Two adapters = real seam.**

## Hard constraints (never propose violations of these)

This skill surfaces friction and proposes refactors. It must **never** propose
anything that contradicts a locked decision:

- Layering (AGENTS.md §2): UI → State → Repository → DB. No shortcuts.
- Sync isolation: only `lib/sync/` imports Supabase. Enforced by grep gate.
- Clock injection: `DateTime.now()` is banned in the engine. Enforced by grep gate.
- AppTokens boundary: no raw hex or spacing literals in `lib/features/`. Enforced by grep gate.
- Material denylist: banned visual widgets in `lib/features/`. Enforced by grep gate.
- E2EE payload rule: every synced table splits into plaintext sync-metadata + one `encrypted_payload` blob (sync.md §3).
- LWW-Register model: cells are the unit of merge. Per-cell timestamps, not per-row (data_model.md §1).

If a candidate would require violating one of the above, do not surface it unless
the friction is real enough to warrant reopening the decision. Mark it clearly:
*"contradicts AGENTS.md §2 — worth reopening because…"*

## Process

### 1. Explore

Read `docs/architecture/index.md` first to orient. Then walk the codebase
organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called?
- Where do tightly-coupled modules leak across their seams?
- Which parts are hard to test through their current interface without reaching past the seam?
- Which modules would be hard for a fresh AI agent to understand without reading three other files?

Apply the **deletion test** to anything you suspect is shallow.

### 2. Present candidates

Present a numbered list of deepening opportunities. For each candidate:

- **Modules involved**: which `lib/` paths are affected
- **Current depth**: why the current shape is causing friction (shallow, leaky, hard to test)
- **Proposed change**: plain English — what would move, what would deepen
- **Benefits**: expressed as locality and leverage; how tests would improve; which grep gate becomes easier to satisfy
- **Layering check**: confirm the proposal does not violate AGENTS.md §2 or any grep gate

Do NOT propose interfaces yet. Ask: "Which of these would you like to explore?"

### 3. Design the deepened interface

Once the user picks a candidate, explore alternative interfaces using
[INTERFACE-DESIGN.md](INTERFACE-DESIGN.md). Walk the design tree — constraints,
dependencies, what sits behind the seam, what tests survive.

Side effects as decisions crystallise:
- **Naming a deepened module after a concept not yet in the architecture docs?**
  Add it to the relevant `docs/architecture/*.md` in the same commit
  (AGENTS.md §5 doc-honesty rule).
- **User rejects the candidate with a load-bearing reason?** Offer to record it
  in `_human/decision_log.md` as a new entry so future architecture reviews
  don't re-surface it. Only offer when the reason would genuinely prevent
  re-suggestion — skip ephemeral reasons.

### 4. Verify the refactor

Any refactor landed in code must leave `dart run tool/verify.dart` green. The
grep gates are the mechanical proof that the deepening didn't introduce a
layering violation. Run them explicitly: `dart run tool/grep_gates.dart`.
