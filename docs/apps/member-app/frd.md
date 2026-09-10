# Member App FRD

## Functional requirements

| ID | Requirement | Evidence |
| --- | --- | --- |
| MEM-AUTH-01 | Initialize Firebase and restore a member session before normal shell access | `lib/main.dart`, `module/auth/` |
| MEM-AUTH-02 | Verify member phone OTP and persist identity in `app.users` | auth service and Neon repositories |
| MEM-REG-01 | Complete member registration and assign a home branch | `module/registration/`, `shield_store` |
| MEM-CAT-01 | Browse home content, categories, products, search, details, FAQs, and reviews | catalogue modules |
| MEM-COM-01 | Maintain a cart and create an order with patient/address/payment context | cart, checkout, orders |
| MEM-COM-02 | Display order lifecycle and tracking steps | order screens/repository |
| MEM-RX-01 | Resize and upload prescription images tied to a patient and store | prescription module |
| MEM-RX-02 | Show prescription review/order state and reviewer outcomes | prescription screens |
| MEM-CARE-01 | Browse and book lab packages for selected patients | labtest module |
| MEM-CARE-02 | Book clinic, tele, dental, and dietitian appointments | appointment/dietitian modules |
| MEM-WAL-01 | Display wallet cards, balance, tiers, and ledger entries | wallet/privilege modules |
| MEM-REF-01 | Display reward balance and referral code/progress | rewards/refer modules |
| MEM-PER-01 | Reflect agent/investor conversion without exposing an unauthorized normal flow | persona/root screens |

## Cross-cutting acceptance

Every network-backed screen must define loading, empty, validation, error, retry, and signed-out states. Sensitive actions require confirmation. Mobile and web plugin differences must be tested before enabling a feature on both platforms.
