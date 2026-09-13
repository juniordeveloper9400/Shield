# Backend Service — Build Playbook

Ordered milestones for building `backend/api/` from these docs. Written for
an AI coding agent to execute sequentially; each milestone names its
definition of done and the docs it must be checked against. Do not skip
ahead — later milestones assume earlier guards/patterns already exist and
should reuse them, not reinvent them per module.

Before milestone 0, read: [README.md](README.md), [prd.md](prd.md),
[trd.md](trd.md), [tech-stack.md](tech-stack.md), and root `AGENTS.md` /
`docs/ai-agent-playbook.md`. Those govern how to work in this repository at
all; this playbook governs what to build, in what order.

## M0 — Scaffold

- Create `backend/api/` per [project-structure.md](project-structure.md).
- NestJS app boots, `/healthz` returns 200, `pnpm test` runs (even with zero
  tests), lint/typecheck/build all pass in CI.
- `drizzle.config.ts` points at a Neon branch (not production); Drizzle
  schema files exist for the *existing* `app` tables (typed mirror only —
  no DDL changes yet) plus the new `backend` schema tables from
  [erd.md](erd.md) §3.

**Done when:** `pnpm dev` serves `/healthz`; CI is green on an empty-feature
scaffold.

## M1 — Identity & Auth

- Implement `/v1/member/auth/*` (Firebase token exchange) and
  `/v1/staff/auth/*` (email+password), per [frd.md](frd.md) §1 and
  [security.md](security.md).
- Implement the shared guards (`common/guards/`): session resolution,
  role check, own-resource check. Every later module depends on these —
  build them generically now, not per-module later.
- Resolve the `admin` role vs. `app.admin_role` drift as part of this
  milestone (touches `backend/db/` migrations — treat as a schema change
  requiring the same confirmation discipline as any other destructive/
  structural DB change).
- Member address and patient CRUD, scoped to owner.

**Done when:** a member can exchange a Firebase token for a session and
fetch their own profile; a staff user can log in and is rejected from a
route requiring a role they don't have; no route is reachable without
passing through a guard.

## M2 — Catalogue (read-heavy, cache-backed)

- Public read endpoints for stores, categories, products, banners, promos,
  reviews, articles, per [frd.md](frd.md) §2.
- Redis caching wired in here first — this is the template every other
  cache-backed module follows.
- Staff write endpoints, role-scoped.

**Done when:** repeated reads hit cache, not Postgres, verified by
instrumentation/logs; cache invalidates correctly on a staff write.

## M3 — Commerce

- Cart, checkout (idempotent), orders, order tracking, bills — per
  [frd.md](frd.md) §3.
- Order status state machine implemented centrally (one place that governs
  legal transitions, not scattered per-endpoint checks).
- Store/branch scoping enforced on every staff-facing order/bill route.

**Done when:** an out-of-order status transition is rejected; totals are
recomputed server-side and a client-submitted total is ignored/verified,
never trusted directly.

## M4 — Prescription

- Upload → object storage (per [security.md](security.md)); prescription,
  prescription_medicine, prescription_order, approval flows per
  [frd.md](frd.md) §4.
- Signed-URL retrieval only, no public image URLs.
- Role-restricted status transitions (pharmacist-only stock status).
- Audit logging wired in here first (extends the pattern to wallet/agent
  modules after).

**Done when:** an uploaded image is retrievable only via a short-lived
signed URL; a status change is blocked for a role that shouldn't be able to
set it; the change appears in `backend.audit_log`.

## M5 — Wallet & Rewards

- Wallet, wallet_card, wallet_entry, membership tiers, reward points,
  referrals — per [frd.md](frd.md) §5.
- Every balance change is an appended ledger row; idempotency-key enforced
  on redeem/load endpoints.

**Done when:** a retried redemption request (same idempotency key) does not
double-credit; balance is always derivable by summing ledger entries, never
stored as a mutable field alone (or if stored denormalized for read speed,
reconciled against the ledger in tests).

## M6 — Care Services

- Labs, clinics, dietitian, appointments — per [frd.md](frd.md) §6.
- Booking-for-patient ownership check reuses the M1 own-resource guard.

**Done when:** booking a lab test for a patient not owned by the
authenticated member (and with no explicit agent-linked relationship) is
rejected.

## M7 — Partners (Agent & Investor) + Geography

- Geo hierarchy read endpoints first (needed by agent slot validation) —
  per [frd.md](frd.md) §8.
- Agent request submission, team-tree read, agent-customer linking,
  withdrawals, wallet transfers — per [frd.md](frd.md) §7.
- Staff-side agent-request approve/reject implementing **both** invariants
  explicitly: single national agent, valid geo slot for level. Write a test
  that specifically tries to create a second national agent and asserts
  rejection — this is the exact bug that exists in production today.

**Done when:** approving a second national-agent request fails; approving a
lower-tier request without a valid `area_id` for its level fails; a normal
approval succeeds and links `agent_request.agent_id` correctly.

## M8 — Admin/Ops hardening

- Staff account management endpoints (`SUPERADMIN`-only).
- Dashboard endpoints served from pre-aggregated/cached data, not live joins
  — per [trd.md](trd.md).
- Full rate-limiting pass across every module (per [security.md](security.md)):
  confirm OTP/login/financial endpoints all have explicit, tighter limits
  than the global default.

**Done when:** a scripted burst of login attempts against one account is
throttled; dashboard endpoints respond without a live cross-table join on
every request.

## M9 — Client cutover

Execute [migration-plan.md](migration-plan.md) Phases 1-4. This is
integration work in the client repos (`shieldweb`, root Flutter app,
`shield agent_invester/`), not further backend feature work — the backend
should be feature-complete for a given client's needs before that client's
phase starts.

**Done when:** each phase's exit criteria in
[migration-plan.md](migration-plan.md) are met in production.

## M10 — Credential rotation & lockdown

Execute [migration-plan.md](migration-plan.md) Phase 5.

**Done when:** no shipped client build contains a Neon credential, verified
by inspecting the actual release artifacts (APK, web bundle), not just the
source tree.

## Acceptance testing note

Every milestone's "done when" line is a test to write, not just a manual
check — unit tests for guards/state machines/idempotency, integration tests
(Supertest + a disposable Neon branch) for the full request path per module.
A milestone is not complete on code existing; it's complete on its stated
failure case being demonstrably rejected and its success case being
demonstrably correct, in an automated test.
