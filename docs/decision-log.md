# Decision Log

This index records decisions that materially affect product behavior, architecture, schema, security, or operations. Use [ADR Template](adr-template.md) for each new decision.

## Existing decisions documented in code

| Decision | Evidence | Implication |
| --- | --- | --- |
| Keep customer tables in a separate `app` schema | `backend/db/app_schema.sql`, `APP_SCHEMA.md` | App schema recreation must not touch `public` |
| Use HTTPS for member Neon writes | `lib/data/neon/neon_http.dart`, `backend/README.md` | Avoid Windows command-line truncation of URLs containing `&` |
| Warm catalogue/reviews without blocking launch | `lib/main.dart` | Screens must handle loading and fallback states |
| Pharmacy access carries a branch code | `shieldweb/src/config/permissions.ts` | Final enforcement must move server-side |
| Current admin login is client-side static credentials | `shieldweb/src/config/admins.ts`, `AuthContext.tsx` | Internal-only; production remediation required |
| An app-submitted agent recruitment files an `app.agent_request` (PENDING) rather than writing `app.agent` directly; the recruit's slot shows locked (name + reference code, no chevron) until an admin approves or rejects in the console | `AgentService.registerAgent`/`AgentRepository.insertAgentRequest` (`shield/`, `shield agent_invester/`), `agent_team_tree_screen.dart`, `shieldweb/src/api/agents.ts` | A pending recruit cannot itself recruit; `app.agent` only ever holds admin-confirmed agents |
| Every agent below national — however created — must occupy a real named geo slot (`app.agent.area_id`, resolved through `region→ward`), not a free-text area | `AgentService.registerAgent` region-slot guard, `shieldweb/src/api/geo.ts` + `UserDetailPage` convert-to-agent picker | Admin-created agents that predate this (webapp's old free-text "area" box) can exist with no `area_id` and will not lock into a team-tree slot; not retroactively fixed |

## Open decisions

- Replace static admin credentials with managed/server-side authentication.
- Put admin Neon queries behind a trusted API.
- Reconcile `admin` role with `app.admin_role` enum.
- Reconcile customer-review video migration and DDL drift.
- Decide the final agent/investor portal boundary.
- Configure production Android signing and release infrastructure.
- Fold `backend/db/migrations/0014_geo_hierarchy.sql`..`0017_agent_area_id.sql` into `backend/db/app_schema.sql` — a fresh `apply_app_schema.dart --yes` currently omits the geo tables and `agent.area_id` (see [ERD known drift](erd.md#5-known-erd-drift)).
- `AgentRepository.ensureNationalRow` (Flutter) has no "only one national agent" guard, unlike the console's `approveAgent`/`convertToAgent`; the live database currently has two `NATIONAL`-level `app.agent` rows. Decide how a device that has never seen an existing national agent's phone should behave, and whether to reconcile the existing duplicate.
