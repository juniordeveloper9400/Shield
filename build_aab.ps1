# Builds the release Android App Bundle (.aab, for the Play Store) with the
# Neon connection string compiled in.
#
#   powershell -ExecutionPolicy Bypass -File build_aab.ps1
#
# Same build as build_apk.ps1 (read that file's own comments for why the
# Neon connection string and SENTRY_DSN are each passed the way they are) —
# this just asks flutter for an app bundle instead of an APK, since that is
# what the Play Store wants for a new release.

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

Write-Host 'Building release App Bundle (one build at a time — close any other flutter build/run) ...' -ForegroundColor Cyan
flutter build appbundle --release --dart-define=BACKEND_API_BASE_URL=$BackendApiBaseUrl --dart-define=SENTRY_DSN=$SentryDsn

Write-Host ''
Write-Host 'Done: build/app/outputs/bundle/release/app-release.aab' -ForegroundColor Green
Write-Host 'Upload this .aab to the Play Console as the new release.'
