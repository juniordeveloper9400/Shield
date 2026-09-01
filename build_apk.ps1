# Builds the release APK with the Neon connection string compiled in.
#
#   powershell -ExecutionPolicy Bypass -File build_apk.ps1
#
# The connection string is NOT passed via --dart-define: it contains '&', and
# flutter.bat runs under cmd.exe on Windows, which treats '&' on the command
# line as a statement separator and truncates the value. Instead it lives in the
# git-ignored lib/data/neon/neon_secret.dart, generated from .env by the step
# below, and is just compiled in. So the build itself takes no special flags.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host 'Generating lib/data/neon/neon_secret.dart from .env ...' -ForegroundColor Cyan
dart run tool/gen_neon_secret.dart

Write-Host 'Building release APK (one build at a time — close any other flutter build/run) ...' -ForegroundColor Cyan
flutter build apk --release

Write-Host ''
Write-Host 'Done: build/app/outputs/flutter-apk/app-release.apk' -ForegroundColor Green
Write-Host 'Uninstall the app on the phone first, then install this. The login'
Write-Host 'screen must show a green "Database connected" line.'
