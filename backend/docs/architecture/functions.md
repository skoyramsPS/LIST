# Edge Functions — TheLIST Backend

This document describes the Edge Function contracts: request shapes, response
shapes, auth requirements, and layer responsibilities.

All paths referenced here are verified by `make verify` (doc-honesty stage).
If you add, move, or rename a function, update this file in the same commit.

---

## Layering reminder

Every Edge Function follows this strict structure:

```
supabase/functions/<name>/index.ts       HTTP entry-point only.
supabase/functions/<name>/handler.ts     Orchestration only. No SQL.
supabase/functions/<name>/service.ts     Domain logic. Pure where possible.
supabase/functions/<name>/repository.ts  SQL + Supabase client. Nothing else.
```

Grep gates enforce these boundaries mechanically. See `AGENTS.md §2`.

---

## Shared utilities

```
supabase/functions/_shared/logger.ts     Structured logger. Use instead of console.log.
supabase/functions/_shared/clock.ts      Clock interface + real implementation.
supabase/functions/_shared/errors.ts     Typed error classes and HTTP error helpers.
supabase/functions/_shared/auth.ts       JWT verification helper used by index.ts files.
```

---

## Functions

*(Add a section here for each Edge Function as it is implemented.)*

### Template

```
### supabase/functions/<name>/

**Method:** POST / GET / PATCH / DELETE
**Path:** /functions/v1/<name>
**Auth:** required (authenticated) / service-role / none

**Request body:**
{
  field: type   // description
}

**Response (200):**
{
  field: type   // description
}

**Response (error):**
{ error: string, code: string }

**Behaviour:**
- What this function does in one paragraph.
- Which tables it reads/writes.
- Whether it touches encrypted_payload (it should not decrypt it).
```
