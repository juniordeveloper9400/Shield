# Member App TRD

## Runtime

- Flutter/Dart application with Material 3.
- Firebase Core and Firebase Phone Auth.
- `NeonHttp` over HTTPS for member sign-in/registration writes.
- `NeonDatabase` via `postgres` for native repository operations.
- `shared_preferences` for local OTP throttling/session-adjacent persistence.
- Flutter web is supported selectively; PostgreSQL socket access is native-only.

## Boundaries

`lib/main.dart` owns startup. `RootScreen` owns splash/auth/persona gating. `AppShell` owns persistent navigation. `lib/module/` owns feature workflows. `lib/data/neon/` owns persistence.

## Reliability rules

Firebase restore, persona resolution, catalogue warmup, review warmup, and Neon ping must not make the app white-screen on failure. Member writes must surface enough status to distinguish unconfigured, unreachable, and successful states.

## Data rules

Use the `app` schema; preserve `numeric(12,2)` monetary values, enum workflow states, soft-delete semantics, and append-oriented wallet ledgers. Prescription images must be resized and treated as sensitive data.

## Release gates

Verify Firebase Android config and signing fingerprints, replace the debug release key, generate the ignored Neon secret from `.env`, run Flutter analysis/tests, and validate platform support for every plugin used by the release.
