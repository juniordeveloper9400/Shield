# Development Workflow

## Before changing code

Check `git status --short`, identify the owning app, and read the nearby implementation plus its test. Preserve unrelated changes, including asset deletions or platform configuration edits already present in the worktree.

## Commands

From the repository root:

```powershell
flutter pub get
flutter analyze
flutter test -j 2
flutter run
```

From `shieldweb/`:

```powershell
npm install
npm run typecheck
npm run build
npm run dev
npm run preview
```

Database tools are run from the repository root and require `.env`:

```powershell
dart run tool/neon_ping.dart
dart run backend/db/introspect.dart
dart run backend/db/dump.dart
```

## Change locations

- Member UI and workflows: `lib/module/`, `lib/screens/`, `lib/widgets/`.
- Shared values and services: `lib/data/`, `lib/theme/`, root utility Dart files.
- Member behavior tests: `test/` with shared fakes in `test/support/`.
- Admin pages and routes: `shieldweb/src/pages/` and `shieldweb/src/App.tsx`.
- Admin query layer: `shieldweb/src/api/`.
- Admin permissions/auth: `shieldweb/src/config/` and `shieldweb/src/context/`.
- Schema and migrations: `backend/db/`.

## Database change discipline

Use a migration for changes to the existing `public` schema. Treat `apply_app_schema.dart --yes`, `wipe.dart --yes`, and `wipe_subset.dart ... --yes` as destructive operations requiring explicit confirmation and a backup where appropriate. Update schema documentation when the model changes.

## Style

Follow the existing Dart lint configuration and TypeScript formatting. Keep public APIs stable, avoid unrelated refactors, and add focused tests for changed behavior. Do not put credentials or connection strings in source, docs, screenshots, logs, or test fixtures.
