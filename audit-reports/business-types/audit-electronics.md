# DukanX Business-Type Audit — Mobile / Electronics

> Read-only, evidence-based audit. Every "missing/broken/orphaned" claim cites the file/function checked. Items I could not confirm are marked **unverified**.
>
> **Sampled (read in full or near-full):** `models/business_type.dart`; `core/billing/business_type_config.dart` (electronics config + extensions); `widgets/desktop/sidebar_configuration.dart` (`_getSectionsForBusiness`, full `_getRetailSections`); `widgets/desktop/sidebar_navigation_handler.dart` (full `getScreenForItem`); `core/isolation/business_capability.dart` (`'electronics'` key + full registry); `core/isolation/feature_resolver.dart`; `core/config/business_capabilities.dart` (`BusinessCapabilities.get`); `features/dashboard/v2/widgets/business_quick_actions.dart`; `features/dashboard/v2/widgets/business_alerts_widget.dart`; `features/billing/presentation/widgets/manual_item_entry_sheet.dart` (electronics branch); `features/billing/services/billing_service.dart` (electronics IMEI block); `features/billing/presentation/widgets/bill_line_item_row.dart` (serial column); `app/routes.dart` (service-job + computer-shop guard blocks).
> **Sampled by directory listing / targeted grep only (internals unverified):** `features/computer_shop/presentation/screens/{warranty_screen,serial_history_screen,multi_unit_screen}.dart`; `features/statements/presentation/screens/imei_tracking_statement_screen.dart`; `core/services/statements_service.dart` + `core/repository/statements_repository.dart` (`getImeiTrackingStatement`); `features/service/services/exchange_service.dart`, `features/service/data/repositories/imei_serial_repository.dart`; `modules/` listing (no `electronics` module); `core/session/session_manager.dart` (RBAC — only `hasPermission` confirmed); `core/navigation/app_screens.dart` (`AppScreen.serviceJobs` enum member referenced but mapping not opened).

---

## 1. Header — Business Type, Sidebar Resolution, Config Summary

**Business type:** `BusinessType.electronics` (`Dukan_x/lib/models/business_type.dart`, 5th enum value). `displayName` = "Mobile / Electronics", `icon` = `phone_android_rounded`; `emoji` = 📱, `primaryColor`/`pdfPrimaryColor` = `#0891B2` (Cyan) (`business_type_config.dart` extensions).

**Sidebar resolution:** Electronics **IS** an explicit case in `_getSectionsForBusiness()` (`sidebar_configuration.dart`) but it is **grouped** with mobileShop and computerShop and returns the shared **generic retail sidebar**:
```dart
case BusinessType.electronics:
case BusinessType.mobileShop:
case BusinessType.computerShop:
  return _getRetailSections();
```
So electronics renders the generic retail sidebar — 10 sections, ~58 items, **zero electronics-specific entries** (no IMEI/serial tracking, no warranty register, no service/repair jobs, no exchange/buyback, no AMC). See the full id table below; resolution of each id is in §6.

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

**Config summary** (`BusinessTypeRegistry._configs[BusinessType.electronics]`):
- requiredFields: `itemName, quantity, price, brand, hsnCode`
- optionalFields: `serialNo, warrantyMonths, discount`
- defaultGstRate: `18.0`, gstEditable: `false` (fixed 18%)
- unitOptions: `pcs, set, nos`
- itemLabel: `Product`, addItemLabel: `Add Product`, priceLabel: `MRP`
- modules: `['inventory','sales','returns','warranty','reports']`

**Capability registry** (`business_capability.dart`, key `'electronics'`): product add/name/salePrice/stockQty/unit/tax/category; inventory list/visibleStock/search; invoice list/search/create; `useLowStockAlert`, `useDailySnapshot`, `useRevenueOverview`; `usePurchaseOrder`, `useStockEntry`, `useSupplierBill`; specialized **`useIMEI`, `useWarranty`, `useBarcodeScanner`, `useScanOCR`, `useStockManagement`**. **Notably NOT granted to electronics (but granted to mobileShop/computerShop):** `useJobSheets`, `useRepairStatus`, `useBuyback`, `useExchange`, `useMultiUnit`. Also NOT granted: `useBatchExpiry`, `useGeneralAlerts`, `useSalesReturn`, `useProformaInvoice`, `useDispatchNote`, `useStockReversal`, `usePurchaseRegister`, `useInventoryExport`. Source comments mark several as `⚠️` ("Dead Stock: ⚠️", "Returns: ⚠️", "Export: ⚠️", "Reversal: ⚠️").

**Capability resolution is strict-deny:** `core/isolation/feature_resolver.dart` `canAccess()` returns `false` for any capability not in the set. Consequence: the only capability-gated retail sidebar item, `batch_tracking` (gated by `useBatchExpiry`), is **filtered out for electronics** (electronics lacks `useBatchExpiry`).

**No dedicated electronics code exists.** There is **no `features/electronics/` folder** (confirmed: `file_search` for `Dukan_x/lib/features/electronics` → "No files found") and **no `modules/electronics/`** module (confirmed: `modules/` listing has `computer_shop`, `mobile_shop`, but no `electronics`). Electronics is the headline "Mobile / Electronics" type yet ships the least dedicated code of the three electronics-family types. All electronics-relevant device features (warranty, serial history, multi-unit) live under `features/computer_shop/` and are **route-guarded to computerShop only** (see §6).

---

## 2. Missing Generic (Vyapar Benchmark) Features

| # | Benchmark | Status for electronics | Evidence | Priority |
|---|-----------|------------------------|----------|----------|
| 1 | Billing/Invoicing | **Present** — `new_sale` → `BillCreationScreenV2`. Serial/IMEI + warranty captured per line (`manual_item_entry_sheet.dart` electronics branch; `bill_line_item_row.dart` `showSerialNo`). | nav handler; billing widgets | — |
| 2 | Inventory (real-time, low-stock, batch/expiry, FIFO, multi-warehouse, reorder, BOM) | **Generic only** — `stock_summary`/`item_stock`/`low_stock`/`stock_valuation`/`damage_logs` → generic inventory screens. No serial-wise stock view, no multi-warehouse, FIFO, reorder-point, or BOM. | nav handler | High |
| 3 | Barcode/POS | **Partial** — `useBarcodeScanner` granted; `IMEI Lookup` quick action exists but is a **dead button** (`onTap: () {}`). No per-unit barcode/label printing surfaced. | `business_quick_actions.dart` | High |
| 4 | Accounting | **Inherited generic** — `accounting_reports`, `income_statement`, `invoice_margin`, `daybook`. | sidebar config | Low |
| 5 | Receivables/Payables | **Inherited generic** — `party_ledger`, `outstanding`, `credit_notes`. `useCreditManagement` not granted (no EMI/credit logic). | capability registry | Medium |
| 6 | Bank/Cash | **Inherited generic** — `bank_accounts`, `cash_bank`. | nav handler | Low |
| 7 | Orders/Delivery | **Partial generic** — `booking_orders`, `dispatch_notes`. No device-pre-booking with serial reservation. | sidebar | Medium |
| 8 | OCR | **Capability granted, no live entry point** — `useScanOCR` in set; `ocrFocus` = "Name, Model, Serial/IMEI" (`business_capabilities.dart`), but no OCR item in the retail sidebar. | capability; grep | Medium |
| 9 | Reports (37+) | **Generic hub** — `analytics_hub` → `ReportsHubScreen`; several BI ids alias to generic screens (see §6). No IMEI/warranty/serial-wise sales report reachable. | nav handler | Medium |
| 10 | Multi-user RBAC + audit | **Partial** — `audit_trail` id maps to `AllTransactionsScreen` (not a real audit log, see §6/§8). RBAC matrix exists (`session_manager.dart`) but retail sidebar items carry **no `permission`** (§11). | nav handler; sidebar | High |
| 11 | Multi-firm | **Unverified** — not surfaced in electronics sidebar. | — | Medium |
| 12 | Backup | **Present** — `backup` → `BackupScreen`. | nav handler | Low |
| 13 | Online store catalog + order | **Partial** — `catalogue` → `CatalogueScreen` (share catalogue). Order-intake unverified. | nav handler | Medium |
| 14 | e-Way bill | **Missing** — no e-Way bill id anywhere in retail sidebar; relevant for high-value electronics. | sidebar grep | High |
| 15 | Loyalty/discount | **Partial** — line `discount` optional field; `useLoyaltyPoints` not granted to electronics. | config; capability | Low |
| 16 | Service-business | **Reachable by route, not by sidebar** — electronics IS allowed on `/job/create`, `/job/status`, `/job/deliver` (`routes.dart` BusinessGuard), but no sidebar entry exposes them. | `routes.dart` 657–692 | High |
| 17 | Offline-first sync | **Inherited generic** — `sync_status` reuses `BackupScreen`; offline correctness unverified (§12). | nav handler | Medium |

---

## 3. Missing Industry-Specific Features (Electronics)

| Need | Status | Evidence | Priority |
|---|---|---|---|
| IMEI/serial capture per unit | **Partial capture, no tracking** — serial captured at billing line (`manual_item_entry_sheet.dart`), but no serial-wise stock/lookup screen reachable for electronics. `ImeiTrackingStatementScreen` exists with real DB query (`statements_repository.getImeiTrackingStatement`) but is **orphaned** (no route/sidebar — §6). | grep; routes | **Critical** |
| Warranty registration & expiry tracking/claims | **Built but denied** — `WarrantyScreen` exists (`features/computer_shop/.../warranty_screen.dart`) but its route `/computer-shop/warranty` is `BusinessGuard(allowedTypes: [computerShop])` with denial "Only Computer Shop businesses can access Warranty." Electronics is excluded. `warranty` module in config is therefore unreachable. | `routes.dart` 1110–1117 | **Critical** |
| Serial-wise sales & purchase history | **Built but denied** — `SerialHistoryScreen` route `/computer-shop/serial-history` guarded to `[computerShop]`. | `routes.dart` 1118–1133 | High |
| Serial uniqueness validation | **Stub** — `billing_service.dart` electronics block has `// Strict 1:1 validation could go here` and performs no uniqueness enforcement. | `billing_service.dart` 119–125 | **Critical** |
| EMI/finance billing | **Missing** — no EMI/finance flow found. | grep | High |
| Exchange/buyback of old devices | **Denied to electronics** — `useExchange`/`useBuyback` granted only to mobileShop; the dashboard Exchange quick action is gated `if (type == BusinessType.mobileShop)`. Electronics excluded. | `business_quick_actions.dart`; capability registry | High |
| AMC / service-job tracking | **Reachable by route only** — electronics allowed on `/job/*` routes but no sidebar/quick-action that is electronics-gated correctly (the "New Repair" quick action navigates via `AppScreen.serviceJobs`). No AMC/contract model surfaced. | `routes.dart` 657–692 | High |
| Accessory bundling | **Missing** — no bundle/combo logic found. | grep | Medium |
| MRP / fixed 18% GST | **Present** — priceLabel "MRP", defaultGstRate 18.0, gstEditable false. | config | — |
| Demo/display units | **Missing** — no demo-unit state. | grep | Low |
| Extended-warranty upsell | **Missing** — `warrantyMonths` is a free int field only; no extended-warranty product/upsell. | config; entry sheet | Medium |
| Return with serial validation | **Missing/weak** — `return_inwards` → generic `ReturnInwardsScreen`; no serial validation on return verified, and `useSalesReturn` not granted to electronics. | nav handler; capability | High |

---

## 4. Missing UI Components

- **No serial/IMEI lookup screen** in the electronics experience. `IMEI Lookup` quick action button renders but does nothing (`onTap: () {}`, `business_quick_actions.dart`). **Priority: High.**
- **No warranty register/claims UI** reachable (WarrantyScreen denied). **Priority: Critical.**
- **No serial-wise stock grid** — inventory uses generic `InventoryDashboardScreen`/`StockSummaryScreen`. **Priority: High.**
- **No EMI/finance entry UI**, **no exchange/buyback UI for electronics**, **no AMC UI**. **Priority: High/Medium.**
- Manual entry sheet serial field has **no scan affordance wired** (hint says "Scan or enter serial number" but it is a plain `TextFormField`, `manual_item_entry_sheet.dart` line ~273). **Priority: Medium.**

---

## 5. Missing Widgets & Dashboard / KPI Cards

- **`BusinessAlertsWidget` electronics case uses HARDCODED counts** (`business_alerts_widget.dart`):
  - "Warranty Expiring" → `count: '5'` (gated by `caps.supportsSerialNumber`, which is `useIMEI` → true for electronics).
  - "Pending Repairs" → `count: '8'` (always shown).
  - "Exchange Requests" → only for `mobileShop`.
  The live `alertCountsProvider` only computes `lowStock` and `expiringSoon` (used by grocery). **Electronics alert counts are 100% static literals** — they never reflect real data. **Priority: High.**
- Title is "Warranty & Service Alerts" (`_getTitle`) — but no underlying warranty/service data source for electronics. **Priority: High.**
- **`BusinessQuickActions` electronics case**: "New Repair" → `nav.navigateTo(AppScreen.serviceJobs)`; "IMEI Lookup" → **dead** `onTap: () {}`; "Exchange" → mobileShop only. **Priority: High.**
- **No KPI cards** for warranty-expiring %, serial coverage, repair turnaround, or exchange value — none exist for electronics. **Priority: Medium.**

---

## 6. Navigation & Route Gaps

**Sidebar id → screen resolution (`SidebarNavigationHandler.getScreenForItem`):** every id in `_getRetailSections()` has an explicit `case` in the handler — **none fall through to `_PlaceholderScreen`**. Verified id-by-id against the switch. So there are **no dead/placeholder links** in the electronics retail sidebar. However, several ids resolve to **generic/aliased** screens:

| Sidebar id | Resolves to | Note |
|---|---|---|
| `turnover_analysis` | `AllTransactionsScreen` | source comment "Placeholder mapping" — miscategorized |
| `daily_activity` | `AllTransactionsScreen` | not a dedicated activity register |
| `ledger_history` | `AllTransactionsScreen` | alias |
| `ledger_abstract` | `TrialBalanceScreen` | alias |
| `outstanding` | `PartyLedgerListScreen(initialFilter:'receivable')` | alias |
| `purchase_register` | `ProcurementLogScreen` | "Reuse procurement log" |
| `invoice_margin` / `income_statement` | `PnlScreen` | two ids → same screen |
| `funds_flow` / `cash_bank` | `CashflowScreen` | two ids → same screen |
| `activity_logs` / `audit_trail` / `transaction_reports` | `AllTransactionsScreen` | **three ids → same screen; `audit_trail` is NOT a real audit log** (§8, §11) |
| `sync_status` | `BackupScreen` | "Reuse Backup for sync status" |
| `doc_templates` / `print_settings` | `PrintMenuScreen` | two ids → same screen |

**Capability-vs-sidebar mismatches / orphaned electronics screens:**
- **Warranty / Serial-history / Multi-unit screens are ORPHANED for electronics.** `WarrantyScreen`, `SerialHistoryScreen`, `MultiUnitScreen` are wired only at `/computer-shop/*` routes with `BusinessGuard(allowedTypes: const [BusinessType.computerShop])` (`routes.dart` 1110–1142). Electronics is **explicitly denied** despite holding `useIMEI`+`useWarranty` capabilities and a `warranty` module in its config. **Priority: Critical.**
- **`ImeiTrackingStatementScreen` is fully orphaned** — defined in `features/statements/...`, exported in `statements/.../screens.dart`, backed by a real query (`statements_repository.getImeiTrackingStatement` over the `iMEISerials` table), but **referenced by no route and no sidebar id anywhere** (grep `ImeiTrackingStatement|imei-tracking|imeiTracking` returns only its own file, the repo, and the service). Dead/unreachable feature. **Priority: High.**
- **Service/repair routes reachable but not surfaced:** `/job/create`, `/job/status`, `/job/deliver` include `BusinessType.electronics` in `allowedTypes` (`routes.dart` 657–692), but **no retail sidebar item points to them**. They are only reachable via the dashboard "New Repair" quick action (`AppScreen.serviceJobs`). So the sidebar and quick-action navigation are inconsistent. **Priority: High.**
- **`batch_tracking`** sidebar item (cap `useBatchExpiry`) is correctly **hidden** for electronics (electronics lacks the cap). Not a bug, but it is the only capability filter applied; everything else is unconditionally visible.
- **No `modules/electronics`** GoRouter module exists; `mobile_shop` and `computer_shop` modules exist but (per the GoRouter-not-mounted note carried across sibling audits — `test/audit/d1_navigation_graph_walk_test.dart`) module nav is **unverified as live** here. Electronics shares neither module. **Priority: Medium.**

---

## 7. Backend Integration Gaps

- **Alert counts not backed by backend for electronics** — `alertCountsProvider` (`business_alerts_widget.dart`) computes only `lowStock` (via `ProductsRepository.getLowStockProducts`) and `expiringSoon` (via `productBatches` query). Electronics warranty/repair counts are literals, never queried. **Priority: High.**
- **IMEI/serial data layer exists but is unused by electronics UI** — `IMEISerialRepository` (`features/service/data/repositories/imei_serial_repository.dart`) and `statements_repository.getImeiTrackingStatement` (real Drift query over `iMEISerials`) exist, but no electronics-reachable screen consumes them (the only consumer, `ImeiTrackingStatementScreen`, is orphaned). **Priority: High.**
- **Serial persistence at sale:** `billing_service.dart` writes `imei: Value(item.imei)` on bill lines (line ~62), and has an electronics branch (line 119) — but it only reads `item.imei`, performs no link to an IMEI inventory record, and no uniqueness/stock-decrement-by-serial. **Priority: High.**
- Sync/backup wiring for serial/warranty entities **unverified**.

---

## 8. Database & API Issues (Real vs Mock; Hardcoded Counts)

- **Hardcoded dashboard counts (mock):** electronics alerts "Warranty Expiring = 5", "Pending Repairs = 8" are string literals (`business_alerts_widget.dart`). **Priority: High.**
- **`audit_trail` is mock-equivalent:** maps to `AllTransactionsScreen`, not a tamper-evident audit log; same screen as `activity_logs` and `transaction_reports`. For a multi-user claim this is misleading. **Priority: High.**
- **Real data paths:** low-stock + batch-expiry counts are real Drift queries (`alertCountsProvider`); `iMEISerials` table + `getImeiTrackingStatement` are real but unreached. **Priority: (informational).**
- **Serial uniqueness not enforced at DB/service layer** — explicit stub comment (`billing_service.dart`). Risk of duplicate IMEI sale. **Priority: Critical (data integrity).**

---

## 9. Responsive Design

- Electronics uses the shared retail sidebar/dashboard widgets; responsiveness is inherited, not electronics-specific. `imei_tracking_statement_screen.dart` imports `core/responsive/responsive.dart` (responsive-aware) but is orphaned. Dashboard widgets use fixed paddings/`Wrap` (`business_quick_actions.dart`) — generally adaptive. **No electronics-specific responsive defects identified; deep layout testing unverified.** **Priority: Low.**

---

## 10. Performance

- `sidebarSectionsProvider` is memoized on `businessTypeProvider`/`authStateProvider` (per source doc comment) — avoids per-frame recompute. Good.
- `alertCountsProvider` re-runs `fetchCounts()` (two DB queries) on every matching UNS event; for electronics these results are not even displayed (counts hardcoded), so the queries are **wasted work** on the electronics dashboard. **Priority: Low/Medium.**
- No N+1 or large-list issues identified in the electronics path (no electronics list screens exist). Deeper profiling **unverified**.

---

## 11. Security (RBAC, Capability-Bypass)

- **Retail sidebar items carry no `permission`** — in `_getRetailSections()` every `SidebarMenuItem` sets only optional `capability` (just `batch_tracking`), never `permission`. The RBAC filter in `sidebarSectionsProvider` only removes items whose `permission != null`. **Therefore all ~58 retail items are visible to every role** (cashier, staff, etc.) for electronics — no role gating on sensitive items like `audit_trail`, `bank_accounts`, `backup`, `expenses`, `accounting_reports`. **Priority: High.**
- **Capability bypass via dashboard quick actions:** "New Repair" navigates electronics to service jobs through `AppScreen.serviceJobs` without checking any capability; electronics lacks `useJobSheets`/`useRepairStatus` in its registry, so the capability model and the navigation disagree. The route-level `BusinessGuard` does allow electronics on `/job/*` (and requires `Permissions.manageStaff`), so the route guard is the only real gate. Inconsistent layering. **Priority: Medium.**
- **Positive:** route-level `BusinessGuard` + `VendorRoleGuard` correctly deny electronics from computer-shop warranty/serial/multi-unit screens (`routes.dart`). Hard-isolation `FeatureResolver.canAccess` is strict-deny by default. 
- RBAC matrix internals (`RolePermissions`, `Permission` enum) referenced from `sidebar_configuration.dart` but defined elsewhere — **not opened; internals unverified.**

---

## 12. Offline Mode Gaps

- `sync_status` reuses `BackupScreen` (no dedicated sync/conflict UI). Offline-first correctness for serial/warranty entities **unverified** (no electronics-specific offline logic found). 
- `alertCountsProvider` has an offline fallback (initial `fetchCounts()` before stream) — but irrelevant to electronics since its counts are static. **Priority: Medium.**

---

## 13. Business Logic Inconsistencies

- **`serialNo`/`warrantyMonths` are optional** in electronics config, yet they are the defining electronics differentiators; mobileShop makes `serialNo` required. An electronics device can be billed with no serial and no warranty, silently. **Priority: High.**
- **`warrantyMonths` is a bare int** with no start-date/expiry computation at point of sale; warranty "expiry" is only computed inside the orphaned `ImeiTrackingStatementScreen`/repository. So warranty entered at billing does not flow into any reachable expiry tracker. **Priority: High.**
- **Capability/feature split confusion:** electronics has `useIMEI` + `useWarranty` (isolation registry) but the only screens implementing warranty/serial are guarded to `computerShop`. The capability grant is therefore meaningless for electronics. **Priority: High.**
- **Two ids → one screen** collisions (§6) mean menu labels promise distinct reports that don't exist. **Priority: Medium.**

---

## 14. Data Validation Issues

- **Serial/IMEI uniqueness: NOT validated** — `manual_item_entry_sheet.dart` stores `serialNo: _serialController.text.trim()` with **no validator** (the field has no `validator:`), and `billing_service.dart` explicitly defers it (`// Strict 1:1 validation could go here`). Duplicate or blank IMEIs accepted. **Priority: Critical.**
- **Warranty months: no validation** — `_warrantyController` parsed with `int.tryParse` and silently dropped if invalid/negative; no range check. **Priority: Medium.**
- **No warranty date validation** (start ≤ expiry) anywhere reachable for electronics. **Priority: Medium.**
- **HSN code required but unvalidated format** — `hsnCode` is a required field; entry sheet captures `_hsnController.text.trim()` with no length/format check (general billing concern). **Priority: Low.**

---

## 15. UX Problems

- **Dead button:** "IMEI Lookup" quick action does nothing (`onTap: () {}`). Users tap and get no feedback. **Priority: High.**
- **Misleading alerts:** "Warranty Expiring (5)" / "Pending Repairs (8)" always show the same fabricated numbers regardless of real data. Erodes trust. **Priority: High.**
- **Serial field invites scanning** ("Scan or enter serial number") but provides no scanner. **Priority: Medium.**
- **No path from sidebar to repair/warranty** — a mobile/electronics shopkeeper sees a generic retail menu with no device-centric entries. **Priority: High.**
- Generic retail sidebar shows ~58 items including many irrelevant to a small electronics counter (e.g., `funds_flow`, `filing_status`, `ledger_abstract`) — cognitive overload. **Priority: Medium.**

---

## 16. Accessibility

- Dashboard widgets rely on icon + text with hardcoded `FuturisticColors`; contrast and semantic labels **unverified**. Quick-action buttons are `InkWell`s with `Text` (no explicit `Semantics`/tooltip). The dead "IMEI Lookup" button gives no accessible state. **Priority: Medium.**
- No electronics-specific accessibility regressions identified beyond shared-widget concerns. Full AT validation requires manual testing — **unverified.**

---

## 17. Bugs / Errors / Crash Scenarios

- **Dead `onTap: () {}`** (IMEI Lookup) — not a crash, but a functional defect. **Priority: High.**
- **Wasted DB queries** on electronics dashboard (`alertCountsProvider` runs but output unused) — performance, not crash. **Priority: Low.**
- **Potential data-integrity bug:** duplicate IMEI accepted at sale (no uniqueness) → corrupt serial-tracking data if/when the orphaned IMEI screen is ever wired. **Priority: Critical (latent).**
- No null-deref/crash identified in the read electronics paths. Orphaned screens (`WarrantyScreen` etc.) are unreachable so cannot crash electronics users.

---

## 18. Unnecessary / Irrelevant Features Shown

- **Shared retail sidebar component (`_getRetailSections`) is the root cause** — electronics, mobileShop, computerShop all render the identical generic 10-section menu. For electronics this surfaces items with no device relevance and **omits all device features**:
  - Likely-irrelevant for a small electronics shop: `funds_flow`, `financial_position`, `ledger_abstract`, `filing_status`, `b2b_b2c`, `procurement_insights`, `damage_logs`.
  - **Missing-but-expected:** IMEI/serial tracking, warranty register, repair jobs, exchange/buyback, EMI.
- **Flag:** the grouping `case electronics: case mobileShop: case computerShop: return _getRetailSections();` means none of the three get their specialized menu. mobileShop/computerShop at least have route-level features; electronics has the least. **Priority: High (shared-component flag).**

---

## 19. Recommendations & Prioritized Implementation Plan

**Critical**
1. **Enforce IMEI/serial uniqueness** at `billing_service.dart` (replace the stub) and add a `validator` on the serial field in `manual_item_entry_sheet.dart`; reject duplicates against `iMEISerials`.
2. **Make warranty/serial reachable for electronics.** Either broaden `BusinessGuard(allowedTypes:)` on `/computer-shop/warranty`, `/serial-history` to include `electronics`, or build electronics equivalents; then add sidebar entries.
3. **Wire the orphaned `ImeiTrackingStatementScreen`** into a route + an electronics sidebar id (it already has a real repository/service).

**High**
4. Add an **electronics sidebar section** (split the `electronics/mobileShop/computerShop` case out of `_getRetailSections`) containing: Serial/IMEI Tracking, Warranty Register, Service/Repair Jobs (`/job/*` already allow electronics), Returns-with-serial.
5. **Replace hardcoded alert counts** for electronics with real queries (warranty-expiring from `iMEISerials.warrantyExpiry`, open repairs from service-job repo); fix the dead "IMEI Lookup" `onTap`.
6. **Add RBAC `permission` to sensitive retail items** (`audit_trail`, `bank_accounts`, `backup`, `expenses`, `accounting_reports`) so non-privileged roles don't see them.
7. **Make a real audit log** for `audit_trail` instead of aliasing `AllTransactionsScreen`.
8. Make `serialNo` **required** (or conditionally required) for electronics at billing; compute warranty expiry from sale date + `warrantyMonths`.
9. Add **e-Way bill** and **EMI/finance** flows for high-value electronics.

**Medium**
10. Add scan affordance to the serial field; add exchange/buyback for electronics (currently mobileShop-only).
11. De-duplicate one-id-per-screen aliases or hide labels for reports that don't exist.
12. Trim irrelevant retail items for electronics via capability gating.

**Low**
13. Avoid running `alertCountsProvider` queries on dashboards that don't display them.
14. Add HSN format validation; add accessibility semantics/tooltips to quick actions.

---

## 20. Confidence & Coverage

- **High confidence (read in full):** sidebar resolution + full retail id list, full `getScreenForItem` mapping (all ids resolve, no placeholder), electronics config + capabilities, dashboard quick-actions & alerts electronics branches (hardcoded counts, dead button), billing serial/warranty capture + uniqueness stub, computer-shop warranty/serial/multi-unit route guards denying electronics, absence of `features/electronics/` and `modules/electronics/`, electronics inclusion in `/job/*` routes, orphaned `ImeiTrackingStatementScreen`.
- **Medium confidence (grep/listing, internals not opened):** internals of `WarrantyScreen`/`SerialHistoryScreen`/`MultiUnitScreen`, `IMEISerialRepository`/`exchange_service` behavior, statements service query details, `AppScreen.serviceJobs` → screen mapping.
- **Unverified:** RBAC `RolePermissions`/`Permission` matrix internals; multi-firm support; offline/sync correctness for serial/warranty; whether GoRouter modules (`mobile_shop`/`computer_shop`) are mounted in the live app; deep responsive/accessibility behavior; bill-creation rendering of serial/warranty columns end-to-end.
- **Skipped (out of scope):** non-electronics business types, backend Node/DynamoDB services, `.archive/` trees, test suites beyond the navigation-graph note.

*End of electronics audit.*
