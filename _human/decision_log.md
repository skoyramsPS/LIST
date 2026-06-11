# Decision Log — rationale & rejected alternatives (HUMAN ONLY)

> **This file is invisible to coding agents by design.** It lives under `/_human/`
> and `make verify` fails the build if any file in `lib/` or `test/` references a
> path resolving here. Its purpose: keep the *history* of why we chose what we
> chose — and especially **why we rejected the alternatives** — so you don't
> re-litigate settled calls. Rejected designs are hallucination fuel for agents;
> that is exactly why they are quarantined here and not in `/docs/architecture/`.

Each entry: **the decision**, then **what we rejected and why**.

---

## 1. Greenfield, full rebuild
**Decided:** Everything is built from scratch — backend, sync engine, design
system, dev environment. Document #1 of the project.
**Rejected:** Reusing/inheriting any pre-existing app's backend, sync surface,
design tokens, or widgets. There is no such app. Any reference to inherited
infrastructure is a hallucination — this is why no proprietary prior system is
named anywhere in the docs.

## 2. Sync engine is the thesis (not a deferred phase)
**Decided:** Build the full local-first E2EE sync engine as the core deliverable.
**Rejected:** "Design-for-sync but defer the engine; ship local-only MVP first."
Rejected because a local-only app only demonstrates CRUD; the entire point is to
demonstrate distributed state, convergence, and a real E2EE trust model.

## 3. Dumb server + client-side merge (vs server-authoritative merge)
**Decided:** Supabase is a dumb, authenticated, RLS-guarded log of opaque blobs +
plaintext LWW metadata. All merge logic runs on-device.
**Rejected:** A Postgres `sync_push` RPC that does field-level LWW merge
server-side. It is fundamentally incompatible with E2EE — to merge fields the
server must read them. We chose E2EE; therefore the server cannot merge. (Also:
client-side merge is testable with zero backend, which the convergence matrix
needs.)

## 4. True E2EE / SQLCipher dropped
**Decided:** Encrypt the payload before it leaves the device (true E2EE). Local
Drift DB is **plaintext on disk**, relying on the OS app sandbox at rest.
**Rejected:** SQLCipher for at-rest local encryption. It guards a weaker threat
(physical, rooted-device file extraction) at a real cost in debugging and key
management, while the threat that matters (rogue admin / server breach / network
interception) is covered by E2EE. Industry E2EE apps (Signal, WhatsApp) commonly
store local DBs in plaintext. **Do not reintroduce SQLCipher** — an agent reading
an old "SQLCipher at rest" note would write broken/contradictory key code.

## 5. Key model B + C (recovery phrase + device QR); auth decoupled from encryption
**Decided:** 256-bit master key (HKDF-derived from 128-bit CSPRNG entropy) in the
Secure Enclave; portable via 12-word BIP-39 recovery phrase (B) and
device-to-device QR transfer carrying the raw entropy (C). Supabase Auth controls
*access*; the key controls *decryption*; the two are independent.
**Rejected:** *Option A — derive the key from the login password.* Rejected
because forgotten password = total unrecoverable data loss, and password change
forces key re-wrapping — an unacceptable demo failure mode. (B's recovery phrase
gives a recovery path; C makes multi-device a designed flow, not an afterthought.)

## 6. Per-cell encryption = merge boundary; uniform payload rule
**Decided:** Each cell is the unit of merge AND encryption. Every synced table
splits into plaintext sync-metadata + one `encrypted_payload` blob. Opaque UUID
foreign keys give schema privacy for free.
**Rejected:** *Per-row encryption (whole cell-bag as one blob).* Rejected because
it breaks per-field LWW — two devices editing different cells of one row would
force a decrypt-and-re-merge at row level, reintroducing the whole-object-clobber
risk the LWW-Register model exists to avoid. *Separate hybrid crypto to hide
schema (explicit Option C)* was unnecessary: EAV + UUIDs + the uniform blob rule
deliver schema privacy with no extra cryptography.
**Accepted tradeoff:** the server learns field counts and change times (metadata),
never contents — harmless for a list app.

## 7. Ordering — fractional indexing with jitter (vs LexoRank)
**Decided:** `position TEXT` fractional index with a random jitter suffix;
`(position, id)` tiebreaker; no MVP rebalancing.
**Rejected:** *LexoRank buckets* — buckets need a central coordinator to rebalance,
which an offline/multi-device app does not have. Jitter makes identical-key
collisions between two offline devices effectively impossible.

## 8. Formulas — no inter-formula references in MVP
**Decided:** Operands are input columns or constants only; results materialized
into `value_number`; recompute in the repository transaction.
**Rejected:** *A full formula DAG with inter-formula references.* Rejected for MVP
because it requires cycle detection and transitive recompute. Flat one-level
fan-out removes all of that. (Standing rule kept for any future chained formulas:
an overridden cell is a value *source*, not a downstream freeze.)

## 9. Column type immutable once populated (vs a coercion engine)
**Decided:** A column's `data_type` locks the moment any cell holds data; migration
is user-driven via a new column. Unlocks if all cells return to null.
**Rejected:** *A type-coercion matrix that rewrites cells on type change* — and its
sub-options (silent-drop unconvertible values; preserve-and-flag with a "conforms"
render state; refuse-change-if-any-cell-fails). All were dropped because immutability
dissolves the entire problem (no lossy conversion, no bulk-rewrite-sync question, no
"conforms" gray zone) for the cost of one disabled dropdown. Matches "user-controlled
data".

## 10. Templates — built-ins as code, custom as flagged Sheets
**Decided:** Built-in templates are declarative Dart code (protected, version with
releases, never sync). Custom templates are Sheets flagged `is_template = 1`
(inherit the whole pipeline). `template_kind` routes specialized renderers;
instantiation is an atomic deep-copy with column-ID remapping, fresh positions,
and Draft/Paused reminders.
**Rejected:** *Everything in the database (a `templates` table or built-ins as
`sheets` rows).* Built-ins-as-rows would mean every user uploads their own
encrypted copy of the identical "Grocery" template — absurd — and protection /
versioning would need extra machinery. A separate parallel `templates` schema was
rejected as redundant with the Sheet pipeline.

## 11. Deletion — deferred tombstone, local-only undo, sync_version optimization
**Decided:** Tombstone commits only when the 5s snackbar expires (interrupted
delete is safe); undo is local-only/ephemeral; `sync_version==0` → hard DELETE,
`>0` → soft tombstone; tombstones retained forever.
**Rejected:** *Immediate-durable tombstone on tap* (forces resurrect-on-undo logic
and causes a vanish-then-reappear flicker on other devices). *Cross-device undo*
(that is a Trash feature, an explicit non-goal). *Tombstoning never-synced empty
rows* (phantom keys on the wire).

## 12. Today tab — SQLite Views, derived at read time (vs maintained cache)
**Decided:** Three native sources (reminders table; a `v_waiting_on` EAV-pivot
View; a `v_subscriptions` EAV-pivot View — both keyed on `semantic_role`) feed
one AttentionItem provider. (Habits were removed from project scope; the former
habit_logs+rule_segments source went with them.) Store the facts, compute the clock (`:now` bound per read).
**Rejected:** *A hand-maintained local `attention_items` cache table updated on
write.* Fatal flaw: Trial Limbo and auto-missed are functions of *time*, and no
write fires when the clock crosses an end-date at midnight while the app is
closed — so a write-maintained cache is stale exactly when it matters. *Pure
in-Dart derivation* (hydrating raw EAV cells to filter) was rejected for GC
stutter; the View keeps the pivot+filter inside SQLite.

## 13. Recurrence — small struct, clamp-never-skip, civil-time, lazy generator
**Decided:** `{freq, interval>=1, byWeekday, anchor}`. Clamp to month-end
(re-derived from the anchor day, never from the prior clamped result). Civil-time
construction for DST safety. `sync*` lazy generator bounded by N≈60 (iOS 64 cap)
and a ~12-month safety horizon.
**Rejected:** *An RFC-5545 / RRULE parser* (calendar-app complexity the product
rejects). *Skip-invalid-months* for the 31st case (silently drops occurrences — fatal
for a renewal tracker). *interval fixed at 1* (would block quarterly/biannual subs;
`interval` is nearly free). *Fixed 30-days-per-reminder budget* (ignores the global
64 cap; the alert-instance is the real schedulable unit).

## 14. UX — scoped-bespoke, not full primitives-only
**Decided:** Custom `List*` components for everything visible; Material kept as the
invisible accessibility/IME/navigation chassis. Plus Jakarta Sans. AppTokens as a
hard, grep-gated boundary. Named Material *visual* denylist in `features/`.
**Rejected:** *Full "Primitives Only"* (ban all Material, rebuild Checkbox/Switch/etc.
from CustomPaint) — rejected because it forces re-implementing accessibility and
spends effort that belongs on the engine. *Themed-M3* (use Material components, just
recolored) — rejected because the ripple, elevation physics, and default padding still
"scream Flutter". Scoped-bespoke is the middle that keeps the bespoke skin and the
solved a11y. *Inter* (now the SaaS default, utilitarian) and *Satoshi*
(editorial/brutalist, licensing) rejected in favor of Plus Jakarta Sans.

## 15. Harness — static/grep for absence, TDD for behavior; no custom AST lint
**Decided:** `make verify` = format → analyze → grep gates → doc-honesty → tests.
Absence-invariants (no `DateTime.now()` in the engine, no raw hex/doubles in UI, the
Material denylist, no `/_human/` references) via banned-imports config + zero-dependency
grep. Behavior via TDD + the two-client convergence matrix. Injected `Clock` /
`SyncTransport` are binding architectural rules.
**Rejected:** *A custom_lint AST package* (unnecessary complexity; banned-imports +
grep cover it). *"Enforce the Clock/DB rules via TDD"* alone — rejected because TDD only
covers tested paths and cannot assert the *absence* of a pattern across all code; absence
needs a complete static scan.

## 16. Dead-spec safety — physical separation, not ignore files
**Decided:** All proposed/archived/rejected docs live under `/_human/`; `make verify`
greps `lib/` and `test/` for references resolving there and fails the build.
**Rejected:** *Tool-specific `.cursorignore`/`.grokignore`/`.aiignore` "blindfolds".*
Rejected because they are per-tool, silently inconsistent, and unenforced — they fall
off the instant you switch agents (which the handoff plan explicitly does), re-exposing
dead context invisibly. Physical separation + an enforced grep gate is a guarantee, not a
courtesy.

## 17. Doc honesty — enforced, generated facts
**Decided:** `make verify` checks that every `lib/...` path/symbol referenced in
`/docs/architecture/*` resolves; `data_model.md` schema facts are generated from the Drift
schema into a fenced `<!-- DRIFT-SCHEMA -->` sentinel region (rationale hand-written
outside the fence). Bug fixes use the same verify spine with a regression-test-first rule.
**Rejected:** *Asking the agent to self-verify doc prose* (unenforceable; a trusted-but-
stale doc is worse than none). *Whole-file doc generation* (would clobber hand-written
rationale — hence the sentinel fence).

---

## 18. Multi-agent root contract — one `AGENTS.md`, `CLAUDE.md` as a stub
**Decided:** The guardrails live in a single canonical **`AGENTS.md`** at the repo
root — the shared convention read natively by **Codex** and **Grok Build** (both
walk `AGENTS.md`/`AGENTS.override.md` from git root down). **`CLAUDE.md`** is a
short pointer stub that redirects Claude Code to `AGENTS.md`. Single source of
truth; all doc cross-references point to `/AGENTS.md`.
**Rejected:** *Maintaining full guardrails in both `CLAUDE.md` and `AGENTS.md`* —
they would drift, leaving two of three agents on a stale contract (the exact
dead-context failure the `/_human/` gate prevents, reintroduced at the root).
*Symlinking `CLAUDE.md → AGENTS.md`* — fragile on Windows/git/some tools (this is
a Windows repo). Keep the root contract under ~150 lines, dense and specific:
every token loads on every turn for every agent.

## Implementation notes captured during the interview (so they aren't lost)
- Root contract is `AGENTS.md` (canonical); `CLAUDE.md` is a pointer stub. If a
  Grok Plan-Mode `.grok/GROK.md` is ever added, it too must point to `AGENTS.md`,
  never fork it.
- `/_human/` grep gate must scan **`lib/` and `test/` only**, or it trips on its own
  rule definition and on docs that explain it.
- DDL generation must replace **only** the content between the
  `<!-- DRIFT-SCHEMA:START -->` / `END` markers, never the whole file.
- Merge stamping in the two-history flow (Phase 4) must preserve each local row's
  **existing** edit timestamps, not "now", or LWW lies across the merge boundary.
- Deep-copy template instantiation must carry a `source_column_id → new_column_id` map
  so copied cells point at the new columns.
- Clamp recurrence **from the anchor day**, never from the previously clamped occurrence.
