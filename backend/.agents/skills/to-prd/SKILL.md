---
name: to-prd
description: >-
  Turn the current conversation context into a backend PRD and save it to
  docs/planning/active/. Use when the user wants to capture a new Edge Function,
  migration, RLS policy, or significant backend change as a formal product
  requirement document. Do NOT interview the user — synthesise what you already
  know from the conversation.
---

# To PRD — TheLIST Backend

Synthesise the current conversation context and codebase understanding into a
PRD. Do NOT interview the user — produce it from what you already know.

## Process

### 1. Explore the codebase

Read `docs/architecture/index.md` to route yourself to the relevant architecture
doc(s). Use the project vocabulary throughout (encrypted_payload, updated_at,
deleted_at, RLS policy, Edge Function, handler, service, repository, Clock,
FakeSupabaseClient). Respect every locked decision in `AGENTS.md` — do not
propose anything that contradicts them.

### 2. Sketch the major modules

Identify which layers the feature touches and what new or modified modules it
requires. Look for opportunities to extract deep modules — small interfaces
hiding complex implementations — especially in the repository and service layers.

Check with the user that the module sketch matches their expectations before
writing the full PRD.

### 3. Write the PRD

Use the template below. Create a folder `docs/planning/active/<feature-slug>/`
and save the document as `docs/planning/active/<feature-slug>/PRD.md`.

After saving, confirm the file path resolves (doc-honesty will check it on
the next `make verify`).

---

## PRD template

```markdown
# <Feature Name> — Backend PRD

**Status:** draft
**Created:** <date>

## Problem statement

The problem being solved, from the product or integration perspective.

## Solution

The solution at the backend level — what endpoints, migrations, or policies
are added/changed.

## User stories / integration stories

Numbered list. Format: "As a <actor>, I want <capability>, so that <benefit>."

Actors: the Flutter app client (authenticated user), the sync engine
(service-role), the Supabase auth system, the local Supabase test harness.

## Implementation decisions

Which layers are touched and what new modules are introduced:

- **Layer(s) affected** (index/handler/service/repository/migration)
- **New or modified Edge Functions** — name, HTTP method, path, auth requirement
- **New or modified repositories** — method signatures (no implementation)
- **New or modified services** — method signatures, Clock injection if needed
- **Schema changes** — new tables/columns, note that `make gen` must be run
- **RLS policies** — which tables, which operations, which roles

## Testing decisions

- Which services will have unit tests (FakeClock, FakeSupabaseClient)
- Which RLS policies will have integration tests (authorized + unauthorized cases)
- Whether any new grep gate is needed

## Out of scope

Things explicitly not included in this PRD.

## Further notes

Any additional context, open questions, or links to relevant architecture docs.
```
