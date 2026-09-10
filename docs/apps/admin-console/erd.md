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
```

The logical `ADMIN_USER` scope shown here reflects intended branch authorization; current client-side filtering is not sufficient integrity enforcement. Reconcile the console `admin` role with the database enum before implementing server auth.
