// tool/doc_honesty.dart
//
// Doc-honesty gate for TheLIST (AGENTS.md §5). Keeps two sets of docs honest:
//
//   1. docs/architecture/*.md  — every `lib/...` path must resolve on disk.
//   2. docs/HARNESS.md         — every `lib/...` and `.claude/skills/...` path
//                                must resolve on disk.
//
// It deliberately checks PATHS, not prose — we never try to verify English. A
// doc that says "the merge lives in lib/sync/merge.dart" is checkable; a doc
// that says "merging is elegant" is not, and that's fine.
//
// Path-shaped tokens:
//   lib/<...>             — .dart file or directory (with optional /** or /)
//   .claude/skills/<...>  — skill directory or SKILL.md file
//
// Directories must exist as directories; files must exist as files.
//
// Run via `dart run tool/doc_honesty.dart` (invoked by `make verify`).

import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  final missing = <String>[];
  var checked = 0;

  // ── 1. docs/architecture/*.md  →  lib/... paths ──────────────────────────
  final archDir = Directory('docs/architecture');
  if (!archDir.existsSync()) {
    stdout.writeln('doc_honesty: no docs/architecture — skipping architecture check.');
  } else {
    final libPattern = RegExp(r'lib/[A-Za-z0-9_/]+(?:\.dart|/\*\*|/)?');
    for (final entity in archDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      _checkPaths(entity as File, libPattern, missing, checked: (n) => checked += n);
    }
  }

  // ── 2. docs/HARNESS.md  →  lib/... and .claude/skills/... paths ──────────
  final harnessFile = File('docs/HARNESS.md');
  if (!harnessFile.existsSync()) {
    stdout.writeln('doc_honesty: no docs/HARNESS.md — skipping harness check.');
  } else {
    // lib/... paths (same pattern as architecture docs)
    final libPattern = RegExp(r'lib/[A-Za-z0-9_/]+(?:\.dart|/\*\*|/)?');
    _checkPaths(harnessFile, libPattern, missing, checked: (n) => checked += n);

    // .claude/skills/... paths — skill directories and their files
    final skillPattern = RegExp(
      r'\.claude/skills/[A-Za-z0-9_/-]+(?:\.md|/\*\*|/)?',
    );
    _checkPaths(harnessFile, skillPattern, missing, checked: (n) => checked += n);
  }

  // ── Report ────────────────────────────────────────────────────────────────
  if (missing.isEmpty) {
    stdout.writeln('doc_honesty: OK — $checked path reference(s) all resolve.');
    exit(0);
  }

  stderr.writeln('doc_honesty: FAILED — ${missing.length} dangling reference(s):\n');
  for (final m in missing) {
    stderr.writeln('  $m');
  }
  stderr.writeln(
    '\nEither the code/skill moved (update the doc) or the doc is stale.\n'
    'Docs must point only at paths that exist on disk (AGENTS.md §5).\n'
    'See docs/HARNESS.md §8 for the maintenance rules.',
  );
  exit(1);
}

/// Scans [file] for tokens matching [pattern] and records any that do not
/// resolve to an existing file or directory under the repo root.
void _checkPaths(
  File file,
  RegExp pattern,
  List<String> missing, {
  required void Function(int) checked,
}) {
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    for (final match in pattern.allMatches(lines[i])) {
      final raw = match.group(0)!;
      final isGlob = raw.endsWith('/**');
      final isDir = raw.endsWith('/') || isGlob;
      final cleaned = raw.replaceAll('/**', '').replaceAll(RegExp(r'/$'), '');
      // Forward-slash paths → host separator (Windows + macOS/Linux alike).
      final probe = p.joinAll(p.posix.split(cleaned));
      checked(1);

      final existsAsFile = File(probe).existsSync();
      final existsAsDir = Directory(probe).existsSync();
      final ok = isDir ? existsAsDir : (existsAsFile || existsAsDir);

      if (!ok) {
        final rel = file.path.replaceAll('\\', '/');
        missing.add('$rel:${i + 1}  references "$raw" which does not exist.');
      }
    }
  }
}
