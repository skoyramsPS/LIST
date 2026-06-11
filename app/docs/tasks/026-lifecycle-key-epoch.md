# 026: Sign-in/merge lifecycle + key_epoch

**Type:** AFK
**Status:** pending
**Blocked by:** 025
**Harness stages exercised:** test / grep-gates

## What to build

The four account/encryption lifecycle phases and the epoch guard, as engine
behaviour with faked transport/auth (`sync.md` §5 as amended; companion §3;
master PRD §10). The ceremony *UI* is 027 — this task makes the engine states
real and testable:

- **Phase 1** local-only: no keys, no network, nothing syncs.
- **Phase 2** later sign-in, empty cloud: generate key → encrypt existing local
  rows → push.
- **Phase 3A** data found: engine surfaces a blocked state requiring
  key-acquisition; on unlock: pull → decrypt → write local.
  **3B** empty account: generate key, start primed.
- **Phase 4** two-history merge, order binding: prove the key against real
  cloud data first (wrong phrase fails safe having touched nothing) → pull &
  insert cloud rows (UUIDs never collide) → stamp local rows, encrypt, bump
  `sync_version`, **preserving each row's existing edit timestamps** → push.
- **`key_epoch`:** stored, sent on every push/pull; on `409 epoch_mismatch`
  erase the local key, halt, surface the Phase-3A unlock state; local plaintext
  untouched and re-merged under the new key via the normal Phase-4 path.
- **`eraseCloudAndRestart()`:** calls `reset()`, adopts the new epoch, fresh key.

Matrix additions: Phase-4 merge preserves original timestamps (LWW honest
across the merge boundary); reset-while-peer-offline → peer reconnects → 409 →
re-unlock under the new key → converges.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Wrong-phrase Phase-3A/4 attempt mutates nothing (fail-safe proven by decrypt failure against fake cloud data)
- [ ] Phase-4 test: pre-merge local edit timestamps survive the merge verbatim; a *newer* cloud edit still beats an older local one afterwards
- [ ] 409 on push **and** pull each: key erased, engine halted in unlock state, local plaintext rows intact
- [ ] Reset-while-peer-offline matrix case converges end-to-end
- [ ] `sync_version` bump on first encryption of pre-existing local rows
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No `DateTime.now()` in `lib/sync/`
- No Supabase import outside `lib/sync/` (auth is still faked here; real OTP wiring is 027/028)

## Notes

The engine's `status` stream is where Phase-3A blocking and "halted: epoch
mismatch" surface — 027 renders these states; design them as explicit enum
states, not strings.
