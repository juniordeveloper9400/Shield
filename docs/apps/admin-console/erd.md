# Admin Console ERD

The console reads and mutates the shared `app` schema. The complete model is [Combined ERD](../../erd.md).

```mermaid
erDiagram
  ADMIN_USER }o--|| SHIELD_STORE : scopes
  USERS ||--o{ ORDER : owns
  SHIELD_STORE ||--o{ ORDER : fulfils
  USERS ||--o{ PRESCRIPTION : submits
  SHIELD_STORE ||--o{ PRESCRIPTION : reviews
  USERS ||--o{ LAB_BOOKING : submits
  LAB_PACKAGE ||--o{ LAB_BOOKING : defines
  USERS ||--o{ APPOINTMENT : books
  SHIELD_STORE ||--o{ PRODUCT : stocks
  PRODUCT_CATEGORY ||--o{ PRODUCT : groups
  USERS ||--o{ WALLET_CARD : owns
  USERS ||--o| AGENT : converts_to
  AGENT ||--o{ AGENT : parent_of
  AGENT ||--o{ AGENT_REQUEST : parent_of
  AGENT_REQUEST ||--o| AGENT : approved_into
  REGION ||--o{ STATE : contains
  STATE ||--o{ DISTRICT : contains
  DISTRICT ||--o{ ASSEMBLY : contains
  ASSEMBLY ||--o{ LSGD : contains
  LSGD ||--o{ WARD : contains
```

The logical `ADMIN_USER` scope shown here reflects intended branch authorization; current client-side filtering is not sufficient integrity enforcement. Reconcile the console `admin` role with the database enum before implementing server auth.

Two agent-facing surfaces write `AGENT`: `AgentApprovalsPage`/`AgentApprovalDetailPage` (`src/api/agents.ts`) approve or reject an app-submitted `AGENT_REQUEST` into a real row, and `UserDetailPage`'s "Convert to agent" (`src/api/users.ts convertToAgent`) creates one directly for an existing member. Both must resolve a named slot (`AGENT.area_id`) from the `REGION`→`WARD` chain (`src/api/geo.ts`) for every level below national — a slot already held by an approved agent is refused.
