# SHIELD Technical Requirements Document

**Status:** Current-state technical baseline with mandatory release remediation  
**Owners:** Flutter app, admin console, and database maintainers

## 1. System topology

```text
Flutter mobile/web client
  Firebase Phone Auth
  NeonHttp over HTTPS for member writes
  NeonDatabase PostgreSQL socket for native repository reads/writes

React/Vite operations console
  React Router + AuthContext
  API query modules
  @neondatabase/serverless over browser HTTPS

Neon PostgreSQL
  app schema: customer/member system
  public schema: Prisma-managed existing system
```

## 2. Runtime contracts

- Flutter entry: `lib/main.dart`.
- Flutter root routing: `lib/screens/root_screen.dart`.
- Flutter authenticated shell: `lib/screens/app_shell.dart`.
- Flutter persistence: `lib/data/neon/`.
- Admin entry: `shieldweb/src/main.tsx`.
- Admin route contract: `shieldweb/src/App.tsx`.
- Admin permission contract: `shieldweb/src/config/permissions.ts`.
- DDL contract: `backend/db/app_schema.sql`.

## 3. Non-functional requirements

| Area | Requirement | Verification |
| --- | --- | --- |
| Reliability | Launch should remain usable when optional warmups fail | Flutter tests and manual offline/error checks |
| Performance | Catalogue and review warmups should not block first shell render | Startup trace/manual check |
| Security | No client-bundled password or database authorization boundary in production | Bundle review and threat model |
| Privacy | Avoid logging personal health information, prescription images, or secrets | Log review and code review |
| Availability | Member write path must use HTTPS and fail visibly enough to diagnose | Neon health check and error-state tests |
| Accessibility | Controls need labels, readable contrast, keyboard/tap reachability, and meaningful error text | Manual UI review |
| Maintainability | Every schema, route, or role change updates traceability and docs | PR checklist |
| Reproducibility | Builds use pinned critical Firebase package versions and documented environment inputs | Clean-machine build |

## 4. Security architecture target

The current browser-direct Neon and static-credential design is internal-only. The target architecture is:

1. Managed identity or server-side auth verifies the operator.
2. A server API creates a short-lived session and enforces role/branch access.
3. Server-side database credentials never enter browser JavaScript.
4. Every mutation is validated and auditable on the server.
5. Prescription and member-health data is protected by least privilege and retention rules.

## 5. Data integrity rules

- Use `bigint` identity keys and UUID external ids as defined by the schema.
- Store monetary values as `numeric(12,2)`; do not compute financial values from formatted strings.
- Preserve order `mrp_total` and `paid_total`; derive the difference rather than storing duplicate earnings.
- Preserve wallet ledger entries as append-oriented accounting facts.
- Use Postgres enums for closed workflow states.
- Keep schema recreation separate from migration application.

## 6. Observability

The current app has launch-level Neon diagnostics. The target is structured, redacted events for auth failures, database availability, order transitions, prescription transitions, activation decisions, and admin authorization failures. Never include OTPs, passwords, connection strings, prescription images, or raw health records.

## 7. Compatibility and release gates

- Android package id: `com.zabnix.shield`.
- Flutter web support must be checked per plugin; PostgreSQL socket access is native-only.
- iOS is not release-ready until Firebase plist/APNs setup is complete.
- Android is not release-ready until a protected production keystore replaces the debug key.
- Admin console is not public-release-ready until auth and database access move server-side.

See [Tech Stack](tech-stack.md), [Database](database.md), and [Deployment](deployment.md).
