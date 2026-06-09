---
name: grill-with-docs
description: >-
  Structured requirements interview for TheLIST at the monorepo level. Challenges
  a feature idea or change against architecture docs, locked decisions, and domain
  vocabulary for both the app/ (Flutter) and backend/ (Supabase) workspaces before
  a PRD is written. Use at the START of any feature that touches either or both
  workspaces — before /to-prd. Output feeds directly into to-prd; no files are
  written during the session.
---

# Grill With Docs — TheLIST (Monorepo)

## Purpose

Turn a rough idea into precise, contradiction-free requirements — **before**
anyone writes a PRD. The output of this session is the input to `to-prd`.

This skill does **not** write files during the session. Its sole output is a
shared understanding that the `to-prd` skill then captures.

## Position in the workflow

```
grill-with-docs  →  to-prd  →  architect-review review-prd  →  to-tasks  →  ...
```

Do not skip this step for anything non-trivial. A PRD written from an un-grilled
idea inherits the idea's ambiguities. Better to surface them here, in conversation,
before they're baked into a document.

## Workspace scope

This monorepo-level version considers **both workspaces**:

- **`app/`** — offline-first Flutter app (Dart, Drift, Riverpod, E2EE sync engine)
- **`backend/`** — Supabase Edge Functions, SQL migrations, RLS policies

Before asking the first question, determine which workspace(s) the idea touches:
- App-only → probe Flutter layering, test seams, grep gates
- Backend-only → probe Edge Function boundaries, SQL schema, RLS correctness
- Cross-cutting → probe both, and explicitly probe the **sync contract boundary**
  between them (the highest-risk surface in the monorepo)

## What "grilling" means here

A structured challenge, not a clarification session. Find:

- Contradictions with locked decisions in root or workspace `AGENTS.md`
- Ambiguity against domain vocabulary in either workspace's `docs/architecture/`
- Ideas touching the sync engine or E2EE model without thinking through both sides
- Non-goals in `docs/planning/active/the-list/PRD.md §4` being smuggled in
- Ideas that are actually two ideas that need separating
- Cross-cutting changes where app and backend have been designed independently
  but not checked against each other at the boundary

## Before the first question

Read these before asking anything:

1. `AGENTS.md` (root) — universal non-negotiables
2. The workspace-specific `AGENTS.md`(s) the idea touches
3. The relevant `docs/architecture/index.md`(s) to route to specific docs
4. The relevant architecture doc(s) — understand the current system shape
5. `docs/planning/active/the-list/PRD.md §4` — the explicit non-goals

Start from what this project has already decided, not from general first principles.

## How to run the session

**One question at a time.** Wait for an answer before the next. Do not front-load.

**Give your recommended answer with each question.** "I think the answer is X
because of Y in the architecture docs — do you agree?" Faster than open-ended probing.

**If a question can be answered by reading the codebase or docs, read them first.**

**Challenge against the domain vocabulary.**
App workspace: Sheet, Row, Cell, Column, Reminder, AttentionItem, SyncTransport,
Clock, AppTokens, template_kind, semantic_role, position, sync_version,
encrypted_payload, FakeClock, FakeMemoryTransport, InMemoryDrift.
Backend workspace: migration, RLS policy, Edge Function, webhook, service role,
anon key, encrypted_payload.
If the human uses a different term for a known concept, flag it.

**Probe the sync contract boundary for cross-cutting features.**
- What does the app write? What does the backend store and return?
- Which fields are inside `encrypted_payload` (server-opaque) vs plaintext
  sync metadata (server-readable)?
- What happens if app and backend have mismatched expectations about a field?
- Does a backend schema change require a coordinated app change? Migration path
  for existing encrypted blobs?

**Probe E2EE implications.** Data the server must not read goes in
`encrypted_payload`. Routing metadata (device_id, updated_at, deleted_at,
sync_version) stays plaintext. Never blur this line.

**Probe layering implications per workspace.**
- App: which `lib/` layers? New repository method? New Riverpod provider? New UI
  component? Any shortcut across layers?
- Backend: which Edge Functions are new or changed? New SQL table or column? Does
  every new table have a correct RLS policy? Is the policy tested?

**Probe test implications per workspace.**
- App: which seams (FakeClock, FakeMemoryTransport, InMemoryDrift)? Convergence
  matrix case needed?
- Backend: which Edge Function integration tests cover this? New RLS test cases?

## Finishing the session

Complete when:
- The feature is described precisely enough that `to-prd` can write it without
  follow-up questions
- Every contradiction with locked decisions is resolved or consciously deferred
- Workspace scope is clear: app-only, backend-only, or cross-cutting
- For cross-cutting: the sync contract boundary is fully specified
- E2EE, layering, and testing implications are understood for each workspace touched

Produce a **session summary** as the handoff to `to-prd`:

```
## Grill Session Summary — <feature name>
**Date:** <today>
**Workspace scope:** app-only / backend-only / cross-cutting

### What we're building
<1-3 sentences. Precise. Uses domain vocabulary.>

### Scope boundary
**In:** <what is included>
**Out:** <what is explicitly excluded — reference PRD non-goals where relevant>

### Workspace breakdown
**App concerns:** <what the Flutter side needs to do>
**Backend concerns:** <what the Supabase side needs to do>
**Sync contract boundary:** <what the app writes, what the backend stores,
which fields are encrypted vs plaintext — omit if app-only or backend-only>

### E2EE implications
<Which data is in encrypted_payload vs plaintext metadata. Any leakage risk.>

### Layering implications (per workspace)
<App: which lib/ layers touched, new modules required.>
<Backend: which Edge Functions, SQL schema changes, RLS implications.>

### Testing implications (per workspace)
<App: which seams, convergence matrix cases.>
<Backend: which integration tests, new RLS test cases.>

### Locked decisions touched
<Any decisions that were relevant. Confirmed, challenged, or deferred.>

### Open questions (if any)
<Unresolved items the architect-review will look for.>
```

Hand this summary to `to-prd`. The PRD writes itself from this.
