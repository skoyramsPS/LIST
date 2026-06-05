import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thelist/main.dart';

/// Seed test so `flutter test` (the last stage of `make verify`) has a real
/// target from day one. Real test suites — especially the two-client sync
/// convergence matrix described in docs/architecture/sync.md §7 — land beside
/// this file as the engine is built.
void main() {
  testWidgets('app boots and shows its name', (tester) async {
    await tester.pumpWidget(const TheListApp());
    expect(find.text('TheLIST'), findsOneWidget);
  });
}
