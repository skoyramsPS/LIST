# 006: Cross-function integration matrix + deployment

**Workspace:** backend
**Type:** HITL
**Status:** pending
**Blocked by:** 003, 004, 005
**Harness stages exercised:** test (integration) / doc-honesty / doc-coverage

## What to build

The acceptance slice for the whole backend (companion PRD §"Testing
decisions"; master PRD §21): full HTTP round-trip scenarios across all three
functions against local Supabase, then deployment to the hosted Supabase
project so the app's `SupabaseTransport` task can integrate.

- **Integration matrix** (in `supabase/functions/_harness/`, real `fetch`
  round-trips, two JWTs, two simulated devices):
  - push → pull round-trip: pulled items are byte-identical to pushed items
    (the server stored and returned blobs it never interpreted).
  - Mixed stale batch: non-stale items commit, stale silently skip,
    `applied_count` reflects it, the skipped row's newer server version
    arrives on the next pull.
  - Tombstone flow: push with `deleted_at` → pull returns the tombstone with
    `encrypted_payload = null`.
  - Reset interleavings: reset between a peer's push and pull; reset while a
    peer holds an old cursor; every stale-epoch interaction 409s and nothing
    is polluted with old-epoch data.
  - Cross-user isolation across all three functions in one scenario.
- **Deployment** (the HITL part): create/link the hosted Supabase project,
  `supabase db push` the migration, deploy the three functions, confirm RLS is
  enforced on the hosted instance (one authorised + one unauthorised smoke
  request per function), record the project ref and any environment
  configuration in `docs/SETUP.md`.

## Acceptance criteria

- [ ] `make verify` is green in backend/ after this task
- [ ] At least one failing test existed before the implementation was written (matrix scenarios written red against the local stack first)
- [ ] Every scenario in companion PRD §"Testing decisions" is covered by at least one test (LWW guard, advisory-lock serialization, cursor pagination, epoch, tombstones, RLS isolation, validation)
- [ ] The three functions respond correctly on the **hosted** project: smoke push/pull/reset with a real JWT, plus a 401 without one — results recorded in the task notes at completion
- [ ] `docs/SETUP.md` documents the deploy procedure and hosted-project configuration
- [ ] <!-- doc-update --> Architecture doc updated if any new function or schema path was introduced

## Schema and RLS obligations (if applicable)

No new tables. Hosted-instance RLS smoke test is mandatory before declaring
deployment done — local-only RLS proof does not count for this task.

## Notes

HITL: deployment needs human-held credentials and the hosted-project choice.
**Completing this task unblocks app/028 (`SupabaseTransport` + scheduling)** —
the single cross-workspace dependency edge. Any wire-contract mismatch
discovered during app/028's two-device smoke test must be fixed by changing
both companion PRDs / both architecture docs in the same commit (root
`AGENTS.md §4`), never by silently adapting either side.
