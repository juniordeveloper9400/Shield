# Setup

## Prerequisites

- Flutter SDK compatible with Dart `^3.10.0`
- Android SDK and a configured emulator or device
- Node.js 20+ and npm for `shieldweb`
- A running `backend/api` instance (local or deployed) for member writes

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

Member sign-in and agent-registration's phone check use MSG91's widget:
the browser page on web and a headless Android WebView on native. Build with
`MSG91_WIDGET_ID`, `MSG91_WIDGET_TOKEN_AUTH` and `BACKEND_API_BASE_URL`.
Android now defaults to the existing production backend and scoped public
widget settings in `lib/module/auth/mobile_build_config.dart`, so a normal
`flutter build apk --release` or app-bundle build includes OTP configuration
even without defines. Defines still override the defaults. Web configuration
continues to require explicit build settings.
Use `build_apk.ps1` / `build_aab.ps1` for Android releases; both pass the
required settings and check the compiled output. The widget sends/verifies
the SMS; the backend validates its resulting access token before issuing
the member session (`/v1/member/auth/widget/verify` or `/widget/register`)
or confirming the agent phone (`/v1/agent/otp/verify-widget`). Keep server
MSG91 credentials in backend environment settings, never in the client.
Firebase phone auth is not used for this member sign-in flow.

The current shared widget uses web mode with CAPTCHA disabled (checked
2026-10-13). Android embeds that same web widget. Do not switch this shared
widget to Mobile Integration without checking the web flow: MSG91 documents
that mobile mode is incompatible with the web widget. A future switch to
MSG91's mobile SDK needs a separately configured mobile widget. See
[MSG91 integration guidance](https://msg91.com/help/sendotp/how-to-integrate-the-new-login-with-otp-widget).

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
3. Verify the MSG91 settings on the backend.
4. Run the Flutter tests and app.
5. Install and typecheck the admin console separately.
6. Apply or seed database schema only after reviewing [Database](database.md).
