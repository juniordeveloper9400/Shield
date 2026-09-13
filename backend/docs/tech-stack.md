# Backend Service — Technology Stack

**Status:** Recommendation for a new build. Chosen for the shape of the
problem (CRUD + RBAC + business invariants over shared Postgres data, three
heterogeneous clients, moderate traffic), not for continuity with any
existing code.

## Core

| Concern | Choice | Why |
| --- | --- | --- |
| Language | TypeScript 5.x | Static types for a domain full of role/branch/status invariants; shares schema vocabulary with `shieldweb` |
| Runtime | Node.js 22 LTS | Mature, boring, huge ecosystem for exactly what's missing today (auth, RBAC, validation, audit) |
| Framework | NestJS 10 | Guard/interceptor/DI model maps directly onto "enforce role + branch scoping consistently across many domain modules" — the actual open problem |
| Package manager | pnpm | Fast, disk-efficient, workspace support if the service later splits into packages |

## Data layer

| Concern | Choice | Why |
| --- | --- | --- |
| Database | Neon Postgres (existing `app` schema) | No change — this service becomes the only thing that connects to it |
| Driver | `postgres.js` (or `pg`) against Neon's **pooled** connection string | This is a long-running server process, not an edge function — use a real pooled connection, not the HTTP-only serverless driver `shieldweb` uses today |
| Connection pooling | Neon's built-in pooler (PgBouncer-compatible) in front of a bounded app-side pool | Fixes the current N-raw-connections problem; single pooled path instead of every client opening its own socket |
| ORM / query layer | Drizzle ORM + drizzle-kit | Type-safe, thin over SQL, good migration story, low cold-start overhead if any part ever needs to run at the edge |
| Migrations | drizzle-kit, generated SQL reviewed by hand before apply | Matches the existing repo's discipline of explicit, reviewed migration files under `backend/db/migrations/` |
| Caching | Redis (ioredis client) | Catalogue, product, and geo-hierarchy reads are the highest-volume paths; take them off Postgres |
| Background jobs | BullMQ (Redis-backed) | OTP dispatch, notification fan-out, wallet/reward ledger posting, agent-approval side effects — anything that shouldn't block a request |
| File storage | S3-compatible object storage (Cloudflare R2 or AWS S3) + signed URLs | Prescription images must stop being base64 blobs in `app.prescription.image` — see [erd.md](erd.md) |

## API surface

| Concern | Choice | Why |
| --- | --- | --- |
| Style | REST, versioned at `/v1` | Three clients, only one is TypeScript — REST + generated clients beats GraphQL/tRPC, which mainly reward TS-to-TS |
| Schema/validation | Zod, wired through `nestjs-zod` pipes | Single source of truth for request/response shape, reused for OpenAPI generation |
| Docs/spec | OpenAPI 3 via `@nestjs/swagger`, generated from code | Feeds `openapi-generator` for a Dart client (both Flutter apps) and a TS client (`shieldweb`) |
| Rate limiting | `@nestjs/throttler` backed by Redis | Server-side OTP/login/mutation throttling — today's throttle is a client-side counter, trivially bypassed |

## Auth

| Concern | Choice | Why |
| --- | --- | --- |
| Member auth | Firebase Admin SDK verifies the existing Firebase phone-auth ID token; backend issues its own short-lived access token + refresh token | Keeps Firebase phone auth as-is (it's legitimate); backend becomes the only thing that talks to Postgres with member identity |
| Staff/admin auth | Firebase (email/password sign-in), same Firebase Admin verification path as members; backend issues its own session | `app.admin_user.firebase_uid` already exists in the schema for exactly this — no new password-storage code needed. Staff accounts are bootstrapped in Firebase Auth once, out of band; first login links `firebase_uid` by matching `email`. Replaces the static credential list in `shieldweb/src/config/admins.ts` and the `localStorage` session |
| Authorization | Custom NestJS guards (role + branch/store scope), modeled on `casl` ability rules | Enforces `shieldweb/src/config/permissions.ts`-style rules server-side, where they currently aren't enforced at all |
| Secrets | Environment variables via the platform's secret store (Fly.io secrets / Render env groups), never checked in, never shipped to a client bundle | The one credential-exposure fix this whole project exists for |

## Observability & ops

| Concern | Choice | Why |
| --- | --- | --- |
| Logging | `pino`, structured JSON, request-scoped correlation IDs | Cheap, fast, plays well with any log aggregator |
| Tracing/metrics | OpenTelemetry SDK, exported to whatever APM is chosen later (Grafana Cloud / Honeycomb / Datadog) | Vendor-agnostic from day one |
| Error tracking | Sentry (Node SDK) | Fast to wire up, immediately useful |
| Testing | Jest (unit) + Supertest (HTTP integration) + a disposable Neon branch per CI run | Neon branching gives cheap, isolated integration-test databases without a local Postgres |
| CI | GitHub Actions: lint → typecheck → test → build → migration dry-run | Matches the repo's existing PowerShell validation pattern, automated |
| Containerization | Docker, multi-stage build | Portable across hosts |
| Hosting | Fly.io (primary recommendation) or Render — pick a region close to Neon's `ap-southeast-1` | Both support long-running Node processes + background workers cheaply; avoid a pure serverless-functions host since BullMQ workers need a persistent process |

## Explicitly not chosen (and why)

- **GraphQL / tRPC** — would only benefit `shieldweb`; the two Flutter clients gain nothing and REST + OpenAPI serves all three uniformly.
- **Prisma** over Drizzle — viable alternative, heavier runtime and historically slower cold starts; Drizzle preferred for staying close to SQL, but either is acceptable if the build has stronger Prisma familiarity.
- **Dart backend (Serverpod/Dart Frog)** — "one language everywhere" is tempting given the Flutter clients, but the ecosystem for production auth/RBAC/audit tooling is thin next to Node's; not worth it for a health-adjacent app where getting auth right is the point.
- **Go / Java / .NET** — all legitimate, more operationally "boring" or more enterprise-grade choices; ruled out only because they trade dev velocity for guarantees (raw performance, static-binary ops simplicity, large-org structure) this project doesn't need yet at the traffic and team size in scope.
