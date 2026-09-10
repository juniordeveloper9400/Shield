# Database and Backend

## Neon

The backend uses Neon Postgres. The root `.env` contains `DATABASE_URL` and is git-ignored. The app schema tools use the connection string directly. `tool/gen_neon_secret.dart` generates the ignored Flutter source used by local builds.

The connection paths are intentionally split:

- `NeonHttp` uses HTTPS for member sign-in and registration writes.
- `NeonDatabase` uses a PostgreSQL socket for the remaining native repository operations.
- The admin console uses `@neondatabase/serverless` over HTTPS from the browser.

## Schemas

### `app`

The customer-facing schema is defined by `backend/db/app_schema.sql` and described in `backend/db/APP_SCHEMA.md`. It stores users, stores, products, carts, orders, prescriptions, wallets, rewards, referrals, lab bookings, appointments, partner data, and related content.

Commands:

```powershell
dart run backend/db/apply_app_schema.dart       # dry run
dart run backend/db/apply_app_schema.dart --yes  # recreate app schema
dart run backend/db/seed_app.dart --yes
```

Recreation drops `app` with cascade. Review and confirm before using it against shared data.

### `public`

`public` is Prisma-managed and has its own migrations. `backend/db/SCHEMA.md` is a generated snapshot. The app schema commands do not write to `public`.

Commands:

```powershell
dart run backend/db/introspect.dart
dart run backend/db/apply_migration.dart backend/db/migrations/0001_admin_user.sql --yes
dart run backend/db/dump.dart
```

`wipe.dart` and `wipe_subset.dart` are destructive; do not run them casually.

## Operational notes

- The Data API endpoint described in `backend/README.md` exposes `public`; app queries must use the configured app schema path or qualified names.
- `backend/db/SCHEMA.md` includes generated metadata and should be refreshed when an accurate public-schema snapshot is needed.
- Database credentials must never ship in a public mobile or web build. The current browser-direct admin design is documented as a risk in [Security](security.md).
