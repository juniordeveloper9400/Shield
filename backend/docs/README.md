# Sahakar 360 Backend Service — Planning Docs

This folder specifies a **new backend API service** that will sit between all
three Sahakar 360 clients (root Flutter member app, `shieldweb` admin console,
`shield agent_invester/`) and Neon Postgres. It does not exist as code yet —
these are the planning documents, written to be complete enough for an AI
coding agent (or a human vibe-coding fast) to build the service end to end
without further product clarification.

**This does not replace anything under `backend/db/`.** That folder's schema
DDL, migrations, and seed tools remain authoritative for the `app` schema —
the new service is a consumer of that schema, not a replacement for it. Root
`AGENTS.md`, `CLAUDE.md`, and `docs/ai-agent-playbook.md` still govern how any
agent works in this repository; nothing here overrides them.

## Why this exists

Today, every client holds a live Neon credential and queries Postgres
directly — no server-side auth, no enforced authorization, no rate limiting,
no audit trail. See `docs/security.md` (repo root) for the specifics. This
service is the fix: one backend, all three clients as consumers, one place
credentials and business rules live.

## Reading order

1. [prd.md](prd.md) — why this service exists, for whom, what's in/out of scope.
2. [frd.md](frd.md) — what it must do, module by module, with the rules it must enforce.
3. [trd.md](trd.md) — how it's built: architecture, NFRs, deployment.
4. [erd.md](erd.md) — the data model: existing `app` schema plus what this service adds.
5. [tech-stack.md](tech-stack.md) — the concrete language/framework/library choices.
6. [api-spec.md](api-spec.md) — the REST surface, conventions, and per-module endpoint catalogue.
7. [security.md](security.md) — authn/authz design, secrets, abuse controls.
8. [project-structure.md](project-structure.md) — the folder layout to scaffold.
9. [migration-plan.md](migration-plan.md) — how existing clients cut over without a big-bang break.
10. [build-playbook.md](build-playbook.md) — the ordered milestone list an agent should execute against.

## Ground rules for whoever (or whatever) builds this

- The `app` schema in Neon is the existing source of truth for domain data.
  Do not redesign it wholesale. Add tables only where this service needs its
  own state (sessions, audit log, idempotency keys) — see [erd.md](erd.md).
- Known schema drift (unfolded geo migrations, `admin` role vs.
  `app.admin_role` enum mismatch) must be resolved as part of this build, not
  inherited silently. Cross-reference `docs/erd.md` (repo root) §5 and
  `docs/decision-log.md` before writing the identity/geo modules.
- Every module in [frd.md](frd.md) lists the invariant it must enforce
  server-side that is currently only enforced (or not enforced at all)
  client-side. Treat those as required, not optional polish.
- Follow [migration-plan.md](migration-plan.md) — clients cut over in phases;
  direct Neon credentials are not revoked from any client until its phase
  completes and is verified.
