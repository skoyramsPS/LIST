---
name: add-grep-gate
description: >-
  Add a new absence-invariant grep gate to TheLIST's verify pipeline. Takes a
  pattern and scope from the human, adds it to tool/grep_gates.dart, writes its
  self-test in test/harness/grep_gates_test.dart, registers it in
  docs/HARNESS.md §2, and verifies green. Invoke when a new structural rule
  must be mechanically enforced across the codebase.
---

# Add Grep Gate — TheLIST

## Purpose

Wire a new absence-invariant into the verify pipeline. A grep gate is a pattern
that must *never* appear in a given set of directories — it is a mechanical
guardrail, not a style preference. This skill makes the gate real: it exists in
`tool/grep_gates.dart`, has a test that proves it fires, and is documented in
`docs/HARNESS.md §2`.

## Position in the workflow

Invoke directly — typically after recognising a recurring violation in code
review, after `architect-review` flags a structural risk, or proactively when a
new architectural boundary is introduced (a new layer, a new prohibited import,
a new injectable abstraction). The gate lands in the `grep-gates` stage of
`make verify`, which runs before schema and doc-honesty.

## Phase 1 — Define the gate precisely

Ask the human (or derive from context if the conversation already answers it):

1. **Gate name** — `snake_case`, describes what is forbidden, not what is
   allowed. Good: `no-direct-db-in-ui`. Bad: `database-rule`.

2. **Forbidden pattern** — the exact regex or literal string that must not
   appear. Be precise: `DateTime\.now\(\)` is better than `DateTime`. If the
   pattern is complex, test it mentally against a false-positive case (something
   that looks similar but should be allowed).

3. **Scope** — which directories does the gate scan? Use the smallest scope that
   covers the invariant. Wrong scope is worse than no gate: too broad produces
   false positives; too narrow misses violations.

4. **Invariant** — one sentence stating the architectural rule this gate
   enforces. This goes in the code comment and in HARNESS.md. If you cannot
   state the invariant in one sentence, the gate is not well-defined.

5. **Existing violations** — before the gate is added, scan the current
   codebase. If violations exist:
   - Intentional (the pattern is needed there): add `// gate-ok: <reason>` at
     that line and confirm the reason is legitimate
   - Accidental (the pattern is a real bug): fix first, then add the gate

Do not add a gate that fires on the current tree with no `gate-ok` markers —
it will immediately break `make verify` for everyone.

## Phase 2 — Implement

### 1. Add the gate to `tool/grep_gates.dart`

Each gate is an entry in the gates list. The exact structure depends on how
`grep_gates.dart` is implemented — read the file first to match the existing
pattern exactly. At minimum, add:
- Gate name
- Forbidden regex pattern
- List of scoped directories
- A comment stating the invariant in one sentence

### 2. Write the self-test in `test/harness/grep_gates_test.dart`

Every gate must have a test that proves it actually fires. A gate without a test
could silently never match — which is the worst failure mode for a guardrail.

The test must:
- Create a temporary sandbox directory
- Write a file containing a deliberate violation of the pattern
- Run the gate (or the full grep_gates.dart) against that sandbox
- Assert it exits non-zero or produces an error for that violation
- Assert a clean file in the same sandbox passes (no false positive)
- Clean up the sandbox after the test

Read `test/harness/grep_gates_test.dart` to match the existing test style
exactly before writing a new one.

### 3. Scan for existing violations

```
# Example — replace pattern and dirs with the actual gate values:
grep -rn "<pattern>" lib/features/ lib/state/
```

For each match: is it a legitimate exception or an accidental violation?
- Legitimate → add `// gate-ok: <reason>` on that line
- Accidental → fix it now, before adding the gate

### 4. Add a row to `docs/HARNESS.md §2`

The table columns are: Gate name | Pattern forbidden | Where | Why.
Keep each cell concise — this table is a quick reference, not a spec.

## Phase 3 — Verify

Run the full pipeline:

```
dart run tool/verify.dart
```

Two stages are directly exercised:
- `grep-gates` — the new gate must pass on the current (clean) tree
- `test` — the new self-test must pass

All other stages must remain green. Do not mark the session complete until all
seven are green.

## Output

No session summary is needed — the output is the green verify run and the three
changed files:
- `tool/grep_gates.dart` — new gate entry
- `test/harness/grep_gates_test.dart` — new self-test
- `docs/HARNESS.md` — new §2 table row

## Hard rules

- **Never add a gate that fires on the current tree** unless you fix the
  violations or add `gate-ok` markers first.
- **Every gate gets a test.** No exceptions. An untested gate is a liability,
  not a guardrail.
- **Smallest possible scope.** A gate that scans `lib/` when it only needs to
  scan `lib/features/` will produce false positives as the codebase grows.
- **Do not mark done until `make verify` is green.**
