# Troubleshooting

## Neon writes do nothing

Run `dart run tool/gen_neon_secret.dart` after changing `.env`. On Windows, do not rely on a raw `--dart-define` for a connection string containing `&`; the build wrapper generates the ignored Dart secret instead. Check the launch log for the Neon configured/endpoint status.

## OTP sign-in reports "not configured" / "unavailable"

Member sign-in and agent registration's phone check both run through `backend/api`'s MSG91-backed endpoints now, not Firebase. "Not configured" means `MSG91_WIDGET_ID`/`MSG91_WIDGET_TOKEN_AUTH` are unset on the backend; "unavailable" means the app couldn't reach the backend at all — confirm `BACKEND_API_BASE_URL` was set at build time (`--dart-define=BACKEND_API_BASE_URL=...`) and the backend is actually reachable. See `backend/api/src/modules/otp/otp.service.ts`.

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
