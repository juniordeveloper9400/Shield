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

## Bills and invoices in the apps

Tapping a bill (Account → **Bills**, or **Bill** on an order card) opens the bill
screen, which shows two things the store sent:

1. **Bill from the store** — the picture an admin attached (`app.bill.image`), tappable to full screen. Absent for a bill the counter priced line by line.
2. **Invoice** — an itemised document drawn by `InvoiceView` (`lib/module/orders/invoice_view.dart`): the store, invoice number (the order code) and date, who it is billed to, delivery address or store pickup, every item with quantity, unit price and amount, then Subtotal, Delivery fee and Bill adjustment when they apply, the **Total**, and PAID / PAYMENT PENDING. **Share invoice** sends the same figures as text. It does not add a tax line: the console's invoice has none, so the app prints only what the store issued.

The invoice is built by `BillInvoice.compose` (`bill_invoice.dart`) the same way the console's `shieldweb/src/lib/invoice.ts buildInvoice` does — the saved bill amount is the total, and a delivery fee is listed only if it reconciles to it — with money held in paise so it adds up exactly. Items are the bill's own lines (`app.bill_line`); a bill that was only a picture falls back to the order's lines the counter marked *available* (never the out-of-stock ones). It is read fresh each time the screen opens, so a bill the counter has just edited shows its latest items.

- **Root app (`lib/`, Android and web build):** `OrderRepository.fetchInvoice` reads it from Neon in a query of its own, so a failure never disturbs the order list. A priced bill with no picture now counts as a bill (`Purchase.hasBill`) and appears in Bills. The old derived "Bill Details" estimate (MRP, discount, a fixed delivery line and an assumed 5% tax) is gone; only the **Pay now** button for an unpaid priced prescription remains, under the invoice.
- **`shield agent_invester/`:** `GET /v1/member/orders/:id/bill` (`backend/api`, `OrderService.getBillForMember`) now returns an `invoice` block beside the bill's own columns — items, store, customer, delivery address and order/payment state. `OrderRepository.invoiceFromBill` reads it into `Purchase.billInvoice` through `PurchaseService.ensureBillLoaded`. `backend/api` must be deployed with this change before that app can show items; until then it prints the bill's total and says the items were not listed. `stock_status` is filtered in SQL and never returned to the member.

Rebuild the relevant Flutter web/Android application before deployed clients receive these changes.

## Registration in `shield agent_invester/`

Whether a member is registered is the backend's call: `app.users.registration_completed_at`, which only `PATCH /v1/member/me` ever sets (on the first successful save, which also credits the 500-point bonus). The app never infers it from other fields.

**Reading it (`RegistrationService`).** On sign-in, on a restored launch, and again as soon as the backend session exists, the app asks `GET /v1/member/me`. It waits for the session, retries a few times, and holds one of five states: `unknown`, `checking`, `registered`, `notRegistered` (only ever the backend's own answer) or `unreachable` (could not ask). Only `notRegistered` shows the "Register now" bar; `unknown`/`checking` show nothing, and `unreachable` shows "Couldn't check your registration" with a retry — a registered member is never told to register because of a slow network or a refresh that outran the session. The profile's branch comes back as `homeStoreCode` whether or not that branch is still active; the public store list only carries active branches, so it is no longer used to decide anything.

**Saving it.** The form awaits the database write (`RegistrationService.submit`); the member only counts as registered, and only sees the celebration, once it has saved. A refusal — for example `STORE_UNAVAILABLE` when the chosen branch is switched off in the console's Stores page — is shown on the form and the form stays open. The branch is sent by code (`homeStoreCode`). A member may always keep their current branch when editing, even if it has since been switched off; choosing a *different*, inactive branch is refused.

**Only registered members can act.** Browsing is open. Adding to the cart, checkout, uploading a prescription, ordering on a prescription, booking a lab test and buying a Health Pass all go through `RegistrationGate` (`AuthFlow.guardRegistered`), which waits for an unresolved lookup, then explains and offers the form to an unregistered member. The backend enforces the same rule (`@RequireRegistered()`, `RegisteredGuard`): `POST cart/lines`, `POST orders`, `POST prescriptions`, `POST prescription-orders`, `POST lab-bookings`, `POST appointments` and `POST wallet/cards` answer `403 REGISTRATION_REQUIRED` for an unregistered member. Reading (`GET`), registering (`PATCH /me`) and the agent-request routes are unaffected. Deploy `backend/api` before rebuilding the app, so the app's `homeStoreCode` save and read are understood.

The root Flutter app (`lib/`) does not use `backend/api` and is unchanged.

Note for whoever runs the console: only branches marked active can be *newly* chosen at registration, so a registration form for a member whose nearest branch is switched off will be refused with a clear message until a different branch is chosen or that branch is re-activated.

## Important boundary

The `shield agent_invester/` directory is a parallel project tree, not part of the normal root build commands. Treat it as legacy or separately targeted until ownership is clarified.
