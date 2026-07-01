# DukanX Business-Type Audit — Hardware Store

READ-ONLY, evidence-based audit of the **Hardware Store** (`BusinessType.hardware`) vertical.
No source files were modified. Every claim cites the file/function checked. Items I could not
confirm are explicitly marked **unverified**.

Audit date: 2026-05 · Auditor: automated code audit (single-vertical pass)

---

## What was sampled vs skipped

**Sampled (read in full or in relevant part):**
- `Dukan_x/lib/models/business_type.dart`
- `Dukan_x/lib/core/billing/business_type_config.dart` (hardware config + registry)
- `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart` (`_getSectionsForBusiness`, `_getRetailSections`)
- `Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart` (`getScreenForItem`)
- `Dukan_x/lib/widgets/desktop/content_host.dart` (`_initScreenBuilders`, `_buildScreen`)
- `Dukan_x/lib/core/navigation/app_screens.dart`, `navigation_controller.dart`
- `Dukan_x/lib/features/dashboard/v2/widgets/business_quick_actions.dart`
- `Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart`
- `Dukan_x/lib/core/isolation/business_capability.dart` (`hardware` set), `feature_resolver.dart`
- `Dukan_x/lib/core/config/business_capabilities.dart`
- `Dukan_x/lib/features/hardware/**` (all screens, repo, rules, dimension widget)
- `Dukan_x/lib/modules/hardware/**` (module, routes, sync, ws)
- `Dukan_x/lib/app/routes.dart` (hardware named routes), `core/module/*` (registry/loader)
- `Dukan_x/lib/models/estimate.dart`

**Skipped / not fully traced (flagged unverified where relevant):**
- Backend Lambda handlers for `/hardware/*` endpoints (only the Flutter client was read).
- `session_manager.dart` `RolePermissions` matrix internals (referenced but not line-audited).
- Runtime behavior (no app was run); all findings are static.
- Whether `HardwareBusinessRules` and `Estimate`/`EstimateItem` are invoked from any live UI flow.
- Accessibility/performance claims that require a running profiler or screen reader.

---

## 1. Header — Resolution, Config, Capabilities

**Sidebar resolution (CONFIRMED):** `sidebar_configuration.dart` → `_getSectionsForBusiness(BusinessType type)`
has **no `case BusinessType.hardware`**. Hardware falls through to `default: _getRetailSections();`.
So Hardware renders the **generic 10-section retail sidebar** (Dashboard & Control, Revenue Desk,
BuyFlow, Inventory & Stock, Parties & Ledger, Business Intelligence, Financial Reports,
Tax & Compliance, Operations & Logs, Utilities & System). There is **zero hardware-specific
sidebar content**.

**Config (CONFIRMED — `business_type_config.dart`, `BusinessType.hardware`):**
- requiredFields: `itemName, quantity, unit, price, gst`
- optionalFields: `brand, weight, dimensions, hsnCode, batchNo`
- defaultGstRate: `18.0`; gstEditable: `true`
- unitOptions: `pcs, kg, ft, mtr, box, nos`
- itemLabel: `Item`; addItemLabel: `Add Item`; priceLabel: `Rate`
- modules: `['inventory','sales','returns','quotations','reports']`

**Capabilities (CONFIRMED — `business_capability.dart` `'hardware'` set):**
Granted: all 7 product caps; `useInventoryList/useVisibleStock/useInventorySearch`;
`useInvoiceList/useInvoiceSearch/useInvoiceCreate`; `useLowStockAlert/useDailySnapshot/useRevenueOverview`;
`usePurchaseOrder/useStockEntry/useSupplierBill`; specialized `useDimensions, useLooseQuantities,
useBarcodeScanner, useStockManagement, useTransportDetails`.
**NOT granted (notable):** `useDeadStock`, `useInventoryExport`, `useSalesReturn`,
`useProformaInvoice`, `useDispatchNote`, `useGeneralAlerts`, `useStockReversal`,
`usePurchaseRegister`, `useCreditLimit`, `useCreditManagement`, `useMultiUnit`,
`useScanOCR`, `useBatchExpiry`.

**Headline problem:** the config/capabilities describe a hardware vertical (dimensions, quotations,
transport), and a full `features/hardware/` + `modules/hardware/` codebase exists — but **none of it
is wired into the live navigation**. The user gets the plain retail shell, and the two hardware
dashboard shortcuts that do exist are dead. Details below.

---

## 2. Missing Generic Features (vs Vyapar benchmark)

| # | Vyapar feature | Status for hardware | Evidence |
|---|----------------|---------------------|----------|
| 4 | Accounting (full) | Partial — `accounting_reports` reuses `BillingReportsScreen` placeholder | `content_host.dart` maps `AppScreen.accountingReports → BillingReportsScreen()` "// Placeholder" |
| 5 | Receivables/Payables | Sidebar has `outstanding`, `party_ledger`; but **no credit-limit capability** for hardware | `business_capability.dart` hardware set lacks `useCreditLimit`/`useCreditManagement` |
| 6 | Bank/Cash | `bank_accounts`, `cash_bank` resolve (BankScreen/CashflowScreen) | `sidebar_navigation_handler.dart` |
| 8 | OCR / scan-bill | **Not available** — hardware lacks `useScanOCR`; `supportsTextOCR=false` | `business_capability.dart`; `business_capabilities.dart` derives `supportsTextOCR` from `useScanOCR` |
| 9 | Reports (37+) | Retail report set present but several are placeholders/aliases | `getScreenForItem`: `turnover_analysis`/`daily_activity`/`activity_logs`/`audit_trail` → `AllTransactionsScreen` |
| 13 | Online store | Not found for hardware | no reference in sampled files (unverified beyond sample) |
| 14 | e-Way bill | **Missing** — no capability/screen | no `eway`/`ewaybill` capability in `business_capability.dart` |
| 17 | Offline-first sync | Module sync handler exists but module unmounted (see §12) | `modules/hardware/sync/hardware_sync_handler.dart` |

Priority: **High** for e-Way bill (#14) and Sales Return (returns is even in the hardware
`modules` list yet `useSalesReturn` is not granted — see §13). **Medium** for OCR/scan-bill and
placeholder reports.

---

## 3. Missing Industry-Specific Features (Hardware)

Hardware shops need the items below. Status is based on capability + wiring evidence.

| Need | Code exists? | Wired/usable? | Evidence |
|------|--------------|---------------|----------|
| Multi-unit & unit conversion (box/pc/kg/ft/mtr) | Units listed in config | **No conversion** — `useMultiUnit` NOT granted to hardware (granted to wholesale/computerShop) | `business_type_config.dart` unitOptions; `business_capability.dart` |
| Quotation/Estimate → Invoice | `models/estimate.dart`, `core/services/estimate_service.dart`, `ProformaScreen` | Proforma screen reachable; estimate→invoice conversion path **unverified** | `estimate.dart`, `sidebar` `proforma_bids → ProformaScreen` |
| Project bidding / site projects | `HardwareOperationsScreen` (Projects/Indents/Deposits tabs) | **Built but unreachable** in shell (see §6) | `features/hardware/presentation/screens/hardware_operations_screen.dart` |
| Delivery challan / site dispatch | `DeliveryChallanListScreen` (route `/delivery_challans`) + `useTransportDetails` granted | Dashboard "Delivery Challan" action is a **dead link** (see §6) | `app/routes.dart`; `business_quick_actions.dart` |
| Weight/dimensions per item | `weight`,`dimensions` optional fields; `DimensionCalculator` widget; `HardwareBusinessRules.squareFeet/cubicFeet/cutToSizeCharge` | Widget + rules **orphaned** (no caller found) | `dimension_calculator.dart`, `hardware_business_rules.dart` |
| Loose-cut sales (pipe/cable cutting) | `useLooseQuantities` granted; `cutToSizeCharge()` ceil-bills | No UI caller found for `cutToSizeCharge` | `hardware_business_rules.dart` (unverified usage) |
| Contractor / B2B credit ledger | `HardwareCreditControlScreen` (route `/hardware/credit-control`) | **Built but unreachable** in shell; `useCreditLimit` NOT granted | `app/routes.dart`; `business_capability.dart` |
| Rate contracts / supplier rate compare | `HardwareOpsRepository.getRateComparison`, `HardwareSupplierManagementScreen` | Repo method real; screen **orphaned** (no route/sidebar) | `hardware_ops_repository.dart`; grep shows no reference to `HardwareSupplierManagementScreen` |
| Supplier-wise procurement | `usePurchaseOrder/useSupplierBill` granted; BuyFlow sidebar present | Usable (generic BuyFlow) | `_getRetailSections` BuyFlow section |
| Breakage/damage | `damage_logs → DamageLogsScreen` | Usable | `getScreenForItem` |
| Material-on-deposit (e.g., shuttering) | `HardwareOperationsScreen` Deposits tab + repo `listDeposits/createDeposit/settleDeposit` | Built but unreachable in shell | `hardware_operations_screen.dart`, `hardware_ops_repository.dart` |
| e-Way bill for bulk dispatch | none | Missing | no capability/screen found |
| Reorder points for fast-movers | `getFastSlowMoving`/`getDeadStock` repo methods exist | screen `HardwarePhase12WorkspaceScreen` **orphaned** | `hardware_ops_repository.dart`; `hardware_phase12_workspace_screen.dart` |

Priority: **Critical** — the single biggest gap is not missing code, it's that the hardware-specific
code that *was* written is not connected to the running navigation.

---

## 4. Missing UI Components

- **No hardware sidebar sections.** Because of `default: _getRetailSections()`
  (`sidebar_configuration.dart`), there are no entries for Projects, Indents, Deposits,
  Credit Control, Supplier Rate Compare, Estimates, or Dimension/Area calculator. Priority **High**.
- **Dimension/Area calculator not surfaced.** `DimensionCalculator`
  (`features/hardware/widgets/dimension_calculator.dart`) is a complete widget (presets, ft↔mtr
  conversion, validation) but has **no caller** (grep for `DimensionCalculator` returns only its own
  definition). It is not embedded in the bill-line item editor. Priority **High** (this is the
  marquee hardware UI and it's dark).
- **Estimate/quotation builder UI** is generic `ProformaScreen`, not hardware-aware (no
  dimension/brand/grade line fields surfaced). Priority **Medium** (unverified internals of ProformaScreen).

---

## 5. Missing Widgets & Dashboard/KPI Cards

- **Dashboard alert counts are hardcoded** (`business_alerts_widget.dart`, `case BusinessType.hardware`):
  - "Pending Quotes" → count `'7'`
  - "Active Projects" → count `'4'`
  - "Overdue Contractor Bills" → count `'3'` (gated by `caps.accessCreditLimit`)
  These are literal strings, not data. Title is `'Project & Quote Alerts'` (`_getTitle`). Priority **High**.
- **The "Overdue Contractor Bills" alert can never render** for hardware: it is wrapped in
  `if (caps.accessCreditLimit)`, but `business_capabilities.dart` derives `accessCreditLimit` from
  `BusinessCapability.useCreditLimit`, which is **not** in the hardware capability set. So the credit
  alert is dead code for hardware. Priority **Medium** (misleading; also contradicts the contractor-credit feature intent).
- **`alertCountsProvider` real data is unused by hardware.** The provider fetches real `lowStock`/
  `expiringSoon` counts from Drift (`business_alerts_widget.dart`), but the hardware branch ignores
  `counts` entirely and uses literals. So even the available real low-stock count isn't shown. Priority **High**.
- **No hardware KPI cards** (e.g., outstanding contractor credit, open indents, deposit liability,
  fast/slow movers) on the dashboard despite repository support (`getFastSlowMoving`, `listDeposits`).
  Priority **Medium**.

---

## 6. Navigation & Route Gaps

### 6a. Each retail sidebar id → does it resolve? (`getScreenForItem` in `sidebar_navigation_handler.dart`)
All ids in `_getRetailSections()` were cross-checked. Resolved (✓) unless noted:

- Dashboard: `executive_dashboard`✓, `live_health`✓, `alerts`✓, `daily_snapshot`✓
- Revenue: `revenue_overview`✓, `new_sale`✓, `receipt_entry`✓, `return_inwards`✓,
  `proforma_bids`✓, `booking_orders`✓, `dispatch_notes`✓, `sales_register`✓
- BuyFlow: `buyflow_dashboard`✓, `purchase_orders`✓, `stock_entry`✓, `stock_reversal`✓,
  `procurement_log`✓, `supplier_bills`✓, `purchase_register`✓ (**aliased** to `ProcurementLogScreen`)
- Inventory: `stock_summary`✓, `item_stock`✓, `batch_tracking`✓ (gated `useBatchExpiry` — **hidden for hardware**),
  `low_stock`✓, `stock_valuation`✓, `damage_logs`✓
- Parties: `customers`✓, `suppliers`✓ (PartyLedger filtered), `party_ledger`✓,
  `ledger_history`✓ (→`AllTransactionsScreen`), `ledger_abstract`✓ (→`TrialBalanceScreen`), `outstanding`✓
- BI: `analytics_hub`✓ (→`ReportsHubScreen`), `turnover_analysis`✓ (**→`AllTransactionsScreen` placeholder**),
  `product_performance`✓, `daily_activity`✓ (**→`AllTransactionsScreen`**), `procurement_insights`✓
  (→`PurchaseReportScreen`), `margin_analysis`✓ (→`BillWiseProfitScreen`), `insights`✓, `catalogue`✓
- Financial: `invoice_margin`✓ (→`PnlScreen`), `income_statement`✓ (→`PnlScreen`), `funds_flow`✓
  (→`CashflowScreen`), `financial_position`✓, `cash_bank`✓ (→`CashflowScreen`), `accounting_reports`✓,
  `bank_accounts`✓, `daybook`✓, `credit_notes`✓, `expenses`✓
- Tax: `gstr1`✓, `b2b_b2c`✓, `hsn_reports`✓, `tax_liability`✓, `filing_status`✓ (all → `GstReportsScreen` tabs)
- Operations: `transaction_reports`✓, `activity_logs`✓ (**→`AllTransactionsScreen`**), `audit_trail`✓
  (**→`AllTransactionsScreen`**), `error_logs`✓
- Utilities: `print_settings`✓, `doc_templates`✓ (**→`PrintMenuScreen`, same as print_settings**),
  `backup`✓, `sync_status`✓ (**→`BackupScreen` reuse**), `device_settings`✓

**Miscategorized / duplicate mappings (Medium):** `audit_trail`, `activity_logs`, `daily_activity`,
`turnover_analysis`, `ledger_history` all collapse onto `AllTransactionsScreen`; `doc_templates`==`print_settings`;
`sync_status`==`backup`. Multiple distinct menu entries open identical screens — confusing and a QA/trust risk.

### 6b. Orphaned hardware screens (built, NOT reachable from the running shell)
Verified via grep for each class across `Dukan_x/lib/**`:
- `HardwareCommandCenterScreen` (`.../screens/hardware_command_center_screen.dart`) — **no reference anywhere**. Orphaned. Priority **High**.
- `HardwareSupplierManagementScreen` (`.../hardware_supplier_management_screen.dart`) — **no reference**. Orphaned. Priority **High**.
- `HardwarePhase12WorkspaceScreen` (`.../hardware_phase12_workspace_screen.dart`) — referenced only by the
  `feature_plan_matrix.dart` plan key `'hardware_phase12'`; no route/sidebar/shell mounts it. Orphaned. Priority **High**.
- `DimensionCalculator` widget — orphaned (see §4).

### 6c. Dead links from the hardware dashboard (CRITICAL)
`business_quick_actions.dart` `case BusinessType.hardware` defines three actions; how the shell
resolves them (`content_host.dart` `_buildScreen` → `_screenBuilders` else `getScreenForItem(screen.id)`):
- **"New Quote"** → `nav.navigateTo(AppScreen.proformaBids)` → `_screenBuilders[AppScreen.proformaBids] = ProformaScreen()` → **works**.
- **"Delivery Challan"** → `nav.navigateTo(AppScreen.deliveryChallans)`. `AppScreen.deliveryChallans.id`
  resolves (via the default snake_case path in `app_screens.dart`) to `'delivery_challans'`. It is
  **absent from `_screenBuilders`** and **absent from `getScreenForItem`'s switch** → falls to
  `default: _buildPlaceholderScreen('Unknown Screen', ...)` → user sees **"Feature Not Found"**. **DEAD LINK.** Priority **Critical**.
- **"Projects"** → `nav.navigateTo(AppScreen.hardwareOperations)`. `id` = `'hardware_operations'`,
  **absent from both `_screenBuilders` and `getScreenForItem`** → **"Feature Not Found"**. **DEAD LINK.** Priority **Critical**.

Note the cruel irony: a fully-built `HardwareOperationsScreen` and a real `DeliveryChallanListScreen`
exist and are even wired to **named routes** in `app/routes.dart` (`/hardware/operations`,
`/delivery_challans`), but the desktop shell navigates by `AppScreen` enum through `content_host`,
not by named route — so those screens are never reached from the dashboard. This is a wiring mismatch
between `app/routes.dart` and `content_host.dart`/`sidebar_navigation_handler.dart`.

### 6d. Capability-vs-sidebar mismatches (un-gated items bypass hard isolation)
The retail sidebar items `proforma_bids`, `dispatch_notes`, `return_inwards` carry **no `capability`**
in `_getRetailSections()`, so they are always shown. But hardware's capability set does **not** include
`useProformaInvoice`, `useDispatchNote`, or `useSalesReturn`. Result: features the hard-isolation
registry intends to deny are nonetheless presented and reachable for hardware. Priority **High**
(see §11). Conversely `batch_tracking` *is* gated (`useBatchExpiry`) and correctly hidden for hardware.

---

## 7. Backend Integration Gaps

- `HardwareOpsRepository` (`features/hardware/data/hardware_ops_repository.dart`) calls **real REST
  endpoints** via `ApiClient`: `/customers`, `/inventory`, `/hardware/projects`, `/hardware/indents`,
  `/hardware/deposits`, `/hardware/purchase-orders`, `/hardware/sales-orders`,
  `/hardware/invoice-profiles`, `/hardware/rate-comparison`, `/hardware/reports/item-velocity`,
  `/hardware/reports/dead-stock`, plus `HardwareApiContract.*` endpoints. Error handling is solid
  (throws `HardwareOpsException` with status code instead of silently returning `[]`). **Good.**
- **Gap:** these calls are only made by orphaned/placeholder-blocked screens (§6b/§6c). The backend
  integration is effectively unreachable from the live UI. Priority **Critical** (wasted, untested in prod path).
- **Backend handler verification skipped** (only the Flutter client was read) — whether `/hardware/*`
  endpoints exist server-side is **unverified**.

---

## 8. Database & API Issues (real vs mock; hardcoded counts)

- **Hardcoded dashboard alert counts** (real issue): `business_alerts_widget.dart` hardware branch uses
  string literals `'7'`, `'4'`, `'3'` (see §5). Mock data shown as if live. Priority **High**.
- **Real DB path exists but unused for hardware:** `alertCountsProvider` queries `productBatches` and
  `getLowStockProducts` from Drift (`app_database.dart`, `products_repository.dart`), wired to the UNS
  notification stream — but hardware alerts ignore it. Priority **High**.
- **Deposit money handling uses integer cents** (`depositAmountCents`, `refundAmountCents`,
  `outstandingDepositCents`) in `hardware_ops_repository.dart`/`hardware_operations_screen.dart` —
  correct for currency. **Good.**
- **API response-shape tolerance:** `_extractItems` handles both `res.data['data'][key]` and
  `res.data[key]` and validates list type — robust. **Good.**

---

## 9. Responsive Design

- Hardware screens use the shared responsive helpers: `HardwareOperationsScreen` imports
  `core/responsive/responsive.dart`, uses `responsiveValue(...)` for dialog padding and `BoundedBox(maxWidth: 800)`.
  Other hardware screens (`hardware_credit_control_screen.dart`, `hardware_command_center_screen.dart`,
  `hardware_invoice_profile_screen.dart`, `hardware_supplier_management_screen.dart`,
  `hardware_phase12_workspace_screen.dart`) all import `responsive.dart`. Reasonable. Priority **Low**.
- `mobile_bottom_nav.dart` includes `proformaBids` in its handled set but **not** `hardwareOperations`
  or `deliveryChallans` — consistent with these screens being unwired; mobile users also can't reach them. Priority **Medium**.
- Detailed layout behavior at breakpoints **unverified** (no run).

---

## 10. Performance

- `content_host.dart` caches screens in `_screenCache` and clears on business-type change — good for switching.
- `HardwareOperationsScreen._refreshAll()` fires **5 sequential awaits** (projects, indents, deposits,
  customers, products). These are independent and could run with `Future.wait` to cut load latency.
  Priority **Low/Medium**.
- Dashboard alert widget recomputes on every matching UNS event; query is bounded. Acceptable. Priority **Low**.
- No obvious N+1 or unbounded list builds in sampled hardware code (lists use `ListView.builder`). Priority **Low**.

---

## 11. Security (RBAC, capability-bypass)

- **RBAC bypass risk in the desktop shell (High):** `app/routes.dart` wraps each route in
  `VendorRoleGuard(requiredPermission: ...)` (e.g., `/hardware/operations` requires `viewReports`,
  `/hardware/fast-billing` requires `createInvoices`). But the live desktop shell renders screens via
  `content_host.dart` → `getScreenForItem(screen.id)` / `_screenBuilders`, which return the **raw
  screen widgets with no `VendorRoleGuard` wrapper**. So staff-role permission checks defined in
  `routes.dart` are not applied on the in-shell navigation path. Whether each screen enforces
  permissions internally is **unverified**, but the guard layer is clearly inconsistent between the
  two navigation systems. Priority **High**.
- **Capability-bypass via un-gated sidebar items (High):** `proforma_bids`, `dispatch_notes`,
  `return_inwards` have no `capability` set in `_getRetailSections()`, so hard-isolation denials
  (`useProformaInvoice`/`useDispatchNote`/`useSalesReturn` absent for hardware) are not enforced at the
  sidebar. The `sidebarSectionsProvider` filter only removes items that *declare* a capability/permission.
- **BusinessGuard on hardware routes is correct** (`app/routes.dart` `/hardware/*` use
  `BusinessGuard(allowedTypes: [BusinessType.hardware], denialMessage: ...)`) — but only matters if
  those routes are actually navigated to (they are not, from the shell). Priority **Medium**.
- `FeatureResolver.enforceAccess` exists for backend/repo layers (`feature_resolver.dart`) but
  `HardwareOpsRepository` does **not** call it — no per-call capability enforcement. Priority **Medium**.

---

## 12. Offline Mode Gaps

- `modules/hardware/sync/hardware_sync_handler.dart` (`HardwareSyncHandler`, collection
  `hardware_products`, `/hardware/products`) and `hardware_ws_handler.dart` (events
  `hardware.stock.low`, `hardware.project.updated`) exist for offline sync + realtime.
- **But the GoRouter module that owns them is not mounted.** `legacy_route_redirect.dart` and
  `auto_parts_routes.dart`/`book_store_routes.dart` comments state the running app uses
  `MaterialApp.routes` (`app/routes.dart`), and migration to `GoRouter`/`routerConfig` "will be wired
  in" later. `HardwareModule` is registered in `core/module/module_loader.dart` `registerAll([...])`,
  and its `routes`/`syncHandlers`/`wsHandlers` are surfaced via `ModuleRegistry.buildRoutes()` /
  `ModuleRouteBuilder` — which feed a GoRouter that `app.dart`'s `MaterialApp` does not consume.
  So whether `HardwareSyncHandler` is actually attached to the live `SyncManager` is **unverified and
  likely not**. Priority **Medium/High**.
- `HardwareOperationsScreen` reads/writes only via `ApiClient` (network); it persists UI prefs
  (tab/filter) to `SharedPreferences` but **does not cache project/indent/deposit data locally** —
  offline it will show empty lists with an error snackbar. Priority **Medium**.

---

## 13. Business Logic Inconsistencies

- **`returns` module advertised but capability denied.** Hardware `modules` list includes `'returns'`
  (`business_type_config.dart`), but `useSalesReturn` is **not** in the hardware capability set
  (`business_capability.dart`). The module manifest and the isolation registry disagree. Priority **High**.
- **`quotations` module advertised but no `useProformaInvoice`.** Same pattern: hardware `modules`
  include `'quotations'` while `useProformaInvoice` is not granted. Priority **High**.
- **Comment vs code contradiction on Purchase Orders.** `business_capability.dart` hardware block
  contains a confused inline comment ("`usePurchaseOrder, // ❌ ... Wait, Checklist says ✅`"). The
  capability *is* granted, but the comment leaves the intent ambiguous and undocumented. Priority **Low**.
- **Contractor credit feature without credit capability.** `HardwareCreditControlScreen` exists and the
  module manifest lists `hardware_contractor_credit` (`hardware_module.dart`), yet hardware lacks
  `useCreditLimit`/`useCreditManagement`, and the dashboard "Overdue Contractor Bills" alert is gated by
  the missing `accessCreditLimit` (so it never shows). Inconsistent. Priority **High**.
- **`cutToSizeCharge` rounds up to whole units** (`hardware_business_rules.dart`: `units.ceilToDouble()`).
  Documented as shop convention, but billing 1.1 ft as 2 ft can over-charge; ensure this is intended and
  disclosed on the invoice. Priority **Medium** (and currently no UI uses it — unverified caller).

---

## 14. Data Validation Issues

- `DimensionCalculator._calculate()` validates ranges (0.1–100 ft/mtr) and rejects non-positive — good,
  but the widget is orphaned so the validation never runs (§4).
- `HardwareOperationsScreen` create dialogs validate: project name non-empty, indent qty `> 0`,
  deposit qty/amount `> 0`, settlement refund `>= 0`. Reasonable. Priority **Low**.
- **Numeric parsing is lenient:** `double.tryParse(...) ?? 0` then a `<= 0` guard — acceptable, but a
  field like `quantity` accepts free text with no inputFormatter in `_field` (only the dimension widget
  restricts to `[0-9.]`). A user can type letters and silently get `0`. Priority **Low/Medium**.
- No GSTIN/HSN format validation surfaced for hardware B2B parties in `createParty`
  (`hardware_ops_repository.dart` passes raw `gstin`). Priority **Medium** (server-side validation unverified).

---

## 15. UX Problems

- **Dead dashboard shortcuts** (§6c): "Projects" and "Delivery Challan" land on a "Feature Not Found"
  placeholder. This is the worst UX issue — primary CTAs fail. Priority **Critical**.
- **Duplicate menu destinations** (§6a): several sidebar entries open the same screen; users can't tell
  them apart. Priority **Medium**.
- **Currency shown as `Rs ` literal** (`NumberFormat.currency(symbol: 'Rs ')` in
  `hardware_operations_screen.dart`) rather than `₹` — inconsistent with a localized app that ships
  Hindi strings (`app_localizations_hi.dart`). Priority **Low**.
- **Generic retail sidebar** gives no hardware affordances (no Projects/Estimates/Dimension tools),
  so even power users must hunt. Priority **High**.

---

## 16. Accessibility

- Hardware screens rely on standard Material widgets (`ListTile`, `TextField`, `Chip`, `TabBar`,
  `FloatingActionButton.extended`) which carry default semantics. No custom `Semantics` labels were
  added; icon-only `IconButton`s in `HardwareOperationsScreen` do set `tooltip` ("Scan product barcode",
  "Reset Filters") — good for screen readers. Priority **Low**.
- Color-only status signaling (e.g., green/orange stock text in the scan dialog) without a text
  alternative in some spots. Priority **Low/Medium**.
- Full WCAG conformance (contrast, focus order, screen-reader flow) requires manual testing with
  assistive tech — **unverified**.

---

## 17. Bugs / Errors / Crash Scenarios

- **Confirmed defect:** dashboard "Projects"/"Delivery Challan" → placeholder screen (§6c). Not a crash,
  but a broken feature. Priority **Critical**.
- **Confirmed dead code:** hardware "Overdue Contractor Bills" alert never renders (gated by a capability
  hardware lacks) (§5/§13). Priority **Medium**.
- **Potential empty-state confusion:** offline/`4xx` makes `HardwareOperationsScreen` show empty lists +
  a red snackbar listing per-section failures (`_refreshAll`). Functional, not a crash. Priority **Low**.
- **`dead_null_aware_expression` suppressed** at top of `hardware_operations_screen.dart`
  (`// ignore_for_file: dead_null_aware_expression`) — masks a redundant `?? _products.first['id']`
  in the indent dialog. Latent smell, not a crash. Priority **Low**.
- No null-deref risks spotted in the orphaned screens beyond standard map access (which uses `?? '-'`
  fallbacks). Crash analysis of orphaned screens is **partially unverified** (not all lines read).

---

## 18. Unnecessary / Irrelevant Features Shown (shared retail sidebar)

Because hardware uses `_getRetailSections()`, it shows the **full retail menu** including items of
limited relevance to a hardware counter, and several that contradict its capabilities:
- `batch_tracking` — correctly hidden (capability-gated), good.
- `proforma_bids`, `dispatch_notes`, `return_inwards` — **shown despite hard-isolation denials** (§6d/§11).
- Heavy financial/compliance stack (`income_statement`, `funds_flow`, `financial_position`, full GST tabs,
  `audit_trail`) — fine for an accountant, arguably noise for a small hardware shop, and several are
  placeholder/duplicate screens (§6a). Priority **Medium**.
- **Flag:** the shared retail sidebar is the root cause of both the noise and the capability bypasses.
  A dedicated `_getHardwareSections()` would fix presentation, isolation, and discoverability together.

---

## 19. Recommendations & Prioritized Implementation Plan

**P0 — Critical (broken user-facing paths):**
1. Fix the two dead dashboard shortcuts. Either (a) add `AppScreen.hardwareOperations` and
   `AppScreen.deliveryChallans` to `content_host.dart` `_screenBuilders` (mapping to
   `HardwareOperationsScreen()` and `DeliveryChallanListScreen()`), **or** (b) add matching
   `case 'hardware_operations'` / `case 'delivery_challans'` to
   `sidebar_navigation_handler.dart` `getScreenForItem`. (Cite: `business_quick_actions.dart`,
   `content_host.dart`, `sidebar_navigation_handler.dart`.)
2. Connect the orphaned, already-built hardware screens (`HardwareOperationsScreen`,
   `HardwareCreditControlScreen`, `HardwareSupplierManagementScreen`, `HardwareInvoiceProfileScreen`,
   `HardwarePhase12WorkspaceScreen`, `HardwareCommandCenterScreen`) to navigation.

**P1 — High:**
3. Add a dedicated `case BusinessType.hardware: return _getHardwareSections();` in
   `sidebar_configuration.dart` with sections for Projects/Indents/Deposits, Estimates→Invoice,
   Delivery Challans, Contractor Credit, Supplier Rate Compare, and an Inventory section — and attach
   correct `capability` gates so isolation is enforced at the menu.
4. Replace hardcoded dashboard alert counts with real data (extend `alertCountsProvider` to compute
   pending quotes/open indents/deposit liability, or read `HardwareOpsRepository`). (`business_alerts_widget.dart`.)
5. Resolve the capability/manifest contradictions: grant `useSalesReturn`, `useProformaInvoice`,
   and (for contractor credit) `useCreditLimit`/`useCreditManagement` to `'hardware'` to match the
   `modules` list and the contractor-credit feature — or remove the conflicting menu items/feature.
   (`business_capability.dart`, `business_type_config.dart`, `hardware_module.dart`.)
6. Unify RBAC: ensure the in-shell render path (`content_host`/`getScreenForItem`) applies the same
   `VendorRoleGuard`/permission checks as `app/routes.dart`.

**P2 — Medium:**
7. Surface `DimensionCalculator` in the bill line-item editor for hardware (and wire
   `HardwareBusinessRules.cutToSizeCharge` for loose-cut pricing with on-invoice disclosure).
8. Grant `useMultiUnit` to hardware and implement box↔pcs↔kg↔ft conversion.
9. Add e-Way bill support (capability + screen) for bulk dispatch.
10. De-duplicate sidebar destinations that collapse onto `AllTransactionsScreen`/`PrintMenuScreen`/`BackupScreen`.
11. Decide on GoRouter-module migration vs. legacy routes so `HardwareModule` sync/ws handlers actually attach.
12. Add local caching/offline fallback to `HardwareOperationsScreen`.

**P3 — Low:**
13. Parallelize `_refreshAll` with `Future.wait`. Replace `Rs ` with `₹` (localized). Add input
    formatters to numeric fields. Resolve the suppressed `dead_null_aware_expression` lint.

---

## 20. Confidence & Coverage

- **Confidence: High** for navigation/wiring findings (§1, §6, §7, §8, §11, §13) — these are derived
  from directly read source: `sidebar_configuration.dart`, `sidebar_navigation_handler.dart`,
  `content_host.dart`, `app_screens.dart`, `business_quick_actions.dart`, `business_alerts_widget.dart`,
  `business_capability.dart`, `business_type_config.dart`, `app/routes.dart`, and the `features/hardware/**`
  + `modules/hardware/**` trees.
- **Confidence: Medium** for offline-sync mounting (§12), RBAC enforcement inside screens (§11), and
  estimate→invoice/cut-to-size live usage (§3/§13) — these depend on subsystems not fully traced.
- **Confidence: Low / unverified:** backend `/hardware/*` handler existence, runtime/responsive/perf
  behavior, accessibility conformance, online-store presence.
- **Coverage:** ~100% of the hardware-specific Flutter surface (config, capabilities, all 6 feature
  screens, repo, rules, widget, module, routes) was read. Backend, generic shared screens’ internals,
  and runtime behavior were sampled or skipped as noted at the top.

---

### Top findings (summary)
1. **Hardware has no dedicated sidebar** — it falls through to `default: _getRetailSections()`
   (`sidebar_configuration.dart`), so zero hardware-specific navigation is exposed.
2. **Two primary dashboard CTAs are dead links** — "Projects" (`AppScreen.hardwareOperations`) and
   "Delivery Challan" (`AppScreen.deliveryChallans`) resolve to a "Feature Not Found" placeholder
   because neither id is in `content_host._screenBuilders` nor `getScreenForItem`.
3. **A whole hardware feature set is built but orphaned** — `HardwareOperationsScreen`,
   `HardwareCreditControlScreen`, `HardwareSupplierManagementScreen`, `HardwareInvoiceProfileScreen`,
   `HardwarePhase12WorkspaceScreen`, `HardwareCommandCenterScreen`, and the `DimensionCalculator`
   widget are unreachable from the running shell (the `modules/hardware` GoRouter is unmounted; the
   `app/routes.dart` named routes aren’t navigated to from the shell).
4. **Dashboard alerts are hardcoded** ('7' quotes, '4' projects, '3' overdue) and ignore the real
   `alertCountsProvider` data; the contractor-credit alert can never render (capability hardware lacks).
5. **Isolation contradictions & RBAC gap** — `modules` advertise `returns`/`quotations` while the
   capability set denies `useSalesReturn`/`useProformaInvoice`; un-gated sidebar items bypass hard
   isolation; and the in-shell render path doesn’t apply the `VendorRoleGuard` that `app/routes.dart` does.
