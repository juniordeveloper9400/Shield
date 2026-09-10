# Agent / Investor App FRD

| ID | Requirement | Evidence/status |
| --- | --- | --- |
| PAR-AUTH-01 | Restore member phone session before access | `module/auth/`, `screens/root_screen.dart` |
| PAR-PER-01 | Resolve agent/investor persona on sign-in and app resume | `module/persona/persona_service.dart` |
| PAR-PER-02 | Clear persona state on sign-out or member switch | `PersonaService.clear()` |
| PAR-AGT-01 | Present agent identity, level, parent, area, sales, earnings, and redeemed values | `module/agent/` present; final workflow needs validation |
| PAR-INV-01 | Present investor identity, store, units, price, plan, and ROI values | `module/investor/` present; final workflow needs validation |
| PAR-ROUTE-01 | Send converted Android users to web-access state | `RootScreen`, `WebAccessScreen` |
| PAR-ROUTE-02 | Allow web persona cards while preserving member shell | `RootScreen`, home/persona services |
| PAR-SEC-01 | Enforce partner authorization server-side | Required; current persona read is not sufficient |

The partner requirements must be revised after the final portal-boundary decision.
