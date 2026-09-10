# Decision Log

This index records decisions that materially affect product behavior, architecture, schema, security, or operations. Use [ADR Template](adr-template.md) for each new decision.

## Existing decisions documented in code

| Decision | Evidence | Implication |
| --- | --- | --- |
| Keep customer tables in a separate `app` schema | `backend/db/app_schema.sql`, `APP_SCHEMA.md` | App schema recreation must not touch `public` |
| Use HTTPS for member Neon writes | `lib/data/neon/neon_http.dart`, `backend/README.md` | Avoid Windows command-line truncation of URLs containing `&` |
| Warm catalogue/reviews without blocking launch | `lib/main.dart` | Screens must handle loading and fallback states |
| Pharmacy access carries a branch code | `shieldweb/src/config/permissions.ts` | Final enforcement must move server-side |
| Current admin login is client-side static credentials | `shieldweb/src/config/admins.ts`, `AuthContext.tsx` | Internal-only; production remediation required |

## Open decisions

- Replace static admin credentials with managed/server-side authentication.
- Put admin Neon queries behind a trusted API.
- Reconcile `admin` role with `app.admin_role` enum.
- Reconcile customer-review video migration and DDL drift.
- Decide the final agent/investor portal boundary.
- Configure production Android signing and release infrastructure.
