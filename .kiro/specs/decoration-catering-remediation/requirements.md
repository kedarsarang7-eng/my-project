# Requirements Document: Decoration & Catering (DC) Remediation

## Introduction

This requirements document is derived from the approved
`design.md` for the `decorationCatering` (Decoration & Catering) business
vertical remediation. It intentionally does **not** restate the original
`audit-reports/business-types/audit-decorationCatering.md` claims at face
value: design.md's "Current State Assessment" re-verified every audit claim
against the current source tree and found that most of the original
Phase 1 reachability plan, and several Phase 2/3 items, are **already
implemented**. Accordingly:

- Requirements for items marked **DONE** in design.md are written as
  **regression-lock requirements**: the behavior must remain true going
  forward, and is enforced by a specific locking test named in the
  requirement. These are not "build this" requirements — implementation
  work for them is limited to writing/confirming the locking test.
- Requirements for items marked **GAP** or **PARTIAL GAP** in design.md are
  written as full acceptance-criteria requirements describing the
  remaining implementation work.
- Phase numbering (`1.x`, `2.x`, `3.x`, `4.x`) mirrors the four-phase
  structure of the original remediation plan referenced by design.md, so
  that every requirement traces back both to design.md and to the original
  remediation ask.
- **Requirement 1.1 (the Phase 1 exit gate) is a hard prerequisite.** No
  Phase 2, 3, or 4 requirement in this document is considered actionable —
  i.e., no implementation task derived from it should be started — until
  Requirement 1.1's locking test exists and passes.
- Cross-cutting rules that apply across all phases are captured as
  **Ground Rule requirements** (`GR-x`), not tied to a single phase.
- Items design.md flags as requiring human product/backend confirmation
  before implementation are captured as **Open Question caveats** (`OQ-x`)
  rather than ordinary acceptance criteria, since they are not yet
  resolvable by an implementer alone.

## Glossary

- **DC_Vertical**: The `decorationCatering` business-type feature module
  rooted at `lib/features/decoration_catering/` in the Dukan_x Flutter app.
- **DcTenant**: A logged-in user/session whose active business type is
  `BusinessType.decorationCatering`.
- **SidebarConfiguration**: `lib/widgets/desktop/sidebar_configuration.dart`,
  specifically `_getDecorationCateringSections()` and
  `_getSectionsForBusiness()`.
- **SidebarNavigationHandler**: `sidebar_navigation_handler.dart`, specifically
  `tryGetScreenForItem()` / `getScreenForItem()`.
- **ContentHost**: `content_host.dart`, which resolves the post-login
  `executive_dashboard` landing screen per active business type.
- **LegacyRoutes**: `lib/core/routing/legacy_routes.dart`, the authoritative
  `go_router` route registry consumed by `lib/core/routing/app_router.dart`.
- **BusinessCapabilityRegistry**: `lib/core/isolation/business_capability.dart`,
  specifically `businessCapabilityRegistry['decorationCatering']`.
- **BusinessQuickActions**: `lib/features/dashboard/v2/widgets/business_quick_actions.dart`.
- **BusinessAlertsWidget**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart`.
- **DcRepository**: `lib/features/decoration_catering/data/repositories/dc_repository.dart`,
  the real `/dc/*`-backed repository.
- **DcBillingScreen**: `dc_billing_screen.dart`.
- **DcInventoryScreen**: `dc_inventory_screen.dart`.
- **DcQuoteConversionScreen**: `dc_quote_conversion_screen.dart`.
- **DecorationCateringBusinessRules**: `utils/decoration_catering_business_rules.dart`,
  including `AdvanceConfig`, `computeAdvancePaise`, `computeQuoteTotalPct`,
  `advanceForfeitedOnCancel`.
- **EventRental**: The rent-out/return/damage state machine model
  (`available → rentedOut → returned/returnedWithDamage`) defined in
  `event_rental.dart`.
- **EventBooking**: The booking data model in `dc_models.dart`, including
  `eventDate`, `eventEndDate`, `guestCount`, `advancePaid`, `status`.
- **CateringPackage**: The catering package data model in `dc_models.dart`,
  including `minGuests`.
- **Permissions**: `lib/config/permissions.dart`, the permission-constant
  registry consumed by `VendorRoleGuard`.
- **DcSyncHandler**: The new write-through sync handler this remediation
  introduces, registered with the existing `SyncManager`
  (`lib/core/sync/sync_manager.dart`).
- **DcEventsTable / DcInventoryTable**: The new Drift tables this remediation
  introduces for the offline-read cache.
- **DcReachabilityGateTest**: The new test file
  `test/features/decoration_catering/dc_reachability_gate_test.dart`
  required by Requirement 1.1.
- **BACKEND GAP error**: An explicit, clearly labeled exception thrown by a
  client-side call when the backend endpoint it depends on returns 404/501,
  as opposed to a silent mock fallback.

## Requirements

### Phase 1: Reachability Lock (hard prerequisite gate)

#### Requirement 1.1: Phase 1 exit reachability gate test

**User Story:** As a maintainer of Dukan_x, I want an automated, CI-enforced
test proving the DC vertical is fully reachable from the running app, so
that no future change to shared navigation/sidebar/capability files can
silently make the DC vertical unreachable again without breaking the build.

**Status:** GAP — this test does not exist yet. This is the hard
prerequisite gate for the rest of this document.

#### Acceptance Criteria

1. THE DC_Vertical SHALL have a test file
   `test/features/decoration_catering/dc_reachability_gate_test.dart`
   (DcReachabilityGateTest) that logs in as a DcTenant and exercises every
   DC sidebar item.
2. WHEN DcReachabilityGateTest runs, THE SidebarConfiguration SHALL return
   exactly 14 DC-only sections/items for a DcTenant.
3. IF any section returned by SidebarConfiguration for a DcTenant has a
   title equal to "BuyFlow", "Inventory & Stock", or "Tax & Compliance",
   THEN DcReachabilityGateTest SHALL fail.
4. WHEN DcReachabilityGateTest resolves any DC sidebar item id via
   SidebarNavigationHandler.tryGetScreenForItem, THE SidebarNavigationHandler
   SHALL return a non-null widget that is not `_PlaceholderScreen`.
5. WHEN DcReachabilityGateTest pumps each resolved DC screen widget, THE
   DC_Vertical SHALL NOT throw during build.
6. WHILE the active session business type is `decorationCatering`, WHEN
   DcReachabilityGateTest resolves the `executive_dashboard` item via
   SidebarNavigationHandler, THE ContentHost SHALL resolve it to
   `DcDashboardScreen`.
7. THE DcReachabilityGateTest SHALL pass before any Phase 2, Phase 3, or
   Phase 4 requirement in this document is considered actionable.

**Verifying test type:** widget/integration test (flutter_test).

---

### Phase 2: Billing, Payments, Rentals, Offline Read

#### Requirement 2.1: Sidebar, routing, landing, and alerts regression lock

**User Story:** As a maintainer of Dukan_x, I want the already-correct DC
sidebar wiring, route registrations, post-login landing, and live alert
counts to be locked in by tests, so that they cannot silently regress.

**Status:** DONE (multiple audit claims) — regression-lock only, no new
production code.

#### Acceptance Criteria

1. THE SidebarNavigationHandler SHALL resolve every one of the 14
   DC-only sidebar item ids to a real, non-`_PlaceholderScreen` widget,
   locked in by DcReachabilityGateTest (Requirement 1.1).
2. THE LegacyRoutes registry SHALL map `/dc/vendors` to
   `DcVendorPaymentsScreen`, locked in by a routing test asserting the
   route target class.
3. THE LegacyRoutes registry SHALL register guarded `GoRoute`s for all 8
   previously-unrouted DC screens (Calendar, Quotes, Profitability,
   ShoppingList, VendorPayments, EventDetail, QuoteConversion,
   StaffAttendance), locked in by a routing test enumerating each route.
4. WHILE a DcTenant is logged in, WHEN the alerts widget renders, THE
   BusinessAlertsWidget SHALL compute alert counts from
   `dcAlertCountsProvider` rather than a hardcoded value, locked in by a
   widget test asserting the provider is consulted.
5. THE decoration_catering.dart barrel export list is covered by
   Requirement 4.4 (barrel-completeness regression lock); this requirement
   does not duplicate it.

**Verifying test type:** widget + routing/integration locking test
(regression-lock — no new production-code coverage).

#### Requirement 2.2: Real payment-method parsing in `getPayments`

**User Story:** As a DC business owner, I want the payments list to show
the actual payment method used, so that my payment records are accurate
instead of always showing "Cash".

**Status:** GAP — `DcRepository.getPayments()` still hardcodes
`PaymentMethod.cash` unconditionally, even though the sibling methods
`_expenseFromJson`/`_vendorPaymentFromJson` already use `_parsePaymentMethod()`.

#### Acceptance Criteria

1. WHEN `DcRepository.getPayments()` maps a raw payment/invoice record to a
   `DcPayment`, THE DcRepository SHALL derive `method` via
   `_parsePaymentMethod()` using the record's `paymentMode` field, falling
   back to `paymentMethod`, consistent with `_vendorPaymentFromJson`.
2. IF neither `paymentMode` nor `paymentMethod` is present on a record,
   THEN THE DcRepository SHALL default `method` to `PaymentMethod.cash` and
   emit a debug-level trace naming the record id, rather than silently
   defaulting with no trace.
3. THE DcRepository SHALL NOT hardcode `method: PaymentMethod.cash`
   unconditionally in `getPayments()`.

**Verifying test type:** unit test (mocked ApiClient, well-formed and
malformed/missing `paymentMode`/`paymentMethod` fixtures).

#### Requirement 2.3: Billing line-item description validation

**User Story:** As a DC business owner, I want blank line-item descriptions
rejected when generating an invoice, so that my invoices always describe
what was billed.

**Status:** GAP — not validated today; blank descriptions are accepted and
submitted.

#### Acceptance Criteria

1. WHEN a user changes a `_BillItem` description field to a blank or
   whitespace-only value, THE DcBillingScreen SHALL set that item's
   `descError` to a non-null validation message.
2. WHILE any `_BillItem` in the current invoice has a non-null `descError`,
   THE DcBillingScreen SHALL keep the "Generate Invoice" action disabled.
3. WHEN a user changes a blank description to a non-blank value, THE
   DcBillingScreen SHALL clear that item's `descError`.
4. IF `_generateAndSaveInvoice` is invoked while any item description is
   blank or whitespace-only, THEN THE DcBillingScreen SHALL NOT submit the
   invoice.

**Verifying test type:** widget test (toggle blank/non-blank description,
assert "Generate Invoice" enablement).

#### Requirement 2.4: Capability-gating regression lock

**User Story:** As a maintainer of Dukan_x, I want the DC capability
registry's "service-only" comment and behavior to stay verified-accurate,
so that the audit's original capability-bypass concern cannot silently
reappear.

**Status:** DONE — the audit's capability-bypass claim (retail
Inventory/BuyFlow items leaking into a DC session) was found to already be
resolved because DC has its own dedicated sidebar section with no
inventory/product capability grants. This is a regression-lock-only
requirement.

#### Acceptance Criteria

1. THE BusinessCapabilityRegistry SHALL NOT grant `decorationCatering` any
   product or inventory capability (e.g. `useProductAdd`, `useInventoryList`,
   `useStockEntry`), locked in by a capability-certification test.
2. WHILE a DcTenant is logged in, THE SidebarConfiguration SHALL NOT
   include any BuyFlow, Inventory & Stock, or Tax & Compliance section,
   locked in by the same test used in Requirement 1.1's item 3.
3. THE regression-lock test for this requirement SHALL fail if any future
   change grants DC an inventory/product capability without also updating
   this test, preventing a silent reintroduction of the capability-bypass
   the original audit flagged.

**Verifying test type:** unit/certification locking test on
`businessCapabilityRegistry` (regression-lock — no new production-code
coverage).

#### Requirement 2.5: Rental lifecycle wiring — `EventRental` to UI and repository

**User Story:** As a DC business owner, I want to rent out and return
decoration/catering inventory items against a specific event, with damage
tracking, so that I can track what's currently out and reconcile losses.

**Status:** PARTIAL GAP — the `EventRental` state machine model
(`available → rentedOut → returned/returnedWithDamage`) already exists and
is already unit-tested in isolation, but it is not wired to
`dc_inventory_screen.dart` nor to any repository/network method.

#### Acceptance Criteria

1. THE DcRepository SHALL provide a `rentOut({itemId, eventId, quantity})`
   method that calls `POST /dc/inventory/{id}/rent-out` and returns an
   `EventRental` on success.
2. IF `POST /dc/inventory/{id}/rent-out` returns HTTP 404, THEN THE
   DcRepository SHALL throw an explicit exception naming the missing
   endpoint and containing the text "BACKEND GAP", and SHALL NOT mutate any
   local state.
3. THE DcRepository SHALL provide a `returnRental({itemId, rentalId,
   damagedQty})` method that calls `POST /dc/inventory/{id}/return` and
   returns an `EventRental` on success.
4. IF `POST /dc/inventory/{id}/return` returns HTTP 404, THEN THE
   DcRepository SHALL throw an explicit exception naming the missing
   endpoint and containing the text "BACKEND GAP", and SHALL NOT mutate any
   local state.
5. WHEN a user triggers a "Rent Out" action on `DcInventoryScreen` for an
   item, THE DcInventoryScreen SHALL first validate the requested quantity
   locally via `EventRental.rentOut()`'s bounds check before calling
   `DcRepository.rentOut()`.
6. WHEN a user triggers a "Return" action on `DcInventoryScreen` for a
   rented item, THE DcInventoryScreen SHALL first validate the damaged
   quantity locally via `EventRental.returnItem()`'s bounds check before
   calling `DcRepository.returnRental()`.
7. IF a locally-invalid quantity is entered for rent-out or return, THEN
   THE DcInventoryScreen SHALL reject it without making a network call.

**Verifying test type:** unit test (mocked ApiClient covering success, 404
BACKEND GAP, and other failure) + widget test for the UI wiring.

#### Requirement 2.6: Offline-read cache for DC events and inventory

**User Story:** As a DC business owner, I want to see my most recently
synced events and inventory when the network is unavailable, so that a
temporary connectivity loss doesn't leave me with a blank screen.

**Status:** GAP — no Drift tables, sync handler, or WebSocket handler exist
for DC anywhere in the current tree; this is full, previously-unstarted
scope, explicitly bounded to **offline-read only**.

#### Acceptance Criteria

1. THE DC_Vertical SHALL define `DcEventsTable` and `DcInventoryTable`
   Drift tables mirroring the fields of `EventBooking` and
   `DcInventoryItem` respectively, plus a `lastSyncedAt` timestamp column.
2. WHEN `DcRepository.getBookings()` or `DcRepository.getInventory()`
   succeeds against the live API, THE DcSyncHandler SHALL write the
   returned rows into `DcEventsTable`/`DcInventoryTable` (write-through
   cache).
3. IF a call to `DcRepository.getBookings()` or `DcRepository.getInventory()`
   throws any exception, THEN THE relevant provider SHALL fall back to
   reading the last-written rows from `DcEventsTable`/`DcInventoryTable`
   and return them instead of propagating the error.
4. WHEN a fallback read occurs per Acceptance Criterion 3, THE returned
   data SHALL be tagged `isStale: true`, and THE UI SHALL surface a
   "showing last-synced data" banner.
5. WHEN a subsequent live fetch succeeds after a stale-data fallback, THE
   UI SHALL clear the "showing last-synced data" banner automatically.
6. WHEN the existing WebSocketService delivers a `dc.event.confirmed`,
   `dc.payment.received`, or `dc.staff.assigned` event, THE DcSyncHandler
   SHALL apply the update to the corresponding local Drift row.
7. WHERE a write operation (booking/invoice create or update) is attempted
   while offline, THE DC_Vertical SHALL surface the existing network
   exception through the existing try/catch UI error path, worded to
   mention connectivity when the underlying error indicates a connectivity
   failure.
8. THE DC_Vertical SHALL NOT implement offline write queuing, local
   optimistic writes, or write-conflict resolution in this remediation —
   offline-write is explicitly out of scope and deferred as a stretch goal.

**Verifying test type:** integration test (seed `DcEventsTable`, force
`ApiClient.get` to throw, assert stale-tagged fallback rows are returned).

---

### Phase 3: Business Rules Consistency

#### Requirement 3.1: Quote vs invoice math unification regression lock

**User Story:** As a DC business owner, I want quote totals and invoice
totals to be computed by the same percentage-based formula, so that a
quote I convert to a booking doesn't produce a different total than the
billing screen would.

**Status:** DONE — both paths now go through `computeQuoteTotalPct`; the old
absolute-amount `computeQuoteTotal` is `@Deprecated` but retained for
back-compat. Regression-lock only.

#### Acceptance Criteria

1. THE DcQuoteConversionScreen and DcBillingScreen SHALL both compute
   totals via `DecorationCateringBusinessRules.computeQuoteTotalPct`.
2. FOR ALL equivalent inputs (same subtotal, discount %, GST %), THE
   quote-path total and the billing-path total SHALL be numerically
   identical, locked in by a parity test.
3. THE deprecated `computeQuoteTotal` function SHALL remain marked
   `@Deprecated` and SHALL NOT be called from any new code path introduced
   by this remediation.

**Verifying test type:** unit locking test (parity test between quote-path
and billing-path totals for equivalent inputs; regression-lock — no new
production-code coverage).

#### Requirement 3.2: Advance default and bounds regression lock

**User Story:** As a DC business owner, I want the advance amount on quote
conversion to default to a sane percentage and never exceed the quote
total, so that I don't accidentally under- or over-collect an advance.

**Status:** DONE — `AdvanceConfig` defaults to 50%, constrained to [30,50];
`computeAdvancePaise` rejects out-of-bounds amounts by returning `null`.
Regression-lock only.

#### Acceptance Criteria

1. WHEN DcQuoteConversionScreen initializes its advance field, THE
   AdvanceConfig SHALL default `advancePct` to 50, and the UI control SHALL
   constrain the selectable range to [30, 50].
2. FOR ALL `AdvanceConfig` instances with `advancePct` outside [30, 50],
   THE `AdvanceConfig.isValid` SHALL be `false`.
3. FOR ALL non-negative `totalPaise` and any `AdvanceConfig` where
   `isValid` is `true`, `computeAdvancePaise(totalPaise)` SHALL return
   either `null` or a value within `[0, totalPaise]`, never a value outside
   that range.
4. IF `computeAdvancePaise` returns `null`, THEN THE
   DcQuoteConversionScreen SHALL reject the conversion and SHALL NOT create
   a booking or change quote status.

**Verifying test type:** unit/property locking test on
`computeAdvancePaise` (see Correctness Properties in design.md;
regression-lock — no new production-code coverage).

#### Requirement 3.3: Advance recorded as a payment ledger entry, with rollback

**User Story:** As a DC business owner, I want the advance collected on
quote conversion to be recorded in the payments ledger, so that my payment
records reflect every advance, and I want the booking rolled back if that
recording fails, so that I never end up with an unpaid, un-tracked booking.

**Status:** DONE — `recordPayment()` is called post-booking-creation with
rollback (delete booking + revert quote status) on failure.
Regression-lock only.

#### Acceptance Criteria

1. WHEN a quote is converted to a booking with a valid advance amount, THE
   DcQuoteConversionScreen SHALL call `DcRepository.createBooking()`
   followed by `DcRepository.recordPayment()` with the advance amount.
2. IF `DcRepository.recordPayment()` fails after a booking was created,
   THEN THE DcQuoteConversionScreen SHALL delete the created booking and
   revert the quote status to its pre-conversion value, and SHALL show an
   error indicating the advance could not be recorded.
3. WHEN both `createBooking()` and `recordPayment()` succeed, THE
   DcQuoteConversionScreen SHALL navigate back and show a success
   indication.

**Verifying test type:** unit locking test (mocked DcRepository, success
and recordPayment-failure-with-rollback paths; regression-lock — no new
production-code coverage).

#### Requirement 3.4: Multi-day event support regression lock

**User Story:** As a DC business owner, I want to record an end date for
multi-day events, so that events spanning more than one day are represented
correctly.

**Status:** DONE — `EventBooking.eventEndDate` (nullable `DateTime?`)
exists, defaults to unset for back-compat, and is validated against
`eventDate` on parse. Regression-lock only. Multi-day profitability
correctness is a separate open question (see OQ-7) and is not covered by
this requirement.

#### Acceptance Criteria

1. THE `EventBooking` model SHALL expose a nullable `eventEndDate` field.
2. IF an `EventBooking` is parsed from a raw record where `eventEndDate` is
   absent, THEN THE `EventBooking` SHALL default `eventEndDate` to `null`
   without throwing.
3. IF an `EventBooking` is parsed from a raw record where `eventEndDate` is
   present but chronologically before `eventDate`, THEN THE parsing logic
   SHALL treat this as invalid input consistent with existing validation
   behavior (locked in by a parsing test, not newly specified here).

**Verifying test type:** unit locking test (parse fixtures with/without
`eventEndDate`, and with an invalid end-before-start value;
regression-lock — no new production-code coverage).

#### Requirement 3.5: `_bookingFromJson` null-safety regression lock

**User Story:** As a DC business owner, I want one malformed booking record
from the backend to not crash my entire bookings list, so that a single bad
record doesn't hide all my other bookings.

**Status:** DONE — null-safe with defaults for every field except `id`
(which intentionally throws and is caught per-record by `_dataList`).
Regression-lock only.

#### Acceptance Criteria

1. FOR ALL raw booking records missing any field other than `id`, THE
   `_bookingFromJson` SHALL return a valid `EventBooking` with a documented
   default for the missing field, and SHALL NOT throw.
2. IF a raw booking record is missing `id`, THEN THE `_bookingFromJson`
   SHALL throw, and THE `_dataList` SHALL catch that exception per-record
   and exclude only that record from the returned list.
3. WHEN a response contains a mix of well-formed and malformed (missing
   `id`) records, THE bookings list SHALL contain all well-formed records
   and exclude only the malformed ones.

**Verifying test type:** unit/property locking test (malformed-record
generation missing various non-`id` fields, and missing-`id` records;
regression-lock — no new production-code coverage).

#### Requirement 3.6: `minGuests` enforcement at billing time

**User Story:** As a DC business owner, I want to be warned when a booking's
guest count is below the selected catering package's minimum, so that I
notice under-priced bookings before invoicing, without being blocked from
billing an already-confirmed event.

**Status:** GAP — not found in `dc_billing_screen.dart`'s
`_addDefaultItems`; `CateringPackage.minGuests` is parsed by the repository
but never checked against `booking.guestCount`.

#### Acceptance Criteria

1. WHEN a catering package is selected for a booking whose `guestCount` is
   less than `CateringPackage.minGuests`, THE DcBillingScreen SHALL call
   `validateMinGuests()` and display a non-blocking banner containing the
   returned message.
2. IF `booking.guestCount >= pkg.minGuests`, THEN THE `validateMinGuests()`
   function SHALL return `null` and no banner SHALL be shown.
3. THE `validateMinGuests()` check SHALL NOT block or disable the
   "Generate Invoice" action; billing SHALL proceed at the actual guest
   count when the user acknowledges or ignores the banner.
4. THE invoice total computed after this check SHALL be unaffected by the
   `minGuests` comparison itself (the comparison is advisory only).

**Verifying test type:** unit test (`validateMinGuests` below/at/above
minimum) + widget test (banner visibility, invoice enablement unaffected).

#### Requirement 3.7: Fine-grained DC permissions replacing borrowed invoice permissions

**User Story:** As a Dukan_x administrator, I want DC route access controlled
by event/staff-specific permissions instead of generic invoice permissions,
so that I can grant a role access to bookings/staff features without also
granting invoice access, and vice versa.

**Status:** GAP — all DC routes still gate on `Permissions.viewInvoices` /
`Permissions.createInvoices` / `Permissions.viewReports` regardless of
whether the action is actually about invoices.

#### Acceptance Criteria

1. THE `Permissions` class SHALL gain two new additive constants,
   `viewEvents` and `createEvents`, without removing or renaming any
   existing permission constant.
2. THE LegacyRoutes registry SHALL update `/dc/bookings` (and equivalent
   booking-viewing routes) to require `Permissions.viewEvents` instead of
   `Permissions.viewInvoices`.
3. THE LegacyRoutes registry SHALL update `/dc/bookings/new` (and
   equivalent booking-creation routes) to require `Permissions.createEvents`
   instead of `Permissions.createInvoices`.
4. THE LegacyRoutes registry SHALL update `/dc/staff_attendance` to require
   `Permissions.manageStaff` instead of `Permissions.viewInvoices`.
5. THE role→permission matrix SHALL map `viewEvents` and `createEvents` to
   the same roles that currently hold `viewInvoices` and `createInvoices`
   respectively, so that no existing DC user loses access as a direct
   result of this change.
6. IF a user holds `viewInvoices`/`createInvoices` but not `manageStaff`,
   THEN THE user SHALL NOT be able to reach `/dc/staff_attendance`.
7. IF a user holds `viewEvents` but not `viewInvoices`, THEN THE user
   SHALL be able to reach `/dc/bookings`.
8. THE `BusinessGuard(allowedTypes:[decorationCatering])` wrapper on every
   DC route SHALL remain unchanged by this requirement — only the
   `requiredPermission` argument changes.

**Verifying test type:** unit/permission-boundary test (route gating with
various permission combinations).

#### Requirement 3.8: `eventDate` time-of-day decision locked in

**User Story:** As a maintainer of Dukan_x, I want the decision that
`eventDate` is intentionally date-only (with time-of-day tracked separately)
to be documented and locked in by a test, so that a future engineer doesn't
"fix" it without realizing it's intentional.

**Status:** GAP (documentation/decision gap) — the truncation behavior
itself already exists and is not changed; what's missing is the explicit
decision record and locking test. See also OQ-5 for the product-facing
caveat.

#### Acceptance Criteria

1. THE `DcRepository.createBooking()`/`updateBooking()` SHALL continue to
   truncate `eventDate` to date-only (`substring(0,10)`) when serializing
   for the API.
2. THE call site performing this truncation SHALL carry a code comment
   stating the truncation is intentional and referencing the locking test
   file by name.
3. THE DC_Vertical SHALL have a test file
   `test/features/decoration_catering/dc_repository_event_date_test.dart`
   asserting the truncation behavior is unchanged.
4. IF a future change alters this truncation behavior, THEN the test in
   Acceptance Criterion 3 SHALL fail, requiring an explicit, deliberate
   update to both the test and the code comment together.

**Verifying test type:** unit test (locking test on serialization output).

#### Requirement 3.9: Regression-lock for billing validation (discount/GST/qty/rate/event-required)

**User Story:** As a DC business owner, I want discount, GST, quantity, and
rate fields validated on the billing screen, and invoice generation blocked
without a selected event, so that I can't accidentally create a nonsensical
or orphaned invoice.

**Status:** DONE — discount clamped [0,100], GST clamped [0,28], qty/rate
rejected when ≤0/negative with inline errors, "Generate Invoice" disabled
without a selected event. Regression-lock only.

#### Acceptance Criteria

1. FOR ALL discount percentage inputs on DcBillingScreen, THE effective
   discount value used in totals SHALL be clamped to `[0, 100]`.
2. FOR ALL GST percentage inputs on DcBillingScreen, THE effective GST
   value used in totals SHALL be clamped to `[0, 28]`.
3. IF a line-item quantity or rate is entered as zero or negative, THEN THE
   DcBillingScreen SHALL show an inline error and SHALL NOT include that
   item's invalid value in the computed total as if it were valid.
4. WHILE no event is selected, THE DcBillingScreen SHALL keep "Generate
   Invoice" disabled.

**Verifying test type:** widget/unit test (locking tests for each clamp/
validation behavior).

---

### Phase 4: Cancellation, Accessibility, Barrel Completeness

#### Requirement 4.1: `advanceForfeitedOnCancel` wired into cancellation flow

**User Story:** As a DC business owner, I want to be told when cancelling a
booking will forfeit the customer's advance under the 7-day lock-in policy,
so that I confirm the forfeiture deliberately rather than it happening
silently.

**Status:** GAP — `advanceForfeitedOnCancel` is a pure, already-tested
calculation but is still test-only; this remediation wires it into the
cancellation flow with a confirmation step.

#### Acceptance Criteria

1. WHEN a user initiates cancellation of an `EventBooking`, THE
   cancellation flow SHALL evaluate
   `DecorationCateringBusinessRules.advanceForfeitedOnCancel(booking.eventDate,
   now)`.
2. IF `advanceForfeitedOnCancel` returns `true` AND `booking.advancePaid >
   0`, THEN THE cancellation flow SHALL show a confirmation dialog stating
   the advance will be forfeited before proceeding.
3. IF the user does not confirm the dialog in Acceptance Criterion 2, THEN
   THE cancellation flow SHALL NOT change the booking's status.
4. WHEN the user confirms cancellation (with or without forfeiture),
   THE cancellation flow SHALL call
   `DcRepository.updateBookingStatus(booking.id, EventStatus.cancelled)`.
5. WHEN forfeiture applies, THE cancellation flow SHALL leave
   `booking.advancePaid` unchanged (forfeited, not refunded) — a refund
   ledger entry is out of scope for this remediation (see OQ-8).

**Verifying test type:** unit test (cancellation confirmation branch:
forfeits vs. does-not-forfeit paths).

#### Requirement 4.2: Accessibility — invoice-history status label font size

**User Story:** As a DC business owner with low vision, I want invoice
status labels to be legible, so that I can distinguish invoice statuses
without strain.

**Status:** PARTIAL GAP — the delete-row icon tooltip fix is already done
(regression-lock, see Requirement 4.3); the font-size fix is the remaining
gap.

#### Acceptance Criteria

1. THE invoice-history status label font size on DcBillingScreen SHALL be
   at least 12px, increased from the current 10px.
2. THE change in Acceptance Criterion 1 SHALL NOT alter the status color
   coding (green/blue/orange) or the accompanying text label already in
   place.

**Verifying test type:** widget test asserting the rendered `TextStyle.fontSize`
of the status label is `>= 12`.

#### Requirement 4.3: Delete-row icon tooltip regression lock

**User Story:** As a maintainer of Dukan_x, I want the delete-row icon
button's accessibility tooltip to remain present, so that the accessibility
fix already made doesn't silently regress.

**Status:** DONE — the delete-row `IconButton` now has
`tooltip: 'Remove line item'`. Regression-lock only.

#### Acceptance Criteria

1. THE delete-row `IconButton` on DcBillingScreen SHALL have a non-null
   `tooltip` property with the value `'Remove line item'`.
2. THE regression-lock test for this requirement SHALL fail if the
   tooltip is removed or its text changes without an accompanying,
   deliberate update to the test.

**Verifying test type:** widget locking test (assert `tooltip` property;
regression-lock — no new production-code coverage).

#### Requirement 4.4: Barrel-completeness regression lock

**User Story:** As a maintainer of Dukan_x, I want the DC feature barrel to
keep exporting every DC screen and dialog, so that import consumers never
silently lose access to a screen because it fell out of the barrel.

**Status:** DONE — all 16 screens plus `dc_vendor_rating_dialog` are
exported. Regression-lock only.

#### Acceptance Criteria

1. THE `decoration_catering.dart` barrel file SHALL export all 16 DC
   screens (`dc_billing_screen`, `dc_bookings_screen`, `dc_calendar_screen`,
   `dc_catering_screen`, `dc_dashboard_screen`, `dc_decoration_screen`,
   `dc_event_detail_screen`, `dc_inventory_screen`,
   `dc_profitability_screen`, `dc_quote_conversion_screen`,
   `dc_quotes_screen`, `dc_reports_screen`, `dc_shopping_list_screen`,
   `dc_staff_attendance_screen`, `dc_staff_screen`,
   `dc_vendor_payments_screen`) plus `dc_vendor_rating_dialog`.
2. THE regression-lock test for this requirement SHALL fail if any of
   these exports is removed from the barrel without a deliberate,
   accompanying update to the test.

**Verifying test type:** static/unit locking test (import-list assertion,
e.g. a test that imports the barrel and references each exported symbol;
regression-lock — no new production-code coverage).

---

## Ground Rule Requirements (cross-cutting, all phases)

#### Requirement GR-1: No regression to other business types

**User Story:** As a maintainer of Dukan_x, I want every DC remediation
change to be additive-only with respect to shared files, so that retail and
pharmacy tenants see byte-for-byte identical sidebar, quick-actions, alerts,
and routing behavior after this remediation lands.

#### Acceptance Criteria

1. THE existing retail and pharmacy sidebar/quick-actions/alerts/routing
   test suites SHALL pass unmodified after this remediation lands.
2. WHEN comparing `getSectionsForBusinessType(retail)` and
   `getSectionsForBusinessType(pharmacy)` output captured before and after
   this remediation, THE output SHALL be byte-for-byte identical.
3. THE shared files (`sidebar_configuration.dart`,
   `sidebar_navigation_handler.dart`, `business_quick_actions.dart`,
   `business_alerts_widget.dart`, `business_capability.dart`, and
   LegacyRoutes) SHALL be modified only via additive `switch`/`case`
   entries or additive route entries.
4. IF a change to a shared file modifies a `default:` branch or another
   business type's `case` branch, THEN that change SHALL be rejected as
   out of scope for this remediation.

**Verifying test type:** integration test (before/after diff of
per-business-type sidebar output; existing retail/pharmacy suites re-run
unmodified).

#### Requirement GR-2: Integer paise for all new/changed money arithmetic

**User Story:** As a maintainer of Dukan_x, I want all new or changed
currency arithmetic in this remediation expressed in integer paise, so
that money values are never subject to floating-point rounding error.

#### Acceptance Criteria

1. FOR ALL new or changed arithmetic introduced by this remediation that
   computes a monetary amount, THE computation SHALL be performed using
   `DcMoneyMath` on integer paise values.
2. THE existing `double` rupee fields already present at the UI boundary
   (e.g. `EventBooking.advancePaid`) SHALL be tolerated as pre-existing and
   are NOT required to be converted by this remediation.
3. IF any new function introduced by this remediation computes a monetary
   amount using `double` arithmetic instead of integer paise, THEN that
   function SHALL be considered non-compliant with this requirement.

**Verifying test type:** unit test (assert integer-paise inputs/outputs on
new money-computing functions).

#### Requirement GR-3: Backend-dependent client calls fail loud, never silently mock

**User Story:** As a maintainer of Dukan_x, I want any new client call that
depends on an unverified backend endpoint to fail with an explicit, labeled
error, so that a missing backend deployment is visible and testable instead
of silently masked by a mock fallback.

#### Acceptance Criteria

1. FOR ALL new client calls introduced by this remediation to
   `/dc/inventory/{id}/adjust`, `/dc/inventory/{id}/rent-out`, or
   `/dc/inventory/{id}/return`, IF the endpoint returns HTTP 404 or 501,
   THEN THE client SHALL throw an exception whose message contains the
   text "BACKEND GAP" and names the specific endpoint.
2. THE client SHALL NOT mutate local state when a BACKEND GAP error is
   thrown.
3. THE DC_Vertical SHALL have a failing integration test documenting each
   unverified endpoint's gap until its deployment is confirmed.
4. THE client SHALL NOT silently substitute a mocked or fabricated
   successful response when a BACKEND GAP condition is detected.

**Verifying test type:** unit/integration test (mocked ApiClient returning
404/501 for each unverified endpoint).

#### Requirement GR-4: Every requirement specifies its verifying test type

**User Story:** As a maintainer of Dukan_x, I want every requirement in
this document to state what kind of automated test verifies it, so that
task creation and implementation have an unambiguous test obligation.

#### Acceptance Criteria

1. THE requirements document SHALL specify a "Verifying test type" (unit,
   widget, or integration) for every numbered requirement (1.1 through
   4.4, and GR-1 through GR-3).
2. WHERE a requirement's status is a regression lock (DONE in design.md),
   THE verifying test type SHALL be a locking test rather than new
   production-code test coverage.

**Verifying test type:** N/A (this is a documentation-completeness
requirement, verified by document review, not an automated test).

---

## Open Questions / Assumptions (require human sign-off before implementation)

The following items are carried over from design.md's "Open Questions /
Assumptions" section. They are **not** ordinary acceptance criteria — each
represents a fact or product decision that an implementer cannot resolve
alone. Any Phase 2/3/4 requirement above that depends on one of these is
flagged with a reference to the relevant OQ item; implementation of that
requirement should proceed under the stated assumption until the caveat is
resolved, and the requirement re-reviewed once it is.

- **OQ-1 (Backend deployment status).** No `/dc/*` endpoint — including
  `/dc/inventory/{id}/adjust`, `/dc/inventory/{id}/rent-out`, and
  `/dc/inventory/{id}/return` — is confirmed deployed. Relevant to
  Requirement 2.5 and GR-3. Assumption: endpoints are either already live
  or will be deployed before the corresponding task is considered complete;
  until then, BACKEND GAP errors and failing tests track the gap.
- **OQ-2 (`rentalPrice` field name/shape).** The repository tries
  `rentalPricePaisa` then `rentalPrice`; neither is confirmed as the actual
  backend field name. No requirement in this document changes this
  fallback chain further without confirmation.
- **OQ-3 (Payment-method/mode field name(s)).** The repository tries
  `paymentMode` then `paymentMethod` in expense/vendor-payment/payment
  responses. Relevant to Requirement 2.2. Assumed sufficient but not
  confirmed against real backend responses.
- **OQ-4 (`minGuests` field existence/shape).** The repository parses
  `j['minGuests']` defaulting to `1` if absent. Relevant to Requirement 3.6.
  Assumed correct but unconfirmed against the real backend contract.
- **OQ-5 (`eventDate` time-of-day intent).** Requirement 3.8 locks in
  "date-only is intentional" as an inference from the presence of separate
  time-of-day fields, not a confirmed product decision. Flagged for
  explicit product sign-off before being treated as permanently settled.
- **OQ-6 (`advanceForfeitedOnCancel` product intent).** Requirement 4.1
  proposes wiring the existing calculation into the cancellation flow based
  on the shape of the existing model and lack of contrary signal. This is a
  product decision that should be explicitly confirmed, not assumed
  correct purely because it was inferred.
- **OQ-7 (Multi-day profitability formula correctness).** `eventEndDate`
  exists on `EventBooking` (Requirement 3.4), but `getEventProfitability`
  is a server-computed value whose formula is not inspected by this
  remediation. Whether the backend's calculation is multi-day-aware is
  unverified and out of client-side scope.
- **OQ-8 (Refund ledger scope).** Requirement 4.1's cancellation flow
  leaves `advancePaid` untouched on forfeiture (no refund state exists in
  the current model). Whether a partial-refund ledger entry should exist is
  a separate, explicitly out-of-scope product question.
- **OQ-9 (Quick-actions capability-gating intent).** `BusinessQuickActions`'
  DC case (New Booking/New Quote/Add Staff/Menu-Package) is not gated by
  `BusinessCapability` the way sidebar items are. Whether this is
  intentional (a fixed, curated action set per vertical) or a gap is
  unresolved; no requirement in this document adds gating without
  confirmation, since DC's capability grant already covers all four actions
  today (no functional bypass currently exists).
