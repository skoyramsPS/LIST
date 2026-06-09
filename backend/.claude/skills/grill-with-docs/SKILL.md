---
name: grill-with-docs
description: >-
  Structured requirements interview for the TheLIST backend. Challenges a
  feature idea or change against the existing architecture docs, RLS model,
  layering rules, and the dumb-server thesis before a PRD is written. Use at
  the START of a new endpoint, migration, or Edge Function — before /to-prd.
  Output feeds directly into to-prd; no files are written during the session.
---

# Grill With Docs — TheLIST Backend

## Purpose

Turn a rough backend idea into precise, contradiction-free requirements —
**before** anyone writes a PRD. The output of this session is the input to
`to-prd`.

This skill does **not** write files. Its sole output is a shared understanding
that `to-prd` then captures.

## Position in the workflow

```
grill-with-docs  →  to-prd  →  architect-review review-prd  →  to-tasks  → ...
```

## What "grilling" means here

This is a structured challenge, not a friendly clarification session. Find:

- Ideas that contradict the dumb-server thesis (server must never decrypt
  user data; all merge logic is client-side)
- Ideas that violate the layering (SQL in a handler, Supabase client in a
  service, business logic in a repository)
- RLS implications that haven't been thought through
- Schema changes that affect the sync contract (updated_at, encrypted_payload)
- Ideas that are actually two features that need to be separated
- Non-goals being smuggled in as sub-features

## Before the first question

Read these:

1. `AGENTS.md` — non-negotiable constraints. Anything the idea violates is an
   immediate challenge, not a question.
2. `docs/architecture/index.md` — route to the specific architecture doc(s)
   the idea touches.
3. The relevant architecture doc(s) — understand the current shape of the
   system in the area being changed.

## How to run the session

**One question at a time.** Wait for an answer before asking the next.

**Give your recommended answer with each question.** "I think the answer is X
because of Y in the architecture — do you agree?" This is faster and more useful
than open-ended probing.

**If a question can be answered by reading the docs, read them first.**

**Challenge against the existing vocabulary.** When the human uses a term that
has a specific meaning in the architecture docs (encrypted_payload, sync_version,
updated_at, deleted_at, RLS policy, service-role key, anon key, Edge Function,
repository, handler, service, Clock, FakeSupabaseClient), use that term exactly.

**Surface the dumb-server constraint explicitly.** For any feature that touches
user data: does the server need to read the plaintext? If yes, that conflicts
with the E2EE model — name the conflict directly.

**Probe the RLS implications.** Every new table needs RLS. Every new access
pattern needs a policy. Ask:
- Who can SELECT / INSERT / UPDATE / DELETE this data?
- Is the policy row-level (per-user) or table-level?
- What happens if an unauthenticated request hits this endpoint?

**Probe the schema implications.** Any new table that syncs must carry
`updated_at` (LWW timestamp), `deleted_at` (tombstone), and `encrypted_payload`
(E2EE blob). Ask whether these are needed.

**Probe the layering implications.** Which layer does this feature touch?
Does it require a new repository method? A new service? A new Edge Function?
Does anything about the design require a layer shortcut? (If yes, the design
is wrong — not the rule.)

**Probe the test implications.** How will this be tested? Unit test for the
service (injected Clock and FakeSupabaseClient)? Integration test for the RLS
policy? What does a failing test look like?

## Finishing the session

The session is complete when:

- The feature is described precisely enough that `to-prd` can write it without
  follow-up questions
- Every contradiction with the dumb-server thesis has been resolved
- RLS, schema, layering, and testing implications are understood
- Scope boundary is clear

Produce a **session summary**:

```
## Grill Session Summary — <feature name>
**Date:** <today>

### What we're building
<1-3 sentences. Precise. Uses the architecture vocabulary.>

### Scope boundary
**In:** <what is included>
**Out:** <what is explicitly excluded>

### Schema implications
<New tables or columns. Whether updated_at/deleted_at/encrypted_payload apply.
Whether gen_schema.ts must be re-run.>

### RLS implications
<Which tables get new policies. Who can access what. Whether integration tests
are needed.>

### Layering implications
<Which layers are touched. New Edge Functions, handlers, services, or
repositories required.>

### Testing implications
<Unit test targets (services). Integration test targets (RLS, HTTP).>

### Open questions (if any)
<Anything that could not be resolved and must be decided during implementation.>
```

Hand this summary to `to-prd`.
