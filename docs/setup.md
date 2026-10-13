# Setup

## Prerequisites

- Flutter SDK compatible with Dart `^3.10.0`
- Android SDK and a configured emulator or device
- Node.js 20+ and npm for `shieldweb`
- A running `backend/api` instance (local or deployed) for member writes
- Firebase CLI and FlutterFire CLI when changing Firebase configuration

## Root environment

The app talks to `backend/api` over plain HTTPS — no database credential of
any kind is compiled into it. Copy `.env.example` to `.env` and set
`BACKEND_API_BASE_URL` to your `backend/api` instance, then:

```powershell
flutter pub get
flutter run --dart-define-from-file=.env
```

A build started without `BACKEND_API_BASE_URL` leaves every member write a
silent no-op (`BackendHttp.isConfigured` is `false`), logged once at launch
rather than crashing.

`backend/api`'s own database is still a Neon Postgres instance, but that
credential lives only in `backend/api`'s own `.env`, never in this app. To
verify connectivity to that database directly (a `backend/api` ops task, not
something this app needs):

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
2. Configure `.env` with `BACKEND_API_BASE_URL`.
3. Verify Firebase Android configuration.
4. Run the Flutter tests and app.
5. Install and typecheck the admin console separately.
6. Apply or seed database schema only after reviewing [Database](database.md).
