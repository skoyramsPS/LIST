# TheLIST backend — harness entrypoints.
#
# `make verify` is the contract (AGENTS.md §0): a single trustworthy signal.
# It delegates to tool/verify.ts so the exact same sequence runs everywhere.
#
# Stages, in order, fail-fast:
#   fmt -> lint -> grep-gates -> schema-fresh -> doc-honesty -> doc-coverage -> test

.PHONY: verify gen fmt lint gates schema docs coverage test setup start stop

## verify: run the full gate (the only definition of "done").
verify:
	deno run --allow-all tool/verify.ts

## setup: install dependencies and pull Supabase CLI (run once after clone).
setup:
	deno cache supabase/functions/**/*.ts
	supabase --version

## start: start the local Supabase stack (Docker required).
start:
	supabase start

## stop: stop the local Supabase stack.
stop:
	supabase stop

## gen: regenerate the schema fence in docs/architecture/schema.md from migration head.
gen:
	deno run --allow-all tool/gen_schema.ts

## fmt: auto-format the tree (fixes what `verify` only checks).
fmt:
	deno fmt .

## lint: static analysis only.
lint:
	deno lint

## gates: run the absence-invariant grep gates only.
gates:
	deno run --allow-all tool/grep_gates.ts

## links: check .agents/skills/ matches .claude/skills/ (--fix to resync).
links:
	deno run --allow-all tool/check_skill_links.ts

## schema: run the schema-fence check only.
schema:
	deno run --allow-all tool/gen_schema.ts --check

## docs: run the doc-honesty check only.
docs:
	deno run --allow-all tool/doc_honesty.ts

## coverage: run the doc-coverage check only.
coverage:
	deno run --allow-all tool/doc_coverage.ts

## test: run the full test suite (unit + integration).
test:
	deno test --allow-all supabase/functions/
