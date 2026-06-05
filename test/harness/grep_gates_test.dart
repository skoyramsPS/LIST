// test/harness/grep_gates_test.dart
//
// The harness must be trustworthy, so the gates are themselves tested: each
// rule must FIRE on a planted violation and STAY SILENT on clean code. Without
// this, a gate that silently never matches would give false confidence — the
// worst failure mode for a guardrail.
//
// We exercise tool/grep_gates.dart as a subprocess against a temporary sandbox
// tree, so we test the real gate logic end-to-end (not a reimplementation).
//
// Strategy: the gate scans fixed dirs (lib/..., test/...) relative to CWD. We
// run the gate with its CWD set to a temp dir that we populate with planted
// violations, and assert exit code + which rule name appears in stderr.

import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  // Absolute path to the gate script in THIS repo, resolved once.
  final gateScript = p.normalize(p.join(Directory.current.path, 'tool', 'grep_gates.dart'));

  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('gate_test_');
  });
  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  void plant(String relPath, String contents) {
    final f = File(p.join(sandbox.path, relPath));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(contents);
  }

  Future<ProcessResult> runGate() {
    // Run the gate from the real repo (so package resolution works), pointing
    // it at the sandbox tree via its root argument. This exercises the real
    // gate logic end-to-end against our planted violations.
    return Process.run('dart', ['run', gateScript, sandbox.path]);
  }

  test('clean tree passes (exit 0)', () async {
    plant('lib/features/widget.dart', '''
import 'package:flutter/material.dart';
class W extends StatelessWidget {
  const W({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('ok'));
}
''');
    final r = await runGate();
    expect(r.exitCode, 0, reason: 'clean tree must pass.\n${r.stderr}');
  });

  test('fires on DateTime.now() in the engine', () async {
    plant('lib/sync/merge.dart', 'final t = DateTime.now();\n');
    final r = await runGate();
    expect(r.exitCode, isNonZero);
    expect(r.stderr.toString(), contains('no-datetime-now'));
  });

  test('fires on raw colour hex in features', () async {
    plant('lib/features/x.dart', "const c = Color(0xFFD1DC00);\n");
    final r = await runGate();
    expect(r.exitCode, isNonZero);
    expect(r.stderr.toString(), contains('no-raw-hex'));
  });

  test('fires on raw spacing literal in features', () async {
    plant('lib/features/x.dart', 'const e = EdgeInsets.all(16);\n');
    final r = await runGate();
    expect(r.exitCode, isNonZero);
    expect(r.stderr.toString(), contains('no-raw-spacing'));
  });

  test('fires on banned Material visual widget in features', () async {
    plant('lib/features/x.dart', 'final w = Card(child: child);\n');
    final r = await runGate();
    expect(r.exitCode, isNonZero);
    expect(r.stderr.toString(), contains('no-material-visual'));
  });

  test('fires on /_human/ reference in code', () async {
    plant('lib/data/x.dart', "// see ../_human/decision_log.md\n");
    final r = await runGate();
    expect(r.exitCode, isNonZero);
    expect(r.stderr.toString(), contains('no-human-ref'));
  });

  test('fires on drift import in the UI layer', () async {
    plant('lib/features/x.dart', "import 'package:drift/drift.dart';\n");
    final r = await runGate();
    expect(r.exitCode, isNonZero);
    expect(r.stderr.toString(), contains('layer-no-drift-in-ui'));
  });

  test('fires on supabase import outside lib/sync', () async {
    plant('lib/repositories/x.dart', "import 'package:supabase_flutter/supabase_flutter.dart';\n");
    final r = await runGate();
    expect(r.exitCode, isNonZero);
    expect(r.stderr.toString(), contains('layer-no-supabase-outside-sync'));
  });

  test('respects the // gate-ok opt-out marker', () async {
    plant('lib/sync/clock.dart', 'final t = DateTime.now(); // gate-ok: the real Clock impl\n');
    final r = await runGate();
    expect(r.exitCode, 0, reason: 'gate-ok line must be exempt.\n${r.stderr}');
  });
}
