# Backend Service — Client Migration Plan

Cutover happens in phases. No client's direct Neon credential is revoked
until that client's phase is complete and verified — this avoids a
coordinated simultaneous release across the Play Store, an APK-distributed
legacy app, and the web console, which isn't realistic to pull off safely in
one step.

## Phase 0 — Foundation (no client-visible change)

- Fold migrations `0014`-`0017` into `backend/db/app_schema.sql`; resolve the
  `admin` role vs. `app.admin_role` drift (see [erd.md](erd.md) §1).
- Stand up the backend service (`backend/api/`) per
  [project-structure.md](project-structure.md), connected read-only to a
  Neon branch, implementing the catalogue/geo read endpoints first (lowest
  risk, highest cache value).
- No client is repointed yet.

**Exit criteria:** backend deployed, health checks green, read endpoints
verified against a Neon branch with production-shaped data.

## Phase 1 — Admin console (`shieldweb`)

Highest-risk item first, deliberately: this is the client with static,
source-visible credentials today.

- Implement staff auth (`/v1/staff/auth/*`) and every `/v1/staff/*` route
  the console currently needs, matching `shieldweb/src/config/permissions.ts`
  role/branch rules server-side.
- Update `shieldweb` to call the backend instead of
  `@neondatabase/serverless` directly; replace the `admins.ts` static list
  and `localStorage` session with the backend-issued cookie session.
- Deploy to a staging environment; run the manual smoke checks already
  listed in `docs/testing.md` (repo root): login/logout, role landing pages,
  protected routes, branch scoping, empty states, direct route refresh.

**Exit criteria:** `shieldweb` in production talks only to the backend;
`admins.ts` and the bundled Neon URL are removed from its build. The Neon
credential is **not yet rotated** — the Flutter apps still hold it.

## Phase 2 — Root Flutter app, write paths first

- Implement `/v1/member/*` write endpoints (checkout, prescription upload,
  wallet redemption, agent requests) — these are the `NeonHttp` paths today.
- Repoint the Flutter app's write operations to the backend over HTTPS,
  behind a feature flag if the release process supports one, so a rollback
  doesn't require an app-store re-release.
- Keep native `NeonDatabase` (socket) reads pointed at Neon directly during
  this phase — do not migrate both paths simultaneously.

**Exit criteria:** member sign-in, registration, checkout, prescription
upload, and wallet/agent writes all flow through the backend in production
for a full release cycle with no regression.

## Phase 3 — Root Flutter app, remaining reads

- Implement remaining `/v1/member/*` and `/v1/public/*` read endpoints.
- Repoint `NeonDatabase` call sites to the backend; remove the `postgres`
  package dependency and `lib/data/neon/neon_database.dart`'s direct socket
  path from the shipped app once verified.
- `tool/gen_neon_secret.dart` and `neon_secret.dart` are no longer needed by
  the shipped app after this phase — they remain only for `backend/db/`
  tooling's own use, if still needed there, or are retired entirely if that
  tooling is later given its own separate config path.

**Exit criteria:** the Flutter app binary contains no Neon connection
string in any build variant.

## Phase 4 — `shield agent_invester/`

- Same pattern as Phases 2-3, scoped to whatever subset of `/v1/agent/*` and
  `/v1/member/*` this legacy tree actually needs.
- Because its long-term product boundary is an open decision
  (`docs/decision-log.md`), do not invest in migrating features here that
  are likely to be retired if that tree folds into the root app — migrate
  the auth/data-access path, not speculative new functionality.

**Exit criteria:** this tree also holds no Neon credential.

## Phase 5 — Credential rotation and lockdown

Only after Phases 1-4 are all verified complete in production:

- Rotate the Neon database password/connection string.
- Update only the backend service's environment (and `backend/db/`
  tooling's local `.env`, since that tooling keeps its own direct access)
  with the new credential.
- Where Neon's plan supports it, restrict network access to the database to
  the backend's egress IPs / a private link, rather than accepting
  connections from anywhere with the credential.
- Confirm via `dart run tool/neon_ping.dart` (or its equivalent at the time)
  that only the intended tooling can still connect, and that no shipped
  client build can.

**Exit criteria:** the only things holding a live Neon credential are the
backend service and `backend/db/` developer tooling. This is the actual
completion of the goal stated in [prd.md](prd.md).

## Rollback within any phase

Each phase's client change should be revertible independently: keep the
pre-migration code path (direct Neon access) intact and dormant behind a
flag or a held-back release until the corresponding phase's exit criteria
are confirmed in production, not just in staging. Do not delete the old
access path until the phase after it has also shipped cleanly — this gives
one full phase of buffer before the old path is unrecoverable.
