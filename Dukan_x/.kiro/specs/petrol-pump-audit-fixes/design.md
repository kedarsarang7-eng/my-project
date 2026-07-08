# Petrol Pump Wiring & Data-Integrity Bugfix Design

## Overview

The petrol pump vertical has a large amount of correctly-implemented domain logic — fraud-proof transactional billing (`PetrolPumpBillingService`), totalizer-rollover-aware shift reconciliation (`ShiftService`, `PetrolPumpBusinessRules`), a fully-built KPI dashboard (`RevenueDashboardScreen`, `PetrolPumpDashboardWidgets`), and permission-checked reading updates (`DispenserService`) — but none of it is reachable from, or written to by, the screens a real station operator actually uses. Direct re-verification of the current codebase against every file in the audit's "Sampled" list confirms 15 distinct defects remain (the GST-default defects the audit also flagged are already fixed at the config/model level and are out of scope here).

The 15 defects fall into four families:

1. **Wiring gaps** — built logic with zero call sites: fuel sales never call `PetrolPumpBillingService.createFuelBill` (`billing.fuelSaleWiring`), no UI exists to add dispensers/nozzles or record readings (`ui.dispenserNozzleReadingEntry`), and the KPI dashboard/widget bundle are never navigated to (`dashboard.orphaned`).
2. **Split-brain datastore** — `TankService`/`DispenserService`/`FuelService`/`PeriodLockService` read/write through the Firestore-compat → API Gateway → DynamoDB bridge (`lib/core/compat/firestore_compat.dart`) while `ShiftService`/`PetrolPumpBillingService` read/write the local Drift (`AppDatabase`) `tanks`/`nozzles`/`dispensers`/`shifts` tables directly — two disconnected records of the same physical equipment (`datastore.splitBrain`).
3. **Fabricated/discarded data** — hardcoded dashboard alert counts (`alerts.hardcodedCounts`), hardcoded fuel-profit report figures (`report.fuelProfitHardcoded`), a purchase price the UI captures but the service signature has no parameter for (`stock.purchasePriceDiscarded`), and shift reconciliation that always computes `closing - opening` (ignoring totalizer rollover) with hardcoded `billedLitres: 0`/`variance: 0` per nozzle (`shift.rolloverAndBilledLitres`).
4. **Access-control and cosmetic defects** — no sidebar capability gates and no `attendant` role (`rbac.sidebarGateMissing`), a permission check that is skipped whenever `employeeId` is `null` — which is every call site today (`rbac.readingPermissionBypass`), a dead FAB and unbounded rate updates (`fuelRates.fabAndBoundsMissing`), mojibake currency/punctuation (`bug.mojibake`), escaped-literal error strings (`bug.escapedErrorString`), raw `print('DEBUG: ...')` statements (`bug.debugPrints`), and silent clamping of rollover/overfill anomalies with no flag (`validation.silentClampNoFlag`).

The fix wires the live UI paths (billing, dispenser/nozzle management, the sidebar's `petrol_dashboard` entry) into the already-built services, migrates the four Firestore-compat-backed services onto the same Drift + `SyncQueue` pattern `ShiftService`/`PetrolPumpBillingService` already use, replaces every hardcoded literal with a live query, closes the two permission gaps, and fixes the four cosmetic defects — while leaving every other business type, and petrol pump's own already-correct behaviors (GST defaults, shift-close fraud tolerance checks, tank/dip validators, responsive layout, existing audit logging), byte-for-byte unchanged.

## Glossary

- **Bug_Condition (C)**: `X.businessType == BusinessType.petrolPump AND X.surface IN {15 surface tags}` — an operation scoped to petrol pump that touches one of the 15 verified-still-defective surfaces (see Bug Details for the full `isBugCondition` spec, reused verbatim from `bugfix.md`).
- **Property (P)**: The surface-specific expected behavior defined in Requirements 2.1–2.15 of `bugfix.md`, restated per-surface in Correctness Properties below.
- **Preservation**: Every non-petrolPump business type's billing/sidebar/inventory/dashboard/report behavior, and petrol pump's own already-correct behaviors (GST defaults, shift-close reconciliation/cash-variance checks, tank/dip/purchase validators, existing audit logging, responsive layout), must remain byte-for-byte unchanged.
- **`PetrolPumpBillingService`**: `lib/features/petrol_pump/services/petrol_pump_billing_service.dart` — Drift-backed, transactional fuel billing (`createFuelBill`): validates active shift, checks tank stock, forces fuel GST to `0`, writes the bill + deducts tank stock + updates nozzle closing reading + posts a ledger entry, all inside one `_db.transaction`.
- **`ShiftService`**: `lib/features/petrol_pump/services/shift_service.dart` — Drift-backed shift lifecycle (`openShift`, `closeShift`, `calculateShiftSales`, `createStaffSettlements`).
- **`TankService` / `DispenserService` / `FuelService` / `PeriodLockService`**: `lib/features/petrol_pump/services/{tank,dispenser,fuel,period_lock}_service.dart` — currently Firestore-compat-backed (route through `lib/core/compat/firestore_compat.dart` → `ApiClient` → API Gateway → DynamoDB), disconnected from the Drift tables the two services above use.
- **`firestore_compat.dart`**: `lib/core/compat/firestore_compat.dart` — drop-in Firestore-style API (`collection().doc().get/set/update`) that actually routes through `ApiClient` to DynamoDB; polls every 30s for `snapshots()`.
- **`AppDatabase` (Drift)**: `lib/core/database/app_database.dart` — the local SQLite database with `tanks`, `nozzles`, `dispensers`, `shifts`, `bills`, `syncQueue` tables that `ShiftService`/`PetrolPumpBillingService` read/write directly via `_db.select(...)`/`_db.customStatement(...)`, with an `_enqueueSync` helper writing to `syncQueue` for offline-first sync.
- **`PetrolPumpBusinessRules`**: `lib/features/petrol_pump/utils/petrol_pump_business_rules.dart` — domain math: `dispensedLitres` (totalizer-rollover-aware), `saleValue`, `cashVariance`. Fully implemented, currently only called by tests — `ShiftService.calculateShiftSales` does not call it.
- **`Nozzle` / `Tank`**: `lib/features/petrol_pump/models/{nozzle,tank}.dart` — domain models with `calculatedSaleLitres`/`addPurchase` etc. that silently clamp anomalous values.
- **`BusinessCapability`**: `lib/core/isolation/business_capability.dart` — `useFuelManagement`/`usePumpReadings`/`useShiftManagement`/`useVehicleDetails`/`useTankerEntry`/`useStockManagement` are already registered to `'petrolPump'` in `businessCapabilityRegistry`, but no `SidebarMenuItem` in `_getPetrolPumpSections()` (`sidebar_configuration.dart`) declares a `capability:` gate referencing them.
- **`UserRole`**: `lib/core/models/user_role.dart` — has no `attendant`/`shiftOperator` value; pump-attendant identity today can only be resolved via the separate `Employee`/`EmployeePermissions` model (`lib/features/petrol_pump/models/employee.dart`), not RBAC.
- **`EmployeePermissions.canEditReadings`**: field on `Employee` (default `true`) checked by `DispenserService._checkPermission`, but only when `employeeId != null` — every call site today passes no `employeeId`, so the check never runs.

## Bug Details

### Bug Condition

The bug manifests whenever a petrolPump-scoped operation touches one of the 15 verified-still-defective surfaces. This is the same formal specification already established as the source of truth in `bugfix.md`:

**Formal Specification:**
```
FUNCTION isBugCondition(X)
  INPUT: X of type PetrolPumpOperation
  OUTPUT: boolean

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

### Examples

- **`billing.fuelSaleWiring`**: `bill_creation_screen_v2.dart` (4594 lines) has zero matches for `shiftId`, `attendantId`, `petrolPump`, `nozzleId`, or `PetrolPumpBillingService`. A petrol pump sale saved via `_handleSave` builds a plain `Bill(...)` with `shiftId: null` and no `attendantId`, and `_addItem`'s non-pharmacy branch sets `gstRate: product.taxRate` — if a fuel `Product` record is ever mis-tagged with a non-zero `taxRate`, the bill is taxed incorrectly with no defensive override.
- **`datastore.splitBrain`**: `DispenserService.updateClosingReading` writes to `_nozzleCollection.doc(nozzleId).update({...})` (API/DynamoDB), while `PetrolPumpBillingService.createFuelBill` writes the closing reading via `_db.customStatement('UPDATE nozzles SET closing_reading = ...')` (local Drift). A reading recorded through one path is invisible to the other.
- **`ui.dispenserNozzleReadingEntry`**: `dispenser_list_screen.dart` has the comment `// FAB removed until Add Dispenser is fully implemented` and `// Add Nozzle button removed until fully implemented` on the `ListTile`'s `trailing`. There is no reading-entry screen anywhere in `lib/features/petrol_pump/presentation/`.
- **`dashboard.orphaned`**: `sidebar_navigation_handler.dart`'s `case 'petrol_dashboard': return const PetrolPumpManagementScreen();` shows a 4-tile menu (Fuel Configuration, Dispenser & Nozzles, Shift Management, Tank & Stock) that only duplicates the sidebar's own `fuel_rates`/`dispenser_management`/`shift_management`/`tank_management` items — `RevenueDashboardScreen` and `PetrolPumpDashboardWidgets` (shift status card, fuel-rate ticker, low-tank summary) are fully implemented but have zero navigation references anywhere.
- **`alerts.hardcodedCounts`**: `business_alerts_widget.dart` line 1664: `case BusinessType.petrolPump: ... count: '2', ... count: '1',` — literal strings, not derived from any provider, unlike every other vertical's `_displayCount(...)` pattern in the same file.
- **`report.fuelProfitHardcoded`**: `fuel_profit_report_screen.dart`'s `_buildSummaryItem`/`_buildFuelProfitCard` calls hardcode `'₹0'`, `'0 L'`, `'0%'` regardless of `fuel` data; `_selectDateRange` calls `showDateRangePicker` and only shows a `SnackBar` with the picked range — the returned `range` is never stored or used to filter anything.
- **`stock.purchasePriceDiscarded`**: `add_stock_dialog.dart._submit` reads `_priceController.text` into local scope but never reads it — `await sl<TankService>().addPurchase(widget.tank.tankId, quantity);` only passes `quantity`; `TankService.addPurchase(String tankId, double quantity, {String? employeeId, String? invoiceNumber})` has no price parameter.
- **`rbac.sidebarGateMissing`**: `_getPetrolPumpSections()` in `sidebar_configuration.dart` builds every `SidebarMenuItem` (`petrol_dashboard`, `shift_management`, `dispenser_management`, `tank_management`, `fuel_rates`, etc.) with no `capability:`/`permission:` argument, even though `businessCapabilityRegistry['petrolPump']` already grants `useFuelManagement`/`usePumpReadings`/`useShiftManagement`; `UserRole` has 11 values and none is `attendant`.
- **`rbac.readingPermissionBypass`**: `DispenserService.updateOpeningReading`: `if (employeeId != null) { final hasPermission = await _checkPermission(...); ... }` — since no caller today passes `employeeId`, this whole block never executes and the update always proceeds.
- **`shift.rolloverAndBilledLitres`**: `ShiftService.calculateShiftSales`: `final litresSold = nozzleEntity.closingReading - nozzleEntity.openingReading;` — if a totalizer rolls over mid-shift (closing < opening), this produces a large negative value instead of calling `PetrolPumpBusinessRules.dispensedLitres`. Separately: `NozzleReconciliation(..., billedLitres: 0, variance: 0)` — hardcoded regardless of the bills actually attributed to that nozzle.
- **`fuelRates.fabAndBoundsMissing`**: `fuel_rates_screen.dart`'s `floatingActionButton: FloatingActionButton(onPressed: () { // Add custom fuel type logic }, ...)` — empty body. `_showUpdateRateDialog`'s `ElevatedButton.onPressed`: `final newRate = double.tryParse(controller.text); if (newRate != null) { await _fuelService.updateFuelRate(...) }` — accepts any positive-or-negative parseable double with no bounds check.
- **`bug.mojibake`**: `shift_report_screen.dart` renders `'â‚¹${shift.totalSaleAmount.toStringAsFixed(2)}'` (twice — `_buildStat` call site and `_buildMiniStat`) instead of `₹`; `petrol_pump_business_rules.dart`'s file header comment renders `// Petrol pump â€” domain rules` and inline comments render `saleValue = dispensedLitres Ã— pricePerLitre` and `cashVariance = expectedCash âˆ’ reportedCash`.
- **`bug.escapedErrorString`**: `add_tank_dialog.dart._submit`'s catch block: `content: Text('Error: \$e'),` — the `\$e` is an escaped literal dollar-sign-e, not string interpolation, so the SnackBar literally displays the text `Error: $e` instead of the exception's message. `dip_reading_dialog.dart._submit` has the identical defect.
- **`bug.debugPrints`**: `petrol_pump_billing_service.dart.createFuelBill` contains nine `print('DEBUG: ...')` calls (e.g. `print('DEBUG: Starting transaction for bill');`, `print('DEBUG: Inserting Bill');`); `shift_service.dart.openShift`/`_resetNozzlesForShift` contains five (`print('DEBUG: Insert Shift Companion');`, the catch block's `print('DEBUG: Shift Insert Failed: $e'); print(stack);`, `print('DEBUG: Enqueue Shift Sync');`, `print('DEBUG: Resetting Nozzles');`).
- **`validation.silentClampNoFlag`**: `Nozzle.calculatedSaleLitres`: `final sale = closingReading - openingReading; return sale >= 0 ? sale : 0;` — a rollover produces `0` with no anomaly signal. `Tank.addPurchase`: `final newStock = currentStock + quantity; return copyWith(..., currentStock: newStock.clamp(0, capacity));` — an over-capacity purchase silently discards the overflow litres.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Every non-petrolPump business type's billing (`_handleSave`, `_addItem`, `_addItemWithStockWarning`), sidebar sections, inventory/stock flows, dashboard alerts, and reports continue to execute their existing code paths with zero references to `PetrolPumpBillingService`, `ShiftService`, `PetrolPumpBusinessRules`, or any capability/role added by this fix.
- `BusinessTypeConfig.petrolPump.defaultGstRate` (`0.0`), `FuelType.linkedGSTRate`'s default (`0.0`), and `PetrolPumpBillingService.createFuelBill`'s `const gstRate = 0.0` compliance override continue to return/apply exactly the same values — this fix enforces that value on the `bill_creation_screen_v2.dart` path in addition, it does not change the values themselves.
- `ShiftService.closeShift`'s reconciliation-tolerance check (`ShiftReconciliation.isWithinTolerance`), cash-declaration variance check (`cashVarianceThreshold`), and `forceClose` owner-override audit logging continue to behave exactly as today — only the *inputs* to reconciliation (rollover-aware litres, real per-nozzle billed litres) become more accurate; the reconciliation/close decision logic itself is untouched.
- `AddTankDialog`/`DipReadingDialog`/`AddStockDialog`'s existing field validators (tank name required, capacity > 0, initial stock ≤ capacity, dip reading ≥ 0 and ≤ capacity, purchase quantity > 0 and ≤ available capacity) continue to enforce exactly as today.
- `TankService.recordDipReading`'s variance audit logging (`STOCK_VARIANCE_ALERT` above 10L) and `DispenserService`'s audit logging of reading changes (`READING_UPDATE`) and unauthorized attempts (`PERMISSION_DENIED`) continue to log exactly as today, once migrated onto Drift — same trigger conditions, same log actions, same metadata shape.
- Every existing `UserRole` value (`owner`, `manager`, `staff`, `accountant`, `pharmacist`, `waiter`, `chef`, `captain`, `doctor`, `receptionist`, `nurse`, `unknown`) resolves exactly as today — adding `attendant` does not alter resolution or `RolePermissions` for any existing role, and no non-petrolPump sidebar's capability/permission gates change.
- Petrol screens' existing responsive layout (`BoundedBox`, `responsiveValue`, `context.isMobile`) continues to lay out identically across mobile/tablet/desktop.
- `Tank.stockVariance`, `Tank.stockPercentage`, `Tank.isLowStock`, `Tank.calculatedStock`, and `Nozzle.isValidReading` continue to return the same values as today for any input that does NOT trigger a rollover or over-fill condition.
- `DispenserService.updateClosingReading`'s `isSystemUpdate` bypass (used by system-initiated closing-reading updates) is a distinct, intentional bypass path and is NOT altered by the `rbac.readingPermissionBypass` fix — only the `employeeId == null` skip in the *manual* permission-checked branches is closed.

**Scope:**
All inputs that are NOT `(businessType == petrolPump AND surface IN {the 15 tags})` are unaffected by this fix. This includes every other business type's equivalent screens, and petrol pump's own GST defaults, shift-close fraud checks, tank/dip/purchase validators, and non-rollover/non-overfill stock math.

## Hypothesized Root Cause

1. **Domain logic built ahead of UI integration.** `PetrolPumpBillingService`, `ShiftService`, `PetrolPumpBusinessRules`, `RevenueDashboardScreen`, and `PetrolPumpDashboardWidgets` are all fully implemented and internally correct, but the corresponding edits to the generic, business-type-agnostic screens (`bill_creation_screen_v2.dart`, `sidebar_navigation_handler.dart`) were never made — the same "built but not wired in" pattern seen in the pharmacy GST resolver bugfix, repeated across billing, dashboard routing, and reading entry.
2. **Two backends evolved independently.** `TankService`/`DispenserService`/`FuelService`/`PeriodLockService` were written against the Firestore-compat shim (`firestore_compat.dart`, itself a bridge to API Gateway/DynamoDB) before `ShiftService`/`PetrolPumpBillingService` were rewritten onto Drift for offline-first transactional integrity ("Refactored for Offline-First using Drift (SQLite)." per `ShiftService`'s own doc comment) — the four older services were never migrated along with them, leaving tanks/nozzles/dispensers with two disconnected records.
3. **Placeholder literals never replaced.** `business_alerts_widget.dart`'s petrolPump case and `fuel_profit_report_screen.dart` were scaffolded with fixed strings during initial UI layout (matching the surrounding widget structure of every other vertical, which *does* use live providers) and the follow-up work to wire real queries was never done — visible by contrast with the same file's `ElectronicsAlertSnapshot`/`DcAlertSnapshot`/`SchoolAlertSnapshot` providers, which are the established live-query pattern.
4. **Service signature never extended for a UI field that already exists.** `AddStockDialog._priceController` was added to the dialog's form but `TankService.addPurchase`'s signature was never extended to accept a price parameter, so the captured value has nowhere to go.
5. **Conditional permission check written defensively backwards.** `DispenserService`'s `if (employeeId != null) { check }` pattern was presumably intended to "only check when we have an identity to check," but because no caller was ever updated to pass one, the intended-safe default (skip if unknown) became "always skip."
6. **Rollover-aware helper and per-nozzle billing shipped separately from the reconciliation call site.** `PetrolPumpBusinessRules.dispensedLitres` and the `NozzleReconciliation.billedLitres`/`variance` fields exist and are unit-tested independently, but `ShiftService.calculateShiftSales` — written earlier — was never updated to call the former or populate the latter from real bill data.
7. **Copy-paste encoding corruption.** The mojibake sequences (`â‚¹` for `₹`, `â€”`/`Ã—`/`âˆ’` for em-dash/multiplication/minus) are consistent with a UTF-8 file being read/written once as Latin-1 (or similar) — a common single round-trip corruption, isolated to `shift_report_screen.dart` and `petrol_pump_business_rules.dart`.
8. **String literal vs. interpolation typo.** `'Error: \$e'` in two dialogs is a straightforward escaping mistake (`\$` intentionally escapes interpolation) most likely copy-pasted from a context where the literal text `$e` was wanted, then reused verbatim in a context where interpolation was intended — `add_stock_dialog.dart`'s otherwise-identical catch block correctly uses `'Error: $e'`, confirming the correct pattern already exists in the same feature.
9. **Debug scaffolding left in from initial transactional-integrity development.** The `print('DEBUG: ...')` statements trace every step of `createFuelBill`'s transaction and `openShift`'s nozzle reset — consistent with debugging aids added while building the offline-first Drift migration, never removed before shipping.
10. **Clamping written for safety, without a companion signal.** `Nozzle.calculatedSaleLitres` and `Tank.addPurchase` both clamp to a safe range (`0`/`capacity`) to prevent negative/over-capacity values from propagating, but neither method returns or exposes whether clamping actually occurred, so the caller (and therefore the UI) has no way to surface the anomaly.

## Correctness Properties

Property 1: Bug Condition - Fuel Sale Wiring

_For any_ petrol pump sale created via `BillCreationScreenV2` where the bug condition holds (`isBugCondition` returns true for surface `billing.fuelSaleWiring`), the fixed save path SHALL set `shiftId` from the currently active shift and `attendantId` from the acting staff identity, and SHALL force the fuel line item's GST rate to `0` regardless of any stored `Product.taxRate`.

**Validates: Requirements 2.1**

Property 2: Bug Condition - Unified Datastore

_For any_ tank, dispenser, nozzle, or fuel-rate read/write where the bug condition holds (surface `datastore.splitBrain`), the fixed `TankService`/`DispenserService`/`FuelService`/`PeriodLockService` SHALL read/write the same Drift tables `ShiftService`/`PetrolPumpBillingService` use, so a change made through any one service is immediately visible to every other service.

**Validates: Requirements 2.2**

Property 3: Bug Condition - Dispenser/Nozzle/Reading Entry UI

_For any_ request to add a dispenser, add a nozzle, or record an opening/closing meter reading where the bug condition holds (surface `ui.dispenserNozzleReadingEntry`), the fixed UI SHALL provide a reachable screen/dialog that performs the operation via `DispenserService`.

**Validates: Requirements 2.3**

Property 4: Bug Condition - Dashboard Reachability

_For any_ navigation to the `petrol_dashboard` sidebar item where the bug condition holds (surface `dashboard.orphaned`), the fixed routing SHALL render `RevenueDashboardScreen` and/or `PetrolPumpDashboardWidgets` instead of the bare 4-tile menu list.

**Validates: Requirements 2.4**

Property 5: Bug Condition - Live Alert Counts

_For any_ render of the petrol pump dashboard alert panel where the bug condition holds (surface `alerts.hardcodedCounts`), the fixed widget SHALL display "Tank Levels Low" and "Shift Settlement Pending" counts computed from a live tank-level query and a live pending-settlement query, never the literals `'2'`/`'1'`.

**Validates: Requirements 2.5**

Property 6: Bug Condition - Real Fuel Profit Figures

_For any_ render of the Fuel Profit Analysis report, or any date-range selection, where the bug condition holds (surface `report.fuelProfitHardcoded`), the fixed screen SHALL compute Total Sales/Cost/Profit, per-fuel Litres Sold, Revenue, and Margin from real bill/purchase data filtered to the selected range, never the literals `'₹0'`/`'0 L'`/`'0%'`.

**Validates: Requirements 2.6**

Property 7: Bug Condition - Purchase Price Persisted

_For any_ purchase submitted via `AddStockDialog` with a non-empty price where the bug condition holds (surface `stock.purchasePriceDiscarded`), the fixed `TankService.addPurchase` SHALL persist that price such that it is retrievable for profit/margin computation.

**Validates: Requirements 2.7**

Property 8: Bug Condition - Sidebar Capability & Role Gating

_For any_ petrol pump sidebar item, or any role-resolution request for a pump attendant, where the bug condition holds (surface `rbac.sidebarGateMissing`), the fixed sidebar item SHALL declare a `capability:`/`permission:` gate consistent with the registered `useFuelManagement`/`usePumpReadings`/`useShiftManagement` capabilities, and `UserRole` SHALL include an `attendant` value resolvable via RBAC.

**Validates: Requirements 2.8**

Property 9: Bug Condition - Reading Permission Enforced

_For any_ call to `DispenserService.updateOpeningReading`/`updateClosingReading` where the bug condition holds (surface `rbac.readingPermissionBypass`, i.e. a non-system-update call with a missing or unauthorized identity), the fixed function SHALL reject the update rather than proceeding unconditionally.

**Validates: Requirements 2.9**

Property 10: Bug Condition - Rollover-Aware, Real Billed Litres

_For any_ shift reconciliation computation where the bug condition holds (surface `shift.rolloverAndBilledLitres`), the fixed `ShiftService.calculateShiftSales` SHALL compute each nozzle's litres sold via `PetrolPumpBusinessRules.dispensedLitres(startReading, endReading)`, and SHALL compute `billedLitres`/`variance` from the bills actually attributed to that nozzle, never hardcoded `0`.

**Validates: Requirements 2.10**

Property 11: Bug Condition - Fuel Rate FAB & Bounds

_For any_ tap of the Fuel Rates FAB, or any fuel-rate update, where the bug condition holds (surface `fuelRates.fabAndBoundsMissing`), the fixed screen SHALL open a working add-fuel-type flow, and SHALL validate the new rate against sane min/max bounds before applying it.

**Validates: Requirements 2.11**

Property 12: Bug Condition - Correct Currency & Punctuation Glyphs

_For any_ render of a currency value in `ShiftReportScreen`, or any read of `petrol_pump_business_rules.dart`'s comments, where the bug condition holds (surface `bug.mojibake`), the fixed text SHALL render the correct `₹` glyph and correct UTF-8 em-dash/multiplication/minus punctuation, never the mojibake byte sequences.

**Validates: Requirements 2.12**

Property 13: Bug Condition - Real Error Messages

_For any_ exception thrown inside `AddTankDialog._submit` or `DipReadingDialog._submit` where the bug condition holds (surface `bug.escapedErrorString`), the fixed SnackBar SHALL display the actual interpolated exception message, never the literal text `Error: $e`.

**Validates: Requirements 2.13**

Property 14: Bug Condition - No Debug Console Output

_For any_ execution of `ShiftService.openShift`/`_resetNozzlesForShift` or `PetrolPumpBillingService.createFuelBill` where the bug condition holds (surface `bug.debugPrints`), the fixed functions SHALL NOT write `print('DEBUG: ...')` output to the production console.

**Validates: Requirements 2.14**

Property 15: Bug Condition - Anomaly Flagged Alongside Clamp

_For any_ computation of `Nozzle.calculatedSaleLitres` that would otherwise be negative, or `Tank.addPurchase` that would otherwise exceed `capacity`, where the bug condition holds (surface `validation.silentClampNoFlag`), the fixed code SHALL surface an anomaly flag/warning alongside the existing clamped value.

**Validates: Requirements 2.15**

Property 16: Preservation - Non-Petrol and Already-Correct Petrol Behaviors Unchanged

_For any_ input where the bug condition does NOT hold — every non-petrolPump business type's billing/sidebar/inventory/dashboard/report behavior, and petrol pump's own GST defaults, shift-close reconciliation/cash-variance checks, tank/dip/purchase field validators, existing audit logging, `isSystemUpdate` bypass, non-rollover/non-overfill stock math, and responsive layout — the fixed code SHALL produce exactly the same result as the original code.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**

## Fix Implementation

Assuming our root cause analysis is correct, changes are organized by the same 15 surfaces used in `bugfix.md`'s `isBugCondition`.

### Surface 1: `billing.fuelSaleWiring`

**File**: `lib/features/billing/presentation/screens/bill_creation_screen_v2.dart`

**Functions**: `_handleSave` (~line 2586), `_addItem`/`_addItemWithStockWarning` (~line 417/600)

**Specific Changes**:
1. **Resolve the active shift at save time.** In `_handleSave`, when `saveBusinessType == BusinessType.petrolPump`, call `await sl<ShiftService>().getActiveShift()`. If `null`, block the save with a SnackBar ("Open a shift before billing fuel sales") — mirroring the pharmacy prescription-gate block pattern already in this function. If present, capture `activeShift.shiftId`.
2. **Resolve the attendant identity.** Use the acting staff/session identity already available in this screen (the same identity source `staffListProvider`/`_session` expose) as `attendantId`; if no staff is selected, fall back to the owner/session id so the field is never left `null` for a petrolPump bill.
3. **Set `shiftId`/`attendantId` on `newBill`.** In the `Bill(...)` constructor call (~line 2916), add `shiftId: saveBusinessType == BusinessType.petrolPump ? activeShiftId : _headerBill.shiftId` and populate `attendantId: saveBusinessType == BusinessType.petrolPump ? resolvedAttendantId : null` (the `attendantId` field already exists on `Bill`, currently always `null` for this path).
4. **Force fuel GST to 0 defensively in `_addItem`'s non-pharmacy branch.** The `else` branch that sets `newItemGstRate = product.taxRate;` gets an additional `else if (businessType == BusinessType.petrolPump) { newItemGstRate = 0.0; newItemCgst = 0.0; newItemSgst = 0.0; }` arm, ahead of the generic `else`, mirroring the existing `if (businessType == BusinessType.pharmacy)` structure already in this function. Apply the identical change to `_addItemWithStockWarning`'s duplicate branch.
5. **Route through `PetrolPumpBillingService` for real stock/nozzle effects.** After the bill is persisted via `_billsRepo.createBill(newBill)`, when `saveBusinessType == BusinessType.petrolPump` and the bill has a `nozzleId`/`fuelType` selected (captured via a new petrol-specific field on `_headerBill`, following the existing `vehicleNumber`/`fuelType` pattern), additionally call `sl<PetrolPumpBillingService>().createFuelBill(nozzle: ..., fuelType: ..., litres: ..., rate: ..., customerId: ..., paymentType: _paymentMode, employeeId: resolvedAttendantId)` so tank stock and nozzle closing readings are updated through the same transactional path `bugfix.md` establishes as the source of truth. This is additive — the existing generic `_billsRepo.createBill` call is unchanged for every other business type.

### Surface 2: `datastore.splitBrain`

**Files**: `lib/features/petrol_pump/services/tank_service.dart`, `dispenser_service.dart`, `fuel_service.dart`, `period_lock_service.dart`

**Specific Changes**:
1. **Migrate `TankService` onto Drift.** Replace `_firestore.collection(...)`/`_tankCollection` reads/writes with `_db.select(_db.tanks)`/`_db.into(_db.tanks).insert(...)`/`_db.update(_db.tanks)` calls against the same `tanks` table `PetrolPumpBillingService._resolveTankForNozzle` already reads, and add an `_enqueueSync(...)` call (identical helper pattern already present in `ShiftService`/`PetrolPumpBillingService`) after every write so tank changes still reach the server when online. `saveTank`, `addPurchase`, `recordDipReading`, `adjustStock`, `deductSales` all convert from `_firestore.runTransaction` to `_db.transaction`.
2. **Migrate `DispenserService` onto Drift.** Replace `_dispenserCollection`/`_nozzleCollection` reads/writes with `_db.select(_db.dispensers)`/`_db.select(_db.nozzles)` and companion inserts/updates against the same tables `ShiftService.calculateShiftSales`/`PetrolPumpBillingService` already read (`_db.select(_db.nozzles)..where((t) => t.linkedShiftId.equals(shiftId))`). `saveDispenser`, `saveNozzle`, `getDispensers`, `getNozzlesByDispenser`, `getAllNozzles`, `updateOpeningReading`, `updateClosingReading` all convert to Drift queries plus `_enqueueSync`.
3. **Migrate `FuelService` onto Drift.** Add a `fuelTypes` Drift table (mirroring `FuelType.toMap()`'s existing fields) and convert `getFuelTypes`, `updateFuelRate`, `addFuelType`, `toggleFuelStatus`, `initializeDefaultFuels` to Drift queries plus `_enqueueSync`, so `FuelRatesScreen`/`FuelProfitReportScreen`/`AddTankDialog`'s fuel-type dropdown all read the same fuel-rate data `PetrolPumpBillingService.createFuelBill` uses for `rate`.
4. **Migrate `PeriodLockService` onto Drift.** Replace `_settingsCollection.doc('period_lock')` with a `_db.select(_db.settings)`-equivalent query (or reuse the existing `LockingService`/Drift-backed lock table `closePeriod` already syncs to via `sl<LockingService>().setLockDate`), so `PetrolPumpBillingService.createFuelBill`'s `_periodLockService.isDateLocked` check and `TankService`'s writes agree on the same lock state without a network round trip.
5. **Preserve the `Stream<List<T>>` return signatures.** Each Drift-backed method exposes a `.watch()`-based stream (mirroring `ShiftService.getShiftHistory`'s `(_db.select(...)..where(...)).watch().map(...)` pattern) so `StreamBuilder`-based UI (`DispenserListScreen`, `FuelRatesScreen`, `AddTankDialog`) requires no changes to its consumption code, only to the service implementation underneath.

### Surface 3: `ui.dispenserNozzleReadingEntry`

**File**: `lib/features/petrol_pump/presentation/screens/dispenser_list_screen.dart` (new dialogs added alongside `add_tank_dialog.dart`/`dip_reading_dialog.dart`)

**Specific Changes**:
1. **Restore the FAB.** Replace the `// FAB removed until Add Dispenser is fully implemented` comment with `floatingActionButton: FloatingActionButton(onPressed: () => _showAddDispenserDialog(context), child: const Icon(Icons.add))`, backed by a new `AddDispenserDialog` (same structure as `AddTankDialog`: name field, `_formKey` validation, calls `sl<DispenserService>().saveDispenser(...)`).
2. **Restore "Add Nozzle".** Replace the `// Add Nozzle button removed until fully implemented` comment with a `trailing: IconButton(icon: Icon(Icons.add_circle_outline), onPressed: () => _showAddNozzleDialog(context, dispenser))`, backed by a new `AddNozzleDialog` (fuel-type dropdown sourced from `sl<FuelService>().getFuelTypes()`, tank-link dropdown sourced from `sl<TankService>().getTanks()`, calls `sl<DispenserService>().saveNozzle(...)`).
3. **Add a reading-entry dialog.** New `NozzleReadingDialog` (in `lib/features/petrol_pump/presentation/dialogs/`, alongside the existing tank dialogs) with opening/closing reading fields, calling `sl<DispenserService>().updateOpeningReading(...)`/`updateClosingReading(...)` with the acting `employeeId` (closes the gap with Surface 9). Reachable from a new per-nozzle `IconButton` in `_buildDispenserCard`'s nozzle `ListTile`.

### Surface 4: `dashboard.orphaned`

**File**: `lib/widgets/desktop/sidebar_navigation_handler.dart`

**Specific Changes**:
1. **Route `petrol_dashboard` to the KPI dashboard.** Change `case 'petrol_dashboard': return const PetrolPumpManagementScreen();` to `case 'petrol_dashboard': return const RevenueDashboardScreen();`.
2. **Surface the widget bundle inside the management screen.** In `petrol_pump_management_screen.dart`, insert `const PetrolPumpDashboardWidgets()` above the existing `ListView` of menu tiles (inside the same `BoundedBox`), so the shift-status card, fuel-rate ticker, and low-tank summary are visible from the (now secondary) management/settings screen without removing the existing 4-tile navigation menu, which remains useful as a settings hub.

### Surface 5: `alerts.hardcodedCounts`

**File**: `lib/features/dashboard/v2/widgets/business_alerts_widget.dart`

**Specific Changes**:
1. **Add a `petrolPumpAlertCountsProvider`**, mirroring the file's established per-vertical snapshot pattern (e.g. `electronicsAlertCountsProvider`): a `FutureProvider.autoDispose<PetrolPumpAlertSnapshot>` that queries `sl<AppDatabase>()` for (a) count of tanks where `isLowStock` (stock% < 20, matching `Tank.isLowStock`), and (b) count of `StaffCashSettlements` with `status == 'PENDING'` (the table `ShiftService.createStaffSettlements` already writes to). Each metric independently marked unavailable on query failure, rendering `'...'`/`'!'` exactly like the electronics/DC/jewellery snapshots in the same file.
2. **Replace the literals.** In `case BusinessType.petrolPump:`, change `count: '2'` to `count: petrolSnapshot == null ? '...' : (petrolSnapshot.lowTankAvailable ? _displayCount(petrolSnapshot.lowTankCount) : '!')` and `count: '1'` to the equivalent for `pendingSettlementCount`, following the exact `_displayCount(...)`/`'...'`/`'!'` ternary already used by every other case in this `switch`.

### Surface 6: `report.fuelProfitHardcoded`

**File**: `lib/features/petrol_pump/presentation/screens/reports/fuel_profit_report_screen.dart`

**Specific Changes**:
1. **Compute real summary figures.** Add a method `Future<FuelProfitSummary> _computeSummary(DateTimeRange range)` that queries `sl<BillsRepository>()` for petrolPump bills within `range`, sums `grandTotal` (Total Sales) and per-fuel-line `qty` (Litres Sold)/`price*qty` (Revenue), and queries the stock-movement/purchase records (extended by Surface 7's price field) for Total Cost, computing Profit = Sales − Cost and Margin = Profit / Sales × 100.
2. **Wire `_selectDateRange` to actually filter.** After `showDateRangePicker` returns a non-null `range`, store it in `setState(() => _selectedRange = range)` and call `_computeSummary(_selectedRange)`, replacing the current SnackBar-only feedback (the SnackBar can remain as a secondary confirmation, but the range now drives real computation).
3. **Replace the literals.** `_buildSummaryItem('Total Sales', '₹0', ...)` → `_buildSummaryItem('Total Sales', '₹${summary.totalSales.toStringAsFixed(0)}', ...)`, and the equivalent for Total Cost/Profit; `_buildFuelProfitCard`'s `_buildMetric('Litres Sold', '0 L')`/`'Revenue', '₹0'`/`'Margin', '0%'` become per-fuel values from `summary.perFuel[fuel.fuelId]`.

### Surface 7: `stock.purchasePriceDiscarded`

**Files**: `lib/features/petrol_pump/services/tank_service.dart`, `lib/features/petrol_pump/presentation/dialogs/add_stock_dialog.dart`

**Specific Changes**:
1. **Extend `TankService.addPurchase`'s signature.** Add `double? pricePerLitre` as a new optional named parameter. When provided, include `'pricePerLitre': pricePerLitre, 'totalCost': quantity * pricePerLitre'` in the `_logStockEvent` metadata map (extending the existing `metadata: {...}` literal, not replacing it) so the purchase cost is persisted in the audit/stock-movement record `report.fuelProfitHardcoded`'s cost computation (Surface 6) reads from.
2. **Pass the captured price.** In `add_stock_dialog.dart._submit`, change `await sl<TankService>().addPurchase(widget.tank.tankId, quantity);` to `await sl<TankService>().addPurchase(widget.tank.tankId, quantity, pricePerLitre: _priceController.text.isNotEmpty ? double.tryParse(_priceController.text) : null);`.

### Surface 8: `rbac.sidebarGateMissing`

**Files**: `lib/widgets/desktop/sidebar_configuration.dart`, `lib/core/models/user_role.dart`

**Specific Changes**:
1. **Add capability gates to `_getPetrolPumpSections()`.** Following the exact pattern already used elsewhere in this file (e.g. `capability: BusinessCapability.useProformaInvoice` on hardware's `proforma_bids` item), add `capability: BusinessCapability.useShiftManagement` to the `shift_management` item, `capability: BusinessCapability.usePumpReadings` to `dispenser_management`, `capability: BusinessCapability.useFuelManagement` to `fuel_rates`/`petrol_dashboard`, and `capability: BusinessCapability.useStockManagement` to `tank_management`/`tank_stock_report`. These capabilities are already granted to `'petrolPump'` in `business_capability.dart`'s registry, so this change is purely additive gating (no registry change) and is filtered through the existing `sidebarSectionsProvider`'s `FeatureResolver.canAccess(typeStr, item.capability!)` check — every gate resolves to visible for petrolPump today, so no existing behavior changes until a future non-owner role is used.
2. **Add `attendant` to `UserRole`.** Append `attendant,` to the enum in `user_role.dart` (after `nurse`, before `unknown`, matching the existing append-only pattern each new role has followed), with a doc comment describing least-privilege pump-attendant access.
3. **Grant `attendant` permissions in `RolePermissions`.** Add a `UserRole.attendant: { Permission.createBill, Permission.printBill, Permission.viewStock }` entry to `_permissions` in `role_management_service.dart`, following the exact least-privilege style of the existing `UserRole.waiter`/`UserRole.pharmacist` entries — grants dispensing and stock-view, denies reports/settings/user-management.
4. **Add `permission:` gates for shift/reading items.** Following the existing `permission: 'viewReports'`/`'manageSettings'` string pattern already used elsewhere in this file, add `permission: 'viewReports'` to `shift_report`/`tank_stock_report`/`fuel_profit_report`/`nozzle_sales_report` so attendants (who lack `viewReports`) see the operational items but not the reports section, while owner/manager (who have `viewReports`) see everything — mirrors the existing RBAC filter (`RolePermissions.hasPermission(userRole, permission)`) already applied by `sidebarSectionsProvider`.

### Surface 9: `rbac.readingPermissionBypass`

**File**: `lib/features/petrol_pump/services/dispenser_service.dart`

**Specific Changes**:
1. **Require `employeeId` for manual reading updates.** In `updateOpeningReading` and the non-`isSystemUpdate` branch of `updateClosingReading`, change `if (employeeId != null) { ... }` to unconditionally check permission: `final effectiveEmployeeId = employeeId; if (effectiveEmployeeId == null || !await _checkPermission(effectiveEmployeeId, 'canEditReadings')) { await _logUnauthorizedAttempt(effectiveEmployeeId ?? 'unknown', 'updateOpeningReading', nozzleId); throw PermissionDeniedException('canEditReadings', 'You do not have permission to edit nozzle readings.'); }` — a missing identity now denies by default instead of skipping the check. The `isSystemUpdate: true` bypass in `updateClosingReading` (used by `PetrolPumpBillingService`'s own system-initiated closing-reading updates) is untouched, since that is an intentional, distinct bypass (Preservation).
2. **Update callers to pass `employeeId`.** The new `NozzleReadingDialog` (Surface 3) and any other manual call site pass the acting staff/employee id resolved the same way Surface 1 resolves `attendantId`.

### Surface 10: `shift.rolloverAndBilledLitres`

**File**: `lib/features/petrol_pump/services/shift_service.dart`

**Specific Changes**:
1. **Call `PetrolPumpBusinessRules.dispensedLitres`.** In `calculateShiftSales`, replace `final litresSold = nozzleEntity.closingReading - nozzleEntity.openingReading;` with `final litresSold = PetrolPumpBusinessRules.dispensedLitres(startReading: nozzleEntity.openingReading, endReading: nozzleEntity.closingReading);`, adding the import `import '../utils/petrol_pump_business_rules.dart';`.
2. **Compute real per-nozzle `billedLitres`/`variance`.** Before the nozzle loop, build a `Map<String, double> billedLitresByNozzle` by iterating `billsList` (already fetched later in the function — move that fetch earlier) and, for each bill's `itemsJson` entries containing a `nozzleId`, summing `qty` per `nozzleId`. In the `NozzleReconciliation(...)` construction, replace `billedLitres: 0, variance: 0` with `billedLitres: billedLitresByNozzle[nozzleEntity.nozzleId] ?? 0, variance: litresSold - (billedLitresByNozzle[nozzleEntity.nozzleId] ?? 0)`.

### Surface 11: `fuelRates.fabAndBoundsMissing`

**File**: `lib/features/petrol_pump/presentation/screens/fuel_rates_screen.dart`

**Specific Changes**:
1. **Wire the FAB.** Replace the empty `onPressed: () { // Add custom fuel type logic }` with `onPressed: () => _showAddFuelTypeDialog(context)`, backed by a new inline dialog (name field, initial rate field, GST fixed at `0` per the already-correct compliance default) that calls `sl<FuelService>().addFuelType(FuelType(...))`.
2. **Add bounds validation to `_showUpdateRateDialog`.** Introduce `const double _minFuelRate = 1.0; const double _maxFuelRate = 500.0;` (documented as sane per-litre bounds for petrol/diesel/CNG/EV pricing in India) and change the `ElevatedButton.onPressed` to: `final newRate = double.tryParse(controller.text); if (newRate == null || newRate < _minFuelRate || newRate > _maxFuelRate) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rate must be between ₹$_minFuelRate and ₹$_maxFuelRate'))); return; } await _fuelService.updateFuelRate(...)`.

### Surface 12: `bug.mojibake`

**Files**: `lib/features/petrol_pump/presentation/screens/reports/shift_report_screen.dart`, `lib/features/petrol_pump/utils/petrol_pump_business_rules.dart`

**Specific Changes**:
1. Replace both `'â‚¹${...}'` occurrences (`_buildStat` call site's `'Total Sales'` value and `_buildMiniStat`'s value) in `shift_report_screen.dart` with `'₹${...}'`.
2. Replace the header comment `// Petrol pump â€” domain rules` with `// Petrol pump — domain rules`, `saleValue = dispensedLitres Ã— pricePerLitre` with `saleValue = dispensedLitres × pricePerLitre`, and `cashVariance = expectedCash âˆ’ reportedCash` with `cashVariance = expectedCash − reportedCash` in `petrol_pump_business_rules.dart`. All three are comment-only changes with zero effect on compiled behavior.

### Surface 13: `bug.escapedErrorString`

**Files**: `lib/features/petrol_pump/presentation/dialogs/add_tank_dialog.dart`, `dip_reading_dialog.dart`

**Specific Changes**:
1. In `add_tank_dialog.dart._submit`'s catch block, change `content: Text('Error: \$e'),` to `content: Text('Error: $e'),` (removing the backslash so `$e` interpolates the caught exception).
2. Apply the identical one-character fix to `dip_reading_dialog.dart._submit`'s catch block. `add_stock_dialog.dart`'s catch block already uses correct interpolation (`'Error: $e'`) and is left unchanged — it is not part of this bug condition.

### Surface 14: `bug.debugPrints`

**Files**: `lib/features/petrol_pump/services/petrol_pump_billing_service.dart`, `shift_service.dart`

**Specific Changes**:
1. Remove all nine `print('DEBUG: ...')` calls in `petrol_pump_billing_service.dart.createFuelBill` (`'Starting transaction for bill'`, `'Generating ID'`, `'Preparing BillCompanion for $billId'`, `'Inserting Bill'`, `'Enqueuing Bill Sync'`, `'Updating Tank Stock for $tankId'`, `'Enqueuing Tank Sync'`, `'Logging Stock Movement'`, `'Updating Nozzle Reading for ${nozzle.nozzleId}'`) with no replacement — they trace normal, non-error control flow and add no diagnostic value once removed; the surrounding transactional logic is untouched.
2. Remove all five `print('DEBUG: ...')` calls in `shift_service.dart` (`'Insert Shift Companion'`, the catch block's `print('DEBUG: Shift Insert Failed: $e'); print(stack);`, `'Enqueue Shift Sync'`, `'Resetting Nozzles'`). The catch block's two `print` calls are replaced with `debugPrint('Shift Insert Failed: $e\n$stack');` (using Flutter's `debugPrint`, which is automatically stripped/no-op in release-mode profiling and is the established pattern for error-path diagnostics elsewhere in the codebase, e.g. `bill_creation_screen_v2.dart`'s `debugPrint("Failed to link bill to service job: $e")`) so the error path retains a diagnostic trail without a bare `print`; the `rethrow` after it is unchanged.

### Surface 15: `validation.silentClampNoFlag`

**Files**: `lib/features/petrol_pump/models/nozzle.dart`, `tank.dart`

**Specific Changes**:
1. **`Nozzle`**: Add a new getter `bool get hasRolloverAnomaly => closingReading - openingReading < 0;` alongside the existing `calculatedSaleLitres` (which is unchanged — it still clamps to `0`, per Preservation of `isValidReading`/existing consumers). UI call sites that display `calculatedSaleLitres` (`dispenser_list_screen.dart`'s nozzle `ListTile`, the new `NozzleReadingDialog` from Surface 3) additionally check `hasRolloverAnomaly` and render a warning icon/text when true.
2. **`Tank`**: Add a new getter `bool get hasOverfillAnomaly => (openingStock + purchaseQuantity - salesDeduction) > capacity;` computed from the same inputs `addPurchase`'s clamp uses (comparing calculated stock, i.e. what stock *would* be without clamping, against `capacity`). `addPurchase`'s own clamping behavior is unchanged (Preservation of `availableCapacity`/existing consumers); `AddStockDialog`'s success SnackBar (Surface 13's file) additionally checks the tank's `hasOverfillAnomaly` after `addPurchase` completes and appends an over-fill warning to the message when true.

## Testing Strategy

### Validation Approach

Because this bugfix spans 15 independent surfaces rather than one narrow defect, the testing strategy applies the same two-phase approach (surface counterexamples on unfixed code, then verify fix + preservation) independently per surface, so a failure in one surface's exploration test does not block confirming the others. Property-based testing is scoped per-surface to the concrete input space each surface actually varies over (e.g. rollover boundary values for Surface 10, min/max rate boundaries for Surface 11) rather than one undifferentiated property across all 15.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate each of the 15 defects BEFORE implementing any fix, confirming or refuting the corresponding root-cause hypothesis.

**Test Plan**: For each surface, write a targeted test against the UNFIXED code that reproduces the exact defect described in that surface's Example, then run it to observe the failure.

**Test Cases** (one representative case per surface; additional edge cases enumerated in Unit/Property/Integration sections below):
1. **`billing.fuelSaleWiring`**: save a petrolPump bill via `_handleSave` and assert `newBill.shiftId != null` — fails on unfixed code (`shiftId` stays `null`, no `PetrolPumpBillingService` call occurs).
2. **`datastore.splitBrain`**: write a tank via `TankService.saveTank`, then read it via `_db.select(_db.tanks)` directly (the table `PetrolPumpBillingService` reads) — assert it is visible; fails on unfixed code (no row exists in Drift, only in the API-backed store).
3. **`ui.dispenserNozzleReadingEntry`**: pump-widget-test `DispenserListScreen` and assert a `FloatingActionButton` exists — fails on unfixed code (no FAB is built).
4. **`dashboard.orphaned`**: resolve `SidebarNavigationHandler.getScreenForItem('petrol_dashboard')` and assert it returns a `RevenueDashboardScreen` — fails on unfixed code (returns `PetrolPumpManagementScreen`).
5. **`alerts.hardcodedCounts`**: render `BusinessAlertsWidget` for two different tank-level fixtures (0 low tanks vs. 5 low tanks) and assert the "Tank Levels Low" count differs — fails on unfixed code (always `'2'`).
6. **`report.fuelProfitHardcoded`**: seed a petrolPump bill with known `grandTotal`, render `FuelProfitReportScreen`, assert "Total Sales" is non-zero and matches — fails on unfixed code (always `'₹0'`).
7. **`stock.purchasePriceDiscarded`**: call `TankService.addPurchase` with a price argument and assert the logged stock-movement metadata contains it — fails on unfixed code (signature has no price parameter, compile-time failure or silently ignored).
8. **`rbac.sidebarGateMissing`**: read `_getPetrolPumpSections()`'s `shift_management` item and assert `capability != null` — fails on unfixed code (`capability` is `null`); separately assert `UserRole.values` contains a value named `attendant` — fails on unfixed code.
9. **`rbac.readingPermissionBypass`**: call `DispenserService.updateOpeningReading(nozzleId, reading, shiftId)` with no `employeeId` for a nozzle whose linked employee lacks `canEditReadings`, and assert it throws `PermissionDeniedException` — fails on unfixed code (proceeds unconditionally since `employeeId == null` skips the check entirely).
10. **`shift.rolloverAndBilledLitres`**: set a nozzle's `openingReading: 999900, closingReading: 100` (rolled over) and call `calculateShiftSales`; assert the computed litres is positive (~200, via rollover math) — fails on unfixed code (returns a large negative number, `100 - 999900`).
11. **`fuelRates.fabAndBoundsMissing`**: tap the Fuel Rates FAB and assert a dialog opens — fails on unfixed code (nothing happens); separately submit a rate of `-50` and assert it is rejected — fails on unfixed code (accepted via bare `double.tryParse`).
12. **`bug.mojibake`**: render `ShiftReportScreen` for a shift with `totalSaleAmount: 100` and assert the rendered text contains `₹100.00`, not `â‚¹100.00` — fails on unfixed code.
13. **`bug.escapedErrorString`**: force `TankService.saveTank` to throw inside `AddTankDialog._submit` and assert the SnackBar text contains the actual exception message, not the literal `Error: $e` — fails on unfixed code.
14. **`bug.debugPrints`**: capture stdout during `PetrolPumpBillingService.createFuelBill` and assert no line starts with `DEBUG:` — fails on unfixed code (nine such lines are printed).
15. **`validation.silentClampNoFlag`**: construct a `Nozzle` with `closingReading < openingReading` (rollover) and assert `hasRolloverAnomaly == true` — fails on unfixed code (the getter does not exist / the anomaly is invisible).

**Expected Counterexamples**: Each test above fails against the unfixed code with the specific symptom described in that surface's Example in Bug Details, confirming the corresponding Hypothesized Root Cause entry.

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior defined by the matching Correctness Property (1–15).

**Pseudocode:**
```
FOR ALL X WHERE isBugCondition(X) DO
  result := F'(X)
  ASSERT expectedBehaviorFor(X.surface)(result)   // Property 1-15, keyed by X.surface
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT F(X) = F'(X)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- The non-petrolPump input space spans 19 other business types' billing/sidebar/dashboard/report code paths — enumerating each by hand risks missing one, whereas generating random business types (excluding petrolPump) and asserting zero behavioral delta catches all of them uniformly.
- Petrol pump's own preserved sub-cases (GST default values, shift-close tolerance boundaries, tank/dip validator boundaries, non-rollover/non-overfill stock values) have natural boundary conditions that property-based generation covers more systematically than a handful of manual examples.

**Test Plan**: Observe UNFIXED-code behavior for representative non-petrolPump business types and petrol pump's own already-correct sub-cases, record exact outputs, then write property-based tests asserting the fixed code reproduces them byte-for-byte.

**Test Cases**:
1. **Non-petrolPump business types unaffected**: for each of the 19 non-petrolPump types, generate random bills/sidebar renders/dashboard alerts/reports and assert zero reference to `PetrolPumpBillingService`/`ShiftService`/`PetrolPumpBusinessRules` and identical output to the pre-fix code.
2. **Petrol pump GST defaults preserved**: generate arbitrary fuel `Product.taxRate` values and assert the fixed `_addItem`/`createFuelBill` GST override still forces `0`, exactly as `bugfix.md`'s "already fixed" baseline established.
3. **Shift-close reconciliation/cash-variance logic preserved**: generate arbitrary `ShiftReconciliation` inputs that stay within tolerance and assert `closeShift`'s tolerance/variance decision is unchanged — only `calculateShiftSales`'s *inputs* (rollover-aware litres, real billed litres) changed, not the close-decision thresholds themselves.
4. **Non-rollover/non-overfill Tank/Nozzle values preserved**: generate `Nozzle`/`Tank` values that do NOT trigger rollover/overfill and assert `calculatedSaleLitres`/`stockVariance`/`stockPercentage`/`isLowStock`/`isValidReading`/`hasRolloverAnomaly`/`hasOverfillAnomaly` match the pre-fix values (the new anomaly getters are additive and must read `false` whenever the pre-fix clamped output already reflected the true value).
5. **Existing `UserRole` resolution preserved**: generate all 11 pre-existing `UserRole` values and assert `RolePermissions.hasPermission` returns identical results to before `attendant` was added.

### Unit Tests

- `_handleSave`/`_addItem`/`_addItemWithStockWarning`: petrolPump bill sets `shiftId`/`attendantId` and forces `gstRate: 0` regardless of `product.taxRate`.
- `TankService`/`DispenserService`/`FuelService`/`PeriodLockService`: each Drift-backed method reads back what a sibling service wrote (cross-service visibility, no polling delay).
- `DispenserListScreen`: FAB and "Add Nozzle"/reading-entry affordances are present and invoke the corresponding service methods.
- `SidebarNavigationHandler.getScreenForItem('petrol_dashboard')` returns `RevenueDashboardScreen`.
- `BusinessAlertsWidget` petrolPump case: counts vary with fixture data, never literal `'2'`/`'1'`.
- `FuelProfitReportScreen`: summary/per-fuel figures reflect seeded bill/purchase data; date-range selection changes the displayed figures.
- `TankService.addPurchase`: price parameter is optional (backward compatible for callers that omit it) and is persisted when provided.
- `_getPetrolPumpSections()`: every item that maps to a registered capability declares that capability; `UserRole.attendant` exists and resolves the least-privilege permission set.
- `DispenserService.updateOpeningReading`/`updateClosingReading`: missing/unauthorized `employeeId` throws `PermissionDeniedException`; `isSystemUpdate: true` still bypasses (unchanged).
- `ShiftService.calculateShiftSales`: rollover input produces the correct positive litres via `PetrolPumpBusinessRules.dispensedLitres`; `billedLitres`/`variance` reflect seeded bills.
- `FuelRatesScreen`: FAB opens a dialog; rate updates outside `[_minFuelRate, _maxFuelRate]` are rejected.
- `ShiftReportScreen`/`petrol_pump_business_rules.dart`: rendered/source text contains correct UTF-8 glyphs, no mojibake byte sequences.
- `AddTankDialog`/`DipReadingDialog`: thrown exceptions produce a SnackBar containing the actual exception message.
- `PetrolPumpBillingService.createFuelBill`/`ShiftService.openShift`: no `print` output during execution (success and error paths).
- `Nozzle.hasRolloverAnomaly`/`Tank.hasOverfillAnomaly`: `true` exactly when the underlying clamp would otherwise discard information, `false` otherwise.

### Property-Based Tests

- Generate arbitrary `(openingReading, closingReading)` pairs spanning both normal and rollover cases and assert `ShiftService.calculateShiftSales`'s computed litres always matches `PetrolPumpBusinessRules.dispensedLitres` directly, for every generated pair.
- Generate arbitrary fuel rate update values (including boundary values at/around `_minFuelRate`/`_maxFuelRate`) and assert acceptance/rejection matches the bounds check exactly.
- Generate arbitrary `Product.taxRate` values for petrolPump fuel products and assert the resulting `BillItem.gstRate` is always `0`, never `taxRate`, for every generated value.
- Generate arbitrary `(openingStock, purchaseQuantity, salesDeduction, capacity)` tuples for `Tank` and assert `hasOverfillAnomaly` is `true` if-and-only-if the unclamped calculated stock exceeds `capacity`.
- Generate arbitrary non-petrolPump business types with arbitrary bill/sidebar/dashboard/report inputs and assert the resulting output is identical to the pre-fix formula for every generated combination (preservation).
- Generate arbitrary `Employee`/`EmployeePermissions` combinations (including `employeeId: null`) and assert `DispenserService.updateOpeningReading`/`updateClosingReading` denies exactly when `employeeId` is null or the resolved employee lacks `canEditReadings`, and allows otherwise.

### Integration Tests

- Full fuel-sale flow: select a nozzle/fuel type in `BillCreationScreenV2`, save the bill, and verify the tank's `currentStock` (read via `TankService`, now Drift-backed) decreases by the sold litres and the nozzle's `closingReading` (read via `DispenserService`, now Drift-backed) increases — proving Surfaces 1 and 2 together close the loop `PetrolPumpBillingService` already implements transactionally.
- Full dispenser/nozzle/reading-entry flow: add a dispenser, add a nozzle to it, record an opening reading, then a closing reading, and verify each step's data is visible to `ShiftService.calculateShiftSales` for the active shift.
- Dashboard navigation flow: tap `petrol_dashboard` in the sidebar and verify `RevenueDashboardScreen`'s revenue chart renders using real bill data seeded in the test, with `PetrolPumpDashboardWidgets`' shift-status card reflecting the actual active-shift state.
- Shift close flow with rollover: open a shift, sell fuel through a nozzle until its totalizer rolls over, close the shift, and verify `closeShift`'s reconciliation uses the rollover-corrected litres (not a large negative number) and does not spuriously block the close.
- RBAC flow: log in as a resolved `UserRole.attendant`, verify the sidebar shows `new_sale`/`dispenser_management` but hides `shift_report`/`fuel_profit_report` (no `viewReports`), then attempt a nozzle reading update as that attendant and verify it succeeds only if `canEditReadings` is granted on their `Employee` record.
