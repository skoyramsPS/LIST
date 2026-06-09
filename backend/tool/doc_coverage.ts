#!/usr/bin/env -S deno run --allow-all
/**
 * tool/doc_coverage.ts — Doc-coverage check for the TheLIST backend.
 *
 * Every task in docs/tasks/*.md with `**Status:** complete` must either:
 *   (a) have its <!-- doc-update --> criterion checked: `- [x] <!-- doc-update -->`
 *   (b) carry a `**No-doc-impact:** <non-empty reason>` field
 *
 * A completed task that fails both checks exits 1.
 *
 * This is enforced by `make verify` stage 5b (doc-coverage). It catches the
 * failure mode that doc-honesty cannot: an agent that finishes a task and
 * updates the code but never touches the architecture docs at all.
 */

import { walk } from "https://deno.land/std@0.224.0/fs/walk.ts";
import { relative } from "https://deno.land/std@0.224.0/path/mod.ts";
import { join } from "https://deno.land/std@0.224.0/path/mod.ts";

const ROOT = new URL("../", import.meta.url).pathname;
const TASKS_DIR = join(ROOT, "docs/tasks");

const STATUS_COMPLETE_RE = /\*\*Status:\*\*\s*complete/i;
const DOC_UPDATE_CHECKED_RE = /- \[x\] <!-- doc-update -->/i;
const NO_DOC_IMPACT_RE = /\*\*No-doc-impact:\*\*\s*\S+/;

type Failure = { file: string; reason: string };
const failures: Failure[] = [];

let tasksDir;
try {
  tasksDir = walk(TASKS_DIR, { exts: [".md"], includeDirs: false });
} catch {
  // No tasks directory yet — nothing to check.
  console.log("✓ doc-coverage: no tasks directory found (skipping)");
  Deno.exit(0);
}

for await (const entry of tasksDir) {
  const text = await Deno.readTextFile(entry.path);

  if (!STATUS_COMPLETE_RE.test(text)) continue;

  const hasCheckedCriterion = DOC_UPDATE_CHECKED_RE.test(text);
  const hasEscapeHatch = NO_DOC_IMPACT_RE.test(text);

  if (!hasCheckedCriterion && !hasEscapeHatch) {
    failures.push({
      file: relative(ROOT, entry.path),
      reason:
        "**Status:** complete but <!-- doc-update --> is unchecked and no **No-doc-impact:** escape hatch present",
    });
  }
}

if (failures.length === 0) {
  console.log("✓ doc-coverage: all completed tasks have doc-update confirmed");
  Deno.exit(0);
} else {
  console.error(`✗ doc-coverage: ${failures.length} task(s) need attention\n`);
  for (const f of failures) {
    console.error(`  ${f.file}`);
    console.error(`    ${f.reason}\n`);
  }
  console.error(
    "Either check the <!-- doc-update --> criterion or add **No-doc-impact:** <reason>."
  );
  Deno.exit(1);
}
