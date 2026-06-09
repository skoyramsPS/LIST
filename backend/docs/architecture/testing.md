# Testing Strategy — TheLIST Backend

This document describes how the backend is tested: which seams are used, where
unit vs integration tests live, and how to run the harness.

---

## The two test seams

Only these two abstractions are mocked in tests. Never mock internal
collaborators (a service calling a repository, etc.).

| Seam | Production adapter | Test adapter |
|---|---|---|
| **Time** | `new Date()` / `Date.now()` (banned in service/repo — see grep gate) | `FakeClock` — injectable interface, tick-controllable |
| **Supabase client** | `@supabase/supabase-js` `SupabaseClient` | `FakeSupabaseClient` — in-memory store, no network |

### FakeClock interface

```typescript
// supabase/functions/_shared/clock.ts
export interface Clock {
  now(): Date;
}
export class RealClock implements Clock {
  now() { return new Date(); } // gate-ok: production adapter, not service/repo layer
}
export class FakeClock implements Clock {
  private _now: Date;
  constructor(initial: Date) { this._now = initial; }
  now() { return this._now; }
  tick(ms: number) { this._now = new Date(this._now.getTime() + ms); }
}
```

### FakeSupabaseClient

Lives in `supabase/functions/_harness/fake_supabase_client.ts`. Implements
the subset of the Supabase client interface used by repository files. Backed
by an in-memory Map. Does not require `supabase start`.

---

## Unit tests

- Live alongside source: `supabase/functions/<name>/<file>_test.ts`
- Run with: `deno test --allow-all supabase/functions/`
- Must NOT require `supabase start` — use `FakeSupabaseClient`
- Must NOT call `Date.now()` directly — use injected `FakeClock`
- Exercise behaviour through the service's public interface, not implementation
  details

---

## Integration tests

- Live in `supabase/functions/_harness/`
- Run with: `supabase start` then `deno test --allow-all supabase/functions/_harness/`
- Test RLS policies (authenticated vs anon vs service-role)
- Test full HTTP request/response round-trips via `fetch`
- Each RLS policy needs at minimum:
  - A test that an authorized user CAN perform the operation
  - A test that an unauthorized user receives a 401/403

---

## Harness self-tests

`supabase/functions/_harness/grep_gates_test.ts` — tests that each grep gate
fires on a planted violation and stays silent on clean code. These run as part
of `deno test` in the verify pipeline.

---

## Running tests

```bash
# Unit tests only (no Docker needed)
make test

# Start local Supabase for integration tests
make start

# Full verify (all seven stages)
make verify
```
