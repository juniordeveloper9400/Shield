# One lab order per checkout

Status: written design approved by the user on 2026-10-17, including full admin editing. Implementation planning follows. No implementation or migration has been run for this feature.

## Outcome and scope

Submitting a lab cart with two tests creates one lab order containing two test entries. Both the root member app and the separate `shield agent_invester` web app show one confirmation and one entry in booking history. Admin Lab Orders shows one row for the checkout; opening it shows each test and its own patients, progress, reports and charges.

This applies only to labs. Medicine orders, prescriptions, appointments, existing wallet collection rules and unrelated admin features retain their current behavior. Two separate checkouts by the same user remain two separate orders.

## Current behavior

Both Flutter order repositories loop over cart packages and POST each separately to `/v1/member/lab-bookings`. `BookingService.bookLabTest` writes one `app.lab_booking`, its patient rows and a package-based price. Admin `LabOrdersPage` lists these individual bookings. Reports, technician assignment and lab bills reference individual booking IDs. Client submission currently catches individual failures, which can leave a partially submitted basket.

## Selected approach

Add a parent lab order and retain existing lab bookings as its test entries. This preserves each test's clinical workflow and financial references while establishing a reliable checkout boundary. Merely grouping records by member or timestamp could combine unrelated checkouts and cannot guarantee that all tests were accepted together. Replacing the existing booking/report/bill model wholesale would introduce unnecessary migration risk.

## Storage and compatibility

Add `app.lab_order` with an identity ID, unique public UUID, member ID, client request UUID, creation timestamp and an index supporting member history. Enforce uniqueness on `(member_id, request_uuid)`. Derive the public order code from the server identity; clients must not invent a success code.

Add indexed nullable `lab_booking.lab_order_id` referencing the parent. Existing package, patient, status, store, scheduling, report and bill columns remain on the child. Order totals and progress are calculated from the children, avoiding a second mutable copy of those values.

The additive migration backfills one parent per existing booking; historical checkouts must not be guessed from matching times or members. Keep the FK nullable for a deployment overlap. Grouped reads also include any unlinked legacy booking as a standalone order with a distinct legacy identifier. The legacy single-booking endpoint remains supported and creates a singleton parent once the new backend is deployed.

## Atomic submission and retries

Add `POST /v1/member/lab-orders` accepting a request UUID, shared branch, collection method, optional shared address/date, and a nonempty list of test entries. Each entry has its package ID and patient array, including optional per-patient addresses. Apply bounded array limits using the existing five-patient maximum; reject an empty cart or empty patient list. Reject duplicate package entries rather than silently double-charging.

Validate ownership of every supplied patient and address, eligibility of the branch, and availability of every package. Compute all prices from current server catalogue data. Create the parent and all child bookings/patients inside one transaction. Any invalid test or failed write rolls back the complete checkout.

Repeating an accepted request UUID returns the same order and children. Bind the UUID to a normalized request fingerprint and reject reuse with different contents. Concurrent duplicate requests must also produce exactly one parent and one set of children. A database uniqueness constraint is required; a preliminary application lookup alone is insufficient.

Both clients submit one request for the whole cart and retain its request UUID across network retries. A changed cart or checkout selection gets a new UUID. On failure, show a retryable error and retain the cart. Clear it only after the server confirms the complete order. Keep Skip patient details, optional addresses and the estimated-charge wording. Booking-only patient labels continue to omit invented ages and patient IDs.

## Member experience

Add grouped member list/detail responses under `/v1/member/lab-orders`. A history card shows the order code, date, number of test entries and estimated total. Its details show all tests and the selected patients, with the existing report viewer and per-test status available for each entry. Counts distinguish tests from patient-test combinations. The existing checkout card remains a booking summary, with Estimated total and the lab's final-charge notice; the removed Bill summary card is not restored.

## Admin experience and authorization

Add grouped staff list/detail responses under `/v1/staff/lab-orders`. Admin Lab Orders displays one row per checkout, with member, branch, test count, combined amount and progress counts. Search matches order code, permitted member information and test names. Status filters match an order when at least one visible child matches. Opening a row shows the order header and a separate section for every test; selecting a test reuses the existing booking editor for technician, scheduling, patient details, notes, status, reports and billing.

Retain existing backend role and store authorization. Pharmacy users retain their existing clinical-data redaction. Group counts, totals and nested child responses must not reveal entries that a role cannot view. Fetching a parent ID cannot bypass authorization on its children. If staff move an individual test to another eligible branch using the existing editor, grouping remains intact and branch-scoped staff see only their permitted entries; unscoped admin roles see the full order with branch labels per entry.

Keep operational statuses per test. Show completed/total and canceled counts at order level; a single ready report must not mark all tests ready. Existing bills, OTP collection, wallet debits, refunds and report ownership continue to reference the individual test entry. This feature does not create a new consolidated financial invoice.

## Full admin editing of user-entered lab details

Admin and Super Admin must be able to correct every user-entered detail from the grouped lab order. The current modal already edits branch, collection address, patient names/ages, schedule and notes, but that is not complete coverage. Build an explicit editor rather than leaving the remaining details as read-only rows.

| Section | Editable information |
| --- | --- |
| Booking contact | Booking contact name, phone and collection-address contact name/phone |
| Tests | Add another eligible test/package, replace a selected test, cancel/remove a test entry from the active order, and change each test's patient selection/count |
| Patient details | Name, phone, date of birth or age, gender, relationship and optional ABHA; fill in details skipped at checkout, add patients or remove patients from a test |
| Service and branch | Home collection/store visit and eligible branch, using existing staff/store authorization |
| Collection location | Shared and per-patient collection address, including address lines, locality, landmark, pincode and receiver/contact details; an address can remain absent |
| Dates and instructions | Customer-requested visit/collection date, lab schedule, assigned technician and order/test notes |
| Charges | Unit price and applicable discounts through the staff billing workflow, with line/order totals recomputed from patient counts; the lab-confirmed amount remains distinct from the checkout estimate |
| Progress and reports | Existing status transitions, report attachments and report notes, exposed within each test entry |

Store editable booking-contact, patient and collection-location snapshots so that changing one lab order does not silently update `app.users`, saved patients, saved addresses or unrelated orders. Extend submission and detail DTOs to carry all supplied patient/address fields; the current name/age-only booking representation cannot support editing or displaying data it never saved. Snapshot fields are optional for old records and skipped details. Where an old booking has only a saved-patient/address reference, resolve the existing permitted data for display; an edit creates an order-specific snapshot. Never invent missing historical values.

An edited contact phone is an order contact, not a change to the owning member's identity. Wallet collection authentication continues to use the actual owning account's verified phone, not an editable display/contact number. Keep owner IDs, order IDs and original creation/audit timestamps server-controlled because the user did not enter them.

Save related changes atomically, validate field formats and limits, and record actor, timestamp, reason and before/after values in the existing staff-audit system. Show successful changes in member order details in both clients. Preserve authorization and clinical workflow checks: editing a progress label cannot bypass required staff assignment or report requirements. Corrections to a finalized report or settled bill use a recorded correction/adjustment path; retain the prior report and financial audit history. Removing an already acted-on test cancels that entry rather than deleting its reports, bill or payment records. The order detail must make every supported edit discoverable, including fields with no value yet.

## Validation and rollout

Backend integration coverage: two tests create one parent/two children; invalid second test rolls back everything; retries and concurrent duplicates do not duplicate charges; changed payload with the same request UUID is rejected; guest patients and absent addresses work; prices are server-derived; member ownership, staff branch scoping and pharmacy redaction hold; old singleton bookings remain readable; per-test reports and bills remain linked correctly.

Flutter coverage in each project: two cart tests produce one checkout request and confirmation; both tests appear inside one history order; different patient selections are retained; optional details/addresses still work; errors preserve the cart; retries reuse the request UUID. Admin coverage: one order row expands to two test entries, filtering/search and permissions remain correct, and an individual test can still be managed.

Admin editing coverage must exercise each row of the editing matrix, completion of skipped patient fields, adding/replacing/removing a test, recomputed counts/totals, persistence across reload and visibility in both member clients. Verify that booking contact/patient/address edits do not mutate the account's saved records, edited contact phones cannot redirect wallet OTPs, paid-bill/report corrections retain history, audit entries identify the staff actor, and unauthorized roles/stores cannot perform edits.

Apply the additive migration, deploy the compatible backend, deploy the admin console and agent/investor web app, then release the new Android build. Verify a real two-test checkout in each client and confirm one admin order with both entries. Preserve compatibility routes during rollout. Do not infer historical grouping or delete existing clinical/financial records. Live migration and production deployment are separate release actions, not completed by preparing this design.
