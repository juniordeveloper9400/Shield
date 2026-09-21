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

### Order status on the prescription cards

Each card on **Upload Prescription → Your prescriptions** now has an **Order status** section once its prescription is linked to an order (`app.prescription_order.order_id`): the order code, a stage chip, a four-step progress line, a one-line explanation (English and Malayalam, following the screen's language switch) and a **Track order** link. A prescription that was only uploaded shows nothing. When a script was reordered it is linked to several orders, and the newest one is shown.

- **`shield agent_invester/`** shows the four stages above (Placed → Store contact → Billed → Complete, or Cancelled). `GET /v1/member/prescriptions` and `/:id` (`backend/api`, `PrescriptionService.latestOrders`) now return an `order` block — `id`, `code`, `status`, `storeContactedAt` and `billed` — which the app reads into `PrescriptionRecord.order` (`LinkedOrder`). The stage comes from `OrderStage.derive`, the same rule `Purchase.stage` uses on Track order, and the card prefers the app's loaded order book (`PurchaseService.purchaseFor`) over the block because it is refreshed more often. `backend/api` must be deployed with this change; until then the cards look as before.
- **Root app (`lib/`)** shows its own statuses (Order placed → Processing → Out for delivery → Delivered, or Cancelled), drawn from the same `OrderTrack` steps as Track order. `PrescriptionRepository.fetchForMember` reads the linked order with a `LATERAL` join in the same Neon query.
- Both screens load the order book on open, refresh it every 15 seconds while the screen is current (only with a backend/database configured), look for the link of a prescription that is ordered but not linked yet, and re-read after checkout returns and on pull-to-refresh.

The yellow diagnostic line some cards show (`picked=1 | … | insertUpload ok, id=44`) is the agent app's temporary `PrescriptionRecord.imageDebugNote`, added for the "photo never reached the counter" bug. It is not part of this feature and is still there; remove it once that bug is closed.

## Bills and invoices in the apps

Tapping a bill (Account → **Bills**, or **Bill** on an order card) opens the bill
screen, which shows two things the store sent:

1. **Bill from the store** — the picture an admin attached (`app.bill.image`), tappable to full screen. Absent for a bill the counter priced line by line.
2. **Invoice** — an itemised document drawn by `InvoiceView` (`lib/module/orders/invoice_view.dart`): the store, invoice number (the order code) and date, who it is billed to, delivery address or store pickup, every item with quantity, unit price and amount, then Subtotal, Delivery fee and Bill adjustment when they apply, the **Total**, and PAID / PAYMENT PENDING. **Share invoice** sends the same figures as text. It does not add a tax line: the console's invoice has none, so the app prints only what the store issued.

The invoice is built by `BillInvoice.compose` (`bill_invoice.dart`) the same way the console's `shieldweb/src/lib/invoice.ts buildInvoice` does — the saved bill amount is the total, and a delivery fee is listed only if it reconciles to it — with money held in paise so it adds up exactly. Items are the bill's own lines (`app.bill_line`); a bill that was only a picture falls back to the order's lines the counter marked *available* (never the out-of-stock ones). It is read fresh each time the screen opens, so a bill the counter has just edited shows its latest items.

- **Root app (`lib/`, Android and web build):** `OrderRepository.fetchInvoice` reads it from Neon in a query of its own, so a failure never disturbs the order list. A priced bill with no picture now counts as a bill (`Purchase.hasBill`) and appears in Bills. The old derived "Bill Details" estimate (MRP, discount, a fixed delivery line and an assumed 5% tax) is gone; only the **Pay now** button for an unpaid priced prescription remains, under the invoice.
- **`shield agent_invester/`:** `GET /v1/member/orders/:id/bill` (`backend/api`, `OrderService.getBillForMember`) now returns an `invoice` block beside the bill's own columns — items, store, customer, delivery address and order/payment state. `OrderRepository.invoiceFromBill` reads it into `Purchase.billInvoice` through `PurchaseService.ensureBillLoaded`. `backend/api` must be deployed with this change before that app can show items; until then it prints the bill's total and says the items were not listed. `stock_status` is filtered in SQL and never returned to the member.

Rebuild the relevant Flutter web/Android application before deployed clients receive these changes.

## Order and prescription pictures on My Orders / Track order

Both apps show what an order actually is, not just its name and total: a thumbnail on each My Orders card, an itemised "Items in this order" card with each product's real picture on a standard order's tracker, and the member's own uploaded scan (not a generic icon and a toast) on a prescription order's tracker. Every fetch is best-effort and lazy — fired once a card or tracker actually opens, never carried on the cheap list read, and rendering nothing rather than an error when it fails or has not landed yet.

- **Root app (`lib/`, Android and web build):** `OrderRepository.fetchItems` / `.fetchPrescriptions` (`lib/data/neon/order_repository.dart`) query Neon directly by the order's own `code`. `PrescriptionUploadedCard` (`order_detail_sections.dart`) is no longer a static placeholder — it fetches the real scan the same way `OrderItemsCard` fetches product pictures.
- **`shield agent_invester/`:** `GET /v1/member/orders/:id/items` (`backend/api`, `OrderService.getItemsForOrder`) is new alongside the existing `.../prescriptions` route — `app.order_line` left-joined to `app.product` for `image`, filtered to `stock_status = 'AVAILABLE'` the same way the invoice's own lines are. Empty for a prescription order, which never gets `order_line` rows. `OrderRepository.fetchItems` (`lib/data/backend/order_repository.dart`) reads it; `OrderItemsCard` and the My Orders thumbnail call it lazily. `backend/api` must be deployed with this change before that app can show product pictures; until then the card and thumbnail simply show nothing.

## Registration in `shield agent_invester/`

Whether a member is registered is the backend's call: `app.users.registration_completed_at`, which only `PATCH /v1/member/me` ever sets (on the first successful save, which also credits the 500-point bonus). The app never infers it from other fields.

**Reading it (`RegistrationService`).** On sign-in, on a restored launch, and again as soon as the backend session exists, the app asks `GET /v1/member/me`. It waits for the session, retries a few times, and holds one of five states: `unknown`, `checking`, `registered`, `notRegistered` (only ever the backend's own answer) or `unreachable` (could not ask). Only `notRegistered` shows the "Register now" bar; `unknown`/`checking` show nothing, and `unreachable` shows "Couldn't check your registration" with a retry — a registered member is never told to register because of a slow network or a refresh that outran the session. The profile's branch comes back as `homeStoreCode` whether or not that branch is still active; the public store list only carries active branches, so it is no longer used to decide anything.

**Saving it.** The form awaits the database write (`RegistrationService.submit`); the member only counts as registered, and only sees the celebration, once it has saved. A refusal — for example `STORE_UNAVAILABLE` when the chosen branch is switched off in the console's Stores page — is shown on the form and the form stays open. The branch is sent by code (`homeStoreCode`). A member may always keep their current branch when editing, even if it has since been switched off; choosing a *different*, inactive branch is refused.

**Only registered members can act.** Browsing is open. Adding to the cart, checkout, uploading a prescription, ordering on a prescription, booking a lab test and buying a Health Pass all go through `RegistrationGate` (`AuthFlow.guardRegistered`), which waits for an unresolved lookup, then explains and offers the form to an unregistered member. The backend enforces the same rule (`@RequireRegistered()`, `RegisteredGuard`): `POST cart/lines`, `POST orders`, `POST prescriptions`, `POST prescription-orders`, `POST lab-bookings`, `POST appointments` and `POST wallet/cards` answer `403 REGISTRATION_REQUIRED` for an unregistered member. Reading (`GET`), registering (`PATCH /me`) and the agent-request routes are unaffected. Deploy `backend/api` before rebuilding the app, so the app's `homeStoreCode` save and read are understood.

The root Flutter app (`lib/`) does not use `backend/api` and is unchanged.

Note for whoever runs the console: only branches marked active can be *newly* chosen at registration, so a registration form for a member whose nearest branch is switched off will be refused with a clear message until a different branch is chosen or that branch is re-activated.

## Wallet transaction history (root app)

`WalletService.balance` and `entries` (Account → My Wallet → Transaction history) are read back from the real `app.wallet_entry` ledger, not kept as a running local total. `WalletService.refreshFromDatabase` (called on sign-in, session restore, app resume, and after checkout) pulls `app.wallet.balance` and every `wallet_entry` row for the member (`WalletRepository.fetchWallet` / `fetchEntries`) and `applyRemoteWallet` replaces the balance and the whole list with them — matching `shield agent_invester/`'s backend-based `WalletService`, which already worked this way.

This is what keeps an order's transaction honest: the database only writes a `SPEND` row once money has actually moved — at checkout for a standard order paid by wallet, or, for a prescription order, only once the store has billed it and staff have collected it with the member's OTP (`collectBillWithWallet`, `shieldweb/src/api/billPayments.ts`). Reading the ledger back is what makes an order's debit appear "only after bill received and OTP validation" — nothing on the client decides that, the row simply does not exist in the database until then. The same reasoning `MemberEarnings` already uses, reading fresh off the order list rather than a locally kept total.

`ACTIVATION`/`BONUS`/`REFERRAL_EARNINGS`/`AGENT_EARNINGS` rows read back the same way, superseding the narrower `applyReferralEarnings` (REFERRAL_EARNINGS-only) path this replaced. Optimistic local entries (`creditEarnings`, `spendBalance`, a card `applyRemoteCards` has just approved) show immediately and are reconciled to the ledger on the next refresh.

## Sign-in and create account

Both Flutter apps (`lib/` and `shield agent_invester/`) open the login screen on **Sign in** only — one mobile-number field, no tabs and no "Create an account" link. **Get OTP** first asks `app.users` whether the number has a live account (`AuthService.hasAccount`):

- **Has an account** — the code is sent straight away and no name is asked.
- **No account** — no code yet. The screen says *"You're a new user"*, switches to the **Create your Sahakar 360 account** view with a name field (the number is kept), and the next **Get OTP** sends the code with that name. *Back to sign in* returns to the number-only view.
- **Could not check** (database unreachable) — the code is sent as a sign-in; the check never blocks a real member.

An existing number always keeps the name stored on it. If the number is edited on the create view to one that already has an account, the typed name is ignored and the code step says the saved name is used. This is enforced in three places so a typed name can never rename a member: the screen, `AuthService` (`_nameFor` prefers the stored name from `MemberRepository.nameByPhone`), and `MemberRepository.upsertOnSignIn`, whose `ON CONFLICT` keeps `app.users.name` for a live row. Only a new row, a row with no name, or a reactivated deleted account takes the incoming name; `nameByPhone` ignores deleted accounts so a re-signup does not inherit "Deleted user".

## Important boundary

The `shield agent_invester/` directory is a parallel project tree, not part of the normal root build commands. Treat it as legacy or separately targeted until ownership is clarified.
