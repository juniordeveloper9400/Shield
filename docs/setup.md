# Setup

## Prerequisites

- Flutter SDK compatible with Dart `^3.10.0`
- Android SDK and a configured emulator or device
- Node.js 20+ and npm for `shieldweb`
- Dart access to the Neon database for backend tools
- Firebase CLI and FlutterFire CLI when changing Firebase configuration

## Root environment

Copy `.env.example` to `.env` and fill in the Neon connection string. Keep `.env` git-ignored.

The Windows build path avoids passing a Neon URL containing `&` through `flutter.bat`. Generate the ignored Dart secret before running builds that need member writes:

```powershell
dart run tool/gen_neon_secret.dart
flutter pub get
```

Check connectivity without changing data:

```powershell
dart run tool/neon_ping.dart
```

## OTP verification

Member sign-in and agent-registration's phone check both run through `backend/api`'s MSG91-backed `/v1/*/auth/otp/*` endpoints (see `backend/api/src/modules/otp/`) — no Firebase setup is needed in this app any more. Set `MSG91_WIDGET_ID`/`MSG91_WIDGET_TOKEN_AUTH` in `backend/api`'s own env (see its `.env.example`) for OTP sending to actually work; left unset, the endpoints report themselves unconfigured instead of crashing.

## Run the Flutter app

```powershell
flutter run
```

For Chrome:

```powershell
flutter run -d chrome --web-port 53431
```

## Admin console

```powershell
Set-Location shieldweb
npm install
```

Create `shieldweb/.env.local` from `shieldweb/.env.example` if the file exists in the checkout, then provide the values required by the current Vite configuration. The console currently has static credentials in source; do not use it as a public production authentication system. Start it with:

```powershell
npm run dev
```

Open the Vite URL shown by the command, normally `http://localhost:5173`.

## First setup order

1. Install Flutter dependencies.
2. Configure `.env` and generate the Neon secret.
3. Verify Neon connectivity.
4. Verify Firebase Android configuration.
5. Run the Flutter tests and app.
6. Install and typecheck the admin console separately.
7. Apply or seed database schema only after reviewing [Database](database.md).
