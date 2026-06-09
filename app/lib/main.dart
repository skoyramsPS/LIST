import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entry point for TheLIST.
///
/// This is an intentionally minimal shell so the harness (`make verify`) has a
/// real target to analyze and test. Real features land under `lib/features/`,
/// wired through Riverpod (`lib/state/`) to repositories (`lib/repositories/`).
/// See AGENTS.md for the layering contract.
void main() {
  runApp(const ProviderScope(child: TheListApp()));
}

class TheListApp extends StatelessWidget {
  const TheListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'TheLIST',
      home: Scaffold(
        body: Center(child: Text('TheLIST')),
      ),
    );
  }
}
