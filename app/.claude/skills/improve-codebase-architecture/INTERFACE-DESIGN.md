# Interface Design — TheLIST

When exploring alternative interfaces for a deepening candidate, use this
process. Based on "Design It Twice" (Ousterhout) — your first idea is rarely
the best. Uses the vocabulary in [LANGUAGE.md](LANGUAGE.md).

## Process

### 1. Frame the problem space

Before proposing alternatives, write a brief explanation of:

- The constraints any new interface must satisfy (layering rules from AGENTS.md §2,
  grep-gate obligations, the three real seams)
- The dependencies it relies on and which seam category they fall into
- A rough illustrative Dart sketch to make constraints concrete — not a proposal,
  just grounding

Show this to the user, then immediately proceed to step 2.

### 2. Propose alternatives

Produce 2–3 radically different interface designs for the deepened module.
For each design:

1. **Interface** — Dart abstract class or typedef: methods, params, return types,
   plus invariants, ordering constraints, error modes
2. **Usage example** — how a caller (repository, provider, or widget) uses it
3. **What the implementation hides** — what complexity sits behind the seam
4. **Seam fit** — which of the three project seams this plugs into (or whether it
   introduces a new hypothetical seam)
5. **Trade-offs** — where leverage is high, where it is thin; which grep gate
   becomes easier or harder to satisfy

Design constraints to vary across alternatives:

- **Minimise the interface** — aim for 1–3 entry points max; maximise leverage per entry point
- **Maximise flexibility** — support many call patterns and future extension
- **Optimise for the most common caller** — make the default case trivial, edge cases possible

### 3. Compare and recommend

Compare designs in prose: **depth** (leverage at the interface), **locality**
(where change concentrates), and **seam placement** (which grep gate governs it).

Give a concrete recommendation — which design is strongest and why. If elements
from different designs combine well, propose a hybrid. Be opinionated.

## Layering constraint reminder

Any new interface must respect AGENTS.md §2:

```
lib/features/**      May only call into lib/state/**
lib/state/**         May only call into lib/repositories/**
lib/repositories/**  Only layer permitted to call Drift
lib/sync/**          Only layer permitted to call Supabase
lib/crypto/**        Key management — called from lib/sync/** only
```

An interface that requires a caller in `lib/features/` to directly reference
`lib/data/` or `lib/sync/` is a layering violation — do not propose it.
