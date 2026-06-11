# TheLIST — App Implementation PRD (companion)

**Status:** draft
**Created:** 2026-06-10
**Workspace scope:** app (companion to the cross-cutting master spec)
**Relates to:** `docs/planning/active/the-list/PRD.md` (monorepo root, the "What");
backend companion: `backend/docs/planning/active/the-list/PRD.md`

> **Contract rule.** This PRD is *mortal*. Every binding implementation decision
> below must land in the *immortal* architecture docs as its first implementation
> task (see §"Architecture doc amendments" at the end); once amended, the
> architecture docs are authoritative and this PRD is archived. The **sync wire
> contract** section is duplicated verbatim in the backend companion PRD by
> design — it is the shared boundary; any change to it must update both PRDs (and
> later both `sync.md` and `backend/docs/architecture/functions.md`) in the same
> commit, per root `AGENTS.md §4`.

---

## Problem statement

The master PRD defines *what* TheLIST does but leaves implementation-level
contracts open: the exact cryptography, the sync wire protocol, the screen-level
UX, and the module decomposition. Unspecified contracts become improvised
contracts, which become bugs — especially at the app↔backend boundary and in
E2EE code where mistakes are silent and permanent.

## Solution

Fix every open contract explicitly: a 12-word BIP-39 + HKDF + XChaCha20-Poly1305
crypto chain; a `server_seq`-cursored, epoch-guarded, LWW-upsert wire protocol
against a single `sync_entities` log; a complete screen/bottom-sheet/ceremony
inventory; and a deep-module map with closed public interfaces. Nothing in this
document is open to interpretation.

## User stories

1. As a user, I want to use the app fully offline with no account, so that there
   is zero friction and zero data leaves my device (master PRD Phase 1).
2. As a user, I want to sign in with only my email and a 6-digit code, so that
   there is no password to create, remember, or reset.
3. As a user, I want my data end-to-end encrypted with a key only I hold, so
   that the server operator can never read it.
4. As a user, I want a 12-word recovery phrase shown once at key creation and
   re-viewable later behind my device unlock, so that I can always write it down
   again while I still have a signed-in device.
5. As a user, I want to link a new device by scanning a QR code from my old
   device, so that I never have to type the phrase when both devices are present.
6. As a user on a new device, I want to unlock my encrypted cloud data by QR or
   by typing my 12 words (with per-word autocomplete and checksum validation
   before any network call), so that unlocking is fast and typo-proof.
7. As a user who lost both phrase and devices, I want an explicit "erase cloud
   data and start over" path, so that I am never permanently locked out of the
   *app* even though the old ciphertext is unrecoverable (E2EE keeping its promise).
8. As a user's second device, I want any interleaving of offline edits on both
   devices to converge to an identical final state after sync, so that no edit
   is ever silently lost (per-field LWW; convergence matrix).
9. As a user's second device that was offline during a cloud reset, I want to be
   cleanly halted and asked to re-unlock with the new key, so that I never
   pollute the account with old-key ciphertext.
10. As the notification system, I want reminders materialized deterministically
    from synced recurrence rules on each device, so that notifications survive
    sync without ever being synced themselves.
11. As a user, I want sync to be invisible and self-managing (no spinners, no
    sync buttons in the main UI), so that the app stays calm and offline-first.

## App implementation decisions

### 1. Cryptography (binding chain — every byte specified)

- **Entropy:** 128 random bits (16 bytes), generated once on first sync
  (lifecycle Phase 2 or 3B), via the platform CSPRNG.
- **Recovery phrase:** BIP-39 encoding of those 16 bytes → **12 words** with
  built-in checksum. The `bip39` package is used **only** for
  encode/decode/checksum — BIP-39's PBKDF2 seed-stretching step is deliberately
  **not** used (it hardens human passphrases; our entropy is already full-strength).
- **Key derivation (the single derivation path for both phrase and QR):**

  ```
  master_key = HKDF-SHA256(
      ikm:  entropy,            // the raw 16 bytes — NOT the BIP-39 PBKDF2 seed
      salt: "thelist.sync.v1",
      info: "master-key",
      length: 32 bytes)
  ```

- **Key storage:** the derived 32-byte key in iOS Keychain / Android Keystore.
  The entropy is re-derivable from the phrase only; it is not stored.
- **QR transfer payload:** the **16 entropy bytes** (not the derived key, not
  the words), so QR and phrase converge on the identical derivation.
- **Cipher:** **XChaCha20-Poly1305** (AEAD). One fresh random **192-bit nonce
  per encryption**, prepended to the ciphertext; the whole frame is base64url
  encoded into `encrypted_payload`. Rationale: random nonces are unconditionally
  safe at 192 bits; AES-GCM's 96-bit nonce is a birthday-bound liability when
  multiple offline devices encrypt thousands of cells with no coordinator.
- **AAD:** every blob's associated data is `(table_name, id)` — a ciphertext can
  never be replayed into a different row or table by a buggy/malicious server.
- **No key-check value (KCV):** the BIP-39 checksum catches input typos; the
  Poly1305 tag fails closed on a wrong key when decrypting real cloud data
  (lifecycle Phases 3A/4). A wrong phrase therefore fails safe having touched nothing.
- **No key rotation (explicit non-goal):** per-cell encryption means rotation =
  pull-all, decrypt-all, re-encrypt-all, push-all. Out of scope for MVP.
- **New dependencies to declare in `pubspec.yaml`** (raise-first rule satisfied
  in the grill session): `cryptography`, `cryptography_flutter` (platform-
  accelerated delegates), `bip39`, `local_auth`, plus a QR display/scan
  capability (e.g. `qr_flutter` + `mobile_scanner` — confirm exact packages at
  task time; they are the only remaining package choice).

### 2. Encrypted payload schemas (versioned, canonical)

All domain data — **including foreign keys and `field_timestamps`** — lives
inside `encrypted_payload`. Every payload carries `v` (integer, starts at 1).
The client up-migrates older `v` lazily at decrypt time; the server can never
migrate what it cannot read. Canonical v1 shapes (field names binding):

| `table_name` | Payload v1 fields |
| --- | --- |
| `sheet` | `v, name, icon, category, currency_code, is_pinned, position, template_kind, is_template` |
| `column` | `v, sheet_id, name, data_type, semantic_role, position, is_hidden, config, default_value` |
| `row` | `v, sheet_id, position` |
| `cell` | `v, row_id, column_id, value, is_overridden` |
| `reminder` | `v, sheet_id, row_id, target_date, recurrence_rule, alert_offsets, is_enabled, field_timestamps` |

Notes: `config` is the column's type-specific JSON (dropdown options, formula
definition, currency code, reminder presets). `value` is the cell's single
scalar; its type is dictated by the owning column's `data_type` (typed-slot rule,
`data_model.md §3`). `recurrence_rule` is the grammar in `sync.md §8`.
`field_timestamps` is `{field_name: epoch_ms}` — per-field LWW runs on-device;
the row-level `updated_at` sent as plaintext is the **max** of the field timestamps.

### 3. Sync engine (self-scheduling deep module)

- Public interface (complete): `syncNow()`, `status` (stream),
  `eraseCloudAndRestart()`. Nothing else. No screen ever orchestrates sync.
- Internal triggers: trailing **2 s** debounce after the last local write;
  immediate sync on app foreground/resume; **5 min** periodic pull while
  foregrounded; none in background (foreground-authoritative, matching the
  notification scheduler's posture). Retry: exponential backoff, **2 s base,
  ×2, cap 5 min, ±20 % jitter**, reset on success or connectivity-restored.
- All constants live in one `SyncConstants` declaration in `lib/sync/`; docs and
  tests reference the same named values (see constants table below).
- **`key_epoch` handling:** the engine stores the server-issued `key_epoch`,
  sends it on every push/pull, and on `409 epoch_mismatch` erases the local key,
  halts, and presents the Phase-3A unlock state ("This account's encryption was
  reset from another device"). Local plaintext data is untouched and re-merges
  under the new key via the normal Phase-4 path.
- The four sign-in/merge lifecycle phases, deferred-tombstone deletion, and the
  `sync_version == 0` hard-delete optimization are as locked in `sync.md` §5–6.

### 4. Sync constants (binding values)

| Constant | Value |
| --- | --- |
| Push/pull batch size | exactly 500 items |
| Write-triggered sync debounce | 2 s trailing |
| On foreground/resume | immediate `syncNow()` |
| Foreground periodic pull | every 5 min; none in background |
| Retry backoff | 2 s base, ×2, cap 5 min, ±20 % jitter |
| Notification budget | N = 60 alert-instances, 12-month safety horizon |
| Undo snackbar / tombstone commit window | 5 s |
| OTP | Supabase defaults: 6-digit, 60 s resend cooldown, 1 h expiry |

### 5. Auth

Supabase built-in `signInWithOtp` (email, 6-digit code) called from `lib/sync/`
(the only layer permitted to touch Supabase). **No passwords. No OAuth/social
login** (also sidesteps App Store rule 4.8 / Sign in with Apple obligation).
**No custom auth Edge Function exists** — auth recovery is "get a new code",
fully decoupled from the encryption key.

### 6. Deep module map (public interfaces are the complete surface)

| Module | Public interface (complete) | Hides |
| --- | --- | --- |
| Crypto — `KeyManager` | `generateKey()`, `keyFromPhrase(words)`, `keyFromQrBytes(bytes)`, `phrase`, `qrBytes`, `hasKey`, `eraseKey()` | BIP-39 dictionary/checksum, HKDF, Keychain/Keystore I/O |
| Crypto — `PayloadCipher` | `encrypt(json, aad)`, `decrypt(blob, aad)` | XChaCha20-Poly1305, nonce framing, base64url |
| Sync — `SyncEngine` | `syncNow()`, `status` stream, `eraseCloudAndRestart()` | lifecycle phases, batching, cursor, epoch, LWW merge, dirty-tracking, scheduling/retry |
| Sync — `SyncTransport` (interface) | `push(batch)`, `pull(cursor, n)`, `reset()` | `SupabaseTransport` (prod) / `FakeMemoryTransport` (tests) |
| Data — `AppDatabase` | Drift tables, DAOs, the two pivot Views (`v_subscriptions`, `v_waiting_on`) | SQL, STRICT DDL, indices |
| Repositories — **three, by aggregate** | `SheetRepository` (sheets + columns + rows + cells + formula recompute + fractional ordering + empty-row rule + atomic deep-copy), `ReminderRepository`, `AttentionRepository` (read-only Today pipeline) | transactions, EAV writes, cascade semantics |
| Notifications — `ReminderScheduler` | `reconcile()` | recurrence generator, clamp rules, 60-budget diffing, deterministic IDs, OS plugin |
| UI | `AppTokens` + `List*` components per `design_system.md` | — |
| State / Features | Riverpod providers / screens per `ux_spec.md` | orchestration only |

Repositories are **per aggregate, not per table** — a `CellRepository` beside a
`SheetRepository` is the local-first anti-pattern this map exists to prevent.

### 7. UX inventory (the contents of the new `ux_spec.md`)

Every screen is specified as: **purpose · layout (as `List*` composition) ·
states (empty/loading/error) · interactions · navigation in/out.** Markdown
only; the design system is constrained enough that a `List*` composition *is*
the wireframe.

- **Shell:** bottom-nav scaffold (Today / Sheets / Settings). `go_router` routes
  for tabs and full-screen views **only**; bottom sheets are local UI state,
  never routes (no modal stacking).
- **Core screens (7):** Today · Sheets list · Sheet view · Settings · Template
  picker · Manage templates · Onboarding (≤3 pages, one screen).
- **Bottom sheets (11):** cell editors for Date, Reminder, Notes, Formula,
  Dropdown, Link · row long-press menu · column settings · sheet settings
  (name/icon/category/currency) · save-as-template · **Sheet Deletion
  confirmation as an explicit destructive morph of the Sheet Settings sheet**
  (the one sanctioned use of `danger` red; single sheet morphs, never stacks).
- **Account & sync ceremony screens (5):** sign-in (email → OTP entry) ·
  recovery-phrase display ("write this down — we cannot recover it"; one
  confirm button "I wrote it down"; **no verification quiz**) · key entry
  (12-word input, per-word BIP-39 autocomplete, checksum validated before any
  network call) · QR display (Settings, device 1) · QR scan (device 2).
- **Phase-3A unlock** ("Encrypted data found — unlock with phrase or QR, or
  erase cloud data and start over") is an **inline blocking state of the Sheets
  tab**, not a route.
- **Secret-screen hardening:** phrase display and QR display are gated by a
  fresh `local_auth` prompt and carry screenshot/recording blocking
  (`FLAG_SECURE` / iOS equivalent). If the device has no screen lock:
  allow-with-warning banner, never hard-block (consistent with the
  no-SQLCipher local threat model).
- **Cross-cutting states:** Trial Limbo pinned card on Today;
  tap-to-navigate-and-pulse; soft-delete snackbar (5 s); quiet sync indicator in
  Settings only — no spinners in the main UI.

### 8. Layers affected / schema / harness

- **Layers:** all (UI, State, Repository, Data, Sync, Crypto, Notifications) —
  this is the greenfield build-out PRD.
- **Schema:** first Drift tables (`sheets`, `columns`, `rows`, `cells`,
  `reminders`, all `STRICT`, per `data_model.md`) → `data_model.md` generated
  fence must be regenerated via `dart run tool/gen_schema.dart`.
- **Harness prerequisites triggered — all three** (master PRD §22): §22a font
  assets land with the first `List*` component; §22b `_dumpSchema()` wired in
  the same commit as the first Drift table; §22c `custom_lint`/`riverpod_lint`
  activation lands with the first provider. Each must be its own explicit task.

## Sync contract boundary (shared verbatim with the backend companion PRD)

- **App writes (push):** `POST /functions/v1/sync_push` with
  `{ key_epoch, items: [≤500] }`; each item:
  `{ table: 'sheet'|'column'|'row'|'cell'|'reminder', id, updated_at,
  deleted_at, sync_version, device_id, encrypted_payload }` (payload null iff
  tombstone). Response `200`: `{ applied_count, key_epoch }`. Stale rows are
  silently skipped server-side; the client reconciles via the next pull —
  **no per-row applied/stale statuses.**
- **App reads (pull):** `POST /functions/v1/sync_pull` with
  `{ key_epoch, cursor, batch_size: 500 }` → `{ changes: [...], next_cursor,
  has_more, key_epoch }`; client loops until `has_more = false`; the stored
  cursor is the last `server_seq` seen.
- **Reset:** `POST /functions/v1/sync_reset` → atomically deletes all of the
  user's rows and increments `key_epoch`; response returns the new epoch.
- **Epoch guard:** push and pull return `409 epoch_mismatch` when the client's
  `key_epoch` is stale; the client halts and re-enters the unlock flow.
- **Encrypted (server-opaque):** all domain data — names, values, configs,
  recurrence, notes, **foreign keys**, and **`field_timestamps`**.
- **Plaintext (the complete server-readable universe):** `user_id, id,
  table_name, server_seq, updated_at, deleted_at, sync_version, device_id`.
- **Convergence behaviour:** per-field LWW on-device (single-scalar entities by
  row `updated_at`; reminders by `field_timestamps`); the server's only
  comparison is the conditional-upsert guard
  `incoming.updated_at >= existing.updated_at`. Any interleaving of the same
  edits on any devices yields identical final state.
- **Timestamp clamp (binding, client-side):** when stamping any edit,
  `updated_at = max(clock.now, existing.updated_at + 1 ms)` — applied
  identically to each entry in a reminder's `field_timestamps`. A device can
  never produce a timestamp older than the version it is editing on top of,
  so the server's silent-skip path can only fire for data a pull has already
  superseded. Without this, a device with a backward-skewed wall clock pushes
  a stamp older than the server's copy, is silently skipped, and — its cursor
  already past that row — diverges permanently. The clamp closes the hole
  with zero new server logic.
- **Re-push rule (binding, general — not tie-specific):** after **any**
  pull-merge whose result differs from the pulled server version, the row is
  marked dirty and re-pushed (the `>=` guard accepts it). This is what lands
  locally-surviving fields on the server after a concurrent different-field
  reminder merge or a silently-skipped stale push — the server holds the
  last-pusher's whole payload and cannot field-merge, so the client must
  re-push the merged superset. The rule terminates: the re-pushed merged
  version is a superset, the peer's merge of it is a no-op, so no ping-pong.
- **Tie-break (binding, client-side only):** equal timestamps resolve by a
  deterministic total order — the version with the **higher `device_id`** wins;
  for per-field reminder ties (where `field_timestamps` carries no per-field
  device id), the **lexicographically greater serialized field value** wins.
  A local tie-break win is simply one instance of the general re-push rule
  above (the server holds the last-pusher's copy, not necessarily the
  tie-break winner). The server needs no tie logic.
- **Migration path:** payload `v` field + lazy client-side up-migration at
  decrypt; the server never migrates payloads (it cannot read them).

## Testing decisions

- **Convergence matrix** (two `InMemoryDrift` + one `FakeMemoryTransport` +
  `FakeClock`): existing cases plus — stale-push-then-pull reconciliation;
  tombstone-with-null-payload; payload `v` up-migration; Phase-4 merge
  preserving original edit timestamps; **reset-while-peer-offline → peer
  reconnects → 409 → re-unlock under new key**; **equal-timestamp tie on the
  same field from two devices (both push orders) converges via the
  device_id/value tie-break, including the dirty-on-local-win re-push**;
  **backward-skewed clock on one device — the timestamp clamp keeps its edits
  propagating and both devices converge**; **concurrent different-field
  reminder edits, both push orders — the general re-push rule lands the full
  merged payload on the server and the re-push cycle terminates (no
  ping-pong)**.
- **Crypto:** round-trip; AAD-mismatch rejection; wrong-key fail-closed;
  phrase ↔ entropy ↔ QR equivalence vectors (fixed test vectors for the HKDF
  chain); BIP-39 checksum rejection.
- **Scheduler:** clamp-never-skip; clamp-from-anchor; civil-time/DST; budget
  cutoff at N = 60; deterministic ID stability — all against `FakeClock`.
- **Repository:** empty-row auto-delete rule; atomic deep-copy with column-id
  remap; formula recompute inside the writing transaction; fractional-index
  reorder writes only the moved row.

## Out of scope

Everything in master PRD §4, plus (made explicit in this session): encryption
key rotation; recovery-phrase verification quiz; OAuth/social login; custom
auth Edge Functions; position-key rebalancing; background-execution sync
guarantees; cross-device undo.

## Architecture doc amendments (first implementation tasks; this PRD is the source until they land)

1. `docs/architecture/sync.md` §4: 24→12 words; add the binding HKDF chain,
   cipher/nonce/AAD spec, and QR-carries-entropy rule.
2. `docs/architecture/sync.md` §3: FKs and `field_timestamps` move inside
   `encrypted_payload`; restate the (improved) leakage tradeoff; add the
   versioned payload schema table.
3. `docs/architecture/sync.md`: add the wire contract (§"Sync contract
   boundary" above), the `key_epoch` lifecycle, the timestamp-clamp rule, the
   general re-push rule, and the `SyncConstants` table.
4. **New** `docs/architecture/ux_spec.md` per §7 above; register it in
   `docs/architecture/index.md`.
5. `docs/architecture/design_system.md`: note the Sheet-Deletion destructive
   morph as the sanctioned `danger` usage if not already covered.
