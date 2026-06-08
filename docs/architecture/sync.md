# Sync, Encryption & Scheduling — the distributed core

This is the load-bearing engine and the thing this project exists to
demonstrate: a **local-first app with a true end-to-end-encrypted, offline-capable
multi-device sync engine**. A local-only app proves you can query SQLite; this
proves conflict resolution, distributed convergence, and a real E2EE trust model.

Source code: `lib/sync/` (the only layer that touches Supabase), `lib/crypto/`
(keys + payload encryption), `lib/notifications/` (the scheduler).

---

## 1. The dumb server

Supabase is **not** a smart backend. It is an authenticated, RLS-guarded,
append/upsert **log of opaque encrypted blobs plus plaintext LWW metadata**. It
performs **no merging, no ordering, no arithmetic** on any field. It cannot,
because it cannot read the data.

- `sync_push`: authenticated, RLS-guarded upsert of `{ id, foreign keys,
  sync_version, device_id, deleted_at, timestamps, encrypted_payload }`.
- `sync_pull`: "give me every row where `server_updated_at > my_cursor`".

All intelligence — decrypt, compare timestamps, apply LWW, re-materialize
formulas — runs **on-device** after pull. The server merging fields would require
the server to read them, which would break E2EE. The two are mutually exclusive;
we chose E2EE.

## 2. The merge: per-field Last-Write-Wins, client-side

- **Single-scalar entities** (cells, sheets, columns, rows): one `updated_at`
  *is* the field-timestamp. Merge = higher timestamp wins. A Cell is a degenerate
  **LWW-Register**.
- **Multi-field entities** (reminders): carry a `field_timestamps`
  `{field_name: epoch_ms}` map + client-side `pending_changed_fields` dirty
  tracking. Merge is **per field** by timestamp, so two devices editing different
  fields of the same record never clobber each other.

Convergence property: applying any interleaving of the same set of edits, in any
order, on any number of devices, yields **identical final state**. This is what
the convergence test matrix asserts (§7).

## 3. The E2EE payload boundary (one uniform rule, all tables)

Every synced row splits into two parts:

1. **Plaintext sync metadata** — `id`, foreign keys (`sheet_id`, `row_id`,
   `column_id`), `sync_version`, `device_id`, `deleted_at`, and the LWW
   timestamps (`updated_at` or the `field_timestamps` map, whose **keys** are
   logical field names). The server needs these to do its dumb job; none are
   secret.
2. **One `encrypted_payload` blob** — *all* domain data (names, icons, cell
   values, JSON type-configs, recurrence rules, notes) serialized to one JSON
   object and encrypted with the Sync Master Key.

Because foreign keys are opaque UUIDs and column meaning lives inside the
encrypted payload, the server sees a graph of meaningless IDs and timestamps. It
learns *that* a row has three cells and *when* they changed — never *what* they
are. **Accepted tradeoff:** this metadata leakage (field count, change times) is
harmless for a list app and buys enormous simplicity.

## 4. Keys: auth and encryption are fully decoupled

**Supabase Auth controls *access*. The user's key controls *decryption*. The
server has zero custody of the key.**

- On first sync, the client generates a cryptographically random **256-bit Sync
  Master Key**, stored in the OS Secure Enclave (iOS Keychain / Android Keystore).
- The key is portable to other devices two ways (model **B + C**):
  - **B — 24-word recovery phrase.** Shown **once**, with an unmissable warning:
    "Write this down. We cannot reset it for you." Survives password reset and
    forgotten passwords.
  - **C — device-to-device QR transfer.** Device 1 displays a QR in Settings;
    Device 2 scans it to import the key directly, no server custody.
- **No SQLCipher.** The local Drift DB is **plaintext on disk**, relying on the OS
  app sandbox at rest (the same posture as Signal/WhatsApp local stores). SQLCipher
  guarded a weaker threat (physical rooted-device extraction) at a real debugging
  and key-management cost. E2EE — encrypting before the byte leaves the device —
  is the threat model that matters and is fully intact.

## 5. The account/encryption lifecycle (four phases)

**Phase 1 — Local-only (default).** Open app, no onboarding wall, no account, no
network. Sheets/rows/reminders write to local plaintext Drift. No keys exist
yet. Lightning fast, zero friction.

**Phase 2 — Later sign-in, empty account.** User has local data, signs in,
cloud has none. App generates the Master Key, stores it in the Enclave, shows the
recovery-phrase screen, then encrypts existing local rows and pushes them.

**Phase 3 — Immediate sign-in (new device or fresh user).**
- *Branch A (data found):* app blocks the Sheets tab — "Encrypted data found.
  Scan QR from your other device or enter your 24-word phrase." On unlock: derive
  key → save to Enclave → `sync_pull` → decrypt → write plaintext into local
  Drift.
- *Branch B (no data):* brand-new account. Generate key, save, show recovery
  phrase, start empty-but-primed; the background worker encrypts and pushes as the
  user creates sheets.

**Phase 4 — Two-history merge** (local data *and* cloud data both exist). Order
matters — prove the key before mutating local state:
1. Acquire key (QR or phrase) — a successful decrypt of real cloud data proves
   the key is valid, so a wrong phrase fails safe having touched nothing.
2. Pull & decrypt cloud rows, insert into local Drift (clean inserts — UUIDs
   never collide).
3. Stamp existing local rows with `user_id`, encrypt, bump `sync_version` —
   **preserving each row's *existing* edit timestamps**, not "now", so LWW stays
   honest across the merge boundary.
4. Push the newly-encrypted local rows. UI reacts; local and cloud sheets sit
   side by side. (Semantic duplicates are possible and acceptable — the user
   deletes one; nothing is ever lost.)

## 6. Deletion across devices

- **Deferred tombstone (pre-commit window).** On "Delete", Riverpod hides the row
  immediately, but the Drift write of `deleted_at` + the dirty-flag for push does
  **not** fire until the 5-second snackbar timer completes. Hard-swiping the app
  closed mid-window leaves the row alive — an interrupted delete is safe.
- **Undo is local-only and ephemeral** — a UI state, never a DB op, never a
  resurrection across devices. Once a tombstone commits it is permanent
  everywhere. There is no cross-device undo by design (that would be Trash, a
  non-goal).
- **`sync_version` optimization.** `sync_version == 0` (never left the device) →
  deletion is a hard SQL `DELETE` (e.g. abandoned empty rows — no phantom keys on
  the wire). `sync_version > 0` (server has seen it) → soft `UPDATE deleted_at`.
- Tombstones are **retained forever locally** — hard-deleting one would let a
  stale device re-push the row as alive.

## 7. Testability is architecture, not an afterthought

The engine is built against **injected abstractions** so convergence is provable
deterministically with no network:

- **Injected `Clock`** — `DateTime.now()` is banned in the engine (grep-gated). A
  fake clock makes time-dependent logic reproducible; any internal `DateTime.now()`
  call makes a fake-clock test fail.
- **Injected `SyncTransport`** — production hits Supabase; tests use
  `FakeMemoryTransport`, an in-memory list of encrypted blobs.
- **Pure merge functions** — no I/O inside merge.

**The convergence matrix:** spin up two `InMemoryDrift` databases sharing one
`FakeMemoryTransport`, apply divergent edit sequences, flush + pull, assert
**identical final state regardless of order**. Runs in milliseconds. Start with
example-based interleavings; add randomized/property-based interleavings only once
the basic merge is solid.

## 8. The notification scheduler & recurrence

Recurrence is the source of truth in the `reminders` table; the OS holds only a
materialized near-term slice.

**Budget by global nearest-N alert-instances, not a time window.** The binding
constraint is iOS's **64 pending-notification cap**. The schedulable unit is the
**alert-instance** = `reminder × offset × occurrence-date`. The scheduler
materializes the soonest **N ≈ 60** alert-instances across *all* reminders
(headroom under 64), plus a **safety horizon** (don't schedule past ~12 months
out even if the budget isn't full — prevents a lone far-future daily reminder from
enumerating forever).

- **Foreground is the authoritative replenish trigger.** iOS background execution
  is opportunistic; `workmanager`/background is best-effort bonus only. The design
  is correct on foreground alone.
- **Replenish = idempotent reconcile, not append.** Each pass recomputes the
  desired next-N set and **diffs** against what's actually scheduled (cancel stale,
  add missing, leave matches). Notification IDs are **deterministic** =
  `hash(reminder_id, offset, occurrence_date)`, never random, so the diff matches.
- **Notification IDs and the scheduled slice are device-local and never synced.**
  Each device materializes its own slice from the synced `reminders` rows.

### Recurrence grammar (serialized into the encrypted `recurrence_rule` payload)

```json
{
  "freq": "none|daily|weekly|monthly|yearly",
  "interval": 1,            // >= 1, default 1. Enables quarterly (monthly×3), biweekly, etc.
  "byWeekday": [1, 3, 5],   // 1=Mon .. 7=Sun. Used only when freq=weekly.
  "anchor": 1717511127000   // epoch ms. Also dictates the target wall-clock TIME.
}
```

Enforcement rules for the implementer (each is a test):

1. **Clamp, never skip.** Monthly/Yearly clamp to the end of the month, never
   skipping an occurrence: Jan 31 → Feb 28/29 → Mar 31 → Apr 30. A renewal tracker
   that silently skips a month has failed at its one job.
2. **Clamp from the anchor, never from the prior result.** Each occurrence is the
   anchor's intended day-of-month clamped into the target month — re-derived from
   the anchor (31), not walked from Feb's clamped 28. (This is the single most
   common recurrence bug.)
3. **Civil-time rule (DST-safe).** Extract civil date + civil time from the anchor
   in the user's *current* timezone; build each occurrence by adding the frequency
   to the civil date, re-appending the exact civil time, then converting to a UTC
   instant for scheduling. 9:00 AM always means 9:00 AM local, across DST and
   travel.
4. **Lazy generator.** A Dart `sync*` generator yields occurrences on demand,
   multiplies by `alert_offsets`, merges across all active reminders, sorts by
   nearest-in-time, and stops the instant the global ≈60 budget (or the safety
   horizon) is reached. Infinite recurrences must never enumerate to infinity.
