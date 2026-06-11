# 024: Sync engine core + basic convergence matrix

**Type:** AFK
**Status:** pending
**Blocked by:** 001, 002, 023
**Harness stages exercised:** test / grep-gates / analyze

## What to build

The heart of the project (`sync.md` §1–§3, §7 as amended; companion §3–§4):
`SyncEngine` in `lib/sync/` with the closed public interface `syncNow()`,
`status` (stream), `eraseCloudAndRestart()` — nothing else — proven convergent
with two in-memory clients and no network.

- **`SyncTransport` interface** — `push(batch)`, `pull(cursor, n)`, `reset()` —
  plus `FakeMemoryTransport` (an in-memory log of encrypted blobs with
  `server_seq` and the server's only rule: conditional upsert
  `incoming.updated_at >= existing.updated_at`, silent skip otherwise).
- **Payload v1 encode/decode:** each entity serialized to its canonical v1
  shape (FKs and `field_timestamps` **inside** the payload), encrypted via
  `PayloadCipher` with `(table_name, id)` AAD; plaintext on the wire is exactly
  `user_id, id, table_name, server_seq, updated_at, deleted_at, sync_version,
  device_id`. Payload `v` field + lazy up-migration hook at decrypt.
- **Push:** dirty-tracked rows in batches of 500; tombstones with null payload.
  **Pull:** cursor = last `server_seq`, loop until `has_more = false`.
- **Single-scalar LWW merge** (cells, sheets, columns, rows): higher
  `updated_at` wins; pure merge functions, no I/O inside merge.
- **Basic convergence matrix:** two `InMemoryDrift` databases + one
  `FakeMemoryTransport` + `FakeClock`; example-based divergent edit
  interleavings; assert identical final state regardless of order. Include:
  stale-push-then-pull reconciliation; tombstone-with-null-payload; payload `v`
  up-migration.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] The convergence matrix passes: any tested interleaving of the same edits on two clients yields byte-identical final state
- [ ] Wire shape test: pushed items expose exactly the eight plaintext fields; everything else is inside `encrypted_payload`
- [ ] Batching test: 1,201 dirty rows push as 500/500/201; pull loops cursors until `has_more = false`
- [ ] All timing/size values come from a single `SyncConstants` declaration in `lib/sync/` (batch 500, debounce 2 s, periodic 5 min, backoff 2 s ×2 cap 5 min ±20 %, undo window 5 s)
- [ ] Merge functions are pure (no I/O) and unit-tested in isolation
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- **No `DateTime.now()` in `lib/sync/`** — injected `Clock` only
- **No Supabase import outside `lib/sync/`** — and none at all in this task (`FakeMemoryTransport` only; the real transport is 028)
- No Drift import outside `lib/repositories/` / `lib/data/` — the engine reads/writes through repository-level interfaces

## Notes

Reminders' per-field merge, the timestamp clamp, tie-breaks, and the re-push
rule are deliberately deferred to 025 so this slice stays provable. The
internal trigger scheduling (debounce/foreground/periodic/backoff) is wired in
028 — here `syncNow()` is invoked explicitly by tests.
