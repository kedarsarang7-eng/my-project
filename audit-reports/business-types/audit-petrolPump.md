# DukanX Business-Type Audit — Petrol Pump (`petrolPump`)

> READ-ONLY, evidence-based audit. No source files were modified. Every claim cites the file/function checked. Items not directly verified are marked **unverified**.

---

## What was sampled vs skipped

**Sampled (read in full or in relevant part):**
- `Dukan_x/lib/models/business_type.dart`
- `Dukan_x/lib/core/billing/business_type_config.dart`
- `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart` (incl. `_getPetrolPumpSections()`)
- `Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart` (`getScreenForItem()`)
- `Dukan_x/lib/features/dashboard/v2/widgets/business_quick_actions.dart`
- `Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart`
- `Dukan_x/lib/core/isolation/business_capability.dart` (petrolPump set)
- `Dukan_x/lib/core/session/session_manager.dart` (UserRole, role resolution — partial)
- `Dukan_x/lib/core/compat/firestore_compat.dart` (API-gateway bridge)
- All petrol screens: `petrol_pump_management_screen.dart`, `shift_history_screen.dart`, `tank_list_screen.dart`, `dispenser_list_screen.dart`, `fuel_rates_screen.dart`, `revenue_dashboard_screen.dart`, `reports/{fuel_profit_report,nozzle_sales_report,shift_report,tank_stock_report}_screen.dart`
- All petrol services: `shift_service.dart`, `tank_service.dart`, `dispenser_service.dart`, `fuel_service.dart`, `petrol_pump_billing_service.dart`, `period_lock_service.dart`, `calibration_reminder_service.dart`
- `utils/petrol_pump_business_rules.dart`
- Models: `fuel_type.dart`, `tank.dart`, `nozzle.dart`
- Dialogs: `add_tank_dialog.dart`, `add_stock_dialog.dart`, `dip_reading_dialog.dart`
- `features/billing/presentation/screens/bill_creation_screen_v2.dart` (petrol header handling, save path)

**Skipped / not fully verified:**
- `models/shift.dart`, `models/shift_reconciliation.dart`, `models/dispenser.dart`, `models/employee.dart` (read only via their usages)
- `staff_list_screen.dart` / `staff_detail_screen.dart` / `add_staff_screen.dart` internals under `petrol_pump/` (name collide with `features/staff/...`)
- `service_locator.dart` registration of each petrol service (services are resolved via `sl<...>()` and the app references them; explicit registration **unverified**)
- `main.dart` route table; deep accessibility tree; runtime behavior

---

## 1. Header — Resolution, Config, Capabilities

**Business type:** `BusinessType.petrolPump`, displayName "Petrol Pump", icon `local_gas_station_rounded` (`business_type.dart`), emoji ⛽, primary color `#DC2626` (`business_type_config.dart`).

**Sidebar resolution:** `sidebar_configuration.dart` → `_getSectionsForBusiness()` has a dedicated `case BusinessType.petrolPump: return _getPetrolPumpSections();` (verified). `_getPetrolPumpSections()` defines 3 dedicated sections + `_getCommonSections(startingIndex: 3)`:
- **Fuel Station Ops:** `petrol_dashboard`, `shift_management`, `dispenser_management`, `tank_management`
- **Billing & Sales:** `new_sale`, `revenue_overview`, `sales_register`
- **Reports & Analytics:** `fuel_rates`, `fuel_profit_report`, `nozzle_sales_report`, `shift_report`, `tank_stock_report`

**Config (`business_type_config.dart` → `BusinessType.petrolPump`):** requiredFields `[itemName, quantity, price]`; optional `[nozzleId, fuelType, litres, vehicleNumber, gst]`; `defaultGstRate: 18.0`; `gstEditable: false`; `unitOptions: [ltr, kg]`; itemLabel "Fuel"; priceLabel "Rate/Ltr"; modules `['inventory','sales','shifts','reading','reports']`. All as described in the brief (verified).

**Capabilities (`business_capability.dart` → `'petrolPump'`):** useProduct* (all 7), useInventoryList/useVisibleStock/useInventorySearch, useInvoiceList/Search/Create, useLowStockAlert, useDailySnapshot, useRevenueOverview, usePurchaseOrder, useStockEntry, useSupplierBill, and specialized `useFuelManagement, usePumpReadings, useShiftManagement, useVehicleDetails, useTankerEntry, useStockManagement` (verified).

**RBAC:** `UserRole` (session_manager.dart) resolves to `owner / manager / staff / accountant / unknown`. **There is no `attendant` or `shiftOperator` role** in the core RBAC enum (verified by role-switch in `_loadUserSession`). Petrol "attendant" identity lives only in a separate `Employee`/`StaffModel` concept (see §11).

---

## 2. Missing Generic Features (vs Vyapar benchmark)

| # | Vyapar capability | Petrol pump status | Evidence | Priority |
|---|---|---|---|---|
| 2.1 | Receivables/Payables, Party ledger | Present via `_getCommonSections` (`customers`, `party_ledger`, `outstanding`) | sidebar common sections | — |
| 2.2 | Accounting (P&L, trial balance) | Reachable only if common sections include them; petrol billing posts journal entries in the **unused** Drift service | `petrol_pump_billing_service._postAccountingEntry` (not wired, see §7) | High |
| 2.3 | Barcode/POS | N/A for fuel (acceptable) | — | Low |
| 2.4 | Bank/Cash | Generic `cash_bank`/`bank_accounts` via common sections | nav handler | — |
| 2.5 | e-Way bill / e-invoice | Not surfaced for petrol | no petrol references | Low |
| 2.6 | Loyalty / fleet cards | **Missing** (no fleet-card/coupon module) | no code found | High |
| 2.7 | Multi-firm, Backup, Online store | Generic (common sections / `backup`) | nav handler | — |
| 2.8 | 37+ reports | Petrol exposes 4 petrol reports + generic; petrol reports are thin/partly hardcoded | §8 | High |

---

## 3. Missing Industry-Specific Features

| # | Petrol-pump need | Status | Evidence | Priority |
|---|---|---|---|---|
| 3.1 | Nozzle meter readings (opening/closing per shift) | Model + reset logic exist, but **no UI to enter readings**; sales never update readings in practice | `nozzle.dart`, `shift_service._resetNozzlesForShift`; readings only changed by unused `PetrolPumpBillingService` / `DispenserService.updateClosingReading` (no caller) | Critical |
| 3.2 | Fuel density & temperature (ATG/volume correction) | **Missing entirely** | no fields in `tank.dart`/`nozzle.dart` | High |
| 3.3 | Tank dip & stock reconciliation | Partial: `DipReadingDialog` + `TankService.recordDipReading` log variance | `dip_reading_dialog.dart`, `tank_service.dart` | — |
| 3.4 | Evaporation / shortage loss tracking | **Missing** (only ad-hoc dip variance, no evaporation model) | `tank.dart` has no loss field | Medium |
| 3.5 | Shift handover + cash reconciliation per attendant | Logic exists in `ShiftService` (reconciliation, cash declaration, staff settlements) but depends on bills carrying `shiftId`/`attendantId` which the billing UI never sets | `shift_service.calculateShiftSales/createStaffSettlements`; see §13 | Critical |
| 3.6 | Daily fuel rate change with effective time | Rate + `rateHistory` stored, but **no effective-from timestamp/scheduling**; update is immediate | `fuel_type.dart updateRate`, `fuel_rates_screen._showUpdateRateDialog` | High |
| 3.7 | Credit/fleet customers & coupons | Only generic customer credit-limit check in unused billing service | `petrol_pump_billing_service` STEP 3 | High |
| 3.8 | Lube/oil & non-fuel sales | Not modeled distinctly (generic items only) | config has no non-fuel path | Medium |
| 3.9 | Testing/calibration 5L test return | **Missing** (no 5L test-return adjustment) | no code | Medium |
| 3.10 | Wet stock vs book stock variance | Partial via `Tank.stockVariance` (currentStock − calculatedStock) | `tank.dart` | — |
| 3.11 | Decanting / tanker receipt (TT) | Only `AddStockDialog` (quantity), no tanker/invoice/decanting record; **purchase price captured then discarded** | `add_stock_dialog._submit` passes only `quantity` | High |
| 3.12 | DU totalizer / rollover | Logic exists in `PetrolPumpBusinessRules.dispensedLitres` but is **never used**; live math uses naive `closing − opening` | `petrol_pump_business_rules.dart` (no callers) vs `shift_service.calculateShiftSales` | High |
| 3.13 | Calibration reminder (W&M compliance) | Implemented (`CalibrationReminderService`, Drift) but **no UI/dashboard wiring** found | `calibration_reminder_service.dart` (no caller located) | Medium |

---

## 4. Missing UI Components

| # | Gap | Evidence | Priority |
|---|---|---|---|
| 4.1 | **No "Add Dispenser" UI** | `dispenser_list_screen.dart`: "FAB removed until Add Dispenser is fully implemented" | Critical |
| 4.2 | **No "Add Nozzle" UI** | `dispenser_list_screen.dart`: "Add Nozzle button removed until fully implemented" | Critical |
| 4.3 | **No nozzle reading-entry screen** (opening/closing) | no screen; only `_showNozzleAssignmentDialog` assigns staff | Critical |
| 4.4 | Fuel "Add custom fuel type" FAB is a no-op | `fuel_rates_screen.dart`: FAB `onPressed` body is empty `// Add custom fuel type logic` | High |
| 4.5 | Employee/attendant management removed from petrol mgmt screen | `petrol_pump_management_screen.dart`: "Employee Management removed until fully implemented" | High |
| 4.6 | Fuel rate update lacks effective-time / confirmation of impact | `fuel_rates_screen._showUpdateRateDialog` | Medium |

Result: A user **cannot fully configure a station** (dispensers, nozzles, readings) through the UI, which breaks the entire shift/reconciliation pipeline.

---

## 5. Missing Widgets & Dashboard / KPI Cards

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 5.1 | `petrol_dashboard` opens a **plain menu list**, not a KPI dashboard | `petrol_pump_management_screen.dart` (4 `ListTile` menu tiles) | High |
| 5.2 | A rich petrol KPI dashboard exists but is **orphaned** | `revenue_dashboard_screen.dart` (`RevenueDashboardScreen`: revenue, txns, litres, avg ticket, hourly bar chart, fuel pie, payment split, staff leaderboard) — no references in `Dukan_x/lib` outside its own definition (grep) | High |
| 5.3 | A petrol dashboard widget bundle exists but is **orphaned** | `petrol_pump_dashboard_widgets.dart` (`PetrolPumpDashboardWidgets`: shift status, fuel ticker, low-tank summary) — no references outside its definition (grep) | High |
| 5.4 | Generic dashboard has **no petrol KPI tiles** (no per-fuel sales, no tank %, no shift status) | `business_quick_actions.dart` only adds 3 buttons; no petrol KPI widget wired into V2 dashboard | Medium |

---

## 6. Navigation & Route Gaps

**Every petrol sidebar id resolves** in `sidebar_navigation_handler.getScreenForItem()` (verified):

| Sidebar id | Resolves to | Status |
|---|---|---|
| `petrol_dashboard` | `PetrolPumpManagementScreen` | ✅ (but menu-only, see 5.1) |
| `shift_management` | `ShiftHistoryScreen` | ✅ |
| `dispenser_management` | `DispenserListScreen` | ✅ |
| `tank_management` | `TankListScreen` | ✅ |
| `new_sale` | `BillCreationScreenV2` | ✅ (generic, not fuel-aware, see §7/§13) |
| `revenue_overview` | `RevenueOverviewScreen` | ✅ (generic) |
| `sales_register` | `SalesRegisterScreen` | ✅ (generic) |
| `fuel_rates` | `FuelRatesScreen` | ✅ |
| `fuel_profit_report` | `FuelProfitReportScreen` | ✅ (hardcoded ₹0, §8) |
| `nozzle_sales_report` | `NozzleSalesReportScreen` | ✅ |
| `shift_report` | `ShiftReportScreen` | ✅ |
| `tank_stock_report` | `TankStockReportScreen` | ✅ |

**Orphaned petrol screens (not referenced by sidebar handler):**
- `revenue_dashboard_screen.dart` (`RevenueDashboardScreen`) — **orphaned**, no references in `Dukan_x/lib` outside its own file (grep). The single best petrol UI is unreachable. **Priority: High.**
- `presentation/widgets/petrol_pump_dashboard_widgets.dart` — **orphaned** (grep). **High.**
- `presentation/screens/staff_list_screen.dart`, `staff_detail_screen.dart`, `add_staff_screen.dart` (petrol copies) — not imported by the petrol sidebar handler; name collides with `features/staff/...` versions used elsewhere. Wiring of the **petrol-specific** copies is **unverified** but appears orphaned. **Medium.**

**Miscategorized:** `fuel_rates`, `fuel_profit_report` etc. are imported in the nav handler under a comment block "HIDDEN FEATURE SCREENS (Made visible per audit)" / "Petrol Pump Reports (Hidden)" — they now resolve, so this is cosmetic only.

**Dead links inside screens:** `PetrolPumpDashboardWidgets._buildShiftStatusCard` "Open Shift" button `onPressed` is a commented-out navigation no-op (`// Navigator.pushNamed(...)`). **Low** (screen is orphaned anyway).

**Capability mismatch:** None of the petrol sidebar items declare a `capability:` gate (unlike clinic/pharmacy items). So `useFuelManagement / useShiftManagement / usePumpReadings` capabilities are defined in the registry but **never enforced** on the sidebar. **Priority: Medium** (see §11).

---

## 7. Backend Integration Gaps

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 7.1 | **Fuel billing pipeline is dead code.** `PetrolPumpBillingService.createFuelBill` (tank deduction, nozzle increment, ledger posting, period-lock, credit/stock checks, fraud) is **never called outside tests** | grep `createFuelBill` → only definition + `test/` files | Critical |
| 7.2 | `new_sale` uses generic `BillCreationScreenV2` which **does not set `shiftId` or `attendantId`** on bills | grep `shiftId|attendantId` in `features/billing/**` → **no matches**; `bill_creation_screen_v2` save path sets fuelType/vehicleNumber only | Critical |
| 7.3 | Therefore tank stock, nozzle readings, shift reconciliation, and staff settlement are **not driven by real sales** | consequence of 7.1+7.2 | Critical |
| 7.4 | Calibration service unused | `calibration_reminder_service.dart` (no caller located) | Medium |
| 7.5 | `PetrolPumpBusinessRules` (rollover/saleValue/cashVariance) unused | grep → only definition | Medium |

---

## 8. Database & API Issues (real vs mock; hardcoded counts)

**Split-brain datastore (Critical):** Petrol entities are read/written through **two different backends**:
- **Drift / SQLite (offline-first):** `ShiftService`, `PetrolPumpBillingService`, `CalibrationReminderService` operate on `_db.shifts/_db.nozzles/_db.tanks/_db.dispensers/_db.bills` etc.
- **API Gateway via `firestore_compat`:** `TankService`, `DispenserService`, `FuelService`, `PeriodLockService` use `FirebaseFirestore.instance.collection('tanks'|'dispensers'|'nozzles'|'fuelTypes'|'settings')` which `firestore_compat.dart` routes to `/api/v1/...`.

Consequence: The UI lists tanks/nozzles/fuel from the **API store**, while the (unused) billing/shift logic mutates the **Drift store**. Even if billing were wired, tank/nozzle changes would not appear in `TankListScreen`/`DispenserListScreen`/`NozzleSalesReportScreen`. Evidence: compare `tank_service.dart` (`FirebaseFirestore`) vs `petrol_pump_billing_service.dart` (`_db.customStatement('UPDATE tanks ...')`). **Priority: Critical.**

**API collection-name mismatch (High):** `FuelService` uses `.collection('fuelTypes')`, but `firestore_compat._collectionToApi` maps only `'fuel_types' → /api/v1/fuel-types`. `_resolveEndpoint` falls through to the last-segment fallback → `/api/v1/fuelTypes` (logs a WARNING). Likely 404 against the real `fuel-types` route. Evidence: `fuel_service.dart` + `firestore_compat.dart` mapping table. **Priority: High (unverified at runtime).**

**Polling, not real-time (Medium):** `firestore_compat` `snapshots()` polls every **30s** (`DocumentReference.snapshots()` / `Query.snapshots()`). So tank levels, nozzle readings, and fuel rates update with up-to-30s lag and extra network cost. **Priority: Medium.**

**Hardcoded dashboard alert counts (High):** `business_alerts_widget.dart` `case BusinessType.petrolPump` emits **static** values: "Tank Levels Low" count `'2'`, "Shift Settlement Pending" count `'1'`. Title is "Station Alerts" (`_getTitle`). Only `grocery` uses the live `alertCountsProvider`; petrol is fabricated. **Priority: High.**

**Hardcoded report numbers (High):** `fuel_profit_report_screen.dart` shows Total Sales/Cost/Profit = "₹0", per-fuel Litres "0 L", Revenue "₹0", Margin "0%" — only fuel names/rates are real. The date-range picker just shows a SnackBar and **does not filter** anything. **Priority: High.**

**Purchase cost discarded (High):** `add_stock_dialog` collects "Purchase Price per Litre" but `_submit` calls `TankService.addPurchase(tankId, quantity)` only — price is dropped. With no cost captured, profit/margin reports cannot be computed. **Priority: High.**

---

## 9. Responsive Design

- Petrol screens use `BoundedBox(maxWidth: ...)` and `responsiveValue<double>(...)` consistently (`petrol_pump_management_screen`, `tank_list_screen`, `fuel_rates_screen`, all report screens). The orphaned `revenue_dashboard_screen` has full mobile/tablet/desktop layouts. **Good.**
- Minor: `shift_history_screen` builds a wide action `Row` (Assign Nozzles + Close buttons + text) inside the header with no wrap — likely overflow on narrow widths. Evidence: `shift_history_screen.dart` active-shift `Row`. **Priority: Low.**

---

## 10. Performance

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 10.1 | 30s polling on every tank/nozzle/fuel stream | `firestore_compat` `snapshots()` | Medium |
| 10.2 | `_showNozzleAssignmentDialog` fetches dispensers then **N sequential** `getNozzlesByDispenser(...).first` calls (one round trip each) | `shift_history_screen._showNozzleAssignmentDialog` | Medium |
| 10.3 | `_resetNozzlesForShift` enqueues a sync row per nozzle in a loop | `shift_service._resetNozzlesForShift` | Low |
| 10.4 | `RevenueDashboardScreen` recomputes all metrics on every bill stream tick over full `watchAll` list | `revenue_dashboard_screen.build` | Low (orphaned) |

---

## 11. Security (RBAC, capability bypass)

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 11.1 | **No attendant/shift-operator role** in core RBAC | `session_manager._loadUserSession` maps only owner/manager/staff/accountant/unknown | High |
| 11.2 | Petrol sidebar items have **no `capability`/`permission` gate**, so `useShiftManagement`/`usePumpReadings` are never enforced; any role seeing the sidebar can open shifts, edit rates, adjust tanks | `_getPetrolPumpSections()` items lack `capability:`; `sidebarSectionsProvider` only filters when set | High |
| 11.3 | Nozzle reading permission checks are **bypassable**: `DispenserService.updateOpeningReading/updateClosingReading` skip the `canEditReadings` check entirely when `employeeId == null`, and UI never passes an `employeeId` | `dispenser_service.dart` (`if (employeeId != null)`) | High |
| 11.4 | `Employee` permission model (`canEditReadings`, `canOpenShift`...) exists but there is **no UI to create Employees**, so the permission system is inert | `dispenser_service._checkPermission` reads `employees` collection; petrol mgmt screen removed employee UI | Medium |
| 11.5 | Shift close has real anti-fraud guards (reconciliation tolerance, cash-declaration variance, `forceClose` owner override, audit logging) — good, but `forceClose` is callable without a verified owner-role check at the service layer | `shift_service.closeShift` | Medium |
| 11.6 | Period lock writes to API store but only **best-effort** syncs to the Drift global lock (`if (sl.isRegistered<LockingService>())`) | `period_lock_service.closePeriod` | Medium |

---

## 12. Offline Mode Gaps

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 12.1 | **Inconsistent offline strategy.** Shifts/bills/calibration are Drift-backed with a `SyncQueue` (offline-first), but tanks/nozzles/dispensers/fuel rates/period-lock go straight to the API and **fail/serve stale on no network** (no sync queue) | `shift_service._enqueueSync` (Drift) vs `tank_service`/`dispenser_service`/`fuel_service` (direct API) | Critical |
| 12.2 | Meter readings and tank levels — the most safety-critical offline data — are on the **non-offline** API path | §8 split-brain | Critical |
| 12.3 | `firestore_compat` swallows errors in `get()`/`snapshots()` (returns empty/`exists:false`), so offline failures look like "no data" rather than surfacing an error | `firestore_compat DocumentReference.get` catch → `exists:false` | Medium |

---

## 13. Business Logic Inconsistencies

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 13.1 | **GST on fuel is wrong for India.** Petrol & diesel are **outside GST** (VAT + central excise). The app hardcodes 18% GST for fuel: `business_type_config` `defaultGstRate: 18.0`; `FuelType.linkedGSTRate` default `18.0`; billing computes `gstAmount = total * gstRate/(100+gstRate)` and splits CGST/SGST | `business_type_config.dart`, `fuel_type.dart`, `petrol_pump_billing_service.createFuelBill` | Critical |
| 13.2 | Shift reconciliation depends on bills having `shiftId` (Drift) and on nozzle closing readings being updated by sales — neither happens via the live UI, so `calculateShiftSales` yields `nozzleLitres=0, billedLitres=0` and warns "No sales recorded" | `shift_service.calculateShiftSales`; bills have no `shiftId` (§7.2) | Critical |
| 13.3 | Per-nozzle billed-litres reconciliation is stubbed: `billedLitres: 0` hardcoded in `NozzleReconciliation` | `shift_service.calculateShiftSales` comment "Not tracking per-nozzle billing yet" | High |
| 13.4 | Totalizer rollover not applied in live math: `litresSold = closing − opening` (can go negative on rollover) although `PetrolPumpBusinessRules.dispensedLitres` handles it (unused) | `shift_service.calculateShiftSales` vs `petrol_pump_business_rules.dart` | High |
| 13.5 | `Nozzle.calculatedSaleLitres` clamps negatives to 0, **masking** rollover/tamper instead of flagging | `nozzle.dart` getter | Medium |
| 13.6 | `Tank.addPurchase` clamps to capacity, silently dropping overflow litres (no over-fill warning) | `tank.dart addPurchase` | Medium |
| 13.7 | Staff settlement seeds `actualCash: 0` and `difference: -expectedCash` (full shortage) with status PENDING but **no UI to settle/reconcile** | `shift_service.createStaffSettlements` | Medium |

---

## 14. Data Validation Issues

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 14.1 | No nozzle reading-entry UI → meter rollover/negative/decreasing readings cannot be validated at input | no screen (§4.3) | High |
| 14.2 | Dip reading validates `>=0` and `<= capacity`, but **no high-variance hard block** at input (variance only logged server-side >10L) | `dip_reading_dialog` validator; `tank_service.recordDipReading` logs `STOCK_VARIANCE_ALERT` | Medium |
| 14.3 | **No fuel density/temperature bounds** (feature absent) | §3.2 | Medium |
| 14.4 | Fuel rate update accepts any `double.tryParse` ≥ ? — **no min/max sanity bounds** (e.g., rejects 0 or absurd values?) Actually accepts any non-null number incl. 0/negative-after-parse only blocked if `null` | `fuel_rates_screen._showUpdateRateDialog` (`if (newRate != null)`) | Medium |
| 14.5 | `closeShift` cash declaration parses `double.tryParse(...) ?? 0.0` — empty handled in dialog, but non-numeric silently becomes 0 | `shift_history_screen` close flow | Low |
| 14.6 | Tank capacity/initial-stock validated well in `AddTankDialog` (positive, ≤ capacity) | `add_tank_dialog` validators | — (good) |

---

## 15. UX Problems

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 15.1 | `petrol_dashboard` is a bare menu list; no at-a-glance KPIs | `petrol_pump_management_screen.dart` | High |
| 15.2 | Best petrol dashboard is unreachable (orphaned) | §5.2 | High |
| 15.3 | Fuel "Add" FAB does nothing (silent) | `fuel_rates_screen` empty FAB | Medium |
| 15.4 | `add_tank_dialog` & `dip_reading_dialog` error SnackBars print literal `Error: $e` (escaped `\$e`), hiding the real error | `add_tank_dialog._submit` `Text('Error: \$e')`; same in `dip_reading_dialog` | Medium |
| 15.5 | Shift reconciliation warning "No sales recorded" will always show under current wiring, confusing users | §13.2 | Medium |
| 15.6 | Hardcoded report ₹0 + non-functional date picker erodes trust | `fuel_profit_report_screen` | Medium |

---

## 16. Accessibility

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 16.1 | No `Semantics`/`tooltip` on most icon-only elements (e.g., tank action buttons, fuel edit `IconButton`) | `tank_list_screen`, `fuel_rates_screen` (no semantics) | Medium |
| 16.2 | Status conveyed by color alone (tank level red/orange/green; variance red/green) without text/icon redundancy in some spots | `tank_list_screen._getColorForLevel`, `dip_reading_dialog` variance block (has icon+text — ok) | Medium |
| 16.3 | Fixed small font sizes (e.g., `fontSize: 10/12`) in tickers/reports may not scale with text-scaling | `petrol_pump_dashboard_widgets`, `shift_report_screen` mini-stats | Low |
| 16.4 | Full WCAG conformance requires manual AT testing — **unverified** | — | — |

---

## 17. Bugs / Errors / Crash Scenarios

| # | Finding | Evidence | Severity |
|---|---|---|---|
| 17.1 | Mojibake in report labels: literal `â‚¹` instead of ₹, and a comment uses `clause 2.16` with corrupted chars | `shift_report_screen` (`'â‚¹${...}'` in Total Sales/mini-stats), `petrol_pump_business_rules.dart` header comment | Medium |
| 17.2 | Escaped interpolation hides errors (`'Error: \$e'`) | `add_tank_dialog`, `dip_reading_dialog` | Low |
| 17.3 | `debug print` statements left in production service (`print('DEBUG: ...')`) | `shift_service.openShift`, `petrol_pump_billing_service.createFuelBill` | Low |
| 17.4 | Potential negative litres / wrong reconciliation on totalizer rollover (no guard in live path) | §13.4 | Medium |
| 17.5 | If `FuelService` API path 404s (collection-name mismatch), fuel lists render "No fuel types found" with no error — silent failure | §8 + `firestore_compat` swallow | Medium (unverified) |
| 17.6 | `_resolveTankForNozzle` reads `_db.dispensers` by `t.id` but nozzle stores `dispenserId`; Drift `dispensers` PK vs `dispenserId` field mapping is **unverified** (could resolve no tank → no stock deduction) | `petrol_pump_billing_service._resolveTankForNozzle` | Medium (unverified, code path unused) |

---

## 18. Unnecessary / Irrelevant Features Shown

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 18.1 | Common sections likely expose retail/manufacturing items irrelevant to fuel (e.g., batch tracking, proforma/dispatch, HSN) via `_getCommonSections` | `_getPetrolPumpSections()` appends `_getCommonSections(startingIndex: 3)` — content not fully enumerated here (**partially unverified**) | Medium |
| 18.2 | Config optional field `gst` shown though fuel GST handling is itself incorrect (§13.1) — exposing an editable/auto GST on fuel invoices is misleading | `business_type_config` optional `[... gst]`, `gstEditable:false` | Medium |
| 18.3 | Quick action "Fuel Rates" duplicates the sidebar `fuel_rates` entry (minor redundancy) | `business_quick_actions` petrolPump case | Low |

---

## 19. Recommendations & Prioritized Implementation Plan

**P0 — Critical (correctness/data integrity):**
1. **Fix fuel GST/VAT** (§13.1): set petrol/diesel as non-GST (VAT/excise-inclusive, tax-on-fuel = 0 GST or a configurable state VAT line). Update `business_type_config.defaultGstRate`, `FuelType.linkedGSTRate` defaults for petrol/diesel, and the GST split in `createFuelBill`.
2. **Unify the datastore** (§8 split-brain, §12): move `TankService`/`DispenserService`/`FuelService`/`PeriodLockService` onto the same Drift + SyncQueue path used by `ShiftService`/billing (or vice-versa), so UI and logic share one source of truth.
3. **Wire fuel billing** (§7): make `new_sale` for petrolPump route fuel lines through `PetrolPumpBillingService.createFuelBill` (or have `BillCreationScreenV2` set `shiftId`/`attendantId` and trigger tank/nozzle updates), so sales actually move stock and feed reconciliation.
4. **Build nozzle/dispenser setup + reading-entry UI** (§4.1–4.3) so stations can be configured and opening/closing readings captured.

**P1 — High:**
5. Replace the `petrol_dashboard` menu with the existing `RevenueDashboardScreen` (un-orphan it) and wire `PetrolPumpDashboardWidgets` (§5.2/5.3/6).
6. Make `fuel_profit_report` compute real sales/cost/margin and honor the date range; **capture purchase price** in `AddStockDialog` (§8, §3.11).
7. Replace hardcoded "Station Alerts" counts with live tank-level/shift-settlement queries (§8).
8. Add capability/permission gates to petrol sidebar items and introduce an **attendant** role (§11.1/11.2).
9. Use `PetrolPumpBusinessRules.dispensedLitres` (rollover) in `calculateShiftSales`; implement per-nozzle billed-litres (§13.3/13.4).
10. Fuel rate change with **effective-from time** + bounds validation (§3.6/14.4).

**P2 — Medium:**
11. Density/temperature & volume correction; evaporation-loss tracking; 5L test-return; tanker/decanting record (§3.2/3.4/3.9/3.11).
12. Wire `CalibrationReminderService` into a dashboard/alerts panel (§3.13).
13. Fix mojibake ₹ labels and `Error: \$e` SnackBars; remove `print` debug logs (§17).
14. Enforce `forceClose`/period-lock with verified owner role; non-null `employeeId` for reading edits (§11).
15. Accessibility: semantics/tooltips, text-scaling, non-color status cues (§16).

**P3 — Low:** reduce 30s polling reliance; batch nozzle fetches; de-duplicate quick action vs sidebar.

---

## 20. Confidence & Coverage

**Coverage:** High for the petrol feature surface. Read 100% of `petrol_pump/` screens, services, dialogs, the three core models, business rules, the sidebar config/handler, both dashboard widgets, capability registry (petrol set), and the billing save path. Cross-checked all 12 petrol sidebar ids against the nav handler. Used grep to confirm orphaned screens (`RevenueDashboardScreen`, `PetrolPumpDashboardWidgets`) and unused logic (`createFuelBill`, `PetrolPumpBusinessRules`) and the absence of `shiftId`/`attendantId` in billing.

**Confidence by area:**
- Sidebar/nav/config/capabilities: **High** (direct reads).
- Hardcoded alerts/reports: **High** (direct reads).
- Split-brain datastore & billing-not-wired: **High** (direct reads + grep).
- GST/VAT defect: **High** (config + model + billing all read).
- API collection-name 404, `_resolveTankForNozzle` PK mapping, runtime offline behavior: **Medium / unverified** (static inference; not run).
- Common-section irrelevant items (§18.1): **Partially unverified** (did not enumerate every common item).
- Petrol staff-screen wiring & `service_locator` registrations: **unverified** (name collisions / file not read).

**Not done:** runtime execution, AT/WCAG validation, `main.dart` route table, `shift.dart`/`shift_reconciliation.dart`/`dispenser.dart`/`employee.dart` internals.
