# Interface Design for Testability — TheLIST

Good interfaces make testing natural. These principles apply to every layer in
the project (Repository, SyncEngine, RecurrenceEngine, NotificationScheduler,
Riverpod providers).

## 1. Accept dependencies, don't create them

```dart
// GOOD — testable: all dependencies injected
class ReminderScheduler {
  const ReminderScheduler({
    required this.db,
    required this.clock,
    required this.notificationPlugin,
  });
  final AppDatabase db;
  final Clock clock;
  final FlutterLocalNotificationsPlugin notificationPlugin;
}

// BAD — hard to test: creates its own time source and DB
class ReminderScheduler {
  Future<void> schedule() async {
    final db = AppDatabase(); // can't inject InMemoryDrift
    final now = DateTime.now(); // grep gate violation
  }
}
```

## 2. Return results, don't produce hidden side effects

```dart
// GOOD — testable: merge function is pure, returns a result
CellValue merge(CellValue local, CellValue remote) {
  return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
}

// BAD — hard to test: mutates state as a side effect
void applyRemote(CellValue local, CellValue remote) {
  if (remote.updatedAt.isAfter(local.updatedAt)) {
    local.value = remote.value; // side effect hidden inside
  }
}
```

## 3. Small surface area

Fewer methods = fewer tests needed. Fewer parameters = simpler test setup.

```dart
// GOOD: one entry point for the whole sync cycle
abstract class SyncEngine {
  Future<SyncResult> sync();
}

// BAD: leaks internal steps into the interface
abstract class SyncEngine {
  Future<void> fetchRemoteChanges();
  Future<void> applyMerge(List<SyncRecord> records);
  Future<void> pushLocalChanges();
  Future<void> updateCursor(int version);
}
```

## 4. Riverpod providers as the DI seam for the UI layer

In `lib/features/` (UI), dependencies come from Riverpod providers, never
constructed inline. In tests, override providers with `ProviderScope`:

```dart
// In tests: override the repository provider with a fake
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      sheetRepositoryProvider.overrideWithValue(FakeSheetRepository()),
    ],
    child: const TheListApp(),
  ),
);
```

This means widget tests never need to touch Drift or Supabase directly — the
provider override is the seam.

## 5. Pure merge functions in the sync engine

All LWW merge logic must be pure functions with no I/O. This is both a
testability requirement and an architectural one (`sync.md §2`):

```dart
// Pure — easily unit-tested with FakeClock timestamps
SyncRecord mergeRecords(SyncRecord local, SyncRecord remote) {
  if (local.updatedAt.isAfter(remote.updatedAt)) return local;
  return remote;
}
```

No I/O inside merge functions means the convergence matrix tests run in
milliseconds with zero network.
