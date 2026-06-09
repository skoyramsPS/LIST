#!/usr/bin/env -S deno run --allow-all
/**
 * tool/doc_honesty.ts — Doc-honesty check for the TheLIST backend.
 *
 * Extracts every path token matching:
 *   supabase/functions/...
 *   supabase/migrations/...
 *   tool/...
 *
 * from every docs/architecture/*.md file, then verifies each path resolves
 * on disk. Exits 1 if any path is dangling.
 *
 * This is enforced by `make verify` stage 5 (doc-honesty). If you add,
 * move, or rename a function/migration, update the architecture docs in the
 * same commit.
 */

import { walk } from "https://deno.land/std@0.224.0/fs/walk.ts";
import { join, relative } from "https://deno.land/std@0.224.0/path/mod.ts";

const ROOT = new URL("../", import.meta.url).pathname;
const DOCS_DIR = join(ROOT, "docs/architecture");

// Matches path tokens like supabase/functions/sync/index.ts or tool/verify.ts
const PATH_RE =
  /(?:supabase\/(?:functions|migrations)\/[\w\-./]+|tool\/[\w\-.]+\.ts)/g;

type Dangling = { doc: string; path: string };
const dangling: Dangling[] = [];

for await (const entry of walk(DOCS_DIR, {
  exts: [".md"],
  includeDirs: false,
})) {
  const text = await Deno.readTextFile(entry.path);
  const matches = [...text.matchAll(PATH_RE)];

  for (const match of matches) {
    const token = match[0];
    const abs = join(ROOT, token);
    try {
      await Deno.stat(abs);
    } catch {
      dangling.push({ doc: relative(ROOT, entry.path), path: token });
    }
  }
}

if (dangling.length === 0) {
  console.log("✓ doc-honesty: all referenced paths resolve");
  Deno.exit(0);
} else {
  console.error(`✗ doc-honesty: ${dangling.length} dangling path(s)\n`);
  for (const d of dangling) {
    console.error(`  ${d.doc} → "${d.path}" does not exist on disk`);
  }
  console.error(
    "\nUpdate the architecture docs to match the current file tree."
  );
  Deno.exit(1);
}
