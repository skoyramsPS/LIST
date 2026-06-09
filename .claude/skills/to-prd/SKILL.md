---
name: to-prd
description: >-
  Turn the current conversation context into a monorepo-level PRD and save it to
  docs/planning/active/. Use when capturing a feature idea, new capability, or
  significant change that may span the app/ (Flutter) and/or backend/ (Supabase)
  workspaces. Produces a single cross-cutting PRD with clearly separated app and
  backend sections. Do NOT interview the user — synthesise from what you already
  know. Once requirements are finalised, the PRD is split into workspace-specific
  feature PRDs in app/docs/planning/active/ and backend/docs/planning/active/.
---

# To PRD — TheLIST (Monorepo)

Synthesise the current conversation context and codebase understanding into a
monorepo-level PRD. Do NOT interview the user — produce it from what you already know.

## Process

### 1. Read the contracts

Before writing anything:

1. `AGENTS.md` (root) — universal constraints that apply to everything
2. The workspace-specific `AGENTS.md`(s) the feature touches — layering rules,
   grep gates, verify pipelines differ per workspace
3. The relevant `docs/architecture/index.md`(s) — route to specific architecture docs
4. `docs/planning/active/the-list/PRD.md` (root) — the master product spec;
   do NOT overwrite it; new feature PRDs live alongside it in their own subfolders

Use the project domain vocabulary throughout. Respect every locked decision.
Do not propose anything that contradicts them.

### 2. Determine workspace scope

Identify which workspace(s) the feature touches:

- **App-only** — produces an app-focused PRD; backend section is omitted
- **Backend-only** — produces a backend-focused PRD; app section is omitted
- **Cross-cutting** — produces both sections and a sync contract boundary section;
  this is the most important case to get right

### 3. Sketch the major modules

For each workspace in scope, identify which layers the feature touches and what
new or modified modules it requires.

- **App:** which `lib/` layers (UI / State / Repository / Data / Sync / Crypto /
  Notifications)? New deep modules? Schema changes? Sync contract additions?
- **Backend:** which Edge Functions are new or changed? New SQL tables or columns?
  RLS policy implications? Any change to the sync contract the app must honour?

For cross-cutting features, sketch the **sync contract boundary** explicitly:
what the app writes, what the backend stores, which fields are in
`encrypted_payload` vs plaintext metadata.

Check with the user that the module sketch matches their expectations before
writing the full PRD.

### 4. Write the PRD

Use the template below. Create `docs/planning/active/<feature-slug>/` at the
**monorepo root** and save as `docs/planning/active/<feature-slug>/PRD.md`.

The existing `docs/planning/active/the-list/PRD.md` is the master product spec —
do NOT overwrite it. Feature PRDs live in their own subfolders alongside it.

After saving, confirm the file path resolves.

### 5. Splitting into workspace PRDs (when requirements are finalised)

Once this PRD is approved and stable, split it:

- App-specific requirements → `app/docs/planning/active/<feature-slug>/PRD.md`
- Backend-specific requirements → `backend/docs/planning/active/<feature-slug>/PRD.md`

Each workspace PRD should be self-contained for that workspace's agents. The
monorepo PRD remains the source of truth and cross-cutting reference.

---

## PRD template

```markdown
# <Feature Name> — PRD

**Status:** draft
**Created:** <date>
**Workspace scope:** app-only / backend-only / cross-cutting
**Relates to:** docs/planning/active/the-list/PRD.md §<section(s)>

## Problem statement

The problem the user is facing, from their perspective.

## Solution

The solution, from the user's perspective.

## User stories

A thorough numbered list. Format: "As a <actor>, I want <feature>, so that <benefit>."

Actors: the user (always offline-first), their second device (sync scenario),
the notification system, the backend (for backend-facing stories).

## App implementation decisions
*(omit if backend-only)*

- **Layers affected:** UI / State / Repository / Data / Sync / Crypto / Notifications
- **New or modified deep modules:** interface sketches (no file paths, no code snippets)
- **Schema changes:** note that data_model.md §"Generated schema" requires
  regeneration via `dart run tool/gen_schema.dart`
- **Sync contract additions:** every new synced table must carry updated_at,
  deleted_at, encrypted_payload per sync.md §3
- **AppTokens or List* component additions:** if any
- **Harness prerequisites triggered:** PRD §22a (fonts), §22b (gen_schema),
  §22c (riverpod_lint) — call out explicitly if triggered

## Backend implementation decisions
*(omit if app-only)*

- **Edge Functions:** new or modified functions and their responsibilities
- **SQL schema changes:** new tables or columns; note migration file required
- **RLS policies:** new or modified policies; confirm every new table has a policy
- **Sync contract surface:** what this backend change exposes or expects from the app

## Sync contract boundary
*(cross-cutting features only)*

- **App writes:** <what the Flutter sync engine produces>
- **Backend stores/returns:** <what Supabase persists and serves>
- **Encrypted (server-opaque):** <fields inside encrypted_payload>
- **Plaintext (routing metadata):** <fields the server reads: device_id, updated_at, etc.>
- **Convergence behaviour:** <what the correct merged result is if two devices edit simultaneously>
- **Migration path:** <how existing encrypted blobs are handled if the schema changes>

## Testing decisions

- **App:** which modules have tests; convergence matrix cases (if sync touched);
  which seams are exercised (FakeClock, FakeMemoryTransport, InMemoryDrift)
- **Backend:** which Edge Function integration tests; which RLS policy tests;
  whether a local Supabase environment is required

## Out of scope

Things explicitly not included in this PRD.

## Further notes

Open questions, links to relevant architecture sections, or context for the
architect-review.
```
