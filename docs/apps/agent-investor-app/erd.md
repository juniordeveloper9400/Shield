# Agent / Investor App ERD

The partner app reads the shared `app` schema. The complete model is [Combined ERD](../../erd.md).

```mermaid
erDiagram
  USERS ||--o| AGENT : converts_to
  USERS ||--o| INVESTOR : converts_to
  AGENT ||--o{ AGENT : parent_of
  AGENT ||--o{ AGENT_CUSTOMER : manages
  AGENT ||--o{ AGENT_WITHDRAWAL : requests
  AGENT ||--o{ AGENT_WALLET_TRANSFER : sends
  INVESTOR ||--o{ INVESTOR_PLAN_CHANGE_REQUEST : requests
  USERS ||--o{ ORDER : places
  WALLET_CARD }o--|| AGENT : sold_by
```

Persona ownership is resolved through the member phone and optional `member_id` relationships. Partner financial values need server-side authorization, auditability, and domain review before being treated as production accounting.
