# Architecture

## Repository boundaries

```text
Flutter member app (root)
  lib/main.dart -> RootScreen -> AppShell -> feature modules
  lib/data/neon -> Neon HTTP and PostgreSQL repositories
  Firebase -> member phone authentication
  Neon app schema -> member data and content

React operations console (shieldweb/)
  src/main.tsx -> AuthProvider -> App routes/pages
  src/api -> direct Neon HTTPS queries
  app schema -> stores, catalogue, orders, prescriptions, labs, appointments
```

The root Flutter app and `shieldweb` are separate applications but share the Neon `app` schema. The `public` schema is an existing Prisma-managed back-office schema and is not the target of the app schema tools.

## Flutter startup

`lib/main.dart` initializes Flutter and Firebase, restores the member session, starts persona checking, attaches rewards and referral services, warms catalogue and review data, checks the Neon HTTP endpoint, and then renders `ShieldApp` with `RootScreen`.

`RootScreen` decides among splash, phone sign-in, web-only agent/investor routing, and the authenticated `AppShell`. The shell exposes the member-facing home, health/labs, clinics, orders, and account areas.

## Flutter source ownership

- `lib/module/auth/`: Firebase phone auth, session, persona gate, and registration auth flows.
- `lib/module/catalogue/`, `categories/`, `product/`, `search/`: catalogue browsing.
- `lib/module/cart/`, `checkout/`, `orders/`: purchase workflow.
- `lib/module/prescription/`: prescription upload and prescription checkout.
- `lib/module/labtest/`, `appointment/`, `dietitian/`, `patients/`: care services.
- `lib/module/wallet/`, `rewards/`, `refer/`, `investment/`, `agent/`: account and partner features.
- `lib/data/neon/`: database clients and repositories.
- `lib/screens/`, `lib/widgets/`, `lib/theme/`: composition and shared UI.

## Data paths

Member sign-in and registration writes use `NeonHttp` over HTTPS. Other repository operations use `NeonDatabase` and the PostgreSQL socket. The generated `lib/data/neon/neon_secret.dart` supplies the connection value for local builds and is git-ignored.

The admin console uses `@neondatabase/serverless` directly from the browser. This is an internal implementation with a significant production security limitation; see [Security](security.md).

## Important boundary

The `shield agent_invester/` directory is a parallel project tree, not part of the normal root build commands. Treat it as legacy or separately targeted until ownership is clarified.
