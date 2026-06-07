# Good and Bad Tests — TheLIST

All examples are Dart/Flutter using `flutter_test` and `package:test`.

## Good Tests

**Integration-style**: test through real interfaces, not mocks of internal parts.

```dart
// GOOD: Tests observable behaviour through the repository interface
test('added row is retrievable by sheet', () async {
  final db = InMemoryDrift();
  final repo = RowRepository(db);

  final sheetId = const Uuid().v4();
  final rowId = await repo.addRow(sheetId: sheetId, title: 'Milk');
  final rows = await repo.rowsForSheet(sheetId).first;

  expect(rows.map((r) => r.id), contains(rowId));
});
```

```dart
// GOOD: Tests sync convergence — the project's most critical behaviour
test('two offline devices converge after sync', () async {
  final transport = FakeMemoryTransport();
  final clock = FakeClock(DateTime(2025));

  final deviceA = SyncClient(InMemoryDrift(), transport, clock);
  final deviceB = SyncClient(InMemoryDrift(), transport, clock);

  await deviceA.addRow(sheetId: 'sheet-1', title: 'Eggs');
  await deviceB.addRow(sheetId: 'sheet-1', title: 'Butter');

  await deviceA.push();
  await deviceB.push();
  await deviceA.pull();
  await deviceB.pull();

  final rowsA = await deviceA.rowsForSheet('sheet-1');
  final rowsB = await deviceB.rowsForSheet('sheet-1');
  expect(rowsA.map((r) => r.title).toSet(),
      equals(rowsB.map((r) => r.title).toSet()));
});
```

Characteristics:
- Tests behaviour callers/users care about
- Uses public interface of the correct layer only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test
- Uses the project domain vocabulary (Sheet, Row, Cell, Reminder…)

## Bad Tests

**Implementation-detail tests**: coupled to internal structure.

```dart
// BAD: Tests that a specific private method was called
test('repository calls _insertRow on add', () async {
  final mockRepo = MockRowRepository();
  await someFeature.addRow(mockRepo, title: 'Milk');
  verify(mockRepo._insertRow(any)).called(1); // testing internals
});
```

```dart
// BAD: Bypasses the interface to verify via raw Drift query
test('addRow saves to database', () async {
  final repo = RowRepository(realDb);
  await repo.addRow(sheetId: 'x', title: 'Milk');
  // Querying the DB directly — bypasses the interface
  final rows = await realDb.select(realDb.rows).get();
  expect(rows, isNotEmpty);
});

// GOOD: Verifies through the public interface
test('addRow makes row retrievable', () async {
  final repo = RowRepository(InMemoryDrift());
  await repo.addRow(sheetId: 'x', title: 'Milk');
  final rows = await repo.rowsForSheet('x').first;
  expect(rows.first.title, equals('Milk'));
});
```

```dart
// BAD: DateTime.now() in a test for sync/engine code — makes the test
// non-deterministic and violates the no-datetime-now grep gate intent
test('LWW picks the later edit', () async {
  final cellA = Cell(updatedAt: DateTime.now()); // non-deterministic
  final cellB = Cell(updatedAt: DateTime.now().add(Duration(seconds: 1)));
  expect(merge(cellA, cellB).updatedAt, equals(cellB.updatedAt));
});

// GOOD: Use FakeClock for deterministic time
test('LWW picks the later edit', () async {
  final clock = FakeClock(DateTime(2025, 1, 1));
  final cellA = Cell(updatedAt: clock.now());
  clock.advance(const Duration(seconds: 1));
  final cellB = Cell(updatedAt: clock.now());
  expect(merge(cellA, cellB).updatedAt, equals(cellB.updatedAt));
});
```

Red flags:
- Mocking internal collaborators (your own repositories, providers, widgets)
- Using `DateTime.now()` in tests touching sync/engine code
- Asserting on call counts or internal method invocations
- Test breaks on refactor without behaviour change
- Test name describes HOW, not WHAT
- Importing `package:drift` in a test for `lib/features/` or `lib/state/`
