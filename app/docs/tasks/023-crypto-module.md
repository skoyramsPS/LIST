# 023: Crypto module — KeyManager + PayloadCipher

**Type:** AFK
**Status:** pending
**Blocked by:** 001
**Harness stages exercised:** test / analyze

## What to build

`lib/crypto/` as two deep modules with closed public interfaces (companion §1,
§6; `sync.md` §4 as amended by task 001):

- **`KeyManager`** — `generateKey()`, `keyFromPhrase(words)`,
  `keyFromQrBytes(bytes)`, `phrase`, `qrBytes`, `hasKey`, `eraseKey()`. Hides:
  128-bit CSPRNG entropy; BIP-39 encode/decode/checksum (**no PBKDF2
  stretching**); HKDF-SHA256 (ikm = raw entropy, salt `"thelist.sync.v1"`,
  info `"master-key"`, 32 bytes); Keychain/Keystore I/O behind an injected
  secure-storage interface. QR payload = the 16 entropy bytes, so phrase and QR
  converge on the identical derivation. Entropy itself is never stored.
- **`PayloadCipher`** — `encrypt(json, aad)`, `decrypt(blob, aad)`. Hides:
  XChaCha20-Poly1305; one fresh random 192-bit nonce per encryption, prepended;
  base64url framing. AAD is always `(table_name, id)`.

New dependencies (pre-approved in the companion PRD): `cryptography`,
`cryptography_flutter`, `bip39`. (`local_auth` and QR packages belong to 027.)

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Round-trip: encrypt → decrypt with matching AAD succeeds
- [ ] AAD mismatch (same key, different `(table_name, id)`) fails closed
- [ ] Wrong key fails closed (Poly1305 tag rejection) — no partial plaintext
- [ ] Fixed test vectors pin the full chain: entropy → 12 words → entropy → HKDF → key (phrase ↔ entropy ↔ QR equivalence)
- [ ] BIP-39 checksum rejection: a 12-word string with a bad checksum is rejected before any derivation
- [ ] Two encryptions of the same plaintext yield different ciphertexts (fresh nonce)
- [ ] No KCV anywhere — key validity is only ever proven by decrypting real data
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No Supabase import (crypto is offline-pure)
- No Drift import outside `lib/repositories/` / `lib/data/`
- No reference resolving into `/_human/`

## Harness prerequisites triggered (if any)

None directly, but **blocked by 001 (master PRD §22d)**: do not implement key
handling from the un-amended `sync.md` — task 001 must land first so the
architecture doc, not the mortal PRD, is the source.

## Notes

The public interfaces above are **complete** — adding a method is an
architecture change requiring a doc update. Secure storage is injected so all
tests run with an in-memory fake; no platform channels in unit tests.
