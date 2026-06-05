# Dev Environment Setup & First-Run

How to get TheLIST building and verifying on a fresh machine — **Windows and
macOS** alike. This doc is **maintained**: if a setup step changes (a new tool, a
new gate, a version bump), update this file in the same commit. A stale setup doc
is a broken machine on day one.

> **Why both OSes work.** The harness is pure Dart — no shell scripts, no
> platform binaries. `make verify` and `dart run tool/verify.dart` run the
> identical sequence on every OS. Paths are normalised through `package:path`,
> and `.gitattributes` forces LF line endings so the format gate can be green on
> Windows and macOS at the same time.

---

## 1. Prerequisites (install once per machine)

You need **Flutter** (which bundles the matching Dart SDK). Target: Flutter
**3.44+**, Dart **3.5+**.

### macOS
1. Install Flutter — easiest via the official tarball or `brew install --cask flutter`.
2. Ensure `flutter` and `dart` are on your `PATH` (`flutter doctor` to confirm).
3. For iOS builds: Xcode + `sudo xcodebuild -runFirstLaunch`. (Not needed just to
   run `make verify`.)
4. `make` is preinstalled once you've accepted Xcode command-line tools
   (`xcode-select --install`). **`make` is optional** — see §3.

### Windows
1. Install Flutter (official zip, or `winget install --id=Google.Flutter` if
   available, or via `git clone` of the Flutter repo). Add `flutter\bin` to `PATH`.
2. `flutter doctor` to confirm `flutter` and `dart` resolve.
3. For Android builds: Android Studio + SDK. (Not needed for `make verify`.)
4. **`make` is NOT installed by default on Windows** — and you don't need it.
   Use the Dart entrypoint (§3). If you *want* `make`, install via
   `winget install GnuWin32.Make` or `choco install make` or `scoop install make`.

### Verify your toolchain (both OSes)
```
flutter --version      # expect 3.44.x, Dart 3.5+
dart --version
flutter doctor         # resolve anything it flags
```

---

## 2. First-run sequence (fresh clone)

Run these in order, from the repo root. **This is the canonical sequence — the
same on Windows and macOS.**

```
# 1. Fetch dependencies (required before anything else).
flutter pub get

# 2. Auto-fix the easy stuff BEFORE the strict gate runs.
#    dart fix applies safe lint fixes; format normalises whitespace.
dart fix --apply
dart format .

# 3. Run the full harness. THIS is the definition of "done".
dart run tool/verify.dart
```

**Expect on the very first run:** `analyze` is strict (`--fatal-infos`), so a
fresh checkout may surface a few info-level nits. Step 2 (`dart fix` + `format`)
clears the auto-fixable ones. Re-run step 3 until it is green.

A green run prints:
```
✓ verify PASSED — all stages green in Ns.
```

### What `verify` runs (and what each stage means)
| Stage | Command | Fails when |
| --- | --- | --- |
| format | `dart format --set-exit-if-changed .` | code isn't formatted (run `dart format .`) |
| analyze | `dart analyze --fatal-infos --fatal-warnings` | any analyzer issue, incl. layering imports |
| grep-gates | `dart run tool/grep_gates.dart` | an absence-invariant is violated (AGENTS.md §3) |
| schema-fresh | `dart run tool/gen_schema.dart --check` | the schema fence in `data_model.md` is stale (run `dart run tool/gen_schema.dart`) |
| doc-honesty | `dart run tool/doc_honesty.dart` | an architecture doc points at a `lib/...` path that doesn't exist |
| test | `flutter test` | any test fails (incl. the harness self-tests) |

---

## 3. `make` vs `dart run` — they are equivalent

`make verify` simply calls `dart run tool/verify.dart`. Use whichever you have:

| You have… | Run |
| --- | --- |
| `make` (typical macOS) | `make verify` |
| no `make` (typical Windows) | `dart run tool/verify.dart` |

Other convenience targets (`make format`, `make gates`, `make docs`, `make gen`,
`make test`) each map to a single `dart`/`flutter` command — see the `Makefile`.
On Windows without `make`, run that underlying command directly.

---

## 4. Moving between machines — checklist

When you pick up the repo on a different machine (or a teammate clones it):

1. `flutter doctor` — confirm the SDK is present and on `PATH`.
2. `flutter pub get` — dependencies are not committed; fetch them.
3. `dart run tool/verify.dart` — confirm green before you start work.

If `verify` fails on a *new* machine but passed on the old one, the usual suspects
are: (a) a different Flutter/Dart version — match §1; (b) line endings — ensure
git honoured `.gitattributes` (`git add --renormalize .` if a file was committed
with CRLF before the attributes existed); (c) the SDK isn't on `PATH`.

---

## 5. Keeping this doc current

This file lives under the same maintenance rule as the architecture docs and the
README (AGENTS.md §5): **when the setup, toolchain, or harness changes, update
this doc in the same commit.** If you add a gate, add its row to the table in §2.
If you bump the Flutter version, change §1. The whole point is that a new machine
can be made productive from this one file.
