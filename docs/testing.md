# Testing

## Permanent member purge

The existing pg-mem backend fixture cannot execute PL/pgSQL. An isolated
PGlite PostgreSQL engine tests migration 0089, using both relational fixtures
and the repository app schema, without touching a configured/live database:

```powershell
npm install --prefix .buildlog/pg-delete-test --no-save @electric-sql/pglite@0.5.9
node --test --test-isolation=none backend/db/tests/permanent_user_delete.test.mjs
```

Run these from the repository root. The temporary engine is under the
git-ignored `.buildlog`; no application dependency is added. Cases cover
fresh registration, peer preservation, session/token cleanup, staff role
rejection and rollback on a child failure. Backend role tests are also part
of `backend/api`'s normal Jest suite.

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
