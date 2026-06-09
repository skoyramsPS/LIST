// tool/check_skill_links.dart
//
// Skill-sync gate for TheLIST (AGENTS.md §8 / HARNESS.md §6).
//
// INVARIANT: .agents/skills/ must be an exact copy of .claude/skills/.
//   - Every skill directory in .claude/skills/ must exist in .agents/skills/.
//   - Every skill directory in .agents/skills/ must exist in .claude/skills/.
//   - Every file must exist in both trees with identical content.
//
// WHY COPIES NOT SYMLINKS: core.symlinks=false on Windows (the primary dev
// machine) means Git stores symlinks as plain text files. A symlink from
// .agents/skills -> .claude/skills breaks Git operations in VS Code and CI.
// Copies are the only approach that works reliably across platforms.
//
// HOW TO FIX FAILURES:
//   dart run tool/check_skill_links.dart --fix
//   make links
//
// This overwrites .agents/skills/ from .claude/skills/. Safe — .claude/skills/
// is always the source of truth.
//
// Run via `dart run tool/check_skill_links.dart` (invoked by `make verify`).

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final fix = args.contains('--fix');

  final source = Directory('.claude/skills');
  final mirror = Directory('.agents/skills');

  if (!source.existsSync()) {
    stderr.writeln('check_skill_links: ERROR — .claude/skills/ does not exist.');
    exit(1);
  }

  if (fix) {
    _rebuild(source, mirror);
    stdout.writeln('check_skill_links: rebuilt .agents/skills/ from .claude/skills/');
    exit(0);
  }

  if (!mirror.existsSync()) {
    stderr.writeln(
      'check_skill_links: FAILED — .agents/skills/ does not exist.\n'
      'Run `dart run tool/check_skill_links.dart --fix` to rebuild it.',
    );
    exit(1);
  }

  final errors = <String>[];

  final sourceDirs = _skillDirs(source);
  final mirrorDirs = _skillDirs(mirror);

  // Skills in .claude not in .agents
  for (final name in sourceDirs.keys) {
    if (!mirrorDirs.containsKey(name)) {
      errors.add('Missing in .agents/skills/: "$name"');
    }
  }

  // Skills in .agents not in .claude (orphans)
  for (final name in mirrorDirs.keys) {
    if (!sourceDirs.containsKey(name)) {
      errors.add('Orphan in .agents/skills/: "$name" (not in .claude/skills/)');
    }
  }

  // Content comparison for skills present in both
  for (final name in sourceDirs.keys) {
    if (!mirrorDirs.containsKey(name)) continue;

    final srcFiles = _allFiles(sourceDirs[name]!);
    final dstFiles = _allFiles(mirrorDirs[name]!);

    for (final rel in srcFiles.keys) {
      if (!dstFiles.containsKey(rel)) {
        errors.add('.agents/skills/$name/$rel — missing');
        continue;
      }
      final srcHash = _md5(srcFiles[rel]!);
      final dstHash = _md5(dstFiles[rel]!);
      if (srcHash != dstHash) {
        errors.add(
          '.agents/skills/$name/$rel — content differs from .claude/skills/$name/$rel\n'
          '  Run `dart run tool/check_skill_links.dart --fix` to resync.',
        );
      }
    }

    for (final rel in dstFiles.keys) {
      if (!srcFiles.containsKey(rel)) {
        errors.add('.agents/skills/$name/$rel — orphan (not in .claude/skills/$name/)');
      }
    }
  }

  if (errors.isEmpty) {
    final count = sourceDirs.length;
    stdout.writeln('check_skill_links: OK — $count skill(s) in sync.');
    exit(0);
  }

  stderr.writeln('check_skill_links: FAILED — ${errors.length} sync error(s):\n');
  for (final e in errors) stderr.writeln('  $e');
  stderr.writeln(
    '\nRun `dart run tool/check_skill_links.dart --fix` to resync '
    '.agents/skills/ from .claude/skills/.\n'
    'See HARNESS.md §6 maintenance rules.',
  );
  exit(1);
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Map<String, Directory> _skillDirs(Directory parent) {
  final result = <String, Directory>{};
  for (final e in parent.listSync()) {
    if (e is Directory) result[p.basename(e.path)] = e;
  }
  return result;
}

Map<String, File> _allFiles(Directory dir) {
  final result = <String, File>{};
  for (final e in dir.listSync(recursive: true)) {
    if (e is File) result[p.relative(e.path, from: dir.path)] = e;
  }
  return result;
}

String _md5(File f) => md5.convert(f.readAsBytesSync()).toString();

void _rebuild(Directory source, Directory mirror) {
  if (mirror.existsSync()) mirror.deleteSync(recursive: true);
  mirror.createSync(recursive: true);

  for (final skillDir in source.listSync()) {
    if (skillDir is! Directory) continue;
    final name = p.basename(skillDir.path);
    final dst = Directory(p.join(mirror.path, name))..createSync();

    for (final entity in skillDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final rel = p.relative(entity.path, from: skillDir.path);
      final dstFile = File(p.join(dst.path, rel));
      dstFile.parent.createSync(recursive: true);
      entity.copySync(dstFile.path);
    }
  }
}
