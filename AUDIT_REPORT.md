# SHIELD Repository Audit Report

**Date:** 2026-09-16
**Scope:** Full repository — root Flutter member app (`lib/`, `test/`, `android/`), `shieldweb/` (React/TS/Vite admin console), `backend/` (NestJS API + Neon/Postgres schema and migrations). `shield agent_invester/` (legacy parallel tree) was excluded per `AGENTS.md`.
**Method:** Manual review of bootstrap/auth/data-access layers, targeted deep-dives per module, cross-checked against existing docs (`docs/security.md`, `docs/decision-log.md`, `docs/erd.md`, `docs/tech-stack.md`), plus a review of the six files currently modified but uncommitted in the working tree. `flutter analyze` was run; `shieldweb` typecheck/build and backend test execution were assessed by static reading (not run against a live DB).

No code was changed as part of this audit — findings only.

---

## 1. Executive summary

The codebase is in better shape than the checked-in docs suggest in one important respect (the admin console now has real server-side auth), and in a materially worse shape in another (the admin console's *data layer* still bypasses that auth entirely). The single highest-impact fact in this report is:

> **The `shieldweb` admin console authenticates staff with real bcrypt/JWT auth, but every data read and write after login still goes straight from the browser to Neon Postgres using a bundled full-privilege connection string.** Login is real; authorization is not. Anyone who extracts the connection string from the JS bundle has unauthenticated, unaudited, full read/write access to the entire `app` schema — including the ability to approve agents, alter commission tiers, and rewrite order/bill status for any branch — with no server in the loop at all.

The second most important fact is a **money-integrity bug in the Flutter app**: a wallet-paid order is marked `PAID` before the wallet debit is confirmed to have succeeded, and the debit's boolean success flag is discarded. The correct pattern already exists elsewhere in the same file but wasn't applied here.

The third is **schema drift that will break a fresh database**: `backend/db/app_schema.sql` (the canonical from-scratch DDL) is missing the geo-hierarchy tables and `agent.area_id` that live code depends on, so `apply_app_schema.dart --yes` today produces a database that 500s on agent approvals and all geo routes.

None of these are new categories of problem — `docs/decision-log.md` and `docs/security.md` already flagged adjacent issues — but this audit found the concrete, currently-exploitable code paths behind them, plus several the docs don't mention at all (races in wallet-card and NATIONAL-agent approval, missing indexes, unbounded prescription-image payloads, and the fact that `docs/security.md` itself is now out of date about the admin console's auth model).

---

## 2. Findings ranked by severity (cross-repo)

### 🔴 Critical

| # | Area | Finding | Location |
|---|------|---------|----------|
| C1 | shieldweb | Full-privilege raw Postgres connection string (`neondb_owner`) is bundled into the browser and used for every data operation post-login — login is real, authorization is not. | `shieldweb/src/lib/db.ts:20-51`, `shieldweb/src/lib/api.ts:3-5` |
| C2 | shieldweb | No role/branch check *inside* the mutating functions themselves — `approveAgent`, `rejectAgent`, activation approve/reject run raw SQL with zero server-side authorization; the role check only hides a button client-side. | `shieldweb/src/api/agents.ts:85,210`, `shieldweb/src/api/activations.ts:152,205` |
| C3 | shieldweb | Branch/store scoping is applied only *after* fetching every branch's data client-side — a branch-scoped Pharmacy Admin's browser receives every other branch's orders, bills, and prescriptions in full. | `shieldweb/src/api/orders.ts:36-69`, `prescriptions.ts`, `billPayments.ts`; filtered only in `OrdersPage.tsx:63`, `BillsPage.tsx:55`, `PrescriptionsPage.tsx:41` |
| C4 | Flutter app | Wallet-paid orders are recorded as `PAID` unconditionally before the wallet debit's success is checked; the debit's `bool` return is discarded, so a declined/failed debit still shows the member a fully-paid order with no ledger entry. | `lib/data/neon/order_repository.dart:406-449` (contrast with the correct pattern at lines 740-748 in the same file) |
| C5 | backend/db | `backend/db/app_schema.sql` lacks the `region/state/district/assembly/lsgd/ward` tables and `agent.area_id`, which live code (`AgentService.approveRequest`, `GeoModule`) depends on — a fresh schema apply breaks agent approval and all geo routes. | `backend/db/app_schema.sql` vs. `migrations/0014_geo_hierarchy.sql`…`0017_agent_area_id.sql`; `backend/api/src/modules/agent/agent.service.ts:106,117-141,173-177` |

### 🟠 High

| # | Area | Finding | Location |
|---|------|---------|----------|
| H1 | shieldweb | Order status can be changed for any store's order — no ownership/branch check in `setOrderStatus`. | `shieldweb/src/api/orders.ts:160-165` |
| H2 | shieldweb | Bill attach/send/clear on any order has no store/role check — invoices can be forged or erased for any branch. | `shieldweb/src/api/orders.ts:167-248` |
| H3 | Flutter app | `AgentRepository.ensureNationalRow` keys uniqueness only on `phone` + `ON CONFLICT (code)`; two different registrations can each create a `NATIONAL`-level row with no shared key — matches the two-NATIONAL-row state already observed in production per `docs/decision-log.md`. | `lib/data/neon/agent_repository.dart:108-133` |
| H4 | Flutter app | Systemic silent-failure pattern: every Neon repository method collapses network errors, SQL errors, and business-rule failures (insufficient balance, missing row) into the same falsy return, and most callers (including the checkout path in C4) don't branch on it. | `lib/data/neon/*_repository.dart` (e.g. `wallet_repository.dart:289-299`) |
| H5 | backend | TOCTOU race in NATIONAL-agent approval: existence check and insert are both inside one transaction but with no DB-level partial unique index or row locking — concurrent approvals can recreate the exact duplicate-NATIONAL-row bug the code's docstring claims to prevent. | `backend/api/src/modules/agent/agent.service.ts:91-101` |
| H6 | backend | Same race shape in wallet-card approval and withdrawal resolution: the status-flipping `UPDATE` has no `WHERE status = 'PENDING'` guard, so two concurrent approvals (or a client retry) can double-credit a wallet. | `backend/api/src/modules/wallet/wallet.service.ts:100-148` (`approveCard`), `agent.service.ts:285-309` (`resolveWithdrawal`) |

### 🟡 Medium

| # | Area | Finding | Location |
|---|------|---------|----------|
| M1 | docs | `docs/security.md` is stale: it still describes the removed `shieldweb/src/config/admins.ts` static-credential list as the current risk, and doesn't mention that a real bcrypt/JWT login now exists — masking that the *actual* remaining boundary is the raw DB credential (C1), which is a different and arguably worse risk than what's documented. | `docs/security.md:16-18` |
| M2 | backend | New `getPrescriptionsForOrder` endpoint is authorization-correct (verified via `getOwnedByMemberOrThrow`) but returns the raw `image` column name instead of the `imageUrl` renaming convention used everywhere else in the prescription API, and has no size bound — large base64 prescription scans are returned inline with no pagination or signed-URL indirection (the existing `ObjectStorage`/S3 module is unused; images live as base64 in Postgres). | `backend/api/src/modules/commerce/order.service.ts:306-319` vs. `prescription.service.ts:268-276` |
| M3 | backend | Missing indexes on `app.prescription_order`'s foreign key columns (`prescription_id`, `order_id`) — the new endpoint's query and existing staff lookups are sequential scans. | `backend/db/app_schema.sql:677-687` |
| M4 | backend | CORS is fully open with credentials enabled (`origin: true`); already flagged in-code as temporary, exposure is partly mitigated by bearer-token (not cookie) auth, but no defense-in-depth remains for any XSS-obtained token. | `backend/api/src/main.ts:16` |
| M5 | Flutter app | Order-code collision retry gives up silently after 20 attempts, dropping the entire order (lines, wallet debit, receipt) with no user-facing error. | `lib/data/neon/order_repository.dart:432-436` |
| M6 | Flutter app | Repository layer (money movement: wallet debits, order payment status, prescriptions — ~3000+ lines) has essentially no direct unit test coverage; existing tests exercise higher-level facades, not the Neon repository logic where C4 lives. | `test/neon_repository_test.dart` (44 lines total), no `wallet_test.dart` |
| M7 | shieldweb | `.env.local` (correctly git-ignored, confirmed untracked) holds a live Vercel OIDC token and the real Neon owner credential in plaintext on disk — not a code bug, but a standing handling risk per `CLAUDE.md`'s secret rules. | `shieldweb/.env.local` |
| M8 | backend | `investor` and `identity` modules have no `*.e2e-spec.ts` under `backend/api/test/integration/`, unlike `commerce`, `wallet`, `agent`, `care`, `catalogue`, `admin`, `prescription`. | `backend/api/test/integration/` |

### ⚪ Low

| # | Area | Finding | Location |
|---|------|---------|----------|
| L1 | backend | Validation relies on a hand-called `ZodValidationPipe` per route with no global `APP_PIPE` default — currently applied consistently everywhere checked, but nothing prevents a future controller from skipping it silently. | `backend/api/src/**/*.controller.ts` |
| L2 | backend | `geo.controller.ts` id params take raw strings with no format validation, inconsistent with `ParseIntPipe` used elsewhere (not exploitable — Drizzle parameterizes — just inconsistent). | `backend/api/src/modules/geo/geo.controller.ts:42-66` |
| L3 | Flutter app | `analysis_options.yaml` uses only stock `flutter_lints` with all stricter rules commented out; low-risk today since `flutter analyze` is clean apart from 2 trivial deprecation infos in a test file. | `analysis_options.yaml:1-32` |
| L4 | Flutter app | `postgres` package (raw socket driver) is still a dependency though all member writes reportedly go through `neon_http.dart` now — worth confirming it's still used or dropping it. | `pubspec.yaml` |
| L5 | docs | `docs/security.md` says the Android release script signs with the debug key; actual `build.gradle.kts` correctly implements a real keystore via git-ignored `key.properties`, falling back to debug only when that file is absent. This is the doc being *more pessimistic* than reality — worth correcting either direction so the doc is trusted. | `android/app/build.gradle.kts:56-81` |
| L6 | Flutter app | New dialog-based review video player (`showReviewVideo`) has no loading/error state if the YouTube iframe fails to load, and its close button lacks a `Tooltip`/`Semantics` label. | `lib/module/home/review_video_player_screen.dart` |
| L7 | shieldweb | Firebase web config is hardcoded in source — correctly non-secret per Firebase's own model, flagged only for completeness. | `shieldweb/src/lib/deliveryOtp.ts:19-26` |

---

## 3. Review of currently uncommitted changes

Six files are modified in the working tree (not yet committed):

- `backend/api/src/modules/commerce/member-commerce.controller.ts` + `order.service.ts` + `prescription.e2e-spec.ts` — adds `GET /v1/member/orders/:id/prescriptions`. **Authorization is correct** (ownership-checked, cross-member access blocked, confirmed by the new e2e test). The only issues are M2 and M3 above (field naming inconsistency + unbounded payload + missing index) — not blockers, but worth fixing alongside this change rather than separately.
- `lib/module/home/customer_reviews.dart` + `review_video_player_screen.dart` + `test/customer_reviews_test.dart` — converts the review-video full-page route into a dialog overlay. Correctly disposes its `YoutubePlayerController`, is well covered by the new test (overlay-not-a-route, close-button dismiss, no-op on malformed URL). Only L6 (no load-failure state, missing a11y label) applies.

Neither in-progress change introduces a new Critical/High issue; both are otherwise sound.

---

## 4. Cross-reference with existing documentation

`docs/decision-log.md` and `docs/erd.md` already record some of these as open items. This audit either **confirms with a concrete code path**, **sharpens the scope**, or **adds a new item not previously documented**:

- Two `NATIONAL` agent rows in production (documented) → confirmed via `ensureNationalRow` (H3) *and* a second, independent server-side race that can reproduce it even after a client-side fix (H5).
- Geo-table/`area_id` schema drift (documented as needing to "fold 0014-0017 into app_schema.sql") → confirmed as **not just cosmetic drift but a live 500-error risk** on a fresh schema apply (C5).
- Admin console Neon-URL-in-browser and "final enforcement must move server-side" (documented) → confirmed as **currently unenforced in the mutating paths that matter most** (agent approval, wallet/commission changes, cross-branch order/bill mutation) — C1-C3, H1-H2, not just a data-read exposure.
- **Not previously documented**: `docs/security.md`'s description of the admin console's *login* mechanism is now inaccurate (M1) — the static credential list it warns about no longer exists in the code (replaced by real bcrypt/JWT), while the actual remaining exposure (raw DB access bypassing that auth) is undersold by the doc's current wording.
- **Not previously documented**: the Android signing-key doc statement is more pessimistic than the actual implementation (L5).
- **Not previously documented**: wallet-card/withdrawal approval race conditions (H6), missing `prescription_order` indexes (M3), and the Flutter wallet-debit-order-status bug (C4).

---

## 5. What's actually solid

- **SQL injection risk is essentially absent repo-wide.** All ~19 files in `lib/data/neon/`, all `shieldweb/src/api/*` modules, and all `backend/api` Drizzle queries use parameterized placeholders or tagged templates — no string-concatenated SQL was found anywhere in three independent passes.
- **Staff auth core in `shieldweb`/`backend` is well-built**: bcrypt password hashing, generic invalid-credential errors (no login-id enumeration), single-use rotating refresh tokens stored only as hashes, and session revocation is re-checked on every request rather than only at token issuance.
- **Money paths on the backend use real transactions**: `OrderService.checkout` wraps order creation, cart clearing, rewards, referrals, and wallet debit in one transaction, with the debit amount clamped server-side rather than trusted from the client.
- **Ownership checks are consistently applied** on the backend via small, repeated `getOwnedByMemberOrThrow`/`getOwnedByStaffOrThrow` helpers, and store-scoped staff access correctly falls back except for `SUPERADMIN`.
- **Secret hygiene is correct in practice, not just on paper**: `git ls-files` confirms `.env`, `lib/data/neon/neon_secret.dart`, `android/key.properties`, keystores, and `shieldweb/.env.local` are all genuinely untracked; only templates/generators are committed.
- **`flutter analyze` is clean** apart from two trivial test-only deprecation infos; async-gap `setState` calls checked in checkout and agent-registration flows are properly `mounted`-guarded.
- **`shieldweb` typechecks cleanly** under `strict: true`, uses a consistent shared `useAsync` hook across pages instead of ad hoc fetch/loading/error state, and has no `dangerouslySetInnerHTML`/`.innerHTML` anywhere in its source.
- **Env var handling on the backend has no insecure fallback secrets** — JWT secrets are required with a minimum length and no `??` default; Firebase credentials are enforced as required in production via schema validation.

---

## 6. Suggested priority order (not actioned — for discussion)

1. **C1–C3, H1–H2 (shieldweb authorization boundary)**: this is the single largest blast-radius gap in the repo — one leaked bundle currently gives unaudited write access to agent approvals, commissions, and every branch's orders/bills. Moving mutating operations behind `backend/api` with real server-side role/branch checks (already partially built — the auth server exists) is the natural next step, not a new framework.
2. **C4 (wallet-paid order marked PAID before debit confirmed)**: small, isolated fix — apply the same guard pattern already used in `markOrderPaidByWallet` in the same file.
3. **C5 (schema drift)**: fold migrations 0014–0017 into `app_schema.sql` per the existing decision-log item — now confirmed as a functional break, not just documentation debt.
4. **H5–H6 (approval races)**: add `WHERE status = 'PENDING'` guards and a partial unique index for single-NATIONAL-agent; both are narrow, low-risk changes.
5. Everything else (M/L) can be scheduled normally; M1 and L5 (doc corrections) are near-zero effort and prevent future contributors from misjudging real risk in either direction.

---

*This report reflects a point-in-time read of the working tree on 2026-09-16 and does not constitute a penetration test. `backend/api` tests and `shieldweb` build/typecheck were assessed by reading, not by execution against a live database, per the safety constraints in `CLAUDE.md` and `docs/security.md`.*
