# Builds the release Android App Bundle (.aab, for the Play Store). No
# database credential is compiled in — see build_apk.ps1's own comments for
# how BACKEND_API_BASE_URL and SENTRY_DSN are passed; this just asks
# flutter for an app bundle instead of an APK, since that is what the Play
# Store wants for a new release.
#
# Always starts with `flutter clean`, and verifies BACKEND_API_BASE_URL
# actually made it into the compiled code afterward — see build_apk.ps1's
# own comment for why: confirmed live on this machine (2026-10-13) that a
# plain `flutter build` after an earlier build can silently keep the
# previous build's compiled Dart code, dart-defines included, with no
# error or non-zero exit code. Do not remove either step for a faster
# build — a release uploaded to the Play Store with the wrong backend (or
# none) is far more expensive to notice and fix than a few extra minutes
# here.

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

Write-Host 'Building release App Bundle (one build at a time — close any other flutter build/run) ...' -ForegroundColor Cyan
flutter build appbundle --release --dart-define=BACKEND_API_BASE_URL=$BackendApiBaseUrl --dart-define=SENTRY_DSN=$SentryDsn

$AabPath = 'build\app\outputs\bundle\release\app-release.aab'

# Self-check — same reasoning as build_apk.ps1's own. An .aab is a zip of
# per-module zips (base/lib/<abi>/libapp.so inside the "base" module), so
# one Expand-Archive unpacks it directly; no nested-zip step needed.
Write-Host 'Verifying the backend URL actually made it into the build ...' -ForegroundColor Cyan
$CheckDir = Join-Path $env:TEMP "shield-aab-check-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $CheckDir -Force | Out-Null
try {
    $ZipCopy = Join-Path $CheckDir 'app-release.zip'
    Copy-Item $AabPath $ZipCopy
    Expand-Archive -Path $ZipCopy -DestinationPath $CheckDir -Force
    $LibApp = Get-ChildItem -Path $CheckDir -Recurse -Filter 'libapp.so' | Select-Object -First 1
    $Found = $false
    if ($LibApp) {
        $Bytes = [System.IO.File]::ReadAllBytes($LibApp.FullName)
        # ISO-8859-1, not Encoding.Latin1 — see build_apk.ps1's own comment
        # on why (null under Windows PowerShell 5.1's .NET Framework
        # runtime). Purely a byte-safe 1:1 decode for a substring search.
        $Text = [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($Bytes)
        $Found = $Text.Contains($BackendApiBaseUrl)
    }
    if (-not $Found) {
        Write-Host ''
        Write-Host "BUILD VERIFICATION FAILED: $BackendApiBaseUrl was not found in the compiled" -ForegroundColor Red
        Write-Host 'app. Do not upload this .aab to the Play Store.' -ForegroundColor Red
        exit 1
    }
    Write-Host 'Confirmed: the backend URL is present in the compiled app.' -ForegroundColor Green
} finally {
    Remove-Item -Path $CheckDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Done: $AabPath" -ForegroundColor Green
Write-Host 'Upload this .aab to the Play Console as the new release.'
