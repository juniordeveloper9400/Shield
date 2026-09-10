# SHIELD Documentation

This is the maintained documentation index for the repository. It describes the implementation currently in the workspace; known gaps and risks are called out rather than hidden.

## Application map

- [Member app](apps/member-app/README.md): root Flutter customer/member application.
- [Admin console](apps/admin-console/README.md): `shieldweb` React/Vite operations application.
- [Agent/investor app](apps/agent-investor-app/README.md): `shield agent_invester` Flutter partner-enabled application.
- [Combined system documentation](combined/README.md): cross-app product, architecture, data, security, release, and AI-agent authority.

Each application folder contains its own PRD, FRD, TRD, ERD, tech-stack, and UI/UX documents. The documents below remain the repository-wide combined baseline.

## Product and code

- [Product requirements](prd.md): product goals, actors, scope, outcomes, and risks.
- [Functional requirements](frd.md): testable member and operations-console requirements.
- [Technical requirements](trd.md): topology, runtime contracts, non-functional requirements, and release gates.
- [Entity relationships](erd.md): logical data model and known schema drift.
- [Technology stack](tech-stack.md): verified frameworks, dependencies, runtime paths, and open stack decisions.
- [UI/UX specification](ui-ux.md): information architecture, visual rules, interaction states, and accessibility requirements.
- [Architecture](architecture.md): applications, startup, navigation, modules, and data flow.
- [Database and backend](database.md): Neon connection paths, schemas, migrations, and tools.
- [Admin console](admin-console.md): routes, roles, queries, local development, and current auth behavior.

## Working locally

- [Setup](setup.md): prerequisites, environment files, Firebase, Neon, and first run.
- [Development workflow](development.md): commands, source ownership, and change practices.
- [Testing](testing.md): Flutter checks, admin checks, and current coverage boundaries.
- [Troubleshooting](troubleshooting.md): common setup and runtime failures.
- [Requirements traceability](requirements-traceability.md): requirements linked to source, data, tests, and status.

## Operations

- [Deployment](deployment.md): Android APK, Flutter web, and admin-console hosting.
- [Security](security.md): secrets, current risks, and release blockers.
- [Release checklist](release-checklist.md): pre-release quality, data, security, and artifact gates.
- [Decision log](decision-log.md): significant decisions and unresolved architecture choices.
- [ADR template](adr-template.md): template for durable technical/product decisions.
- [Change template](change-template.md): template for scoped implementation requests.
- [AI-agent playbook](ai-agent-playbook.md): context, change, review, and completion protocol for AI agents.

## Source references

- Root Flutter dependencies: `pubspec.yaml`
- Flutter entry point: `lib/main.dart`
- Admin entry point: `shieldweb/src/main.tsx`
- Admin routes: `shieldweb/src/App.tsx`
- App schema: `backend/db/app_schema.sql`
- Public schema snapshot: `backend/db/SCHEMA.md`
- Firebase setup: `FIREBASE_SETUP.md`
