#!/usr/bin/env -S deno run --allow-all
/**
 * tool/check_skill_links.ts — Verify (and optionally fix) that
 * .agents/skills/ is an exact content-copy of .claude/skills/.
 *
 * Why two directories? .claude/skills/ is Claude Code's skill path;
 * .agents/skills/ is Codex's skill path. A symlink cannot be used because
 * core.symlinks=false on Windows breaks Git. So we maintain a content copy.
 *
 * Usage:
 *   deno run --allow-all tool/check_skill_links.ts         # check only
 *   deno run --allow-all tool/check_skill_links.ts --fix   # rebuild copy
 *
 * Exit 0 if in sync (or after fixing); exit 1 if out of sync (check mode).
 */

import { walk } from "https://deno.land/std@0.224.0/fs/walk.ts";
import { join, relative } from "https://deno.land/std@0.224.0/path/mod.ts";
import { ensureDir } from "https://deno.land/std@0.224.0/fs/ensure_dir.ts";
import { copy } from "https://deno.land/std@0.224.0/fs/copy.ts";

const ROOT = new URL("../", import.meta.url).pathname;
const SRC = join(ROOT, ".claude/skills");
const DST = join(ROOT, ".agents/skills");
const FIX = Deno.args.includes("--fix");

type Diff = { path: string; reason: string };
const diffs: Diff[] = [];

// Collect all SKILL.md files from the source
let srcEntries: Array<{ path: string; rel: string }> = [];
try {
  for await (const entry of walk(SRC, {
    match: [/SKILL\.md$/],
    includeDirs: false,
  })) {
    srcEntries.push({ path: entry.path, rel: relative(SRC, entry.path) });
  }
} catch {
  console.log("✓ skill-links: no .claude/skills directory (skipping)");
  Deno.exit(0);
}

for (const { path: srcPath, rel } of srcEntries) {
  const dstPath = join(DST, rel);
  const srcText = await Deno.readTextFile(srcPath);

  let dstText: string | null = null;
  try {
    dstText = await Deno.readTextFile(dstPath);
  } catch {
    diffs.push({ path: rel, reason: "missing in .agents/skills/" });
  }

  if (dstText !== null && srcText !== dstText) {
    diffs.push({ path: rel, reason: "content differs" });
  }
}

if (diffs.length === 0) {
  console.log("✓ skill-links: .agents/skills/ is in sync with .claude/skills/");
  Deno.exit(0);
}

if (!FIX) {
  console.error(
    `✗ skill-links: ${diffs.length} out-of-sync file(s). Run with --fix to rebuild.\n`
  );
  for (const d of diffs) {
    console.error(`  ${d.path}: ${d.reason}`);
  }
  Deno.exit(1);
}

// --fix: rebuild .agents/skills/ from .claude/skills/
console.log("Rebuilding .agents/skills/ from .claude/skills/ ...");
try {
  await Deno.remove(DST, { recursive: true });
} catch {
  // didn't exist
}
await ensureDir(DST);
await copy(SRC, DST, { overwrite: true });
console.log("✓ skill-links: .agents/skills/ rebuilt successfully");
