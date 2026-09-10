# Member App ERD

The member app uses the shared `app` schema. The complete logical model is [Combined ERD](../../erd.md); this is the member-owned slice.

```mermaid
erDiagram
  USERS ||--o{ MEMBER_ADDRESS : has
  USERS ||--o{ PATIENT : owns
  USERS ||--o{ CART : owns
  CART ||--o{ CART_LINE : contains
  USERS ||--o{ ORDER : places
  ORDER ||--o{ ORDER_LINE : contains
  USERS ||--o{ PRESCRIPTION : submits
  PATIENT ||--o{ PRESCRIPTION : for
  PRESCRIPTION ||--o{ PRESCRIPTION_MEDICINE : reviewed_as
  USERS ||--o{ WALLET : owns
  WALLET ||--o{ WALLET_ENTRY : records
  USERS ||--o{ REFERRAL : participates
  USERS ||--o{ LAB_BOOKING : books
  USERS ||--o{ APPOINTMENT : books
```

Key branch relationship: `users.home_store_id -> shield_store.id`; orders and prescriptions also carry branch context. The DDL at `backend/db/app_schema.sql` is authoritative.
