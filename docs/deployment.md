# Deployment

## Android APK

Generate the local Neon secret and build the release APK with:

```powershell
powershell -ExecutionPolicy Bypass -File build_apk.ps1
```

The output is `build/app/outputs/flutter-apk/app-release.apk`. The current script notes that release signing uses the debug key. This is a release blocker: configure a protected production keystore, register its Firebase SHA-1 and SHA-256 fingerprints, and keep signing credentials out of git before distribution.

The script also compiles in Sentry's DSN from `.env`'s `SENTRY_DSN` line, if one is set — see [Sentry](sentry.md). Leaving it blank just builds with Sentry disabled.

## Flutter web

**Generate the Neon secret before building, the same as the APK does.** `NeonHttp` (`lib/data/neon/neon_http.dart`) reads its connection string from the compiled-in `kNeonDatabaseUrl` const in `lib/data/neon/neon_secret.dart` — never from `--dart-define` (that path is deliberately unused; see `tool/gen_neon_secret.dart`'s own doc comment on why). That file is git-ignored, so a clean checkout — including a hosting provider's build server — has none, and `flutter build web` still succeeds: it falls back to the empty-string stub, `NeonHttp.isConfigured` is `false`, and every Neon-backed read or write (sign-in/registration check, a member's own referral code shown as their Member ID, agent/investor detection for the Account screen and home feed) fails silently. The build looks identical to a working one; nothing errors, the UI just never gets data. Generate the real file first:

```powershell
dart run tool/gen_neon_secret.dart   # needs DATABASE_URL in a .env at the repo root
flutter build web
```

On a CI/hosting provider (Vercel or otherwise) that starts from a clean checkout, the build command must write that `.env` from a provider-set secret (never commit `DATABASE_URL` or `neon_secret.dart` itself) before running the generator, e.g.:

```bash
echo "DATABASE_URL=$DATABASE_URL" > .env && dart run tool/gen_neon_secret.dart && flutter build web
```

The web output is generated under `build/web`. Verify Firebase options and platform support before treating web auth or database behavior as production-ready.

To also compile in Sentry (crash and error reporting), add its DSN:

```powershell
flutter build web --dart-define=SENTRY_DSN=<your DSN>
```

or `--dart-define-from-file=.env` with `SENTRY_DSN=` set there. Leaving it out just ships with Sentry disabled. See [Sentry](sentry.md).

Pass `BACKEND_API_BASE_URL` (the deployed `shield_backend` URL — public, not a secret) so the app can mint a backend-issued session alongside its existing Neon sign-in:

```powershell
flutter build web --dart-define=BACKEND_API_BASE_URL=https://shieldbackend.vercel.app --dart-define=SENTRY_DSN=<your DSN>
```

Leaving it out just leaves `BackendHttp.isConfigured` false at runtime — currently a no-op either way, since no screen reads from `backend/api` yet (foundation-only slice; see the root-app off-direct-Neon migration notes).

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
- Verify Neon endpoint reachability and schema compatibility.
- Replace browser-bundled admin credentials with server-side auth and authorization.
- Move browser-direct database access behind a server API.
- Confirm backup and rollback procedures.
- Do not ship `.env`, generated Neon secret source, service-account files, passwords, or debug signing keys.
