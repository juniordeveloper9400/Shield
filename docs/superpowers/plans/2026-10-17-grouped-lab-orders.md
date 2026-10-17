# Grouped Lab Orders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One lab checkout becomes one order containing all tests, with full admin editing and grouped order history in both Flutter projects.

**Architecture:** Add an order parent above existing lab bookings; existing bookings remain the independently managed test entries. A transactional batch endpoint establishes the checkout boundary and idempotency, grouped reads enforce existing permissions, and order-specific snapshots support admin corrections without changing saved member records. Preserve existing per-test reports, bills and payment references.

**Tech Stack:** NestJS, TypeScript, Zod, Drizzle/Postgres, Jest/pg-mem, Flutter/Dart, React/TypeScript/Vite and existing test utilities; no new dependencies by default.

**Spec:** `docs/superpowers/specs/2026-10-17-grouped-lab-orders-design.md` (user approved).

## Global Constraints

- This applies only to labs. Medicine orders, prescriptions, appointments, existing wallet collection rules and unrelated admin features retain their current behavior.
- Two separate checkouts by the same user remain two separate orders.
- Preserve Skip patient details, optional addresses, Estimated total, and the existing notice: "Estimated charges: The lab may update these charges. The final amount will be confirmed by the lab."
- The removed Bill summary card is not restored.
- Existing bills, OTP collection, wallet debits, refunds and report ownership continue to reference the individual test entry. This feature does not create a new consolidated financial invoice.
- Booking-only patient labels omit invented ages and patient IDs and are not saved as patients.
- Preserve unrelated changes in all three git repositories. Read current `AGENTS.md` and docs before execution. Source changes in `shield agent_invester/` are explicitly authorized for this feature.
- Do not print secrets, modify global account identity from booking edits, apply a live migration, publish deployments or upload a store release as part of code implementation.

## Review Focus

1. A double tap, timeout or concurrent retry must never create a second set of lab bookings (Task 2).
2. Editing a cart between retries must not submit different contents with an accepted request UUID (Tasks 2 and 5).
3. An order split between branches must not leak hidden clinical details, counts or charges to branch-limited staff (Task 3).
4. Two staff editors must not silently overwrite each other's changes; finalized financial/report records retain their history (Task 4).
5. Old apps and pre-migration singleton bookings must remain usable during rollout, without guessing historical checkout groups (Tasks 1, 2 and 3).

## Structure and shared contracts

`lab_booking` stays the test entry. Create focused backend `lab-order.dto.ts`, `lab-order.service.ts`, `lab-order.read.ts` and `lab-booking-write.ts` under `backend/api/src/modules/care/`; avoid adding another large subsystem to `booking.service.ts`. Keep existing child workflow routes and extract only shared lab creation/reading code needed by the parent service. `care.module.ts` registers the new service without a circular dependency.

Create admin `src/api/labOrders.ts`, `src/lib/labOrder.ts`, `src/components/labs/LabOrderModal.tsx` and `LabOrderEditor.tsx`. Extend existing types and child modal. Each Flutter project gets `lib/module/labtest/lab_order_record.dart` and `lib/data/backend/lab_order_repository.dart`; share the wire shape, while retaining each project's existing auth and branch resolution.

Wire contracts use JSON numbers for backend IDs, decimal strings for money, ISO dates, optional ISO birth dates, and nullable age. Canonical snapshots:

- `LabContactSnapshot`: `{ name, phone }`.
- `LabAddressSnapshot`: `{ house, area, landmark, city, state, pincode, receiverFirstName, receiverLastName, receiverPhone, label }`, each optional text field; whole snapshot nullable.
- `LabPatientSnapshot`: `{ name, phone?, dob?, age?, gender?, relation?, abhaId? }`; blank optional details normalize to null. A supplied DOB determines age; reject a contradictory age. Age range is 0-120; ABHA is blank or 14 digits; phones follow existing ten-digit validation.
- `CreateLabOrderDto`: `{ requestId: UUID, storeId?, addressId?, address?: LabAddressSnapshot, contact?: LabContactSnapshot, fulfillmentType, scheduledFor?, entries: [{ labPackageId, patients: [{ patientId?, addressId?, address?, details: LabPatientSnapshot }] }] }`.
- Cart limit: 1-50 distinct package entries, each with 1-5 patients, using existing report/upload bounds unchanged. Reject duplicate package IDs. Staff edits can replace an entry but must not introduce a second active entry for the same package.
- `LabOrderView`: `{ id: string, code, version, createdAt, contact, entries: LabOrderEntryView[], estimatedTotal: string, billedTotal: string, testEntryCount, patientTestCount, progress: { requested, confirmed, sampleCollected, reportReady, cancelled } }`. Count only entries visible to the caller; `patientTestCount` is explicitly patient-test combinations, not a claim of unique people.
- `LabOrderEntryView` extends existing authorized booking detail with `orderId`, package ID, patient/location snapshots, original/current estimated charges, and correction history references. Existing report and bill IDs remain unchanged.
- New parent IDs serialize as `order:<numericId>`; unlinked historical records serialize as `legacy:<bookingId>`. GET routes accept only these two validated formats, never arbitrary SQL fragments. Display code for new parents is `LO-<id padded to six digits>`; preserve existing LB codes inside child details.

### Task 1: Add parent, snapshots and immutable correction storage

**Files:** Create `backend/db/migrations/0102_grouped_lab_orders.sql` (recheck next free migration number before creation); modify `backend/api/src/db/schema/app-care.ts`, `backend/api/test/integration/create-test-db.ts`; create `backend/api/test/integration/lab-order.e2e-spec.ts`.

**Interfaces:** Produce `labOrder`, `labOrderRevision` and nullable `labBooking.labOrderId` schema exports. Parent stores member, UUID, request UUID/hash, version, contact/address snapshots and timestamps. Add snapshot JSONB columns on bookings/patients and an original estimated-unit-price column. Revision stores parent/child reference, actor, reason, before/after snapshots, timestamp, optional financial delta/resolution reference and preserved report/bill snapshots.

- [ ] Write schema tests: two same-member request UUIDs violate uniqueness; foreign keys reject orphan children; inserting an old-style child without an order still works; existing reports/bills keep their IDs.
- [ ] Run `npm test -- --runInBand test/integration/lab-order.e2e-spec.ts` from `backend/api`; verify the new schema assertions fail before implementation.
- [ ] Implement additive tables/columns/indexes and matching test DDL. Backfill exactly one parent per historical booking, with generated request UUID/hash and unchanged child/report/bill rows; use an idempotent backfill. Never merge by timestamp/member. Use DB checks for nonnegative prices/version and valid references. Do not run the migration against live data.
- [ ] Run the integration test plus `npm run typecheck`; verify schema/legacy cases pass. Validate migration syntax and rerun behavior against a disposable Postgres database if available; document pg-mem's inability to prove production locking/migration behavior.
- [ ] Commit only schema, migration and schema-test files in the root repository.

### Task 2: Submit the entire checkout atomically

**Files:** Create `backend/api/src/modules/care/lab-order.dto.ts`, `lab-order.service.ts`, `lab-booking-write.ts`; modify `dto.ts`, `booking.service.ts`, `member-booking.controller.ts`, `care.module.ts`; extend `lab-order.e2e-spec.ts` and existing `care.e2e-spec.ts`.

**Interfaces:** `LabOrderService.create(memberId: number, dto: CreateLabOrderDto): Promise<LabOrderView>`; `POST /v1/member/lab-orders`; legacy `POST /v1/member/lab-bookings` still returns its existing booking shape while creating one singleton parent. The service uses a transaction-scoped shared lab write helper; it must not call a helper that starts another transaction.

- [ ] Add tests with assertions `parents.length === 1`, `children.length === 2`, total equals live package prices times patient counts, and no rows remain when the second entry is unavailable. Test guest snapshots, absent addresses, wrong-owner IDs, duplicate packages, more than five patients and empty entries.
- [ ] Run the focused integration suite and confirm these routes/atomicity cases fail.
- [ ] Normalize fields and compute SHA-256 of a canonical request before writing. Under one transaction, claim `(memberId, requestId)` using a unique insert/conflict path; compare the saved original request hash on retries. Validate every entry/ownership/branch before committing children. Same UUID/different contents returns 409 `IDEMPOTENCY_CONFLICT`; same UUID/same contents returns the existing authorized order. Concurrent duplicate claims must resolve through the constraint, not a preflight lookup alone. Existing single-booking calls delegate to the same creation primitives without changing response shape.
- [ ] Run creation, rollback, sequential retry, changed-body retry and concurrent retry tests, then `care.e2e-spec.ts`. Verify concurrency on disposable real Postgres where pg-mem cannot simulate locks; do not claim production concurrency validation from pg-mem alone.
- [ ] Commit the tested API creation slice; retain existing non-lab booking methods unchanged.

### Task 3: Grouped reads with ownership and branch redaction

**Files:** Create `backend/api/src/modules/care/lab-order.read.ts`; modify `lab-order.service.ts`, `member-booking.controller.ts`, `staff-booking.controller.ts`, `booking.service.ts`; extend `lab-order.e2e-spec.ts`.

**Interfaces:** `listForMember(memberId): Promise<LabOrderView[]>`, `getForMember(memberId, id): Promise<LabOrderView>`, `listForStaff(actor): Promise<LabOrderView[]>`, `getForStaff(actor, id): Promise<LabOrderView>`. Add GET list/detail under member/staff `lab-orders`. Existing booking/report endpoints remain compatible.

- [ ] Write tests: two child bookings appear under one parent; two checkouts remain separate; foreign member receives 404; an unlinked legacy booking appears once as `legacy:<id>`; a split-branch order exposes only permitted entries/totals to branch staff; pharmacy nested DTOs omit clinical fields.
- [ ] Run focused tests and verify the new grouped read cases fail.
- [ ] Implement shared authorized child hydration, filtering before aggregation/serialization. Return current snapshots with permitted saved-data fallback only for legacy missing snapshots. Estimated total sums noncancelled entries; billed total uses actual linked bills and remains distinct. Preserve cancelled entries/history in details and expose per-status progress counts. Stable sorting is descending order timestamp then identity; child order follows creation ID.
- [ ] Run read/redaction, existing member report, branch technician and pharmacy tests; assert unauthorized child IDs cannot be fetched through the parent.
- [ ] Commit the grouped read API slice.

### Task 4: Full, audited admin editing and corrections

**Files:** Extend `lab-order.dto.ts`, `lab-order.service.ts`, `staff-booking.controller.ts`, existing child mutation methods in `booking.service.ts`; modify existing audit integration only as needed; extend `lab-order.e2e-spec.ts` and `care.e2e-spec.ts`.

**Interfaces:** `PATCH /v1/staff/lab-orders/:id` accepts `{ expectedVersion, reason, contact?, address?, entries?: EntryEdit[] }`. `EntryEdit` has child ID or new package ID, operation `add|update|cancel`, patient snapshots/references, service/branch, requested/scheduled dates, note and optional staff-priced unit price/discount. Full-order editing is Admin/Super Admin only. Preserve existing scoped lab-staff operational routes. Expose authorized revision history through grouped detail.

- [ ] Write table-driven tests covering every approved editing-matrix row. Assert snapshot edits leave `users`, saved patients and saved addresses unchanged; two edits at version N yield one success and one 409; adding/replacing/cancelling entries retains grouping; counts/prices recompute; blank guest details can be completed; edited contact phone never changes wallet OTP's account-phone target.
- [ ] Run failing edit tests. Add explicit finalized-report and paid-bill correction cases before their implementation.
- [ ] Implement row-locked, version-checked transactional edits with actor/reason/before/after revisions; increment parent version for every child write, including existing status/staff/report/bill routes. Use shared authorization and existing state-machine validations. Do not trust client-computed totals. Replacing an acted-on test cancels the old entry and adds a new one; never repoint paid bills/reports to a different package. Preserve source estimates separately from staff revisions.
- [ ] Implement finalized corrections: archive superseded report content in immutable revision storage before replacing/removing active pages; retain the existing requirement for an active report before REPORT_READY. Preserve settled bill/payment rows verbatim; store corrected charges, signed difference and reason as a pending billing correction visible in details. A pending correction is not a payment/refund or wallet transfer. Record any later external reconciliation reference as an audited resolution; existing financial collection/refund authorization remains mandatory. Revisions cannot be deleted through order editing. Test original paid amounts/report history remain recoverable.
- [ ] Run all matrix/version/audit cases, existing care billing/report tests and backend typecheck. Commit the tested editing slice, excluding unrelated wallet work already in the workspace.

### Task 5: Atomic cart submission in both Flutter clients

**Files (each project):** Create `lib/data/backend/lab_order_repository.dart`, `lib/module/labtest/lab_order_record.dart`; modify root `lib/data/backend/backend_order_repository.dart`, partner `lib/data/backend/order_repository.dart`, and each `lab_cart_service.dart`, `lab_checkout_screen.dart`, `lab_booking_placed_screen.dart`. Create each project's `test/lab_order_repository_test.dart`; extend existing checkout/cart tests.

**Interfaces:** Dart `Future<LabOrderRecord> placeLabOrder(LabOrderCheckout checkout)` returns server ID/code and children or throws a retryable exception. `LabOrderCheckout` matches Task 2 DTO; build JSON from each project's existing patient/address models without persisting guests. Introduce constructor-injected HTTP/care/address resolvers for repository tests, following existing backend repository test patterns.

- [ ] Write MockClient tests asserting one POST contains two entries and all real patient/address snapshots, while guests omit demographic keys. Assert server error throws instead of returning success. Widget assertions: failed submission retains cart; successful response clears it once and displays server code; retry sends the same request UUID.
- [ ] Run each project's targeted tests and confirm failure against existing loop-per-package behavior.
- [ ] Implement one whole-cart call and complete snapshot serialization. Retain the request UUID for an unchanged normalized checkout payload, including resolved server IDs; rotate it when payload changes. Generate UUIDs with existing utilities or `Random.secure` plus standard UUID bit formatting, without adding a dependency. Disable duplicate taps while awaiting response. Replace catch-and-skip behavior for lab checkout only; preserve non-lab repository contracts.
- [ ] Run repository, cart, picker, checkout and branch tests from each project's own directory. Test changing a patient/branch/address between attempts produces a new UUID. Confirm optional address, Skip and estimated wording remain intact.
- [ ] Commit separately in root and partner repositories, staging only each task's files.

### Task 6: One history order with nested test details in both clients

**Files (each project):** Modify `lab_order_record.dart`, `lab_order_repository.dart`, `my_lab_bookings_screen.dart`, `lab_report_screen.dart`; create `lab_order_details_screen.dart`. Extend `test/my_lab_bookings_test.dart`; create `test/lab_order_details_test.dart`.

**Interfaces:** `Future<List<LabOrderRecord>> fetchLabOrders()` and `Future<LabOrderRecord> fetchLabOrder(String id)` read Task 3 endpoints. Keep existing child report fetching by booking ID. Add a focused injectable order-loader override following existing test patterns rather than making tests call live HTTP.

- [ ] Write tests: two tests show one history card, opening it shows both patient selections and individual progress/report links; separate checkouts show separate cards; legacy singleton still opens; completed one-of-two does not label the whole order complete; refreshed staff edits update the displayed detail.
- [ ] Run failing history/detail tests in each project.
- [ ] Implement parent card/detail navigation and per-test sections, preserving report viewer ownership and polling behavior. Show test-entry counts and estimated/billed labels distinctly. Render optional snapshot fields only when supplied; never fabricate unknown ages or addresses.
- [ ] Run history/detail/report tests in both projects and confirm loading, empty, error/retry and cancellation states work.
- [ ] Commit each client's tested history slice separately.

### Task 7: One Admin Lab Orders row and full order editor

**Files:** Create `shieldweb/src/api/labOrders.ts`, `src/lib/labOrder.ts`, `src/components/labs/LabOrderModal.tsx`, `LabOrderEditor.tsx`; modify `src/types/index.ts`, `src/pages/LabOrdersPage.tsx`, `src/components/labs/LabBookingModal.tsx`; create `tests/labOrder.test.mjs`.

**Interfaces:** `listLabOrders(token)`, `getLabOrder(id, token)`, `updateLabOrder(id, input, token)` map Tasks 3/4 JSON to console types. Keep `memberPhone` for owning-account OTP separate from `contact.phone`. The parent modal opens the existing authorized child editor for operations/reports and a full Admin/Super Admin edit panel for snapshots/tests/charges.

- [ ] Write pure-helper tests asserting search finds nested test names, status filters match visible children, one group yields one row, monetary totals preserve paise, guest/legacy fields map correctly, and stale-version responses retain draft edits with a reload prompt.
- [ ] Run `node --experimental-strip-types --test --test-isolation=none tests/labOrder.test.mjs` from `shieldweb`; verify failure before helpers exist.
- [ ] Implement grouped list/detail and editing controls for every approved matrix row, including empty fields and confirmation of cancellation/replacement. Use existing form components, upload/report helpers, permission gates and loading/error patterns. Send expectedVersion/reason, reload current grouped detail after success, and show pending finalized-bill correction separately from the unchanged settled payment. Keep status/branch filters scoped and pharmacy details redacted. Keep the original child operational editor accessible inside the parent, rather than creating independent top-level order rows.
- [ ] Run helper tests, `npm run typecheck` and `npm run build`. Exercise in a local browser with fixtures: two tests in one row, nested edits survive reload, add/cancel test, role-restricted controls, contact corrections versus actual OTP account phone, and both desktop/mobile scrolling. Record browser validation that could not be performed.
- [ ] Commit only the admin grouped-order slice in `shieldweb`.

### Task 8: Compatibility, full verification and release documentation

**Files:** Update `docs/architecture.md`, `docs/database.md`, `docs/admin-console.md`, `docs/deployment.md`, `backend/docs/migration-plan.md`; update this plan's completed checkboxes with actual results.

**Interfaces:** No new API; verify all previous task contracts together. No live publication is implied by this task.

- [ ] Run backend `npm run typecheck`, `npm run build` and lab-order/care integration suites. Run relevant Flutter repository, checkout, history and report tests with `flutter test -j 2` in each app; run scoped analysis, then normal required checks. Run console tests/typecheck/build. Identify pre-existing failures using a baseline rather than modifying unrelated code.
- [ ] Build both Flutter web projects; build the root Android release only with the existing authorized signing/build workflow, without changing version numbers or accessing secrets unnecessarily. Exercise a disposable-backed two-test end-to-end checkout and admin edit where an isolated database/browser are available. Preserve evidence of permissions, retry/rollback and legacy compatibility checks.
- [ ] Document migration ordering, nullable legacy fallback, grouped API contracts, correction history, actual test limitations and rollback compatibility. Confirm removing new frontend code still leaves old single-booking routes functional; do not delete the additive schema during rollback.
- [ ] Request a final independent code review of the complete feature, fix material findings, rerun the affected checks and document remaining limitations.
- [ ] Commit the documentation/check results in the owning repository. Present the concrete migration/build/deployment artifacts for release review; apply live migration, production deploy and store upload only with release authorization and confirmed destinations.

## Self-review and execution handoff

Coverage: Tasks 1-3 implement grouping, compatibility and authorization; Task 4 covers every admin field and correction/audit requirement; Tasks 5-6 cover both clients and their failure/history behavior; Task 7 covers the grouped admin screen; Task 8 covers verification and release boundaries. Review Focus conditions map to explicit task tests. The original financial references and non-lab behavior remain unchanged throughout.

Execution is not started. Recommended method: **Native**, because DTOs, transactional creation, snapshots and UI edits depend on one another and all three worktrees contain unrelated changes to preserve. Implement task by task in this session, with a final independent review. The alternative is subagent-driven task execution with a fresh implementer/reviewer per task. User review of this plan and method selection are required before either starts.
