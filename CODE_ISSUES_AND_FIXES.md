# SHIELD — Current Code Issues & Fixes

**Date:** 2026-09-16
**Scope:** Findings derived exclusively from reading the current source code (not from `log.md`, git history, or narrative docs under `docs/`). Covers optimization/performance, UI/UX, and forward-looking scaling risks across the Flutter member app, the `shieldweb` admin console, and the `backend` NestJS API/database. This is a companion to `AUDIT_REPORT.md`, which covers correctness/authorization bugs — findings already listed there are not repeated here.

Every item below has a concrete fix. No code has been changed — this is a findings + remediation list for review.

---

## 1. Flutter member app (`lib/`)

### 1.1 Performance / optimization

**HIGH — Catalogue fetch has no pagination and embeds full base64 images.**
`lib/data/neon/product_repository.dart:29-56` (`listActive()`) selects every `ACTIVE` product row — including the base64 `image` data URI (line 47) — with no `LIMIT`, on every cold start (`main.dart:82`) and every catalogue refresh.
*Fix*: page the listing with keyset pagination (`WHERE created_at < $cursor ORDER BY created_at DESC LIMIT 40`) and move `image` out of the list query into a separate per-product fetch or a dedicated thumbnail column.

**HIGH — Agent roster fetch pulls the entire national hierarchy on every "My Team" open.**
`lib/data/neon/agent_repository.dart:28-38` (`fetchAll()`) runs `SELECT ... FROM app.agent ORDER BY id` with no `WHERE`/`LIMIT`. `agent_team_tree_screen.dart:77,83` calls `ensureLoaded(force: true)` every time the screen opens, even though the UI (`_MindNode._buildChildNodes`, lines 681-713) only ever renders one open branch at a time.
*Fix*: fetch children on demand (`WHERE parent_id = $1`) scoped to the node being expanded, instead of loading the whole tree client-side; at minimum, drop `force: true` when the roster is already warm.

**MEDIUM — Product images decoded at full resolution regardless of display size.**
`lib/widgets/app_image.dart:83-91` calls `Image.memory`/`Image.network` with no `cacheWidth`/`cacheHeight`, so a ~150–180px grid tile (`product_collection_screen.dart:197-209`, `category_listing_screen.dart:165-166`) still decodes the source photo at full size.
*Fix*: since `width`/`height` are already passed in, compute `cacheWidth: (width! * MediaQuery.of(context).devicePixelRatio).round()` (same for height) and pass it through on both branches.

**MEDIUM — Persona-status polling never pauses when the app is backgrounded.**
`lib/module/auth/persona_gate.dart:106-130` runs a `Timer.periodic` (60s) for the entire process lifetime with no `WidgetsBindingObserver`/lifecycle gating — the surrounding code comment (lines 85-90) already acknowledges this. It keeps firing Neon queries while backgrounded.
*Fix*: add a `WidgetsBindingObserver`, cancel the timer on `paused`/`detached`, recheck once immediately and restart on `resumed`.

**LOW — Seven concurrent bootstrap fetches compete for bandwidth at cold start.**
`lib/main.dart:82-106` fires catalogue, categories, reviews, agent geo, stores, and investor loads all at once via `unawaited(...)`, alongside a ping (line 116).
*Fix*: stagger the calls — load catalogue + categories first, defer investor/reviews slightly — or add one combined bootstrap endpoint server-side.

### 1.2 UI/UX

**HIGH — Home feed silently disappears on a load failure instead of showing an error.**
`lib/screens/home_screen.dart:330-334`: when `CatalogueService.status == CatalogueStatus.error`, the entire product-rows section renders `SizedBox.shrink()` — no message, no retry. Compare `agent_team_tree_screen.dart:317-326`'s `_HierarchyStatus`, which does this correctly for the same failure class.
*Fix*: add an inline error state (icon + "Couldn't load products" + a retry button calling `CatalogueService.instance.refresh()`), mirroring `_HierarchyStatus`.

**MEDIUM — Cart shows a different currency format than the rest of the app.**
Most screens format money via `formatRupees()` (comma-grouped, no decimals — e.g. `agent_detail_screen.dart:86-95`, `checkout_order.dart:22,76`), but the cart hand-builds labels: `lib/module/cart/cart_screen.dart:371,510,534,1007,1011,1021` and `lib/module/cart/cart_bar.dart:57` use `'₹${value.toStringAsFixed(2)}'`, producing `₹1234.50` instead of `₹1,234.50` right where users move between feed → cart → checkout.
*Fix*: route these six call sites through `formatRupees()` (extend it to optionally keep two decimals, or round first) so cart and checkout match.

**MEDIUM — No dark theme declared; system dark mode does nothing predictable.**
`lib/main.dart:136-144` sets only a light `theme:` with no `darkTheme`/explicit `themeMode`. Flutter's default `themeMode` is `system`, so a user with OS dark mode gets an app that's still all-white (hardcoded `AppColors.white` throughout `lib/theme/app_colors.dart`) with no adjusted contrast.
*Fix*: either build a real `darkTheme` (a second `ColorScheme` in `app_colors.dart`), or explicitly set `themeMode: ThemeMode.light` in `main.dart` so the light-only behavior is a stated decision, not an accident.

**LOW — One fee label skips the shared formatter.**
`lib/module/appointment/clinic_detail_screen.dart:575` interpolates `'₹${doctor.fee}'` raw, unlike the equivalent `dietitian_screen.dart:300`, which uses `formatRupees(dietitian.fee)`.
*Fix*: wrap with `formatRupees(doctor.fee)`.

### 1.3 Future risk

**HIGH — Flat agent-roster query won't survive network growth.**
`agent_repository.dart:28-38`'s `fetchAll()` is the only path populating the hierarchy, with no server-side subtree scoping, even though the agent model is explicitly designed as a deep multi-tier hierarchy (`AgentLevel.childCapacity`, `agent_team_tree_screen.dart:22,609`). Query cost grows with the *entire* national agent count, not with any one agent's own downline.
*Fix*: add subtree-scoped queries (recursive CTE or lazy per-node fetch) before the agent count grows past a few hundred.

**HIGH — Catalogue pagination and image-storage migration are coupled, and both are still pending.**
`product_repository.dart:29-56` has no `LIMIT` and embeds base64 photos directly in the listing row — solving pagination later will require solving image storage at the same time if this isn't decoupled now.
*Fix*: move to URL-referenced image storage (object storage + CDN) now, independent of when pagination lands, so the two aren't both blocking the same fix later.

**MEDIUM — Session polling has no backoff/jitter or push alternative.**
`persona_gate.dart:101,112,129` polls every fixed 60s per signed-in device indefinitely, with no server-push (FCM) fallback.
*Fix*: when device count justifies it, replace polling with a push signal (FCM data message on persona change) and keep the timer only as a longer-interval safety net.

---

## 2. shieldweb admin console (`shieldweb/src/`)

### 2.1 Performance / optimization

**HIGH — Dashboard fetches entire Orders + Prescriptions tables for a summary widget.**
`src/pages/DashboardPage.tsx:33-48` calls unfiltered `listOrders()`/`listPrescriptions()` then filters client-side (lines 60-61). Both underlying queries join 5-6 tables across the *entire* table history, on every dashboard visit, for every role.
*Fix*: add narrow indexed summary queries — e.g. `listOrdersByStatus('processing', {limit: 50})` and a `SELECT count(*) ... WHERE status = 'PROCESSING'` for the stat number — so dashboard cost stays flat as order volume grows.

**HIGH — `useAsync` has no caching or request de-duplication.**
`src/lib/useAsync.ts:16-48` refetches from scratch on every mount/dep change. Two components mounted with the same loader (e.g. `DashboardPage` and `OrdersPage` both calling `listOrders`) issue two independent full round-trips.
*Fix*: add a minimal module-level cache map (`Map<key, {data, ts, promise}>`) keyed by a caller-supplied string, returning the in-flight promise to concurrent callers and serving cached data for N seconds before revalidating — or adopt TanStack Query.

**HIGH — `DataTable` has no pagination or virtualization.**
`src/components/ui/DataTable.tsx:11-83` maps `rows` straight into `<tr>` elements with no page size or windowing. `listApprovedAgents` (`src/api/agents.ts:264-271`) has no `LIMIT` either — thousands of DOM rows will render as data accumulates.
*Fix*: add a `pageSize`/cursor prop to `DataTable`, and page the underlying SQL with keyset pagination (`WHERE placed_at < $cursor ORDER BY placed_at DESC LIMIT 50`); at minimum add a "Load more" control.

**MEDIUM — Sequential per-row writes instead of batched inserts.**
`src/api/prescriptions.ts:289-310` (`savePrescriptionIntake`) and `src/api/orders.ts:233-242` (`sendOrderInvoice`'s bill-line rewrite) each loop `for (...) { await query(...) }` — one Neon round trip per line item, while the read side of the same file correctly batches with `WHERE id = ANY($1::bigint[])`.
*Fix*: build one `INSERT ... SELECT * FROM unnest($1::text[], $2::text[], ...)` (or a multi-row `VALUES` list bound as arrays) so a 10-line prescription is one round trip.

**LOW — Table columns array rebuilt (with inline closures) on every render.**
`src/pages/OrdersPage.tsx:164-234` recreates `columns: Column<Order>[]` on every render, including every keystroke in search (line 40), and passes it into a non-memoized `DataTable`.
*Fix*: wrap the columns array in `useMemo` (deps: `branchBound`) and wrap `DataTable` in `React.memo`.

### 2.2 UI/UX

**HIGH — Table rows are mouse-only; no keyboard access.**
`src/components/ui/DataTable.tsx:60-67` makes the whole `<tr>` clickable via `onClick` with no `tabIndex`, `role="button"`, or `onKeyDown`. Affects every list page using `onRowClick` (Orders, Agent Approvals, Activations, Users, Prescriptions) — a keyboard-only or screen-reader user cannot open a row's detail view.
*Fix*: when `onRowClick` is set, add `tabIndex={0}`, `role="button"`, and an `onKeyDown` firing on `Enter`/`Space`; or make the first cell a real `<Link>`.

**MEDIUM — Dashboard stat cards show a false "0" while still loading.**
`src/pages/DashboardPage.tsx:137-172` renders `processingOrders.length` etc. immediately from `orders.data ?? []` with no loading gate — an admin briefly sees "Orders processing: 0" during the fetch, reading as "nothing pending" rather than "still loading."
*Fix*: pass `loading` into `StatCard` and render a skeleton/dash instead of `0` until `!loading`.

**MEDIUM — No busy state on submit buttons; only opacity dims.**
`src/components/ui/Button.tsx:24-36` only applies `disabled:opacity-50` — no spinner, no `aria-busy`. On `AgentApprovalDetailPage.tsx:317-333`/`ActivationDetailPage.tsx:355-376`, "Approve"/"Reject" sit side by side; a hesitant double-click during a slow request can land the *adjacent* action instead of a harmless duplicate.
*Fix*: add an `isLoading` prop to `Button` (spinner + "Approving…" label + `aria-busy="true"`), and disable the whole action row — not just the clicked button — while saving.

**MEDIUM — Session expiry has no proactive refresh, discarding in-progress form state.**
`AuthContext.tsx` receives `expiresIn` (line 29) but never schedules a refresh from it; `src/lib/api.ts:30-52` has no 401-triggered refresh+retry. An admin mid-form on `AgentApprovalDetailPage` past token expiry gets a raw error and loses typed notes/selections on forced re-login.
*Fix*: `setTimeout(refresh, expiresIn * 0.9 * 1000)` in `establishSession`; in `api.ts`, attempt one silent refresh + retry on 401 before surfacing the error.

**LOW — Date/number formatting bypasses the shared `lib/format.ts` helpers.**
`src/api/accounts.ts:259` and `src/pages/StoresPage.tsx:350,356,398,520,524` call `.toLocaleDateString`/`.toLocaleString` directly instead of the shared formatters.
*Fix*: add a `formatNumber` helper to `lib/format.ts` and replace the ad hoc calls.

### 2.3 Future risk

**HIGH — Unbounded list queries across most modules, not just the ones already flagged.**
`listApprovedAgents`/`listPendingAgents` (`src/api/agents.ts:264-271`, `:43-50`) and likely Appointments/Lab Bookings pages built the same way have no `LIMIT`/cursor — even though `getWalletActivity` (`src/api/activations.ts:118-125`) already shows the team knows to cap lists (`LIMIT 25`).
*Fix*: standardize a `{limit, cursor}` param on every `list*` function in `src/api/*.ts`, default page size ~100.

**HIGH — No shared data-access layer; migrating a module to the real backend is a per-page rewrite.**
`src/lib/api.ts:1-6` documents a module-by-module migration off direct-Neon access, but every page imports its own `src/api/<module>.ts` talking straight to Neon, and `useAsync` has no adapter layer.
*Fix*: introduce one thin `useQuery(key, fetcher)` wrapper around `useAsync` so switching a module's fetcher from Neon-SQL to a backend API call is a one-file change with a stable call-site contract.

**MEDIUM — Role/permission metadata is scattered across four files with no single source of truth.**
Adding a role touches `src/types/index.ts:14`, `src/config/permissions.ts:160-187`, a separate `ROLE_COLOR` map in `AuthContext.tsx:17-24`, and the `StaffProfileResponse.role` mapping (`AuthContext.tsx:36,43`) — missing one (e.g. `ROLE_COLOR`, no fallback) breaks avatar rendering silently.
*Fix*: consolidate per-role metadata into one `Record<Role, RoleConfig>` in `permissions.ts`; have `AuthContext` import from there.

**MEDIUM — No environment-based feature flags anywhere.**
Only two env vars exist repo-wide (`VITE_API_BASE_URL`, `VITE_DATABASE_URL`), both infrastructure endpoints — no behavioral flags, so the planned per-module backend migration is all-or-nothing per deploy.
*Fix*: add `src/config/flags.ts` reading `VITE_FLAG_*` (or a `staff_flag` DB table) so each module's data-source switch is toggleable per environment.

---

## 3. Backend (`backend/api/src/`, `backend/db/`)

### 3.1 Performance / optimization

**HIGH — Staff-facing list endpoints return entire tables, unbounded, across multiple modules.**
`prescription.service.ts:184-196` (`listForStaff`, SUPERADMIN path) selects every prescription's full base64 `image`, no `WHERE`/`LIMIT`. Same shape in `commerce/order.service.ts:323-329` (`listForStaff`), `prescription/approval.service.ts:90-93` (`listForStaff`), `care/booking.service.ts:69-71,146` (lab bookings / appointments).
*Fix*: paginate every one (`limit`/`cursor`, matching the pattern already used in `catalogue.service.ts:121-138`); for the prescription list specifically, exclude `image` from the list query entirely and fetch it only in the single-record `getForStaff` call.

**MEDIUM — Sequential per-row updates instead of one batched statement.**
`prescription/approval.service.ts:70-73` loops `for (const item of dto.items) { await tx.update(...).where(eq(approvalItem.id, item.approvalItemId)); }` — one round trip per approval item inside a transaction.
*Fix*: one statement using `inArray` + a `CASE WHEN` expression, or `UPDATE ... FROM (VALUES ...) AS v(id, accepted) WHERE approval_item.id = v.id`.

**MEDIUM — Missing indexes on several high-traffic foreign-key columns.**
Unindexed: `prescription_medicine.prescription_id` (queried on every prescription detail view), `approval_item.approval_id`, `agent_wallet_transfer.agent_id`, `agent_customer_plan.agent_customer_id`, and the entire geo hierarchy chain (`state.region_id`, `district.state_id`, `assembly.district_id`, `lsgd.assembly_id`, `ward.lsgd_id` — ward alone is ~21k rows).
*Fix*:
```sql
CREATE INDEX prescription_medicine_prescription_idx ON app.prescription_medicine(prescription_id);
CREATE INDEX approval_item_approval_idx ON app.approval_item(approval_id);
CREATE INDEX state_region_idx ON app.state(region_id);
CREATE INDEX district_state_idx ON app.district(state_id);
CREATE INDEX assembly_district_idx ON app.assembly(district_id);
CREATE INDEX lsgd_assembly_idx ON app.lsgd(assembly_id);
CREATE INDEX ward_lsgd_idx ON app.ward(lsgd_id);
```
(Note: `cache/cache.service.ts` is genuinely used across catalogue/geo/care/dashboard — not dead code.)

### 3.2 Security (beyond what `AUDIT_REPORT.md` already covers)

**HIGH — Refresh-token reuse is rejected but never revokes the session.**
`modules/auth/auth.service.ts:175-188`: a used/expired refresh token throws `UnauthorizedException`, but the matching `authSession` is left active. If an attacker exfiltrates and uses a refresh token first, the legitimate client's next refresh simply fails while the session keeps rotating under the attacker — no kill switch, no signal to the real user.
*Fix*: when `stored.usedAt` is already set (token was valid but already consumed — distinct from "not found/expired"), call `revokeAllSessions` for that session before throwing, and consider notifying the member.

**MEDIUM — No size ceiling on base64 image uploads anywhere in the stack.**
`modules/prescription/dto.ts:7` validates `image` with only a format regex, no `.max()`; `main.ts` never overrides Nest's default body-parser limits; `member-prescription.controller.ts:25-31` (`upload`) has no endpoint-specific throttle, only the global 120/min default.
*Fix*: add `.max(4_000_000)` to the zod schema for every base64 image field, set `express.json({ limit: '3mb' })` explicitly in `main.ts`, and add a `@Throttle` decorator to the upload endpoint.

**LOW — In-memory rate limiting doesn't hold up under horizontal/serverless scale.**
`app.module.ts:36` (`ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }])`) has no `storage:` option, defaulting to per-process memory. On the Vercel serverless deployment (`api/vercel.json`), each warm instance keeps its own counter, so the real per-identity ceiling becomes `limit × concurrent-instance-count`, not `limit` — undermining the `AuthThrottle`/`FinancialThrottle` decorators' intent.
*Fix*: back `ThrottlerModule` with `ThrottlerStorageRedisService` against the existing `REDIS_URL`.

### 3.3 Future risk

**HIGH — Hardcoded DB pool size on a serverless deployment risks exhausting Neon's connection ceiling.**
`db/client.ts:20-25`: `new Pool({ ..., max: 15 })` is a fixed literal, not in `config/env.ts`'s schema. Each concurrently-scaled Vercel instance opens its own pool of up to 15 connections; a traffic burst spinning up dozens of instances multiplies quickly.
*Fix*: add `DB_POOL_MAX` to `env.ts` with a small serverless-appropriate default (3-5), and confirm `DATABASE_URL` in production points at Neon's `-pooler` (pgbouncer) endpoint, not the direct one.

**MEDIUM — No archival/cleanup path for ever-growing auth/idempotency tables, and no job-scheduling primitive exists.**
`backend-idempotency.ts` (`idempotency_key`) and `backend-auth.ts` (`refresh_token`, a new row per rotation) have no expiry sweep. A repo-wide search found zero uses of `@nestjs/schedule`/cron anywhere — meaning nothing cleans these up today, and the first naive `@Cron` added later will double-fire across every serverless instance with no lock.
*Fix*: use a periodic *external* job (Vercel Cron hitting an authenticated internal endpoint, or a Neon scheduled job) doing `DELETE FROM backend.refresh_token WHERE expires_at < now() - interval '90 days'`, etc. — not an in-process scheduler.

**LOW — An irreversible column-dropping migration with no rollback tooling.**
`db/migrations/0024_bill_table.sql:40-41` drops `bill_image`/`billed_at` from `order` permanently after migrating their data; `db/apply_migration.dart` has no down/rollback mechanism at all.
*Fix*: for future column-dropping migrations, rename-then-drop in a later migration (two-step) so there's a verification window; document a "restore from Neon branch/PITR" runbook as compensating control since `apply_migration.dart` has none.

**LOW — CORS is configured independently in two places that can silently diverge.**
`main.ts:14` and `api/index.js:23` each call `enableCors({ origin: true, credentials: true })` separately — a future origin-allowlist fix applied to one will miss the other.
*Fix*: extract one shared `configureCors(app)` helper used by both entrypoints.

---

## 4. Summary table (fix priority)

| Priority | Area | Issue | Effort |
|---|---|---|---|
| 1 | shieldweb + backend | Add pagination/`LIMIT` to every unbounded list query (dashboard, orders, prescriptions, agents, catalogue) | Medium — repeated pattern, same fix each time |
| 2 | Flutter | Catalogue/agent-roster fetches: page + move images out of list payload | Medium |
| 3 | backend | Fix refresh-token-reuse to revoke session, not just reject | Small |
| 4 | backend | Add missing FK indexes (SQL provided above) | Small |
| 5 | shieldweb | Add caching/dedup to `useAsync`, memoize `DataTable` columns | Medium |
| 6 | Flutter | Home-feed error state, cart currency formatting, dark-theme decision | Small each |
| 7 | shieldweb | Keyboard accessibility on `DataTable` rows, loading-state stat cards, busy-state buttons | Small each |
| 8 | backend | Image upload size caps + throttle on prescription upload | Small |
| 9 | backend | Move rate limiting to Redis-backed storage; env-driven DB pool size | Small |
| 10 | all | Everything under "Future risk" | Schedule as roadmap items, not blockers |

---

*All findings verified by reading current source; none were derived from `log.md`, git history, or narrative documentation. See `AUDIT_REPORT.md` for the separate correctness/authorization audit.*
