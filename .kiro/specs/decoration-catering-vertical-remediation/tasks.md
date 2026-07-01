# Implementation Plan

## Overview

Phased implementation plan for making the DukanX `decorationCatering` vertical (the **DC_System**)
shippable end-to-end. Work proceeds strictly in phase order (Phase 0 → Phase 8). Phase 0 is
read-only verification. Every subsequent phase ends with an explicit human approval gate. The plan
follows the same remediation pattern used by the restaurant and clinic verticals and honors the
cross-cutting constraints in Requirement 1 (tenant scoping, integer-paise money for touched code,
RID ids, idempotent migrations, no silent deletions/schema changes, real fixes only).

Implementation language: **Dart / Flutter** (the design specifies Dart APIs throughout). Property
tests use `package:glados` (already used in `test/certification/pbt/`), one test per Correctness
Property, minimum 100 generated cases, each tagged
`Feature: decoration-catering-vertical-remediation, Property {n}: {text}`.

> **Phased STOP gates (steering operating rules).** After every phase: (a) list every file
> created/modified/deleted, (b) run `flutter analyze` on touched files and report results, (c)
> output exactly `PHASE N COMPLETE — AWAITING APPROVAL`, then stop and wait for the literal reply
> `APPROVED`. Do NOT auto-continue. Phase 2 (capability path), Phase 7 (offline sync), and the
> Phase 8 deletions are sign-off gated and stay conditional until their sign-off is recorded. Any
> DynamoDB schema change requires a Mini_Approval_Gate. Do NOT modify any other business type's
> code, capability config, or sidebar sections. Do NOT change the DC 18% GST default.
>
> Sub-tasks marked with `*` are optional test tasks (property/unit/integration/widget tests) and
> may be skipped for a faster MVP; core implementation sub-tasks are never optional.

## Tasks

- [x] 1. Phase 0 — Read-Only Backend Reality Check
  - [x] 1.1 Produce the `Verification_Report` Markdown artifact (read-only; zero source changes)
    - Create a single Markdown file under the spec folder; create/modify/delete no other file
    - Classify each of the 17 `/dc/*` endpoints (events CRUD, staff, staff/attendance, vendors,
      inventory, menu, packages, themes, expenses, invoices, quotes, payments, dashboard,
      profitability, shopping-list) as exactly one of: `non-stub handler deployed`,
      `stub handler deployed`, or `no handler deployed`
    - For every referenced audit finding, cite file path + start/end line numbers confirming
      current behavior; flag any endpoint with no non-stub handler as a backend gap
    - State whether `decoration_catering_module.dart` (go_router DC_Module) is dead code with
      path + line-number evidence; record the `getEventProfitability` formula (path + lines) and
      confirm or flag it as unverified
    - Confirm the Phase-0-pending field/endpoint names used downstream: the inventory rental-price
      API field name and the atomic inventory-delta endpoint; flag any unclassifiable item as
      `unverified` with a stated reason
    - **If any Ground Truth/audit claim contradicts the live code → STOP and report the
      discrepancy; do not route around it**
    - _Requirements: 1.12, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

- [x] 2. Phase 0 checkpoint — list artifact, output `PHASE 0 COMPLETE — AWAITING APPROVAL`, stop and wait for `APPROVED`
  - Ensure the Verification_Report is complete and no source files changed, ask the user if questions arise.

- [ ] 3. Phase 1 — Reachability (cross-cutting infra, sidebar, barrel, navigation, routes, landing)
  - [x] 3.1 Add the tenant-context resolver and RID generator (cross-cutting infra for all phases)
    - Implement a single resolver returning `Tenant_Id` from `SessionManager.currentBusinessId`;
      when null/empty it returns a `TenantContextUnavailable` error and performs no DC data access;
      the literal `vendorId: 'SYSTEM'` is never used
    - Implement an RID generator producing `{tenantId}-{timestamp_ms}-{uuid_v4_short}` for all new
      DC entity ids; add the `MoneyMath` half-up paise helper seam used by later phases
    - _Requirements: 1.1, 1.2, 1.5, 1.13_

  - [ ]* 3.2 Write property test for tenant scoping
    - **Property 1: Tenant scoping, never 'SYSTEM'**
    - **Validates: Requirements 1.1, 1.2**

  - [ ]* 3.3 Write property test for fail-safe on missing tenant
    - **Property 2: Fail-safe on missing tenant**
    - **Validates: Requirements 1.13**

  - [ ]* 3.4 Write property test for RID identifier format
    - **Property 3: RID identifier format**
    - **Validates: Requirements 1.5**

  - [x] 3.5 Add the `BusinessType.decorationCatering` case to `Sidebar_Configuration`
    - Add an explicit `case BusinessType.decorationCatering` in `_getSectionsForBusiness` returning
      a new `_getDecorationCateringSections()`; do NOT fall through to `_getRetailSections()`
    - Return exactly the 14 sections (Dashboard, Bookings, Calendar, Quotes, Catering/Menu,
      Decoration/Themes, Staff, Attendance, Vendors & Payments, Inventory/Rentals, Shopping List,
      Billing, Profitability, Reports), each with a non-empty label and a sidebar-reachable target
    - Do not modify any other `BusinessType` branch
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 3.6 Write property test for non-DC sidebar preservation
    - **Property 5: Non-DC sidebar preservation**
    - **Validates: Requirements 3.4**

  - [ ]* 3.7 Write property test for well-formed DC sidebar sections
    - **Property 6: DC sidebar sections are well-formed** (also assert exactly the 14 named sections)
    - **Validates: Requirements 3.2, 3.3**

  - [x] 3.8 Complete the `DC_Barrel` exports
    - Add the four missing exports to `decoration_catering.dart`: `dc_event_detail_screen`,
      `dc_quote_conversion_screen`, `dc_staff_attendance_screen`, `dc_vendor_rating_dialog`
    - Confirm zero unresolved-import/missing-symbol analyzer errors
    - _Requirements: 4.1_

  - [x] 3.9 Wire `Sidebar_Navigation_Handler.getScreenForItem` for all 14 DC ids
    - Map each enumerated DC id to its single DC screen, constructed with the session-resolved
      `Tenant_Id`; the `/dc/vendors`-class id resolves to `DcVendorPaymentsScreen`, not
      `DcStaffScreen`; unknown ids fall through to `_PlaceholderScreen` without throwing
    - _Requirements: 4.2, 4.3, 4.4, 5.4_

  - [ ]* 3.10 Write property test for DC navigation resolution
    - **Property 7: DC navigation resolution**
    - **Validates: Requirements 4.2, 4.3, 4.4**

  - [x] 3.11 Register the eight guarded DC routes and fix the redirect loop
    - In `App_Router`/`legacy_routes`, register `dc_calendar`, `dc_quotes`, `dc_profitability`,
      `dc_shopping_list`, `dc_vendor_payments`, `dc_event_detail`, `dc_quote_conversion`,
      `dc_staff_attendance`, each wrapped in both `Vendor_Role_Guard` and
      `Business_Guard(allowedTypes: [decorationCatering])`
    - Make `DC_Routes` redirect resolve in a single pass (eliminate the self-redirect loop)
    - _Requirements: 5.1, 5.2, 5.3, 5.6_

  - [ ]* 3.12 Write property test for DC route guard wrapping
    - **Property 10: DC route guard wrapping**
    - **Validates: Requirements 5.2**

  - [ ]* 3.13 Write property test for single-pass route redirect
    - **Property 9: Single-pass route redirect**
    - **Validates: Requirements 5.6**

  - [x] 3.14 Fix post-login landing to `DcDashboardScreen`
    - When a `decorationCatering` tenant authenticates, render `DcDashboardScreen` within 3s; if the
      resolved route is anything else, fall back to `DcDashboardScreen`; a render failure keeps the
      tenant on the current screen with a "could not load" error
    - _Requirements: 6.1, 6.3, 6.4_

  - [ ]* 3.15 Write reachability property + integration test for all 16 DC screens
    - **Property 11: All DC screens reachable** (≤ 2 navigation actions from `DcDashboardScreen`)
    - Add an integration test: login as DC tenant → land on dashboard → navigate to each of the 16
      screens via sidebar → assert primary content renders without crash
    - **Validates: Requirements 6.2**

- [x] 4. Phase 1 checkpoint — list files, run `flutter analyze` on touched files, output `PHASE 1 COMPLETE — AWAITING APPROVAL`, stop and wait for `APPROVED`
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Phase 2 — Capability & Isolation Reconciliation (sign-off gated)
  - [x] 5.1 Implement the capability reconciliation decision (Path A / Path B) behind sign-off
    - If Path A is signed off: register the capabilities the DC_System actually uses
      (inventory-for-rentals, billing) and remove the "service-only" comment from the capability
      config; if Path B is signed off: attach a capability guard to the retail-only
      `SidebarMenuItem`s BuyFlow, Stock, Purchase so they are unreachable for DC
    - If neither path is signed off: make no capability change and surface that sign-off is required
    - Report the integer count (≥ 0) of `SidebarMenuItem`s that both lack a `capability:` field and
      fall outside DC scope
    - **STOP and request sign-off before changing the capability config**
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 5.2 Attach `Business_Guard` to routes determined out of DC scope
    - For any route outside DC scope, attach `Business_Guard` so DC access is denied
    - _Requirements: 7.6_

  - [ ]* 5.3 Write property test for guard denial of out-of-scope access
    - **Property 8: Guard denial for out-of-scope access**
    - **Validates: Requirements 5.5, 7.6**

  - [ ]* 5.4 Write unit tests for capability reconciliation paths
    - Path A removes the service-only comment; Path B guards BuyFlow/Stock/Purchase; no-sign-off
      makes no change and surfaces sign-off-required; the out-of-scope capability-less count is
      reported
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 6. Phase 2 checkpoint — list files, run `flutter analyze`, output `PHASE 2 COMPLETE — AWAITING APPROVAL`, stop and wait for `APPROVED`
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Phase 3 — Dashboard Quick Actions & Alerts
  - [x] 7.1 Add the DC branch to `Quick_Actions`
    - Provide exactly four activatable controls — New Booking, New Quote, Add Staff, Menu/Package —
      each navigating to its corresponding screen when activated
    - _Requirements: 8.1_

  - [x] 7.2 Add the DC branch to `Alerts_Widget` with repository-derived counts
    - Display three integer counts sourced only from `DC_Repository`: events within the next 7 days
      (today inclusive → +7 days), bookings with advance pending, and rentals due on/before today;
      a zero count renders as `0`; a repository failure renders an error indication (no stale/default)
    - _Requirements: 8.2, 8.3, 8.4, 8.5_

  - [x] 7.3 Populate `DcDashboardScreen` from `dcStatsProvider`
    - Ensure every displayed statistic traces to a `dcStatsProvider` value (no placeholder branches)
    - _Requirements: 8.6_

  - [ ]* 7.4 Write property test for alert counts derived from repository data
    - **Property 12: Alert counts derive from repository data**
    - **Validates: Requirements 8.2, 8.4**

  - [ ]* 7.5 Write unit tests for quick actions and alert rendering
    - Exactly four DC quick actions each navigate to their screen (8.1); zero-count renders `0`
      (8.3); repository failure renders an error indication (8.5); each dashboard statistic traces
      to a `dcStatsProvider` value (8.6)
    - _Requirements: 8.1, 8.3, 8.5, 8.6_

- [x] 8. Phase 3 checkpoint — list files, run `flutter analyze`, output `PHASE 3 COMPLETE — AWAITING APPROVAL`, stop and wait for `APPROVED`
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. Phase 4 — Rental Lifecycle Correctness
  - [x] 9.1 Populate `rentalPrice` from the API in `_inventoryFromJson`
    - Map `rentalPrice` from the confirmed API field via `_paisa(...)`; if missing/null, default to
      `0`, keep all other fields, and surface a non-blocking "rentalPrice unavailable" indication
    - _Requirements: 9.1, 9.2_

  - [x] 9.3 Implement the per-event rental lifecycle state machine and `EventRental` model
    - Add `RentalState { available, rentedOut, returned, returnedWithDamage }` and `EventRental`
      (RID-generated ids, integer-paise money); rent-out quantity ∈ `[1, availableOnHand]`, return
      damaged-or-lost ∈ `[0, rentedQty]`; out-of-bounds entries are rejected and the previous state
      retained
    - _Requirements: 9.3, 9.4, 9.5, 9.6_

  - [x] 9.5 Replace `adjustInventory` read-all-then-PUT with an atomic delta call
    - Use the confirmed atomic delta endpoint; on failure leave stored quantity unchanged and
      surface an error; if the backend has no atomic delta, document the backend gap (no silent
      fallback)
    - _Requirements: 9.7, 9.8, 9.9_

  - [ ]* 9.2 Write property test for rentalPrice mapping
    - **Property 13: rentalPrice mapping**
    - **Validates: Requirements 9.1**

  - [ ]* 9.4 Write property test for rental quantity bounds and state
    - **Property 14: Rental quantity bounds and state**
    - **Validates: Requirements 9.3, 9.4, 9.5, 9.6**

  - [ ]* 9.6 Write integration test for the rental flow
    - Rent out an item, return it (with and without damage); assert quantity and state transitions
      and that the adjustment used the atomic delta path
    - _Requirements: 9.3, 9.4, 9.5, 9.6, 9.7_

- [x] 10. Phase 4 checkpoint — list files, run `flutter analyze`, output `PHASE 4 COMPLETE — AWAITING APPROVAL`, stop and wait for `APPROVED`
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Phase 5 — Discount/Tax Unification & Advance/Ledger Correctness
  - [x] 11.1 Unify the percentage-based discount/tax money model (integer paise)
    - Implement `computeQuoteTotalPct` in `DecorationCateringBusinessRules` and align
      `dc_billing_screen.dart`: `discountAmount = round2(subtotal*discountPct/100)`,
      `postDiscount = subtotal - discountAmount`, `gstAmount = round2(postDiscount*gstPct/100)`,
      `grandTotal = postDiscount + gstAmount`, GST applied to the post-discount subtotal with
      identical rate/rounding in both call sites so grand totals match to the paise
    - _Requirements: 10.1, 10.3, 10.4_

  - [x] 11.8 Add `AdvanceConfig`, advance computation, and `recordPayment` on conversion
    - Replace "advance defaults to 100%" with a configurable advance percentage (default 50%,
      accepted range 30–50% inclusive); `advanceAmount = round2(total*advancePct/100)` validated
      `0 ≤ advanceAmount ≤ total`; out-of-bounds advance rejects the conversion, creates no booking,
      and leaves the source quote in its pre-conversion state
    - On conversion, call `DcRepository.recordPayment` against `/dc/events/{id}/payments`; if it
      fails, reject the conversion, create no booking, leave the ledger unchanged, present a "could
      not record advance" error
    - _Requirements: 11.1, 11.3, 11.4, 11.5, 11.6, 11.7_

  - [x] 11.3 Add the idempotent absolute-to-percentage discount migration
    - Convert each stored absolute discount to `discountPct = round2(absDiscount/subtotal*100)` and
      persist it in the percentage model; make the migration idempotent (zero records changed after
      the first run); a DynamoDB schema change requires a Mini_Approval_Gate
    - _Requirements: 10.2, 1.8_

  - [x] 11.6 Add discount-range validation
    - A discount percentage outside `[0, 100]` is rejected, the previous valid value retained, and
      an out-of-range error returned; advance-config range error retained on `[30,50]` violation
    - _Requirements: 10.5, 11.2_

  - [ ]* 11.2 Write property test for discount/tax model equivalence
    - **Property 15: Discount/tax model equivalence**
    - **Validates: Requirements 10.1, 10.3, 10.4**

  - [ ]* 11.4 Write property test for absolute-to-percentage discount conversion
    - **Property 16: Absolute-to-percentage discount conversion**
    - **Validates: Requirements 10.2**

  - [ ]* 11.5 Write property test for migration idempotence
    - **Property 4: Migration idempotence**
    - **Validates: Requirements 1.8**

  - [ ]* 11.7 Write property test for out-of-range discount rejection
    - **Property 17: Out-of-range discount rejection**
    - **Validates: Requirements 10.5**

  - [ ]* 11.9 Write property test for advance amount computation
    - **Property 18: Advance amount computation**
    - **Validates: Requirements 11.3, 11.4**

  - [ ]* 11.10 Write property test for advance configuration range
    - **Property 19: Advance configuration range**
    - **Validates: Requirements 11.2**

  - [ ]* 11.11 Write integration test for the quote→booking conversion flow
    - Valid advance → booking created + ledger payment recorded; forced `recordPayment` failure →
      no booking, quote unchanged, ledger unchanged
    - _Requirements: 11.5, 11.6, 11.7_

- [x] 12. Phase 5 checkpoint — list files, run `flutter analyze`, output `PHASE 5 COMPLETE — AWAITING APPROVAL`, stop and wait for `APPROVED`
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 13. Phase 6 — Data Validation & JSON Robustness
  - [x] 13.1 Clamp discount/GST inputs and gate Generate Invoice
    - Discount input clamps to `[0, 100]`; GST input bounds to `[0, 28]`; the "Generate Invoice"
      action stays disabled while no event is selected
    - _Requirements: 12.1, 12.2, 12.5_

  - [x] 13.3 Validate line-item quantity and rate inputs
    - Quantity `≤ 0`/empty/non-numeric and rate `< 0`/empty/non-numeric are rejected, the previous
      valid value retained, and an error indication presented
    - _Requirements: 12.3, 12.4_

  - [x] 13.5 Read stored payment method in `_expenseFromJson` / `_vendorPaymentFromJson`
    - Map to the stored `paymentMode`/`paymentMethod` instead of hardcoding `PaymentMethod.cash`; a
      missing/unrecognized method applies a defined default and surfaces a non-blocking indication
    - _Requirements: 12.8, 12.10_

  - [x] 13.7 Harden `_bookingFromJson` with null-safe parsing and map/validate `eventEndDate`
    - Use null-safe parsing with defined defaults; a malformed booking record is skipped (valid
      records preserved), an error indication surfaced, no screen crash; add `eventEndDate` to
      `EventBooking` and propagate through booking form, calendar, and profitability;
      `eventEndDate < eventDate` is rejected with an error
    - _Requirements: 12.6, 12.7, 12.9, 12.11_

  - [ ]* 13.2 Write property test for percentage field clamping
    - **Property 20: Percentage field clamping**
    - **Validates: Requirements 12.1, 12.2**

  - [ ]* 13.4 Write property test for line-item numeric input validation
    - **Property 21: Line-item numeric input validation**
    - **Validates: Requirements 12.3, 12.4**

  - [ ]* 13.6 Write property test for payment-method mapping
    - **Property 22: Payment-method mapping**
    - **Validates: Requirements 12.8**

  - [ ]* 13.8 Write property test for booking parse robustness
    - **Property 23: Booking parse robustness**
    - **Validates: Requirements 12.7, 12.9**

  - [ ]* 13.9 Write property test for event date ordering
    - **Property 24: Event date ordering**
    - **Validates: Requirements 12.11**

- [x] 14. Phase 6 checkpoint — list files, run `flutter analyze`, output `PHASE 6 COMPLETE — AWAITING APPROVAL`, stop and wait for `APPROVED`
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 15. Phase 7 — Optional Offline-First Sync (sign-off gated; create no artifact until sign-off recorded)
  - [x] 15.1 Add local Drift tables for the approved in-scope DC entities
    - Only after documented sign-off naming the in-scope entities (events/bookings, staff, vendors,
      inventory, quotes, payments) and excluding all others: add a Drift table per named entity
      carrying the retail vertical's sync columns (last-modified timestamp, sync status, soft-delete
      flag); a schema change requires a Mini_Approval_Gate
    - **STOP and request sign-off before creating any Phase 7 artifact**
    - **SKIPPED — no sign-off recorded; no artifacts created**
    - _Requirements: 13.1, 13.2_

  - [x] 15.2 Wire `DC_Sync_Handler` / `DC_Ws_Handler` to the approved tables only
    - Read from/write to only the tables defined in 15.1; no sync operation references a table
      absent from that set
    - **SKIPPED — no sign-off recorded**
    - _Requirements: 13.3_

  - [x] 15.3 Implement optimistic local write + FIFO sync queue with bounded retry
    - Persist each create/update/delete to the local Drift table immediately and enqueue one ordered
      sync entry; process the queue FIFO when connectivity is available; a failed entry is retained,
      the local record preserved, retried up to 5 times, then marked failed-sync without discarding
      the local change
    - **SKIPPED — no sign-off recorded**
    - _Requirements: 13.4, 13.5, 13.6_

  - [ ]* 15.4 Write property test for sync referencing only approved tables
    - **Property 27: Sync references only approved tables**
    - **Validates: Requirements 13.3**

  - [ ]* 15.5 Write property test for optimistic write enqueuing one ordered entry
    - **Property 28: Optimistic write enqueues one ordered entry**
    - **Validates: Requirements 13.4, 13.5**

  - [ ]* 15.6 Write property test for bounded retry preserving the local change
    - **Property 29: Bounded retry preserves local change**
    - **Validates: Requirements 13.6**

- [x] 16. Phase 7 checkpoint — list files, run `flutter analyze`, output `PHASE 7 COMPLETE — AWAITING APPROVAL`, stop and wait for `APPROVED`
  - **Phase 7 SKIPPED — no sign-off recorded. No artifacts created. Proceeding to Phase 8.**

- [ ] 17. Phase 8 — Polish & Dead-Code Disposition
  - [x] 17.1 Add tooltips and assistive-tech semantic labels to icon-only DC buttons
    - Every icon-only DC button exposes a non-empty tooltip and a non-empty semantic label
      describing its action
    - _Requirements: 14.1, 14.2_

  - [x] 17.3 Raise sub-10px DC status badge font sizes to 10–11px
    - Any DC status badge whose font size would be below 10px is set to a value in `[10, 11]` px
    - _Requirements: 14.3_

  - [x] 17.5 Dispose of `advanceForfeitedOnCancel` and the go_router `DC_Module` per recorded sign-off
    - Per the recorded sign-off decision, wire `advanceForfeitedOnCancel` into the cancellation flow
      or remove it; delete the dead `DC_Module` or retain it with a documented rationale; any
      deletion requires explicit recorded sign-off first and the code stays unchanged until then
    - **STOP and request sign-off before any deletion**
    - _Requirements: 14.4, 14.5, 14.6, 14.7_

  - [ ]* 17.2 Write property test for icon-only button accessibility
    - **Property 25: Icon-only button accessibility**
    - **Validates: Requirements 14.1, 14.2**

  - [ ]* 17.4 Write property test for the status badge font floor
    - **Property 26: Status badge font floor**
    - **Validates: Requirements 14.3**

- [x] 18. Phase 8 final checkpoint — full verification
  - Re-run the full property-test suite (P1–P26, plus P27–P29 if Phase 7 was approved) and all
    unit/integration/widget tests; confirm zero variance between `computeQuoteTotal` and
    `dc_billing_screen.dart` grand totals
  - Run `flutter analyze` across all touched files; confirm zero unresolved-import/missing-symbol
    errors and no new warnings; confirm no other business type's code/config/sidebar was modified
  - List files created/modified/deleted, output `PHASE 8 COMPLETE — AWAITING APPROVAL`, stop and
    wait for `APPROVED`
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks and can be skipped for a faster MVP; core
  implementation sub-tasks are never optional.
- Each task references specific requirement clauses for traceability; each property test references
  its design property number and the requirement clause it validates.
- Phases execute strictly in order with a human approval gate after each (`PHASE N COMPLETE —
  AWAITING APPROVAL` → wait for `APPROVED`). Phase 2 (capability path), Phase 7 (offline sync), and
  Phase 8 deletions are sign-off gated and stay conditional until sign-off is recorded.
- Cross-cutting constraints (Requirement 1) are implemented once in task 3.1 (tenant resolver, RID
  generator, MoneyMath paise seam) and reused by every later phase.
- Money in touched code is integer paise via the `_paisa`/`_toPaisa` boundary and `MoneyMath`; no
  new `double` currency types are introduced. The DC 18% GST default is preserved.
- Migrations are idempotent; DynamoDB schema changes require a Mini_Approval_Gate; deletions require
  explicit recorded sign-off.
- Property tests use `package:glados`, one test per property, minimum 100 generated cases, each
  tagged `Feature: decoration-catering-vertical-remediation, Property {n}: {text}`.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["3.1"] },
    { "id": 2, "tasks": ["3.5", "3.8", "3.9", "3.11", "3.14"] },
    { "id": 3, "tasks": ["3.2", "3.3", "3.4", "3.6", "3.7", "3.10", "3.12", "3.13", "3.15"] },
    { "id": 4, "tasks": ["5.1", "5.2"] },
    { "id": 5, "tasks": ["5.3", "5.4"] },
    { "id": 6, "tasks": ["7.1", "7.2", "7.3"] },
    { "id": 7, "tasks": ["7.4", "7.5"] },
    { "id": 8, "tasks": ["9.1", "9.3"] },
    { "id": 9, "tasks": ["9.5"] },
    { "id": 10, "tasks": ["9.2", "9.4", "9.6"] },
    { "id": 11, "tasks": ["11.1", "11.8"] },
    { "id": 12, "tasks": ["11.3", "11.6"] },
    { "id": 13, "tasks": ["11.2", "11.4", "11.5", "11.7", "11.9", "11.10", "11.11"] },
    { "id": 14, "tasks": ["13.1", "13.3", "13.5"] },
    { "id": 15, "tasks": ["13.7"] },
    { "id": 16, "tasks": ["13.2", "13.4", "13.6", "13.8", "13.9"] },
    { "id": 17, "tasks": ["15.1"] },
    { "id": 18, "tasks": ["15.2", "15.3"] },
    { "id": 19, "tasks": ["15.4", "15.5", "15.6"] },
    { "id": 20, "tasks": ["17.1", "17.3", "17.5"] },
    { "id": 21, "tasks": ["17.2", "17.4"] }
  ]
}
```
