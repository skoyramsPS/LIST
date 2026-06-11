# 028: SupabaseTransport + sync scheduling

**Type:** HITL
**Status:** pending
**Blocked by:** 026 (and 027 for end-to-end ceremony); **backend/006** (integration matrix + deployment — sync_push / sync_pull / sync_reset live on the hosted project)
**Harness stages exercised:** test / grep-gates

## What to build

The production edge of the engine (companion §3–§4, §"Sync contract boundary";
master PRD §10a):

- **`SupabaseTransport`** implementing `SyncTransport` against the Edge
  Functions: `POST /functions/v1/sync_push` (`{ key_epoch, items: [≤500] }` →
  `{ applied_count, key_epoch }`), `sync_pull` (`{ key_epoch, cursor,
  batch_size: 500 }` → `{ changes, next_cursor, has_more, key_epoch }`),
  `sync_reset` (→ new epoch). `409 epoch_mismatch` surfaces as the typed error
  026 already handles. No per-row statuses — stale pushes reconcile via pull.
- **Internal trigger scheduling** (all from `SyncConstants`): trailing 2 s
  debounce after the last local write; immediate `syncNow()` on
  foreground/resume; 5 min periodic pull while foregrounded; nothing in
  background; retry with exponential backoff 2 s base ×2 cap 5 min ±20 %
  jitter, reset on success/connectivity-restored.
- **Quiet sync indicator** in Settings only (driven by the `status` stream) —
  no spinners or sync buttons anywhere else.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Transport unit tests against a faked HTTP layer assert exact wire shapes (request/response field names verbatim per the contract)
- [ ] Scheduling tests with `FakeClock`: burst of writes → exactly one sync 2 s after the last; foreground → immediate; 5 min periodic while foregrounded only; backoff sequence 2/4/8…capped with jitter bounds asserted
- [ ] 409 from the real transport path flows into 026's halt/unlock behaviour
- [ ] Settings shows the quiet indicator; no sync affordance exists in any other screen
- [ ] Manual two-device (or two-simulator) smoke test against the deployed backend: edit offline on both, sync, identical state — recorded in the task notes at completion
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- **No Supabase import outside `lib/sync/`**
- No `DateTime.now()` in `lib/sync/` — debounce/periodic/backoff all run on the injected `Clock`
- No raw colour hex or spacing literals in `lib/features/` (the Settings indicator)

## Notes

HITL: cross-workspace integration — requires the backend deployed
(`backend/docs/tasks/006-integration-matrix-deployment.md`) and human-run
device smoke testing.
Any wire-contract mismatch discovered here must be fixed by changing **both**
companion PRDs / both architecture docs in the same commit (root `AGENTS.md`
§4) — never by silently adapting the client.
