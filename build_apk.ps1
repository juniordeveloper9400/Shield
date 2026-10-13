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
# Always starts with `flutter clean`. Confirmed live on this machine
# (2026-10-13): a plain `flutter build apk` after an earlier build can
# silently keep the previous build's compiled Dart code — including a
# different (or absent) BACKEND_API_BASE_URL — without any error, warning,
# or non-zero exit code. Verified by unzipping the resulting APK and
# grepping libapp.so for the URL string directly: present after a clean
# build, absent after a same-cache rebuild with the exact same command.
# `flutter clean` costs a few minutes of rebuild time; a build that quietly
# ships the wrong backend (or none) costs a lot more than that to even
# notice. Do not remove this for the sake of a faster build.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$BackendApiBaseUrl = 'https://shieldbackend.vercel.app'

$SentryDsn = ''
if (Test-Path '.env') {
    $line = Select-String -Path '.env' -Pattern '^\s*SENTRY_DSN\s*=' | Select-Object -Last 1
    if ($line) {
        $SentryDsn = ($line.Line -split '=', 2)[1].Trim().Trim('"').Trim("'")
    }
}

Write-Host 'Cleaning previous build output (required — see this script''s own comment on why) ...' -ForegroundColor Cyan
flutter clean

Write-Host 'Building release APK (one build at a time — close any other flutter build/run) ...' -ForegroundColor Cyan
flutter build apk --release --dart-define=BACKEND_API_BASE_URL=$BackendApiBaseUrl --dart-define=SENTRY_DSN=$SentryDsn

$ApkPath = 'build\app\outputs\flutter-apk\app-release.apk'

# Self-check: confirm BACKEND_API_BASE_URL actually made it into the
# compiled code, rather than trusting that `flutter build` exiting 0 means
# it did (see this script's own comment above on why that trust already
# failed once). Unzips the APK into a throwaway temp folder and greps the
# compiled Dart snapshot (libapp.so) for the literal URL string.
Write-Host 'Verifying the backend URL actually made it into the build ...' -ForegroundColor Cyan
$CheckDir = Join-Path $env:TEMP "shield-apk-check-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $CheckDir -Force | Out-Null
try {
    $ZipCopy = Join-Path $CheckDir 'app-release.zip'
    Copy-Item $ApkPath $ZipCopy
    Expand-Archive -Path $ZipCopy -DestinationPath $CheckDir -Force
    $LibApp = Get-ChildItem -Path $CheckDir -Recurse -Filter 'libapp.so' | Select-Object -First 1
    $Found = $false
    if ($LibApp) {
        $Bytes = [System.IO.File]::ReadAllBytes($LibApp.FullName)
        # ISO-8859-1, not Encoding.Latin1 — the latter is a .NET 5+-only
        # static property and is $null under Windows PowerShell 5.1's
        # .NET Framework runtime (confirmed: silently null, not an error,
        # until .GetString() throws). Either way it's purely a byte-safe
        # 1:1 decode for finding an ASCII URL substring in binary data —
        # not an attempt to read the file's real encoding.
        $Text = [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($Bytes)
        $Found = $Text.Contains($BackendApiBaseUrl)
    }
    if (-not $Found) {
        Write-Host ''
        Write-Host "BUILD VERIFICATION FAILED: $BackendApiBaseUrl was not found in the compiled" -ForegroundColor Red
        Write-Host 'app. Installing this APK will reproduce "Verification is unavailable on' -ForegroundColor Red
        Write-Host 'this device right now." Do not distribute this build.' -ForegroundColor Red
        exit 1
    }
    Write-Host 'Confirmed: the backend URL is present in the compiled app.' -ForegroundColor Green
} finally {
    Remove-Item -Path $CheckDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Done: $ApkPath" -ForegroundColor Green
Write-Host 'Uninstall the app on the phone first, then install this. "Get OTP" on'
Write-Host 'the sign-in screen must actually text a code — "Verification is'
Write-Host 'unavailable on this device right now" means BACKEND_API_BASE_URL'
Write-Host 'above is wrong or the backend is unreachable, not a code problem.'
