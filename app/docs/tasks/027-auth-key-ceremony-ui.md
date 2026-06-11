# 027: Auth + key ceremony UI

**Type:** HITL
**Status:** pending
**Blocked by:** 026
**Harness stages exercised:** test / grep-gates

## What to build

The five ceremony screens plus the blocking state (master PRD §10; companion
§5, §7; `ux_spec.md`):

- **Sign-in:** email → 6-digit OTP entry via Supabase `signInWithOtp`, called
  from `lib/sync/` only. No passwords, no OAuth. OTP behaviour per Supabase
  defaults (60 s resend cooldown, 1 h expiry).
- **Recovery-phrase display:** "Write this down — we cannot recover it"; one
  confirm button "I wrote it down"; **no verification quiz**. Re-viewable from
  Settings behind a fresh `local_auth` prompt.
- **Key entry:** 12-word input with per-word BIP-39 autocomplete; checksum
  validated **before any network call**.
- **QR display** (Settings, device 1) and **QR scan** (device 2) carrying the
  16 entropy bytes.
- **Phase-3A unlock** as an **inline blocking state of the Sheets tab** (not a
  route): "Encrypted data found — unlock with phrase or QR, or erase cloud data
  and start over" (the erase path with explicit confirmation).
- **Secret-screen hardening:** phrase + QR display gated by fresh `local_auth`,
  screenshot/recording blocked (`FLAG_SECURE` / iOS equivalent); no device
  screen lock → allow-with-warning banner, never hard-block.
- Epoch-mismatch halt renders as "This account's encryption was reset from
  another device" → unlock flow.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Widget test: bad-checksum 12-word entry is rejected with **zero** transport/auth calls (faked transport asserts no traffic)
- [ ] Phrase display requires a fresh (faked) `local_auth` success; no-screen-lock path shows the warning banner and proceeds
- [ ] Phase-3A blocking state renders inside the Sheets tab and is not navigable-around
- [ ] Erase-and-restart path requires explicit confirmation and lands in the fresh-key state
- [ ] Per-word autocomplete restricts entry to the BIP-39 wordlist
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- **No Supabase import outside `lib/sync/`** — the OTP screens talk to a provider that talks to the sync-layer auth facade
- No raw colour hex or spacing literals in `lib/features/`
- No banned Material visual widgets in `lib/features/`

## Notes

HITL for two human decisions before/while implementing: (1) a Supabase project
+ env config for real OTP smoke-testing, (2) confirming the QR packages
(companion §1 suggests `qr_flutter` + `mobile_scanner` — the one remaining
package choice; raise-first rule applies). `FLAG_SECURE`/`local_auth` are
faked in widget tests; manual device verification of the hardening is part of
the HITL review.
