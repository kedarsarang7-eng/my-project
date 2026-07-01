# DukanX Business-Type Audit — Wholesale / Distribution

> Read-only, evidence-based audit. Every "missing/broken/orphaned" claim cites the file/function checked. Items I could not confirm are marked **unverified**.
>
> **Sampled (read in full or near-full):** `models/business_type.dart`; `core/billing/business_type_config.dart` (wholesale config + emoji/color/pdf extensions, full registry); `widgets/desktop/sidebar_configuration.dart` (`_getSectionsForBusiness`, full `_getRetailSections`, clinic/service/restaurant/petrol variants, `sidebarSectionsProvider` filtering); `widgets/desktop/sidebar_navigation_handler.dart` (full `getScreenForItem`); `core/isolation/business_capability.dart` (`'wholesale'` key + full registry); `core/isolation/feature_resolver.dart` (full); `core/config/business_capabilities.dart` (full); `features/dashboard/v2/widgets/business_quick_actions.dart` + `business_alerts_widget.dart` (full); `modules/wholesale/wholesale_module.dart`, `modules/wholesale/routes/wholesale_routes.dart`, `modules/wholesale/sync/wholesale_sync_handler.dart`, `modules/wholesale/websocket/wholesale_ws_handler.dart` (full); `core/module/legacy_route_redirect.dart` (full).
> **Sampled by directory listing / targeted grep only (internals unverified):** `core/module/module_loader.dart` (`registerAll` includes `WholesaleModule()`), `core/module/module_registry.dart` (`buildNavItems`/`buildRoutes`); `app/routes.dart` (legacy named routes `/billing_flow`, `/delivery_challans`, `/proforma`, `/party_ledger` exist behind `VendorRoleGuard`); `features/billing/presentation/screens/bill_creation_screen_v2.dart` (used by `new_sale`, not opened); `core/session/session_manager.dart` (RBAC `Permission`/`RolePermissions.hasPermission` referenced from sidebar config only); backend Lambda endpoints behind `ApiClient` (`/wholesale/orders`, `/api/v1/delivery-challans`).
> **There is NO `features/wholesale/` folder** (file search returned nothing). Wholesale's runtime UI is the **generic retail sidebar**. A separate `lib/modules/wholesale/` plugin exists but every route is a redirect stub (see §1, §6).

---

## 1. Header — Business Type, Sidebar Resolution, Config, Capabilities

**Business type:** `BusinessType.wholesale` (`Dukan_x/lib/models/business_type.dart`, 10th enum value). `displayName` = "Wholesale", `icon` = `inventory_2_rounded`; `emoji` = 📦, `primaryColor`/`pdfPrimaryColor` = `#0D9488` (Teal) (`business_type_config.dart` extensions). Selection-screen label "Wholesale" / "Bulk & Cartons" (`screens/business_type_selection_screen.dart`).

**Sidebar resolution:** wholesale is **NOT** a dedicated case in `_getSectionsForBusiness()` (`sidebar_configuration.dart`). It falls through to:
```dart
default:
  return _getRetailSections();
```
So wholesale renders the **generic retail sidebar** — 10 sections, ~58 items, **zero wholesale-specific entries**: no tiered/slab pricing, no party-wise rate lists, no e-Way bill, no delivery challan/transport (LR), no credit-limit screen, no salesman/beat/route, no godown/warehouse, no min-order-qty. Full id table in §6.

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

**Config summary** (`BusinessTypeRegistry._configs[BusinessType.wholesale]`):
- requiredFields: `itemName, quantity, price`
- optionalFields: `unit, discount, gst, hsnCode, drugSchedule, batchNo, expiryDate`
- defaultGstRate: `18.0`, gstEditable: `true`
- unitOptions: `pcs, box, kg`
- itemLabel: `Product`, addItemLabel: `Add Product`, priceLabel: `Rate`
- modules: `['inventory','sales','bulk_orders','customers','reports']`
- **Anomaly:** `ItemField.drugSchedule` (a pharmacy-only field) is listed as a wholesale optional field. See §13/§18.

**Capability registry** (`business_capability.dart`, key `'wholesale'`) — wholesale is one of the **most-privileged** types: product add/name/salePrice/stockQty/unit/tax/category; inventory list/visibleStock/**deadStock**/search/**export**; invoice list/search/create/**salesReturn**/**proformaInvoice**/**dispatchNote**; `useLowStockAlert`, `useGeneralAlerts`, `useDailySnapshot`, `useRevenueOverview`; purchase order/stockEntry/**stockReversal**/supplierBill/**purchaseRegister**; specialized **`useStockManagement`, `useMultiUnit`, `useCreditManagement`, `useCreditLimit`, `useTransportDetails`, `useBarcodeScanner`, `useBatchExpiry`**. **Not granted:** `useScanOCR` (no OCR), `useIMEI`/`useWarranty`, `useLoyaltyPoints`, and there is **no capability for e-Way bill, tiered pricing, rate lists, godown, MOQ, or salesman/beat** anywhere in the enum.

**Capability vs sidebar — the gates are inert.** wholesale's specialized capabilities (`useMultiUnit`, `useCreditManagement`, `useCreditLimit`, `useTransportDetails`, `useStockReversal`, `useProformaInvoice`, `useDispatchNote`, `useInventoryExport`) gate **no item** in `_getRetailSections()`. The only capability-gated retail item is `batch_tracking` (gated `useBatchExpiry`), which wholesale **has**, so it shows. Net effect: the rich wholesale capability set changes nothing about navigation — items like `dispatch_notes`, `proforma_bids`, `stock_reversal`, `purchase_register`, `outstanding` are shown to **every** retail-default type regardless of capability (§6, §11).

**Dedicated `modules/wholesale/` plugin — a redirect facade.** `WholesaleModule` (`modules/wholesale/wholesale_module.dart`) is registered in `core/module/module_loader.dart` (`ModuleRegistry.instance.registerAll([... WholesaleModule() ...])`). Its manifest advertises featureKeys `wholesale_basic_bulk_entry`, `wholesale_tiered_pricing`, `wholesale_logistics`, `wholesale_eway_bill`, `wholesale_advanced_ar` and 7 `navItems` (Billing, Inventory, Scan Bill/Purchase, Dispatch, Price Tiers, e-Way Bill, Receivables). **But every route in `modules/wholesale/routes/wholesale_routes.dart` is a `LegacyRouteRedirect` stub** to a generic legacy screen — there are **no real wholesale screens**:

| Module route | Advertised feature | Redirects to (legacy) | Reality |
|---|---|---|---|
| `/wholesale/billing` | bulk entry | `/billing_flow` | generic bill screen |
| `/wholesale/inventory` | bulk entry | `/inventory` | generic inventory |
| `/wholesale/dispatch` | logistics | `/delivery_challans` | generic challan list |
| `/wholesale/pricing` | **tiered pricing** | `/proforma` | **just the proforma screen — no tier engine** |
| `/wholesale/eway` | **e-Way bill** | `/delivery_challans` | **just challan list — no e-Way generation** |
| `/wholesale/ar` | advanced AR | `/party_ledger` | generic ledger |

`LegacyRouteRedirect` (`core/module/legacy_route_redirect.dart`) itself documents that the app still uses the legacy `MaterialApp.routes` map and the `go_router` module routes are "wired in once `MaterialApp` migrates from `routes:` to `routerConfig:`". So whether these module `navItems` are even rendered on the desktop is **unverified** — I found `ModuleRegistry.buildNavItems()` but no production widget consuming it for the desktop shell (the desktop shell uses `sidebarSectionsProvider` → `_getRetailSections`). Either way, the "wholesale module" delivers **zero wholesale-specific functionality**; it relabels generic screens. **Critical.**

---

## 2. Missing Generic (Vyapar Benchmark) Features

| # | Benchmark | Status for wholesale | Evidence | Priority |
|---|-----------|----------------------|----------|----------|
| 1 | Billing/Invoicing | **Present (generic)** — `new_sale` → `BillCreationScreenV2`. B2B GST invoice specifics (party rate auto-pull, case-pack qty) **unverified** (bill screen not opened). | nav handler | — |
| 2 | Inventory (real-time, low-stock, batch/expiry, FIFO, multi-warehouse, reorder, BOM) | **Generic only** — `stock_summary`/`item_stock`/`batch_tracking`/`low_stock`/`stock_valuation`/`damage_logs`. **No godown/multi-warehouse, no FIFO, no reorder/MOQ, no BOM.** Batch/expiry present (cap granted). | sidebar; capability registry | High |
| 3 | Barcode/POS | **Partial** — `useBarcodeScanner` granted; quick-action "Bulk Scan" is a **dead button** (`onTap: () {}`, `business_quick_actions.dart`). No POS-style fast bulk entry. | `business_quick_actions.dart` | High |
| 4 | Accounting | **Inherited generic** — `accounting_reports`, `income_statement`, `invoice_margin`, `daybook`. | sidebar | Low |
| 5 | Receivables/Payables (party ledger, bulk reminders, **credit limits**, bill-wise linking) | **Partial** — `party_ledger`, `outstanding`, `credit_notes` present; `useCreditManagement`/`useCreditLimit` granted **but no credit-limit screen exists** and the cap gates nothing. **Bill-wise payment linking & bulk reminders unverified/likely missing.** | capability registry; sidebar | High |
| 6 | Bank/Cash | **Inherited generic** — `bank_accounts`, `cash_bank`. | nav handler | Low |
| 7 | Orders/Delivery (sales/purchase orders, **delivery challan**, status) | **Partial generic** — `booking_orders`, `dispatch_notes` → `DispatchNoteScreen`; `purchase_orders`. Delivery-challan screen exists (`/delivery_challans`) but is **not in the wholesale sidebar** (only reachable via the orphaned module redirect / hardware command center). No transport/LR fields surfaced. | sidebar; nav handler | High |
| 8 | OCR | **Missing** — `useScanOCR` **not granted** to wholesale; no OCR item. (Module `navItem` "Scan Bill / Purchase" → `/purchase/scan-bill` exists but module nav is unsurfaced.) | capability registry | Medium |
| 9 | Reports (37+) | **Generic hub** — `analytics_hub` → `ReportsHubScreen`. No distributor-specific reports (party-wise sales, scheme/claim, beat/route, stock-ageing by godown). | nav handler | Medium |
| 10 | RBAC + audit | **Partial** — `audit_trail` id maps to `AllTransactionsScreen` (not a real audit log). Retail sidebar items carry **no `permission`** (§11). | nav handler | High |
| 11 | Multi-firm | **Unverified** — not surfaced in wholesale sidebar. | — | Medium |
| 12 | Backup | **Present** — `backup` → `BackupScreen`. | nav handler | Low |
| 13 | Online store | **Partial** — `catalogue` → `CatalogueScreen` (share-only). No B2B dealer ordering portal. | nav handler | Medium |
| 14 | **e-Way bill** (mandatory >₹50k inter-state) | **Missing** — no e-Way id in sidebar; module's `/wholesale/eway` redirects to `/delivery_challans` (not an e-Way generator). No GSP/NIC integration found. | `wholesale_routes.dart`; sidebar grep | **Critical** |
| 15 | Loyalty | **Missing** — `useLoyaltyPoints` not granted (n/a for B2B; trade-scheme equivalent also missing). | capability registry | Low |
| 16 | Service-business | **N/A** for wholesale. | — | — |
| 17 | Offline-first sync | **Generic Drift sync only** — `WholesaleSyncHandler` (`collection: 'wholesale_orders'`, `apiBasePath: '/wholesale/orders'`) is registered, but there is **no wholesale_orders UI or repository** to populate it; the dashboard alert stream (`business_alerts_widget.dart`) reads generic `products`/`product_batches` Drift tables. | `wholesale_sync_handler.dart` | Medium |

---

## 3. Missing Industry-Specific Features (Wholesale / Distribution)

| Need | Status | Evidence | Priority |
|---|---|---|---|
| Bulk / case-pack pricing & multi-unit (box→piece) | **Capability only, no UI** — `useMultiUnit` granted and `unitOptions` include `box`/`pcs`/`kg`, but **no unit-conversion/case-pack screen** exists for wholesale (no `features/wholesale/`). Conversion factor entry unverified in bill screen. | capability registry; config; file search | High |
| Slab / quantity-based pricing tiers | **Missing (facade)** — advertised by featureKey `wholesale_tiered_pricing`; module route `/wholesale/pricing` redirects to `/proforma`. **No tier/slab pricing engine, model, or screen anywhere.** | `wholesale_routes.dart` | **Critical** |
| Party-wise rate lists | **Missing** — no rate-list model/screen; bill uses generic price. | file search (no `features/wholesale/`) | High |
| B2B credit terms, credit limits & aging | **Partial** — `useCreditLimit`/`useCreditManagement` granted; `outstanding` → `PartyLedgerListScreen(initialFilter:'receivable')`. **No credit-limit enforcement screen; ageing buckets unverified.** Dashboard "Credit Limit Alerts" count is **hardcoded** (§5/§8). | capability registry; nav handler; `business_alerts_widget.dart` | High |
| Bill-wise outstanding & payment linking | **Unverified / likely missing** — generic `party_ledger`/`outstanding` only; no bill-wise allocation UI found in sampled files. | nav handler | High |
| e-Way bill (>₹50k inter-state) | **Missing** — see §2 #14. | `wholesale_routes.dart` | **Critical** |
| Delivery challan & transport/LR details | **Partial** — `DeliveryChallanListScreen` exists at `/delivery_challans` (`app/routes.dart`) but **not in wholesale sidebar**; transport/vehicle/LR field surfacing unverified. `useTransportDetails` granted but gates nothing. | sidebar; capability registry | High |
| Salesman / beat / route & order booking | **Missing** — `booking_orders` → `BookingOrderScreen` (generic) only; no beat/route/salesman model or screen. | nav handler; file search | High |
| GST B2B invoicing | **Generic** — `gstr1`, `b2b_b2c`, `hsn_reports` present; B2B party-GSTIN auto-capture in bill unverified. | sidebar | Medium |
| Schemes / trade discounts | **Missing** — only line-level `discount`; no scheme/slab/free-qty engine. | config | Medium |
| Min order qty (MOQ) | **Missing** — no MOQ field/validation; dashboard alert "Below MOQ levels" is **hardcoded text** with no backing logic (§8). | `business_alerts_widget.dart`; config | Medium |
| Godown / warehouse stock | **Missing** — no warehouse model or multi-location stock; generic single-stock inventory. | sidebar; file search | High |
| Purchase from manufacturers | **Generic** — `purchase_orders`, `supplier_bills`, `procurement_log`, `purchase_register` present. | sidebar | Low |
| Statement / ledger to dealers | **Generic** — `party_ledger`, `ledger_abstract`. Bulk dealer-statement print/email unverified. | nav handler | Medium |

---

## 4. Missing UI Components

- **No tiered-pricing form / rate-list editor** — there is no wholesale screen at all (`features/wholesale/` absent). The advertised "Price Tiers" opens the proforma screen (`wholesale_routes.dart` → `/proforma`). Critical.
- **No e-Way bill form** — no transporter/distance/vehicle/GSTIN capture, no JSON export to NIC. The "e-Way Bill" nav redirects to the challan list. Critical.
- **No credit-limit configuration UI** despite `useCreditLimit` capability; "Credit Check" quick-action only opens the generic `outstanding` ledger filter. High.
- **No godown/warehouse selector** anywhere in inventory/billing for wholesale. High.
- **Dead button:** `business_quick_actions.dart` wholesale branch → "Bulk Scan" `onTap: () {}` (no-op). Medium.
- **No MOQ / case-pack input** on item entry (config has no MOQ field). Medium.

---

## 5. Missing Widgets & Dashboard / KPI Cards

- **Dashboard alerts are HARDCODED for wholesale.** `business_alerts_widget.dart` `_buildAlertsForBusiness` (wholesale branch):
  - "Bulk Stock Low / Below MOQ levels" → `count: '15'` (string literal)
  - "Credit Limit Alerts / Customers near limit" → `count: '7'` (gated by `caps.accessCreditLimit`, which is **true** for wholesale)
  Neither value comes from a repository. The widget's `alertCountsProvider` fetches only generic `lowStock`/`expiringSoon` from Drift, and those are consumed **only** by the grocery branch. So wholesale alerts never reflect real data. High.
- **Title is correct but data is fake** — `_getTitle(BusinessType.wholesale)` returns "Bulk Order Alerts" (confirms expectation); the underlying counts are the hardcoded values above. Medium.
- **Quick actions don't reach any wholesale feature** — `business_quick_actions.dart` wholesale branch: "Bulk Entry" → `AppScreen.stockEntry`; "Bulk Scan" → dead; "Credit Check" → `AppScreen.outstanding`. No tiered-pricing, e-Way, dispatch, or rate-list action. High.
- **No distributor KPI cards** — no party-wise outstanding aging, no top-dealer revenue, no scheme liability, no stock-ageing-by-godown, no dispatch-pending funnel. None exist. Medium.

---

## 6. Navigation & Route Gaps

**Retail sidebar id → screen resolution** (`sidebar_navigation_handler.dart getScreenForItem`). All ~58 ids in `_getRetailSections()` resolve to a real screen (none hit the `default` placeholder). Notable **alias/placeholder** mappings shared with all retail-default types:

- `turnover_analysis`, `daily_activity`, `ledger_history`, `transaction_reports`, `activity_logs`, **`audit_trail`** → all `AllTransactionsScreen` (audit_trail is **not** a real audit log — High).
- `ledger_abstract` → `TrialBalanceScreen`; `outstanding` → `PartyLedgerListScreen(initialFilter:'receivable')`; `suppliers` → `PartyLedgerListScreen(initialFilter:'supplier')`.
- `invoice_margin` & `income_statement` → both `PnlScreen`; `funds_flow` & `cash_bank` → both `CashflowScreen`.
- `gstr1` & `b2b_b2c` → both `GstReportsScreen(initialIndex:0)`.
- `purchase_register` → `ProcurementLogScreen` (reuses procurement log); `sync_status` → `BackupScreen`; `doc_templates` & `print_settings` → both `PrintMenuScreen`.

**Capability-vs-sidebar mismatches (inert gates):** wholesale is granted `useMultiUnit`, `useCreditManagement`, `useCreditLimit`, `useTransportDetails`, `useStockReversal`, `useProformaInvoice`, `useDispatchNote`, `useInventoryExport`, `useGeneralAlerts`, `useDeadStock`, `useSalesReturn` — **none of these gate a sidebar item**, so they have no navigation effect. Conversely, retail items `stock_reversal`, `dispatch_notes`, `proforma_bids`, `return_inwards`, `purchase_register` are shown **ungated** to every retail-default type (electronics/computerShop/hardware/etc.) even where the capability is **not** granted — a capability-bypass surface (§11).

**Orphaned screens / dead links:**
- Wholesale's dedicated **module nav items** (`wholesale_billing`, `wholesale_inventory`, `wholesale_scan_bill`, `wholesale_dispatch`, `wholesale_pricing`, `wholesale_eway`, `wholesale_ar` in `wholesale_module.dart`) are **not present** in the desktop `_getRetailSections()` sidebar. Whether `ModuleRegistry.buildNavItems()` surfaces them in any live shell is **unverified** (no consumer found in sampled desktop code). If unsurfaced, all 7 are orphaned; if surfaced, they lead to redirect stubs. Critical/unverified.
- Delivery-challan screen (`/delivery_challans` → `DeliveryChallanListScreen`, `app/routes.dart`) is **not** linked from the wholesale sidebar despite being highly relevant. High.
- `vendor_payouts` has a handler case (`getScreenForItem`) and import but **no sidebar item** references it in `_getRetailSections()` — orphaned handler (Low; shared retail issue).

**Miscategorized:** `dispatch_notes` and `booking_orders` sit under "Revenue Desk" rather than an Orders/Logistics group — acceptable but not distributor-oriented. Low.

---

## 7. Backend Integration Gaps

- **Sync handler with no producer.** `WholesaleSyncHandler` (`modules/wholesale/sync/wholesale_sync_handler.dart`) syncs collection `wholesale_orders` to `/wholesale/orders`, but no UI/repository creates `wholesale_orders` records (no `features/wholesale/`). The handler is effectively dormant. Medium.
- **WS handler listens for events nothing emits locally.** `WholesaleWsHandler` (`modules/wholesale/websocket/wholesale_ws_handler.dart`) handles `wholesale.order.placed`, `wholesale.stock.low`, `wholesale.dispatch.updated` and raises local notifications. These depend on a backend pushing those events; no client code emits them. Functional only if the server sends them — **unverified**. Medium.
- **Generic billing/inventory/ledger** go through the shared `ApiClient` + Drift repos (e.g. `ProductsRepository.getLowStockProducts`, `db.productBatches` in `business_alerts_widget.dart`). No wholesale-specific endpoints beyond `/wholesale/orders` (unused). Medium.
- **e-Way / tiered-pricing backends** — none referenced anywhere. Critical (feature absent end-to-end).

---

## 8. Database & API Issues (Real vs Mock; Hardcoded Counts)

- **Hardcoded dashboard counts (confirmed):** `business_alerts_widget.dart` wholesale branch → "Bulk Stock Low" `count: '15'`, "Credit Limit Alerts" `count: '7'`. Both are literals, not query results. High.
- **Real data path exists but unused by wholesale:** `alertCountsProvider` (same file) computes real `lowStock` (`productsRepo.getLowStockProducts`) and `expiringSoon` (`db.productBatches` expiry window) counts — but the wholesale branch ignores `counts` entirely. So a working query is bypassed in favor of literals. High.
- **No wholesale tables surfaced:** alert/inventory reads hit generic `products`/`product_batches`. `wholesale_orders` (sync registry) has no read path. Medium.
- **Credit-limit data:** no evidence of a credit-limit field/threshold being read from DB for the "near limit" alert — the '7' is fabricated. High.
- Real-vs-mock for the generic shared screens (`BillCreationScreenV2`, `PartyLedgerListScreen`, etc.) **unverified** (not opened).

---

## 9. Responsive Design

- Sidebar supports `expanded/collapsed/mini` (`SidebarMode`, `sidebar_configuration.dart`) — generic, applies to wholesale.
- Wholesale has **no dedicated screens**, so no wholesale-specific responsive concerns to assess; the redirect splash (`LegacyRouteRedirect`) is a simple centered `Column` (fine on all widths). 
- Generic screen responsiveness **unverified** (screens not opened). Low.

---

## 10. Performance

- `sidebarSectionsProvider` is a memoized Riverpod `Provider` recomputed only when `businessTypeProvider`/`authStateProvider` change (documented in file) — good; not per-frame.
- `alertCountsProvider` runs two DB queries on every qualifying UNS/event tick; for wholesale the result is **discarded** (literals used), so it's wasted work but low-volume. Low.
- `LegacyRouteRedirect` schedules a `pushReplacementNamed` in a post-frame callback — adds one extra frame + a throwaway splash per module-route navigation. Minor. Low.
- No large wholesale lists to assess (no screens). Remaining perf **unverified**.

---

## 11. Security (RBAC, Capability-Bypass)

- **No RBAC on retail sidebar items.** Every `SidebarMenuItem` in `_getRetailSections()` has `permission: null` (none set). `sidebarSectionsProvider` only enforces `item.permission` when non-null, so **no nav item is RBAC-filtered** for wholesale. Sensitive items (`bank_accounts`, `accounting_reports`, `audit_trail`, `expenses`, `credit_notes`, `outstanding`) are shown to all roles. Screen-level guards (`VendorRoleGuard` in `app/routes.dart`) may still apply, but the **sidebar exposes them**. High.
- **Capability-bypass via ungated items.** Because the retail sidebar gates only `batch_tracking` (cap `useBatchExpiry`), capabilities exist that don't restrict the menu. For wholesale this mostly under-delivers (granted caps unused). For **other** retail-default types it over-exposes (items shown without the matching capability). The hard-isolation enforcement (`FeatureResolver.enforceAccess`, throws `SecurityException`) protects repo/back-end layers, but the **sidebar does not call it for these items** — UI exposure vs enforced access can diverge. High.
- **No audit trail.** `audit_trail` → `AllTransactionsScreen` (transaction list), not a tamper-evident audit log. High.

---

## 12. Offline Mode Gaps

- Generic alert counts read from local **Drift** (`AppDatabase`, `product_batches`) with a UNS-stream/`EventDispatcher` fallback (`business_alerts_widget.dart`) — works offline for generic data.
- **Wholesale-specific data has no offline story** — `wholesale_orders` sync handler exists but no local table read/write UI; tiered pricing, rate lists, e-Way, credit limits don't exist to cache. Medium.
- `LegacyRouteRedirect` is offline-safe (pure navigation). Low.
- Sync conflict/queue behavior for `wholesale_orders` **unverified** (`BaseModuleSyncHandler` not opened).

---

## 13. Business Logic Inconsistencies

- **Pharmacy field leaking into wholesale config.** `business_type_config.dart` wholesale `optionalFields` includes `ItemField.drugSchedule` (and `batchNo`/`expiryDate`). `drugSchedule` is a pharmacy/clinic concept with no wholesale meaning; it will surface a "Drug Schedule" input on wholesale item entry if the bill screen renders optional fields. Medium.
- **`gstEditable: true` + `defaultGstRate: 18.0`** is reasonable for mixed B2B goods, but combined with no HSN-driven rate logic, multi-rate cart correctness is **unverified**. Low.
- **Module advertises features it doesn't implement.** `wholesale_module.dart` manifest lists `wholesale_tiered_pricing`/`wholesale_eway_bill`/`wholesale_advanced_ar` as featureKeys, but routes redirect to generic proforma/challan/ledger — feature flags imply capabilities that don't exist. High.
- **`useCreditLimit` granted with no enforcement** — capability present, no limit-check logic found. Medium.
- **`useMultiUnit` granted with no conversion logic surfaced** — box→pcs factor entry not found for wholesale. Medium.

---

## 14. Data Validation Issues

- **No MOQ / case-pack validation** — config lacks a min-qty or pack-size field; bulk quantities are free numeric (validation in `BillCreationScreenV2` **unverified**). Medium.
- **No credit-limit validation at billing** — selling beyond a dealer's limit is not blocked (no limit data/logic). High.
- **`drugSchedule` optional field** would accept arbitrary input on a wholesale bill with no schedule master relevance. Low.
- **e-Way threshold validation absent** — no check for >₹50k inter-state requiring an e-Way number. High.
- Generic field-level validation in shared screens **unverified** (not opened).

---

## 15. UX Problems

- **Misleading labels.** "Price Tiers" and "e-Way Bill" nav items (if surfaced) open a proforma screen and a challan list respectively (`wholesale_routes.dart`) — users expecting tier setup or e-Way generation get an unrelated screen after a redirect splash. High.
- **Generic retail vocabulary.** Sidebar says "Customers"/"Suppliers"/"Sales Register" rather than distributor terms (Dealers/Beat/Rate List). The config `itemLabel` is "Product" (appropriate). Medium.
- **Dead "Bulk Scan" quick action** gives no feedback (`onTap: () {}`). Medium.
- **Fake alert counts** ("15 Bulk Stock Low", "7 Credit Limit Alerts") erode trust once users notice they never change. High.
- **No entry point** to dispatch/delivery-challan from the wholesale sidebar despite being core to distribution. High.

---

## 16. Accessibility

- Sidebar items use `IconData` + text labels (`SidebarMenuItem`) — readable, but no explicit `Semantics`/tooltip in sampled config. Generic.
- `LegacyRouteRedirect` shows an icon + title + "Opening …" text (`legacy_route_redirect.dart`) — has text, but the auto-redirect may be too fast for screen-reader announcement. Low.
- Alert count badges are color + number; color-only severity (red/amber) without text severity may fail contrast/colorblind needs (`business_alerts_widget.dart` `_buildAlertItem`). Low/Medium.
- Full a11y (focus order, contrast, screen-reader labels) on generic screens **unverified** — requires manual assistive-tech testing.

---

## 17. Bugs / Errors / Crash Scenarios

- **No-op button:** "Bulk Scan" quick action (`business_quick_actions.dart`) — not a crash, but a dead control. Medium.
- **Redirect on missing legacy route:** `LegacyRouteRedirect` calls `Navigator.pushReplacementNamed(legacyRoute)`; if a target (`/billing_flow`, `/delivery_challans`, `/proforma`, `/party_ledger`) were absent from `MaterialApp.routes` it would throw. I confirmed all four exist in `app/routes.dart` (behind `VendorRoleGuard`), so this is safe **today**; a future route rename would crash the redirect. Low.
- **`context.mounted` guard present** in `LegacyRouteRedirect` post-frame callback — avoids use-after-dispose. Good.
- **Stale/fake counts** are not crashes but are functional bugs (§5/§8). High.
- Crash behavior of generic shared screens under wholesale data **unverified**.

---

## 18. Unnecessary / Irrelevant Features Shown (Shared Retail Sidebar)

The generic retail sidebar shows wholesale users many items with low/no distributor relevance, and hides the relevant ones:

- **`batch_tracking`** (shows because `useBatchExpiry` granted) — useful only for perishable/dated FMCG wholesale; fine but config also injects pharmacy `drugSchedule`. 
- **`warranty`-style / repair items** — not in retail sidebar (good).
- **Irrelevant-leaning items shown:** `proforma_bids` relabeled as the wholesale "tiered pricing" target adds confusion; `catalogue` (share-only) is weak for B2B. 
- **`drugSchedule` optional field** on wholesale items is irrelevant (§13). 
- **Missing-but-expected, shown-as-generic:** there is no Dealers/Rate-List/Beat/Godown/e-Way grouping — the whole sidebar is generic retail. 

**Flag:** wholesale shares 100% of its sidebar with the retail default; nothing is tailored. Medium–High (relevance), and the redirect "module" is a facade (Critical).

---

## 19. Recommendations & Prioritized Implementation Plan

**Critical**
1. **Build real wholesale screens or stop advertising them.** Either implement `features/wholesale/` (tiered/slab pricing engine, e-Way bill generator, party rate lists, credit-limit enforcement, godown stock) or remove the misleading `wholesale_module.dart` featureKeys/navItems and redirect stubs (`wholesale_routes.dart`) so the app doesn't promise tiered pricing/e-Way that resolve to proforma/challan.
2. **e-Way bill feature** — add a dedicated screen + NIC/GSP JSON export + >₹50k inter-state validation; wire to a real `useEWayBill` capability.
3. **Tiered/slab pricing + party-wise rate lists** — add model, editor screen, and bill-time auto-pricing; back with a real capability.

**High**
4. **Add a dedicated `_getWholesaleSections()`** in `sidebar_configuration.dart` (replace the `default → _getRetailSections()` fallthrough) with distributor groups: Orders & Dispatch (booking, dispatch/delivery challan, e-Way), Pricing (tiers, rate lists, schemes), Receivables (credit limits, ageing, bill-wise), Godown stock. Add a `case BusinessType.wholesale:` branch.
5. **Replace hardcoded dashboard counts** in `business_alerts_widget.dart` wholesale branch with real queries (extend `alertCountsProvider` to compute below-MOQ stock and customers-near-credit-limit).
6. **Credit-limit enforcement** — add limit field + block/warn at billing; surface a real credit-limit screen behind `useCreditLimit`.
7. **Surface delivery challan + transport/LR** in the wholesale sidebar and bill flow (`useTransportDetails` is already granted).
8. **RBAC on sidebar** — set `permission:` on sensitive items (`bank_accounts`, `accounting_reports`, `audit_trail`, `expenses`, `credit_notes`, `outstanding`) so `sidebarSectionsProvider` filters by role.
9. **Wire "Bulk Scan"** quick action to the barcode scanner (`useBarcodeScanner` granted).

**Medium**
10. Remove `ItemField.drugSchedule` from wholesale `optionalFields` (config) — pharmacy leak.
11. Add MOQ/case-pack/godown fields to the item config + validation.
12. Provide a true audit-log screen for `audit_trail` (currently `AllTransactionsScreen`).
13. Connect `wholesale_orders` sync handler to a real order entity, or remove it.
14. Add distributor reports (party-wise sales, ageing-by-godown, scheme liability, beat/route).

**Low**
15. Add multi-firm surfacing if supported; verify offline conflict handling for wholesale data; a11y labels/contrast on alert badges.

---

## 20. Confidence & Coverage

- **High confidence (read in full):** sidebar resolution (`default → _getRetailSections`), full retail sidebar id set, `getScreenForItem` mappings, wholesale config block, wholesale capability registry, `FeatureResolver`, `BusinessCapabilities`, dashboard quick-actions + alerts wholesale branches (hardcoded counts), the entire `modules/wholesale/` plugin (module, routes, sync, ws) and `LegacyRouteRedirect`.
- **Medium confidence (grep/listing, internals not opened):** module registration in `module_loader.dart`/`module_registry.dart`; existence of legacy routes in `app/routes.dart`; whether module `navItems` are rendered in any live shell (no desktop consumer found → likely unsurfaced, marked unverified).
- **Not verified (explicitly out of read scope):** `BillCreationScreenV2` line-item rendering of wholesale optional fields (incl. `drugSchedule`), `PartyLedgerListScreen`/`DispatchNoteScreen`/`BookingOrderScreen` internals, RBAC matrices in `session_manager.dart`, `BaseModuleSyncHandler` conflict logic, all backend Lambda behavior behind `ApiClient` (`/wholesale/orders`, `/api/v1/delivery-challans`), and generic-screen responsiveness/a11y/crash behavior.
- **Coverage estimate:** ~90% of wholesale-specific wiring (config, capabilities, navigation resolution, dashboard widgets, dedicated module) directly inspected; ~10% (shared generic screens + backend + live module-nav surfacing) inferred or marked unverified.

**Top finding:** Wholesale has **no dedicated UI** — it runs the generic retail sidebar (`default → _getRetailSections`), and the only "wholesale-specific" code, `lib/modules/wholesale/`, is a **facade**: all 6 routes are `LegacyRouteRedirect` stubs where "tiered pricing"→proforma and "e-Way bill"→delivery-challan, despite manifest featureKeys claiming those capabilities.
