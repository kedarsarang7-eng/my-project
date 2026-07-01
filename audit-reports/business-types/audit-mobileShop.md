# DukanX Business-Type Audit — Mobile Phone Shop (`mobileShop`)

> Read-only, evidence-based audit. Every "missing/broken/orphaned" claim cites the file/function checked. Items I could not confirm are marked **unverified**.
>
> **Sampled (read in full or near-full):** `models/business_type.dart`, `core/billing/business_type_config.dart` (mobileShop config + extensions), `widgets/desktop/sidebar_configuration.dart` (`_getSectionsForBusiness`, `_getRetailSections`, `_getServiceSections`), `widgets/desktop/sidebar_navigation_handler.dart` (full `getScreenForItem`), `widgets/desktop/content_host.dart` (`_buildScreen`), `core/isolation/business_capability.dart` (`'mobileShop'` key), `core/isolation/feature_resolver.dart`, `core/config/business_capabilities.dart`, `features/dashboard/v2/widgets/business_quick_actions.dart`, `features/dashboard/v2/widgets/business_alerts_widget.dart`, `modules/mobile_shop/mobile_shop_module.dart`, `modules/mobile_shop/routes/mobile_shop_routes.dart`, `features/service/presentation/screens/{service_job_list_screen,exchange_list_screen}.dart`, `features/service/services/imei_validation_service.dart`, `core/repository/bills_repository.dart` (IMEI hooks), `core/di/service_locator.dart` (BillsRepository registration), `features/billing/presentation/widgets/{bill_line_item_row,manual_item_entry_sheet}.dart` (relevant parts), `features/billing/services/billing_service.dart` (IMEI block), `app/app.dart` (router wiring), `app/routes.dart` (`/service_jobs`, `/exchanges`, `/job/*`, `/computer-shop/*`).
> **Sampled by directory listing / targeted grep only (not opened in full):** `features/service/{models,data/repositories,services}/*` (exchange, imei_serial, service_job, warranty_claim), `features/computer_shop/presentation/screens/{warranty_screen,serial_history_screen,job_card_detail_screen,multi_unit_screen}.dart`, `modules/mobile_shop/sync|websocket/*`, `core/navigation/{navigation_controller,app_screens}.dart` (confirmed members referenced), `core/session/session_manager.dart` (RBAC). Internals of these are marked **unverified** where not opened.

---

## 1. Header — Business Type, Sidebar Resolution, Config Summary

**Business type:** `BusinessType.mobileShop` (`models/business_type.dart`, 6th enum value). `displayName` = "Mobile Phone Shop", `icon` = `smartphone_rounded`; `emoji` = 📱, `primaryColor` = `#06B6D4` (Light Cyan), `pdfPrimaryColor` = `#06B6D4` (`business_type_config.dart` extensions).

**Sidebar resolution:** mobileShop is grouped with electronics/computerShop in `_getSectionsForBusiness()` (`sidebar_configuration.dart`):
```dart
case BusinessType.electronics:
case BusinessType.mobileShop:
case BusinessType.computerShop:
  return _getRetailSections();
```
So mobileShop renders the **generic retail sidebar** — 10 sections, ~60 items, **zero mobile-specific entries**: no IMEI tracking, no repair/service jobs, no exchange/buyback, no warranty registration, no second-hand/used inventory, no EMI. This directly contradicts the config's declared `modules: ['inventory','sales','repairs','second_hand','reports']` (see §6, §18).

`_getRetailSections()` sections (sidebar id → see §6 for resolution):

| Section | Items (sidebar id) |
|---|---|
| 0 Dashboard & Control | `executive_dashboard`, `live_health`, `alerts`, `daily_snapshot` |
| 1 Revenue Desk | `revenue_overview`, `new_sale`, `receipt_entry`, `return_inwards`, `proforma_bids`, `booking_orders`, `dispatch_notes`, `sales_register` |
| 2 BuyFlow | `buyflow_dashboard`, `purchase_orders`, `stock_entry`, `stock_reversal`, `procurement_log`, `supplier_bills`, `purchase_register` |
| 3 Inventory & Stock | `stock_summary`, `item_stock`, `batch_tracking` (cap `useBatchExpiry`), `low_stock`, `stock_valuation`, `damage_logs` |
| 4 Parties & Ledger | `customers`, `suppliers`, `party_ledger`, `ledger_history`, `ledger_abstract`, `outstanding` |
| 5 Business Intelligence | `analytics_hub`, `turnover_analysis`, `product_performance`, `daily_activity`, `procurement_insights`, `margin_analysis`, `insights`, `catalogue` |
| 6 Financial Reports | `invoice_margin`, `income_statement`, `funds_flow`, `financial_position`, `cash_bank`, `accounting_reports`, `bank_accounts`, `daybook`, `credit_notes`, `expenses` |
| 7 Tax & Compliance | `gstr1`, `b2b_b2c`, `hsn_reports`, `tax_liability`, `filing_status` |
| 8 Operations & Logs | `transaction_reports`, `activity_logs`, `audit_trail`, `error_logs` |
| 9 Utilities & System | `print_settings`, `doc_templates`, `backup`, `sync_status`, `device_settings` |

> Note: a dedicated **`_getServiceSections()`** exists (with `service_jobs` → Service Jobs and `exchanges` → Device Exchanges sidebar entries) but it is wired **only** to `BusinessType.service`, **not** mobileShop. The mobile shop is the most repair/exchange-centric vertical yet does not get this section. **(High — see §6, §18.)**

**Config summary** (`BusinessTypeRegistry._configs[BusinessType.mobileShop]`):
- requiredFields: `itemName, quantity, price, brand, serialNo (IMEI), hsnCode`
- optionalFields: `warrantyMonths, color, discount`
- defaultGstRate: `18.0`, gstEditable: `false`
- unitOptions: `pcs, set, nos`
- itemLabel: `Mobile`, addItemLabel: `Add Mobile`, priceLabel: `MRP`
- modules: `['inventory','sales','repairs','second_hand','reports']`

**Capability registry** (`business_capability.dart`, key `'mobileShop'`): product add/name/salePrice/stockQty/unit/tax/category; inventory list/visibleStock/search; invoice list/search/create; `useLowStockAlert`, `useDailySnapshot`, `useRevenueOverview`; `usePurchaseOrder`, `useStockEntry`, `useSupplierBill`; specialized **`useIMEI`, `useWarranty`, `useBuyback`, `useExchange`, `useJobSheets`, `useRepairStatus`, `useStockManagement`, `useBarcodeScanner`**.
**Notably NOT granted** (compare electronics/computerShop): `useScanOCR` (electronics has it; mobileShop lost it — see §3), `useSalesReturn`, `useGeneralAlerts`, `useProformaInvoice`, `useDispatchNote`, `useStockReversal`, `usePurchaseRegister`, `useInventoryExport`, `useDeadStock`, `useBatchExpiry`, `useMultiUnit` (computerShop has it), `useCreditManagement`/`useCreditLimit`, `useLoyaltyPoints`.

**Capability resolution is strict-deny:** `core/isolation/feature_resolver.dart canAccess()` returns `false` for any capability not explicitly in the set; `_normalizeType` maps `'mobileshop' → 'mobileShop'`. Consequence: the only capability-gated retail sidebar item, `batch_tracking` (gated by `useBatchExpiry`), is **filtered out for mobileShop** (it lacks `useBatchExpiry`).

**Two capability layers exist and can disagree:** `core/config/business_capabilities.dart` (`BusinessCapabilities.get`) derives dashboard flags from the isolation resolver. Key derived flags for mobileShop: `supportsSerialNumber = useIMEI = true`, `supportsStock = true`, `supportsTextOCR = useScanOCR = false`, `supportsExpiry = false`. `ocrFocus` for mobileShop is hard-coded to `'Name, Model, Serial/IMEI'` even though `useScanOCR` is **denied** — a stated OCR focus with no OCR capability (§3, §13).

**Architectural note (critical — same pattern as other audits):** the live app uses the **legacy `MaterialApp.routes` map**, not GoRouter:
- **Live:** `app/app.dart` → `MaterialApp(routes: buildAppRoutes(), onUnknownRoute: unknownRouteBuilder)`. Inside the desktop shell, screens are resolved by `content_host.dart _buildScreen()` → `SidebarNavigationHandler.getScreenForItem(screen.id, context)`.
- **Parallel (NOT mounted):** `MobileShopModule` (`modules/mobile_shop/mobile_shop_module.dart`) exposes GoRouter `routes => mobileShopRoutes` and 6 `navItems` (Billing, Scan Bill, IMEI Track, Repair, Exchange, EMI). Because the app never builds `MaterialApp.router`, **the entire mobile-shop module nav and its GoRouter routes are orphaned** (§6).

---

## 2. Missing Generic (Vyapar Benchmark) Features

| # | Benchmark | Status for mobileShop | Evidence | Priority |
|---|-----------|------------------------|----------|----------|
| 1 | Billing/Invoicing | **Partial** — `new_sale` → `BillCreationScreenV2`. Bill UI renders Serial/IMEI + warranty columns via `BillFieldConfig.forBusinessType` (`config.hasField(ItemField.serialNo)` → true). | `bill_line_item_row.dart`; `bill_creation_screen_v2.dart` | High |
| 2 | Inventory (real-time, low-stock, batch/expiry, FIFO, multi-warehouse, reorder, BOM) | **Generic only** — `stock_summary`/`item_stock`/`low_stock`/`stock_valuation`/`damage_logs` → generic inventory screens. No per-IMEI unit tracking surfaced; no new-vs-used segregation. | nav handler | High |
| 3 | Barcode/POS | **Partial** — `useBarcodeScanner` granted, but the dashboard "IMEI Lookup" quick action has an **empty `onTap: () {}`** (dead). No dedicated POS counter or IMEI-scan-to-bill surfaced. | `business_quick_actions.dart` (mobileShop case) | High |
| 4 | Accounting | **Inherited generic** — `accounting_reports`, `income_statement`, `invoice_margin`, `daybook`. | sidebar | Low |
| 5 | Receivables/Payables | **Inherited generic** — `party_ledger`, `outstanding`, `credit_notes`. `useCreditManagement`/`useCreditLimit` **not granted** (no EMI/udhaar logic). | capability registry | Medium |
| 6 | Bank/Cash | **Inherited generic** — `bank_accounts`, `cash_bank`. | nav handler | Low |
| 7 | Orders/Delivery | **Partial generic** — `booking_orders`, `dispatch_notes`. No mobile-specific reservation/booking of a specific IMEI unit. | sidebar | Medium |
| 8 | OCR | **Denied** — `useScanOCR` NOT in mobileShop set, so any OCR-gated entry is strict-denied, yet `ocrFocus='Name, Model, Serial/IMEI'` implies it exists. Contradiction. | `business_capability.dart`; `business_capabilities.dart _getOcrFocus` | Medium |
| 9 | Reports (37+) | **Generic** — `analytics_hub`, `turnover_analysis`, `product_performance`, `margin_analysis`, `gstr1`, etc. No IMEI-wise / brand-wise / repair-revenue / exchange-margin reports. Several BI ids are placeholder remaps (§6). | nav handler | Medium |
| 10 | Multi-user RBAC + audit | **Weak** — retail sidebar items carry **no `permission`** (only one `capability`), so RBAC does not gate them (§11). `audit_trail`/`activity_logs` both remap to `AllTransactionsScreen`. | sidebar config; nav handler | High |
| 11 | Multi-firm | **Partial/unverified** — service screens read user id but via two different sources (`AuthService().currentUser` vs `FirebaseAuth.instance`); per-tenant `userId` scoping in those screens present, broader scoping **unverified**. | `service_job_list_screen.dart`; `exchange_list_screen.dart` | Medium |
| 12 | Backup | **Inherited** — `backup` → `BackupScreen`; `sync_status` also → `BackupScreen`. Encryption **unverified**. | nav handler | Low |
| 13 | Online store | **Generic** — `catalogue` → `CatalogueScreen`. No mobile-model catalog specifics. | nav handler | Medium |
| 14 | e-Way bill | **Missing** — no e-Way screen found (grep); only GSTR-1/HSN. | grep | Low |
| 15 | Loyalty/discount | **Missing** — `useLoyaltyPoints` not granted; no combo/accessory-bundle engine. | capability registry | Medium |
| 16 | Service-business | **Built but partially reachable** — full service-job + exchange + warranty-claim + IMEI backend exists (`features/service/*`), reachable only via dashboard quick actions, NOT the sidebar (§3, §6). | `features/service/*`; nav handler | High |
| 17 | Offline-first sync | **Partial/unverified** — service/exchange screens use Drift via services (`ServiceJobService`, `ExchangeService` over `AppDatabase`), so they read local DB. `MobileShopSyncHandler`/`MobileShopWsHandler` are registered through the **unmounted** module system; live effect **unverified**. | `service_job_list_screen.dart`; `mobile_shop_module.dart` | Medium |

---

## 3. Missing Industry-Specific Features (Mobile Shop)

| Feature | Status | Evidence | Priority |
|---------|--------|----------|----------|
| IMEI capture (required) & per-unit tracking | **Partially built, validation un-wired** — `IMEISerial` model + `IMEISerialRepository` + `IMEIValidationService` exist; `bills_repository.dart` calls `imeiValidationService!.validateBillItems()` and `markIMEIsAsSold()` — but the service is **never injected** (see §7/§8). Bill UI captures `serialNo` but does **not enforce** it as required (manual entry uses `hasField`, not `isRequired`). | `imei_validation_service.dart`; `bills_repository.dart`; `service_locator.dart`; `manual_item_entry_sheet.dart` | **Critical** |
| IMEI uniqueness / duplicate-sale prevention | **Dead at runtime** — logic exists (`getByNumber`, status checks for sold/inService/damaged) but unreachable because `imeiValidationService == null` (§7). | `imei_validation_service.dart`; `service_locator.dart` | **Critical** |
| New vs second-hand/used phone inventory | **Missing UI** — config declares module `'second_hand'` but there is **no second-hand sidebar entry and no second-hand inventory screen** (grep). `useBuyback` is granted but only `ExchangeListScreen` (trade-in) exists. | `business_type_config.dart`; sidebar; grep | High |
| Buyback / exchange valuation | **Built, reachable only via quick action** — `ExchangeListScreen`/`CreateExchangeScreen`/`ExchangeService` exist and use real Drift stats (`getExchangeStats`). Reached only via dashboard "Exchange" quick action (`AppScreen.exchanges`), not the sidebar. | `exchange_list_screen.dart`; `business_quick_actions.dart` | Medium |
| Repair/service job sheets (device, fault, estimate, status, technician) | **Built, reachable only via quick action** — `ServiceJobListScreen` (tabs Active/Completed/All, status cards from `getJobCounts`, warranty badge, overdue logic) + `CreateServiceJobScreen` + `ServiceJobService`. Reached only via "New Repair" quick action (`AppScreen.serviceJobs`); not in sidebar. | `service_job_list_screen.dart`; `business_quick_actions.dart` | High |
| Warranty registration & claims | **Built but BLOCKED for mobileShop** — `WarrantyClaimService` (full lifecycle) exists; the warranty UI `WarrantyScreen` lives in `features/computer_shop/` and its route `/computer-shop/warranty` is `BusinessGuard(allowedTypes: [computerShop])` — **mobileShop is denied** despite holding `useWarranty`. No mobile-reachable warranty screen. | `warranty_claim_service.dart`; `app/routes.dart` (`/computer-shop/warranty`); `business_capability.dart` | **Critical** |
| IMEI / serial history lookup | **Built but BLOCKED for mobileShop** — `SerialHistoryScreen` (computer_shop) route `/computer-shop/serial-history` is `BusinessGuard([computerShop])` only. mobileShop holds `useIMEI` but cannot reach it. The "IMEI Lookup" dashboard button is a dead `() {}`. | `app/routes.dart`; `business_quick_actions.dart` | High |
| EMI / finance | **Missing** — module navItem `mobile_emi` → `/mobile/emi` is a `LegacyRouteRedirect` to `/payment-history` (and the module is unmounted). No EMI plan/financier engine. `useCreditManagement` not granted. | `mobile_shop_routes.dart`; `mobile_shop_module.dart` | High |
| Accessory sales | **Generic** — accessories would be plain inventory items; no accessory category/attach-to-handset flow. | nav handler; config | Low |
| SIM / recharge | **Unverified / not found** — no recharge or SIM-activation screen located (grep). | grep | Low |
| Price-protection / MRP markdown | **Missing** — flat `defaultGstRate 18.0`, price label "MRP"; no price-protection logic. | config | Low |
| IMEI-validated returns | **Missing** — `useSalesReturn` not granted to mobileShop; generic `return_inwards` is not IMEI-aware. | capability registry; nav handler | Medium |
| Demo units | **Missing** — `IMEISerialStatus` enum has inStock/sold/inService/returned/damaged but no "demo" state. | `imei_serial.dart` (status enum referenced in `imei_validation_service.dart`) | Low |

---

## 4. Missing UI Components

| Component | Status | Evidence | Priority |
|---|---|---|---|
| Mandatory IMEI entry/validation in add-item & bill line | **Weak** — Serial/IMEI field shown (`showSerialNo`) and captured, but never enforced required and never validated for duplicates at the UI layer. | `bill_line_item_row.dart`; `manual_item_entry_sheet.dart` | **Critical** |
| Warranty registration screen reachable for mobileShop | **Blocked** — only exists as computerShop-guarded `WarrantyScreen`. | `app/routes.dart` | High |
| IMEI/serial history viewer reachable for mobileShop | **Blocked** — computerShop-guarded `SerialHistoryScreen`. | `app/routes.dart` | High |
| Second-hand / used-stock intake form | **Missing** — none found. | grep | High |
| Repair job sheet sidebar entry | **Missing** — `service_jobs` not in retail sidebar. | sidebar config | High |
| IMEI scanner button (functional) | **Dead** — "IMEI Lookup" quick action `onTap: () {}`. | `business_quick_actions.dart` | High |

---

## 5. Missing Widgets & Dashboard / KPI Cards

- **Dashboard host:** `content_host.dart` resolves `getScreenForItem(currentScreen.id)`; the V2 dashboard widgets below are the only mobileShop-specific surfaces.
- **`business_quick_actions.dart` (electronics/mobileShop/computerShop case):** renders common "New Sale" (if `caps.accessInvoiceCreate`), then **"New Repair"** → `nav.navigateTo(AppScreen.serviceJobs)`, **"IMEI Lookup"** (if `caps.supportsSerialNumber`) → **empty `onTap: () {}`**, and for mobileShop only **"Exchange"** → `nav.navigateTo(AppScreen.exchanges)`, then common "Alerts".
  - Issues: (a) **dead "IMEI Lookup"** button; (b) no "Warranty", no "Buyback", no "Add Used Phone", no "New Sale w/ IMEI scan". **Priority: High.**
- **`business_alerts_widget.dart` (electronics/mobileShop/computerShop case):** title `"Warranty & Service Alerts"`; renders **hardcoded** cards: `"Warranty Expiring"` count **`'5'`** (if `caps.supportsSerialNumber`), `"Pending Repairs"` count **`'8'`**, and (mobileShop only) `"Exchange Requests"` count **`'3'`**. These are **static literals** — they do **not** read `alertCountsProvider` (the live Drift/UNS stream used by the grocery case for `lowStock`/`expiringSoon`), nor the **real** counts that `ServiceJobService.getJobCounts` / `ExchangeService.getExchangeStats` already compute. So the dashboard KPIs are fake while the actual screens have real numbers — an internal inconsistency. **Priority: High.** (§8)
- **Missing KPI cards:** active repairs by status (data exists in `getJobCounts`), exchange pipeline value (exists in `getExchangeStats` `totalExchangeValue`), IMEI-in-stock vs sold, warranty claims open/approved — none surfaced on the dashboard.

---

## 6. Navigation & Route Gaps

**A. Every retail sidebar id → resolution (`SidebarNavigationHandler.getScreenForItem`):** all ~60 ids have a `case` — **none fall to `_PlaceholderScreen`** (no hard dead links). Many are reuse/placeholder remaps, identical to the clothing/electronics audits:

| Sidebar id | Resolves to | Note |
|---|---|---|
| `turnover_analysis`, `daily_activity`, `ledger_history`, `activity_logs`, `audit_trail`, `transaction_reports` | `AllTransactionsScreen` | shared; `audit_trail` is just all-transactions, not a real audit log |
| `invoice_margin` + `income_statement` | `PnlScreen` | both → P&L |
| `funds_flow` + `cash_bank` | `CashflowScreen` | both → cashflow |
| `suppliers` / `outstanding` | `PartyLedgerListScreen(initialFilter:'supplier'|'receivable')` | reuse |
| `purchase_register` | `ProcurementLogScreen` | reuse |
| `sync_status` | `BackupScreen` | reuse |
| `print_settings` + `doc_templates` | `PrintMenuScreen` | both → same |
| `gstr1`/`b2b_b2c`/`hsn_reports`/`tax_liability`/`filing_status` | `GstReportsScreen(initialIndex:n)` | tabbed reuse |

None are mobile-aware.

**B. `batch_tracking` hidden for mobileShop (capability mismatch).** Gated by `useBatchExpiry`, which mobileShop lacks → filtered out by `sidebarSectionsProvider`. (Likely intentional; mobiles don't have expiry, but the item label "Batch / Variant Tracking" is also where per-IMEI lot tracking might belong — none provided instead.) **Priority: Low.**

**C. Mobile-specific screens that ARE reachable (via dashboard quick actions only, not sidebar):**

| Screen | Reached via | Mechanism | Evidence |
|---|---|---|---|
| `ServiceJobListScreen` | "New Repair" quick action | `navigateTo(AppScreen.serviceJobs)` → `content_host` → `getScreenForItem('service_jobs')` | `business_quick_actions.dart`; `sidebar_navigation_handler.dart` (`case 'service_jobs'`) |
| `ExchangeListScreen` | "Exchange" quick action | `navigateTo(AppScreen.exchanges)` → `getScreenForItem('exchanges')` | same |

> These bypass the named-route `BusinessGuard`/`VendorRoleGuard` entirely because `content_host` renders the widget directly. So the repair/exchange screens are reachable but **only if the user finds the dashboard quick action** — they are absent from the sidebar (poor discoverability). **Priority: High.**

**D. Mobile-specific screens that are ORPHANED or BLOCKED for mobileShop:**

| Screen / route | Wiring | mobileShop reachability | Evidence |
|---|---|---|---|
| `WarrantyScreen` (`/computer-shop/warranty`) | `BusinessGuard(allowedTypes:[computerShop])` | **BLOCKED** — denial message "Only Computer Shop businesses can access Warranty." despite mobileShop holding `useWarranty`. | `app/routes.dart` |
| `SerialHistoryScreen` (`/computer-shop/serial-history`) | `BusinessGuard([computerShop])` | **BLOCKED** for mobileShop despite `useIMEI`. | `app/routes.dart` |
| `JobCardDetailScreen` (`/computer-shop/job-card/...`) | `BusinessGuard([computerShop])` | **BLOCKED** for mobileShop. | `app/routes.dart` |
| `MultiUnitScreen` (`/computer-shop/multi-unit`) | `BusinessGuard([computerShop])` | Blocked (mobileShop also lacks `useMultiUnit`). | `app/routes.dart` |
| `MobileShopModule.navItems` (Billing, Scan Bill, IMEI Track, Repair, Exchange, EMI) | `module_registry.buildNavItems()` (GoRouter) | **Orphaned** — app uses `MaterialApp.routes`, no shell consumes module nav items. | `mobile_shop_module.dart`; `app/app.dart` |
| `mobileShopRoutes` (`/mobile/billing`,`/mobile/imei`,`/mobile/repair`,`/mobile/exchange`,`/mobile/emi`) | GoRouter, all `LegacyRouteRedirect` stubs | **Orphaned + stubbed** — redirect to `/billing_flow`, `/inventory`, `/job/status`, `/exchanges`, `/payment-history`. | `mobile_shop_routes.dart` |

**E. `/job/*` named routes:** `/job/create`, `/job/status`, `/job/deliver` use `BusinessGuard(allowedTypes:[mobileShop, computerShop, service, electronics])` + `Permissions.manageStaff`. These DO allow mobileShop, but **no mobileShop UI navigates to them** (the only paths in are the dashboard quick actions, which use `AppScreen.serviceJobs`/`exchanges`, not these named routes). So the guards are correct but the entry points are missing from the sidebar. **Priority: Medium.**

**F. `/service_jobs` and `/exchanges` named routes** are guarded by `VendorRoleGuard(Permissions.manageStaff)` **without** a `BusinessGuard` — so any business type with that permission could open them by route; but again no sidebar link exists. **Priority: Low (consistency).**

**G. Capability-vs-sidebar mismatch summary:** mobileShop holds `useIMEI, useWarranty, useBuyback, useExchange, useJobSheets, useRepairStatus` — **none** of these have a corresponding sidebar item in `_getRetailSections()`. The capabilities are granted but undiscoverable. **Priority: High.**

---

## 7. Backend Integration Gaps

- **IMEI validation service not injected (runtime no-op):** `core/di/service_locator.dart` registers `BillsRepository(...)` **without** `imeiValidationService:` (and without `dayBookService:`). The constructor field is nullable (`bills_repository.dart` line ~61), so `imeiValidationService == null`, and both guarded blocks (`validateBillItems` pre-save, `markIMEIsAsSold` post-save) are **skipped**. IMEI duplicate-prevention, auto-registration, and mark-as-sold never run for mobileShop. **Priority: Critical.** Evidence: `service_locator.dart` (lines 435–448) vs `bills_repository.dart` (lines 217–222, 464–469).
- **Second, parallel IMEI check is also dead:** `features/billing/services/billing_service.dart` gates on `businessType == 'electronics' || businessType == 'mobile_shop'` — but the enum `name` is `mobileShop` (camelCase), so the string `'mobile_shop'` **never matches**; and the block body is only a comment `// Strict 1:1 validation could go here`. **Priority: High.**
- Service/exchange/warranty repositories (`features/service/data/repositories/*`) operate over `AppDatabase` (Drift) directly; their sync/backend reconciliation is handled by the **unmounted** `MobileShopSyncHandler`/`MobileShopWsHandler`, so live server sync of repair/exchange/IMEI data is **unverified/likely inactive**. **Priority: Medium.**

---

## 8. Database & API Issues (real vs mock; hardcoded counts)

- **Hardcoded dashboard alert counts (mock):** `business_alerts_widget.dart` mobileShop branch emits literals `'5'` (Warranty Expiring), `'8'` (Pending Repairs), `'3'` (Exchange Requests). They ignore the real `alertCountsProvider` stream AND the real `ServiceJobService.getJobCounts` / `ExchangeService.getExchangeStats`. **Mock data shown as live KPIs.** **Priority: High.**
- **IMEI persistence path dead:** because `imeiValidationService` is null, `IMEISerial` rows are never auto-created/marked on sale (§7). The `IMEISerials` table can silently go unpopulated for mobileShop. **Priority: Critical.**
- **Real data does exist** in the repair/exchange screens: `getJobCounts` (Drift) and `getExchangeStats` (Drift) — confirming the dashboard's hardcoding is gratuitous. **Priority: (informational).**
- **Inconsistent auth/user-id source:** `ServiceJobListScreen` uses `AuthService().currentUser?.uid`; `ExchangeListScreen` uses `FirebaseAuth.instance.currentUser?.uid` (`core/compat/firebase_auth_compat.dart`). Divergent identity sources for sibling screens in the same module. **Priority: Medium.**

---

## 9. Responsive Design

- `ServiceJobListScreen`: wraps body in `BoundedBox(maxWidth: 800)` and uses `responsiveValue<double>(...)` for font sizes (good), but uses hardcoded `Colors.grey[400/500/600/700]` and theme-mixed styling. Acceptable but not fully theme-aware. **Priority: Low.**
- `ExchangeListScreen`: theme-aware via `isDark` (gradients adapt), `BoundedBox(maxWidth: 800)`, `responsiveValue` font sizes — but heavy use of hardcoded gradient hex colors (`0xFF6366F1`, etc.) regardless of app theme tokens. **Priority: Low.**
- The generic retail sidebar/screens responsiveness is inherited (not mobileShop-specific). **Priority: (n/a).**

---

## 10. Performance

- `ServiceJobListScreen._buildJobList` applies search/status filters by re-running `.where(...)` over the full job list on **every** `onChanged` keystroke (`setState(_searchQuery)`); for large job lists this is O(n) per keystroke with no debounce. Backed by `StreamBuilder` so it also rebuilds on stream ticks. **Priority: Low/Medium.**
- `ExchangeListScreen` filters the full exchange list per tab inside `StreamBuilder` (`watchExchanges` then `.where(status)`), recomputed on each build. **Priority: Low.**
- `content_host.dart` caches built screens (`_screenCache`) and clears on business-type change — good; no obvious perf issue for mobileShop. **Priority: (informational).**

---

## 11. Security (RBAC, capability-bypass)

- **Capability-bypass on un-gated sidebar items:** in `_getRetailSections()`, **only** `batch_tracking` carries a `capability` and **no item carries a `permission`**. `sidebarSectionsProvider` only filters when `capability`/`permission` is set. So for mobileShop, sensitive items — `audit_trail`, `bank_accounts`, `accounting_reports`, `gstr1`/tax, `expenses`, `credit_notes`, `backup` — are shown to **every role** with no RBAC gate. **Priority: High.** Recommendation: attach `permission:` (e.g., `viewReports`, `manageSettings`) to financial/compliance/admin items.
- **Content-host bypass of route guards:** repair/exchange screens are rendered by `content_host` via `getScreenForItem('service_jobs'|'exchanges')` **without** the `VendorRoleGuard(manageStaff)` that wraps the equivalent named routes (`/service_jobs`, `/exchanges`). So the permission intended for those screens is **not enforced** on the in-shell path. **Priority: Medium/High.**
- **Wrong/odd permission for repair workflows:** `/job/*` and `/service_jobs`/`/exchanges` require `Permissions.manageStaff` — a staff-management permission gating repair/exchange operations (likely should be an operations/invoice permission). **Priority: Medium.**
- **Capability granted but no enforcement at data layer for IMEI:** `useIMEI`/`useWarranty` are granted but the IMEI enforcement service is unwired (§7), so the "hard isolation" intent (`FeatureResolver.enforceAccess`) is not actually exercised on the billing path for IMEI. **Priority: Medium.**
- **Strict-deny engine is correct** (`feature_resolver.dart canAccess` defaults false; `_normalizeType` handles `mobileshop`). **Priority: (informational).**

---

## 12. Offline Mode Gaps

- Repair (`ServiceJobService`) and exchange (`ExchangeService`) screens read from `AppDatabase` (Drift) → work offline for reads/writes locally. **Good.**
- IMEI table population depends on the **un-wired** `IMEIValidationService` (§7), so offline IMEI state is never recorded regardless of connectivity. **Priority: Critical (data, not just offline).**
- `MobileShopSyncHandler`/`MobileShopWsHandler` are registered via the unmounted module system; their contribution to offline-first reconciliation is **unverified/likely inactive**. **Priority: Medium (verify).**

---

## 13. Business Logic Inconsistencies

- **`modules` config vs actual sidebar:** config says mobileShop has `'repairs'` and `'second_hand'` modules; the rendered sidebar (`_getRetailSections`) exposes **neither**. The `service` business type (which has `_getServiceSections` with repair/exchange entries) is the only one that surfaces them. Misalignment between declared modules and UI. **Priority: High.**
- **OCR focus without OCR capability:** `_getOcrFocus(mobileShop) = 'Name, Model, Serial/IMEI'` but `useScanOCR` is denied → a configured focus for a disabled feature. **Priority: Medium.**
- **mobileShop vs electronics divergence:** electronics has `useScanOCR`; mobileShop (the more scan-centric vertical) does not. Likely an oversight. **Priority: Medium.**
- **Warranty/serial UI tied to the wrong vertical:** the only built warranty/serial UIs live under `features/computer_shop` and are `BusinessGuard`-restricted to computerShop, even though mobileShop has the matching capabilities and arguably greater need. **Priority: High.**
- **IMEI type guess heuristic:** `_guessIMEIType` treats any 15-digit numeric string as IMEI; no Luhn checksum (IMEI uses Luhn). **Priority: Medium** (see §14).

---

## 14. Data Validation Issues (IMEI uniqueness/format, warranty dates)

- **IMEI not enforced required in UI:** config marks `serialNo` required for mobileShop, but `manual_item_entry_sheet.dart` captures `_serialController.text.trim()` with **no non-empty guard**; `bill_line_item_row.dart` uses `hasField` (visibility) not `isRequired`. The only "required" check lives in the **un-wired** `IMEIValidationService` (`'IMEI/Serial required for: ...'` when `businessType.contains('mobile')`). **Net: empty IMEI can pass.** **Priority: Critical.**
- **No IMEI format/Luhn validation:** `_guessIMEIType` only checks length 15 + numeric; accepts non-Luhn-valid 15-digit strings as IMEI and anything else as "serial". **Priority: Medium.**
- **Uniqueness check exists but unreachable:** `IMEISerialRepository.getByNumber` + status switch (sold/inService/damaged → error) implement duplicate prevention, but the service is not injected (§7). **Priority: Critical.**
- **Warranty date math:** `markIMEIsAsSold` computes `warrantyEndDate = DateTime(now.year, now.month + warrantyMonths, now.day)`. Dart normalizes month overflow, but day-of-month edge cases (e.g., sold on the 31st + N months landing on a 30-day month) roll into the next month. Minor. **Priority: Low.** (Also moot until the service is wired.)
- Warranty months input in manual entry: `int.tryParse(_warrantyController.text)` with no range/negative guard. **Priority: Low.**

---

## 15. UX Problems

- **Discoverability ≈ zero** for mobile-specific tools: repairs and exchange are only on dashboard quick actions; warranty and IMEI history are blocked entirely; second-hand intake doesn't exist. A mobile merchant effectively sees a generic retail app. **Priority: High.**
- **Dead "IMEI Lookup" button** (`onTap: () {}`) — visible, looks functional, does nothing. **Priority: High.**
- **Fake, unchanging alert counts** ("Warranty Expiring 5", "Pending Repairs 8", "Exchange Requests 3") erode trust and contradict the real numbers shown inside the repair/exchange screens. **Priority: High.**
- **Inconsistent screen styling** between `ServiceJobListScreen` (light, AppBar-based) and `ExchangeListScreen` (dark-gradient, custom header) within the same workflow family. **Priority: Low.**

---

## 16. Accessibility

- Service/exchange cards rely on color + icon for status (status chips, warranty badge) with text labels present (good), but custom tap targets (`GestureDetector` on exchange cards, status cards with empty `onTap`) lack `Semantics`/tooltips. **Priority: Low.**
- The dead "IMEI Lookup" action provides no disabled/aria state. **Priority: Low.**
- Hardcoded low-contrast greys in `ServiceJobListScreen` (e.g., `Colors.grey[500]` on light bg) may fail WCAG contrast; **full WCAG validation requires manual testing with assistive tech and is not performed here.** **Priority: Low (verify).**

---

## 17. Bugs / Errors / Crash Scenarios

- **Silent IMEI loss bug (data integrity):** sales of mobiles never record IMEIs (service un-injected, §7) — duplicate IMEIs can be billed, no warranty linkage created. **Priority: Critical.**
- **`billing_service.dart` IMEI branch never executes** for mobileShop due to `'mobile_shop'` vs `mobileShop` string mismatch; even if it did, it's a no-op comment. Dead branch — no crash, but misleading. **Priority: High.**
- **Guard denial dead-ends:** if any code path (or a future sidebar link) routes mobileShop to `/computer-shop/warranty` or `/computer-shop/serial-history`, the user hits a `BusinessGuard` denial screen ("Only Computer Shop businesses…"). Confusing for a feature the vertical is supposed to have. **Priority: Medium.**
- `ExchangeListScreen` reads `FirebaseAuth.instance.currentUser?.uid`; if the compat shim returns null (no session), `_userId` stays null and the list shows a perpetual spinner (no error state). **Priority: Low/Medium.**
- Status card `onTap` in `ServiceJobListScreen` is an empty closure (`// Filter by this status`) — non-functional but harmless. **Priority: Low.**

---

## 18. Unnecessary / Irrelevant Features Shown (flag shared retail sidebar)

- mobileShop renders the **full generic retail sidebar** (`_getRetailSections`), including items of little/no relevance to a phone shop: `batch_tracking` (filtered out anyway), `proforma_bids`, `dispatch_notes`, `booking_orders`, `stock_reversal`, `procurement_insights`, `b2b_b2c`, `filing_status`, `credit_notes`, etc. Many are also not backed by mobileShop capabilities (e.g., `useProformaInvoice`, `useDispatchNote`, `useSalesReturn` not granted) yet are shown because the items carry no capability tag. **Priority: High** (clutter + capability/UI mismatch).
- Conversely, the genuinely relevant `service_jobs`/`exchanges` (present in `_getServiceSections`) are **withheld** from mobileShop. The sidebar is simultaneously **over-broad** (irrelevant retail items) and **under-specific** (no mobile tools). **Priority: High.**

---

## 19. Recommendations & Prioritized Implementation Plan

**Critical (data integrity / core promise):**
1. **Wire `IMEIValidationService` into `BillsRepository`** in `service_locator.dart` (pass `imeiValidationService: IMEIValidationService(sl<AppDatabase>())`). This activates duplicate-prevention, auto-registration, and mark-as-sold. Verify `IMEISerials` is populated after a mobile sale.
2. **Enforce IMEI as required in the bill/add-item UI** for mobileShop using `config.isRequired(ItemField.serialNo)` (not just `hasField`); block save on empty/duplicate IMEI. Add Luhn validation in `_guessIMEIType`/a validator.
3. **Unblock warranty & serial-history for mobileShop**: change `/computer-shop/warranty` and `/computer-shop/serial-history` `BusinessGuard` to include `BusinessType.mobileShop` (or move these screens to a shared `features/device_service/` reachable by all device verticals).

**High:**
4. **Add a dedicated mobile sidebar section** (or reuse `_getServiceSections` content for mobileShop) exposing: Service Jobs (`service_jobs`), Exchanges (`exchanges`), IMEI Tracking, Warranty, Second-Hand Intake. Tag each with the matching capability (`useJobSheets`, `useExchange`, `useIMEI`, `useWarranty`).
5. **Fix the dead "IMEI Lookup" quick action** (wire to serial-history) and **replace hardcoded dashboard counts** with `ServiceJobService.getJobCounts` / `ExchangeService.getExchangeStats` / `alertCountsProvider`.
6. **Build second-hand/used inventory** intake + valuation (config already declares `'second_hand'`); add a "demo" `IMEISerialStatus`.
7. **Attach RBAC `permission:`** to financial/compliance/admin sidebar items; enforce the repair/exchange permission on the `content_host` path, not just named routes.
8. **Fix `billing_service.dart`** string check (`'mobileShop'`, via `BusinessType.mobileShop.name`) and implement or remove the empty IMEI branch.

**Medium:**
9. Grant `useScanOCR` to mobileShop (align with electronics) or remove the misleading `ocrFocus`.
10. Add EMI/finance support (capability + screen) instead of the `/mobile/emi → /payment-history` stub.
11. Unify auth/user-id source across service screens; add empty/error states for null sessions.
12. Add IMEI-validated returns (grant `useSalesReturn` or a device-specific return flow).

**Low:**
13. Debounce search in service/exchange lists; standardize screen theming; add `Semantics` to custom tap targets; range-guard warranty months.

---

## 20. Confidence & Coverage

- **High confidence (read in full / near-full):** sidebar resolution for mobileShop (`_getRetailSections`), config block, capability set, both capability layers, dashboard quick-actions & alerts mobileShop branches, mobile_shop module + routes (stubs), service-job & exchange list screens, IMEI validation service, `BillsRepository` IMEI hooks + its DI registration (un-injected), bill line-item/manual-entry IMEI handling, app router wiring, and the computer-shop guard restrictions in `app/routes.dart`.
- **Medium confidence (grep / listing, not opened in full):** service models & repositories internals (`service_job`, `exchange`, `imei_serial`, `warranty_claim`), `warranty_claim_service.dart` lifecycle (skimmed), computer_shop screen internals, module sync/ws handlers, `session_manager.dart` RBAC matrix.
- **Unverified (explicitly flagged in-line):** live server sync of repair/exchange/IMEI data; multi-firm scoping beyond the userId reads observed; WCAG contrast; presence of SIM/recharge; backup encryption; exact behavior of `BillCreationScreenV2` IMEI required-field enforcement at submit time (only manual-entry sheet path confirmed).
- **Skipped (out of scope):** backend endpoint implementations; the full ~60-item retail screen internals beyond resolution mapping; non-mobileShop business branches except where compared (electronics/computerShop/service).

**Net assessment:** mobileShop is configured and capability-granted as a specialized vertical (IMEI required, repairs, exchange, warranty, buyback), and a substantial real backend exists (`features/service/*`), but the **live wiring is broken or generic**: the sidebar is shared generic-retail with no mobile tools, the two most important data guarantees (IMEI validation + warranty UI) are respectively **un-injected** and **guarded to computerShop only**, dashboard KPIs are hardcoded, and the dedicated mobile module is orphaned. The fixes are mostly wiring/guards/sidebar, not new architecture.
