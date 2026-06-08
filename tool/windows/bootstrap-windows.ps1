<#
=====================================================================
 TheLIST - one-time Windows machine bootstrap
=====================================================================

 PURPOSE
   Take a *bare* Windows machine (no Flutter, no Android tooling) to the
   point where you can run BOTH:
     - the project gate:  dart run tool/verify.dart   (pure-Dart, no Android)
     - the Android app:   flutter run                 (emulator or device)

 IMPORTANT - this is NOT part of the harness.
   AGENTS.md (sec 0) defines "done" as `make verify` / `dart run tool/verify.dart`,
   which is pure Dart and identical on every OS. This script installs developer
   tooling on the machine; it is a convenience for first-time onboarding only.
   It is never invoked by verify, CI, or any gate. Deleting it changes nothing
   about how the project builds. The manual steps it automates live in
   docs/SETUP.md and remain the source of truth.

 SAFE TO RE-RUN.
   Every step checks before acting; already-installed tools are skipped.

 USAGE
   1. Open Windows PowerShell (or Terminal) as your normal user.
   2. Allow this one script to run in the current session:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   3. From the repo root:
        powershell -ExecutionPolicy Bypass -File tool\windows\bootstrap-windows.ps1
   4. CLOSE and REOPEN your terminal afterwards so PATH changes take effect,
      then run:  flutter doctor

 REQUIRES
   - Windows 10/11 with winget (App Installer). If `winget` is missing, install
     "App Installer" from the Microsoft Store, then re-run.
=====================================================================
#>

$ErrorActionPreference = 'Stop'

# --- pinned facts (keep in sync with pubspec.yaml + docs/SETUP.md) ----
$FlutterChannel = 'stable'      # pubspec floor: Flutter >=3.44.0, Dart >=3.5.0
$WingetFlutter  = 'Google.Flutter'
$WingetStudio   = 'Google.AndroidStudio'
$WingetGit      = 'Git.Git'

function Write-Step  ($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Write-Ok    ($m) { Write-Host "  [ok]   $m" -ForegroundColor Green }
function Write-Skip  ($m) { Write-Host "  [skip] $m" -ForegroundColor DarkGray }
function Write-Warn2 ($m) { Write-Host "  [warn] $m" -ForegroundColor Yellow }

function Test-Cmd ($name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Install-IfMissing {
  param([string]$WingetId, [string]$ProbeCmd, [string]$Label)
  Write-Step "Install: $Label"
  if ($ProbeCmd -and (Test-Cmd $ProbeCmd)) {
    Write-Skip "$Label already present ($ProbeCmd resolves)."
    return
  }
  if (-not (Test-Cmd 'winget')) {
    throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
  }
  Write-Host "  Installing $WingetId via winget..."
  winget install --id $WingetId --exact --silent `
        --accept-package-agreements --accept-source-agreements
  Write-Ok "$Label install command completed."
}

# ---------------------------------------------------------------------
Write-Host "TheLIST - Windows bootstrap" -ForegroundColor White
Write-Host "This installs Flutter, Git, and Android Studio (Android SDK)." -ForegroundColor White

# 1. Git (Flutter's winget package and `flutter` itself rely on git).
Install-IfMissing -WingetId $WingetGit    -ProbeCmd 'git'     -Label 'Git'

# 2. Flutter SDK (bundles the matching Dart SDK).
Install-IfMissing -WingetId $WingetFlutter -ProbeCmd 'flutter' -Label 'Flutter SDK'

# 3. Android Studio (brings the Android SDK + a bundled, compatible JDK,
#    which is what makes `flutter doctor --android-licenses` work cleanly).
Install-IfMissing -WingetId $WingetStudio  -ProbeCmd $null     -Label 'Android Studio'

# ---------------------------------------------------------------------
Write-Step "PATH note"
Write-Warn2 "winget updated PATH for NEW terminals only."
Write-Warn2 "If 'flutter' is not found below, CLOSE and REOPEN your terminal,"
Write-Warn2 "then run this script again (it will skip what's installed) or just"
Write-Warn2 "continue manually from docs/SETUP.md."

# ---------------------------------------------------------------------
Write-Step "Flutter channel + version"
if (Test-Cmd 'flutter') {
  flutter channel $FlutterChannel
  flutter --version
} else {
  Write-Warn2 "flutter not on PATH in THIS session - reopen terminal and re-run."
  Write-Host "`nPartial bootstrap done. Reopen your terminal and re-run this script." -ForegroundColor Yellow
  exit 0
}

# ---------------------------------------------------------------------
Write-Step "Android command-line tools + licenses"
# `flutter doctor --android-licenses` shells out to Android's sdkmanager.
# It needs the cmdline-tools component (Android Studio installs it) and a
# compatible JDK (Android Studio's bundled JDK). If Studio's first-run wizard
# has not yet downloaded the SDK, this step may report it can't find a tool -
# in that case open Android Studio once, finish the setup wizard, then re-run.
try {
  Write-Host "  Accepting Android SDK licenses (answers 'y' to each prompt)..."
  cmd /c "echo y| flutter doctor --android-licenses"
  Write-Ok "License acceptance attempted."
} catch {
  Write-Warn2 "Could not auto-accept licenses yet."
  Write-Warn2 "Open Android Studio once, complete the Setup Wizard (it downloads"
  Write-Warn2 "the Android SDK + cmdline-tools), then run:"
  Write-Warn2 "    flutter doctor --android-licenses"
}

# ---------------------------------------------------------------------
Write-Step "flutter doctor (final report)"
flutter doctor

# ---------------------------------------------------------------------
Write-Step "Next steps"
Write-Host @"
  1. If any line above is not a check mark, follow what 'flutter doctor' says.
     Most common: open Android Studio once to finish its Setup Wizard, then
     re-run:  flutter doctor --android-licenses

  2. Create / start an Android emulator (Android Studio > Device Manager),
     or plug in a phone with USB debugging on.

  3. From the repo root, prove the project gate is green (no Android needed):
       flutter pub get
       dart fix --apply
       dart format .
       dart run tool/verify.dart

  4. Run the app on Android:
       flutter run

  Full details + manual fallback: docs/SETUP.md
"@ -ForegroundColor White

Write-Ok "Bootstrap script finished."
