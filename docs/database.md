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

**Geo hierarchy and agent approval queue (migrations `0014`–`0017`, applied to the live database, not yet folded into `app_schema.sql`):**

- `region → state → district → assembly → lsgd → ward` — one table per administrative tier (UUIDv7 keys), replacing the earlier `agent_geo_node` slot table. No seed rows ship with the migration; the real Kerala data is loaded separately by `dart run backend/db/seed_kerala_geo.dart` from the Suvida LSG source spreadsheet (not committed).
- `agent.area_id` — the real slot id (into whichever geo table `agent.level` implies) behind the free-text `agent.area` display name. Deliberately not a DB-level FK (polymorphic by level); see the comment in `0017_agent_area_id.sql`.
- `agent_request` — an app-submitted recruitment (KYC + requested level/parent/area, phone already OTP-verified) awaiting an admin's review in the web console. Registering a lower-tier agent from the app or `shield agent_invester/` never writes `agent` directly; approving a request inserts the real row and links back via `agent_request.agent_id`.

- `lab_booking` (+ `note`, `report_uploaded_at`), `lab_booking_patient`, `lab_booking_report` — a member's lab bookings. `lab_booking_report` (migration `0052_lab_booking_details_report.sql`) holds the lab's report one row per page as a resized JPEG data URI, read only by the owning member and staff.
- `lab_test`, `lab_test_group_item`, `lab_test_special_rate` — the laboratory's own test master (single tests, group tests and packages, with the tests inside a group and per-referring-lab rates), edited on the console's Lab Tests → Test Master tab. Separate from `lab_package` / `lab_profile`, which are what members book. Migrations `0046_lab_test_master.sql` (tables), `0048_lab_test_rate_list_columns.sql` (`scheduled_days`, `reporting_time`, `lab_rate`), `0049_seed_lab_test_rate_list.sql` (the 525-test reference-lab rate list) and `0050_lab_test_source.sql` (`source`: `ADMIN` = created in the console, `RATE_LIST` = the imported list).
- `lab_category` (migration `0055_lab_categories.sql`, written and verified but NOT yet applied to the live database) — "Explore by health concern": a name, an uploaded `image` (a data URI, same shape as `product_category.image`), sort and active flag. `lab_test.category_id` and `lab_package.category_id` both reference it, `ON DELETE SET NULL` on either. `lab_package_test_item` (package_id, test_id, sort; test `ON DELETE RESTRICT`) is the same migration's other addition — the console's package builder (Lab Tests → Member packages → "+ New package") writes it alongside `lab_package`/`lab_profile`, so a console-built package keeps a real link back to the `lab_test` rows it was assembled from, not just the free-text `lab_profile` rows the app renders.

**Referral flow triggers (migration `0052_referral_flow_triggers.sql`, applied to the live database):** `users_assign_referral_code` (BEFORE INSERT on `app.users`) gives every new member a unique `SAHAKAR-####` code, and the migration backfills members that had none. `order_advance_referral` (AFTER INSERT OR UPDATE OF `payment_status` on `app."order"`, when the order is `PAID`) moves the buyer's own `REGISTERED` referral to `TRANSACTED` and calls `app.award_referral_level_points` for the inviter — a trigger because orders are marked paid from several places (the API's wallet checkout, and the admin console writing straight to Neon), and each must count. The migration also backfills referrals whose invitee already had a paid order. **Referral commission auto-credit (migration `0054_referral_commission_autocredit.sql`, written and verified but NOT yet applied to the live database — it needs `0053_company_reserve_on_activation.sql` applied first, because it rewrites `app.approve_wallet_card_activation` on top of that version):** `app.pay_referral_commission(card, referrer)` credits the referrer's wallet 2% of one approved plan (a `REFERRAL_EARNINGS` `wallet_entry` plus the balance), moves the referral to `PLAN_ACTIVATED` and pays level points; one payment per card, guarded by the ledger line and an advisory lock. Triggers `wallet_card_pay_referral` (approval by any path) and `referral_pay_earlier_plans` (a referral recorded after the plan was bought) call it, and the migration ends with a catch-up over every already-approved card of a referred member, so applying it credits commission that was missed (idempotent). `approve_wallet_card_activation` now delegates its referral step to the same function.

The trigger is not in `app_schema.sql` yet; the pg-mem test database has no plpgsql, so the API repeats the same step explicitly in `order.service.ts`.

`backend/db/app_schema.sql` already has `agent_request` (folded in separately), but does **not** yet define the six geo tables or `agent.area_id` — see [ERD known drift](erd.md#5-known-erd-drift) before running a schema recreation.

**Wallet/cash checkout, delivery method, delivery-boy role, priced prescription bills (migration `0031_wallet_cash_delivery.sql`, folded into `app_schema.sql`, NOT yet applied to the live database):**

- `app.payment_method` now offers `wallet` and `cash` as the live checkout methods; `bank-transfer` is kept (existing orders/receipts still reference it) but marked `is_live = false` and no longer offered at order-time checkout. The Health Pass / privilege-plan purchase screen, which is how the wallet is funded in the first place, is unaffected — it does not read `payment_method.is_live`.
- `app."order"` gains `fulfillment_type` (`HOME_DELIVERY` / `STORE_PICKUP`), `payment_status` (`PENDING` / `PAID`), `delivery_boy_id` (→ `app.admin_user`, a `DELIVERY`-role staff account), and `paid_at`.
- `app.bill` gains `amount`, `status`, `paid_at` — it is no longer just an invoice *image*; a new `app.bill_line` table (mirroring `app.order_line`) carries the priced breakdown, letting a prescription order (priced only after the pharmacist's intake review, unlike a standard order which is priced at cart time) get a real, payable invoice.
- `app.admin_role` gains `DELIVERY` — a delivery boy's own console login, store-scoped the same way `PHARMACY` is.
- `app.wallet_entry.order_id` (already present, previously unused) starts getting populated: paying an order from the wallet posts a `SPEND` entry referencing that order and debits `app.wallet.balance` directly, alongside the existing monthly reward-release counter, which SPEND does not touch.

**Order review and explicit bill conversion (migration `0044_order_review_and_bill_conversion.sql`, folded into `app_schema.sql`, applied to the live database):**

- `app.order_line` gains `stock_status` (`app.order_line_status`: `AVAILABLE` / `OUT_OF_STOCK` / `NOT_POSSIBLE` / `CUSTOMER_NOT_NEEDED`, default `AVAILABLE`) — a counter-only note set from the console's Orders review modal, never read by the member's app.
- `app."order"` gains `reviewed_at` (the review's "Submit") and `converted_to_bill_at` ("Convert to bill"); the console's Bills page lists only orders where the latter is set. The migration backfills both from `app.bill.sent_at` for orders that already have a bill, and is additive and idempotent. The `backend/api` Drizzle schema (`app-commerce.ts`) does not declare these columns yet; nothing there reads them.

**Store-contact stamp (migration `0045_order_store_contacted_at.sql`, folded into `app_schema.sql`, applied to the live database):** `app."order".store_contacted_at` is set the first time staff use the console's Call / WhatsApp button for that order's member; it is the "Store contact" stage on the member's Track order screen. Additive and idempotent, no backfill.

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
