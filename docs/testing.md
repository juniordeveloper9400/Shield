# Testing

## Flutter

Flutter tests are in `test/` and cover authentication, persona routing, navigation, catalogue and categories, products, cart and checkout, orders, prescriptions, labs, appointments, rewards, referrals, investor/agent flows, and Neon repositories. Shared fakes and helpers are under `test/support/`.

Run the full suite:

```powershell
flutter test -j 2
```

Run a focused file:

```powershell
flutter test test/auth_test.dart
```

Static analysis:

```powershell
flutter analyze
```

## Admin console

The current `shieldweb` package exposes typecheck and production build checks but no dedicated React test suite was found:

```powershell
Set-Location shieldweb
npm run typecheck
npm run build
```

Manual smoke checks should cover login/logout, role landing pages, protected routes, branch scoping, empty database states, and direct route refreshes.

## Test hygiene

Do not use production credentials or live destructive database commands in tests. Prefer fakes and isolated data. When a test depends on Firebase or Neon, document the required configuration and keep secrets outside the repository.

Historical test counts in `log.md` are not a substitute for a fresh run; report the command and result from the current checkout.
