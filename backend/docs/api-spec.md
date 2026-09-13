# Backend Service — API Specification

This is a condensed endpoint catalogue and the conventions every endpoint
follows. The authoritative machine-readable spec is generated from code via
`@nestjs/swagger` once the service exists (`GET /v1/openapi.json`); this
document is what an agent scaffolds *toward*.

## Conventions

- **Base path:** `/v1`. Breaking changes get `/v2`; do not silently change
  response shapes under `/v1`.
- **Auth:**
  - Mobile clients (Flutter member app, `shield agent_invester/`): bearer
    token in `Authorization: Bearer <access_token>`.
  - `shieldweb`: httpOnly session cookie, `SameSite=Strict`, set by the
    login endpoint.
  - Every non-public route requires one of the above; public routes are
    explicitly listed in [frd.md](frd.md) §2 (catalogue browse) and §8
    (geo lookup).
- **Route namespacing by role**, enforced by guard, not just by convention:
  - `/v1/member/*` — member-scoped, requires member session.
  - `/v1/staff/*` — staff-scoped, requires staff session + role/branch check.
  - `/v1/agent/*` — agent/investor-scoped, requires member session with an
    agent/investor role claim.
  - `/v1/public/*` — no auth (catalogue browse, geo lookup, health check).
- **Pagination:** cursor-based (`?cursor=&limit=`), response includes
  `next_cursor: string | null`. Offset pagination is not used anywhere —
  cheaper to get this right once than retrofit it under load.
- **Idempotency:** any endpoint that moves money or creates an
  irreversible state transition (checkout, wallet redemption, agent
  withdrawal/transfer, agent-request approval) requires an
  `Idempotency-Key` header; a repeated key with the same body returns the
  original response instead of repeating the effect.
- **Error envelope:**
  ```json
  {
    "error": {
      "code": "VALIDATION_ERROR | UNAUTHORIZED | FORBIDDEN | NOT_FOUND | CONFLICT | RATE_LIMITED | INTERNAL",
      "message": "human-readable",
      "details": {}
    }
  }
  ```
- **Timestamps:** ISO 8601 UTC everywhere. Money values as integer minor
  units (paise), never floats.

## Endpoint catalogue by module

Full request/response shapes belong in the generated OpenAPI spec once code
exists; this table is the scope, not the schema.

### Auth (`/v1/member/auth`, `/v1/staff/auth`)

| Method & path | Auth | Description |
| --- | --- | --- |
| `POST /v1/member/auth/session` | Firebase ID token in body | Exchange verified Firebase token for backend session |
| `POST /v1/staff/auth/session` | email + password in body | Staff login |
| `POST /v1/{member,staff}/auth/refresh` | refresh token | Rotate access token |
| `DELETE /v1/{member,staff}/auth/session` | session | Logout (current device) |
| `DELETE /v1/{member,staff}/auth/sessions` | session | Logout all devices |

### Catalogue (`/v1/public/catalogue/*`, `/v1/staff/catalogue/*`)

`GET` stores, categories, subcategories, products, product detail/FAQ,
banners, promos, reviews, health articles — public.
`POST`/`PATCH`/`DELETE` on the same resources — staff, role-scoped.

### Commerce (`/v1/member/cart`, `/v1/member/orders`, `/v1/staff/orders`, `/v1/member/bills`)

`GET|POST|PATCH|DELETE /v1/member/cart` — member's own cart.
`POST /v1/member/orders` (checkout, idempotent) — creates order from cart.
`GET /v1/member/orders`, `GET /v1/member/orders/:id` — member's own orders.
`GET /v1/staff/orders`, `PATCH /v1/staff/orders/:id/status` — branch-scoped.
`GET /v1/member/bills/:id`, `GET /v1/staff/bills` — read.

### Prescription (`/v1/member/prescriptions`, `/v1/staff/prescriptions`)

`POST /v1/member/prescriptions` (multipart upload → object storage).
`GET /v1/member/prescriptions`, `GET /v1/member/prescriptions/:id`.
`GET /v1/staff/prescriptions`, `PATCH /v1/staff/prescriptions/:id/medicine/:medicineId/status` (role-restricted per [frd.md](frd.md) §4).
`GET /v1/staff/approvals`, `PATCH /v1/staff/approvals/:id`.

### Wallet & rewards (`/v1/member/wallet`, `/v1/member/rewards`, `/v1/member/referrals`)

`GET /v1/member/wallet`, `GET /v1/member/wallet/entries`.
`POST /v1/member/wallet/cards` (load a card).
`POST /v1/member/rewards/redeem` (idempotent, enforces minimum-to-redeem rule).
`GET /v1/member/referrals`, `POST /v1/member/referrals`.

### Care services (`/v1/public/labs`, `/v1/member/lab-bookings`, `/v1/public/clinics`, `/v1/member/appointments`)

`GET` lab packages/profiles, clinics, doctors, dietitians — public.
`POST /v1/member/lab-bookings`, `GET /v1/member/lab-bookings`.
`POST /v1/member/appointments`, `GET /v1/member/appointments`.
`GET /v1/staff/lab-bookings`, `GET /v1/staff/appointments` — branch-scoped.

### Partners — agent & investor (`/v1/agent/*`, `/v1/staff/agents`)

`POST /v1/agent/requests` — submit recruitment (creates `agent_request`, never `agent`).
`GET /v1/agent/team` — self + descendants tree.
`GET /v1/agent/customers`, `POST /v1/agent/customers` (link).
`POST /v1/agent/withdrawals` (idempotent), `POST /v1/agent/wallet-transfers` (idempotent).
`GET /v1/staff/agent-requests`, `POST /v1/staff/agent-requests/:id/approve`, `POST /v1/staff/agent-requests/:id/reject` — enforces single-national-agent and geo-slot invariants ([frd.md](frd.md) §7).
`GET /v1/investor/*`, `POST /v1/investor/plan-change-requests`.

### Geography (`/v1/public/geo/*`)

`GET /v1/public/geo/regions|states|districts|assemblies|lsgds|wards` —
hierarchy browse, heavily cached.

### Admin/ops (`/v1/staff/admins`, `/v1/staff/dashboard`)

`GET|POST|PATCH /v1/staff/admins` — staff account management, `SUPERADMIN` only.
`GET /v1/staff/dashboard/*` — aggregate reads, served from a
pre-aggregated/cached path per [trd.md](trd.md), not live joins on request.

### System

`GET /healthz` — liveness, no auth.
`GET /readyz` — readiness (DB + Redis check), no auth.
`GET /v1/openapi.json` — generated spec, no auth.
