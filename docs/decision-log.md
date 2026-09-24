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
| An app-submitted agent recruitment files an `app.agent_request` (PENDING) rather than writing `app.agent` directly; the recruit's slot shows locked (name + reference code, lock icon in place of a detail screen) until an admin approves or rejects in the console. The chevron itself is not part of that lock — it still fans out the tier the recruit would head, same as an approved agent's | `AgentService.registerAgent`/`AgentRepository.insertAgentRequest` (`shield/`, `shield agent_invester/`), `agent_team_tree_screen.dart` (`_MindPill.locked`, `canExpand`), `shieldweb/src/api/agents.ts` | A pending recruit cannot itself recruit; `app.agent` only ever holds admin-confirmed agents. A recruiter can still preview their whole prospective team shape before anyone is confirmed |
| Every agent below national — however created — must occupy a real named geo slot (`app.agent.area_id`, resolved through `region→ward`), not a free-text area | `AgentService.registerAgent` region-slot guard, `shieldweb/src/api/geo.ts` + `UserDetailPage` convert-to-agent picker | Admin-created agents that predate this (webapp's old free-text "area" box) can exist with no `area_id` and will not lock into a team-tree slot; not retroactively fixed |
| The team tree (`agent_team_tree_screen.dart`, both `shield/` and `shield agent_invester/`) lands the camera on the first *real, registered* agent inside a tier it just opened, if one exists, rather than centring the tapped card or defaulting to the tier's own start. Falls back to the tier's own start (left edge, not centre) only when every seat in it is still open | `AgentTeamTreeScreen._firstRealAgentUnder`, `_targetXFor`, `test/agent_team_tree_lands_on_real_agent_test.dart`, `test/agent_team_tree_reachable_from_start_test.dart` | A named tier wide enough to spill past the viewport (a Kerala district can hold 17 assembly seats) no longer requires already knowing to pan sideways to find a specific registered agent buried in it; centring the tapped card only ever surfaced whichever siblings sat nearest its middle |
| `_expanded` (which branches the team tree currently has open) is reconciled against the agent roster every time it changes, and the camera re-follows whatever got promoted. An open seat's id is derived from its *parent's* current id, so a registration completed without navigating away from "My Team" — turning an ancestor seat from open to a real agent — silently orphaned every descendant seat's old id unless this ran | `AgentTeamTreeScreen._onAgentsChanged`, `_currentIdForGeoNode`, `test/agent_team_tree_survives_promotion_test.dart`, `test/agent_team_tree_follows_promotion_test.dart` | Without this, registering an agent into an already-drilled-into branch reads as the whole branch silently collapsing, and re-tapping the (secretly already-open) arrow closes it instead of opening it |
| The team tree's chevron button keeps a small 26px visible circle but tap-targets a 48x48 area centred on it (Material's own minimum touch-target guidance), instead of the circle itself being the whole hit area | `_CaretButton` (`agent_team_tree_screen.dart`) | The most-reported "tapping the arrow does nothing" case reached the arrow via a manual pan just beforehand, when `InteractiveViewer`'s own pan/scale gesture recognizer is still active and most likely to contest a small target instead of letting a plain tap through — not reproducible with `flutter test`'s synthetic taps, only on a real touchscreen |

## Open decisions

- Replace static admin credentials with managed/server-side authentication.
- Put admin Neon queries behind a trusted API.
- Reconcile `admin` role with `app.admin_role` enum.
- Reconcile customer-review video migration and DDL drift.
- Decide the final agent/investor portal boundary.
- Configure production Android signing and release infrastructure.
- Fold `backend/db/migrations/0014_geo_hierarchy.sql`..`0017_agent_area_id.sql` into `backend/db/app_schema.sql` — a fresh `apply_app_schema.dart --yes` currently omits the geo tables and `agent.area_id` (see [ERD known drift](erd.md#5-known-erd-drift)).
- `AgentRepository.ensureNationalRow` (Flutter) has no "only one national agent" guard, unlike the console's `approveAgent`/`convertToAgent`; the live database currently has two `NATIONAL`-level `app.agent` rows. Decide how a device that has never seen an existing national agent's phone should behave, and whether to reconcile the existing duplicate.
- PAR-AGT-04's "refusing a slot another live recruit already holds" guard checks confirmed `app.agent` rows; the live `app.agent_request` table currently holds two separate PENDING requests for the same state seat (Kerala), both named "Althaf". Decide whether the guard should also cover other still-pending requests for the same `requested_area_id`, and whether to clean up the existing duplicate.
