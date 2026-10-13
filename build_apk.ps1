# Builds the release APK with the Neon connection string compiled in.
#
#   powershell -ExecutionPolicy Bypass -File build_apk.ps1
#
# The connection string is NOT passed via --dart-define: it contains '&', and
# flutter.bat runs under cmd.exe on Windows, which treats '&' on the command
# line as a statement separator and truncates the value. Instead it lives in the
# git-ignored lib/data/neon/neon_secret.dart, generated from .env by the step
# below, and is just compiled in.
#
# SENTRY_DSN has no '&', so it IS passed via --dart-define, read straight out
# of the same .env gen_neon_secret.dart already requires. Blank (no line, or
# no .env yet) just builds with Sentry disabled — see docs/sentry.md.
#
# BACKEND_API_BASE_URL is public, not a secret — shield_backend's own
# deployed URL, hardcoded here the same way the agent app's own
# build_apk.ps1 does. NOT optional any more: member sign-in now runs
# entirely through backend/api's MSG91-backed /v1/member/auth/otp/*
# (see AuthService's own doc) — a blank or stale value here means
# BackendHttp.isEnabled is false on the built APK and every sign-in
# attempt fails immediately with "Verification is unavailable on this
# device right now," with no network call ever made. Update this the
# moment the backend is ever redeployed to a different domain.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$BackendApiBaseUrl = 'https://shieldbackend.vercel.app'

Write-Host 'Generating lib/data/neon/neon_secret.dart from .env ...' -ForegroundColor Cyan
dart run tool/gen_neon_secret.dart

$SentryDsn = ''
if (Test-Path '.env') {
    $line = Select-String -Path '.env' -Pattern '^\s*SENTRY_DSN\s*=' | Select-Object -Last 1
    if ($line) {
        $SentryDsn = ($line.Line -split '=', 2)[1].Trim().Trim('"').Trim("'")
    }
}

Write-Host 'Building release APK (one build at a time — close any other flutter build/run) ...' -ForegroundColor Cyan
flutter build apk --release --dart-define=BACKEND_API_BASE_URL=$BackendApiBaseUrl --dart-define=SENTRY_DSN=$SentryDsn

Write-Host ''
Write-Host 'Done: build/app/outputs/flutter-apk/app-release.apk' -ForegroundColor Green
Write-Host 'Uninstall the app on the phone first, then install this. "Get OTP" on'
Write-Host 'the sign-in screen must actually text a code — "Verification is'
Write-Host 'unavailable on this device right now" means BACKEND_API_BASE_URL'
Write-Host 'above is wrong or the backend is unreachable, not a code problem.'
