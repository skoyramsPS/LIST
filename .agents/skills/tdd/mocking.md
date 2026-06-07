# When to Mock — TheLIST

Mock at **system boundaries** only. This project has exactly three:

## The three seams — mock ONLY these

### 1. Time (`Clock`)
`DateTime.now()` is **banned** in `lib/sync/`, `lib/repositories/`, and
`lib/notifications/` by the `no-datetime-now` grep gate. Every time-dependent
module accepts an injected `Clock`. In tests, use `FakeClock` — a deterministic
clock you advance manually.

```dart
// GOOD: Clock injected, test is deterministic
final clock = FakeClock(DateTime(2025, 6, 1, 9, 0));
final scheduler = ReminderScheduler(db: InMemoryDrift(), clock: clock);

clock.advance(const Duration(days: 1));
final due = scheduler.dueReminders();
expect(due, hasLength(1));
```

### 2. Sync transport (`SyncTransport`)
Only `lib/sync/` imports Supabase — enforced by the `layer-no-supabase-outside-sync`
grep gate. In tests use `FakeMemoryTransport`: an in-memory list of encrypted blobs
that both client instances share, simulating the server without any network.

```dart
// GOOD: Two clients sharing a FakeMemoryTransport — the convergence matrix pattern
final transport = FakeMemoryTransport();
final clientA = SyncClient(InMemoryDrift(), transport, FakeClock());
final clientB = SyncClient(InMemoryDrift(), transport, FakeClock());
```

### 3. Database (`InMemoryDrift`)
For repository-layer tests you may use `InMemoryDrift` — the real Drift schema
running against an in-memory SQLite instance (no file I/O, no test pollution).
Do NOT reach past the repository interface to query Drift directly in tests.

```dart
// GOOD: Repository tested with InMemoryDrift
final repo = SheetRepository(InMemoryDrift());
final id = await repo.createSheet(name: 'Grocery');
expect(await repo.sheetById(id), isNotNull);
```

## Do NOT mock

- Your own modules (repositories, providers, widgets, notifiers)
- Internal collaborators between layers you own
- Riverpod providers in widget tests — use `ProviderScope` with real or
  overridden providers instead
- Drift DAOs or tables directly — test through the repository interface

## Designing for mockability

**Inject dependencies, don't create them internally:**

```dart
// GOOD — testable: Clock injected
class RecurrenceEngine {
  const RecurrenceEngine({required this.clock});
  final Clock clock;

  DateTime nextOccurrence(Reminder reminder) {
    final now = clock.now(); // uses injected clock
    // ...
  }
}

// BAD — not testable: creates its own time source
class RecurrenceEngine {
  DateTime nextOccurrence(Reminder reminder) {
    final now = DateTime.now(); // grep gate violation + untestable
    // ...
  }
}
```

**Prefer specific interfaces over generic ones at seams:**

```dart
// GOOD: each sync operation is independently testable
abstract class SyncTransport {
  Future<void> push(List<SyncRecord> records);
  Future<List<SyncRecord>> pull({required int sinceVersion});
}

// BAD: generic fetcher with conditional logic — mocking requires
// conditionals inside the mock
abstract class SyncTransport {
  Future<dynamic> call(String operation, Map<String, dynamic> params);
}
```
