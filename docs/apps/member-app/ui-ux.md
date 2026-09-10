# Member App UI/UX

## Navigation

The persistent shell exposes Home, Health/Labs, Clinics, Orders, and Account. The drawer provides account summary, cart/wallet/reward shortcuts, browse links, services, referrals, orders, and account actions.

## Visual language

Use Material 3 and the SHIELD blue/green palette defined in `lib/theme/app_colors.dart`. Category panels, privilege cards, rewards, and status colors have distinct semantic roles; do not repurpose them casually.

## Workflow principles

- Keep branch, patient, address, and payment context visible during checkout.
- Preserve tab and scroll state where expected.
- Confirm order placement, activation decisions, cancellations, and destructive actions.
- Never imply a Neon write succeeded when configuration or connectivity is missing.
- Provide accessible labels for product, review, and prescription media.

## Required states

Splash, signed out, Firebase unavailable, loading, empty catalogue/cart/order, validation failure, retryable database failure, successful submission, and converted-persona web-access states must be designed and tested.
