---
name: add-grep-gate
description: >-
  Add a new absence-invariant grep gate to the TheLIST backend verify pipeline.
  Takes a pattern and scope from the human, adds it to tool/grep_gates.ts,
  writes its self-test in supabase/functions/_harness/grep_gates_test.ts,
  registers it in docs/HARNESS.md §2, and verifies green. Invoke when a new
  structural rule must be mechanically enforced across the backend codebase.
---

# Add Grep Gate — TheLIST Backend

## Purpose

Wire a new absence-invariant into the verify pipeline. A grep gate is a pattern
that must *never* appear in a given set of files — it is a mechanical guardrail,
not a style preference. This skill makes the gate real: it exists in
`tool/grep_gates.ts`, has a test that proves it fires, and is documented in
`docs/HARNESS.md §2`.

## Position in the workflow

Invoke directly — typically after recognising a recurring violation in code
review, after `architect-review` flags a structural risk, or proactively when a
new architectural boundary is introduced.

## Phase 1 — Define the gate precisely

Ask the human (or derive from context):

1. **Gate name** — `snake_case`, describes what is forbidden. Good:
   `no-sql-outside-repository`. Bad: `database-rule`.

2. **Forbidden pattern** — the exact regex that must not appear. Be precise.
   Test mentally against a false-positive case.

3. **Scope** — which directories and which file-name exemptions apply.
   (e.g. `repository.ts` is exempt from the SQL gate; `index.ts` from the
   response gate; `*_test.ts` from the console.log gate.)

4. **Invariant** — one sentence stating the architectural rule. Goes in the
   code comment and in HARNESS.md.

5. **Existing violations** — scan first. Fix accidental ones before adding
   the gate; add `// gate-ok: <reason>` for intentional ones.

## Phase 2 — Implement

### 1. Add the gate to `tool/grep_gates.ts`

Read the file first to match the existing `Gate` interface. Add `name`,
`pattern`, `dirs`, `invariant`. Add file-name exemptions in the per-entry
`if` guards following the existing patterns.

### 2. Write the self-test in `supabase/functions/_harness/grep_gates_test.ts`

The test must:
- Create a `Deno.makeTempDir()` sandbox
- Write a file with a deliberate violation
- Assert the gate exits non-zero for the violation
- Assert a clean file passes (no false positive)
- Clean up with `Deno.remove(tmpDir, { recursive: true })`

Match the existing test style exactly.

### 3. Scan for existing violations

```bash
grep -rn "<pattern>" supabase/functions/
```

Fix accidentals; add `gate-ok` for intentionals.

### 4. Add a row to `docs/HARNESS.md §2`

Columns: Gate name | Pattern forbidden | Where | Why.

## Phase 3 — Verify

```
make verify
```

`grep-gates` and `test` are directly exercised. All seven stages must be green.

## Output

- `tool/grep_gates.ts` — new gate entry
- `supabase/functions/_harness/grep_gates_test.ts` — new self-test
- `docs/HARNESS.md` — new §2 table row

## Hard rules

- **Never add a gate that fires on the current tree** without fixing violations first.
- **Every gate gets a test.** No exceptions.
- **Smallest possible scope.**
- **Do not mark done until `make verify` is green.**
