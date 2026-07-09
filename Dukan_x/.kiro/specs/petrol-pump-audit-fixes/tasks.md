# Implementation Plan

## Overview

Scope: all 15 verified-still-defective petrol pump surfaces from `bugfix.md`'s `isBugCondition` — `billing.fuelSaleWiring`, `datastore.splitBrain`, `ui.dispenserNozzleReadingEntry`, `dashboard.orphaned`, `alerts.hardcodedCounts`, `report.fuelProfitHardcoded`, `stock.purchasePriceDiscarded`, `rbac.sidebarGateMissing`, `rbac.readingPermissionBypass`, `shift.rolloverAndBilledLitres`, `fuelRates.fabAndBoundsMissing`, `bug.mojibake`, `bug.escapedErrorString`, `bug.debugPrints`, `validation.silentClampNoFlag`. No task may alter behavior for any other business type, or for petrol pump's own already-correct behaviors (GST defaults, shift-close reconciliation/cash-variance checks, tank/dip/purchase validators, existing audit logging, responsive layout).

Testing mandate: write all 15 bug-condition exploration tests (Properties 1-15) and all 5 preservation property tests (Property 16, split by preserved-behavior group) FIRST, run them on UNFIXED code (exploration tests FAIL, preservation tests PASS), then implement each surface's fix, then re-run the same tests unchanged to confirm the fix resolves that surface's bug and introduces no regressions.

## Task Dependency Graph

```json
{
  "waves": [
    {
      "wave": 1,
      "description": "All 15 bug-condition exploration tests, written and run on UNFIXED code before any fix - each MUST FAIL",
      "tasks": ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"]
    },
    {
      "wave": 2,
      "description": "All 5 preservation property tests, written and run on UNFIXED code before any fix - each MUST PASS",
      "tasks": ["16", "17", "18", "19", "20"]
    },
    {
      "wave": 3,
      "description": "Foundational datastore migration (Surface 2) - underlies Surfaces 1, 3, 7, 9, 10, 11 which read/write the same Drift tables",
      "tasks": ["22.1", "22.2", "22.3"]
    },
    {
      "wave": 4,
      "description": "Independent surface fixes that do not depend on each other beyond the Surface 2 datastore migration",
      "tasks": ["21.1", "21.2", "21.3", "24.1", "24.2", "24.3", "25.1", "25.2", "25.3", "28.1", "28.2", "28.3", "31.1", "31.2", "31.3", "32.1", "32.2", "32.3", "33.1", "33.2", "33.3", "34.1", "34.2", "34.3"]
    },
    {
      "wave": 5,
      "description": "Surface 7 (purchase price persisted) must land before Surface 6 (fuel profit cost computation) can read real cost data",
      "tasks": ["27.1", "27.2", "27.3"]
    },
    {
      "wave": 6,
      "description": "Surface 15 (anomaly getters) feeds Surface 3's warning UI, and Surface 3 (reading-entry dialogs) is the caller Surface 9's permission enforcement is exercised through",
      "tasks": ["35.1", "35.2", "35.3", "23.1", "23.2", "23.3"]
    },
    {
      "wave": 7,
      "description": "Surface 9 (permission enforcement) depends on Surface 3's NozzleReadingDialog caller, and Surface 6 depends on Surface 7's persisted price",
      "tasks": ["29.1", "29.2", "29.3", "26.1", "26.2", "26.3", "30.1", "30.2", "30.3"]
    },
    {
      "wave": 8,
      "description": "Final checkpoint - full suite green across all 15 exploration tests and all 5 preservation tests",
      "tasks": ["36"]
    }
  ]
}
```

**Key dependency notes:**
- **Surface 2 (`datastore.splitBrain`, task 22) is foundational.** `TankService`/`DispenserService`/`FuelService`/`PeriodLockService`'s migration onto Drift underlies Surface 1 (fuel sale wiring reads tank/nozzle state), Surface 3 (new dialogs call these services), Surface 7 (purchase price persisted through `TankService`), Surface 9 (permission check lives in `DispenserService`), Surface 10 (`ShiftService` and `DispenserService` must agree on nozzle state), and Surface 11 (`FuelService.updateFuelRate`/`addFuelType`). Implement Surface 2 early to avoid rework on the others.
- **Surface 7 → Surface 6**: the Fuel Profit report's cost computation depends on the purchase price being persisted first. Task 26.1 notes this as a soft dependency (can stub cost as `0` until task 27 lands, but must complete before Surface 6 is considered done).
- **Surface 3 → Surface 9**: the new `NozzleReadingDialog` (Surface 3) is the caller that must pass `employeeId` for Surface 9's permission enforcement to be exercised end-to-end.
- **Surface 15 → Surface 3**: the anomaly-flag getters (Surface 15) are consumed by the reading-entry UI's warning display, so Surface 15 should land before or alongside Surface 3's UI polish (though Surface 3's core dialogs can be built independently).
- All 15 exploration tests (Phase 1 / wave 1) and all 5 preservation tests (Phase 2 / wave 2) MUST be written and run on UNFIXED code before any implementation task begins — this ordering applies globally, not just per-surface.
- Within each surface's parent task, the three sub-tasks (implement → verify fix → verify preservation) are strictly sequential, but different surfaces' parent tasks (21-35) may be implemented in any order consistent with the cross-surface dependencies above.

## Tasks

### Phase 1: Exploration Tests (Bug Condition, Properties 1-15) — write and run BEFORE any fix

- [x] 1. Write bug condition exploration test — Fuel Sale Wiring
  - **Property 1: Bug Condition** - Fuel Sale Wiring
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists. Do NOT fix the test or the code when it fails.
  - **Surface**: `billing.fuelSaleWiring`
  - Save a petrolPump bill via `BillCreationScreenV2._handleSave` (with an active shift seeded) and assert `newBill.shiftId != null` and `newBill.attendantId != null`
  - Separately, seed a fuel `Product` with a non-zero `taxRate` and assert the resulting `BillItem.gstRate == 0`
  - Run on UNFIXED code — expect FAILURE (`shiftId`/`attendantId` stay `null`, `gstRate` inherits `product.taxRate`, no `PetrolPumpBillingService` call occurs)
  - Document the counterexample (e.g. "petrolPump bill saved with shiftId=null, attendantId=null, gstRate=<product.taxRate>")
  - _Requirements: 1.1_

- [x] 2. Write bug condition exploration test — Unified Datastore
  - **Property 2: Bug Condition** - Unified Datastore
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `datastore.splitBrain`
  - Write a tank via `TankService.saveTank`, then read it via `_db.select(_db.tanks)` directly (the Drift table `PetrolPumpBillingService` reads)
  - Assert the tank written through `TankService` is visible in the Drift table
  - Run on UNFIXED code — expect FAILURE (no row exists in Drift; `TankService` only wrote to the Firestore-compat/API-backed store)
  - Document the counterexample (cross-service write invisible to `ShiftService`/`PetrolPumpBillingService`'s reads)
  - _Requirements: 1.2_

- [x] 3. Write bug condition exploration test — Dispenser/Nozzle/Reading Entry UI
  - **Property 3: Bug Condition** - Dispenser/Nozzle/Reading Entry UI
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `ui.dispenserNozzleReadingEntry`
  - Widget-test `DispenserListScreen` and assert a `FloatingActionButton` exists and an "Add Nozzle" affordance exists per dispenser card
  - Run on UNFIXED code — expect FAILURE (FAB and "Add Nozzle" button are both removed with a "not fully implemented" comment)
  - Document the counterexample (no reading-entry screen/dialog exists anywhere in `lib/features/petrol_pump/presentation/`)
  - _Requirements: 1.3_

- [x] 4. Write bug condition exploration test — Dashboard Reachability
  - **Property 4: Bug Condition** - Dashboard Reachability
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `dashboard.orphaned`
  - Resolve `SidebarNavigationHandler.getScreenForItem('petrol_dashboard')` and assert it returns a `RevenueDashboardScreen`
  - Run on UNFIXED code — expect FAILURE (returns `PetrolPumpManagementScreen`, a bare 4-tile menu)
  - Document the counterexample
  - _Requirements: 1.4_

- [x] 5. Write bug condition exploration test — Live Alert Counts
  - **Property 5: Bug Condition** - Live Alert Counts
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `alerts.hardcodedCounts`
  - Render `BusinessAlertsWidget` for two different tank-level fixtures (0 low tanks vs. 5 low tanks) and assert the "Tank Levels Low" displayed count differs between the two renders
  - Run on UNFIXED code — expect FAILURE (count is always the literal `'2'` regardless of fixture)
  - Document the counterexample
  - _Requirements: 1.5_

- [x] 6. Write bug condition exploration test — Real Fuel Profit Figures
  - **Property 6: Bug Condition** - Real Fuel Profit Figures
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `report.fuelProfitHardcoded`
  - Seed a petrolPump bill with a known non-zero `grandTotal`, render `FuelProfitReportScreen`, and assert the displayed "Total Sales" is non-zero and matches the seeded value
  - Run on UNFIXED code — expect FAILURE (always displays literal `'₹0'` regardless of seeded data)
  - Document the counterexample
  - _Requirements: 1.6_

- [x] 7. Write bug condition exploration test — Purchase Price Persisted
  - **Property 7: Bug Condition** - Purchase Price Persisted
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `stock.purchasePriceDiscarded`
  - Call `TankService.addPurchase` with a price argument and assert the logged stock-movement metadata contains `pricePerLitre`/`totalCost`
  - Run on UNFIXED code — expect FAILURE (signature has no price parameter; the call either fails to compile against the new call site or the price is silently discarded)
  - Document the counterexample
  - _Requirements: 1.7_

- [x] 8. Write bug condition exploration test — Sidebar Capability & Role Gating
  - **Property 8: Bug Condition** - Sidebar Capability & Role Gating
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `rbac.sidebarGateMissing`
  - Read `_getPetrolPumpSections()`'s `shift_management` item and assert `capability != null`
  - Separately assert `UserRole.values` contains a value named `attendant`
  - Run on UNFIXED code — expect FAILURE (`capability` is `null` on every petrol pump sidebar item; no `attendant` value exists in `UserRole`)
  - Document the counterexample
  - _Requirements: 1.8_

- [x] 9. Write bug condition exploration test — Reading Permission Enforced
  - **Property 9: Bug Condition** - Reading Permission Enforced
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `rbac.readingPermissionBypass`
  - Call `DispenserService.updateOpeningReading(nozzleId, reading, shiftId)` with no `employeeId`, for a nozzle whose linked employee lacks `canEditReadings`, and assert it throws `PermissionDeniedException`
  - Run on UNFIXED code — expect FAILURE (proceeds unconditionally since `employeeId == null` skips the permission check entirely)
  - Document the counterexample
  - _Requirements: 1.9_

- [x] 10. Write bug condition exploration test — Rollover-Aware, Real Billed Litres
  - **Property 10: Bug Condition** - Rollover-Aware, Real Billed Litres
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `shift.rolloverAndBilledLitres`
  - **Scoped PBT Approach**: Property-based test generating `(openingReading, closingReading)` pairs where `closingReading < openingReading` (rollover region); for each, call `ShiftService.calculateShiftSales` and assert the computed litres equals `PetrolPumpBusinessRules.dispensedLitres(startReading, endReading)` (positive, rollover-corrected)
  - Concrete case: `openingReading: 999900, closingReading: 100` — assert computed litres is ~200, not `-999800`
  - Separately assert every `NozzleReconciliation.billedLitres`/`variance` is non-zero when bills are attributed to that nozzle
  - Run on UNFIXED code — expect FAILURE (returns `closingReading - openingReading` directly, producing a large negative value; `billedLitres`/`variance` are hardcoded `0`)
  - Document the counterexample
  - _Requirements: 1.10_

- [x] 11. Write bug condition exploration test — Fuel Rate FAB & Bounds
  - **Property 11: Bug Condition** - Fuel Rate FAB & Bounds
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `fuelRates.fabAndBoundsMissing`
  - Tap the Fuel Rates FAB and assert a dialog opens
  - **Scoped PBT Approach**: Property-based test generating rate values outside `[1.0, 500.0]` (including negative values) and asserting each is rejected by the update flow
  - Run on UNFIXED code — expect FAILURE (FAB `onPressed` body is empty, nothing opens; a rate of `-50` is accepted via bare `double.tryParse` with no bounds check)
  - Document the counterexample
  - _Requirements: 1.11_

- [x] 12. Write bug condition exploration test — Correct Currency & Punctuation Glyphs
  - **Property 12: Bug Condition** - Correct Currency & Punctuation Glyphs
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `bug.mojibake`
  - Render `ShiftReportScreen` for a shift with `totalSaleAmount: 100` and assert the rendered text contains `₹100.00`, not `â‚¹100.00`
  - Separately, read `petrol_pump_business_rules.dart`'s source and assert its comments contain `—`, `×`, `−`, not the mojibake byte sequences `â€”`, `Ã—`, `âˆ’`
  - Run on UNFIXED code — expect FAILURE (mojibake sequences render/appear in both files)
  - Document the counterexample
  - _Requirements: 1.12_

- [x] 13. Write bug condition exploration test — Real Error Messages
  - **Property 13: Bug Condition** - Real Error Messages
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `bug.escapedErrorString`
  - Force `TankService.saveTank` to throw a specific exception message inside `AddTankDialog._submit`, and assert the resulting SnackBar text contains that exact exception message
  - Repeat for `DipReadingDialog._submit`
  - Run on UNFIXED code — expect FAILURE (SnackBar always displays the literal text `Error: $e`, never the actual exception message)
  - Document the counterexample
  - _Requirements: 1.13_

- [x] 14. Write bug condition exploration test — No Debug Console Output
  - **Property 14: Bug Condition** - No Debug Console Output
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `bug.debugPrints`
  - Capture stdout during `PetrolPumpBillingService.createFuelBill` (success path) and assert no captured line starts with `DEBUG:`
  - Repeat for `ShiftService.openShift`/`_resetNozzlesForShift`
  - Run on UNFIXED code — expect FAILURE (nine `DEBUG:` lines printed in `createFuelBill`, five in `shift_service.dart`)
  - Document the counterexample
  - _Requirements: 1.14_

- [x] 15. Write bug condition exploration test — Anomaly Flagged Alongside Clamp
  - **Property 15: Bug Condition** - Anomaly Flagged Alongside Clamp
  - **CRITICAL**: This test MUST FAIL on unfixed code.
  - **Surface**: `validation.silentClampNoFlag`
  - **Scoped PBT Approach**: Property-based test generating `Nozzle` values with `closingReading < openingReading` (rollover) and asserting `hasRolloverAnomaly == true`
  - Separately, property-based test generating `Tank`/`(openingStock, purchaseQuantity, capacity)` tuples that would overflow capacity and asserting `hasOverfillAnomaly == true`
  - Run on UNFIXED code — expect FAILURE (`hasRolloverAnomaly`/`hasOverfillAnomaly` getters do not exist; the anomaly is invisible, only the clamped value is returned)
  - Document the counterexample
  - _Requirements: 1.15_

### Phase 2: Preservation Tests (Property 16) — write and verify PASS on UNFIXED code BEFORE any fix

- [x] 16. Write preservation property test — Non-Petrol Business Types Unaffected
  - **Property 16: Preservation** - Non-Petrol Business Types Unaffected
  - **IMPORTANT**: Follow observation-first methodology — observe current output for each of the 19 non-petrolPump business types' billing/sidebar/dashboard/report code paths on UNFIXED code, record it, then assert it in the test
  - Property-based test: generate arbitrary non-petrolPump `BusinessType` values with arbitrary bill/sidebar/dashboard/report inputs and assert zero reference to `PetrolPumpBillingService`/`ShiftService`/`PetrolPumpBusinessRules`/`UserRole.attendant`, and identical output to the recorded baseline
  - Also cover responsive layout (`BoundedBox`/`responsiveValue`) rendering identically across mobile/tablet/desktop for petrol screens (Requirement 3.7)
  - Verify test PASSES on UNFIXED code (confirms baseline behavior to preserve)
  - _Requirements: 3.1, 3.7_

- [x] 17. Write preservation property test — Petrol Pump GST Defaults Preserved
  - **Property 16: Preservation** - Petrol Pump GST Defaults Preserved
  - **IMPORTANT**: Observe `BusinessTypeConfig.petrolPump.defaultGstRate` and `FuelType.linkedGSTRate`'s default on UNFIXED code (both `0.0`) and `PetrolPumpBillingService.createFuelBill`'s existing `const gstRate = 0.0` override
  - Property-based test: generate arbitrary `Product.taxRate` values and assert these three already-correct values are unchanged by this fix (the fix enforces `0` on the `bill_creation_screen_v2.dart` path in addition, it does not change the values themselves)
  - Verify test PASSES on UNFIXED code
  - _Requirements: 3.2_

- [x] 18. Write preservation property test — Shift-Close Reconciliation/Cash-Variance Logic Preserved
  - **Property 16: Preservation** - Shift-Close Reconciliation/Cash-Variance Logic Preserved
  - **IMPORTANT**: Observe `ShiftService.closeShift`'s reconciliation-tolerance check (`ShiftReconciliation.isWithinTolerance`), cash-declaration variance check (`cashVarianceThreshold`), and `forceClose` owner-override audit logging on UNFIXED code
  - Property-based test: generate arbitrary `ShiftReconciliation` inputs within/at tolerance boundaries and assert `closeShift`'s tolerance/variance decision is unchanged — only `calculateShiftSales`'s *inputs* (rollover-aware litres, real billed litres) become more accurate, not the close-decision thresholds
  - Verify test PASSES on UNFIXED code
  - _Requirements: 3.3_

- [x] 19. Write preservation property test — Tank/Dispenser Validators and Audit Logging Preserved
  - **Property 16: Preservation** - Tank/Dispenser Validators and Audit Logging Preserved
  - **IMPORTANT**: Observe `AddTankDialog`/`DipReadingDialog`/`AddStockDialog`'s existing field validators and `TankService.recordDipReading`'s `STOCK_VARIANCE_ALERT`/`DispenserService`'s `READING_UPDATE`/`PERMISSION_DENIED` audit logging on UNFIXED code
  - Property-based test: generate arbitrary tank name/capacity/initial-stock/dip-reading/purchase-quantity values and assert the existing validators (name required, capacity > 0, initial stock ≤ capacity, dip reading ≥ 0 and ≤ capacity, purchase quantity > 0 and ≤ available capacity) enforce identically after the Drift migration (Surface 2), and audit log entries retain the same trigger conditions/actions/metadata shape
  - Also generate arbitrary `Nozzle`/`Tank` values that do NOT trigger rollover/overfill and assert `calculatedSaleLitres`/`stockVariance`/`stockPercentage`/`isLowStock`/`isValidReading` match pre-fix values, and the new `hasRolloverAnomaly`/`hasOverfillAnomaly` getters read `false`
  - Verify test PASSES on UNFIXED code (for the validator/audit-logging portion; the new anomaly getters do not exist yet on unfixed code, so scope that assertion to run once the getters land in Phase 3, tracked as a follow-up re-run in task 35.3)
  - _Requirements: 3.4, 3.5, 3.8_

- [x] 20. Write preservation property test — Existing UserRole Resolution Preserved
  - **Property 16: Preservation** - Existing UserRole Resolution Preserved
  - **IMPORTANT**: Observe `RolePermissions.hasPermission` results for all 11 pre-existing `UserRole` values (`owner`, `manager`, `staff`, `accountant`, `pharmacist`, `waiter`, `chef`, `captain`, `doctor`, `receptionist`, `nurse`, `unknown`) on UNFIXED code
  - Property-based test: generate all 11 pre-existing `UserRole` values against arbitrary `Permission` checks and assert results are unchanged after `attendant` is added; also assert no non-petrolPump sidebar's capability/permission gates change
  - Verify test PASSES on UNFIXED code
  - _Requirements: 3.6_

### Phase 3: Implementation (one parent task per surface)

- [x] 21. Fix Surface 1: billing.fuelSaleWiring

  - [x] 21.1 Implement the fix
    - In `bill_creation_screen_v2.dart._handleSave`, resolve the active shift via `sl<ShiftService>().getActiveShift()` when `saveBusinessType == BusinessType.petrolPump`; block the save with a SnackBar if `null`
    - Resolve the attendant identity from the existing staff/session identity source; fall back to owner/session id if none selected
    - Set `shiftId`/`attendantId` on the `Bill(...)` constructor call for petrolPump bills only
    - In `_addItem`/`_addItemWithStockWarning`'s non-pharmacy branch, add an `else if (businessType == BusinessType.petrolPump)` arm that forces `newItemGstRate = 0.0` / `newItemCgst = 0.0` / `newItemSgst = 0.0`, ahead of the generic `else`
    - After `_billsRepo.createBill(newBill)`, additionally call `sl<PetrolPumpBillingService>().createFuelBill(...)` for petrolPump bills with a nozzle/fuel selection, additive to the existing generic call
    - _Bug_Condition: isBugCondition(X) where X.surface = 'billing.fuelSaleWiring'_
    - _Expected_Behavior: Correctness Property 1 from design.md_
    - _Preservation: non-petrolPump `_handleSave`/`_addItem` branches and existing GST-default values are unaffected (Correctness Property 16)_
    - _Requirements: 1.1, 2.1_

  - [x] 21.2 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Fuel Sale Wiring
    - Re-run the SAME test from task 1 — do NOT write a new test
    - Expected outcome: test PASSES (petrolPump bills now carry `shiftId`/`attendantId`, GST forced to `0`)
    - _Requirements: 2.1_

  - [x] 21.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Non-Petrol and GST-Default Behaviors Unchanged
    - Re-run tasks 16 and 17's tests — do NOT write new tests
    - Expected outcome: tests PASS (no regression to non-petrolPump billing or GST defaults)
    - _Requirements: 3.1, 3.2_

- [x] 22. Fix Surface 2: datastore.splitBrain

  - [x] 22.1 Implement the fix
    - Migrate `TankService` (`saveTank`, `addPurchase`, `recordDipReading`, `adjustStock`, `deductSales`) from `_firestore.collection(...)`/`runTransaction` onto `_db.select(_db.tanks)`/`_db.transaction` plus `_enqueueSync(...)` after every write
    - Migrate `DispenserService` (`saveDispenser`, `saveNozzle`, `getDispensers`, `getNozzlesByDispenser`, `getAllNozzles`, `updateOpeningReading`, `updateClosingReading`) onto `_db.select(_db.dispensers)`/`_db.select(_db.nozzles)` plus companion inserts/updates and `_enqueueSync`
    - Add a `fuelTypes` Drift table and migrate `FuelService` (`getFuelTypes`, `updateFuelRate`, `addFuelType`, `toggleFuelStatus`, `initializeDefaultFuels`) onto it plus `_enqueueSync`
    - Migrate `PeriodLockService` onto a Drift-backed lock table/query, reusing the existing `LockingService` pattern if available
    - Preserve each method's `Stream<List<T>>` return signature via `.watch()`-based queries so `StreamBuilder` consumers require no changes
    - _Bug_Condition: isBugCondition(X) where X.surface = 'datastore.splitBrain'_
    - _Expected_Behavior: Correctness Property 2 from design.md_
    - _Preservation: `TankService.recordDipReading`'s variance audit logging and `DispenserService`'s audit logging retain identical trigger conditions/actions/metadata shape (Correctness Property 16)_
    - _Requirements: 1.2, 2.2_

  - [x] 22.2 Verify bug condition exploration test now passes
    - **Property 2: Expected Behavior** - Unified Datastore
    - Re-run the SAME test from task 2 — do NOT write a new test
    - Expected outcome: test PASSES (a tank written via `TankService` is now visible in the Drift `tanks` table)
    - _Requirements: 2.2_

  - [x] 22.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Validators and Audit Logging Unchanged
    - Re-run task 19's test — do NOT write a new test
    - Expected outcome: test PASSES (existing validators and audit logging behave identically post-migration)
    - _Requirements: 3.4, 3.5_

- [x] 23. Fix Surface 3: ui.dispenserNozzleReadingEntry

  - [x] 23.1 Implement the fix
    - Restore the FAB in `dispenser_list_screen.dart`, backed by a new `AddDispenserDialog` calling `sl<DispenserService>().saveDispenser(...)`
    - Restore the "Add Nozzle" affordance, backed by a new `AddNozzleDialog` (fuel-type dropdown from `FuelService.getFuelTypes()`, tank-link dropdown from `TankService.getTanks()`) calling `sl<DispenserService>().saveNozzle(...)`
    - Add a new `NozzleReadingDialog` (opening/closing reading fields) calling `updateOpeningReading(...)`/`updateClosingReading(...)` with the acting `employeeId`, reachable from a new per-nozzle `IconButton`
    - _Bug_Condition: isBugCondition(X) where X.surface = 'ui.dispenserNozzleReadingEntry'_
    - _Expected_Behavior: Correctness Property 3 from design.md_
    - _Preservation: existing dispenser list rendering and responsive layout unaffected (Correctness Property 16)_
    - _Requirements: 1.3, 2.3_

  - [x] 23.2 Verify bug condition exploration test now passes
    - **Property 3: Expected Behavior** - Dispenser/Nozzle/Reading Entry UI
    - Re-run the SAME test from task 3 — do NOT write a new test
    - Expected outcome: test PASSES (FAB and "Add Nozzle" affordances now exist and invoke `DispenserService`)
    - _Requirements: 2.3_

  - [x] 23.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Non-Petrol and Layout Behaviors Unchanged
    - Re-run task 16's test — do NOT write a new test
    - Expected outcome: test PASSES
    - _Requirements: 3.1, 3.7_

- [x] 24. Fix Surface 4: dashboard.orphaned

  - [x] 24.1 Implement the fix
    - In `sidebar_navigation_handler.dart`, change `case 'petrol_dashboard':` to return `const RevenueDashboardScreen()`
    - In `petrol_pump_management_screen.dart`, insert `const PetrolPumpDashboardWidgets()` above the existing 4-tile `ListView`, keeping the menu as a secondary settings hub
    - _Bug_Condition: isBugCondition(X) where X.surface = 'dashboard.orphaned'_
    - _Expected_Behavior: Correctness Property 4 from design.md_
    - _Preservation: other sidebar routing cases and the 4-tile settings menu remain reachable (Correctness Property 16)_
    - _Requirements: 1.4, 2.4_

  - [x] 24.2 Verify bug condition exploration test now passes
    - **Property 4: Expected Behavior** - Dashboard Reachability
    - Re-run the SAME test from task 4 — do NOT write a new test
    - Expected outcome: test PASSES (`petrol_dashboard` now resolves to `RevenueDashboardScreen`)
    - _Requirements: 2.4_

  - [x] 24.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Sidebar Routing Unchanged for Other Cases
    - Re-run task 16's test — do NOT write a new test
    - Expected outcome: test PASSES
    - _Requirements: 3.1_

- [x] 25. Fix Surface 5: alerts.hardcodedCounts

  - [x] 25.1 Implement the fix
    - Add a `petrolPumpAlertCountsProvider` (`FutureProvider.autoDispose<PetrolPumpAlertSnapshot>`) querying `AppDatabase` for low-tank count and pending-settlement count, following the file's established per-vertical snapshot pattern
    - Replace `count: '2'`/`count: '1'` in `case BusinessType.petrolPump:` with the `_displayCount(...)`/`'...'`/`'!'` ternary already used by every other case
    - _Bug_Condition: isBugCondition(X) where X.surface = 'alerts.hardcodedCounts'_
    - _Expected_Behavior: Correctness Property 5 from design.md_
    - _Preservation: every other business type's alert case in `business_alerts_widget.dart` unaffected (Correctness Property 16)_
    - _Requirements: 1.5, 2.5_

  - [x] 25.2 Verify bug condition exploration test now passes
    - **Property 5: Expected Behavior** - Live Alert Counts
    - Re-run the SAME test from task 5 — do NOT write a new test
    - Expected outcome: test PASSES (counts vary with fixture data)
    - _Requirements: 2.5_

  - [x] 25.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Other Business Types' Alerts Unchanged
    - Re-run task 16's test — do NOT write a new test
    - Expected outcome: test PASSES
    - _Requirements: 3.1_

- [x] 26. Fix Surface 6: report.fuelProfitHardcoded

  - [x] 26.1 Implement the fix
    - Add `_computeSummary(DateTimeRange range)` querying `BillsRepository` for petrolPump bills within range, summing Total Sales/Litres Sold/Revenue, and reading Surface 7's persisted purchase price for Total Cost; compute Profit/Margin
    - Wire `_selectDateRange` to store the picked range in state and call `_computeSummary`, replacing SnackBar-only feedback
    - Replace the `'₹0'`/`'0 L'`/`'0%'` literals with computed values
    - _Bug_Condition: isBugCondition(X) where X.surface = 'report.fuelProfitHardcoded'_
    - _Expected_Behavior: Correctness Property 6 from design.md_
    - _Preservation: report layout/structure unaffected, only the data source changes (Correctness Property 16)_
    - _Requirements: 1.6, 2.6_
    - _Depends on: Surface 7 (task 27) for cost data — implement task 27 first or stub cost as 0 until task 27 lands_

  - [x] 26.2 Verify bug condition exploration test now passes
    - **Property 6: Expected Behavior** - Real Fuel Profit Figures
    - Re-run the SAME test from task 6 — do NOT write a new test
    - Expected outcome: test PASSES (Total Sales reflects seeded bill data)
    - _Requirements: 2.6_

  - [x] 26.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Non-Petrol Reports Unchanged
    - Re-run task 16's test — do NOT write a new test
    - Expected outcome: test PASSES
    - _Requirements: 3.1_

- [x] 27. Fix Surface 7: stock.purchasePriceDiscarded

  - [x] 27.1 Implement the fix
    - Extend `TankService.addPurchase`'s signature with optional named `double? pricePerLitre`; when provided, include `pricePerLitre`/`totalCost` in the `_logStockEvent` metadata map (additive, not replacing existing metadata)
    - In `add_stock_dialog.dart._submit`, pass `pricePerLitre: _priceController.text.isNotEmpty ? double.tryParse(_priceController.text) : null` to `addPurchase`
    - _Bug_Condition: isBugCondition(X) where X.surface = 'stock.purchasePriceDiscarded'_
    - _Expected_Behavior: Correctness Property 7 from design.md_
    - _Preservation: existing callers that omit `pricePerLitre` continue to work unchanged (Correctness Property 16)_
    - _Requirements: 1.7, 2.7_

  - [x] 27.2 Verify bug condition exploration test now passes
    - **Property 7: Expected Behavior** - Purchase Price Persisted
    - Re-run the SAME test from task 7 — do NOT write a new test
    - Expected outcome: test PASSES (price is persisted in stock-movement metadata)
    - _Requirements: 2.7_

  - [x] 27.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Existing addPurchase Callers Unchanged
    - Re-run task 19's test — do NOT write a new test
    - Expected outcome: test PASSES (callers omitting the new parameter behave identically)
    - _Requirements: 3.4_

- [x] 28. Fix Surface 8: rbac.sidebarGateMissing

  - [x] 28.1 Implement the fix
    - Add `capability:` gates to `_getPetrolPumpSections()`'s items (`useShiftManagement`, `usePumpReadings`, `useFuelManagement`, `useStockManagement`) following the existing capability-gate pattern
    - Append `attendant` to `UserRole` (after `nurse`, before `unknown`)
    - Add a `UserRole.attendant` entry to `RolePermissions._permissions` (least-privilege: `createBill`, `printBill`, `viewStock`)
    - Add `permission: 'viewReports'` gates to `shift_report`/`tank_stock_report`/`fuel_profit_report`/`nozzle_sales_report` sidebar items
    - _Bug_Condition: isBugCondition(X) where X.surface = 'rbac.sidebarGateMissing'_
    - _Expected_Behavior: Correctness Property 8 from design.md_
    - _Preservation: existing 11 `UserRole` values and non-petrolPump sidebar gates unaffected (Correctness Property 16)_
    - _Requirements: 1.8, 2.8_

  - [x] 28.2 Verify bug condition exploration test now passes
    - **Property 8: Expected Behavior** - Sidebar Capability & Role Gating
    - Re-run the SAME test from task 8 — do NOT write a new test
    - Expected outcome: test PASSES (`capability` is set; `UserRole.attendant` exists)
    - _Requirements: 2.8_

  - [x] 28.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Existing UserRole Resolution Unchanged
    - Re-run task 20's test — do NOT write a new test
    - Expected outcome: test PASSES
    - _Requirements: 3.6_

- [x] 29. Fix Surface 9: rbac.readingPermissionBypass

  - [x] 29.1 Implement the fix
    - In `DispenserService.updateOpeningReading` and the non-`isSystemUpdate` branch of `updateClosingReading`, replace the `if (employeeId != null) { check }` pattern with an unconditional check that denies by default when `employeeId` is `null` or the resolved employee lacks `canEditReadings`, throwing `PermissionDeniedException` and logging the unauthorized attempt
    - Leave the `isSystemUpdate: true` bypass in `updateClosingReading` untouched (distinct, intentional bypass)
    - Update the new `NozzleReadingDialog` (Surface 3) to pass the acting `employeeId`
    - _Bug_Condition: isBugCondition(X) where X.surface = 'rbac.readingPermissionBypass'_
    - _Expected_Behavior: Correctness Property 9 from design.md_
    - _Preservation: `isSystemUpdate: true` bypass path unaffected (Correctness Property 16)_
    - _Requirements: 1.9, 2.9_

  - [x] 29.2 Verify bug condition exploration test now passes
    - **Property 9: Expected Behavior** - Reading Permission Enforced
    - Re-run the SAME test from task 9 — do NOT write a new test
    - Expected outcome: test PASSES (missing/unauthorized `employeeId` now throws `PermissionDeniedException`)
    - _Requirements: 2.9_

  - [x] 29.3 Verify preservation tests still pass
    - **Property 16: Preservation** - System-Update Bypass Unchanged
    - Re-run task 19's test — do NOT write a new test
    - Expected outcome: test PASSES (`isSystemUpdate: true` calls still bypass as before)
    - _Requirements: 3.5_

- [x] 30. Fix Surface 10: shift.rolloverAndBilledLitres

  - [x] 30.1 Implement the fix
    - In `ShiftService.calculateShiftSales`, replace direct `closingReading - openingReading` subtraction with `PetrolPumpBusinessRules.dispensedLitres(startReading: ..., endReading: ...)`
    - Build a `billedLitresByNozzle` map from `billsList` (move the fetch earlier in the function) and replace `NozzleReconciliation(..., billedLitres: 0, variance: 0)` with real computed values
    - _Bug_Condition: isBugCondition(X) where X.surface = 'shift.rolloverAndBilledLitres'_
    - _Expected_Behavior: Correctness Property 10 from design.md_
    - _Preservation: `closeShift`'s tolerance/variance decision logic and `forceClose` behavior unaffected — only reconciliation inputs improve (Correctness Property 16)_
    - _Requirements: 1.10, 2.10_

  - [x] 30.2 Verify bug condition exploration test now passes
    - **Property 10: Expected Behavior** - Rollover-Aware, Real Billed Litres
    - Re-run the SAME test from task 10 — do NOT write a new test
    - Expected outcome: test PASSES (rollover pairs produce correct positive litres; `billedLitres`/`variance` reflect seeded bills)
    - _Requirements: 2.10_

  - [x] 30.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Shift-Close Decision Logic Unchanged
    - Re-run task 18's test — do NOT write a new test
    - Expected outcome: test PASSES
    - _Requirements: 3.3_

- [x] 31. Fix Surface 11: fuelRates.fabAndBoundsMissing

  - [x] 31.1 Implement the fix
    - Wire the Fuel Rates FAB `onPressed` to open a new add-fuel-type dialog calling `sl<FuelService>().addFuelType(...)`
    - Add `_minFuelRate`/`_maxFuelRate` constants and bounds validation to `_showUpdateRateDialog`'s update flow, rejecting out-of-bounds values with a SnackBar
    - _Bug_Condition: isBugCondition(X) where X.surface = 'fuelRates.fabAndBoundsMissing'_
    - _Expected_Behavior: Correctness Property 11 from design.md_
    - _Preservation: in-bounds rate updates continue to apply exactly as today (Correctness Property 16)_
    - _Requirements: 1.11, 2.11_

  - [x] 31.2 Verify bug condition exploration test now passes
    - **Property 11: Expected Behavior** - Fuel Rate FAB & Bounds
    - Re-run the SAME test from task 11 — do NOT write a new test
    - Expected outcome: test PASSES (FAB opens a dialog; out-of-bounds rates rejected)
    - _Requirements: 2.11_

  - [x] 31.3 Verify preservation tests still pass
    - **Property 16: Preservation** - In-Bounds Rate Updates Unchanged
    - Re-run task 17's test — do NOT write a new test
    - Expected outcome: test PASSES
    - _Requirements: 3.2_

- [x] 32. Fix Surface 12: bug.mojibake

  - [x] 32.1 Implement the fix
    - Replace both `'â‚¹${...}'` occurrences in `shift_report_screen.dart` with `'₹${...}'`
    - Replace the mojibake comment sequences in `petrol_pump_business_rules.dart` (`â€”`→`—`, `Ã—`→`×`, `âˆ’`→`−`) — comment-only, zero effect on compiled behavior
    - _Bug_Condition: isBugCondition(X) where X.surface = 'bug.mojibake'_
    - _Expected_Behavior: Correctness Property 12 from design.md_
    - _Preservation: no compiled-code behavior changes, only text/comment content (Correctness Property 16)_
    - _Requirements: 1.12, 2.12_

  - [x] 32.2 Verify bug condition exploration test now passes
    - **Property 12: Expected Behavior** - Correct Currency & Punctuation Glyphs
    - Re-run the SAME test from task 12 — do NOT write a new test
    - Expected outcome: test PASSES (correct `₹`/`—`/`×`/`−` glyphs render/appear)
    - _Requirements: 2.12_

  - [x] 32.3 Verify preservation tests still pass
    - **Property 16: Preservation** - No Behavioral Change from Comment/Text Fix
    - Re-run task 16's test — do NOT write a new test
    - Expected outcome: test PASSES
    - _Requirements: 3.1_

- [x] 33. Fix Surface 13: bug.escapedErrorString

  - [x] 33.1 Implement the fix
    - In `add_tank_dialog.dart._submit`'s catch block, change `content: Text('Error: \$e'),` to `content: Text('Error: $e'),`
    - Apply the identical fix to `dip_reading_dialog.dart._submit`'s catch block
    - Leave `add_stock_dialog.dart`'s already-correct catch block unchanged
    - _Bug_Condition: isBugCondition(X) where X.surface = 'bug.escapedErrorString'_
    - _Expected_Behavior: Correctness Property 13 from design.md_
    - _Preservation: `add_stock_dialog.dart`'s catch block and all other dialog error handling unaffected (Correctness Property 16)_
    - _Requirements: 1.13, 2.13_

  - [x] 33.2 Verify bug condition exploration test now passes
    - **Property 13: Expected Behavior** - Real Error Messages
    - Re-run the SAME test from task 13 — do NOT write a new test
    - Expected outcome: test PASSES (SnackBar shows the actual exception message)
    - _Requirements: 2.13_

  - [x] 33.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Other Dialog Error Handling Unchanged
    - Re-run task 19's test — do NOT write a new test
    - Expected outcome: test PASSES
    - _Requirements: 3.4_

- [x] 34. Fix Surface 14: bug.debugPrints

  - [x] 34.1 Implement the fix
    - Remove all nine `print('DEBUG: ...')` calls in `petrol_pump_billing_service.dart.createFuelBill` with no replacement
    - Remove all five `print('DEBUG: ...')` calls in `shift_service.dart`; replace the catch block's two `print` calls with a single `debugPrint('Shift Insert Failed: $e\n$stack');` call, leaving the `rethrow` unchanged
    - _Bug_Condition: isBugCondition(X) where X.surface = 'bug.debugPrints'_
    - _Expected_Behavior: Correctness Property 14 from design.md_
    - _Preservation: transactional logic and error-path `rethrow` behavior unaffected — only console output changes (Correctness Property 16)_
    - _Requirements: 1.14, 2.14_

  - [x] 34.2 Verify bug condition exploration test now passes
    - **Property 14: Expected Behavior** - No Debug Console Output
    - Re-run the SAME test from task 14 — do NOT write a new test
    - Expected outcome: test PASSES (no `DEBUG:` lines printed)
    - _Requirements: 2.14_

  - [x] 34.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Transactional/Error-Path Behavior Unchanged
    - Re-run task 19's test — do NOT write a new test
    - Expected outcome: test PASSES
    - _Requirements: 3.5_

- [x] 35. Fix Surface 15: validation.silentClampNoFlag

  - [x] 35.1 Implement the fix
    - Add `Nozzle.hasRolloverAnomaly` getter (`closingReading - openingReading < 0`); leave `calculatedSaleLitres`'s existing clamp-to-`0` behavior unchanged
    - Add `Tank.hasOverfillAnomaly` getter comparing unclamped calculated stock against `capacity`; leave `addPurchase`'s existing clamp-to-`capacity` behavior unchanged
    - Update `dispenser_list_screen.dart`/`NozzleReadingDialog` to show a warning when `hasRolloverAnomaly` is true; update `AddStockDialog`'s success SnackBar to append an over-fill warning when `hasOverfillAnomaly` is true
    - _Bug_Condition: isBugCondition(X) where X.surface = 'validation.silentClampNoFlag'_
    - _Expected_Behavior: Correctness Property 15 from design.md_
    - _Preservation: `calculatedSaleLitres`/`addPurchase`'s clamped return values unchanged; new getters are additive (Correctness Property 16)_
    - _Requirements: 1.15, 2.15_

  - [x] 35.2 Verify bug condition exploration test now passes
    - **Property 15: Expected Behavior** - Anomaly Flagged Alongside Clamp
    - Re-run the SAME test from task 15 — do NOT write a new test
    - Expected outcome: test PASSES (`hasRolloverAnomaly`/`hasOverfillAnomaly` correctly flag anomalies)
    - _Requirements: 2.15_

  - [x] 35.3 Verify preservation tests still pass
    - **Property 16: Preservation** - Clamped Values and Non-Anomaly Getters Unchanged
    - Re-run task 19's test — do NOT write a new test
    - Also confirm the deferred assertion from task 19 (new anomaly getters read `false` for non-rollover/non-overfill values) now passes
    - Expected outcome: test PASSES
    - _Requirements: 3.8_

### Phase 4: Checkpoint

- [x] 36. Checkpoint - Ensure all tests pass
  - Run the full test suite (all 15 exploration tests from Phase 1, all 5 preservation tests from Phase 2, and every sub-task verification from Phase 3)
  - Confirm all 15 exploration tests now PASS (bugs fixed) and all 5 preservation tests still PASS (no regressions)
  - Ask the user if any test fails unexpectedly or if a root-cause hypothesis was refuted during Phase 1
  - Run the project's full build/analyze step (`flutter analyze`, relevant `flutter test` targets) and resolve any errors before considering the bugfix complete

## Notes

- Property numbers 1-15 map 1:1 to the 15 surfaces and to `design.md`'s Correctness Properties 1-15 (Bug Condition). Property 16 is the single shared Preservation property, split across tasks 16-20 by preserved-behavior group for testability, and re-verified in every surface's `.3` sub-task.
- Every exploration test (tasks 1-15) MUST fail on unfixed code before its corresponding implementation task begins — a passing exploration test at that stage means the test does not actually exercise the bug and must be revised.
- Every preservation test (tasks 16-20) MUST pass on unfixed code before any implementation begins, establishing the byte-for-byte baseline that Phase 3's `.3` sub-tasks re-verify after each fix.
- Surfaces 1, 3, 6, 7, 9, 10, 11 have cross-surface dependencies (see Task Dependency Graph above); all other surfaces (2, 4, 5, 8, 12, 13, 14, 15) can be implemented independently once Surface 2's datastore migration lands.
