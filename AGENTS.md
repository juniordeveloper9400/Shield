# SHIELD Repository Agent Guide

## Scope

This guide applies to the entire repository. More specific guidance may be added in child directories when needed.

## Repository shape

- The root project is a Flutter app for SHIELD members.
- `shieldweb/` is an independent React + TypeScript + Vite operations console.
- `backend/` contains Neon/Postgres schema snapshots, migrations, and database tools.
- `test/` contains Flutter widget and service tests.
- `shield agent_invester/` is a parallel/legacy Flutter project tree. Do not modify it unless the task explicitly targets it.
- `build/`, `.dart_tool/`, and other generated files are not source of truth.

## Working rules

- Read `docs/README.md` and the relevant topic document before changing behavior.
- Keep Flutter app work under the root `lib/`, `test/`, `android/`, `web/`, and `assets/` unless the request names another tree.
- Keep admin-console work under `shieldweb/`; run its commands from that directory.
- Keep database changes in `backend/db/` and document destructive operations before running them.
- Never print, commit, or copy values from `.env`, generated Neon secrets, Firebase service-account files, keystores, or passwords.
- Do not treat browser-bundled values as secrets. The admin console currently ships its database URL and its login credential list to the browser; see `docs/security.md`.
- Preserve unrelated worktree changes. Avoid broad formatting or generated-file churn.
- Prefer existing repository patterns and small, focused edits. Do not add dependencies without need.

## Validation

Flutter:

```powershell
flutter pub get
flutter analyze
flutter test -j 2
```

Admin console:

```powershell
Set-Location shieldweb
npm install
npm run typecheck
npm run build
```

Database tools require a configured, git-ignored `.env`; use `dart run tool/neon_ping.dart` for a non-destructive connectivity check.

## Documentation expectations

Update `docs/` when setup, data flow, security, deployment, or commands change. Keep current limitations explicit rather than documenting intended future architecture as if it exists.
