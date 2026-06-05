// tool/doc_honesty.dart
//
// Doc-honesty gate for TheLIST (AGENTS.md §5). The architecture docs are the
// first thing every agent reads, so they must never describe code that no
// longer exists. This script extracts every `lib/...` filesystem path mentioned
// in docs/architecture/*.md and fails the build if any does not resolve on disk.
//
// It deliberately checks PATHS, not prose — we never try to verify English. A
// doc that says "the merge lives in lib/sync/merge.dart" is checkable; a doc
// that says "merging is elegant" is not, and that's fine.
//
// Path-shaped tokens are matched as `lib/<...>` ending in `.dart` (optionally
// with a `/**` or trailing `/` for a directory). Directories must exist as
// directories; files must exist as files.
//
// Run via `dart run tool/doc_honesty.dart` (invoked by `make verify`).

import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  final docDir = Directory('docs/architecture');
  if (!docDir.existsSync()) {
    stdout.writeln('doc_honesty: no docs/architecture — skipping.');
    exit(0);
  }

  // Matches lib/..., either a .dart file or a directory path. Stops at
  // whitespace, backticks, parentheses, commas, or closing markdown chars.
  final pathPattern = RegExp(r'lib/[A-Za-z0-9_/]+(?:\.dart|/\*\*|/)?');

  final missing = <String>[];
  var checked = 0;

  for (final entity in docDir.listSync()) {
    if (entity is! File || !entity.path.endsWith('.md')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final match in pathPattern.allMatches(lines[i])) {
        var raw = match.group(0)!;
        // Normalise glob/dir suffixes to a real on-disk path to test.
        final isGlob = raw.endsWith('/**');
        final isDir = raw.endsWith('/') || isGlob;
        final cleaned = raw.replaceAll('/**', '').replaceAll(RegExp(r'/$'), '');
        // Docs always use forward slashes; convert to the host path separator
        // so the existence checks work identically on Windows and macOS/Linux.
        final probe = p.joinAll(p.posix.split(cleaned));
        checked++;

        final existsAsFile = File(probe).existsSync();
        final existsAsDir = Directory(probe).existsSync();

        final ok = isDir ? existsAsDir : (existsAsFile || existsAsDir);
        if (!ok) {
          final rel = entity.path.replaceAll('\\', '/');
          missing.add('$rel:${i + 1}  references "$raw" which does not exist.');
        }
      }
    }
  }

  if (missing.isEmpty) {
    stdout.writeln('doc_honesty: OK — $checked path reference(s) all resolve.');
    exit(0);
  }

  stderr.writeln('doc_honesty: FAILED — ${missing.length} dangling reference(s):\n');
  for (final m in missing) {
    stderr.writeln('  $m');
  }
  stderr.writeln(
      '\nEither the code moved (update the doc) or the doc is stale. '
      'Architecture docs must point only at code that exists (AGENTS.md §5).');
  exit(1);
}
