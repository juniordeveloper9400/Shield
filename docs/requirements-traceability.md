# Requirements Traceability Matrix

**Purpose:** Keep product requirements connected to implementation, data, tests, and release evidence.

| Requirement family | Primary implementation | Data surface | Test/evidence | Current status |
| --- | --- | --- | --- | --- |
| AUTH | `lib/module/auth/`, `lib/screens/root_screen.dart` | `users`, Firebase identity | `test/auth_test.dart`, `test/persona_gate_test.dart` | Member auth implemented; admin auth blocker |
| REG | `lib/module/registration/` | `users`, `shield_store`, addresses | registration/location tests | Implemented |
| CAT | catalogue/category/product/search modules | product/category/content tables | catalogue/category/product/search tests | Implemented |
| COM | cart/checkout/orders modules | cart/order/payment/tracking tables | cart/checkout/order tests | Implemented |
| RX | prescription module and admin prescription pages | prescription/approval tables | prescription/upload tests | Implemented with operational review flow |
| CARE | labtest/appointment/dietitian modules | lab/clinic/appointment tables | lab/clinic/dietitian tests | Implemented |
| WAL | wallet/privilege modules and admin activations | wallet/card/entry/tier tables | investment/privilege/earnings tests | Implemented; authorization hardening needed |
| REF | refer/rewards modules | referral/level/points tables | refer/rewards tests | Implemented |
| OPS | `shieldweb/src/App.tsx`, pages, APIs, permissions | shared `app` tables, intended `admin_user` | typecheck/build; no React test suite found | Internal-only current state |
| DATA | `backend/db/` tools and DDL | `app` and `public` schemas | introspection/ping/manual review | Implemented with known drift |

## Update rule

For a new feature, add a row or extend the relevant family with: requirement ID, source path, schema entity, focused test, and release evidence. A feature is not complete when only the UI exists.
