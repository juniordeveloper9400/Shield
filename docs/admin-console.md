# Admin Console

`shieldweb/` is a React 18 + TypeScript + Vite + Tailwind operations console. Its entry point is `shieldweb/src/main.tsx`; routes are defined in `shieldweb/src/App.tsx`.

## Routes

The current console includes login, dashboard, stores, products, orders, prescriptions, activations, lab orders, lab tests, appointments, users, user details, admins, agent approvals, and no-access views. Parameterized routes include activation, user/member detail, and agent approval detail pages.

### Agent approval queue

`AgentApprovalsPage` lists every `app.agent_request` still `PENDING` (`src/api/agents.ts listPendingAgents`); `AgentApprovalDetailPage` confirms the level/parent/area and calls `approveAgent` (inserts the real `app.agent` row, links `agent_request.agent_id`, marks the request `APPROVED`) or `rejectAgent` (marks `REJECTED` with a reason, no `agent` row — the app's team tree unlocks the slot). These requests come from the app's own OTP-verified registration flow (`shield/` and `shield agent_invester/`), which never writes `app.agent` directly.

A user can also be made an agent directly, bypassing the request queue: `UserDetailPage`'s "Convert to agent" (`convertToAgent` in `src/api/users.ts`) creates the `app.agent` row on the spot. Every level below national must pick a real named slot — a cascading region → state → district → assembly → lsgd → ward picker (`src/api/geo.ts`, reading `app.region`/`state`/`district`/`assembly`/`lsgd`/`ward`) sized to however many tiers that level needs — so the new agent gets a real `area_id` and locks into a slot in the team tree instead of floating with no area. A slot already held by an approved agent is refused, same as the request-approval path.

## Roles

Permission definitions and landing paths live in `shieldweb/src/config/permissions.ts`. Current roles are `superadmin`, `admin`, `pharmacy`, `lab`, and `appointments`; pharmacy access is scoped by `storeCode`.

## Current authentication implementation

The code currently authenticates against the credential list in `shieldweb/src/config/admins.ts` and persists only the login id in browser `localStorage` via `AuthContext`. It does not currently use Firebase Email/Password or resolve admin identity from `app.admin_user`, despite older README text saying otherwise. Do not copy or publish the credentials from that source file.

This must be replaced with a server-side authentication and authorization boundary before public or high-trust deployment. See [Security](security.md).

## Data access

Each `shieldweb/src/api/*.ts` module is a thin query layer over Neon. Pages call API modules rather than embedding SQL. The browser bundle currently receives the database URL, so this console should be treated as internal-only until queries move behind a server API.

## Local commands

```powershell
Set-Location shieldweb
npm install
npm run typecheck
npm run build
npm run dev
```

Vite normally serves at `http://localhost:5173`. Vercel is configured to build `dist` and rewrite routes to `index.html`; see [Deployment](deployment.md).
