# Deployment

## Android APK

Build the release APK with:

```powershell
powershell -ExecutionPolicy Bypass -File build_apk.ps1
```

The output is `build/app/outputs/flutter-apk/app-release.apk`. The current script notes that release signing uses the debug key. This is a release blocker: configure a protected production keystore, register its Firebase SHA-1 and SHA-256 fingerprints, and keep signing credentials out of git before distribution.

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

The web output is generated under `build/web`. Verify Firebase options and platform support before treating web auth or database behavior as production-ready.

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

Set the required Vite environment values in the hosting provider and redeploy after changing them because Vite embeds them at build time. Add the deployed domain to Firebase Authorized Domains only if the implemented authentication flow uses Firebase.

## Pre-release checklist

- Run `flutter analyze`, `flutter test -j 2`, `npm run typecheck`, and `npm run build`.
- Verify Firebase configuration and release-key fingerprints.
- Verify `backend/api` and its Neon database are reachable and schema-compatible.
- Replace browser-bundled admin credentials with server-side auth and authorization.
- Move browser-direct database access behind a server API.
- Confirm backup and rollback procedures.
- Do not ship `.env`, service-account files, passwords, or debug signing keys.
