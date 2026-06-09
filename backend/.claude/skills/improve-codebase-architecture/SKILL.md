---
name: improve-codebase-architecture
description: >-
  Find deepening opportunities in the TheLIST backend codebase — refactors that
  turn shallow modules into deep ones for better testability and AI-navigability.
  Use when the user wants to improve architecture, find refactoring opportunities,
  consolidate tightly-coupled layers, or make Edge Functions more testable.
  Always respects AGENTS.md layering rules and locked decisions.
---

# Improve Codebase Architecture — TheLIST Backend

Surface architectural friction and propose **deepening opportunities** — refactors
that turn shallow modules into deep ones. The aim is testability (exercisable
through the two project seams: FakeClock, FakeSupabaseClient) and
AI-navigability (an agent reading one module understands its full contract).

## Vocabulary

- **Module** — anything with an interface and an implementation (function,
  service, repository, handler).
- **Depth** — leverage at the interface: a lot of behaviour behind a small
  interface. **Deep** = high leverage. **Shallow** = interface nearly as complex
  as the implementation.
- **Seam** — where an interface lives; a place behaviour can be altered without
  editing in place.
- **Deletion test** — imagine deleting the module. If complexity vanishes, it
  was a pass-through. If complexity reappears across N callers, it was earning
  its keep.

## Hard constraints (never propose violations of these)

- Layering (AGENTS.md §2): index → handler → service → repository. No shortcuts.
- SQL isolation: only `repository.ts` files run SQL. Enforced by grep gate.
- Clock injection: `Date.now()` is banned in service/repository. Enforced by grep gate.
- No server-side decryption: the backend must never read plaintext user data.
- RLS as the security boundary: policies in the database, not in application code.

## Process

### 1. Explore

Read `docs/architecture/index.md` first. Then walk the codebase and note friction:

- Where does understanding one function require reading three other files?
- Where are modules shallow — interface nearly as complex as the implementation?
- Where does a handler contain SQL (should be in a repository)?
- Where does a service instantiate a Supabase client (should be injected)?
- Which services are hard to unit-test because they call `Date.now()`?
- Which repositories leak query construction details to their callers?

Apply the deletion test to anything suspected of being shallow.

### 2. Present candidates

For each candidate:

- **Modules involved**: which `supabase/functions/...` paths are affected
- **Current depth**: why the current shape causes friction
- **Proposed change**: plain English — what would move, what would deepen
- **Benefits**: locality and leverage; how tests would improve; which grep gate
  becomes easier to satisfy
- **Layering check**: confirm the proposal does not violate AGENTS.md §2

Do NOT propose interfaces yet. Ask: "Which of these would you like to explore?"

### 3. Design the deepened interface

Once the user picks a candidate, explore alternatives. Walk the design space:
constraints, dependencies, what sits behind the seam, what tests survive a refactor.

If naming a deepened module after a concept not yet in the architecture docs,
add it to the relevant `docs/architecture/*.md` in the same commit.

### 4. Verify the refactor

```
make verify
```

The grep gates are the mechanical proof that the deepening didn't introduce a
layering violation. All seven stages must be green.
