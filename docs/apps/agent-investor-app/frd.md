# Agent / Investor App FRD

| ID | Requirement | Evidence/status |
| --- | --- | --- |
| PAR-AUTH-01 | Restore member phone session before access | `module/auth/`, `screens/root_screen.dart` |
| PAR-PER-01 | Resolve agent/investor persona on sign-in and app resume | `module/persona/persona_service.dart` |
| PAR-PER-02 | Clear persona state on sign-out or member switch | `PersonaService.clear()` |
| PAR-AGT-01 | Present agent identity, level, parent, area, sales, earnings, and redeemed values | `module/agent/` implemented; earnings/redeemed read zero while `approvalStatus` is pending (`Agent.displayEarned`) |
| PAR-AGT-02 | Recruit a lower-tier agent: verify their phone over a real Firebase OTP (secondary app, never signs the recruiter out), then file the registration for admin review rather than creating them directly | `agent_otp_verifier.dart` (secondary Firebase app), `AgentService.registerAgent`, `AgentRepository.insertAgentRequest` → `app.agent_request` |
| PAR-AGT-03 | Show a recruit awaiting approval as a locked position in the team tree — name and reference code, no chevron to recruit under them — until an admin approves or rejects | `agent_team_tree_screen.dart` (`_MindPill.locked`, `agent.isApproved` gates `canExpand`), `AgentApprovalStatus.pending` |
| PAR-AGT-04 | Require a named geo slot (region/state/district/assembly/lsgd/ward) for a recruit at that level, refusing a slot another live recruit already holds | `AgentService.registerAgent` (region-slot guard, one-agent-per-slot check), `AgentGeo`/`agent_geo_repository.dart` |
| PAR-INV-01 | Present investor identity, store, units, price, plan, and ROI values | `module/investor/` present; final workflow needs validation |
| PAR-ROUTE-01 | Send converted Android users to web-access state | `RootScreen`, `WebAccessScreen` |
| PAR-ROUTE-02 | Allow web persona cards while preserving member shell | `RootScreen`, home/persona services |
| PAR-SEC-01 | Enforce partner authorization server-side | Required; current persona read is not sufficient |

The partner requirements must be revised after the final portal-boundary decision. The agent-recruitment rows (PAR-AGT-02..04) hold regardless of that decision — the approval queue and geo-slot rules are shared with the root app (`lib/module/agent/`) and the admin console (see [Admin Console FRD](../admin-console/frd.md) ADM-AGT-01/02).
