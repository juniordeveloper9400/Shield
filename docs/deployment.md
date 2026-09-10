# Deployment

## Android APK

Generate the local Neon secret and build the release APK with:

```powershell
powershell -ExecutionPolicy Bypass -File build_apk.ps1
```

The output is `build/app/outputs/flutter-apk/app-release.apk`. The current script notes that release signing uses the debug key. This is a release blocker: configure a protected production keystore, register its Firebase SHA-1 and SHA-256 fingerprints, and keep signing credentials out of git before distribution.

## Flutter web

Build with:

```powershell
flutter build web
```

The web output is generated under `build/web`. Verify Firebase options and platform support before treating web auth or database behavior as production-ready.

## Admin console hosting

From `shieldweb/`:

```powershell
npm run build
npm run preview
```

The Vite build emits `dist`. `shieldweb/vercel.json` configures `npm run build`, `dist`, and an SPA fallback. `shieldweb/public/_redirects` supports hosts that use that convention.

Set the required Vite environment values in the hosting provider and redeploy after changing them because Vite embeds them at build time. Add the deployed domain to Firebase Authorized Domains only if the implemented authentication flow uses Firebase.

## Pre-release checklist

- Run `flutter analyze`, `flutter test -j 2`, `npm run typecheck`, and `npm run build`.
- Verify Firebase configuration and release-key fingerprints.
- Verify Neon endpoint reachability and schema compatibility.
- Replace browser-bundled admin credentials with server-side auth and authorization.
- Move browser-direct database access behind a server API.
- Confirm backup and rollback procedures.
- Do not ship `.env`, generated Neon secret source, service-account files, passwords, or debug signing keys.
