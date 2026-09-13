# Backend Service — Security Design

This is the enforcement design for the risks already named in
`docs/security.md` (repo root). That document describes the problem; this
one is the fix, scoped to the new backend service.

## Threat model summary (inherited)

1. Neon DB URL is bundled into `shieldweb`'s JS and generated into the
   Flutter app's `neon_secret.dart` — extractable by anyone.
2. Admin login credentials are a static list in
   `shieldweb/src/config/admins.ts` — extractable the same way.
3. No server-side authorization boundary exists for any client today.
4. OTP throttling is client-side only (`shared_preferences` counter).

Every item below exists specifically to close one of these.

## Authentication

- **Member/agent/investor:** client authenticates with Firebase phone auth
  (unchanged — this part is legitimate). Client sends the Firebase ID token
  to `POST /v1/member/auth/session`; backend verifies it with the Firebase
  Admin SDK (server-side, using a service-account credential that itself
  never leaves the backend's secret store) and issues its own short-lived
  access token (15 min) + longer-lived refresh token (30 days, rotated on
  use, stored hashed in `backend.refresh_token`).
- **Staff:** `app.admin_user.firebase_uid` already exists in the live schema —
  staff authenticate through Firebase (email/password sign-in) the same way
  members authenticate through Firebase (phone), and the backend verifies
  their token through the identical Firebase Admin path. No password hash is
  stored in Postgres at all; Firebase owns credential security for both
  client types. Staff accounts must be created in Firebase Auth once, out of
  band (Firebase console or Admin SDK `createUser`), before this works for
  them — see backend/docs/migration-plan.md Phase 1. First successful login
  links `firebase_uid` by matching `email`. Login issues a backend session
  (httpOnly, `SameSite=Strict`, `Secure` cookie) instead of the current
  `localStorage` id. Consider TOTP as a second factor for `SUPERADMIN`
  specifically, given the blast radius of that role.
- Access tokens are short-lived by design so a leaked token has a small
  exploitation window; refresh tokens are the thing that gets revoked on
  logout/compromise (`backend.auth_session.revoked_at`).

## Authorization

- Every route declares its required role(s) and, where applicable, its
  required scope (own-resource-only, or branch/store match) via a NestJS
  guard — this is the server-side counterpart to
  `shieldweb/src/config/permissions.ts`, which today is client-side only and
  therefore not actually enforcing anything against a party with the raw DB
  credential.
- Resource-level checks (e.g. "this order belongs to this store") happen in
  the guard or the service layer before any query runs with write intent —
  never rely on a `WHERE` clause alone to be the only authorization check.
- Role vocabulary is reconciled once (see [erd.md](erd.md) §1) rather than
  each module inventing its own mapping between the console's `admin` role
  and the schema's `app.admin_role` enum.

## Secrets management

- No secret (`DATABASE_URL`, Firebase service-account JSON, JWT signing
  keys, object-storage keys) is ever committed, logged, or included in a
  response body.
- Secrets live in the hosting platform's secret store (Fly.io secrets /
  Render env groups), injected as environment variables at runtime.
- Rotate the Neon credential as the final step of
  [migration-plan.md](migration-plan.md) — once no client holds it anymore,
  issue a new one for the backend service and revoke the old one.
- `.env.example` in the service root lists variable names only, never
  values — same convention the repo root already follows.

## Rate limiting & abuse controls

- Redis-backed (`@nestjs/throttler`), applied specifically to:
  - OTP-adjacent endpoints (member auth session exchange) — per phone
    number and per IP.
  - Staff login — per account and per IP, with exponential backoff /
    temporary lockout after repeated failures.
  - Financial mutation endpoints (wallet redeem, agent withdrawal/transfer)
    — lower ceilings, logged on trip.
- A global default limit applies to every route as a floor, so no endpoint
  is accidentally unlimited.

## Audit logging

- Every mutating staff action, and every mutating action on prescription or
  wallet/financial tables regardless of actor, writes a
  `backend.audit_log` row in the same transaction (see [erd.md](erd.md) §3).
- Audit entries never include full prescription image data or raw payment
  details — reference IDs only.
- Audit log is append-only at the application layer (no update/delete
  endpoint exists for it).

## Data protection

- TLS everywhere (client↔backend, backend↔Postgres via Neon's enforced
  `sslmode=require`, backend↔Redis, backend↔object storage).
- Prescription images and any member-uploaded medical document: stored in
  object storage, served only via short-lived signed URLs (a few minutes'
  validity), never a permanently public bucket URL.
- Structured logs exclude request/response bodies for
  auth/prescription/wallet routes entirely — log identifiers and outcomes,
  not payloads.
- PII minimization: dashboards and admin list views return only the fields
  the specific role needs, not full row dumps.

## Dependency & build hygiene

- `npm audit` / `pnpm audit` (or equivalent) in CI; block merge on
  high/critical findings without an explicit, reviewed exception.
- Pin dependency versions; review and bump deliberately, matching the
  discipline `docs/tech-stack.md` (repo root) already asks of the Flutter
  and admin-console dependency sets.

## Incident response note

If a Neon credential or a signing secret is ever suspected leaked (source,
logs, screenshot, shared environment): rotate it immediately, invalidate all
active sessions (`backend.auth_session`), and treat it as the same class of
event `docs/security.md` (repo root) already calls out as a required
remediation step — this is not new policy, it's this service actually being
able to execute that policy, which the current architecture cannot.
