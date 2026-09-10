# Security

## Secret handling

Keep these local and git-ignored:

- root `.env` and `shieldweb/.env.local`
- generated `lib/data/neon/neon_secret.dart`
- Firebase service-account credentials
- release keystores and passwords

Firebase client configuration is not equivalent to a service-account secret. Never add Admin SDK credentials to Flutter or the browser app.

## Current high-risk limitations

1. The admin console credential list is bundled in `shieldweb/src/config/admins.ts`. Anyone who can retrieve the JavaScript bundle can recover the login passwords.
2. The admin console stores the login id in `localStorage` and has no server-issued session or server-side authorization boundary.
3. The admin console bundles a Neon database URL and queries Neon directly from the browser.
4. The Android release script currently signs with the debug key.

These are known implementation facts, not acceptable production security controls. Restrict the console to a trusted internal environment while they remain.

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
