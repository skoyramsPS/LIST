# TheLIST — harness entrypoints.
#
# `make verify` is the contract (AGENTS.md §0): a single trustworthy signal.
# It delegates to tool/verify.dart so the exact same sequence runs everywhere,
# including Windows (`dart run tool/verify.dart`) and CI.
#
# Stages, in order, fail-fast:
#   format -> analyze -> grep-gates -> skill-links -> schema-fresh -> doc-honesty -> doc-coverage -> test

.PHONY: verify gen format analyze gates links docs coverage test setup

## verify: run the full gate (the only definition of "done").
verify:
	dart run tool/verify.dart

## setup: fetch dependencies (run once after clone).
setup:
	flutter pub get

## gen: regenerate the schema fence in data_model.md from the Drift schema.
gen:
	dart run tool/gen_schema.dart

## format: auto-format the tree (fixes what `verify` only checks).
format:
	dart format .

## analyze: static analysis only.
analyze:
	dart analyze --fatal-infos --fatal-warnings

## gates: run the absence-invariant grep gates only.
gates:
	dart run tool/grep_gates.dart

## links: check .agents/skills/ matches .claude/skills/ (--fix to resync).
links:
	dart run tool/check_skill_links.dart

## docs: run the doc-honesty check only.
docs:
	dart run tool/doc_honesty.dart

## coverage: run the doc-coverage check only (completed tasks have doc-update confirmed).
coverage:
	dart run tool/doc_coverage.dart

## test: run the test suite only.
test:
	flutter test
