// tool/doc_coverage.dart
//
// Doc-coverage gate for TheLIST (AGENTS.md §5 / HARNESS.md §2b).
//
// Catches documentation rot by omission: a completed task that introduced
// new lib/... paths or symbols but never updated the architecture docs.
//
// WHAT IT CHECKS
// ──────────────
// For every task file in docs/tasks/*.md whose **Status:** field is "complete",
// find the line tagged <!-- doc-update -->. That line must be checked ([x]),
// OR the task file must carry a **No-doc-impact:** field with a non-empty reason.
//
// A task that is pending/in_progress is ignored entirely — the gate only fires
// once the task is closed.
//
// ESCAPE HATCH
// ────────────
// Add to the task file's frontmatter block (top of file, before the first ##):
//
//   **No-doc-impact:** <reason>
//
// Example legitimate reasons:
//   **No-doc-impact:** test-only change, no new lib/ paths introduced
//   **No-doc-impact:** tooling-only (tool/*.dart), not reflected in arch docs
//
// The reason must be non-empty. A bare **No-doc-impact:** with no text fails.
//
// THE MARKER
// ──────────
// The acceptance-criterion line to check looks like:
//   - [ ] <!-- doc-update --> Architecture doc updated ...
//   - [x] <!-- doc-update --> Architecture doc updated ...
//
// Any line containing the literal token "<!-- doc-update -->" is the marker.
// Exactly one such line is expected per task. If none is found and the task has
// no No-doc-impact field, that is also reported as an error (malformed task).
//
// Run via `dart run tool/doc_coverage.dart` (invoked by `make verify`).

import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  final tasksDir = Directory('docs/tasks');
  if (!tasksDir.existsSync()) {
    stdout.writeln('doc_coverage: no docs/tasks/ directory — nothing to check.');
    exit(0);
  }

  final taskFiles = tasksDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList()
    ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  if (taskFiles.isEmpty) {
    stdout.writeln('doc_coverage: no task files found — nothing to check.');
    exit(0);
  }

  final errors = <String>[];
  var checked = 0;
  var skipped = 0;

  for (final file in taskFiles) {
    final result = _checkTask(file);
    switch (result.kind) {
      case _ResultKind.notComplete:
        skipped++;
      case _ResultKind.ok:
        checked++;
      case _ResultKind.fail:
        checked++;
        errors.add(result.message!);
    }
  }

  if (errors.isEmpty) {
    stdout.writeln(
      'doc_coverage: OK — $checked complete task(s) checked, '
      '$skipped pending/in-progress skipped.',
    );
    exit(0);
  }

  stderr.writeln(
    'doc_coverage: FAILED — ${errors.length} task(s) missing doc update:\n',
  );
  for (final e in errors) {
    stderr.writeln('  $e');
  }
  stderr.writeln(
    '\nFor each task above, either:\n'
    '  1. Mark the <!-- doc-update --> criterion checked:  - [x] <!-- doc-update --> ...\n'
    '  2. Or add an escape hatch if genuinely no docs changed:\n'
    '       **No-doc-impact:** <reason why no architecture doc needed updating>\n'
    '\nSee AGENTS.md §5 and docs/HARNESS.md §2b.',
  );
  exit(1);
}

// ─── Task checker ────────────────────────────────────────────────────────────

enum _ResultKind { notComplete, ok, fail }

class _Result {
  const _Result.notComplete() : kind = _ResultKind.notComplete, message = null;
  const _Result.ok() : kind = _ResultKind.ok, message = null;
  const _Result.fail(this.message) : kind = _ResultKind.fail;

  final _ResultKind kind;
  final String? message;
}

_Result _checkTask(File file) {
  final lines = file.readAsLinesSync();
  final rel = file.path.replaceAll('\\', '/');

  // ── 1. Is the task complete? ──────────────────────────────────────────────
  final statusLine = lines.firstWhere(
    (l) => l.trimLeft().startsWith('**Status:**'),
    orElse: () => '',
  );
  if (statusLine.isEmpty) {
    // No status field — treat as not complete (malformed tasks don't block verify).
    return const _Result.notComplete();
  }
  final statusValue = statusLine
      .replaceFirst(RegExp(r'.*\*\*Status:\*\*\s*'), '')
      .trim()
      .toLowerCase();
  if (statusValue != 'complete') {
    return const _Result.notComplete();
  }

  // ── 2. Does it have a No-doc-impact escape hatch? ─────────────────────────
  final noDocLine = lines.firstWhere(
    (l) => l.trimLeft().startsWith('**No-doc-impact:**'),
    orElse: () => '',
  );
  if (noDocLine.isNotEmpty) {
    final reason = noDocLine
        .replaceFirst(RegExp(r'.*\*\*No-doc-impact:\*\*\s*'), '')
        .trim();
    if (reason.isNotEmpty) {
      return const _Result.ok(); // Legitimate escape hatch.
    }
    // Bare **No-doc-impact:** with no reason is invalid.
    return _Result.fail(
      '$rel — **No-doc-impact:** field is present but has no reason. '
      'Provide a non-empty justification or remove the field and check the '
      '<!-- doc-update --> criterion instead.',
    );
  }

  // ── 3. Find the <!-- doc-update --> marker line ───────────────────────────
  const marker = '<!-- doc-update -->';
  final markerLines = <int>[];
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains(marker)) markerLines.add(i);
  }

  if (markerLines.isEmpty) {
    return _Result.fail(
      '$rel — status is "complete" but no <!-- doc-update --> marker found. '
      'Add the marker line to Acceptance criteria, or add **No-doc-impact:** '
      'if this task truly introduced no new lib/ paths.',
    );
  }

  if (markerLines.length > 1) {
    return _Result.fail(
      '$rel — found ${markerLines.length} lines containing <!-- doc-update -->. '
      'Expected exactly one. Remove duplicates.',
    );
  }

  // ── 4. Is it checked? ─────────────────────────────────────────────────────
  final markerLine = lines[markerLines.first];
  // Matches:  - [x] or - [X]  anywhere before the marker
  final checked = RegExp(r'-\s*\[[xX]\]').hasMatch(
    markerLine.substring(0, markerLine.indexOf(marker)),
  );

  if (checked) return const _Result.ok();

  return _Result.fail(
    '$rel — status is "complete" but the <!-- doc-update --> criterion is '
    'still unchecked (- [ ]). Either:\n'
    '    • Check it off: change "- [ ]" to "- [x]"\n'
    '    • Or add **No-doc-impact:** <reason> if no architecture doc needed '
    'updating (e.g. test-only or tooling-only change).',
  );
}
