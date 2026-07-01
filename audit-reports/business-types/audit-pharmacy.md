# DukanX Business-Type Audit — Pharmacy (Medical / Pharmacy)

> READ-ONLY, evidence-based audit. No source files were modified. Every claim cites the file checked. Items not directly verified are marked **unverified**.
>
> Scope: `BusinessType.pharmacy` in the DukanX Flutter desktop/enterprise app (`Dukan_x/`).
> Date of audit: generated from current workspace state.

---

## 1. Header — Resolution, Config & Capability Summary

### 1.1 Business type & config
- Enum: `BusinessType.pharmacy`, displayName **"Medical / Pharmacy"**, icon `medical_services_rounded` — `Dukan_x/lib/models/business_type.dart`.
- Emoji 💊, primary color `#2563EB` (blue) — `Dukan_x/lib/core/billing/business_type_config.dart`.
- Config (`BusinessTypeRegistry._configs[BusinessType.pharmacy]`, `business_type_config.dart`):
  - requiredFields: `itemName, quantity, price, batchNo, expiryDate, drugSchedule`
  - optionalFields: `doctorName, hsnCode`
  - `defaultGstRate: 12.0`, `gstEditable: false`
  - unitOptions: `pcs, strip, ml, gm, box`
  - `itemLabel: 'Medicine'`, `addItemLabel: 'Add Medicine'`, `priceLabel: 'MRP'`
  - modules: `inventory, prescriptions, sales, returns, suppliers, reports`
  - **Confirmed matches the brief.**

### 1.2 Sidebar resolution (desktop primary UI)
Source: `_getPharmacySections()` + `_getCommonSections(startingIndex: 4)` in `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart`. Resolution target: `SidebarNavigationHandler.getScreenForItem()` in `Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart`.

| Section | Sidebar id | Resolves to | Status |
|---|---|---|---|
| Pharmacy Control | `executive_dashboard` | `DashboardController` → `ProfessionalOwnerDashboard` | ✅ resolves (generic, see §6.4) |
| Pharmacy Control | `live_health` | `LiveBusinessHealthScreen` | ✅ |
| Pharmacy Control | `daily_snapshot` | `DailySnapshotScreen` | ✅ |
| Dispensing & Sales | `new_sale` | `BillCreationScreenV2` | ✅ (pharmacy-aware, §7) |
| Dispensing & Sales | `prescriptions` | `SafePrescriptionListScreen` (doctor module) | ✅ resolves; gated by `usePrescription` |
| Dispensing & Sales | `revenue_overview` | `RevenueOverviewScreen` | ✅ |
| Dispensing & Sales | `sales_register` | `SalesRegisterScreen` | ✅ |
| Inventory & Expiry | `item_stock` | `InventoryDashboardScreen` | ✅ |
| Inventory & Expiry | `batch_tracking` | `BatchTrackingScreen` | ✅ (real data, §8) — **no capability gate here** (see §13) |
| Inventory & Expiry | `low_stock` | `LowStockAlertsScreen` | ✅ |
| Inventory & Expiry | `stock_valuation` | `StockValuationScreen` | ✅ |
| Procurement | `purchase_orders` | `BuyOrdersScreen` | ✅ |
| Procurement | `stock_entry` | `StockEntryScreen` | ✅ |
| Procurement | `supplier_bills` | `SupplierBillsScreen` | ✅ |
| Parties & Ledger (common) | `customers` | `CustomersListScreen` | ✅ |
| Parties & Ledger (common) | `suppliers` | `PartyLedgerListScreen(initialFilter:'supplier')` | ✅ |
| Parties & Ledger (common) | `party_ledger` | `PartyLedgerListScreen` | ✅ |
| Parties & Ledger (common) | `outstanding` | `PartyLedgerListScreen(initialFilter:'receivable')` | ✅ |
| Reports (common) | `analytics_hub` | `ReportsHubScreen` | ✅ |
| Reports (common) | `product_performance` | `ProductPerformanceScreen` | ✅ |
| Reports (common) | `invoice_margin` | `PnlScreen` | ✅ |
| Reports (common) | `gstr1` | `GstReportsScreen(initialIndex:0)` | ✅ |
| System (common) | `print_settings` | `PrintMenuScreen` | ✅ |
| System (common) | `backup` | `BackupScreen` | ✅ |
| System (common) | `error_logs` | `ErrorLogsScreen` | ✅ |
| System (common) | `device_settings` | `DeviceSettingsScreen` | ✅ |

**Result: All 24 pharmacy sidebar ids resolve to real screens. No `_PlaceholderScreen` dead links in the sidebar itself.** (Dead links exist in dashboard quick-actions instead — see §6.)

### 1.3 Capability summary
Two capability layers exist:
- Hard-isolation registry `businessCapabilityRegistry['pharmacy']` — `Dukan_x/lib/core/isolation/business_capability.dart`. Pharmacy grants: product 1–7, inventory list/visible/dead/search, invoice list/search/create + `useSalesReturn`, alerts (low-stock/general/snapshot/revenue), purchase (PO/entry/reversal/supplier-bill/register), and specialized: `usePrescription, useDoctorLinking, usePatientRegistry, useDrugSchedule, useSaltSearch, useBatchExpiry, useBarcodeScanner, useScanOCR, useStockManagement, useLowStockAlerts`.
- Derived flags `BusinessCapabilities.get()` — `Dukan_x/lib/core/config/business_capabilities.dart`. For pharmacy: `supportsExpiry=true` (note grocery is explicitly excluded), `supportsBatch=true`, `supportsPrescriptions=true`, `supportsBarcodeScan=true`, `supportsTextOCR=true`, `ocrFocus='Name, Batch, Expiry, MRP'`.

Resolver: `FeatureResolver.canAccess()` / `enforceAccess()` — `Dukan_x/lib/core/isolation/feature_resolver.dart` (strict deny on unknown type).

---

## 2. Missing Generic Features (vs Vyapar benchmark)

Evidence base: sidebar config, `business_capability.dart`, `sidebar_navigation_handler.dart`.

| # | Vyapar feature | Pharmacy status | Evidence | Priority |
|---|---|---|---|---|
| 1 | Billing: quote→invoice, WhatsApp/SMS/email, thermal+A4 | Billing exists (`BillCreationScreenV2`); **no Proforma/quote item in pharmacy sidebar** (`proforma_bids` omitted from `_getPharmacySections`). Share/WhatsApp/thermal-vs-A4 **unverified** | `sidebar_configuration.dart` (no proforma in pharmacy); `useProformaInvoice` not granted to pharmacy in `business_capability.dart` | High |
| 2 | Inventory: FIFO/FEFO, multi-warehouse, reorder, BOM | FEFO present in billing (§7). **Multi-warehouse, reorder automation, BOM: not found** for pharmacy | grep across `lib` found no warehouse/BOM wiring (**unverified beyond search**) | Medium |
| 3 | Barcode/POS: POS counter, item/bill discount, weighing, cashier reports | `useBarcodeScanner`+`useScanOCR` granted; "New Sale (POS)" present. Dedicated cashier/counter reports **not in pharmacy sidebar** | `sidebar_configuration.dart` | Medium |
| 4 | Accounting: auto-ledger, expense cats, multi-currency, multi-language | Party Ledger + GST present. `expenses` screen exists but **not surfaced in pharmacy sidebar** (only in retail/common-retail) | `sidebar_navigation_handler.dart` has `expenses`→`ExpensesScreen`, but pharmacy `_getCommonSections` omits it | Medium |
| 5 | Receivables/Payables: bulk reminders, credit limits, bill-wise | `outstanding` present; **credit limit not granted** to pharmacy (`useCreditLimit` absent) | `business_capability.dart` pharmacy set | Low |
| 6 | Bank/Cash: multi-bank, cheque/UPI/card/wallet | `cash_bank`/`bank_accounts` **not in pharmacy sidebar** (handler supports `bank_accounts`→`BankScreen`) | `sidebar_configuration.dart` pharmacy/common sections | Medium |
| 7 | Orders/Delivery: delivery challan, status | **Not in pharmacy sidebar**; `useDispatchNote` not granted to pharmacy | `business_capability.dart` | Low |
| 8 | OCR bill→purchase entry | `useScanOCR` granted; medicine OCR parser exists (`features/ml/parsers/medicine_ocr_parser.dart`) and billing has OCR path. Purchase-entry-from-OCR **unverified** | `bill_creation_screen_v2.dart` OCR block | Medium |
| 9 | Reports (37+, P&L/BS/GST/stock/outstanding) | Subset present (analytics hub, product perf, P&L, GST). Full 37+ set **not surfaced** for pharmacy | `_getCommonSections` Reports section (4 items) | Medium |
| 10 | Multi-user RBAC + audit trail | RBAC present but **no pharmacist role** (§11); `audit_trail` not in pharmacy sidebar | `lib/core/models/user_role.dart`; `sidebar_configuration.dart` | High |
| 11 | Multi-firm | **unverified** | not searched conclusively | — |
| 12 | Encrypted cloud backup+restore | `backup`→`BackupScreen` present | `sidebar_navigation_handler.dart` | OK |
| 13 | Online store catalog+order link | `catalogue`→`CatalogueScreen` exists but **not in pharmacy sidebar** | handler vs config | Low |
| 14 | e-Way bill | **Not found** | grep (**unverified**) | Low |
| 15 | Loyalty/discount schemes | `useLoyaltyPoints` **not granted** to pharmacy | `business_capability.dart` | Low |
| 16 | Service-business (appointments) | N/A for retail pharmacy (clinic has it) | — | N/A |
| 17 | Offline-first auto-sync | Drift local DB used throughout (e.g. `BatchTrackingScreen`, alerts provider); sync via `BackupScreen`/UNS. Batch/expiry offline behavior §12 | `business_alerts_widget.dart`, `batch_tracking_screen.dart` | see §12 |

---

## 3. Missing Industry-Specific Features (pharmacy)

| Need | Status | Evidence | Priority |
|---|---|---|---|
| Drug license (DL No.) on invoice | **Not found** in pharmacy config or bill header fields; config optional fields are only `doctorName, hsnCode` | `business_type_config.dart` pharmacy config | High |
| Batch + expiry-driven billing & FEFO | **Implemented**: `BillCreationScreenV2` auto-selects first-expiry batch via `PharmacyDao.getBatchesForProduct` and an explicit expiry sort in pre-save check | `bill_creation_screen_v2.dart` (FEFO blocks ~L267, ~L351, ~L1645) | OK (verify ordering — §7) |
| Schedule H/H1/X tracking + Rx-required enforcement | **Partially**: `PharmacyValidationService` blocks scheduled-drug sale without `prescriptionId`; but the POS never captures it (§7/§11) | `core/services/pharmacy_validation_service.dart`; `core/repository/bills_repository.dart` | Critical |
| Prescription capture/linking | Rx list screen reachable; **`PrescriptionGateDialog` is orphaned** (no caller) | grep: `prescription_gate_dialog.dart` only self-referenced | Critical |
| Substitute/generic suggestion, salt search | **Implemented but orphaned in desktop**: `SaltSearchScreen` exists, only reachable via named route `/pharmacy/salt-search` and the orphaned `PharmacyDashboardScreen` | `features/pharmacy/screens/salt_search_screen.dart`; `app/routes.dart`; not in desktop sidebar | High |
| Salt/composition search backend | `SaltSearchScreen` calls real API `/pharmacy/salt-search` | `salt_search_screen.dart` (L67) | OK |
| GST per-item (5/12/18%) | Config `defaultGstRate 12.0`, `gstEditable false` → **single fixed rate**, no per-item schedule-driven GST in config; comment says "per-item" but mechanism not in config | `business_type_config.dart` | High |
| MRP enforcement (cannot sell above MRP) | **Dead code**: `MrpEnforcementValidator` exists but is **never called** anywhere | `lib/utils/mrp_enforcement_validator.dart`; grep found no callers | High |
| Expiry return/credit note to supplier | `useSalesReturn` granted; supplier-side expiry credit note **not found** for pharmacy sidebar | `business_capability.dart`; `sidebar_configuration.dart` | Medium |
| Near-expiry alerts | Logic exists (`isExpiringSoon` 90-day, `isNearExpiry` 30-day); surfaced in `BatchTrackingScreen` + alerts provider | `pharmacy_business_rules.dart`; `business_alerts_widget.dart` | OK (but dashboard widget hardcoded, §8) |
| Refill reminders | **Not found** | grep (**unverified**) | Low |
| Partial-strip sale | unit `strip` exists; partial-strip split logic **unverified** | `business_type_config.dart` unitOptions | Low |
| Supplier/distributor management | `suppliers`, `supplier_bills`, `purchase_orders` present | `sidebar_configuration.dart` | OK |
| Narcotic register | **Implemented but orphaned**: `NarcoticRegisterScreen` (two copies) unreferenced in desktop sidebar | `features/pharmacy/screens/narcotic_register_screen.dart` & `features/prescriptions/.../narcotic_register_screen.dart` | High |
| H1 register | **Implemented but orphaned / dead link** (§6.3) | `features/prescriptions/.../h1_register_screen.dart` | High |
| Patient registry | **Implemented but orphaned in desktop**: `PatientRegistryScreen` only via named route | `features/pharmacy/screens/patient_registry_screen.dart` | Medium |
| Cold-chain | Not relevant / **unverified** | — | — |

---

## 4. Missing UI Components

- **Drug License No. field** on invoice header/print — absent from pharmacy config and bill header fields (`business_type_config.dart`). High.
- **Rx-capture inline component** in POS — `PrescriptionGateDialog` exists but unwired; no batch/Rx entry surface in `BillCreationScreenV2` beyond auto-FEFO. High.
- **Per-item GST selector** keyed to drug schedule — not present (`gstEditable: false`, single `defaultGstRate`). High.
- **Substitute/salt panel inside billing** — `SaltSearchScreen` supports an `onProductSelected` callback (`salt_search_screen.dart` L87) designed for billing integration, but billing never opens it. Medium.

---

## 5. Missing Widgets & Dashboard/KPI Cards

- The **desktop** pharmacy dashboard (`executive_dashboard` → `DashboardController` → `ProfessionalOwnerDashboard`, `dashboard_controller.dart`) is the **generic owner dashboard** — no pharmacy KPI cards (expiring count, schedule-drug stock, Rx dispensed). 
- A **dedicated** `PharmacyDashboardScreen` with pharmacy KPIs and a real backend service (`features/dashboard/v2/services/pharmacy_dashboard_service.dart` calling `/api/pharmacy/revenue`, `/patients/new`, `/prescriptions/count`, `/inventory/low-stock/count`) **exists but is not reachable from the desktop sidebar** (only via the `/pharmacy/dashboard` named route + redirects). High — duplicate, disconnected dashboards.
- `BusinessAlertsWidget` pharmacy case provides KPI-style alert cards, but with **hardcoded counts** (§8) and only hosted by the **orphaned** `DashboardV2Screen`.

---

## 6. Navigation & Route Gaps

### 6.1 Sidebar ids → all resolve
Per §1.2, every pharmacy sidebar id resolves to a real screen; none fall to `_PlaceholderScreen`. ✅

### 6.2 Orphaned pharmacy/prescription screens (not reachable from desktop sidebar)
Enumerated from `features/pharmacy/` and `features/prescriptions/`; cross-checked against `sidebar_navigation_handler.dart` imports (none import these) and `content_host.dart` `_screenBuilders` (none present):
- `features/pharmacy/screens/salt_search_screen.dart` (`SaltSearchScreen`) — only via `/pharmacy/salt-search`.
- `features/pharmacy/screens/patient_registry_screen.dart` (`PatientRegistryScreen`) — only via `/pharmacy/patients`.
- `features/pharmacy/screens/product_catalog_screen.dart` (`PharmacyProductCatalogScreen`) — **no route, no nav reference found** (fully orphaned).
- `features/pharmacy/screens/narcotic_register_screen.dart` (`NarcoticRegisterScreen`) — referenced only by the orphaned `PharmacyDashboardScreen`.
- `features/prescriptions/presentation/screens/narcotic_register_screen.dart` — **duplicate** `NarcoticRegisterScreen`; no references found.
- `features/prescriptions/presentation/screens/h1_register_screen.dart` (`H1RegisterScreen`) — see §6.3.
- `features/prescriptions/presentation/widgets/prescription_gate_dialog.dart` (`PrescriptionGateDialog`) — no caller in `lib/`.

### 6.3 Dead link: "H1 Register" quick action
`BusinessQuickActions` pharmacy case (`features/dashboard/v2/widgets/business_quick_actions.dart`) navigates `nav.navigateTo(AppScreen.h1Register)`. Resolution path: `content_host.dart` `_buildScreen` → not in `_screenBuilders` → falls to `SidebarNavigationHandler.getScreenForItem(AppScreen.h1Register.id)`. `AppScreen.h1Register.id` defaults to snake_case `'h1_register'` (`app_screens.dart`), and `getScreenForItem` has **no `'h1_register'` case → returns `_PlaceholderScreen`**. So the H1 Register action is a **dead link**, even though `H1RegisterScreen` exists. (Also note `AppScreen.h1Register` is oddly grouped under "JEWELLERY SPECIFIC" in `app_screens.dart`.) Critical for compliance UX.
- By contrast, `AppScreen.medicineMaster.id`=`'medicine_master'` ✅ resolves to `MedicineMasterScreen`; `AppScreen.prescriptions` ✅ resolves.

### 6.4 Two parallel navigation systems (architectural)
- Desktop shell: `EnterpriseDesktopSidebar` → `navigateById` → `NavigationController`(AppScreen) → `DesktopContentHost` (`content_host.dart`) → `SidebarNavigationHandler`.
- Named routes: `app/routes.dart` + `core/navigation/owner_dashboard_redirect.dart` + `core/navigation/pharmacy_dashboard_redirect.dart` (redirect pharmacy → `/pharmacy/dashboard`). 
The dedicated pharmacy screens live only on the named-route side, so the **desktop pharmacy experience is effectively generic-retail minus expenses/proforma/bank**, while the richer pharmacy vertical (dashboard, salt search, patient registry, registers) is stranded on the other path. High.

### 6.5 Miscategorized
- `AppScreen.h1Register` filed under "JEWELLERY SPECIFIC" comment (`app_screens.dart`). Low (cosmetic) but indicative of the unfinished wiring.

---

## 7. Backend Integration Gaps

- **Billing pharmacy logic (positive):** `BillCreationScreenV2` (`bill_creation_screen_v2.dart`):
  - FEFO auto-fill from `PharmacyDao.getBatchesForProduct` (uses `batches.first` — **assumes DAO returns earliest-expiry first; ordering not verified in this audit** → confirm `PharmacyDao` ordering, otherwise FEFO is wrong).
  - Pharmacy hard-block on insufficient stock (no negative stock), vs soft-warn for others (~L1577–1616).
  - Pre-save warns on unbatched multi-batch items with explicit earliest-expiry sort (~L1645).
  - Passes `prescriptionId: _prescriptionId` into the saved bill (~L1760).
- **Rx capture gap:** `_prescriptionId` in the pharmacy POS is **declared but never assigned** — the only `_prescriptionId =` assignment in the codebase is in `features/doctor/presentation/screens/visit_screen.dart` (L896), not in the pharmacy billing screen. Combined with `PharmacyValidationService` throwing `MISSING_PRESCRIPTION` for schedule H/H1/X (`pharmacy_validation_service.dart`), a scheduled-drug sale is either **un-completable** through the desktop POS or the schedule check never fires because items lack `drugSchedule`. **Critical business-logic/compliance gap.**
- **MRP validator not wired:** `MrpEnforcementValidator.validateMrpCompliance` / `isMrpCompliant` have no callers (`mrp_enforcement_validator.dart`). MRP ceiling is not enforced in billing or `bills_repository`.
- **Real backend services exist but disconnected:** `pharmacy_dashboard_service.dart` and `patient_registry_service.dart` call real `/api/pharmacy/*` endpoints, but their host screens are off the desktop path (§5, §6.4).

---

## 8. Database & API Issues (real-data vs mock)

- **Confirmed real data:**
  - `BatchTrackingScreen` (`features/inventory/presentation/screens/batch_tracking_screen.dart`) loads `ProductsRepository.getAllBatches` + `getAll` from Drift — real data.
  - `MedicineMasterScreen` (`features/doctor/presentation/screens/medicine_master_screen.dart`) loads `ProductsRepository.getAll` filtered by `category in {medicine, medicines, drug}` — real data.
  - `alertCountsProvider` (`business_alerts_widget.dart`) computes `lowStock`/`expiringSoon` from Drift (`productBatches` 7-day window) via UNS stream — real data.
- **Confirmed hardcoded / mock (explicit per brief):** `BusinessAlertsWidget` **pharmacy** case (`business_alerts_widget.dart`) **ignores the live `counts` map** and renders static strings:
  - "Critical Stock (H1/X)" → **`count: '5'`**
  - "Expired Medicines" → **`count: '3'`**
  - "Expiring This Week" → **`count: '15'`**
  Contrast: the **grocery** case in the same widget correctly uses `counts['expiringSoon']`/`counts['lowStock']`. So pharmacy alert numbers are fake while grocery's are live. 
  - **Mitigating nuance:** the only host of this widget, `DashboardV2Screen`, appears **unreferenced** (no callers found in `lib/`), so these fake numbers may not render on the active desktop path. Still a real defect (wrong widget logic + dead screen). Medium–High.
- `SaltSearchScreen` and `PatientRegistryScreen` use real API clients (`/pharmacy/salt-search`, `/pharmacy/patients`) — real data, but screens orphaned (§6.2).

---

## 9. Responsive Design Issues

- Screens use `desktop_content_container.dart` + `core/responsive/responsive.dart` (seen in `BatchTrackingScreen`, `MedicineMasterScreen`, `PharmacyDashboardScreen`). `DashboardV2Screen` branches on `isMobile` for alerts/quick-actions layout. No specific pharmacy responsive breakage observed in sampled files. **Largely unverified** — no runtime layout testing performed.

---

## 10. Performance Issues

- `DesktopContentHost` caches screens (`_screenCache`) and clears on business-type change — reasonable.
- `BatchTrackingScreen._loadData` loads **all** batches + **all** products into memory and builds a name map each load — could be heavy for large pharmacy inventories (`batch_tracking_screen.dart`). Medium (scales with catalog size).
- `BillCreationScreenV2` performs a `PharmacyDao` DB round-trip **per item add** for FEFO (`bill_creation_screen_v2.dart` ~L272/L357) — potential N queries during fast counter billing. Medium.
- Otherwise **unverified** (no profiling).

---

## 11. Security Concerns (Rx / schedule-drug compliance, RBAC)

- **No pharmacist role.** `UserRole = { owner, manager, staff, accountant, unknown }` (`lib/core/models/user_role.dart`). The H1/narcotic screens document "Access: owner, manager, pharmacist" (`h1_register_screen.dart`, `prescriptions/.../narcotic_register_screen.dart`) but **`pharmacist` does not exist** in the enum — the intended least-privilege dispensing role is unimplemented. High.
- **Schedule-drug enforcement is half-wired.** `PharmacyValidationService` (data layer, called from `bills_repository._validatePharmacyCompliance`) blocks H/H1/X without `prescriptionId`, but the POS UI never collects one (§7) and `PrescriptionGateDialog` is orphaned. Net effect: either sales are blocked with no recovery path, or the rule is silently bypassed when `drugSchedule` is unset on items. Critical.
- **No prescription retention workflow** surfaced (rule exists in `pharmacy_business_rules.requiresPrescriptionRetention` for H1/X but no UI consumes it). High.
- Sidebar capability/permission gating is implemented (`sidebar_configuration.dart` filters by `FeatureResolver.canAccess` + `RolePermissions.hasPermission`), but pharmacy items mostly carry no `permission`, so role-based hiding is minimal for this type.

---

## 12. Offline Mode Gaps (batch/expiry sync)

- Batch/expiry data is local-first (Drift `productBatches`); `alertCountsProvider` does an initial offline fetch then listens to UNS, with an `EventDispatcher` fallback (`business_alerts_widget.dart`). Reasonable offline behavior for alerts.
- `BillCreationScreenV2` FEFO reads from local `PharmacyDao`/`AppDatabase` — works offline.
- **Gap:** no explicit conflict-resolution/sync path observed for batch quantity decrements vs server (e.g., two offline terminals dispensing the same batch). **Unverified** — needs sync-layer review (`PharmacyDao`, sync engine not read). Medium.

---

## 13. Business Logic Inconsistencies

- **`batch_tracking` not capability-gated for pharmacy** (`sidebar_configuration.dart` pharmacy section), whereas the retail section gates it with `useBatchExpiry`. Pharmacy does hold `useBatchExpiry`, so functionally fine, but inconsistent gating. Low.
- **`supportsExpiry` excludes grocery by special-case** (`business_capabilities.dart`: `type != BusinessType.grocery && canAccess(useBatchExpiry)`) — grocery holds `useBatchExpiry` but `supportsExpiry=false`; pharmacy is unaffected but the override is a smell. Low.
- **Config says GST is "per-item based on schedule"** (comment) yet `gstEditable:false` + single `defaultGstRate:12.0` with no per-schedule mapping (`business_type_config.dart`). Medicines legitimately span 5/12/18%. High.
- **Duplicate `NarcoticRegisterScreen`** in two packages (`features/pharmacy/screens` and `features/prescriptions/presentation/screens`) — divergent implementations risk. Medium.
- **FEFO trust assumption:** billing uses `batches.first` as earliest-expiry (`bill_creation_screen_v2.dart`) without an inline sort at add-time (sort only appears in the pre-save scan). If `PharmacyDao.getBatchesForProduct` is not ordered by expiry, FEFO is incorrect. Verify. Medium.

---

## 14. Data Validation Issues

- **Expiry:** blocked at sale if `expiryDate` in the past, but **only when `expiryDate` is set** — items with null expiry bypass the block (`pharmacy_validation_service.dart` Rule 1). For pharmacy, batch+expiry are required fields (Rule 2) so this is partly mitigated, but the order of checks means a null-expiry scheduled drug could still surface confusing errors. Medium.
- **MRP:** no validation that selling price ≤ MRP (validator dead, §7). Data-entry allows price above MRP. `add_product_sheet.dart` validates MRP > 0 and numeric only, not a ceiling. High.
- **Schedule value matching is string-based** (`_isScheduledDrug` compares upper-cased `'H'|'H1'|'X'`; `pharmacy_business_rules.DrugSchedule` is an enum) — two representations of schedule (string on `BillItem.drugSchedule` vs `DrugSchedule` enum) increase mismatch risk. Medium.
- **Batch number:** required for pharmacy (Rule 2) — good.

---

## 15. UX Problems

- Pharmacy users on desktop see a **generic owner dashboard** with no pharmacy KPIs (§5); the purpose-built pharmacy dashboard is unreachable from the sidebar. High.
- The **"H1 Register" quick action leads to a "Feature Not Found" placeholder** (§6.3) — broken affordance for a compliance feature. Critical.
- "Drug Lookup" quick action → `MedicineMaster` works, but the richer **salt/substitute search** is never offered in-flow. Medium.
- Prescriptions item reuses the **doctor module** `SafePrescriptionListScreen` — pharmacy-specific dispensing context may be missing. **Unverified** (screen not deeply read). Medium.

---

## 16. Accessibility Issues

- No `Semantics`/screen-reader audit performed. Quick-action and alert cards (`business_quick_actions.dart`, `business_alerts_widget.dart`) are icon+text `InkWell`/`Row`s without explicit semantic labels — likely adequate but **unverified**. Full WCAG validation requires manual assistive-tech testing. Low–Medium (unverified).

---

## 17. Bugs, Errors, Crash Scenarios

- **Dead link** (`AppScreen.h1Register` → placeholder) — §6.3. Critical (functional).
- **Hardcoded pharmacy alert counts** — §8. Medium–High (data integrity).
- **Scheduled-drug sale dead-end** — POS cannot supply `prescriptionId`; `bills_repository` validation may throw `PharmacyComplianceException(MISSING_PRESCRIPTION)` with no UI remedy (§7/§11). Crash/abort-of-flow risk. Critical.
- **Duplicate class `NarcoticRegisterScreen`** across two files — import-ambiguity / maintenance hazard (§13). Medium.
- `BatchTrackingScreen._loadData` swallows exceptions silently (`catch (e) { setState(loading=false) }`, `batch_tracking_screen.dart`) — failures show empty list with no error surface. Low–Medium.

---

## 18. Unnecessary / Irrelevant Features Shown (flag only — do not remove without sign-off)

Shared components surfaced for pharmacy that may be off-target:
- **Generic owner dashboard** instead of pharmacy dashboard (`dashboard_controller.dart`). Flag.
- `prescriptions` item routes to the **doctor/clinic** `SafePrescriptionListScreen` (`sidebar_navigation_handler.dart`) — shared with clinic; verify it fits pharmacy dispensing. Flag.
- Reuse mappings in handler: `suppliers`→PartyLedger(filter), `purchase_register`→`ProcurementLogScreen`, `invoice_margin`→`PnlScreen` — acceptable reuse, but verify labels match pharmacy expectations. Flag (low).
- `product_catalog_screen.dart` (pharmacy) exists but is unused — candidate to wire or retire (do not delete without sign-off). Flag.

---

## 19. Recommendations & Prioritized Implementation Plan

### Critical
1. **Wire Rx capture into the pharmacy POS.** Invoke `PrescriptionGateDialog` (`prescriptions/.../prescription_gate_dialog.dart`) from `BillCreationScreenV2` when an item's `drugSchedule ∈ {H,H1,X}`, and assign its result to `_prescriptionId` before save. Resolves the scheduled-drug dead-end (§7, §11).
2. **Fix the H1 Register dead link.** Add a `'h1_register'` case to `SidebarNavigationHandler.getScreenForItem` (or register `AppScreen.h1Register` in `content_host._screenBuilders`) pointing to `H1RegisterScreen`; also surface H1/Narcotic registers in the pharmacy sidebar (§6.3).
3. **Decide the dashboard story.** Either route pharmacy `executive_dashboard` to `PharmacyDashboardScreen` (and connect its real `pharmacy_dashboard_service`) or port its KPIs into the owner dashboard. Eliminate the parallel-nav split (§5, §6.4).

### High
4. **Implement a `pharmacist` `UserRole`** with least-privilege permissions; align H1/narcotic/registers access (`user_role.dart`, `session_manager.dart`).
5. **Enforce MRP.** Call `MrpEnforcementValidator` in `bills_repository`/billing; populate per-batch MRP; block/flag price > MRP (§7, §14).
6. **Per-item GST by schedule.** Replace the single `defaultGstRate` with a schedule/HSN→rate mapping for medicines (§3, §13).
7. **Surface pharmacy verticals in the desktop sidebar:** Salt/Substitute search, Patient Registry, Narcotic/H1 registers; add Drug License No. to invoice header/print (§3, §6.2).
8. **Replace hardcoded pharmacy alert counts** with the live `counts` map (mirror the grocery branch) in `business_alerts_widget.dart`, and remove/retire the orphaned `DashboardV2Screen` (§8).

### Medium
9. Verify/guarantee FEFO ordering in `PharmacyDao.getBatchesForProduct`; add an inline expiry sort at add-time (§7, §13).
10. De-duplicate `NarcoticRegisterScreen` (§13).
11. Add expiry/return credit-note-to-supplier flow; expenses + bank entries to the pharmacy sidebar (§2).
12. Surface load errors in `BatchTrackingScreen`; paginate batch/product loads (§10, §17).
13. Reconcile the two `drugSchedule` representations (string vs `DrugSchedule` enum) (§14).

### Low
14. Move `AppScreen.h1Register` out of the "JEWELLERY SPECIFIC" group; tidy capability gating consistency for `batch_tracking` (§6.5, §13).
15. Accessibility pass (semantic labels) on dashboard cards (§16).

---

## 20. Confidence & Coverage

**Read in full (high confidence):**
- `models/business_type.dart`; `core/billing/business_type_config.dart` (pharmacy config); `widgets/desktop/sidebar_configuration.dart` (full pharmacy + common sections); `widgets/desktop/sidebar_navigation_handler.dart` (full); `core/isolation/business_capability.dart` (pharmacy set) + `feature_resolver.dart`; `core/config/business_capabilities.dart`; `features/dashboard/v2/widgets/business_quick_actions.dart` + `business_alerts_widget.dart`; `core/navigation/app_screens.dart` + `navigation_controller.dart`; `widgets/desktop/content_host.dart` (screen-builder map); `features/dashboard/presentation/screens/dashboard_controller.dart`; `core/services/pharmacy_validation_service.dart`; `features/pharmacy/utils/pharmacy_business_rules.dart`; `lib/utils/mrp_enforcement_validator.dart`; `lib/core/models/user_role.dart`.

**Sampled (headers / targeted ranges / grep-verified, medium confidence):**
- `features/inventory/.../batch_tracking_screen.dart` (data source + load path); `features/doctor/.../medicine_master_screen.dart` (data source); `bill_creation_screen_v2.dart` (FEFO, stock-block, `_prescriptionId`, OCR via grep + ranges); `core/repository/bills_repository.dart` (validation wiring via grep); `app/routes.dart` (pharmacy routes); `core/navigation/owner_dashboard_redirect.dart` / `pharmacy_dashboard_redirect.dart` (grep); `features/pharmacy/screens/*` and `features/prescriptions/**` (enumerated + grep for references); `pharmacy_dashboard_service.dart` / `patient_registry_service.dart` / `salt_search_screen.dart` (API endpoints via grep).

**Skipped / not verified (low confidence — flagged "unverified" inline):**
- Full bodies of `SaltSearchScreen`, `PatientRegistryScreen`, `NarcoticRegisterScreen` (both), `H1RegisterScreen`, `PharmacyProductCatalogScreen`, `PrescriptionGateDialog`, `add_product_sheet.dart`, `PharmacyDashboardScreen`.
- `PharmacyDao` (FEFO ordering, stock decrement, sync/conflict resolution); offline sync engine.
- Print/PDF templates (DL No., thermal vs A4, WhatsApp/SMS/email share).
- Runtime responsive/layout behavior; performance profiling; accessibility (assistive-tech) testing.
- Multi-firm, e-Way bill, refill reminders, multi-warehouse/BOM (searched, not found — may exist outside searched paths).

**Approximate coverage:** core routing/config/capability/validation layer for pharmacy ≈ fully read; pharmacy feature screens ≈ enumerated + reference-checked but bodies sampled; print/sync/perf/a11y ≈ not assessed.
