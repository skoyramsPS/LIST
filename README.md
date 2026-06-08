# TheLIST

An **offline-first, local-first Flutter list app** with a **true end-to-end-encrypted, multi-device sync engine**.

You make flexible lists ("Sheets") — groceries, subscription/free-trial trackers, goals, habits — reorder them by hand, and attach reminders. Everything works fully offline with no account. When you choose to sign in, your data syncs privately across your own devices, end-to-end encrypted, where the server can never read it.

The headline isn't the list app — it's the **sync engine**: field-level last-write-wins convergence across offline devices, with E2EE, built so its correctness is *provable by deterministic test* (two in-memory clients, no network).

---

## Status

Early scaffold. The **product and architecture are fully specified**, and the **coding-agent harness is in place**. Feature implementation follows, test-first, behind `make verify`.

---

## How the project is organised

This repo is built to be worked by **coding agents** (Codex, Grok Build, Claude Code) as much as by humans, so context is deliberately structured and token-efficient.

```
AGENTS.md                     ← the contract every agent reads first (Codex + Grok + Claude)
CLAUDE.md                     ← a pointer stub → AGENTS.md (so the contract never forks)
docs/
  planning/active/the-list/PRD.md  ← the product spec: WHAT to build (mortal — archived once built)
  architecture/
    index.md                  ← routing map: which doc your task needs
    data_model.md             ← EAV, UUIDs, STRICT tables, SQLite Views  (+ generated schema)
    sync.md                   ← dumb server, client-side LWW, E2EE keys, scheduler
    design_system.md          ← scoped-bespoke UI, tokens, the denylist, typography
  tasks/                      ← disposable TDD handoff checklists (deleted when green)
lib/                          ← app code, strictly layered (see AGENTS.md §2)
tool/                         ← the harness scripts (verify, gates, generators)
test/                         ← tests, incl. test/harness/ (the gates test themselves)
_human/                       ← rejected-alternative rationale; INVISIBLE to agents, enforced
```

**Read order for any contributor (human or agent):** `AGENTS.md` → `docs/architecture/index.md` → the one doc your task points to. You should rarely need to load more than that.

---

## The harness: `make verify`

There is one trustworthy signal. **Nothing is "done" until `make verify` is green.** It runs, in strict order, failing on the first problem:

1. **format** — `dart format --set-exit-if-changed .`
2. **analyze** — `dart analyze --fatal-infos --fatal-warnings` (incl. layering rules)
3. **grep-gates** — absence-invariants scanned across the whole tree (see below)
4. **schema-fresh** — the generated schema block in `data_model.md` is up to date
5. **doc-honesty** — every `lib/...` path mentioned in the architecture docs still exists
6. **test** — `flutter test` (unit, widget, the sync convergence matrix, and the harness's own self-tests)

### Running it

```bash
# one-time, after cloning:
flutter pub get

# auto-fix the easy stuff, then run the full gate:
dart fix --apply && dart format .
dart run tool/verify.dart        # or, if you have make: make verify
```

Both entrypoints run the *identical* sequence (the Makefile just calls `tool/verify.dart`), so behaviour is the same on Windows, macOS, Linux, and CI. **`make` is optional** — it's preinstalled on macOS but not Windows; the `dart run` form needs no extra tooling.

**New machine, or full setup steps?** See [`docs/SETUP.md`](./docs/SETUP.md) — the maintained, cross-platform (Windows + macOS) environment + first-run guide.

### Useful sub-commands

```bash
make format    # auto-fix formatting (verify only checks it)
make gates     # run the absence-invariant gates only
make docs      # run the doc-honesty check only
make gen       # regenerate the schema fence in data_model.md from the Drift schema
make test      # run the test suite only
```

### What the gates enforce (and why)

The gates encode the architecture's load-bearing rules as **machine checks**, because prose drifts and CI doesn't. They are plain Dart (`tool/`), zero extra toolchain, and they scan the *whole* tree — so an untested code path can't sneak a violation past them.

| Gate | Rule | Why |
| --- | --- | --- |
| `no-datetime-now` | no `DateTime.now()` in `lib/sync`, `lib/repositories`, `lib/notifications` | time is an injected `Clock`, so sync/recurrence is deterministically testable |
| `no-raw-hex` / `no-raw-spacing` | no raw colours or padding/radius literals in `lib/features` | everything routes through `AppTokens` — "calm pastel" is tunable in one file |
| `no-material-visual` | no banned Material widgets (`Card`, `ElevatedButton`, `InkWell`, …) in `lib/features` | the UI is scoped-bespoke `List*` components; Material is an invisible a11y chassis |
| `layer-no-drift-in-ui` | no `drift` import in `lib/features` or `lib/state` | only repositories touch the database |
| `layer-no-supabase-outside-sync` | no `supabase` import outside `lib/sync` | the sync engine is the only thing that talks to the backend |
| `no-human-ref` | nothing in `lib/` or `test/` references `/_human/` | rejected/dead context is quarantined and must never re-enter the build |

A reviewed, deliberate exception can opt a single line out with a `// gate-ok: <reason>` comment.

**The gates are themselves tested** (`test/harness/grep_gates_test.dart`): each one must *fire* on a planted violation and *stay silent* on clean code, so a gate can never silently rot into a no-op.

---

## How work happens here

- **Greenfield.** Everything is built from scratch — no inherited backend, design system, or widget library. (See `AGENTS.md §1`.)
- **Test-first**, for features *and* bugs. A feature starts as a failing test derived from the PRD; a bug starts as a failing regression test that reproduces it. Then code, then `make verify`.
- **Docs stay honest by construction**, not by discipline: schema facts are generated, doc-referenced paths are checked, and the architecture docs are the only thing agents route through.
- **All docs are Markdown; decisions are made by discussion** and recorded in the docs (`AGENTS.md §5b`).

The full contract and rationale live in [`AGENTS.md`](./AGENTS.md) and [`docs/architecture/index.md`](./docs/architecture/index.md).

---

## Tech stack

Flutter · Riverpod 3 · Drift (SQLite) · Supabase (auth + dumb sync log) · `flutter_local_notifications` + `workmanager` · Plus Jakarta Sans. Local DB is plaintext (OS-sandbox at rest); only *synced* data is end-to-end encrypted.

## License

See [LICENSE](./LICENSE).
