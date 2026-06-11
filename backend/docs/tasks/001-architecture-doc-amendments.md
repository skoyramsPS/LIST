# 001: Land the backend architecture-doc amendments

**Workspace:** backend
**Type:** HITL
**Status:** pending
**Blocked by:** None — can start immediately
**Harness stages exercised:** doc-honesty / doc-coverage / fmt

## What to build

Move the binding implementation decisions from the mortal backend companion PRD
(`docs/planning/active/the-list/PRD.md`, §"Architecture doc amendments") into
the immortal architecture docs, making them authoritative. This is the backend
mirror of app task 001 and **must complete before any schema or function
implementation task (002–006)**.

Concretely:

1. `docs/architecture/schema.md` — replace the per-table sync conventions
   section with the single-table model: one generic `sync_entities` log
   (nullable `encrypted_payload` + CHECK, trigger-assigned per-user
   `server_seq`, no FK constraints anywhere, plaintext `table_name`
   discriminator) plus the per-user `sync_state` epoch row. State the binding
   rationale (one table not five; FKs travel inside the payload; `sync_version`
   stored never branched on). The `<!-- SCHEMA -->` fence itself regenerates
   from the migration in task 002 — do not hand-fill it here.
2. `docs/architecture/functions.md` — add the three function contracts exactly
   as specified in companion PRD §4: `sync_push`, `sync_pull`, `sync_reset`
   request/response shapes, the `pg_advisory_xact_lock(hashtext(user_id))`
   concurrency rule, the silent-stale-skip and no-per-row-statuses rules, the
   epoch guard, and the error envelope with codes `epoch_mismatch` (409),
   `batch_too_large` (400), `unauthorized` (401), `invalid_request` (400).
3. `docs/architecture/testing.md` — add the advisory-lock/cursor-gap and epoch
   test obligations (concurrent same-user pushes never produce a cursor gap;
   stale-epoch push/pull rejection; reset atomicity).
4. State the server prohibitions (companion PRD §5) where they belong: no
   decrypting/parsing `encrypted_payload`, no merge logic beyond the single
   `updated_at` guard, no branching on `sync_version` or `table_name`
   semantics, no custom auth functions.

## Acceptance criteria

- [ ] `make verify` is green in backend/ after this task
- [ ] At least one failing test existed before the implementation was written — **N/A: doc-only task; the doc-honesty stage is the mechanical check here**
- [ ] `schema.md` and `functions.md` fully supersede the companion PRD amendments (no binding decision exists only in the PRD)
- [ ] The three function contracts in `functions.md` match the wire contract duplicated verbatim in both companion PRDs (root `AGENTS.md §4`)
- [ ] `testing.md` lists the advisory-lock/cursor-gap and epoch test obligations
- [ ] No `supabase/functions/...` or `supabase/migrations/...` path is referenced that does not yet resolve (doc-honesty extracts and checks them — phrase forward-looking contracts as endpoint paths `/functions/v1/...`, not source paths, until the code exists)
- [x] <!-- doc-update --> Architecture doc updated if any new function or schema path was introduced (the doc updates *are* the deliverable)

## Schema and RLS obligations (if applicable)

None — doc-only. The migration + RLS land together in task 002.

## Notes

HITL: the human reviews the immortal docs before they become authoritative.
Watch the doc-honesty stage: `functions.md` already references the planned
`_shared/` source paths — if the checker fails on them now, defer those
path-bearing lines to task 003 (which creates the files) rather than weakening
the checker. After this task completes, the architecture docs — not the
companion PRD — are authoritative for schema and function contracts.
