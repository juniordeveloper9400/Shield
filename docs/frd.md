# SHIELD Functional Requirements Document

**Status:** Current-state functional baseline  
**Requirement IDs:** `AUTH`, `REG`, `CAT`, `COM`, `RX`, `CARE`, `WAL`, `REF`, `OPS`, `DATA`

## 1. Authentication and identity

| ID | Requirement | Acceptance criteria | Status |
| --- | --- | --- | --- |
| AUTH-01 | Initialize Firebase before rendering the app | App remains reachable when Firebase is unavailable and reports auth unavailability instead of white-screening | Implemented |
| AUTH-02 | Authenticate members with phone OTP | Valid phone receives OTP; valid code creates/restores a Firebase session | Implemented |
| AUTH-03 | Persist member identity | Member data is upserted/touched in `app.users` without blocking launch on a transient write failure | Implemented |
| AUTH-04 | Resolve member personas | Agent/investor status is checked after session restoration and routes to the appropriate web-only state | Implemented/transitional |
| AUTH-05 | Enforce staff authentication server-side | Credentials, sessions, role checks, and branch checks are not recoverable from browser JavaScript | Not implemented; release blocker |

## 2. Registration and branch selection

- `REG-01`: collect the required member profile fields and validate them.
- `REG-02`: allow branch discovery by directory, pincode, or device location.
- `REG-03`: persist the selected `home_store_id`.
- `REG-04`: provide clear permission-denied and unavailable-location states.
- `REG-05`: keep member registration writes on the HTTPS Neon path.

## 3. Catalogue and commerce

- `CAT-01`: display banners, promotions, categories, products, details, FAQs, and reviews.
- `CAT-02`: support category navigation and product search.
- `COM-01`: add, update, and remove cart lines with quantity validation.
- `COM-02`: select address, patient, branch context, and payment method at checkout.
- `COM-03`: create an order with line items, MRP total, paid total, and billing wallet context.
- `COM-04`: show order history and status tracking.
- `COM-05`: prevent checkout with invalid, empty, or unavailable cart state.

## 4. Prescriptions

- `RX-01`: upload a prescription image and resize it before persistence.
- `RX-02`: associate the prescription with a member, patient, and store.
- `RX-03`: allow pharmacy staff to review the image and record medicine/intake details.
- `RX-04`: represent the lifecycle `AWAITING_REVIEW -> READ -> IN_CART -> ORDERED`.
- `RX-05`: expose approval/rejection state and reviewer notes where applicable.

## 5. Health services

- `CARE-01`: browse lab packages and submit bookings.
- `CARE-02`: attach one or more patients to a lab booking.
- `CARE-03`: update lab status through requested, confirmed, sample collected, and report ready states.
- `CARE-04`: browse clinics, doctors, dietitians, and appointment types.
- `CARE-05`: create and update clinic, tele, dental, and dietitian appointments.

## 6. Wallet, rewards, and referrals

- `WAL-01`: display wallet balance, privilege cards, tiers, loads, and ledger entries.
- `WAL-02`: submit privilege-plan activation for review.
- `WAL-03`: approve/reject activations with a reviewer note and corresponding ledger entries.
- `REF-01`: display referral code and referral progress.
- `REF-02`: record referral states and reward ledger entries without presenting derived earnings as stored facts.

## 7. Operations console

- `OPS-01`: expose route modules for dashboard, stores, products, orders, prescriptions, activations, labs, appointments, users, and admins.
- `OPS-02`: restrict module navigation by role.
- `OPS-03`: restrict pharmacy data to its `storeCode`.
- `OPS-04`: allow only `superadmin` and `admin` to review privilege activations.
- `OPS-05`: support empty, loading, error, no-access, and direct-route-refresh states.
- `OPS-06`: move all authorization decisions to a trusted server before production.

## 8. Data and operational requirements

- `DATA-01`: use the `app` schema for customer data and do not mutate `public` through app schema tools.
- `DATA-02`: make destructive schema commands explicit and reviewable.
- `DATA-03`: preserve auditability for order, prescription, activation, wallet, and role changes.
- `DATA-04`: keep health data and prescription images out of logs and test fixtures.

## 9. Error-state requirements

Every network-backed workflow must support loading, success, empty, retryable failure, validation failure, unauthorized/no-access, and offline or unavailable-service states where the platform can detect them.
