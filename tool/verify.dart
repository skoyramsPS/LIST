// tool/verify.dart
//
// The single source of truth for `make verify` (AGENTS.md §0). Runs the full
// gate, in strict order, failing non-zero on the FIRST failure. This is pure
// Dart so it runs identically on Windows, macOS, Linux, and CI — `make verify`
// and the Windows-friendly `dart run tool/verify.dart` execute the exact same
// sequence.
//
// Order (each stage must pass before the next runs):
//   1. dart format --set-exit-if-changed .
//   2. dart analyze --fatal-infos --fatal-warnings
//   3. grep gates            (tool/grep_gates.dart)
//   4. skill-links           (tool/check_skill_links.dart)
//   5. schema fence is fresh (tool/gen_schema.dart --check)
//   6. doc-honesty           (tool/doc_honesty.dart)
//   7. flutter test
//
// A passing run here is the ONLY definition of "done".

import 'dart:io';

Future<void> main() async {
  final stages = <_Stage>[
    _Stage('format', 'dart', ['format', '--set-exit-if-changed', '.']),
    _Stage('analyze', 'dart', ['analyze', '--fatal-infos', '--fatal-warnings']),
    _Stage('grep-gates', 'dart', ['run', 'tool/grep_gates.dart']),
    _Stage('skill-links', 'dart', ['run', 'tool/check_skill_links.dart']),
    _Stage('schema-fresh', 'dart', ['run', 'tool/gen_schema.dart', '--check']),
    _Stage('doc-honesty', 'dart', ['run', 'tool/doc_honesty.dart']),
    _Stage('test', 'flutter', ['test']),
  ];

  final sw = Stopwatch()..start();
  for (final stage in stages) {
    stdout.writeln('\n=== verify: ${stage.name} ===');
    final code = await stage.run();
    if (code != 0) {
      stdout.writeln('\n✗ verify FAILED at stage "${stage.name}" '
          '(exit $code) after ${sw.elapsed.inSeconds}s.');
      exit(code);
    }
  }
  stdout.writeln('\n✓ verify PASSED — all stages green in ${sw.elapsed.inSeconds}s.');
  exit(0);
}

class _Stage {
  _Stage(this.name, this.executable, this.args);
  final String name;
  final String executable;
  final List<String> args;

  Future<int> run() async {
    try {
      final proc = await Process.start(
        executable,
        args,
        mode: ProcessStartMode.inheritStdio,
        runInShell: true,
      );
      return proc.exitCode;
    } on ProcessException catch (e) {
      stderr.writeln('verify: could not run "$executable ${args.join(' ')}": '
          '${e.message}');
      stderr.writeln('Is the Flutter/Dart SDK on your PATH?');
      return 127;
    }
  }
}
