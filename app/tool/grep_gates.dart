// tool/grep_gates.dart
//
// Absence-invariant gates for TheLIST (AGENTS.md §3). These scan the WHOLE
// source tree — so, unlike example-based tests, they cannot be defeated by an
// untested code path. Pure Dart, zero dependencies, cross-platform.
//
// Run via `dart run tool/grep_gates.dart` (invoked by `make verify`).
// Exits non-zero on the first category with any violation, printing each
// offending file:line so the fix is obvious.
//
// Gates enforced:
//   1. No `DateTime.now()` in the engine (lib/sync, lib/repositories,
//      lib/notifications) — time must be an injected Clock.
//   2. No raw colour hex / numeric padding-radius literals in lib/features
//      — everything routes through AppTokens.
//   3. No banned Material *visual* widgets in lib/features — use List* components.
//   4. No reference resolving into /_human/ anywhere in lib/ or test/.
//   5. Layering: no `package:drift` in lib/features|lib/state;
//      no supabase outside lib/sync.
//
// Each gate is data-driven below; add a rule by adding a _Rule entry.

import 'dart:io';
import 'package:path/path.dart' as p;

/// Optional first arg = a root directory to scan (used by the harness
/// self-tests to point the gate at a temporary sandbox tree). Defaults to the
/// current directory, which is what `make verify` uses.
String _root = '.';

void main(List<String> args) {
  if (args.isNotEmpty && args.first.isNotEmpty) {
    _root = args.first;
  }

  final violations = <String>[];

  for (final rule in _rules) {
    violations.addAll(rule.run());
  }

  if (violations.isEmpty) {
    stdout.writeln('grep_gates: OK — all absence-invariants hold.');
    exit(0);
  }

  stderr.writeln('grep_gates: FAILED — ${violations.length} violation(s):\n');
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  stderr.writeln('\nSee AGENTS.md §3 for the rules and how to fix them.');
  exit(1);
}

/// A single absence-invariant: a forbidden [pattern] that must not appear in
/// files under [includeDirs] (minus [excludeSuffixes]). [allowComment] lets a
/// line opt out with an inline `// gate-ok: <reason>` marker for the rare,
/// reviewed exception.
class _Rule {
  const _Rule({
    required this.name,
    required this.pattern,
    required this.includeDirs,
    required this.message,
    this.excludeSuffixes = const ['.g.dart', '.freezed.dart', '.drift.dart'],
  });

  final String name;
  final RegExp pattern;
  final List<String> includeDirs;
  final String message;
  final List<String> excludeSuffixes;

  List<String> run() {
    final hits = <String>[];
    for (final dir in includeDirs) {
      // includeDirs use forward slashes; join through package:path so the
      // resulting path uses the host separator (Windows + macOS/Linux alike).
      final dirParts = p.posix.split(dir);
      final d = Directory(
          _root == '.' ? p.joinAll(dirParts) : p.join(_root, p.joinAll(dirParts)));
      if (!d.existsSync()) continue;
      for (final entity in d.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;
        if (excludeSuffixes.any(entity.path.endsWith)) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('// gate-ok')) continue;
          if (pattern.hasMatch(line)) {
            final rel = entity.path.replaceAll('\\', '/');
            hits.add('[$name] $rel:${i + 1}  — $message\n      > ${line.trim()}');
          }
        }
      }
    }
    return hits;
  }
}

final List<_Rule> _rules = [
  // 1. No wall-clock in the engine. Time is an injected Clock.
  _Rule(
    name: 'no-datetime-now',
    pattern: RegExp(r'DateTime\.now\s*\('),
    includeDirs: ['lib/sync', 'lib/repositories', 'lib/notifications'],
    message: 'use an injected Clock, never DateTime.now() (testability).',
  ),

  // 2a. No raw colour hex in the UI layer.
  _Rule(
    name: 'no-raw-hex',
    pattern: RegExp(r'(Color\s*\(\s*0x|0xFF[0-9A-Fa-f]{6}|#[0-9A-Fa-f]{6})'),
    includeDirs: ['lib/features'],
    message: 'no raw colours in features — use AppTokens.color.*',
  ),

  // 2b. No raw numeric padding/radius literals in the UI layer.
  // Flags EdgeInsets.all/symmetric/only(...) and BorderRadius.circular(...)
  // with a bare number literal instead of a token.
  _Rule(
    name: 'no-raw-spacing',
    pattern: RegExp(
        r'(EdgeInsets\.(all|symmetric|only|fromLTRB)\s*\([^)]*\d|'
        r'BorderRadius\.circular\s*\(\s*\d|'
        r'\bRadius\.circular\s*\(\s*\d)'),
    includeDirs: ['lib/features'],
    message: 'no raw spacing/radius in features — use AppTokens.spacing.* / radius.*',
  ),

  // 3. No banned Material visual widgets in features. Chassis widgets
  //    (Scaffold, Navigator, Semantics, TextField-via-ListTextField) are allowed.
  _Rule(
    name: 'no-material-visual',
    pattern: RegExp(
        r'\b(Card|ElevatedButton|TextButton|OutlinedButton|InkWell|ListTile|'
        r'Checkbox|Switch|FloatingActionButton|AppBar|Divider)\s*\('),
    includeDirs: ['lib/features'],
    message: 'use the List* component, not the Material widget (design_system.md).',
  ),

  // 4. /_human/ is dead context. Nothing in code may reference it.
  _Rule(
    name: 'no-human-ref',
    pattern: RegExp(r'_human'),
    includeDirs: ['lib', 'test'],
    message: '/_human/ is quarantined dead context — never reference it.',
  ),

  // 5a. Layering: no Drift in UI / state layers.
  _Rule(
    name: 'layer-no-drift-in-ui',
    pattern: RegExp(r'''import\s+['"]package:drift'''),
    includeDirs: ['lib/features', 'lib/state'],
    message: 'only repositories may import drift (AGENTS.md §2).',
  ),

  // 5b. Layering: Supabase only inside lib/sync. We scan the other code dirs.
  _Rule(
    name: 'layer-no-supabase-outside-sync',
    pattern: RegExp(r'''import\s+['"]package:supabase'''),
    includeDirs: [
      'lib/features',
      'lib/state',
      'lib/repositories',
      'lib/data',
      'lib/crypto',
      'lib/notifications',
      'lib/ui',
    ],
    message: 'only lib/sync may import supabase (AGENTS.md §2).',
  ),
];
