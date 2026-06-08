---
name: to-prd
description: Turn the current conversation context into a PRD and save it to docs/planning/active/. Use when the user wants to capture a feature idea, a new capability, or a significant change as a formal product requirement document. Do NOT interview the user — synthesise what you already know from the conversation.
---

# To PRD — TheLIST

Synthesise the current conversation context and codebase understanding into a
PRD. Do NOT interview the user — just produce it from what you already know.

## Process

### 1. Explore the codebase

Read `docs/architecture/index.md` to route yourself to the relevant architecture
doc(s). Use the project domain vocabulary throughout (Sheet, Row, Cell, Column,
Reminder, AttentionItem, SyncTransport, Clock, AppTokens, List* components).
Respect every locked decision in `AGENTS.md` and the architecture docs — do not
propose anything that contradicts them.

### 2. Sketch the major modules

Identify which `lib/` layers the feature touches and what new or modified
modules it requires. Look for opportunities to extract [deep modules](../tdd/deep-modules.md)
— small interfaces hiding complex implementations — especially in the sync
engine, repository layer, and recurrence logic.

Check with the user that the module sketch matches their expectations before
writing the full PRD.

### 3. Write the PRD

Use the template below. Create a folder `docs/planning/active/<feature-slug>/`
and save the document as `docs/planning/active/<feature-slug>/PRD.md`.

The existing `docs/planning/active/the-list/PRD.md` is the master product spec — do NOT
overwrite it. Feature PRDs live in their own subfolders alongside it.

After saving, confirm the file path resolves (doc-honesty will check it on the
next `dart run tool/verify.dart`).

---

## PRD template

```markdown
# <Feature Name> — PRD

**Status:** draft
**Created:** <date>
**Relates to:** docs/planning/active/the-list/PRD.md §<section(s)>

## Problem statement

The problem the user is facing, from their perspective.

## Solution

The solution, from the user's perspective.

## User stories

A thorough numbered list. Format: "As a <actor>, I want <feature>, so that <benefit>."

Use the project's actors: the user (always offline-first), their second device
(sync scenario), the notification system.

## Implementation decisions

Which lib/ layers are touched, what new modules are introduced, interface
sketches (no file paths — they change; no code snippets — they go stale).
Include:

- Layer(s) affected (UI / State / Repository / Data / Sync / Crypto / Notifications)
- New or modified deep modules and their public interfaces
- Schema changes (if any — note that data_model.md §"Generated schema" will need
  regeneration via `dart run tool/gen_schema.dart`)
- Sync contract additions (if any — every new synced table must carry updated_at
  and encrypted_payload per sync.md §3)
- AppTokens or List* component additions (if any)

## Testing decisions

- Which modules will have tests
- What the convergence matrix must cover (if sync is touched)
- Whether the grep gates need a new rule
- Prior art in `test/` to follow

## Harness prerequisites

Call out explicitly any harness obligation this feature triggers:

- Does it add the first Drift table? → wire gen_schema.dart (PRD §22b)
- Does it add the first Riverpod provider? → activate riverpod_lint (PRD §22c)
- Does it add the first List* widget? → font assets must be present (PRD §22a)

## Out of scope

Things explicitly not included in this PRD.

## Further notes

Any additional context, open questions, or links to relevant architecture
sections.
```
