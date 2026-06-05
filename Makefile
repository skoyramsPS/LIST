# TheLIST — harness entrypoints.
#
# `make verify` is the contract (AGENTS.md §0): a single trustworthy signal.
# It delegates to tool/verify.dart so the exact same sequence runs everywhere,
# including Windows (`dart run tool/verify.dart`) and CI.
#
# Stages, in order, fail-fast:
#   format -> analyze -> grep-gates -> schema-fresh -> doc-honesty -> test

.PHONY: verify gen format analyze gates docs test setup

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

## docs: run the doc-honesty check only.
docs:
	dart run tool/doc_honesty.dart

## test: run the test suite only.
test:
	flutter test
