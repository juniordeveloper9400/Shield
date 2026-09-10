# AI Agent Engineering Playbook

This document defines how AI agents should build and maintain SHIELD. `AGENTS.md` remains the repository-wide instruction file.

## 1. Required context sequence

1. Read `AGENTS.md`, `CLAUDE.md`, and this document.
2. Read [Documentation index](README.md) and the relevant PRD/FRD/TRD/ERD/UI-UX document.
3. Identify the owning app and exact source symbol or route.
4. Check `git status --short`; preserve unrelated changes.
5. Read the nearest implementation and neighboring test before editing.

## 2. Source-of-truth hierarchy

1. Executable code and DDL for current behavior.
2. Tests for intended invariants.
3. Requirement documents for product intent.
4. README files and logs for operational context.
5. Agent suggestions or historical notes only after verification.

When sources disagree, document the discrepancy and create or update an ADR. Do not silently make a stale README authoritative.

## 3. Change protocol

- State one local hypothesis about the behavior being changed and one cheap check that could disprove it.
- Make the smallest focused edit.
- Run the narrowest executable validation immediately after the first substantive edit.
- Add or update focused tests for behavior changes.
- Update requirement traceability, docs, and ADRs when routes, schema, roles, dependencies, or release behavior changes.
- Never commit secrets, credentials, generated secret Dart, service-account JSON, signing keys, or real health records.

## 4. App routing

- Root Flutter app changes belong in root `lib/`, `test/`, `android/`, `web/`, and `assets/`.
- Admin console changes belong in `shieldweb/` and must be checked with `npm run typecheck` and `npm run build` when available.
- `shield agent_invester/` is a separate/legacy tree; modify it only when explicitly named.

## 5. Database protocol

- Read `docs/erd.md` and `docs/database.md` before schema changes.
- Use migrations for existing schema changes.
- Treat schema recreation and wipe commands as destructive and require explicit confirmation.
- Verify the target environment before applying commands.
- Update DDL, schema documentation, seed behavior, affected repositories, and tests together.

## 6. Review protocol

AI-generated changes must be reviewed for: authorization at the trusted boundary, data leakage, race conditions, null/empty states, retry behavior, monetary precision, status transition validity, mobile/web plugin compatibility, and documentation drift.

## 7. Completion report

A useful agent completion report names changed files, behavior, tests/commands run, known blockers, and follow-up risks. It must say when a check could not run because a tool or environment prerequisite is unavailable.
