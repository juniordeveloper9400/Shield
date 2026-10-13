# Builds the release Android App Bundle (.aab, for the Play Store). No
# database credential is compiled in — see build_apk.ps1's own comments for
# how BACKEND_API_BASE_URL, MSG91_WIDGET_ID/MSG91_WIDGET_TOKEN_AUTH, and
# SENTRY_DSN are passed, and why the MSG91 pair is required now too; this
# just asks flutter for an app bundle instead of an APK, since that is what
# the Play Store wants for a new release.
#
# Always starts with `flutter clean`, and verifies every required value
# actually made it into the compiled code afterward — see build_apk.ps1's
# own comment for why: confirmed live on this machine (2026-10-13) that a
# plain `flutter build` after an earlier build can silently keep the
# previous build's compiled Dart code, dart-defines included, with no
# error or non-zero exit code. Do not remove either step for a faster
# build — a release uploaded to the Play Store with the wrong backend (or
# none), or with OTP sign-in broken, is far more expensive to notice and
# fix than a few extra minutes here.

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

Write-Host 'Building release App Bundle (one build at a time — close any other flutter build/run) ...' -ForegroundColor Cyan
flutter build appbundle --release `
  --dart-define=BACKEND_API_BASE_URL=$BackendApiBaseUrl `
  --dart-define=MSG91_WIDGET_ID=$Msg91WidgetId `
  --dart-define=MSG91_WIDGET_TOKEN_AUTH=$Msg91TokenAuth `
  --dart-define=SENTRY_DSN=$SentryDsn
if ($LASTEXITCODE -ne 0) { throw 'AAB build failed; do not upload older output.' }

$AabPath = 'build\app\outputs\bundle\release\app-release.aab'

# Self-check — same reasoning as build_apk.ps1's own. An .aab is a zip of
# per-module zips (base/lib/<abi>/libapp.so inside the "base" module), so
# one Expand-Archive unpacks it directly; no nested-zip step needed.
Write-Host 'Verifying the required values actually made it into the build ...' -ForegroundColor Cyan
$CheckDir = Join-Path $env:TEMP "shield-aab-check-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $CheckDir -Force | Out-Null
try {
    $ZipCopy = Join-Path $CheckDir 'app-release.zip'
    Copy-Item $AabPath $ZipCopy
    Expand-Archive -Path $ZipCopy -DestinationPath $CheckDir -Force
    $LibApp = Get-ChildItem -Path $CheckDir -Recurse -Filter 'libapp.so' | Select-Object -First 1
    $Text = ''
    if ($LibApp) {
        $Bytes = [System.IO.File]::ReadAllBytes($LibApp.FullName)
        # ISO-8859-1, not Encoding.Latin1 — see build_apk.ps1's own comment
        # on why (null under Windows PowerShell 5.1's .NET Framework
        # runtime). Purely a byte-safe 1:1 decode for a substring search.
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
        Write-Host 'Do not upload this .aab to the Play Store.' -ForegroundColor Red
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
Write-Host "Done: $AabPath" -ForegroundColor Green
Write-Host 'Upload this .aab to the Play Console as the new release.'
