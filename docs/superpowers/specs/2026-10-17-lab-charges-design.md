# Lab charges and automatic collection distance

Status: proposed for user review; not implemented or deployed.

## Outcome

Admin and Super Admin manage technician and distance charges through a new
**Lab Charges** sidebar entry. Home Collection uses the selected branch and
collection address to calculate road distance automatically. Both the root
member app and `shield agent_invester` use the same backend calculation.

## Rates and administration

The page lists named charge rules with Create, Edit, Delete and Active controls.
Technician charges are a configurable fixed amount per collection visit. No
technician amount is invented: staff must configure that amount.

The initial distance rule is:

| One-way road distance | Distance charge |
| --- | --- |
| Up to and including 3 km | INR 20 |
| Over 3 km through 5 km | INR 50 |
| Over 5 km | INR 50 plus INR 15 for each additional started kilometre |

Examples: 3 km costs INR 20; 3.1 km costs INR 50; 5 km costs INR 50;
5.1 km and 6 km cost INR 65; 6.1 km costs INR 80. The started-kilometre
rounding is a proposed rule for review, not an existing user requirement.
All thresholds and amounts are editable. Rates are non-negative and thresholds
must increase. At most one active technician rule and one active distance rule
apply. A preview explains the calculation before saving a rule.

Deleting or changing a rule affects future quotes only. Existing orders retain
their recorded rates and amounts. Admin permissions use a separate
`lab_charges` module; technician accounts cannot manage rate settings.

## Automatic road distance

Recommended approach: a backend Google Routes adapter, using branch coordinates
when present and the branch postal address otherwise, with the collection postal
address as destination. Calculate one-way driving distance in metres and apply
slabs before rounding the currency amount. This avoids treating straight-line
distance as road distance. The server-only provider key is configured in backend
environment variables; it never enters Flutter or browser bundles.

Alternatives considered: straight-line distance needs no routing provider but
can understate travel; manual kilometres avoid a provider but contradict the
requested automatic calculation.

The adapter has a timeout, validates provider responses, and returns an explicit
pending-distance result when the address is absent, incomplete, or unroutable,
or the provider is unavailable. It must not silently substitute a zero charge.
Patient/address details remain optional for placing a booking. Pending charges
are shown as awaiting confirmation and must be resolved before a final invoice
is issued. Store Visit has no collection technician or distance charge.

Changing the branch, address, or collection method invalidates an unpaid quote.
Recalculation is explicit in the admin editor, showing the new breakdown before
save. Paid invoices retain their financial values.

## One visit, multiple tests or patients

The current clients submit separate bookings for separate tests. Introduce a
shared checkout/collection reference before attaching visit charges, so multiple
tests booked together at one collection address incur one technician fee and
one distance fee. Retried submissions must not create another charge.

For multiple distinct collection addresses, show one visit and charge breakdown
per address, rather than silently summing travel or selecting one patient’s
address. A missing address remains a pending visit. The checkout review must
show the number of collection visits and their estimated charges.

Tests retain their individual details. This charge work shares the collection
reference with the separately requested grouped-lab-order flow; it must not
create a conflicting second grouping mechanism. Historical bookings are not
retrospectively charged or automatically guessed to belong together.

## Persistence and integration

Use additive migrations after existing migration 0102. Persist charge rules and
visit quote snapshots: branch, collection address snapshot, provider distance,
calculation time, applied rate snapshot, technician amount, distance amount and
quote status. Quotes are server-calculated; clients cannot submit trusted prices
or distances. Store monetary amounts as decimal currency values and distance as
integer metres. Avoid retaining raw provider responses or logging addresses.

The admin page uses authenticated backend CRUD APIs. Both Flutter trees display
the backend estimate, including the existing notice that the lab may update
charges. Booking, editing and invoice generation use the same calculation and
visit identity. Test totals and collection charges remain separate invoice lines.

## Verification and release

Test CRUD, authorization, invalid slabs, duplicate active rules, all distance
boundaries, fractional kilometres, missing addresses, provider failures and
timeouts, Store Visit, multiple tests at one address, multiple addresses,
idempotent retries, unpaid recalculation and paid-price protection. Mock the
routing provider in automated tests; perform a configured-provider smoke test
without placing a real order or charging a wallet.

Run backend integration tests/typecheck/build, admin tests/typecheck/build and
appropriate Flutter tests/analyze for both explicitly targeted trees. Deploy the
additive migration and configured backend before the admin and client releases.
Live automatic distance requires an enabled routing-provider account and key;
source changes alone do not enable that external service.
