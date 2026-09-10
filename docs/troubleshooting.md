# Troubleshooting

## Neon writes do nothing

Run `dart run tool/gen_neon_secret.dart` after changing `.env`. On Windows, do not rely on a raw `--dart-define` for a connection string containing `&`; the build wrapper generates the ignored Dart secret instead. Check the launch log for the Neon configured/endpoint status.

## Firebase phone auth is unavailable

Confirm `android/app/google-services.json` exists, the package id is `com.zabnix.shield`, Phone sign-in is enabled, and the SHA-1/SHA-256 fingerprints for the signing key are registered. Re-download the Firebase config after adding fingerprints. See `FIREBASE_SETUP.md`.

## Admin console is empty

The console reads the Neon `app` schema directly and has no mock data. Confirm the schema and reference data have been applied, the Vite environment is set, and the browser can reach the configured endpoint.

## Admin login behavior differs from old docs

The current implementation uses the static credential list in `shieldweb/src/config/admins.ts` and `localStorage`; it does not use the Firebase/database flow described in the older `shieldweb/README.md`. Treat this as an internal development limitation and consult [Admin Console](admin-console.md).

## Flutter assets or build output look stale

Run `flutter clean` only when needed, then `flutter pub get` and the focused build/test command. Do not commit generated `build/` or `.dart_tool/` output.

## Database tool safety

`apply_app_schema.dart --yes`, `wipe.dart --yes`, and `wipe_subset.dart ... --yes` can destroy data. Stop, verify the target database, and take a backup before running them.
