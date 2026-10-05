# Security

## Secret handling

Keep these local and git-ignored:

- root `.env` and `shieldweb/.env.local`
- generated `lib/data/neon/neon_secret.dart`
- Firebase service-account credentials
- release keystores and passwords

Firebase client configuration is not equivalent to a service-account secret. Never add Admin SDK credentials to Flutter or the browser app.

## Current high-risk limitations

Checked against the code on 2026-10-05. Earlier versions of this page described the static admin credential list, which has since been removed.

1. **Admin login is real, but the session is held in the browser.** Staff sign in through `backend/api` (`/v1/staff/auth/*`) with bcrypt-hashed passwords and rotating refresh tokens. The refresh token is kept in `localStorage` (`shieldweb/src/context/AuthContext.tsx`), so any script running in the console's page could read it. Moving it to an HttpOnly cookie is still open.
2. **The console still holds the full-privilege database credential.** `shieldweb/src/lib/db.ts` reads `VITE_DATABASE_URL`, which Vite inlines into the public bundle, and 14 API modules still run SQL from the browser. Order writes, the order board and the fulfilment status now go through `backend/api`; the remaining modules have not moved. Until they do, anyone who can read the bundle has direct database access.
3. **Member and agent apps.** The member APK compiles in a database connection (`lib/data/neon/neon_secret.dart`). The agent/investor web build passes `DATABASE_URL` into its bundle through `vercel-build.sh`. Both are scheduled for removal in the client migration (`backend/docs/migration-plan.md`).
4. **Release signing.** The root app and the agent/investor app both sign release builds with the upload key from `android/key.properties` (git-ignored). The debug key is used only when that file is missing, which should never happen for a release.
5. **Money paths.** A wallet-paid order is marked paid only after the wallet debit succeeds; a refused debit cancels the order. Wallet card approval and national agent approval are guarded against concurrent double-credit. Agent withdrawal approval was already guarded in the database function `app.review_agent_withdrawal`.

These are current facts, not acceptable production controls. Restrict the console to a trusted internal environment until items 1 and 2 are closed.

## Required remediation before public release

- Move authentication to a server-side identity provider/session flow.
- Store password hashes or managed identities server-side; remove static credentials from source and bundles.
- Enforce role and branch authorization on the server for every database operation.
- Move Neon access behind a server API or trusted backend connection.
- Rotate every credential that has appeared in source, logs, screenshots, or shared environments.
- Configure production Android signing and register only the required release fingerprints.
- Review database privileges, backups, audit logging, rate limits, and personal-health-data handling.

## Safe operating rules

Never paste connection strings, passwords, tokens, private keys, or service-account JSON into issues, pull requests, documentation, tests, or chat. Treat prescription images and member health information as sensitive data and avoid using real records in development.
