# SHIELD Product Requirements Document

**Status:** Baseline for the current repository  
**Scope:** Flutter member app and React operations console  
**Source of truth:** Verified code and schema in this repository; future changes require an ADR or an update to this document.

## 1. Product definition

SHIELD is a member health-commerce platform. Members discover health products and services, choose a local SHIELD store, manage patients and addresses, purchase products, submit prescriptions, book labs and appointments, use privilege wallets, earn rewards, and participate in referral or partner programmes. Staff operate fulfilment and care-service workflows through `shieldweb/`.

## 2. Users and actors

| Actor | Primary outcome | Product surface |
| --- | --- | --- |
| Member | Obtain products and health services with local-store support | Flutter app |
| Agent | Participate in field-sales/referral programme | Flutter partner flows; portal boundary is transitional |
| Investor | View or manage investment-plan content/requests | Flutter partner flows; portal boundary is transitional |
| Super Admin | Govern all operations and admins | Operations console |
| Admin | Operate catalogue, users, orders, prescriptions, plans, labs, appointments | Operations console |
| Pharmacy Admin | Work orders, prescriptions, and products for one branch | Operations console |
| Lab Admin | Work lab bookings and diagnostic packages | Operations console |
| Appointments Admin | Work clinic, tele, dental, and dietitian bookings | Operations console |

## 3. Product goals

- Make member sign-in and registration reliable on Android.
- Provide a complete path from discovery to fulfilment for products, prescriptions, labs, and appointments.
- Keep member wallet, rewards, referrals, and order state understandable and auditable.
- Give operations staff focused queues with role and branch boundaries.
- Keep the customer schema isolated from the Prisma-managed `public` schema.

## 4. Success measures

These measures are product targets, not currently instrumented metrics:

- Authentication completion rate and failed-OTP rate.
- Registration completion, including branch selection.
- Catalogue-to-cart and cart-to-order conversion.
- Prescription review turnaround and order conversion.
- Lab and appointment booking completion.
- Order status update latency and delivery completion.
- Admin queue resolution time and rejected unauthorized actions.
- Crash-free launches and successful database write rate.

## 5. Scope

### In scope and implemented

- Firebase phone authentication and session restoration.
- Member profile, branch, address, and patient management.
- Product catalogue, categories, search, cart, checkout, orders, and tracking.
- Prescription image upload and pharmacy review workflow.
- Lab packages/bookings and clinic, tele, dental, and dietitian appointments.
- Wallet/privilege plans, rewards, referrals, agent, and investor content.
- Staff console routes, role-based navigation, branch filtering, and operational queues.
- Neon `app` schema and database tooling.

### In scope but incomplete or transitional

- Production-grade admin authentication and authorization.
- Server-side API boundary for browser database access.
- Production Android signing.
- Final agent/investor portal boundary.
- Complete catalogue import/seed automation.
- Schema and migration drift resolution.

### Out of scope for this baseline

- A new backend service not represented in the repository.
- iOS release readiness; Firebase setup marks it as pending.
- Public deployment of the current browser-direct admin console.
- Replacing the Prisma-managed `public` schema.

## 6. Core acceptance outcomes

- A member can authenticate, select a branch, add an item, complete checkout, and see order tracking.
- A member can upload a prescription tied to a patient and branch and see its lifecycle.
- A staff operator can update the queues allowed by their role, with pharmacy rows restricted to its branch.
- A destructive database operation cannot be treated as a normal development command.
- A release build has documented Firebase configuration, Neon configuration, and production signing controls.

## 7. Product risks

- Current admin credentials are bundled in client JavaScript.
- Current admin database access is direct from the browser.
- Current release APK signing uses the debug key.
- Health and prescription data require strong privacy, auditing, and least privilege.
- Agent/investor routing and schema roles need a final product decision.

See [FRD](frd.md), [TRD](trd.md), and [Security](security.md) for implementation detail and release blockers.
