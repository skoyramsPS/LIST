# 025: Per-field reminder merge + clamp, tie-break, re-push

**Type:** AFK
**Status:** pending
**Blocked by:** 024
**Harness stages exercised:** test / grep-gates

## What to build

The convergence edge cases that make LWW actually safe (companion §"Sync
contract boundary"; `sync.md` §2 as amended):

- **Per-field reminder merge:** `field_timestamps` `{field: epoch_ms}` inside
  the payload + client-side `pending_changed_fields` dirty tracking; merge is
  per field by timestamp, so different-field edits never clobber each other.
  Row-level plaintext `updated_at` = max of the field timestamps.
- **Timestamp clamp (every stamped edit, all entities):**
  `updated_at = max(clock.now, existing.updated_at + 1 ms)` — applied
  identically to each `field_timestamps` entry. A backward-skewed wall clock
  can never produce a stamp older than the version it edits on top of.
- **General re-push rule:** after **any** pull-merge whose result differs from
  the pulled server version, mark the row dirty and re-push (the `>=` guard
  accepts it). Must terminate — the merged superset re-push is a no-op for the
  peer; assert no ping-pong.
- **Tie-break (client-side only):** equal timestamps resolve by higher
  `device_id`; per-field reminder ties by lexicographically greater serialized
  field value. A local tie-break win is one instance of the re-push rule.

Extend the convergence matrix with (each in both push orders where relevant):
equal-timestamp same-field tie from two devices; backward-skewed clock on one
device; concurrent different-field reminder edits landing the full merged
payload server-side with a terminating re-push cycle.

## Acceptance criteria

- [ ] `dart run tool/verify.dart` is green after this task (all seven stages)
- [ ] At least one failing test existed before the implementation was written
- [ ] Different-field concurrent reminder edits converge with both fields surviving, both push orders
- [ ] Equal-timestamp same-field tie converges identically on both devices via device_id/value tie-break, including the dirty-on-local-win re-push
- [ ] Backward-skewed `FakeClock` on one device: its edits still propagate (clamp) and both devices converge
- [ ] Re-push cycle terminates: after the merged re-push, a further sync round produces zero pushes
- [ ] The clamp is applied in one place all stamping paths share (no per-callsite reimplementation)
- [ ] <!-- doc-update --> Architecture doc updated if any new `lib/...` path or symbol was introduced (check this box, or add **No-doc-impact:** below)

## Grep-gate obligations

- No `DateTime.now()` in `lib/sync/` or `lib/repositories/`
- No Supabase import outside `lib/sync/`

## Notes

The server (fake and real) never gains tie logic — its only comparison stays
the `>=` upsert guard. If a test seems to need server-side intelligence, the
client rule is implemented wrong.
