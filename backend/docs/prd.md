# Backend Service — Product Requirements

## Problem

SHIELD has three clients (member Flutter app, `shieldweb` admin console,
`shield agent_invester/`) that all read and write the same Neon `app` schema
**directly** — each holding a live database credential, with no server-side
authentication, authorization, rate limiting, or audit trail. This is
documented as a pre-release blocker in `docs/security.md` (repo root), and it
gets strictly more dangerous as the user base grows: at meaningful scale, a
leaked or extracted credential (already embedded in the `shieldweb` JS bundle
and generated into the Flutter app's `neon_secret.dart`) is a full-database
compromise, not a hypothetical.

## Goal

Build a single backend API service that becomes the **only** thing with a
Neon credential. All three clients talk to it over HTTPS instead of to
Postgres directly. It owns authentication, authorization, business-rule
enforcement, rate limiting, and audit logging for the shared `app` schema.

## Non-goals

- Not a rewrite of the `app` schema's domain model. The existing tables
  (users, orders, prescriptions, wallet, agent hierarchy, etc.) remain the
  source of truth; see [erd.md](erd.md) for what this service adds on top.
- Not a redesign of the three client applications' UX or feature set. Client
  behavior should be preservable; only the transport and trust boundary
  changes (see [migration-plan.md](migration-plan.md)).
- Not a microservices split. One backend, internally modular by domain — see
  [trd.md](trd.md) for why a per-frontend service split was rejected.
- Not solving the `shield agent_invester/` product-boundary question (whether
  it stays a separate app or folds into the member app). This service must
  support it as a client for as long as it exists, without presuming the
  outcome.

## Primary actors

| Actor | Client(s) | Current access | Target access |
| --- | --- | --- | --- |
| Member | Root Flutter app | Firebase phone auth + direct Neon (HTTP for writes, socket for reads) | Firebase phone auth → backend-issued session → backend API only |
| Staff / admin / pharmacy / lab operator | `shieldweb` | Static credential list, `localStorage`, direct browser→Neon | Backend-issued session (email+password, server-hashed), backend API only |
| Agent / investor | `shield agent_invester/`, and agent/investor modules in the root app | Same as member, plus agent-specific tables | Same target as member, with role claims for agent/investor scope |
| System (this repo's own tooling) | `backend/db/*` Dart scripts | Direct Neon connection via `.env` | **Unchanged** — schema/migration tooling keeps its direct connection; it is not a client of the new API |

## Success criteria

1. No client ships a Neon connection string, in any build, on any platform.
2. Every mutating operation is attributable to an authenticated identity and
   passes a server-side authorization check before it reaches Postgres.
3. The invariants currently only enforced (inconsistently) in client code —
   single national agent, agent-approval-before-`agent`-row-write, wallet
   ledger integrity, store/branch scoping — are enforced once, in one place,
   for every client.
4. Prescription images and other member-uploaded media are stored in object
   storage, not as base64 in Postgres rows.
5. OTP send, login attempts, and other abuse-sensitive actions are rate
   limited server-side, not just client-side.
6. All three clients can be migrated to the new backend in phases (see
   [migration-plan.md](migration-plan.md)) without a coordinated simultaneous
   release across app stores and the web console.

## Constraints

- Must interoperate with the existing `app` schema without a big-bang
  migration; the schema is live and actively changing (recent commits:
  `bill` split off `order`, new prescription statuses, agent-customer unique
  constraints).
- Must resolve, not inherit, the known drift called out in `docs/erd.md` §5
  and `docs/decision-log.md` (unfolded geo migrations, `admin` role vs.
  `app.admin_role` enum) before the identity/geo modules are considered done.
- Health data (prescriptions, patient records) and financial data (wallet,
  orders, agent commissions) require audit logging and must never be logged
  in plaintext request/response logs.
- Primary user geography is India (Kerala-specific geo hierarchy data);
  deploy in a region close to Neon's `ap-southeast-1`.
- Team is small; the architecture must not require more operational surface
  (services, queues, infra pieces) than the team can realistically run.
