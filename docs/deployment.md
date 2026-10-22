# Deployment

## Android APK

Build the release APK with:

```powershell
powershell -ExecutionPolicy Bypass -File build_apk.ps1
```

The output is `build/app/outputs/flutter-apk/app-release.apk`. The app uses
the upload signing key from git-ignored `android/key.properties` when
configured; Gradle currently falls back to the debug key when it is absent.
Use the upload key for distributable releases and keep it out of git.

Build the Play Store bundle with `powershell -ExecutionPolicy Bypass -File
build_aab.ps1`; output is `build/app/outputs/bundle/release/app-release.aab`.
Both scripts pass the backend URL and MSG91 widget settings, fail on a
nonzero Flutter exit code, and inspect compiled Dart output for the required
settings and native widget bridge. Use a version code greater than the last
Play upload. Version 1.0.3+17 includes the Android OTP bridge retry/timeout
fixes. Version 1.0.4+18 additionally supplies Android production defaults
when ordinary Flutter builds omit dart-defines. Explicit defines override
those defaults; web builds still require explicit configuration.
Existing installations need the new APK or a published Play update;
they do not pick up Dart fixes from a web deployment.

An APK already copied to the desktop is not refreshed by building again.
Keep the new APK and AAB in a separate artifact folder before another build
script runs `flutter clean`. Test SMS delivery, resend and verified sign-in
on Android before uploading the AAB to Play Console.

The script also compiles in Sentry's DSN from `.env`'s `SENTRY_DSN` line, if one is set — see [Sentry](sentry.md). Leaving it blank just builds with Sentry disabled.

## Flutter web

No database credential is compiled in — every data path goes through
`backend/api` over plain HTTPS. Pass `BACKEND_API_BASE_URL` (the deployed
`shield_backend` URL — public, not a secret) so the build can actually
reach it:

```powershell
flutter build web --dart-define=BACKEND_API_BASE_URL=https://shieldbackend.vercel.app
```

Leaving it out builds successfully but leaves `BackendHttp.isConfigured`
false at runtime: sign-in, registration, the catalogue, and every other
member-facing read or write fails silently rather than erroring — the
build looks identical to a working one; nothing errors, the UI just never
gets data.

The web output is generated under `build/web`.

To also compile in Sentry (crash and error reporting), add its DSN:

```powershell
flutter build web --dart-define=BACKEND_API_BASE_URL=https://shieldbackend.vercel.app --dart-define=SENTRY_DSN=<your DSN>
```

or `--dart-define-from-file=.env` with `BACKEND_API_BASE_URL=`/`SENTRY_DSN=` set there. Leaving `SENTRY_DSN` out just ships with Sentry disabled. See [Sentry](sentry.md).

## Admin console hosting

From `shieldweb/`:

```powershell
npm run build
npm run preview
```

The Vite build emits `dist`. `shieldweb/vercel.json` configures `npm run build`, `dist`, and an SPA fallback. `shieldweb/public/_redirects` supports hosts that use that convention.

Set `VITE_SENTRY_DSN` in the hosting provider's environment (or `shieldweb/.env.local` for local dev) to turn on Sentry crash/error reporting — see [Sentry](sentry.md). Vite embeds it at build time like every other `VITE_` var, so redeploy after setting or changing it.

Set the required Vite environment values in the hosting provider and redeploy after changing them because Vite embeds them at build time.

## Pre-release checklist

- Run `flutter analyze`, `flutter test -j 2`, `npm run typecheck`, and `npm run build`.
- Verify MSG91 configuration (`MSG91_AUTH_KEY`, `MSG91_WIDGET_ID`, `MSG91_WIDGET_TOKEN_AUTH` on the backend; `VITE_MSG91_*` on the admin console) and release-key fingerprints.
- Verify `backend/api` and its Neon database are reachable and schema-compatible.
- Replace browser-bundled admin credentials with server-side auth and authorization.
- Move browser-direct database access behind a server API.
- Confirm backup and rollback procedures.
- Do not ship `.env`, service-account files, passwords, or debug signing keys.
