#!/usr/bin/env -S deno run --allow-all
/**
 * tool/verify.ts — TheLIST backend verify pipeline.
 *
 * Runs all stages in strict fail-fast order. This is the single trustworthy
 * signal: a task is not done until this exits 0.
 *
 * Stages:
 *   1. fmt       — deno fmt --check .
 *   2. lint      — deno lint
 *   3. grep-gates — tool/grep_gates.ts
 *   4. schema-fresh — tool/gen_schema.ts --check
 *   5. doc-honesty — tool/doc_honesty.ts
 *   5b. doc-coverage — tool/doc_coverage.ts
 *   6. test      — deno test --allow-all supabase/functions/
 */

import { join } from "https://deno.land/std@0.224.0/path/mod.ts";

const ROOT = new URL("../", import.meta.url).pathname;

interface Stage {
  name: string;
  cmd: string[];
}

const stages: Stage[] = [
  { name: "fmt", cmd: ["deno", "fmt", "--check", "."] },
  { name: "lint", cmd: ["deno", "lint"] },
  { name: "grep-gates", cmd: ["deno", "run", "--allow-all", join(ROOT, "tool/grep_gates.ts")] },
  { name: "schema-fresh", cmd: ["deno", "run", "--allow-all", join(ROOT, "tool/gen_schema.ts"), "--check"] },
  { name: "doc-honesty", cmd: ["deno", "run", "--allow-all", join(ROOT, "tool/doc_honesty.ts")] },
  { name: "doc-coverage", cmd: ["deno", "run", "--allow-all", join(ROOT, "tool/doc_coverage.ts")] },
  { name: "test", cmd: ["deno", "test", "--allow-all", join(ROOT, "supabase/functions/")] },
];

let failed = false;

for (const stage of stages) {
  const label = `[${stage.name}]`;
  console.log(`\n${label} running: ${stage.cmd.join(" ")}`);

  const proc = new Deno.Command(stage.cmd[0], {
    args: stage.cmd.slice(1),
    cwd: ROOT,
    stdout: "inherit",
    stderr: "inherit",
  });

  const { code } = await proc.output();

  if (code !== 0) {
    console.error(`\n✗ ${label} FAILED (exit ${code}). Stopping.`);
    failed = true;
    break;
  }

  console.log(`✓ ${label} passed`);
}

if (!failed) {
  console.log("\n✓ All stages green. Done.\n");
} else {
  Deno.exit(1);
}
