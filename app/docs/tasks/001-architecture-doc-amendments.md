# 001: Land the architecture-doc amendments

**Type:** HITL
**Status:** pending
**Blocked by:** None — can start immediately
**Harness stages exercised:** doc-honesty / doc-coverage / format

## What to build

Move the binding implementation decisions from the mortal app companion PRD
(`docs/planning/active/the-list/PRD.md`, §"Architecture doc amendments") into the
immortal architecture docs, making them authoritative. This is the authority
handoff required by master PRD §22d and **must complete before any crypto or
sync implementation task (023–028)**.

Concretely:

1. `docs/architecture/sync.md` §4 — 24→12 words; add the binding derivation
   chain (128-bit CSPRNG entropy → BIP-39 12 words → HKDF-SHA256 with
   salt `"thelist.sync.v1"` / info `"master-key"` → 32-byte key), the
   XChaCha20-Poly1305 cipher spec (192-bit random nonce prepended, base64url
   frame), the `(table_name, id)` AAD rule, no-KCV rationale, and the
   QR-carries-entropy rule.
2. `docs/architecture/sync.md` §3 — foreign keys and `field_timestamps` move
   *inside* `encrypted_payload`; restate the (improved) leakage tradeoff; add
   the versioned payload schema table (v1 shapes for sheet/column/row/cell/reminder).
3. `docs/architecture/sync.md` — add the wire contract (push/pull/reset shapes,
   no per-row statuses), the `key_epoch` lifecycle and `409 epoch_mismatch`
   behaviour, the timestamp-clamp rule, the general re-push rule, the
   client-side tie-break, and the `SyncConstants` table.
4. **New** `docs/architecture/ux_spec.md` per companion PRD §7 (7 core screens,
   11 bottom sheets, 5 ceremony screens, Phase-3A inline blocking state,
   secret-screen hardening, cross-cutting states); register it in
   `docs/architecture/index.md`.
5. `docs/architecture/design_system.md` — note the Sheet-Deletion destructive
   morph as the sanctioned `danger` usage.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written — **N/A: doc-only task; the doc-honesty stage is the mechanical check here**
- [ ] `sync.md` §3 and §4 fully supersede the companion PRD amendments (no decision exists only in the PRD)
- [ ] The wire contract, `key_epoch`, timestamp clamp, re-push rule, tie-break, and `SyncConstants` table appear in `sync.md`
- [ ] `ux_spec.md` exists, covers the full companion §7 inventory, and is registered in `index.md`'s routing table
- [ ] `ux_spec.md` references **no `lib/...` paths that do not yet resolve** (doc-honesty stage extracts and checks them — describe layouts as `List*` compositions, not file paths)
- [ ] `design_system.md` documents the destructive-morph `danger` usage
- [x] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (the doc updates *are* the deliverable)

## Grep-gate obligations

None violated by doc work, but: no reference that resolves into `/_human/`.

## Harness prerequisites triggered (if any)

Master PRD **§22d** — this task *is* that prerequisite. Until it completes, the
companion PRD (not `sync.md`) is authoritative for §3/§4; after it completes,
the architecture docs are authoritative and tasks 023–028 may start.

## Notes

HITL: the human reviews the immortal docs before they become authoritative.
Watch the doc-honesty stage: every `lib/...` path written into any architecture
doc must resolve at verify time — phrase forward-looking content in terms of
modules and `List*` compositions, not source paths, until the code exists.
