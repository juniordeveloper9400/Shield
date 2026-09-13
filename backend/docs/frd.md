# Backend Service — Functional Requirements

Organized by domain module. Each module lists: the `app` schema tables it
owns or reads, representative endpoints (full catalogue in
[api-spec.md](api-spec.md)), and the invariant it must enforce server-side
that is currently missing or only enforced client-side.

## 1. Identity & Auth

**Tables:** `users`, `member_address`, `patient`, `device_push_token`,
`notification`, `admin_user`, plus new `auth_session` / `refresh_token`
(see [erd.md](erd.md)).

- Exchange a verified Firebase ID token for a backend session (member/agent).
- Email + password login for staff, returning a backend session (admin).
- Session refresh and revocation (logout, "log out all devices").
- CRUD for member addresses and patients (dependants), scoped to the owning
  user.
- Register/refresh device push tokens.

**Must enforce:**
- A member session can only read/write rows where `users.id` matches the
  authenticated identity, or an explicitly authorized relationship (e.g. an
  agent reading their own `agent_customer` links).
- Staff sessions carry a role (`SUPERADMIN`, `PHARMACY`, `LAB`,
  `APPOINTMENTS`, …) and, where applicable, a branch/store scope; every
  staff-facing endpoint checks both. Resolve the `admin` role vs.
  `app.admin_role` enum mismatch (`docs/erd.md` §5) as part of this module,
  not after.
- OTP request rate limiting is enforced server-side per phone number and per
  IP (today it is a client-side `shared_preferences` counter only).

## 2. Catalogue

**Tables:** `shield_store`, `product_category`, `product_subcategory`,
`product`, `product_detail`, `product_faq`, `home_banner`, `promo`,
`customer_review`, `health_article`, `health_article_section`.

- Public/member-facing read endpoints: stores (with geo lookup for "nearest
  to me"), categories, subcategories, products, product detail/FAQ, banners,
  promos, reviews, health articles.
- Admin write endpoints: manage products, categories, banners, promos.

**Must enforce:**
- These are the highest-read-volume endpoints in the system; must be
  cache-backed (Redis) with explicit invalidation on admin writes, not
  queried against Postgres on every request.
- Review/media writes are scoped to the authenticated member who owns them.

## 3. Commerce (Cart, Checkout, Orders, Bills)

**Tables:** `cart`, `cart_line`, `order`, `order_line`, `order_track_step`,
`order_receipt`, `bill`, `payment_method`.

- Cart CRUD scoped to the member.
- Checkout: validate cart, create `order` + `order_line`, attach payment
  method, return order tracking state.
- Order tracking read; staff-side order status transitions.
- Bill generation/read (per the recent `bill` split off `order` — see
  `docs/decision-log.md` and recent commit history).

**Must enforce:**
- Order status transitions follow a defined state machine (no skipping from
  `PLACED` to `DELIVERED`, no re-opening a `CANCELLED` order) — this exists
  informally in client logic today and must be centralized.
- Store/branch scoping: a pharmacy staff session can only see and mutate
  orders belonging to their assigned `shield_store`.
- Order/bill totals are computed and re-validated server-side, never trusted
  from client-submitted amounts.

## 4. Prescription

**Tables:** `prescription`, `prescription_medicine`, `prescription_order`,
`approval`, `approval_item`.

- Member uploads a prescription image; backend stores it in object storage
  (not as a DB blob) and creates the `prescription` row with a reference URL.
- Pharmacist/staff review: set `prescription_medicine` status (including the
  pharmacist-only stock status and the `ORDERED` status added recently),
  route timing, image rotation metadata.
- Approval workflow: `approval` / `approval_item` read/write.

**Must enforce:**
- Prescription images are served only via short-lived signed URLs, never
  public object-storage URLs — this is health data.
- Status transitions on `prescription_medicine` are restricted to the roles
  the current schema comments describe (pharmacist-only stock status must
  not be settable by a member-facing endpoint).
- Full audit trail (who changed what status, when) — see
  [security.md](security.md).

## 5. Wallet & Rewards

**Tables:** `wallet`, `wallet_card`, `wallet_entry`, `membership_tier`,
`membership_tier_load`, `reward_point_transaction`, `referral`,
`referral_level`.

- Wallet balance read; wallet card load; ledger (`wallet_entry`) read.
- Reward point accrual/redemption, including the minimum-to-redeem rule
  (recent commit: "a minimum to redeem points to the wallet").
- Referral creation and level progression read.

**Must enforce:**
- Every balance change is an appended `wallet_entry` / ledger row, never a
  direct balance overwrite — money math is the single most consequential
  place to get server-side enforcement right.
- Redemption/transfer endpoints are idempotent (require an
  `Idempotency-Key` header) so a retried request cannot double-credit or
  double-debit.

## 6. Care Services (Labs, Clinics, Appointments, Dietitian)

**Tables:** `lab_package`, `lab_profile`, `lab_booking`,
`lab_booking_patient`, `clinic`, `clinic_doctor`, `dietitian`, `appointment`.

- Browse lab packages/profiles, clinics, doctors, dietitians.
- Book a lab test (with one or more patients) or an appointment.
- Staff-side booking/appointment management.

**Must enforce:**
- Booking a lab test or appointment for a `patient` requires that patient to
  belong to the authenticated member (or an agent acting on a linked
  customer's behalf, where that relationship is explicit).

## 7. Partners (Agent & Investor)

**Tables:** `agent`, `agent_request`, `agent_customer`,
`agent_customer_plan`, `agent_withdrawal`, `agent_wallet_transfer`,
`investor`, `investor_plan_change_request`.

- Agent recruitment: an app-submitted registration creates `agent_request`
  (status `PENDING`), never writes `agent` directly.
- Admin approval/rejection of `agent_request`; approval inserts the real
  `agent` row and links `agent_request.agent_id` back.
- Agent team-tree read (self + descendants via `agent.parent_id`).
- Agent-customer linking, withdrawal requests, wallet transfers.
- Investor plan and plan-change-request flows.

**Must enforce:**
- **Single national agent invariant.** The schema's `region.national_agent_id`
  plus `agent.level = NATIONAL` must be constrained to exactly one row,
  enforced at the API layer (and ideally a DB constraint) — the live
  database currently has two, per `docs/decision-log.md`. This module must
  not repeat the bug that exists today in `AgentRepository.ensureNationalRow`.
- Every agent below national occupies a real geo slot
  (`agent.area_id` resolved through the region→ward hierarchy); the API must
  reject a lower-tier agent creation/approval that lacks a valid slot for its
  level, rather than allowing the legacy free-text-area path to continue.
- `agent_request` approval is the only path that writes `agent`; there is no
  endpoint that lets a client create an `agent` row directly.
- Withdrawal and wallet-transfer endpoints are idempotent and ledger-backed,
  same as §5.

## 8. Geography

**Tables:** `region`, `state`, `district`, `assembly`, `lsgd`, `ward`.

- Read-only hierarchy browse/lookup, used by the store map view and the
  agent area-slot picker.

**Must enforce:**
- This data is close to static (seeded from the Suvida LSG source, not
  user-writable) — cache aggressively, invalidate only on the rare admin
  reseed.
- Resolve the schema drift first: these six tables and `agent.area_id` exist
  in the live database via migrations `0014`–`0017` but are not yet folded
  into `backend/db/app_schema.sql`. This module's data-access layer must be
  built against the **live** schema, and the fold-in should happen alongside
  it (see [migration-plan.md](migration-plan.md) Phase 0).

## 9. Admin / Operations

**Tables:** `admin_user`, plus role/permission enforcement across every
module above.

- Staff account management (create/deactivate staff, assign role + branch).
- Dashboards: aggregate reads across orders, prescriptions, agents,
  activations — these are the heaviest ad-hoc queries in the system and
  should be isolated (read replica or a dedicated reporting path) so they
  don't compete with member-facing transactional traffic at scale.

**Must enforce:**
- Role and branch/store scoping middleware applies uniformly to every
  `/admin/*` route — this is the server-side version of
  `shieldweb/src/config/permissions.ts`, which today only runs in the
  browser.
