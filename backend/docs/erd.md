# Backend Service — Entity Relationship Model

**Status:** This does not replace `docs/erd.md` (repo root), which remains
authoritative for the `app` schema's domain entities. This document layers
on top of it: what the backend service reads/writes in `app`, plus the new
tables it owns for its own concerns (sessions, audit, idempotency).

## 1. Precondition: resolve existing drift first — RESOLVED

This section described pre-build drift between `backend/db/app_schema.sql`
and the live database. It has since been resolved: `app_schema.sql` is now
machine-generated straight from the live schema
(`dart run backend/db/dump_app_schema.dart --write`), so this category of
drift can no longer accumulate silently. The specific items originally
listed here are all folded in: the geo hierarchy tables and `agent.area_id`,
`app.customer_review_video`(+`_media`), and the `admin_role` vocabulary
(now `SUPERADMIN`, `ADMIN`, `PHARMACY`, `LAB`, `APPOINTMENTS`, `DELIVERY`,
`LAB_TECHNICIAN` — matching `shieldweb`/this service exactly). See
[`backend/db/APP_SCHEMA.md`](../db/APP_SCHEMA.md) for current state and
[`backend/api/SCHEMA.md`](../api/SCHEMA.md) for this service's own module/
route map, which supersedes §2-§3 below as the current-state reference —
the entity groups and new-tables list below are kept for historical context
only and are not re-verified against the live schema the way those two
documents are.

## 2. Existing `app` schema — entity groups this service reads/writes

Unchanged from `docs/erd.md` (repo root); repeated here for reference only:

| Group | Entities |
| --- | --- |
| Identity | `users`, `member_address`, `patient`, `device_push_token`, `notification` |
| Storefront | `shield_store`, categories, `product`, details, FAQs, banners, promos, articles, reviews |
| Commerce | `cart`, `cart_line`, `order`, `order_line`, tracking, receipt, `bill`, payment method |
| Prescription | `prescription`, `prescription_medicine`, `prescription_order`, `approval`, `approval_item` |
| Wallet | `wallet`, `wallet_card`, `wallet_entry`, membership tiers/loads |
| Rewards | `reward_point_transaction`, `referral`, `referral_level` |
| Care | `lab_package`, `lab_profile`, `lab_booking`, booking patients, `clinic`, `clinic_doctor`, `dietitian`, `appointment` |
| Partners | `agent`, `agent_request`, agent customer/plan/withdrawal/transfer, `investor`, investor plan requests |
| Geography | `region`, `state`, `district`, `assembly`, `lsgd`, `ward` |
| Ops | `admin_user` |

The DDL in `backend/db/app_schema.sql` remains authoritative for column-level
detail. This service must not fork or duplicate that definition.

## 3. New tables this service owns

**Status note:** `backend.auth_session`, `refresh_token`, and
`idempotency_key` were built as specified below and are live. `audit_log`
was planned here but was **not** built — there is no `backend.audit_log`
table and no schema file for it. Treat the table and its integrity rule in
§4 as a future addition, not current state.

```mermaid
erDiagram
  USERS ||--o{ AUTH_SESSION : has
  ADMIN_USER ||--o{ AUTH_SESSION : has
  AUTH_SESSION ||--o| REFRESH_TOKEN : rotates
  AUTH_SESSION ||--o{ AUDIT_LOG : attributed_to
  USERS ||--o{ AUDIT_LOG : attributed_to
  ADMIN_USER ||--o{ AUDIT_LOG : attributed_to
  AUTH_SESSION ||--o{ IDEMPOTENCY_KEY : scoped_to
```

| Table | Purpose | Key columns |
| --- | --- | --- |
| `backend.auth_session` | One row per active login (member or staff) | `id`, `subject_type` (`MEMBER`/`STAFF`), `subject_id`, `issued_at`, `expires_at`, `revoked_at`, `user_agent`, `ip` |
| `backend.refresh_token` | Rotatable refresh tokens, one active per session | `id`, `session_id` FK, `token_hash`, `expires_at`, `used_at` |
| `backend.audit_log` | Append-only record of mutating actions on sensitive tables | `id`, `actor_type`, `actor_id`, `action`, `entity_table`, `entity_id`, `before` (jsonb, nullable), `after` (jsonb, nullable), `created_at` |
| `backend.idempotency_key` | Dedupe retried mutating requests (wallet, agent withdrawal/transfer, checkout) | `key` (client-supplied), `session_id`, `endpoint`, `response_snapshot` (jsonb), `created_at`, unique on `(key, endpoint)` |

Deliberately a **separate `backend` schema**, not `app` — this is
service-owned operational state, not member/store domain data, and keeping
it apart avoids ever conflating "backend infra tables" with "domain tables"
in a future `app_schema.sql` recreation.

### Why not reuse `app.admin_user` as the session store directly

`app.admin_user` stays as the staff identity/role record (per
`docs/erd.md`'s stated intent for that table). `backend.auth_session` is the
ephemeral session layer on top of it — same relationship as `app.users` to
Firebase identity today, just applied consistently to both member and staff
login instead of only to members.

## 4. Integrity rules this service must add

- `backend.auth_session.revoked_at` must be checked on every request, not
  just at token-issue time (supports "log out all devices").
- `backend.audit_log` writes happen in the same transaction as the mutation
  they describe — never fire-and-forget after the fact, or a failed audit
  write could silently under-report a real change.
- `backend.idempotency_key` entries expire (e.g. 24h) and are cleaned up by a
  background job, not kept forever.
- All rules from `docs/erd.md` (repo root) §4 continue to apply and are now
  enforced at this service's API boundary instead of only being documented
  intent: `agent.area_id` polymorphic resolution, `agent_request` as the only
  path to a new `agent` row, wallet ledger append-only semantics, soft-delete
  respected for users/addresses/patients/prescriptions.
