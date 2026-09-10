# SHIELD Entity Relationship Document

**Status:** Logical ERD derived from `backend/db/app_schema.sql` and `backend/db/APP_SCHEMA.md`. The SQL DDL remains authoritative.

## 1. Schema boundary

- `app`: customer/member data used by Flutter and the operations console.
- `public`: separate Prisma-managed system; do not infer app ownership from its tables.

## 2. Logical relationship map

```mermaid
erDiagram
  USERS ||--o{ MEMBER_ADDRESS : has
  USERS ||--o{ PATIENT : owns
  USERS ||--o{ CART : owns
  CART ||--o{ CART_LINE : contains
  USERS ||--o{ ORDER : places
  SHIELD_STORE ||--o{ ORDER : fulfils
  ORDER ||--o{ ORDER_LINE : contains
  ORDER ||--o{ ORDER_TRACK_STEP : tracks
  USERS ||--o{ PRESCRIPTION : submits
  PATIENT ||--o{ PRESCRIPTION : for
  PRESCRIPTION ||--o{ PRESCRIPTION_MEDICINE : reviewed_as
  USERS ||--o{ WALLET : owns
  WALLET ||--o{ WALLET_CARD : loads
  WALLET ||--o{ WALLET_ENTRY : records
  USERS ||--o{ REFERRAL : invites
  LAB_PACKAGE ||--o{ LAB_BOOKING : booked_as
  USERS ||--o{ LAB_BOOKING : submits
  LAB_BOOKING ||--o{ LAB_BOOKING_PATIENT : includes
  USERS ||--o{ APPOINTMENT : books
  CLINIC ||--o{ APPOINTMENT : hosts
  DIETITIAN ||--o{ APPOINTMENT : serves
  AGENT ||--o{ AGENT : parent_of
  USERS ||--o| AGENT : may_be
  USERS ||--o| INVESTOR : may_be
```

## 3. Entity groups

| Group | Entities | Purpose |
| --- | --- | --- |
| Identity | `users`, `member_address`, `patient`, `device_push_token`, `notification` | Member identity, dependants, contact, notifications |
| Storefront | `shield_store`, categories, `product`, details, FAQs, banners, promos, articles, reviews | Product and editorial discovery |
| Commerce | `cart`, `cart_line`, `order`, `order_line`, tracking, receipt, payment method | Purchase lifecycle |
| Prescription | `prescription`, `prescription_medicine`, `prescription_order`, `approval`, `approval_item` | Prescription review and fulfilment |
| Wallet | `wallet`, `wallet_card`, `wallet_entry`, membership tiers and loads | Privilege plan accounting |
| Rewards | `reward_point_transaction`, `referral`, `referral_level` | Points and referral progression |
| Care | `lab_package`, `lab_profile`, `lab_booking`, booking patients, `clinic`, `clinic_doctor`, `dietitian`, `appointment` | Labs and appointments |
| Partners | `agent`, agent customer/plan/withdrawal/transfer, `investor`, investor plan requests | Agent and investor programmes |
| Operations | `admin_user` | Staff identity/role model intended by schema |

## 4. Integrity rules

- `users.phone` is the member identity key; `firebase_uid` links Firebase identity.
- `users.home_store_id` assigns a default branch.
- Pharmacy operations require a store scope; server-side enforcement is still required.
- `agent.parent_id` is self-referencing and supports the configured hierarchy.
- Wallet money and ledger records must not be silently overwritten by UI actions.
- Soft-delete columns must be respected for users, addresses, patients, and prescriptions.

## 5. Known ERD drift

- Migration `0009_customer_review_videos.sql` creates `app.customer_review_video`, while the rebuilt app DDL snapshot does not include it.
- The console source has an `admin` role, while the schema enum currently lists `SUPERADMIN`, `PHARMACY`, `LAB`, and `APPOINTMENTS`.
- These mismatches require an ADR and migration decision before production authorization is implemented.
