# TheLIST — Backend Implementation PRD (companion)

**Status:** draft
**Created:** 2026-06-10
**Workspace scope:** backend (companion to the cross-cutting master spec)
**Relates to:** `docs/planning/active/the-list/PRD.md` (monorepo root, the "What");
app companion: `app/docs/planning/active/the-list/PRD.md`

> **Contract rule.** This PRD is *mortal*. Every binding implementation decision
> below must land in the *immortal* architecture docs as its first implementation
> task (see §"Architecture doc amendments" at the end); once amended, the
> architecture docs are authoritative and this PRD is archived. The **sync wire
> contract** section is duplicated verbatim in the app companion PRD by design —
> it is the shared boundary; any change to it must update both PRDs (and later
> both `docs/architecture/functions.md` and `app/docs/architecture/sync.md`) in
> the same commit, per root `AGENTS.md §4`.

---

## Problem statement

The master PRD names `sync_push` and `sync_pull` but specifies no wire shapes,
no cursor semantics, no conflict rule, no schema, and no recovery path for a
user who loses every key. An unspecified sync protocol gets improvised twice —
once per workspace — and the two improvisations meet in production.

## Solution

A deliberately dumb backend, fully specified: **one** generic encrypted-entity
log (`sync_entities`), **one** per-user epoch row (`sync_state`), **one** RLS
policy pattern, and **three** Edge Functions (`sync_push`, `sync_pull`,
`sync_reset`) with closed request/response contracts. The server stores and
returns opaque blobs, compares exactly two things it owns (one timestamp, one
integer), and interprets nothing else.

## User stories

1. As the backend, I store and return encrypted blobs I can never read, so that
   the E2EE promise holds by construction, not by policy.
2. As the backend, I reject a push whose row-level `updated_at` is older than
   what I hold, so that a stale device can never destroy newer data (the server
   keeps only the latest version per row).
3. As the backend, I assign a gap-safe, per-user monotonic `server_seq` to every
   accepted write, so that a pulling client can never skip a row at the cursor
   boundary.
4. As the backend, I reject any push or pull carrying a stale `key_epoch`, so
   that a device that missed a cloud reset can never pollute the account with
   old-key ciphertext.
5. As an authenticated user, I can erase all my cloud data atomically and start
   over with a new key, so that losing every key locks me out of old ciphertext
   but never out of the app.
6. As any other user, I can never read, write, or reset rows that are not mine
   (RLS), even if the Edge Function layer has a bug.

## Backend implementation decisions

### 1. SQL schema (binding DDL — one migration)

```sql
CREATE TABLE sync_entities (
  user_id           UUID NOT NULL,        -- RLS anchor (auth.uid())
  id                UUID NOT NULL,        -- client-generated UUIDv4
  table_name        TEXT NOT NULL,        -- 'sheet'|'column'|'row'|'cell'|'reminder'
  server_seq        BIGINT NOT NULL,      -- per-user monotonic, trigger-assigned
  updated_at        TIMESTAMPTZ NOT NULL, -- client LWW timestamp (the push guard)
  deleted_at        TIMESTAMPTZ,          -- tombstone marker
  sync_version      BIGINT NOT NULL,      -- stored, never branched on
  device_id         UUID NOT NULL,
  encrypted_payload TEXT,                 -- E2EE blob; NULL iff tombstone
  PRIMARY KEY (user_id, id),
  CHECK (encrypted_payload IS NOT NULL OR deleted_at IS NOT NULL)
);

CREATE INDEX idx_sync_entities_pull ON sync_entities (user_id, server_seq);

CREATE TABLE sync_state (
  user_id    UUID PRIMARY KEY,            -- created lazily on first push/pull
  key_epoch  BIGINT NOT NULL DEFAULT 0
);
```

Binding schema decisions:

- **One generic table, not five mirrored ones.** The server never filters by
  entity type, never joins, enforces no relational meaning — five identical
  tables would be five RLS policies, five triggers, and five places to drift.
  (Industry precedent: Standard Notes' `items` log.)
- **No foreign-key constraints, anywhere.** FKs travel *inside*
  `encrypted_payload`; the server cannot validate meaning it cannot read.
  Referential integrity is owned where the merge logic lives — on the client.
  This also makes multi-batch push order fully irrelevant (no toposort, no
  `INITIALLY DEFERRED`).
- **`encrypted_payload` is nullable with the CHECK above.** A tombstone nulls
  its payload server-side — dead ciphertext is not retained.
- **`table_name` stays plaintext deliberately**: a tombstone with a null payload
  must still be routable to the right local table on the client. Leaking
  entity-type counts is the accepted (trivial) baseline for E2EE systems.
- **`server_seq` is assigned by a trigger on INSERT *and* UPDATE** from a
  per-user counter — plain `BIGSERIAL` fires only on insert and is insufficient.
- **`sync_version` is stored, never branched on** — it is client-side semantics
  only (0 = never pushed → local hard delete).

### 2. Concurrency rule (binding — closes the sequence-cursor gap)

`sync_push` and `sync_reset` take
**`pg_advisory_xact_lock(hashtext(user_id::text))`** at the top of their
transaction. Sequence values commit out of order under concurrency; an
unserialized pull can advance its cursor past a not-yet-committed lower
`server_seq` and lose that row forever. Serializing *per user* (different users
remain fully parallel) makes `server_seq` gap-safe. The only same-user
concurrent writers are the user's own devices — exactly the race that must be
serialized.

### 3. RLS policies

- `sync_entities`: enable RLS; single policy — `auth.uid() = user_id` for
  SELECT / INSERT / UPDATE / DELETE.
- `sync_state`: enable RLS; same pattern.
- Edge Functions run with the **user's JWT** (anon key + Authorization header),
  not the service role — RLS is the backstop even if handler logic is buggy.
  No service-role usage anywhere in MVP.

### 4. Edge Functions (three — the complete surface)

Each follows the mandated split: `index.ts` (HTTP + JWT validation only) →
`handler.ts` (orchestration, no SQL) → `service.ts` (pure domain logic,
injected `Clock`) → `repository.ts` (the only SQL/Supabase-client layer).
Shared: `_shared/logger.ts`, `_shared/clock.ts`, `_shared/errors.ts`,
`_shared/auth.ts`.

#### `POST /functions/v1/sync_push` — auth: required (user JWT)

Request: `{ key_epoch: number, items: SyncItem[] }`, max **500** items, where

```
SyncItem = { table: 'sheet'|'column'|'row'|'cell'|'reminder', id: uuid,
             updated_at: timestamptz, deleted_at: timestamptz|null,
             sync_version: number, device_id: uuid,
             encrypted_payload: string|null }   // null iff deleted_at set
```

Behaviour (single transaction, advisory lock held):
1. Lazily create the user's `sync_state` row; compare `key_epoch` — mismatch →
   `409 { error, code: 'epoch_mismatch' }`, nothing written.
2. Per item: conditional upsert — write only if the row is new or
   `incoming.updated_at >= existing.updated_at`; stale items are **silently
   skipped** (never fail the batch). If `deleted_at` is set, store
   `encrypted_payload = NULL`.
3. Every accepted write gets the next per-user `server_seq` (trigger).
4. Response `200`: `{ applied_count: number, key_epoch: number }` — **no
   per-row applied/stale statuses**; stale state reconciles on the client's
   next pull. >500 items → `400 { code: 'batch_too_large' }`.

#### `POST /functions/v1/sync_pull` — auth: required (user JWT)

Request: `{ key_epoch: number, cursor: number, batch_size: number ≤ 500 }`.
Behaviour: epoch check as above; then
`SELECT … WHERE user_id = auth.uid() AND server_seq > :cursor
ORDER BY server_seq LIMIT :batch_size`.
Response `200`:
`{ changes: SyncItem&{server_seq}[], next_cursor: number, has_more: boolean,
key_epoch: number }`. The client loops until `has_more = false` and stores the
last `server_seq` as its cursor.

#### `POST /functions/v1/sync_reset` — auth: required (user JWT)

Request: `{}` (identity comes from the JWT; resets **own** data only).
Behaviour (single transaction, advisory lock held): delete all of the user's
`sync_entities` rows **and** increment `sync_state.key_epoch` atomically.
Response `200`: `{ key_epoch: number }` (the new epoch). The per-user sequence
is **not** reset (cursors held by other devices stay behind the new rows; their
next interaction 409s on the epoch anyway).

Error envelope everywhere: `{ error: string, code: string }` with codes
`epoch_mismatch` (409), `batch_too_large` (400), `unauthorized` (401),
`invalid_request` (400).

### 5. What the server never does (binding prohibitions)

No decrypting or parsing `encrypted_payload`; no merge logic beyond the single
`updated_at` guard; no branching on `sync_version`, `table_name` semantics, or
payload contents; no FK enforcement; no schema knowledge of sheets/columns/
rows/cells beyond the discriminator string; no custom auth functions
(`signInWithOtp` is built-in Supabase Auth, called by the app directly).

## Sync contract surface (what the app relies on — duplicated verbatim in the app companion PRD)

- Push: `{key_epoch, items[≤500]}` → `200 {applied_count, key_epoch}`;
  stale rows silently skipped; tombstones null the payload.
- Pull: `{key_epoch, cursor, batch_size}` → `{changes[], next_cursor,
  has_more, key_epoch}`; gap-safe `server_seq` cursor.
- Reset: `{}` → `{key_epoch}`; atomic delete + epoch bump.
- Epoch guard: stale `key_epoch` → `409 epoch_mismatch` on push and pull.
- Plaintext universe (complete): `user_id, id, table_name, server_seq,
  updated_at, deleted_at, sync_version, device_id`. Everything else —
  including FKs and `field_timestamps` — is inside `encrypted_payload`.
- Timestamp clamp (client-side, binding): clients stamp every edit with
  `max(clock.now, existing.updated_at + 1 ms)` (applied identically per entry
  of a reminder's `field_timestamps`), so a stale-skipped push can only ever
  concern data a pull has already superseded — backward clock skew cannot
  cause permanent divergence. The server gains no logic from this rule.
- Re-push rule (client-side, binding, general — not tie-specific): after
  **any** pull-merge whose result differs from the pulled server version, the
  client marks the row dirty and re-pushes; the `>=` guard accepts it. This —
  not per-row push statuses — is how locally-surviving fields reach the
  server after a concurrent different-field merge or a silently-skipped stale
  push. Terminates: the merged re-push is a superset, so the peer's merge of
  it is a no-op.
- Equal-timestamp ties resolve **client-side** by a deterministic tie-break
  (higher `device_id`; per-field reminder ties by lexicographically greater
  serialized value); a local tie-break win is one instance of the general
  re-push rule above. **The server has no tie logic** — its only comparison
  remains the conditional-upsert guard.
- Payload versioning (`v` field) and migration are entirely client-side.

## Testing decisions

Integration tests against local Supabase (`supabase start`); unit tests with
in-memory fakes and injected `Clock` per `docs/architecture/testing.md`.

- **LWW guard:** older `updated_at` skipped; equal `updated_at` applied (`>=`);
  newer applied; mixed batch commits non-stale items.
- **Advisory-lock serialization:** two concurrent pushes for one user produce
  no cursor gap (a pull at any point never permanently misses a row); two
  different users push fully in parallel.
- **Cursor pagination:** exact batch boundaries, `has_more` correctness,
  `next_cursor` monotonicity.
- **Epoch:** stale-epoch push rejected with nothing written; stale-epoch pull
  rejected; reset is atomic (rows gone + epoch bumped, or neither); epoch echoed
  on every success path; lazy `sync_state` creation on first contact.
- **Tombstones:** push with `deleted_at` stores `NULL` payload; CHECK constraint
  rejects a live row with no payload.
- **RLS isolation:** user A cannot select, upsert, or reset user B's rows —
  tested at the SQL level with two JWTs, independent of handler logic.
- **Validation:** 501-item batch → 400; missing fields → 400; no JWT → 401.

## Out of scope

Server-side merge or conflict resolution of any kind; reading or validating
`encrypted_payload`; FK constraints; per-row push result statuses; custom auth
Edge Functions; key custody or key reset (the server never holds key material);
multi-user sharing; webhooks; background jobs; service-role code paths.

## Architecture doc amendments (first implementation tasks; this PRD is the source until they land)

1. `docs/architecture/schema.md`: replace the per-table sync conventions with
   the single-table model above (nullable `encrypted_payload` + CHECK,
   `server_seq`, `sync_state`); the `<!-- SCHEMA -->` fence regenerates from the
   migration via `make gen`.
2. `docs/architecture/functions.md`: add the three function contracts exactly as
   specified in §4, including the advisory-lock rule and error codes.
3. `docs/architecture/testing.md`: add the advisory-lock/cursor-gap and epoch
   test obligations if not already implied.
