# SHIELD UI/UX Specification

**Status:** Current design baseline derived from Flutter theme/widgets and the admin console styles. This document guides additions; it does not replace component code.

## 1. Experience principles

- Make health and fulfilment status scannable.
- Keep the next meaningful action obvious.
- Preserve context when moving between tabs, drawers, detail pages, and queues.
- Treat prescription, patient, payment, and address actions as confirmation-sensitive.
- Show service availability and failure states without hiding data or pretending a write succeeded.

## 2. Member app information architecture

- Persistent shell: Home, Health/Labs, Clinics, Orders, Account.
- Drawer: account summary, cart/wallet/rewards shortcuts, browse links, services, referrals, orders, and account.
- Health section: labs, packages, clinics, and dietitian-related flows.
- Orders: history, detail, and tracking.
- Account: profile, patients, addresses, wallet, rewards, referrals, and partner features.

## 3. Admin console information architecture

- Sidebar navigation follows `MODULES` in `shieldweb/src/config/permissions.ts`.
- Dashboard is the role-specific landing page.
- Operational pages use tables, filters, detail views, explicit status transitions, and no-access states.
- Pharmacy pages visibly preserve branch context; cross-branch users can inspect broader data according to role.

## 4. Visual system

Flutter uses Material 3 with the SHIELD logo-derived blue/green palette in `lib/theme/app_colors.dart`, plus distinct category, wallet, reward, and status colors. Admin uses Tailwind tokens and the existing Inter font setup in `shieldweb/src/index.css`.

Do not introduce a new palette or typography system for an isolated feature. Extend the existing tokens and verify text contrast for normal, disabled, error, and selected states.

## 5. Required states

Every screen that reads or writes remote data must define:

- Initial/loading state.
- Empty state with a useful next action.
- Success state.
- Recoverable error with retry.
- Validation error at the field or action level.
- Unauthorized/no-access state.
- Stale or unavailable data indication where freshness matters.
- Destructive-action confirmation for cancellation, rejection, deletion, or schema operations.

## 6. Interaction requirements

- Use familiar icons with accessible labels and tooltips where the icon is not self-evident.
- Keep button dimensions stable when labels, errors, or loading indicators change.
- Use confirmation before placing an order, approving/rejecting an activation, or changing a status.
- Preserve entered form data after recoverable failures.
- Avoid exposing raw SQL, credentials, stack traces, or private health data in UI errors.
- Support keyboard navigation in the admin console and adequate tap targets in Flutter.

## 7. Content and accessibility

Use plain, action-oriented labels. Define status text consistently across member and admin surfaces. Do not rely on color alone for order, prescription, lab, appointment, or activation state. Provide semantics for product images, prescription images, icons, form fields, and loading/error announcements.

## 8. UX acceptance review

Before merging a user-facing change, review at narrow and wide sizes, loading/empty/error/success states, keyboard or screen-reader semantics where applicable, and the complete workflow from the preceding screen. Add a focused widget test for important state transitions.
