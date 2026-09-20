# Admin Console

`shieldweb/` is a React 18 + TypeScript + Vite + Tailwind operations console. Its entry point is `shieldweb/src/main.tsx`; routes are defined in `shieldweb/src/App.tsx`.

## Routes

The current console includes login, dashboard, stores, products, orders, prescriptions, activations, lab orders, lab tests, appointments, users, user details, admins, agent approvals, deliveries, and no-access views. Parameterized routes include activation, user/member detail, and agent approval detail pages.

### Deliveries

`DeliveriesPage` (`/deliveries`) is the `DELIVERY` role's own portal — "available to deliver" (unclaimed cash orders at their branch) and "my deliveries" (claimed, with "mark cash collected" and status-advance actions) — plus a simpler store-scoped assignment view for admin/superadmin/pharmacy to hand a cash order to a specific delivery boy. Backed by `src/api/deliveries.ts`, which is deliberately still direct-to-Neon like the rest of the console's data screens (see [Current authentication implementation](#current-authentication-implementation) below) rather than the unused `backend/api` `StaffCommerceController`.

### Orders → Bills

A member order is reviewed on **Orders** first and only reaches **Bills** when an admin converts it. `OrderReviewModal` (`src/components/orders/OrderReviewModal.tsx`) follows the same two steps as the prescription review:

1. **Items** — set each line's stock status (Stock available, Out of stock, Not possible, Customer not needed); "Process ✓" groups the lines by status. These statuses are counter-only and never shown in the member's app. "Next: Details →" moves on.
2. **Details** — edit the member's name and phone (with call and WhatsApp buttons beside the phone, same as prescriptions), the branch, and, for a pending cash order, the delivery boy. **Submit** saves the statuses and details (`saveOrderReview`), then the button becomes **Convert to bill →**, which stamps the order (`markOrderConvertedToBill`) and opens that order's bill on the Bills page.

`BillsPage` lists only orders where `app."order".converted_to_bill_at` is set, so a freshly received order never shows there. Pricing, sending the invoice and the OTP-gated payment collection happen from Bills (see [Bill collection OTP](#bill-collection-otp)). A new bill starts with the "Stock available" lines only; other lines can be added by hand. The prescription review modal's "Convert to bill →" stamps its linked order the same way. Orders no longer have their own "Manage bill" or "Remove bill" actions; those live on Bills.

The **Call** and **WhatsApp** buttons beside the phone on the Details step (on Orders, and on a prescription's Details step for its linked order) also record the first time staff contacted the member (`markOrderStoreContacted` → `app."order".store_contacted_at`, migration `0045_order_store_contacted_at.sql`). That is what moves the order to **Store contact** in the member's app (see [Order tracking](architecture.md#order-tracking)); clicking again never changes the date, and a cancelled order is not stamped.

This depends on migration `backend/db/migrations/0044_order_review_and_bill_conversion.sql` (new `app.order_line.stock_status`, `app."order".reviewed_at` and `converted_to_bill_at`). It backfills any order that already has a bill as converted, so existing bills stay visible. Until the migration is applied, the Orders and Bills pages will fail to load their queries.

### Agent approval queue

`AgentApprovalsPage` lists every `app.agent_request` still `PENDING` (`src/api/agents.ts listPendingAgents`); `AgentApprovalDetailPage` confirms the level/parent/area and calls `approveAgent` (inserts the real `app.agent` row, links `agent_request.agent_id`, marks the request `APPROVED`) or `rejectAgent` (marks `REJECTED` with a reason, no `agent` row — the app's team tree unlocks the slot). These requests come from the app's own OTP-verified registration flow (`shield/` and `shield agent_invester/`), which never writes `app.agent` directly.

A user can also be made an agent directly, bypassing the request queue: `UserDetailPage`'s "Convert to agent" (`convertToAgent` in `src/api/users.ts`) creates the `app.agent` row on the spot. Every level below national must pick a real named slot — a cascading region → state → district → assembly → lsgd → ward picker (`src/api/geo.ts`, reading `app.region`/`state`/`district`/`assembly`/`lsgd`/`ward`) sized to however many tiers that level needs — so the new agent gets a real `area_id` and locks into a slot in the team tree instead of floating with no area. A slot already held by an approved agent is refused, same as the request-approval path.

## Roles

Permission definitions and landing paths live in `shieldweb/src/config/permissions.ts`. Current roles are `superadmin`, `admin`, `pharmacy`, `lab`, `appointments`, and `delivery` (migration `0031_wallet_cash_delivery.sql`, adding `app.admin_role.DELIVERY`); pharmacy and delivery access are both scoped by `storeCode`.

Creating a staff account (any role) is done from `AdminsPage`'s "Add staff account" form (`POST /v1/staff/admins`, `SUPERADMIN` only) — this was previously backend-only, no console UI.

## Current authentication implementation

The code currently authenticates against the credential list in `shieldweb/src/config/admins.ts` and persists only the login id in browser `localStorage` via `AuthContext`. It does not currently use Firebase Email/Password or resolve admin identity from `app.admin_user`, despite older README text saying otherwise. Do not copy or publish the credentials from that source file.

This must be replaced with a server-side authentication and authorization boundary before public or high-trust deployment. See [Security](security.md).

## Data access

Each `shieldweb/src/api/*.ts` module is a thin query layer over Neon. Pages call API modules rather than embedding SQL. The browser bundle currently receives the database URL, so this console should be treated as internal-only until queries move behind a server API.

## Local commands

### Bill collection OTP

The Bills and Orders invoice modal sends member SMS codes through Firebase
Phone Authentication in project `shield-zabnix`, separately from staff login.
The exact admin website hostname must be registered under Firebase Console →
Authentication → Settings → Authorized domains. Each production, custom, or
preview hostname used for collection must be registered individually. A
`Hostname match not found (auth/captcha-check-failed)` response rejects the
website before an SMS is sent; changing frontend code or Android fingerprints
does not authorize a missing web hostname.

After adding the hostname, reload the admin page and send a new code. The modal
accepts six-digit SMS codes, resets the verification when resending, and cleans
up reCAPTCHA after each send attempt and when closing. Local Indian numbers and
numbers already prefixed with `+91` are normalized to one recipient format.
Wallet collection is invoked by the UI only after Firebase confirms the code;
an unsuccessful collection after verification requires a fresh code. This is
still a client-side gate over the existing direct database API, not server-side
OTP enforcement; the existing security limitations above remain.

Run `npm run test:otp` from `shieldweb/` with Node 22.18+ for the OTP regression
tests, plus the typecheck and build commands below. A real SMS and successful
bill settlement still need end-to-end verification on the authorized hostname.

```powershell
Set-Location shieldweb
npm install
npm run typecheck
npm run build
npm run dev
```

Vite normally serves at `http://localhost:5173`. Vercel is configured to build `dist` and rewrite routes to `index.html`; see [Deployment](deployment.md).
