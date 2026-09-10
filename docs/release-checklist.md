# Release Checklist

## Scope and requirements

- [ ] PRD and FRD requirements for the release are identified.
- [ ] Traceability matrix has implementation and test evidence.
- [ ] Any requirement deviation has an ADR.

## Code quality

- [ ] `flutter analyze`
- [ ] `flutter test -j 2`
- [ ] From `shieldweb/`: `npm run typecheck`
- [ ] From `shieldweb/`: `npm run build`
- [ ] Manual smoke checks cover auth, primary workflows, empty/error states, and direct route refresh.

## Database

- [ ] Schema/migrations are reviewed against `docs/erd.md`.
- [ ] Seed and rollback/backup approach is documented.
- [ ] No destructive command targets the wrong environment.
- [ ] Schema drift is resolved or explicitly accepted in an ADR.

## Security and privacy

- [ ] No `.env`, generated Neon secret, password, token, service-account JSON, keystore, or real health record is included.
- [ ] Staff authentication and authorization are server-side for production.
- [ ] Browser bundles contain no database authorization credential or password.
- [ ] Prescription and member data retention/access rules are reviewed.
- [ ] Production Android keystore replaces the debug key.

## Release artifact

- [ ] Firebase package/config and release fingerprints are verified.
- [ ] Neon endpoint and schema compatibility are verified.
- [ ] Version/build number is updated.
- [ ] APK/web/admin artifact is inspected in the target environment.
- [ ] Rollback owner and incident contact are known.
