# Admin Console FRD

| ID | Requirement | Evidence/status |
| --- | --- | --- |
| ADM-AUTH-01 | Present login/logout and restore a browser session | `AuthContext`; client-side current state |
| ADM-AUTH-02 | Enforce role/module permissions and branch scope | `permissions.ts`; client-side current state |
| ADM-AUTH-03 | Replace bundled credentials and browser authorization with server-side auth | Required before production |
| ADM-OPS-01 | Provide dashboard and role landing paths | `App.tsx`, dashboard page |
| ADM-OPS-02 | Manage stores and catalogue | stores/products pages and APIs |
| ADM-OPS-03 | Manage order and prescription queues | orders/prescriptions pages and APIs |
| ADM-OPS-04 | Review privilege activations | activations pages/API; admin and superadmin review |
| ADM-CARE-01 | Manage lab packages/bookings and appointments | lab/appointment pages/APIs |
| ADM-MEM-01 | Inspect users and partner conversion state | users pages/APIs |
| ADM-AGT-01 | Review, approve, or reject an app-submitted agent registration request | `AgentApprovalsPage`, `AgentApprovalDetailPage`, `src/api/agents.ts` |
| ADM-AGT-02 | Require a real named geo slot (region…ward) for every agent below national, whether approved from a request or converted directly from a user | `src/api/geo.ts`, `UserDetailPage` convert-to-agent picker, `convertToAgent`/`approveAgent` slot-taken checks |
| ADM-SEC-01 | Enforce authorization on a trusted server for every query/mutation | Required before public deployment |

All routes require loading, empty, error, no-access, and direct-refresh behavior. Status transitions must reject invalid state changes and surface failures without losing operator context.
