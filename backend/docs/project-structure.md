# Backend Service — Project Structure

Target location: `backend/api/` (new — sits alongside the existing
`backend/db/`, which keeps its current role unchanged). This lets the schema
tooling and the new service coexist under `backend/` without either
shadowing the other.

```
backend/
  db/                         # UNCHANGED — existing schema DDL, migrations, seed tools
  docs/                       # this planning package
  api/                        # NEW — the backend service, scaffolded from these docs
    src/
      main.ts                 # NestJS bootstrap
      app.module.ts
      common/
        guards/                # auth + role/scope guards
        interceptors/          # audit-log interceptor, correlation-id interceptor
        pipes/                 # Zod validation pipe
        filters/               # error envelope exception filter
        decorators/            # @CurrentUser(), @RequireRole(), @Idempotent()
      config/
        env.ts                 # typed env var loader/validator (fails fast on missing secrets)
      db/
        client.ts              # Drizzle client, pooled connection
        schema/                # Drizzle schema files, one per domain group
          app-identity.ts
          app-catalogue.ts
          app-commerce.ts
          app-prescription.ts
          app-wallet.ts
          app-care.ts
          app-partners.ts
          app-geo.ts
          backend-auth.ts       # backend.auth_session, refresh_token
          backend-audit.ts      # backend.audit_log
          backend-idempotency.ts
        migrations/             # drizzle-kit output, reviewed before apply
      modules/
        auth/
          member/                # Firebase token exchange, session issuance
          staff/                 # email+password login
        identity/                # users, addresses, patients, push tokens
        catalogue/
        commerce/                # cart, checkout, orders, bills
        prescription/
        wallet/
        rewards/
        care/                    # labs, clinics, appointments, dietitian
        partners/
          agent/
          investor/
        geo/
        admin/                   # staff account mgmt, dashboards
      jobs/
        queue.ts                 # BullMQ connection + queue registration
        processors/
          notification.processor.ts
          reward-sweep.processor.ts
          agent-approval.processor.ts
      storage/
        object-storage.client.ts # S3-compatible client, signed-URL helpers
      cache/
        redis.client.ts
      audit/
        audit.service.ts         # writes backend.audit_log inside the caller's transaction
    test/
      unit/
      integration/                # Supertest against a disposable Neon branch
    drizzle.config.ts
    .env.example
    Dockerfile
    docker-compose.yml            # local Redis (+ optional local Postgres) for dev
    package.json
    tsconfig.json
    .eslintrc.cjs
    .prettierrc
```

## Conventions

- **One NestJS module per domain folder under `modules/`**, each with its own
  controller(s), service(s), and DTOs — matches the module boundaries already
  established in [frd.md](frd.md) and mirrors the existing `lib/module/*`
  boundary the Flutter app uses, so the mapping between client feature and
  backend module stays legible.
- **Guards live in `common/guards/`, not duplicated per module.** Role and
  scope requirements are declared per-route with decorators
  (`@RequireRole('PHARMACY')`, `@RequireOwnResource()`), resolved by shared
  guard logic.
- **No module reaches into another module's Drizzle schema file directly**
  for writes — cross-module reads are fine (e.g. commerce reading catalogue
  product prices), cross-module writes go through the owning module's
  service so its invariants stay enforced in one place.
- **Every DTO is a Zod schema**, exported once, used for both request
  validation and OpenAPI generation — no separate hand-maintained Swagger
  decorators drifting from the actual validation rules.
- Package manager: pnpm; lockfile committed.
- Formatting/linting: Prettier + ESLint (typescript-eslint), enforced in CI,
  matching the repo's existing `flutter analyze` / `npm run typecheck`
  discipline for the other two apps.

## Local development

```powershell
Set-Location backend/api
pnpm install
cp .env.example .env.local        # fill in a dev Neon branch + local Redis
docker compose up -d              # Redis (and Postgres if not using a Neon branch)
pnpm drizzle-kit generate         # after any schema change
pnpm dev                          # NestJS in watch mode
pnpm test                         # unit
pnpm test:integration             # against a disposable Neon branch
```

## Relationship to existing `backend/db/`

- Schema changes still originate in `backend/db/` (DDL + migrations) — the
  service's Drizzle schema files under `api/src/db/schema/` are a typed
  **read/write mirror** of that DDL, regenerated or hand-updated to match
  whenever `backend/db/app_schema.sql` changes, not an independent source of
  truth.
- `backend/db/apply_app_schema.dart`, `seed_app.dart`, `seed_kerala_geo.dart`,
  `wipe.dart`, etc. are unaffected — they keep using the direct Neon
  connection from `.env`, as documented in `backend/README.md`.
