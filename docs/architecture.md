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

## Order tracking

**`shield agent_invester/`** shows every order (standard and prescription) as
four stages and nothing else: **Placed → Store contact → Billed → Complete**
(plus **Cancelled** for a cancelled order). `Purchase.stage`
(`lib/module/orders/purchase_service.dart`) derives the furthest stage reached
from what the store has actually done; the raw `app.order.status` still drives
delivery and cancellation behind the scenes.

| Stage | Becomes true when |
| --- | --- |
| Placed | The order exists. |
| Store contact | Staff first click **Call** or **WhatsApp** beside the member's phone in the admin console — the Orders review modal, or a prescription's Details step for its linked order. That stamps `app."order".store_contacted_at` (migration `0045`); the first click wins. |
| Billed | A bill row exists for the order (`billStatus` is non-null on `GET /v1/member/orders`), i.e. it was converted and sent from the console's Bills page. |
| Complete | `app.order.status` is `DELIVERED` ("Complete order" on Bills). |

Checkout totals and payment never advance a stage on their own. An order that
was billed without anyone pressing Call still reads as Billed rather than being
stuck. An order already `OUT_FOR_DELIVERY` counts as at least Store contact.
`GET /v1/member/orders` returns `storeContactedAt` (null until contacted);
`backend/api` must be deployed with it, and migration `0045` applied first,
before the app can show the Store contact stage.

The tracking screen reloads orders on entry, every 15 seconds while it is the
current route, and on app resume, and also listens to order-book changes, so
the header, progress graph and details use the same refreshed record. Failed
loads retain the last known record; updates require connectivity.

The **root** Flutter app (`lib/`) has not been changed: it still renders
Processing, Out for delivery, Delivered or Cancelled straight from
`app.order.status`. These source changes require rebuilding the relevant
Flutter web/Android application before deployed clients receive them.

## Important boundary

The `shield agent_invester/` directory is a parallel project tree, not part of the normal root build commands. Treat it as legacy or separately targeted until ownership is clarified.
