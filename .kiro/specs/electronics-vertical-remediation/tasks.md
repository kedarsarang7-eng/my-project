# Implementation Plan

## Overview

This plan remediates the **Electronics** (`BusinessType.electronics`) vertical across nine
STOP-GATE phases (Phase 0 read-only investigation through Phase 8 final regression), using
the bug-condition methodology from `design.md`. Each defect family is fixed only after its
bug is first demonstrated on the UNFIXED code, and the global preservation baseline proves
every non-Electronics path and Electronics happy path stays byte-for-byte identical.

Property numbers below match the design's "Correctness Properties" exactly: **Property 1**
is the global Preservation property; **Properties 2–10** are the per-phase bug-condition /
expected-behavior properties. PBT task labels use the `**Property N: Type**` format so hover
status resolves against those properties.

The remediation is additive and tenant-isolated. No other business type's code is altered;
every file shared with `mobileShop`/`computerShop` is flagged in the task that touches it and
its non-Electronics branches are preserved. All new code honors the non-negotiable
constraints: integer-paise money, RID-patterned ids
(`{tenantId}-{timestamp_ms}-{uuid_v4_short}`), tenant-scoped queries, idempotent migrations,
and no schema change / hard delete without sign-off.

## Tasks

> Bugfix methodology: each phase first surfaces counterexamples on the UNFIXED code
> (bug-condition exploration), then locks in existing behavior (preservation), then applies
> the fix, then re-runs both. Property numbers below match the design's "Correctness
> Properties" exactly (Property 1 = global Preservation; Properties 2–10 = per-phase). All
> new code honors the non-negotiable constraints: integer-paise money, RID-patterned ids
> (`{tenantId}-{timestamp_ms}-{uuid_v4_short}`), tenant-scoped queries, idempotent
> migrations, no schema change / hard delete without sign-off.
>
> Tests are Dart/`flutter test`; property-based cases use generated `(businessType, input)`
> pairs (e.g. via repeated randomized generation) per the design's Testing Strategy. Each
> phase is a STOP GATE: after the phase, list touched files, run `flutter analyze`, report
> results, output `PHASE N COMPLETE — AWAITING APPROVAL`, then halt for `APPROVED`.

---

### Phase 0 — Investigation & reachability (read-only STOP GATE)

- [x] 1. Perform Phase 0 read-only investigation and record findings
  - **Property 2: Phase 0** - Investigation gates resolved before action
  - **READ-ONLY**: No behavior changes in this phase — produce a documented, evidence-based findings record only
  - 2.1 (route mounting): Grep `core/routing/legacy_routes.dart` and confirm each of `/computer-shop/warranty`, `/computer-shop/serial-history`, `/computer-shop/multi-unit`, `/job/create`, `/job/status`, `/job/deliver` is a live `GoRoute` mounted on the active router (`MaterialApp.router`/`GoRouter`); reconcile the sibling-audit "GoRouter not mounted" note. Block Phase 2 route edits until confirmed
  - 2.2 (access decision per screen): Document, per screen, grant-by-allow-list vs grant-by-capability. Confirm Electronics holds `useIMEI` + `useWarranty` (warranty/serial-history/imei-tracking need only allow-list widening — D6) and lacks `useMultiUnit` (multi-unit needs explicit grant or park); flag `useBuyback`/`useExchange` parked
  - 2.3 (`getImeiTrackingStatement` tenant scope): Confirm whether `userId` is the correct tenant boundary or a `vendorId` filter is required (D4); require a tenant-scoped (non-`SYSTEM`) filter before wiring the screen in Phase 2
  - 2.4 (route-file location): Record the live file (`core/routing/legacy_routes.dart`) and ignore the stale `app/routes.dart` citations (D3)
  - **DELIVERABLE**: Append a `phase-0-findings` note to the spec; this property is satisfied when each gate has a documented, evidence-based answer that confirms or refutes the dependent assumption
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 2. STOP GATE — list files inspected, run `flutter analyze`, report, output `PHASE 0 COMPLETE — AWAITING APPROVAL`, halt for `APPROVED`

---

### Global preservation baseline (write before any fix)

- [x] 3. Write global preservation property test
  - **Property 1: Preservation** - Non-Electronics and Electronics-happy-path behavior unchanged
  - **IMPORTANT**: Follow observation-first methodology — observe behavior on UNFIXED code, then lock it in
  - **GOAL**: Capture a pre-change behavioral snapshot so every later phase can prove `F(X) = F'(X)` for all `isBugCondition(input) = false` inputs
  - Observe on UNFIXED code: `getSectionsForBusinessType(mobileShop)` and `(computerShop)` section output; route-guard allow/deny decisions; capability sets; dashboard alert counts for other verticals; billing result for a unique, valid Electronics serial
  - Write a property-based test generating random `(businessType, input)` pairs where `businessType != electronics` (plus Electronics happy-path unique-valid serials) and assert sidebar sections, route-guard decisions, capability sets, dashboard counts, and billing results equal the pre-change snapshot
  - Include the specific preservation cases: mobileShop/computerShop sidebars (3.1), mobileShop serial validator + `contains('mobile')` async duplicate check (3.2), warranty `0..120` validation (3.3, D2), Electronics MRP/18%/`gstEditable false`/required-fields config (3.4), unique-valid Electronics happy path (3.5), other verticals' dashboards/guards/RBAC (3.6, 3.7)
  - Run on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms the baseline to preserve through every phase)
  - Mark complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

---

### Phase 1 — Serial/IMEI uniqueness & required-at-billing (CRITICAL)

- [x] 4. Write Phase 1 bug-condition exploration test
  - **Property 3: Bug Condition** - Serial/IMEI uniqueness and required-at-billing
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists. DO NOT fix the test or the code when it fails
  - **NOTE**: This test encodes the expected behavior — it validates the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate blank and duplicate serials are accepted today
  - **Scoped PBT Approach**: Combine concrete failing cases with a scoped property: (a) blank serial on an Electronics device line, (b) the same IMEI billed twice in one tenant; plus a property over a random serial multiset within a tenant asserting no two active `IMEISerials` records share a serial after billing
  - Bug condition (from design): `BillLineSave` where `businessType == electronics AND isDeviceLine AND (serial blank OR duplicateOrSold(serial, tenantId))`
  - Expected behavior asserted: blank rejected with "serial required for electronics"; duplicate/already-sold rejected against tenant-scoped `IMEISerials` `{userId, imeiOrSerial}`; unique non-blank accepted unchanged
  - Run on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS — `billing_service.dart` stub (`// Strict 1:1 validation could go here`) accepts duplicates and `manual_item_entry_sheet.dart` `null` validator accepts blanks for electronics
  - Document counterexamples (e.g. "calculate: blank serial saved silently"; "duplicate IMEI billed twice accepted")
  - _Requirements: 2.5, 2.6, 2.7_

- [x] 5. Fix Phase 1 — serial/IMEI uniqueness and required-at-billing

  - [x] 5.1 Enforce tenant-scoped serial uniqueness in billing
    - In `features/billing/services/billing_service.dart`, replace the electronics IMEI stub with a tenant-scoped uniqueness check via `IMEISerialRepository.getByNumber(tenantId, serial)` (DB unique key `{userId, imeiOrSerial}` is the backstop); reject when an existing record is in a sold/active conflict status with a clear validation error; mirror the proven `mobileShop` pattern. No schema change
    - _Bug_Condition: isBugCondition(BillLineSave) where electronics device line AND duplicateOrSold(serial, tenantId)_
    - _Expected_Behavior: reject duplicate/already-sold serial; accept unique non-blank unchanged (Property 3)_
    - _Preservation: mobileShop/computerShop branches and SKU path untouched (3.1, 3.2, 3.5)_
    - _Requirements: 2.5_

  - [x] 5.2 Require non-blank serial for Electronics device lines
    - In `features/billing/presentation/widgets/manual_item_entry_sheet.dart`, set the serial-field `validator` to non-empty-required for `BusinessType.electronics` device lines (currently `null` — D1), reusing the mobileShop message style; treat `serialNo` as conditionally required for Electronics device lines at the validation layer (config field stays optional — no schema/config change)
    - _Bug_Condition: isBugCondition(BillLineSave) where electronics device line AND serial blank_
    - _Expected_Behavior: blank serial rejected with electronics validation message (Property 3)_
    - _Preservation: mobileShop validator + clothing null path + `0..120` warranty validator untouched (3.2, 3.3)_
    - _Requirements: 2.6, 2.7_

  - [x] 5.3 Verify Phase 1 bug-condition exploration test now passes
    - **Property 3: Expected Behavior** - Serial/IMEI uniqueness and required-at-billing
    - **IMPORTANT**: Re-run the SAME test from task 4 — do NOT write a new test
    - **EXPECTED OUTCOME**: Test PASSES (blank and duplicate serials now rejected; unique accepted)
    - _Requirements: 2.5, 2.6, 2.7_

  - [x] 5.4 Verify global preservation test still passes
    - **Property 1: Preservation** - Non-Electronics and Electronics-happy-path behavior unchanged
    - **IMPORTANT**: Re-run the SAME test from task 3 — do NOT write a new test
    - **EXPECTED OUTCOME**: Tests PASS (mobileShop/computerShop billing + entry-sheet branches and the unique-valid happy path unchanged)
    - _Requirements: 3.1, 3.2, 3.3, 3.5, 3.8_

- [x] 6. STOP GATE — list touched files, run `flutter analyze`, report, output `PHASE 1 COMPLETE — AWAITING APPROVAL`, halt for `APPROVED`

---

### Phase 2 — Reachability of device screens (CRITICAL)

- [x] 7. Write Phase 2 bug-condition exploration test
  - **Property 4: Bug Condition** - Device screens reachable for Electronics
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists. DO NOT fix the test or the code when it fails
  - **NOTE**: Encodes expected behavior; validates the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that Electronics is denied/orphaned on built device screens
  - **Scoped PBT Approach**: Concrete cases — navigate Electronics to `/computer-shop/warranty` and `/computer-shop/serial-history` (expect deny); resolve a route/sidebar id for `ImeiTrackingStatementScreen` (expect none); plus a scoped property over device targets {Warranty, SerialHistory, ImeiTracking, ServiceJob} asserting Electronics resolves to render
  - Bug condition (from design): `ScreenNavigation` where `businessType == electronics AND target IN {Warranty, SerialHistory, ImeiTracking, ServiceJob} AND NOT reachableForElectronics(target)`
  - Expected behavior asserted: each device screen renders for Electronics (never deny), backed by a tenant-scoped query
  - Run on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS — `BusinessGuard([computerShop, mobileShop])` denies Electronics; `ImeiTrackingStatementScreen` has no route/sidebar entry
  - Document counterexamples (e.g. "Warranty: 'available for Computer Shop, Mobile Phone Shop'"; "IMEI tracking: no route id resolves")
  - _Requirements: 2.8, 2.9, 2.10_

- [x] 8. Fix Phase 2 — make device screens reachable for Electronics

  - [x] 8.1 Widen guards for Warranty / Serial-History (and decide Multi-Unit)
    - In `core/routing/legacy_routes.dart`, add `BusinessType.electronics` to BOTH the `BusinessGuard.allowedTypes` AND the inner `CapabilityGate.allowedTypes` for `/computer-shop/warranty` and `/computer-shop/serial-history` (D6); update `denialMessage` strings to include Electronics. For `/computer-shop/multi-unit` apply the Phase 0 decision — either grant `useMultiUnit` to electronics in `business_capability.dart` and widen both allow-lists, or park Multi-Unit and document the deferral
    - _Bug_Condition: isBugCondition(ScreenNavigation) where electronics AND target IN {Warranty, SerialHistory, MultiUnit}_
    - _Expected_Behavior: screen renders for electronics (Property 4)_
    - _Preservation: allow-lists only extended, never narrowed; computerShop/mobileShop access preserved (3.1, 3.6)_
    - _Requirements: 2.8_

  - [x] 8.2 Expose ImeiTrackingStatementScreen via a real route
    - Add a new `GoRoute` (e.g. `/electronics/imei-tracking`) in `core/routing/legacy_routes.dart` wrapping `ImeiTrackingStatementScreen` in `VendorRoleGuard(viewInvoices) → BusinessGuard([electronics, ...]) → CapabilityGate(useIMEI)`, backed by the tenant-scoped `getImeiTrackingStatement` confirmed in Phase 0 (2.3); matching sidebar id added in Phase 4
    - _Bug_Condition: isBugCondition(ScreenNavigation) where electronics AND target = ImeiTracking_
    - _Expected_Behavior: ImeiTracking renders via real route backed by tenant-scoped query (Property 4)_
    - _Preservation: no other route altered; query tenant-scoped, non-`SYSTEM` (3.8)_
    - _Requirements: 2.9_

  - [x] 8.3 Confirm Service/Repair job reachability
    - No route change — `/job/create`, `/job/status`, `/job/deliver` already allow Electronics + `manageStaff` (D7); they will be surfaced via the Phase 4 sidebar entry
    - _Bug_Condition: isBugCondition(ScreenNavigation) where electronics AND target = ServiceJob_
    - _Expected_Behavior: service/repair jobs reachable via consistent navigation (Property 4)_
    - _Preservation: `/job/*` guards unchanged (3.1)_
    - _Requirements: 2.10_

  - [x] 8.4 Verify Phase 2 bug-condition exploration test now passes
    - **Property 4: Expected Behavior** - Device screens reachable for Electronics
    - **IMPORTANT**: Re-run the SAME test from task 7 — do NOT write a new test
    - **EXPECTED OUTCOME**: Test PASSES (all device targets render for Electronics)
    - _Requirements: 2.8, 2.9, 2.10_

  - [x] 8.5 Verify global preservation test still passes
    - **Property 1: Preservation** - Non-Electronics and Electronics-happy-path behavior unchanged
    - **IMPORTANT**: Re-run the SAME test from task 3 — do NOT write a new test
    - **EXPECTED OUTCOME**: Tests PASS (computerShop/mobileShop guard decisions unchanged; unrelated types still denied)
    - _Requirements: 3.1, 3.6_

- [x] 9. STOP GATE — list touched files, run `flutter analyze`, report, output `PHASE 2 COMPLETE — AWAITING APPROVAL`, halt for `APPROVED`

---

### Phase 3 — Warranty & serial data integrity at point of sale (HIGH)

- [x] 10. Write Phase 3 bug-condition exploration test
  - **Property 5: Bug Condition** - Warranty/serial data integrity at point of sale
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists. DO NOT fix the test or the code when it fails
  - **NOTE**: Encodes expected behavior; validates the fix when it passes after implementation
  - **GOAL**: Surface that warranty expiry is not computed at POS, no `IMEISerials` record is created, and serial-level stock is not decremented
  - **Scoped PBT Approach**: Property over random `warrantyMonths ∈ 0..120` and sale dates — assert `warrantyEndDate == saleDate + warrantyMonths`, exactly one `IMEISerials` record per unit sold, and serial stock decremented once; include `0` and `120` boundaries
  - Bug condition (from design): `BillLineSave` where `businessType == electronics AND isDeviceLine AND NOT (warrantyExpiryComputed(input) AND serialInventoryLinked(input))`
  - Expected behavior asserted: warranty expiry persisted as single source of truth, RID-patterned tenant-scoped `IMEISerials` record created/linked, serial-level stock decremented
  - Run on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS — no `warrantyEndDate` written at POS, no `IMEISerials` record created from the sale, stock decremented by SKU only
  - Document counterexamples (e.g. "sale with warrantyMonths=12: no warrantyEndDate persisted; no IMEISerials row")
  - _Requirements: 2.11, 2.12, 2.13_

- [x] 11. Fix Phase 3 — warranty & serial integrity at POS

  - [x] 11.1 Compute and persist warranty expiry at POS
    - In the Electronics sale path (`billing_service.dart`), compute `warrantyEndDate = sale_date + warrantyMonths` and persist to `IMEISerials` (`warrantyStartDate`, `warrantyEndDate`, `isUnderWarranty`) as the single source of truth feeding `getImeiTrackingStatement`; columns already exist — no schema change
    - _Bug_Condition: isBugCondition(BillLineSave) where electronics device line AND NOT warrantyExpiryComputed_
    - _Expected_Behavior: warrantyEndDate = saleDate + warrantyMonths persisted (Property 5)_
    - _Preservation: bill-line write for non-device lines and mobileShop/computerShop unchanged (3.1, 3.7)_
    - _Requirements: 2.11_

  - [x] 11.2 Create/link the serial inventory record on sale
    - On sale, create/link the `IMEISerials` record for the unit (RID-patterned `id`, tenant-scoped `userId`, `billId`, `productId`, `status=SOLD`, `purchasePrice` in integer paise for new writes) via `IMEISerialRepository`
    - _Bug_Condition: isBugCondition(BillLineSave) where electronics device line AND NOT serialInventoryLinked_
    - _Expected_Behavior: exactly one RID-patterned tenant-scoped IMEISerials record per unit (Property 5)_
    - _Preservation: integer-paise money, RID ids, tenant-scoped (3.8)_
    - _Requirements: 2.12_

  - [x] 11.3 Decrement serial-level stock for the unit sold
    - Set the sold unit's `IMEISerials.status` to `SOLD` in addition to the existing SKU quantity decrement; the SKU decrement path is preserved
    - _Bug_Condition: isBugCondition(BillLineSave) where electronics device line AND serial-level stock not maintained_
    - _Expected_Behavior: serial-level stock decremented once for the unit sold (Property 5)_
    - _Preservation: SKU stock decrement path unchanged (3.7)_
    - _Requirements: 2.13_

  - [x] 11.4 Verify Phase 3 bug-condition exploration test now passes
    - **Property 5: Expected Behavior** - Warranty/serial data integrity at point of sale
    - **IMPORTANT**: Re-run the SAME test from task 10 — do NOT write a new test
    - **EXPECTED OUTCOME**: Test PASSES (expiry exact; one IMEISerials record per unit; serial stock decremented)
    - _Requirements: 2.11, 2.12, 2.13_

  - [x] 11.5 Verify global preservation test still passes
    - **Property 1: Preservation** - Non-Electronics and Electronics-happy-path behavior unchanged
    - **IMPORTANT**: Re-run the SAME test from task 3 — do NOT write a new test
    - **EXPECTED OUTCOME**: Tests PASS (SKU decrement + bill-line write unchanged for non-device and other verticals)
    - _Requirements: 3.1, 3.7, 3.8_

- [x] 12. STOP GATE — list touched files, run `flutter analyze`, report, output `PHASE 3 COMPLETE — AWAITING APPROVAL`, halt for `APPROVED`

---

### Phase 4 — Electronics sidebar & navigation (HIGH; aliasing MED-LOW)

- [x] 13. Write Phase 4 bug-condition exploration test
  - **Property 6: Bug Condition** - Dedicated Electronics sidebar and correct id resolution
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists. DO NOT fix the test or the code when it fails
  - **NOTE**: Encodes expected behavior; validates the fix when it passes after implementation
  - **GOAL**: Surface that Electronics renders the generic `_getRetailSections()` menu missing device entries, and that aliased ids mislabel screens
  - **Scoped PBT Approach**: Concrete assertions on `getSectionsForBusinessType(electronics)` — expect device entries present (Serial/IMEI Tracking, Warranty Register, Service/Repair Jobs, Returns-with-serial) and irrelevant retail-only ids absent (`funds_flow`, `filing_status`, `ledger_abstract`, `b2b_b2c`); assert `audit_trail` is not presented as a real audit log
  - Bug condition (from design): `SidebarRender` where `businessType == electronics AND sidebarIs(_getRetailSections) AND missingDeviceEntries(input)`
  - Expected behavior asserted: dedicated Electronics section with device entries; ids resolve to intended screens
  - Run on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS — Electronics falls into the shared retail case (D5), device entries missing, retail-only items present
  - Document counterexamples (e.g. "electronics sidebar contains funds_flow; missing IMEI Tracking")
  - _Requirements: 2.14, 2.15, 2.16_

- [x] 14. Fix Phase 4 — dedicated Electronics sidebar

  - [x] 14.1 Split Electronics into a dedicated section builder
    - In `widgets/desktop/sidebar_configuration.dart`, split `electronics` out of the `electronics + computerShop` case (D5) into a new `_getElectronicsSections()`, mirroring `_getMobileShopSections()`; the `computerShop` case stays on `_getRetailSections()`; `default` untouched
    - _Bug_Condition: isBugCondition(SidebarRender) where electronics AND sidebarIs(_getRetailSections)_
    - _Expected_Behavior: dedicated electronics section rendered (Property 6)_
    - _Preservation: `_getRetailSections()`, `_getMobileShopSections()`, computerShop case, default untouched (3.1, 3.6)_
    - _Requirements: 2.14_

  - [x] 14.2 Populate device entries; trim irrelevant retail items
    - `_getElectronicsSections()` includes Serial/IMEI Tracking (→ new ImeiTracking route, 2.9), Warranty Register (→ `/computer-shop/warranty`, 2.8), Service/Repair Jobs (→ `/job/*`, 2.10), Returns-with-serial (→ Phase 7), plus shared common sections; omit clearly-irrelevant retail-only ids (`funds_flow`, `filing_status`, `ledger_abstract`, `b2b_b2c`)
    - _Bug_Condition: isBugCondition(SidebarRender) where electronics AND missingDeviceEntries_
    - _Expected_Behavior: device-relevant entries present, irrelevant retail-only items absent (Property 6)_
    - _Preservation: other verticals' sections unchanged (3.6)_
    - _Requirements: 2.15_

  - [x] 14.3 Correct id resolution / aliasing
    - Ensure each new Electronics id maps to its intended screen; do NOT carry the `audit_trail`→`AllTransactionsScreen` alias into the Electronics section as a "real audit log" (omit or label accurately; real audit log is Phase 8/parked unless backed by one)
    - _Bug_Condition: isBugCondition(SidebarRender) where id alias mislabels a screen_
    - _Expected_Behavior: labels map to intended screens; audit_trail not faked (Property 6)_
    - _Preservation: alias behavior for other verticals' sidebars unchanged (3.6)_
    - _Requirements: 2.16_

  - [x] 14.4 Verify Phase 4 bug-condition exploration test now passes
    - **Property 6: Expected Behavior** - Dedicated Electronics sidebar and correct id resolution
    - **IMPORTANT**: Re-run the SAME test from task 13 — do NOT write a new test
    - **EXPECTED OUTCOME**: Test PASSES (dedicated section with device entries; correct id resolution)
    - _Requirements: 2.14, 2.15, 2.16_

  - [x] 14.5 Verify global preservation test still passes
    - **Property 1: Preservation** - Non-Electronics and Electronics-happy-path behavior unchanged
    - **IMPORTANT**: Re-run the SAME test from task 3 — do NOT write a new test
    - **EXPECTED OUTCOME**: Tests PASS (mobileShop/computerShop/`_getRetailSections()` sidebars byte-for-byte unchanged)
    - _Requirements: 3.1, 3.6_

- [x] 15. STOP GATE — list touched files, run `flutter analyze`, report, output `PHASE 4 COMPLETE — AWAITING APPROVAL`, halt for `APPROVED`

---

### Phase 5 — Dashboard data integrity (HIGH; wasted query LOW)

- [x] 16. Write Phase 5 bug-condition exploration test
  - **Property 7: Bug Condition** - Dashboard data truthfulness
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists. DO NOT fix the test or the code when it fails
  - **NOTE**: Encodes expected behavior; validates the fix when it passes after implementation
  - **GOAL**: Surface hardcoded alert literals, the dead IMEI Lookup action, and wasted queries
  - **Scoped PBT Approach**: Concrete cases — render Electronics dashboard with an empty DB (expect counts reflect zero, not "5"/"8"); tap IMEI Lookup (expect navigation, not no-op); assert only displayed alert queries run for Electronics
  - Bug condition (from design): `DashboardRender` where `businessType == electronics AND countIsHardcodedLiteral(input)`
  - Expected behavior asserted: counts from real tenant-scoped queries; IMEI Lookup navigates; no wasted queries
  - Run on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS — `business_alerts_widget.dart` shows literal `'5'`/`'8'`; IMEI Lookup `onTap: () {}`; `alertCountsProvider` runs unused lowStock/expiringSoon
  - Document counterexamples (e.g. "empty DB still shows Warranty Expiring 5")
  - _Requirements: 2.17, 2.18, 2.19_

- [x] 17. Fix Phase 5 — dashboard data integrity

  - [x] 17.1 Compute real Electronics alert counts
    - Add an `electronicsAlertCountsProvider` (mirroring `mandiAlertCountsProvider`/`schoolAlertCountsProvider` per-vertical snapshot pattern), computing warranty-expiring from tenant-scoped `IMEISerials.warrantyEndDate` and pending repairs from the service-job source; replace the hardcoded `'5'`/`'8'` literals in the electronics+computerShop branch with snapshot values; show an unavailable/`...` indicator on query failure. Gate the new provider on `businessType == electronics` so computerShop is unaffected
    - _Bug_Condition: isBugCondition(DashboardRender) where electronics AND countIsHardcodedLiteral_
    - _Expected_Behavior: counts from real tenant-scoped queries (Property 7)_
    - _Preservation: computerShop branch and all other vertical providers untouched (3.6, 3.8)_
    - _Requirements: 2.17_

  - [x] 17.2 Wire the IMEI Lookup quick action
    - In `business_quick_actions.dart`, replace `onTap: () {}` with navigation to the functional serial/IMEI lookup destination (the ImeiTracking route from 2.9, or Serial-History)
    - _Bug_Condition: isBugCondition(DashboardRender) where IMEI Lookup is a dead onTap_
    - _Expected_Behavior: IMEI Lookup navigates to a functional destination (Property 7)_
    - _Preservation: other quick-action branches untouched (3.6)_
    - _Requirements: 2.18_

  - [x] 17.3 Eliminate wasted alert queries for Electronics
    - Drive the Electronics dashboard from `electronicsAlertCountsProvider`; do not run the generic `alertCountsProvider` lowStock/expiringSoon queries for Electronics if their results are unused
    - _Bug_Condition: isBugCondition(DashboardRender) where electronics runs undisplayed queries_
    - _Expected_Behavior: only displayed alert queries run for electronics (Property 7)_
    - _Preservation: query behavior for other verticals unchanged (3.6)_
    - _Requirements: 2.19_

  - [x] 17.4 Verify Phase 5 bug-condition exploration test now passes
    - **Property 7: Expected Behavior** - Dashboard data truthfulness
    - **IMPORTANT**: Re-run the SAME test from task 16 — do NOT write a new test
    - **EXPECTED OUTCOME**: Test PASSES (real counts; IMEI Lookup navigates; no wasted queries)
    - _Requirements: 2.17, 2.18, 2.19_

  - [x] 17.5 Verify global preservation test still passes
    - **Property 1: Preservation** - Non-Electronics and Electronics-happy-path behavior unchanged
    - **IMPORTANT**: Re-run the SAME test from task 3 — do NOT write a new test
    - **EXPECTED OUTCOME**: Tests PASS (computerShop and other verticals' dashboards/alerts/quick actions unchanged)
    - _Requirements: 3.6, 3.8_

- [x] 18. STOP GATE — list touched files, run `flutter analyze`, report, output `PHASE 5 COMPLETE — AWAITING APPROVAL`, halt for `APPROVED`

---

### Phase 6 — RBAC permission gating (HIGH; layering MED)

- [x] 19. Write Phase 6 bug-condition exploration test
  - **Property 8: Bug Condition** - RBAC permission gating
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists. DO NOT fix the test or the code when it fails
  - **NOTE**: Encodes expected behavior; validates the fix when it passes after implementation
  - **GOAL**: Surface that sensitive sidebar items are visible to non-privileged roles and that "New Repair" bypasses the route guard
  - **Scoped PBT Approach**: Concrete cases — view Electronics sidebar as a cashier/non-privileged role (expect `audit_trail`, `bank_accounts`, `backup`, `expenses`, `accounting_reports` hidden); assert "New Repair" quick action applies the same `manageStaff` authority as `/job/*`
  - Bug condition (from design): `RbacView` where `businessType == electronics AND sensitiveItem(input) AND input.permission IS null`
  - Expected behavior asserted: sensitive items carry a `permission` and are hidden from unauthorized roles; quick action and route guard agree
  - Run on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS — sensitive items carry no `permission`; "New Repair" routes via raw `AppScreen.serviceJobs` without the check
  - Document counterexamples (e.g. "cashier sees audit_trail and backup")
  - _Requirements: 2.20, 2.21_

- [x] 20. Fix Phase 6 — RBAC permission gating

  - [x] 20.1 Assign permissions to sensitive Electronics sidebar items
    - In `_getElectronicsSections()`, assign a `permission` to `audit_trail`, `bank_accounts`, `backup`, `expenses`, `accounting_reports` so the existing RBAC filter in `sidebarSectionsProvider` hides them from unauthorized roles; applied only within the Electronics section
    - _Bug_Condition: isBugCondition(RbacView) where electronics sensitive item AND permission null_
    - _Expected_Behavior: sensitive items gated by permission, hidden from unauthorized roles (Property 8)_
    - _Preservation: RBAC behavior for all other verticals unchanged (3.6)_
    - _Requirements: 2.20_

  - [x] 20.2 Align "New Repair" quick action with the route guard
    - Route the dashboard "New Repair" quick action through the same `manageStaff`-guarded path as `/job/*` (D7) — navigate via the guarded `/job/create` route / the `VendorRoleGuard(manageStaff)`-wrapped in-shell `job_create` case rather than a raw `AppScreen.serviceJobs` navigation
    - _Bug_Condition: isBugCondition(RbacView) where quick action and route guard disagree on authority_
    - _Expected_Behavior: quick action applies same manageStaff authority as the route guard (Property 8)_
    - _Preservation: other quick actions unchanged (3.6)_
    - _Requirements: 2.21_

  - [x] 20.3 Verify Phase 6 bug-condition exploration test now passes
    - **Property 8: Expected Behavior** - RBAC permission gating
    - **IMPORTANT**: Re-run the SAME test from task 19 — do NOT write a new test
    - **EXPECTED OUTCOME**: Test PASSES (sensitive items hidden from cashier; New Repair enforces manageStaff)
    - _Requirements: 2.20, 2.21_

  - [x] 20.4 Verify global preservation test still passes
    - **Property 1: Preservation** - Non-Electronics and Electronics-happy-path behavior unchanged
    - **IMPORTANT**: Re-run the SAME test from task 3 — do NOT write a new test
    - **EXPECTED OUTCOME**: Tests PASS (RBAC for all other verticals unchanged)
    - _Requirements: 3.6_

- [x] 21. STOP GATE — list touched files, run `flutter analyze`, report, output `PHASE 6 COMPLETE — AWAITING APPROVAL`, halt for `APPROVED`

---

### Phase 7 — Returns, serial-stock view & accessibility (HIGH; semantics/HSN MED-LOW)

- [x] 22. Write Phase 7 bug-condition exploration tests
  - **Property 9: Bug Condition** - Returns, serial-stock view, accessibility, HSN
  - **CRITICAL**: These tests MUST FAIL on unfixed code — failure confirms the bugs exist. DO NOT fix the tests or the code when they fail
  - **NOTE**: Encode expected behavior; validate the fixes when they pass after implementation
  - **GOAL**: Surface unvalidated return serials, missing serial-wise stock view, missing accessibility, and unvalidated HSN
  - **Scoped PBT Approach**: Returns — property over random serials asserting only sold, tenant-scoped serials are accepted on return (concrete: wrong/blank/never-sold serial rejected). HSN — property over malformed vs valid HSN strings asserting malformed rejected, valid accepted. Concrete checks for serial-wise stock view existence and `Semantics`/tooltip presence on quick-action buttons
  - Bug condition (from design): `ReturnSave` where `electronics AND isDeviceLine AND NOT serialValidated(input)`; `HsnEntry` where `NOT hsnFormatValidated(input)`
  - Expected behavior asserted: return serial validated (exists, tenant-scoped, was sold); serial-wise stock view provided; quick actions expose semantics/tooltips/state; HSN length/format validated
  - Run on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL — generic return flow does no serial validation; no serial-wise stock view; quick actions are `InkWell`+`Text` with no `Semantics`; HSN field has no validator
  - Document counterexamples (e.g. "return accepts never-sold serial"; "malformed HSN accepted")
  - _Requirements: 2.22, 2.23, 2.24, 2.25_

- [x] 23. Fix Phase 7 — returns, serial-stock, accessibility, HSN

  - [x] 23.1 Validate returned device serial
    - In the Electronics return flow, validate the returned device serial against `IMEISerials` (exists, tenant-scoped, was sold) before accepting the return line; on accept, transition the unit's `status` to `RETURNED`
    - _Bug_Condition: isBugCondition(ReturnSave) where electronics device line AND NOT serialValidated_
    - _Expected_Behavior: only sold, tenant-scoped serials accepted on return (Property 9)_
    - _Preservation: generic return screens for other verticals unchanged (3.7)_
    - _Requirements: 2.22_

  - [x] 23.2 Provide a serial-wise stock view
    - Provide a serial-wise stock view for Electronics (a `status`-filtered `IMEISerials` list, reachable from the Electronics sidebar); broader multi-warehouse/FIFO/BOM remains parked
    - _Bug_Condition: isBugCondition where electronics user has no serial-wise stock view_
    - _Expected_Behavior: serial-wise stock view available (Property 9)_
    - _Preservation: generic SKU inventory screens unchanged (3.7)_
    - _Requirements: 2.23_

  - [x] 23.3 Add accessibility to quick-action buttons
    - Add `Semantics`/tooltips and accessible state to the Electronics quick-action buttons in `business_quick_actions.dart` (including a meaningful state for the now-wired IMEI Lookup button)
    - _Bug_Condition: isBugCondition where quick-action buttons expose no semantics/state_
    - _Expected_Behavior: assistive technology can describe quick actions (Property 9)_
    - _Preservation: other verticals' quick-action widgets unchanged (3.6)_
    - _Requirements: 2.24_

  - [x] 23.4 Validate HSN length/format
    - In `manual_item_entry_sheet.dart`, add a length/format `validator` to the HSN field and reject malformed values; do not change the required-field config
    - _Bug_Condition: isBugCondition(HsnEntry) where NOT hsnFormatValidated_
    - _Expected_Behavior: malformed HSN rejected, valid accepted (Property 9)_
    - _Preservation: HSN required-field config (3.4) and other branches of the entry sheet unchanged_
    - _Requirements: 2.25_

  - [x] 23.5 Verify Phase 7 bug-condition exploration tests now pass
    - **Property 9: Expected Behavior** - Returns, serial-stock view, accessibility, HSN
    - **IMPORTANT**: Re-run the SAME tests from task 22 — do NOT write new tests
    - **EXPECTED OUTCOME**: Tests PASS (return serials validated; stock view present; semantics present; HSN validated)
    - _Requirements: 2.22, 2.23, 2.24, 2.25_

  - [x] 23.6 Verify global preservation test still passes
    - **Property 1: Preservation** - Non-Electronics and Electronics-happy-path behavior unchanged
    - **IMPORTANT**: Re-run the SAME test from task 3 — do NOT write a new test
    - **EXPECTED OUTCOME**: Tests PASS (generic return/inventory screens and HSN required-field config unchanged)
    - _Requirements: 3.4, 3.6, 3.7_

- [x] 24. STOP GATE — list touched files, run `flutter analyze`, report, output `PHASE 7 COMPLETE — AWAITING APPROVAL`, halt for `APPROVED`

---

### Phase 8 — Cleanup & final regression verification

- [x] 25. Fix Phase 8 — cleanup and end-to-end regression

  - [x] 25.1 Remove mislabeled aliases and dead code/queries
    - Remove the mislabeled id aliases and dead code/queries addressed in earlier phases (alias labels promising distinct screens, unused `alertCountsProvider` queries on Electronics)
    - _Bug_Condition: isBugCondition where mislabeled aliases / dead queries remain_
    - _Expected_Behavior: aliases and dead code/queries removed (Property 10)_
    - _Preservation: only Electronics-scoped cleanup; shared/other-vertical code untouched (3.1)_
    - _Requirements: 2.26_

  - [x] 25.2 Run the full property/regression suite end-to-end
    - **Property 10: Expected Behavior** - Cleanup and end-to-end regression
    - Re-run ALL property tests (Properties 1, 3, 4, 5, 6, 7, 8, 9) and the integration/cross-vertical smoke tests from the design's Testing Strategy
    - Confirm all earlier fixes hold and `mobileShop`/`computerShop` behavior (sidebars, guards, capabilities, shared billing/entry-sheet branches) is byte-for-byte unchanged
    - **EXPECTED OUTCOME**: All tests PASS
    - _Requirements: 2.26, 3.1_

  - [x] 25.3 Verify global preservation test still passes
    - **Property 1: Preservation** - Non-Electronics and Electronics-happy-path behavior unchanged
    - **IMPORTANT**: Re-run the SAME test from task 3 — do NOT write a new test
    - **EXPECTED OUTCOME**: Tests PASS (full preservation confirmed after cleanup)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [x] 26. Checkpoint — ensure all tests pass
  - Ensure all property, unit, and integration tests pass; run `flutter analyze` clean on all touched files
  - Confirm every phase's bug-condition test passes and the global preservation test passes
  - List all files created/modified/deleted across the remediation
  - Output `PHASE 8 COMPLETE — AWAITING APPROVAL`; ask the user if any questions arise
  - _Requirements: 2.26, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

---

## Task Dependency Graph

Phases are sequential STOP GATES — each must be `APPROVED` before the next begins. The
global preservation baseline (task 3) must be written before any fix and is re-run after
every phase.

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1"], "description": "Phase 0 read-only investigation" },
    { "wave": 2, "tasks": ["2"], "description": "STOP GATE 0 — await approval" },
    { "wave": 3, "tasks": ["3"], "description": "Global preservation baseline (prerequisite for all fixes)" },
    { "wave": 4, "tasks": ["4"], "description": "Phase 1 bug-condition exploration test" },
    { "wave": 5, "tasks": ["5.1", "5.2"], "description": "Phase 1 fix implementation" },
    { "wave": 6, "tasks": ["5.3", "5.4"], "description": "Phase 1 verification" },
    { "wave": 7, "tasks": ["6"], "description": "STOP GATE 1 — await approval" },
    { "wave": 8, "tasks": ["7"], "description": "Phase 2 bug-condition exploration test" },
    { "wave": 9, "tasks": ["8.1", "8.2", "8.3"], "description": "Phase 2 fix implementation" },
    { "wave": 10, "tasks": ["8.4", "8.5"], "description": "Phase 2 verification" },
    { "wave": 11, "tasks": ["9"], "description": "STOP GATE 2 — await approval" },
    { "wave": 12, "tasks": ["10"], "description": "Phase 3 bug-condition exploration test" },
    { "wave": 13, "tasks": ["11.1", "11.2", "11.3"], "description": "Phase 3 fix implementation" },
    { "wave": 14, "tasks": ["11.4", "11.5"], "description": "Phase 3 verification" },
    { "wave": 15, "tasks": ["12"], "description": "STOP GATE 3 — await approval" },
    { "wave": 16, "tasks": ["13"], "description": "Phase 4 bug-condition exploration test" },
    { "wave": 17, "tasks": ["14.1", "14.2", "14.3"], "description": "Phase 4 fix implementation" },
    { "wave": 18, "tasks": ["14.4", "14.5"], "description": "Phase 4 verification" },
    { "wave": 19, "tasks": ["15"], "description": "STOP GATE 4 — await approval" },
    { "wave": 20, "tasks": ["16"], "description": "Phase 5 bug-condition exploration test" },
    { "wave": 21, "tasks": ["17.1", "17.2", "17.3"], "description": "Phase 5 fix implementation" },
    { "wave": 22, "tasks": ["17.4", "17.5"], "description": "Phase 5 verification" },
    { "wave": 23, "tasks": ["18"], "description": "STOP GATE 5 — await approval" },
    { "wave": 24, "tasks": ["19"], "description": "Phase 6 bug-condition exploration test" },
    { "wave": 25, "tasks": ["20.1", "20.2"], "description": "Phase 6 fix implementation" },
    { "wave": 26, "tasks": ["20.3", "20.4"], "description": "Phase 6 verification" },
    { "wave": 27, "tasks": ["21"], "description": "STOP GATE 6 — await approval" },
    { "wave": 28, "tasks": ["22"], "description": "Phase 7 bug-condition exploration tests" },
    { "wave": 29, "tasks": ["23.1", "23.2", "23.3", "23.4"], "description": "Phase 7 fix implementation" },
    { "wave": 30, "tasks": ["23.5", "23.6"], "description": "Phase 7 verification" },
    { "wave": 31, "tasks": ["24"], "description": "STOP GATE 7 — await approval" },
    { "wave": 32, "tasks": ["25.1", "25.2", "25.3"], "description": "Phase 8 cleanup and end-to-end regression" },
    { "wave": 33, "tasks": ["26"], "description": "Final checkpoint / STOP GATE 8" }
  ]
}
```

Sequential overview:

```
1  (Phase 0 investigation)
└─ 2  (STOP GATE 0)
   └─ 3  (Property 1 — global preservation baseline)   ← prerequisite for all fixes
      ├─ 4  (Property 3 exploration) → 5 (Phase 1 fix: 5.1, 5.2 → 5.3, 5.4) → 6  (STOP GATE 1)
      │     └─ 7  (Property 4 exploration) → 8 (Phase 2 fix: 8.1, 8.2, 8.3 → 8.4, 8.5) → 9  (STOP GATE 2)
      │           └─ 10 (Property 5 exploration) → 11 (Phase 3 fix: 11.1, 11.2, 11.3 → 11.4, 11.5) → 12 (STOP GATE 3)
      │                 └─ 13 (Property 6 exploration) → 14 (Phase 4 fix: 14.1, 14.2, 14.3 → 14.4, 14.5) → 15 (STOP GATE 4)
      │                       └─ 16 (Property 7 exploration) → 17 (Phase 5 fix: 17.1, 17.2, 17.3 → 17.4, 17.5) → 18 (STOP GATE 5)
      │                             └─ 19 (Property 8 exploration) → 20 (Phase 6 fix: 20.1, 20.2 → 20.3, 20.4) → 21 (STOP GATE 6)
      │                                   └─ 22 (Property 9 exploration) → 23 (Phase 7 fix: 23.1–23.4 → 23.5, 23.6) → 24 (STOP GATE 7)
      │                                         └─ 25 (Phase 8 fix: 25.1 → 25.2 → 25.3) → 26 (Checkpoint / STOP GATE 8)
```

Key dependencies:
- Task 3 (preservation baseline) gates every fix and is re-verified in 5.4, 8.5, 11.5, 14.5,
  17.5, 20.4, 23.6, 25.3.
- Phase 2 route/screen edits depend on Phase 0 findings (tasks 1–2): route mounting (2.1),
  access decision (2.2), tracking-query tenant scope (2.3), live route-file location (2.4).
- Phase 4 sidebar entries (task 14) depend on Phase 2 routes existing (ImeiTracking route in
  8.2; warranty/serial-history widened in 8.1; `/job/*` confirmed in 8.3).
- Phase 5 IMEI Lookup wiring (17.2) and Phase 7 serial-stock view (23.2) depend on the Phase 2
  ImeiTracking route (8.2).
- Phase 5 warranty-expiring counts (17.1) and Phase 7 return validation (23.1) depend on the
  Phase 3 `IMEISerials` writes (11.1–11.3).
- Phase 6 sensitive-item permissions (20.1) depend on the dedicated `_getElectronicsSections()`
  from Phase 4 (14.1).
- Phase 8 cleanup/regression (task 25) depends on all prior phases being complete and approved.

## Notes

- **STOP GATE protocol (per steering rules):** After each phase, (a) list every file
  created/modified/deleted, (b) run `flutter analyze` on touched files and report results,
  (c) output exactly `PHASE N COMPLETE — AWAITING APPROVAL`, then stop. Do NOT auto-continue;
  wait for `APPROVED`. If the reply contains changes, apply them and stop again.
- **Property numbering:** Labels intentionally match `design.md` "Correctness Properties"
  (Property 1 = global Preservation; Properties 2–10 = per-phase). Phase 0 corresponds to
  Property 2; Phase 8 to Property 10. Exploration tests reuse the design's bug-condition
  property number, and the same test is re-run post-fix as "Expected Behavior" — never write
  a second test.
- **Phase 0 is read-only.** Its property (Property 2) is satisfied by a documented,
  evidence-based findings record, not a fail→pass code test. No behavior changes until its
  gates are confirmed.
- **Exploration tests must FAIL on unfixed code** (confirming the bug). Preservation tests
  (task 3) must PASS on unfixed code (locking the baseline). Do not "fix" a failing
  exploration test — its failure is the goal.
- **Deterministic bugs are scoped:** where a defect is deterministic (blank serial, denied
  guard, dead `onTap`, hardcoded literal), the property is scoped to concrete failing cases
  for reproducibility, alongside the broader property where the input domain is large.
- **Shared-file ledger (from design):** `billing_service.dart`,
  `manual_item_entry_sheet.dart`, `sidebar_configuration.dart`, `business_alerts_widget.dart`,
  `business_quick_actions.dart`, `legacy_routes.dart` are shared with `mobileShop`/
  `computerShop`. Each touching task flags the file and preserves non-Electronics branches.
- **Constraints on every new write:** integer-paise money, RID-patterned ids, tenant-scoped
  queries, idempotent migrations, no schema change / hard delete without sign-off (Requirement
  3.8). The `IMEISerials` columns needed for warranty/serial work already exist — no schema
  change is anticipated.
- **Tests are Dart/`flutter test`.** Property-based cases use generated `(businessType, input)`
  pairs per the design's Testing Strategy; preservation generation excludes `electronics`
  (plus Electronics happy-path serials) and asserts equality against a pre-change snapshot.
