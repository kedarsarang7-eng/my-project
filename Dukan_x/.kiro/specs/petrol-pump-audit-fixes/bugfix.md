# Bugfix Requirements Document

## Introduction

The petrol pump business-type audit (`audit-reports/business-types/audit-petrolPump.md`) flagged that `BusinessType.petrolPump` has a feature surface which is mostly built but not wired together: real domain logic exists (shift reconciliation, totalizer-rollover math, permission checks, audit logging, a rich KPI dashboard, fraud-proof transactional billing) but the live user-facing paths never call it, and the data that does flow is split across two disconnected backends.

Direct re-verification of the current codebase (not just the audit's original findings) against every file in the audit's "Sampled" list confirms the following starting state:

- **Already fixed, no action needed in this spec**: the GST-rate defaults are already corrected at the config/model level — `BusinessTypeConfig` for `petrolPump` now sets `defaultGstRate: 0.0`, `FuelType.linkedGSTRate` now defaults to `0.0`, and `PetrolPumpBillingService.createFuelBill` hardcodes `const gstRate = 0.0` with a compliance comment. These three data points are out of scope for this bugfix.
- **Still defective (in scope)**: 15 distinct defects remain, verified by direct reads of `petrol_pump_billing_service.dart`, `shift_service.dart`, `tank_service.dart`, `dispenser_service.dart`, `fuel_service.dart`, `firestore_compat.dart`, `bill_creation_screen_v2.dart`, `dispenser_list_screen.dart`, `fuel_rates_screen.dart`, `petrol_pump_management_screen.dart`, `business_alerts_widget.dart`, `fuel_profit_report_screen.dart`, `shift_report_screen.dart`, `add_tank_dialog.dart`, `dip_reading_dialog.dart`, `add_stock_dialog.dart`, `tank.dart`, `nozzle.dart`, `petrol_pump_business_rules.dart`, `sidebar_configuration.dart`, and `user_role.dart` (session_manager's `UserRole` source of truth). Critically, `bill_creation_screen_v2.dart` (4594 lines) has **zero** matches for `shiftId`, `attendantId`, `petrolPump`, `nozzleId`, or `PetrolPumpBillingService` — petrol sales carry no shift/attendant linkage and never touch the fraud-proof billing service at all, so even the already-fixed GST default is not defensively enforced on that live path.

This bugfix wires the built-but-disconnected petrol pump logic into the live UI paths, unifies the split-brain datastore for the safety-critical reading/stock path, adds the missing configuration UI, replaces hardcoded numbers with live queries, closes the permission bypass, and fixes cosmetic defects (mojibake, escaped error strings, debug prints) — while leaving every other business type and petrol pump's own already-correct behaviors (GST defaults, shift-close fraud tolerance checks, tank/dip validation, responsive layout) untouched.

Grouped by the audit's own §19 priority scale (P0 Critical, P1 High, P2 Medium):

## Bug Analysis

### Current Behavior (Defect)

**P0 — Critical (data integrity / correctness)**

1.1 WHEN a petrol pump sale is created via the `new_sale` sidebar item (routes to generic `BillCreationScreenV2`) THEN the system creates the bill with no `shiftId`/`attendantId`, never calls `PetrolPumpBillingService.createFuelBill`, and does not defensively force the fuel line's GST rate to 0 (it simply inherits whichever `taxRate` the fuel `Product` record happens to carry), so tank stock, nozzle readings, and shift reconciliation are never updated by real sales and fuel GST correctness has no enforcement on the path customers actually use

1.2 WHEN nozzle opening/closing readings are written via `DispenserService.updateOpeningReading`/`updateClosingReading` (Firestore-compat → API/DynamoDB) THEN they never reach the Drift `nozzles` table that `ShiftService.calculateShiftSales` reads from, so `TankService`/`DispenserService`/`FuelService`/`PeriodLockService` (API-backed) and `ShiftService`/`PetrolPumpBillingService` (Drift-backed) operate on two disconnected records of the same tanks/nozzles, and tanks/dispensers/nozzles/fuel rates have no offline sync queue (fail or serve stale data with no network)

1.3 WHEN a station operator wants to add a dispenser, add a nozzle to a dispenser, or record an opening/closing meter reading for a nozzle THEN no UI exists anywhere in the app to do so (`dispenser_list_screen.dart`'s FAB and "Add Nozzle" button are both removed with a "not fully implemented" comment, and no reading-entry screen exists in the `petrol_pump` feature folder)

1.4 WHEN a user opens `petrol_dashboard` from the sidebar THEN the system shows a bare 4-item menu list (`PetrolPumpManagementScreen`) instead of the fully-built KPI dashboard (`RevenueDashboardScreen`, with revenue/txns/litres/avg-ticket/hourly chart/fuel pie/payment split/staff leaderboard) or the dashboard widget bundle (`PetrolPumpDashboardWidgets`, shift status/fuel ticker/low-tank summary) — both exist and are fully implemented but have zero references anywhere outside their own definition files

**P1 — High**

1.5 WHEN the petrol pump dashboard alert panel renders THEN "Tank Levels Low" always shows the literal hardcoded count `'2'` and "Shift Settlement Pending" always shows the literal hardcoded count `'1'`, regardless of actual tank levels or pending settlements (`business_alerts_widget.dart` `case BusinessType.petrolPump`)

1.6 WHEN a user opens the Fuel Profit Analysis report THEN Total Sales/Cost/Profit always display the literal string `'₹0'`, per-fuel Litres Sold always shows `'0 L'`, Revenue always shows `'₹0'`, and Margin always shows `'0%'`, regardless of actual sales, and the date-range picker only shows a SnackBar with no filtering effect

1.7 WHEN a user enters a "Purchase Price per Litre" in `AddStockDialog` and submits THEN the price is read into `_priceController` but never passed to `TankService.addPurchase(tankId, quantity)` (whose signature has no price parameter at all), so purchase cost is always discarded and profit/margin can never be computed from real data

1.8 WHEN any authenticated user (regardless of role) views the sidebar for a petrolPump business THEN every item under `_getPetrolPumpSections()` is fully visible and operable with no `capability:`/`permission:` gate, and WHEN role resolution occurs in `SessionManager` THEN the `UserRole` enum has no `attendant`/`shiftOperator` value, so shift-management and pump-reading capabilities registered in `business_capability.dart` are never enforced

1.9 WHEN `DispenserService.updateOpeningReading`/`updateClosingReading` is called with `employeeId == null` (which is every call site today, since no caller passes one) THEN the `canEditReadings` permission check is skipped entirely and the reading update proceeds unconditionally

1.10 WHEN `ShiftService.calculateShiftSales` computes litres sold per nozzle THEN it always computes `closingReading - openingReading` directly, never calling the already-implemented `PetrolPumpBusinessRules.dispensedLitres` (which correctly handles totalizer rollover), so a nozzle whose totalizer has rolled over produces a large negative litres value that corrupts shift reconciliation; separately, every `NozzleReconciliation` entry hardcodes `billedLitres: 0` and `variance: 0` with a "Not tracking per-nozzle billing yet" comment

1.11 WHEN a user opens `FuelRatesScreen` and taps the floating action button THEN nothing happens (the `onPressed` body is an empty comment), and WHEN a user updates a fuel rate via `_showUpdateRateDialog` THEN the new rate is accepted from `double.tryParse` with no minimum/maximum bounds check and no effective-from time — the change takes effect immediately with no scheduling

**P2 — Medium**

1.12 WHEN `ShiftReportScreen` renders Total Sales or any per-payment-type mini-stat THEN the currency symbol renders as the mojibake sequence `â‚¹` instead of `₹`, and WHEN `petrol_pump_business_rules.dart`'s header comment or inline comments render THEN they contain separate mojibake sequences (`â€”`, `Ã—`, `âˆ’`) for em-dash, multiplication, and minus sign

1.13 WHEN a `TankService` call throws inside `AddTankDialog._submit` or `DipReadingDialog._submit` THEN the SnackBar displays the literal text `Error: $e` (escaped interpolation) instead of the actual exception message, hiding the real error from the user

1.14 WHEN `ShiftService.openShift`/`_resetNozzlesForShift` or `PetrolPumpBillingService.createFuelBill` executes THEN raw `print('DEBUG: ...')` statements (5 in `shift_service.dart`, 8 in `petrol_pump_billing_service.dart`) write to the production console/log

1.15 WHEN `Nozzle.calculatedSaleLitres` computes a negative value (e.g. from an unhandled totalizer rollover) THEN it silently clamps to `0` instead of flagging the anomaly, and WHEN `Tank.addPurchase` would push `currentStock` above `capacity` THEN it silently clamps to `capacity`, discarding the overflow litres with no over-fill warning

### Expected Behavior (Correct)

**P0 — Critical**

2.1 WHEN a petrol pump sale is created THEN the system SHALL set `shiftId` (from the active shift) and `attendantId` on the resulting bill, and SHALL force the fuel line item's GST rate to `0` regardless of any stored `Product.taxRate`, so tank stock, nozzle readings, and shift reconciliation are driven by real sales and fuel GST correctness is enforced on the path customers actually use

2.2 WHEN nozzle, tank, dispenser, or fuel-rate reads/writes occur for petrol pump THEN the system SHALL route them through a single source of truth shared with `ShiftService`/`PetrolPumpBillingService` (either by migrating `TankService`/`DispenserService`/`FuelService`/`PeriodLockService` onto the Drift + `SyncQueue` pattern, or the inverse), so a reading or stock change made through any one service is immediately visible to every other service and survives offline use

2.3 WHEN a station operator needs to add a dispenser, add a nozzle, or record an opening/closing meter reading THEN the system SHALL provide UI to do so, reachable from the dispenser/nozzle management screen

2.4 WHEN a user opens `petrol_dashboard` from the sidebar THEN the system SHALL render the existing KPI dashboard (`RevenueDashboardScreen`) and/or `PetrolPumpDashboardWidgets`, replacing the bare menu list, so the fully-built petrol UI becomes reachable

**P1 — High**

2.5 WHEN the petrol pump dashboard alert panel renders THEN "Tank Levels Low" and "Shift Settlement Pending" counts SHALL be computed from live tank-level and pending-settlement queries, not hardcoded literals

2.6 WHEN a user opens the Fuel Profit Analysis report THEN Total Sales/Cost/Profit, per-fuel Litres Sold, Revenue, and Margin SHALL be computed from real bill/purchase data, and the date-range picker SHALL actually filter the displayed figures to the selected range

2.7 WHEN a user enters a purchase price in `AddStockDialog` and submits THEN the system SHALL persist that price (extending `TankService.addPurchase`'s signature and the underlying stock-movement/purchase record) so profit/margin reports can compute real cost data

2.8 WHEN the sidebar renders petrol pump items THEN each item SHALL declare an appropriate `capability:`/`permission:` gate consistent with the registered `useFuelManagement`/`usePumpReadings`/`useShiftManagement` capabilities, and the system SHALL introduce an `attendant` (or `shiftOperator`) value in the core `UserRole` enum so pump-attendant identity can be resolved by RBAC rather than only by the separate `Employee` model

2.9 WHEN `DispenserService.updateOpeningReading`/`updateClosingReading` is called THEN the system SHALL require and validate `employeeId` (or an equivalent authenticated-caller identity) and SHALL NOT skip the `canEditReadings` permission check when it is null

2.10 WHEN `ShiftService.calculateShiftSales` computes litres sold per nozzle THEN it SHALL call `PetrolPumpBusinessRules.dispensedLitres(startReading, endReading)` so totalizer rollover is handled correctly, and SHALL compute a real per-nozzle `billedLitres`/`variance` from the bills attributed to that nozzle instead of hardcoding `0`

2.11 WHEN a user taps the Fuel Rates FAB THEN the system SHALL open a working "add custom fuel type" flow, and WHEN a user updates a fuel rate THEN the system SHALL validate the new rate against sane min/max bounds and SHALL support (or explicitly document as out of scope with a clear message) an effective-from time before applying the new rate

**P2 — Medium**

2.12 WHEN `ShiftReportScreen` renders any currency value THEN it SHALL display the correct `₹` glyph, and WHEN `petrol_pump_business_rules.dart`'s comments render/are read THEN they SHALL use correct UTF-8 punctuation instead of mojibake

2.13 WHEN a `TankService` call throws inside `AddTankDialog._submit` or `DipReadingDialog._submit` THEN the SnackBar SHALL interpolate and display the actual exception message (`Error: $e` with real string interpolation, not the escaped literal)

2.14 WHEN `ShiftService.openShift`/`_resetNozzlesForShift` or `PetrolPumpBillingService.createFuelBill` executes THEN the system SHALL NOT write raw `print('DEBUG: ...')` statements to the production console (removed or replaced with a proper conditional/debug-only logger)

2.15 WHEN `Nozzle.calculatedSaleLitres` would otherwise be negative, or `Tank.addPurchase` would otherwise exceed `capacity` THEN the system SHALL surface a flag/warning (e.g. an anomaly indicator or over-fill warning) alongside the existing clamped value, instead of silently clamping with no signal

### Unchanged Behavior (Regression Prevention)

3.1 WHEN any business type OTHER than `petrolPump` creates a bill, views its sidebar, records inventory/stock changes, or renders its dashboard/alerts/reports THEN the system SHALL CONTINUE TO behave exactly as it does today, with zero references to `PetrolPumpBillingService`, `ShiftService`, `PetrolPumpBusinessRules`, or any petrol-specific capability/role added by this fix

3.2 WHEN `BusinessTypeConfig.petrolPump.defaultGstRate` (`0.0`) or `FuelType.linkedGSTRate`'s default (`0.0`) is read THEN the system SHALL CONTINUE TO return the same already-correct values — this fix enforces that value on the live billing path, it does not change the values themselves

3.3 WHEN `ShiftService.closeShift`'s existing reconciliation-tolerance check, cash-declaration variance check, and `forceClose` owner-override logging run THEN the system SHALL CONTINUE TO behave exactly as today, unaffected by the rollover-aware litres calculation and per-nozzle billed-litres changes (only the *inputs* to reconciliation become more accurate; the reconciliation/close logic itself is untouched)

3.4 WHEN `AddTankDialog`/`DipReadingDialog`/`AddStockDialog`'s existing field validators (tank name required, capacity > 0, initial stock ≤ capacity, dip reading ≥ 0 and ≤ capacity, purchase quantity > 0 and ≤ available capacity) run THEN the system SHALL CONTINUE TO enforce them exactly as today

3.5 WHEN `TankService.recordDipReading`'s variance audit logging (`STOCK_VARIANCE_ALERT` above 10L) or `DispenserService`'s audit logging of reading changes and unauthorized attempts run THEN the system SHALL CONTINUE TO log exactly as today

3.6 WHEN a non-petrolPump sidebar's capability/permission gates are evaluated, or any existing `UserRole` value (`owner`, `manager`, `staff`, `accountant`, `pharmacist`, `waiter`, `chef`, `captain`, `doctor`, `receptionist`, `nurse`, `unknown`) is resolved THEN the system SHALL CONTINUE TO behave exactly as today — adding an `attendant`/`shiftOperator` value SHALL NOT alter resolution for any existing role

3.7 WHEN petrol screens render their existing responsive layout (`BoundedBox`, `responsiveValue`) THEN the system SHALL CONTINUE TO lay out identically across mobile/tablet/desktop, unaffected by the dashboard-wiring and hardcoded-value fixes

3.8 WHEN `Tank.stockVariance`, `Tank.stockPercentage`, `Tank.isLowStock`, `Tank.calculatedStock`, or `Nozzle.isValidReading` are read for values that do NOT trigger a rollover or over-fill condition THEN the system SHALL CONTINUE TO return the same values as today

### Bug Condition

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type PetrolPumpOperation
  OUTPUT: boolean

  // True when the operation is scoped to petrolPump AND touches one of the
  // 15 verified-still-defective surfaces
  RETURN X.businessType = BusinessType.petrolPump
     AND X.surface IN {
           'billing.fuelSaleWiring',        // 1.1 / 2.1
           'datastore.splitBrain',          // 1.2 / 2.2
           'ui.dispenserNozzleReadingEntry',// 1.3 / 2.3
           'dashboard.orphaned',            // 1.4 / 2.4
           'alerts.hardcodedCounts',        // 1.5 / 2.5
           'report.fuelProfitHardcoded',    // 1.6 / 2.6
           'stock.purchasePriceDiscarded',  // 1.7 / 2.7
           'rbac.sidebarGateMissing',       // 1.8 / 2.8
           'rbac.readingPermissionBypass',  // 1.9 / 2.9
           'shift.rolloverAndBilledLitres', // 1.10 / 2.10
           'fuelRates.fabAndBoundsMissing', // 1.11 / 2.11
           'bug.mojibake',                  // 1.12 / 2.12
           'bug.escapedErrorString',        // 1.13 / 2.13
           'bug.debugPrints',               // 1.14 / 2.14
           'validation.silentClampNoFlag'   // 1.15 / 2.15
         }
END FUNCTION
```

### Property Specification

```pascal
// Property: Fix Checking - each of the 15 petrol pump defects resolved
FOR ALL X WHERE isBugCondition(X) DO
  result ← F'(X)
  ASSERT expectedBehaviorFor(X.surface)(result)   // per 2.1-2.15 above
END FOR

// Property: Preservation - all other business types and petrol pump's own
// already-correct behaviors are unaffected
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT F(X) = F'(X)
END FOR
```
