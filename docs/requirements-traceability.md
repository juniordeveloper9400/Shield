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
| AGT | `lib/module/agent/` (`shield/` and `shield agent_invester/`), `shieldweb/src/pages/UserDetailPage.tsx` + `AgentApprovalsPage.tsx`/`AgentApprovalDetailPage.tsx` | `agent`, `agent_request`, `region`/`state`/`district`/`assembly`/`lsgd`/`ward` | `test/agent_portal_test.dart` (root app only; `shield agent_invester/` and `shieldweb` have no discovered test suite for this) | Implemented; `app_schema.sql` missing geo tables/`area_id` (see ERD drift); duplicate-national-agent data issue open (decision log) |
| OPS | `shieldweb/src/App.tsx`, pages, APIs, permissions | shared `app` tables, intended `admin_user` | typecheck/build; no React test suite found | Internal-only current state |
| DATA | `backend/db/` tools and DDL | `app` and `public` schemas | introspection/ping/manual review | Implemented with known drift |

## Update rule

For a new feature, add a row or extend the relevant family with: requirement ID, source path, schema entity, focused test, and release evidence. A feature is not complete when only the UI exists.
