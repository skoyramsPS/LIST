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

## 0. Two tiers of setup (read this first)

There are two distinct things you might want, and they need different amounts of
tooling:

- **Tier 1 — pass the gate.** `make verify` / `dart run tool/verify.dart` is pure
  Dart (format, analyze, grep gates, schema, doc checks, `flutter test`). It needs
  **only the Flutter SDK** — no Android Studio, no emulator. You can do almost all
  development and satisfy the "done" contract (AGENTS.md §0) at this tier.
- **Tier 2 — run the app on a device.** To actually launch TheLIST you need the
  **Android** toolchain (Android Studio + Android SDK + an emulator or a physical
  phone). On Windows, **Android is the only mobile target** — iOS/macOS builds
  require a Mac with Xcode. Windows desktop/web targets are possible but are not
  the focus of this project.

If you only want to write code and keep the suite green, Tier 1 is enough. For
end-to-end app testing, do Tier 2.

### Fastest path on a bare machine — the bootstrap script
A fresh Windows box has no Flutter, so there is no Dart to run yet. A one-time
PowerShell bootstrap installs everything for Tier 2:

```
# From the repo root, in Windows PowerShell / Terminal:
powershell -ExecutionPolicy Bypass -File tool\windows\bootstrap-windows.ps1
# then CLOSE and REOPEN the terminal so PATH updates take effect:
flutter doctor
```

The script `winget`-installs Git, the Flutter SDK, and Android Studio, accepts the
Android SDK licenses, and runs `flutter doctor`. It is **safe to re-run** (every
step checks before acting). It is **not part of the harness** — `verify`/CI never
call it; it only sets up a developer machine. The manual equivalents are in §1–§2
below and remain the source of truth. If you prefer to install by hand, or you're
on macOS, skip the script and follow the manual steps.

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
3. For Android builds (Tier 2): Android Studio + SDK — see §1b. (Not needed for
   `make verify`.)
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

## 1b. Android toolchain (Tier 2 — only needed to run the app)

Skip this entirely if you only need `verify` to pass. Required to launch TheLIST
on an emulator or phone. The bootstrap script (§0) does steps 1–3 for you.

1. **Install Android Studio.** `winget install --id Google.AndroidStudio` (or the
   official installer). It brings the Android SDK **and a bundled, compatible JDK**
   — that JDK is what makes license acceptance work without a separate Java install.
2. **Finish the Setup Wizard.** Open Android Studio once and let its first-run
   wizard download the Android SDK, platform-tools, and **command-line tools**.
   `flutter doctor --android-licenses` shells out to Android's `sdkmanager`, which
   lives in the command-line tools — without them, license acceptance fails.
3. **Accept the SDK licenses:**
   ```
   flutter doctor --android-licenses     # answer y to each
   ```
4. **Get a device.** Either create an emulator (Android Studio → Device Manager →
   create a virtual device) or connect a physical phone with **USB debugging**
   enabled (Settings → Developer options).
5. **Confirm and run:**
   ```
   flutter devices        # your emulator/phone should be listed
   flutter run            # builds + launches TheLIST on Android
   ```

**Common snags.** If `flutter doctor` reports "cmdline-tools component is missing",
open Android Studio → Settings → Languages &amp; Frameworks → Android SDK → *SDK
Tools* tab → check **Android SDK Command-line Tools (latest)** → Apply, then re-run
`flutter doctor --android-licenses`. If `sdkmanager` errors with a Java
incompatibility, use Android Studio's bundled JDK (point `JAVA_HOME` at it or run
licenses from inside Studio's terminal) — system Java 17+ is not compatible with
older `sdkmanager`.

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
If you bump the Flutter version, change §1 **and** the pinned values at the top of
`tool/windows/bootstrap-windows.ps1` (the Flutter floor and winget package IDs are
duplicated there for the bare-machine case). The script is a convenience installer,
not a gate — `verify`/CI never run it — but a stale script is a broken onboarding,
so keep it in step with this doc. The whole point is that a new machine can be made
productive from this one file.
