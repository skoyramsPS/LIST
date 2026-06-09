#!/usr/bin/env -S deno run --allow-all
/**
 * tool/grep_gates.ts — Absence-invariant grep gates for the TheLIST backend.
 *
 * Each gate defines a pattern that must NEVER appear in certain directories.
 * A line can opt out with a trailing comment: // gate-ok: <reason>
 *
 * Exit 0 if all gates pass; exit 1 (with details) if any fire.
 *
 * Gates are self-tested in supabase/functions/_harness/grep_gates_test.ts —
 * every gate must fire on a planted violation and stay silent on clean code.
 */

import { walk } from "https://deno.land/std@0.224.0/fs/walk.ts";
import { relative } from "https://deno.land/std@0.224.0/path/mod.ts";

const ROOT = new URL("../", import.meta.url).pathname;

interface Gate {
  name: string;
  /** Regex pattern that must NOT appear. */
  pattern: RegExp;
  /** Directories to scan (relative to ROOT). */
  dirs: string[];
  /** One-sentence invariant this gate enforces. */
  invariant: string;
}

const gates: Gate[] = [
  {
    name: "no-datetime-in-service",
    pattern: /(?:Date\.now\(\)|new Date\(\))/,
    dirs: ["supabase/functions"],
    invariant:
      "Time must be an injected Clock in service and repository layers so logic is deterministically testable.",
  },
  {
    name: "no-sql-outside-repository",
    pattern: /`[^`]*(?:SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER)[^`]*`/i,
    dirs: ["supabase/functions"],
    invariant:
      "Raw SQL strings are only permitted in repository.ts files; all other layers receive typed data.",
  },
  {
    name: "no-supabase-client-outside-repository",
    pattern: /createClient\s*\(/,
    dirs: ["supabase/functions"],
    invariant:
      "The Supabase client is injected into repositories; it must never be instantiated in handler or service layers.",
  },
  {
    name: "no-hardcoded-secrets",
    pattern:
      /(?:eyJ[A-Za-z0-9_-]{20,}|service_role|anon.*key\s*=\s*["'][A-Za-z0-9]{20,})/,
    dirs: ["supabase/functions", "supabase/migrations"],
    invariant:
      "Secrets must come from Deno.env.get(); hardcoded keys or JWT tokens are forbidden.",
  },
  {
    name: "no-console-log-in-production",
    pattern: /console\.log\s*\(/,
    dirs: ["supabase/functions"],
    invariant:
      "Production code uses the structured logger; console.log is for tests only.",
  },
  {
    name: "no-response-in-handler-or-service",
    pattern: /new Response\s*\(/,
    dirs: ["supabase/functions"],
    invariant:
      "Only index.ts constructs Response objects; handler and service layers return typed values.",
  },
];

/** Files whose names are always allowed to contain certain patterns. */
const ALWAYS_ALLOWED_NAMES = new Set([
  "grep_gates.ts",
  "grep_gates_test.ts",
]);

const GATE_OK_RE = /\/\/\s*gate-ok:/i;

type Violation = { gate: string; file: string; line: number; text: string };

const violations: Violation[] = [];

for (const gate of gates) {
  for (const dir of gate.dirs) {
    const absDir = `${ROOT}${dir}`;

    let entries;
    try {
      entries = walk(absDir, { exts: [".ts"], includeDirs: false });
    } catch {
      // Directory doesn't exist yet — skip silently (greenfield project).
      continue;
    }

    for await (const entry of entries) {
      if (ALWAYS_ALLOWED_NAMES.has(entry.name)) continue;

      // sql-outside-repository gate only fires on non-repository files
      if (
        gate.name === "no-sql-outside-repository" &&
        entry.name === "repository.ts"
      )
        continue;
      if (
        gate.name === "no-supabase-client-outside-repository" &&
        entry.name === "repository.ts"
      )
        continue;
      // no-response gate only fires on non-index files
      if (
        gate.name === "no-response-in-handler-or-service" &&
        entry.name === "index.ts"
      )
        continue;
      // no-console gate doesn't fire in test files
      if (
        gate.name === "no-console-log-in-production" &&
        entry.name.endsWith("_test.ts")
      )
        continue;

      const text = await Deno.readTextFile(entry.path);
      const lines = text.split("\n");

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (gate.pattern.test(line) && !GATE_OK_RE.test(line)) {
          violations.push({
            gate: gate.name,
            file: relative(ROOT, entry.path),
            line: i + 1,
            text: line.trim(),
          });
        }
      }
    }
  }
}

if (violations.length === 0) {
  console.log("✓ grep-gates: all clear");
  Deno.exit(0);
} else {
  console.error(`✗ grep-gates: ${violations.length} violation(s) found\n`);
  for (const v of violations) {
    console.error(`  [${v.gate}] ${v.file}:${v.line}`);
    console.error(`    ${v.text}`);
    console.error(
      `    Add // gate-ok: <reason> to this line if the exception is intentional.\n`
    );
  }
  Deno.exit(1);
}
