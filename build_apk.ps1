# Builds the release APK. No database credential of any kind is compiled
# in any more — every data path goes through backend/api over plain HTTPS.
#
#   powershell -ExecutionPolicy Bypass -File build_apk.ps1
#
# SENTRY_DSN, if set, is read straight out of .env and passed via
# --dart-define. Blank (no line, or no .env yet) just builds with Sentry
# disabled — see docs/sentry.md.
#
# BACKEND_API_BASE_URL is public, not a secret — shield_backend's own
# deployed URL, hardcoded here the same way the agent app's own
# build_apk.ps1 does. NOT optional: member sign-in runs entirely through
# backend/api's MSG91-backed /v1/member/auth/otp/* (see AuthService's own
# doc) — a blank or stale value here means BackendHttp.isEnabled is false
# on the built APK and every sign-in attempt fails immediately with
# "Verification is unavailable on this device right now," with no network
# call ever made. Update this the moment the backend is ever redeployed to
# a different domain.
#
# MSG91_WIDGET_ID/MSG91_WIDGET_TOKEN_AUTH are ALSO required now — confirmed
# live (2026-10-13) that MSG91's Widget product has no real
# server-to-server "send" at all (a bare REST call with a known-good
# credential gets HTTP 403 from MSG91), so sign-in now runs the actual JS
# widget everywhere, in an invisible headless WebView on native
# (lib/module/auth/msg91_widget_otp_native.dart) the same way the web
# build already ran it in the page. These two are public, not secrets — the
# `tokenAuth` is MSG91's own browser-safe, scoped, throttled token made
# specifically to travel in client code, same reasoning the web build's own
# vercel-build.sh already documents. A blank value here means OTP sending
# throws "OTP sending is not configured in this build" instead.
#
# Always starts with `flutter clean`. Confirmed live on this machine
# (2026-10-13): a plain `flutter build apk` after an earlier build can
# silently keep the previous build's compiled Dart code — including
# different (or absent) --dart-define values — without any error, warning,
# or non-zero exit code. Verified by unzipping the resulting APK and
# grepping libapp.so for the values directly: present after a clean
# build, absent after a same-cache rebuild with the exact same command.
# `flutter clean` costs a few minutes of rebuild time; a build that quietly
# ships the wrong backend (or none) costs a lot more than that to even
# notice. Do not remove this for the sake of a faster build.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$BackendApiBaseUrl = 'https://shieldbackend.vercel.app'
$Msg91WidgetId = '366a696a446a343235393238'
$Msg91TokenAuth = '579930TU1QZriuNLU6ac9d73bP1'

$SentryDsn = ''
if (Test-Path '.env') {
    $line = Select-String -Path '.env' -Pattern '^\s*SENTRY_DSN\s*=' | Select-Object -Last 1
    if ($line) {
        $SentryDsn = ($line.Line -split '=', 2)[1].Trim().Trim('"').Trim("'")
    }
}

Write-Host 'Cleaning previous build output (required — see this script''s own comment on why) ...' -ForegroundColor Cyan
flutter clean
if ($LASTEXITCODE -ne 0) { throw 'Flutter clean failed; no release was produced.' }

Write-Host 'Building release APK (one build at a time — close any other flutter build/run) ...' -ForegroundColor Cyan
flutter build apk --release `
  --dart-define=BACKEND_API_BASE_URL=$BackendApiBaseUrl `
  --dart-define=MSG91_WIDGET_ID=$Msg91WidgetId `
  --dart-define=MSG91_WIDGET_TOKEN_AUTH=$Msg91TokenAuth `
  --dart-define=SENTRY_DSN=$SentryDsn
if ($LASTEXITCODE -ne 0) { throw 'APK build failed; do not distribute older output.' }

$ApkPath = 'build\app\outputs\flutter-apk\app-release.apk'

# Self-check: confirm the required values actually made it into the
# compiled code, rather than trusting that `flutter build` exiting 0 means
# they did (see this script's own comment above on why that trust already
# failed once). Unzips the APK into a throwaway temp folder and greps the
# compiled Dart snapshot (libapp.so) for the literal strings.
Write-Host 'Verifying the required values actually made it into the build ...' -ForegroundColor Cyan
$CheckDir = Join-Path $env:TEMP "shield-apk-check-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $CheckDir -Force | Out-Null
try {
    $ZipCopy = Join-Path $CheckDir 'app-release.zip'
    Copy-Item $ApkPath $ZipCopy
    Expand-Archive -Path $ZipCopy -DestinationPath $CheckDir -Force
    $LibApp = Get-ChildItem -Path $CheckDir -Recurse -Filter 'libapp.so' | Select-Object -First 1
    $Text = ''
    if ($LibApp) {
        $Bytes = [System.IO.File]::ReadAllBytes($LibApp.FullName)
        # ISO-8859-1, not Encoding.Latin1 — the latter is a .NET 5+-only
        # static property and is $null under Windows PowerShell 5.1's
        # .NET Framework runtime (confirmed: silently null, not an error,
        # until .GetString() throws). Either way it's purely a byte-safe
        # 1:1 decode for finding an ASCII substring in binary data — not
        # an attempt to read the file's real encoding.
        $Text = [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($Bytes)
    }
    $Missing = @()
    if (-not $Text.Contains($BackendApiBaseUrl)) { $Missing += 'BACKEND_API_BASE_URL' }
    if (-not $Text.Contains($Msg91WidgetId)) { $Missing += 'MSG91_WIDGET_ID' }
    if (-not $Text.Contains($Msg91TokenAuth)) { $Missing += 'MSG91_WIDGET_TOKEN_AUTH' }
    if (-not $Text.Contains('sahakarOtpReady')) { $Missing += 'Android MSG91 widget bridge' }
    if (-not $Text.Contains('var booted = false;')) { $Missing += 'updated Android OTP startup' }
    if ($Missing.Count -gt 0) {
        Write-Host ''
        Write-Host "BUILD VERIFICATION FAILED: missing from the compiled app: $($Missing -join ', ')" -ForegroundColor Red
        Write-Host 'Installing this APK will reproduce a broken sign-in screen. Do not' -ForegroundColor Red
        Write-Host 'distribute this build.' -ForegroundColor Red
        exit 1
    }
    Write-Host 'Confirmed: all required values are present in the compiled app.' -ForegroundColor Green
} finally {
    $ResolvedCheckDir = [System.IO.Path]::GetFullPath($CheckDir)
    $TempRoot = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
    if ($ResolvedCheckDir.StartsWith($TempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $ResolvedCheckDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host "Done: $ApkPath" -ForegroundColor Green
Write-Host 'Install this new release over the older app when its signing key matches.'
Write-Host 'Verify Get OTP, resend and sign-in on a real Android device before publishing.'
