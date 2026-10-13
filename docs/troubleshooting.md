# Troubleshooting

## Member writes do nothing

The app has no database credential of its own — every write goes through `backend/api`. Confirm `BACKEND_API_BASE_URL` was set at build time and the backend is reachable; check the launch log for the connected/unreachable status it logs once at startup (`BackendHttp.isConfigured`).

## OTP sign-in reports "not configured" / "unavailable"

Current builds use the MSG91 widget on both web and Android, with server
validation of the resulting token. A build missing `MSG91_WIDGET_ID` or
`MSG91_WIDGET_TOKEN_AUTH` cannot send SMS. A build missing
`BACKEND_API_BASE_URL` cannot complete sign-in. Rebuild using the release
scripts, rather than distributing an older desktop APK. These settings are
compiled into the app; changing server settings cannot repair an already
installed app that lacks them. Version 1.0.4+18 adds Android defaults for the
public backend/widget configuration, fixing builds made without defines.
Install this new release; earlier APKs retain their original configuration.

Android startup waits for the WebView JavaScript bridge, retries failed
initialization and times out loading after 20 seconds. Send/verify callbacks
time out after 30 seconds; retry after restoring connectivity. The widget
script requires access to `verify.msg91.com` and `control.msg91.com`.
If provider settings change, check CAPTCHA and mobile integration against
the working web configuration. Test SMS delivery, resend and token-backed
sign-in on an actual Android device before publishing a new Play release.

## Admin console is empty

The console reads the Neon `app` schema directly and has no mock data. Confirm the schema and reference data have been applied, the Vite environment is set, and the browser can reach the configured endpoint.

## Admin login behavior differs from old docs

The current implementation uses the static credential list in `shieldweb/src/config/admins.ts` and `localStorage`; it does not use the Firebase/database flow described in the older `shieldweb/README.md`. Treat this as an internal development limitation and consult [Admin Console](admin-console.md).

## Flutter assets or build output look stale

### Android release fails in Sentry with Kotlin language version 1.6

`sentry_flutter` 8.14.2 pins its Android Kotlin language version to 1.6,
which the project's Kotlin 2.2.20 compiler rejects. `android/build.gradle.kts`
overrides only Sentry's Kotlin compile tasks to language version 1.8, leaving
its JVM target unchanged. Keep this override while using that package version;
do not patch the shared pub cache. Verify with `flutter build apk --release`.

Run `flutter clean` only when needed, then `flutter pub get` and the focused build/test command. Do not commit generated `build/` or `.dart_tool/` output.

## Database tool safety

`apply_app_schema.dart --yes`, `wipe.dart --yes`, and `wipe_subset.dart ... --yes` can destroy data. Stop, verify the target database, and take a backup before running them.
