# DukanX Business-Type Audit — Grocery

> Read-only, evidence-based audit. Every "missing/broken/orphaned" claim cites the file/function checked. Items I could not confirm are marked **unverified**.

---

## 1. Header — Business Type, Sidebar Resolution, Config Summary

**Business type:** `BusinessType.grocery` (`Dukan_x/lib/models/business_type.dart`, first enum value). `displayName` = "Grocery Store", `icon` = `shopping_basket_rounded`, `emoji` = 🛒, `primaryColor` = `#059669` (Emerald) — `business_type_config.dart` extensions.

**Sidebar resolution:** Grocery is **not** a dedicated case in `_getSectionsForBusiness()` (`Dukan_x/lib/widgets/desktop/sidebar_configuration.dart`). The switch handles `clinic`, `pharmacy`, `restaurant`, `petrolPump`, `electronics/mobileShop/computerShop` (→ retail), `service`, and everything else falls to `default: _getRetailSections()`. **Grocery therefore renders the full 10-section enterprise "retail" sidebar** (Dashboard & Control, Revenue Desk, BuyFlow, Inventory & Stock, Parties & Ledger, Business Intelligence, Financial Reports, Tax & Compliance, Operations & Logs, Utilities & System).

**Config summary** (`BusinessTypeRegistry._configs[BusinessType.grocery]`, `business_type_config.dart`):
- requiredFields: `itemName, quantity, unit, price`
- optionalFields: `discount, gst, brand`
- defaultGstRate: `0.0`, gstEditable: `true`
- unitOptions: `pcs, kg, gm, ltr, nos`
- itemLabel: `Item`, addItemLabel: `Add Item`, priceLabel: `Rate`
- modules: `['inventory','sales','returns','expenses','reports']`

**Capability registry** (`Dukan_x/lib/core/isolation/business_capability.dart`, key `'grocery'`): product add/name/price/qty/unit/tax/category; inventory list/visible/dead/search; invoice list/search/create; low-stock + general alerts + daily snapshot + revenue overview; purchase order + stock entry + supplier bill; legacy `useBarcodeScanner`, `useScanOCR`, `useStockManagement`, `useLowStockAlerts`, `useBatchExpiry`, `useVoiceInput`. **Notably NOT granted:** `useSalesReturn`, `useProformaInvoice`, `useDispatchNote`, `useStockReversal`, `usePurchaseRegister`, `useInventoryExport`.

**Architectural note (important):** There are TWO parallel module systems in the repo and only one is live:
- **Live:** `ModuleLoaderService` (`core/services/module_loader_service.dart`) — stores active module IDs; wired via DI (`service_locator.dart`) and `integrity_jobs.dart` (`.init()`), and used in onboarding/license screens.
- **Dead/unwired:** `ModuleLoader` (`core/module/module_loader.dart`) + `GroceryModule` (`modules/grocery/grocery_module.dart`). `ModuleLoader.instance.initialize()` is **never called** anywhere (grep across `Dukan_x/lib/**` returns only the definition), and `ModuleRouteBuilder.buildRoutes()` appears only in a comment. So the grocery plugin's routes/navItems are never mounted (see §6).

---

## 2. Missing Generic (Vyapar Benchmark) Features

| # | Benchmark | Status in grocery | Evidence | Priority |
|---|-----------|-------------------|----------|----------|
| 1 | Billing/Invoicing (GST, multi-format, quote→invoice, WhatsApp/SMS/email, thermal+A4) | **Partial** — billing exists (`bill_creation_screen_v2.dart`); PDF templates exist (`core/pdf/invoice_template_factory.dart`, `adaptive_pdf_layouts.dart`, thermal in `bill_print_service.dart`). WhatsApp/SMS/email share **unverified** (not located in billing screen). | grep | Medium |
| 2 | Inventory (real-time, low-stock, batch/expiry, FIFO, multi-warehouse, reorder, BOM) | **Partial** — stock summary/valuation/low-stock/batch screens wired. Multi-warehouse, FIFO, BOM, reorder points **not found** — **unverified/likely missing**. | nav handler imports | High |
| 3 | Barcode/POS (generate+scan, POS counter, item/bill discount, weighing scale, cashier reports) | **Partial** — barcode scan is real in billing (`_handleBarcodeScan`, `BarcodeScannerService`, F2 shortcut). **Weighing scale UI exists but is orphaned** (§5). Cashier-wise/counter-close reports **not found**. | bill_creation_screen_v2.dart 1007-1060 | High |
| 4 | Accounting (auto-ledger, GST/non-GST expense cats, multi-currency, multi-language) | **Partial** — P&L/trial balance/daybook/accounting screens wired. Multi-currency **not found**; multi-language partially (validate-translations workflow exists). | nav handler | Medium |
| 5 | Receivables/Payables (party ledger, bulk reminders, credit limits, bill-wise) | **Partial** — party ledger + outstanding wired; credit limit capability **not granted to grocery** (`accessCreditLimit` false). Bulk reminders **unverified**. | capability registry | Medium |
| 6 | Bank/Cash (multi-bank, cheque/UPI/card/wallet, overdraft, loans) | **Partial** — `bank_accounts`→BankScreen, cash/bank summary→CashflowScreen. Overdraft/loans **not found**. | nav handler | Low |
| 7 | Orders/Delivery (sales/purchase orders, delivery challan, status) | **Inconsistent** — `booking_orders`, `dispatch_notes` shown in grocery sidebar but `useDispatchNote` is **denied** in capability registry (§13). | sidebar vs registry | Medium |
| 8 | OCR bill scan→purchase entry | **Capability granted** (`useScanOCR`) and a `/purchase/scan-bill` nav item exists in the **dead** GroceryModule. No OCR entry point in the live retail sidebar — **effectively missing**. | grocery_module.dart navItems; sidebar | High |
| 9 | Reports (37+, P&L, BS, GST, stock, outstanding; PDF/Excel) | **Strong** — large report suite wired (reports/gst screens). Excel export = `useInventoryExport` is **denied** for grocery. | capability registry | Low |
| 10 | Multi-user RBAC + audit trail | **RBAC real** (`session_manager.dart` `RolePermissions`, `effectiveRole`, business_users). **Audit trail is fake**: sidebar `audit_trail` → `AllTransactionsScreen` (not a real immutable audit log). | nav handler `case 'audit_trail'` | High |
| 11 | Multi-firm | **Partial** — session has `activeBusinessId`/`setActiveBusiness` + multi-role picker. Firm-switch UI **unverified**. | session_manager.dart | Low |
| 12 | Encrypted cloud backup + restore | **Partial** — `backup`→`BackupScreen`. Encryption claim **unverified** (BackupScreen not read). | nav handler | Medium |
| 13 | Online store catalog + order link | **Partial** — `catalogue`→`CatalogueScreen`. Customer-facing order link **unverified**. | nav handler | Low |
| 14 | e-Way bill | **Missing** — no e-Way bill screen/route found (grep). | grep | Low |
| 15 | Loyalty/discount schemes | **Missing for grocery** — `useLoyaltyPoints` granted to jewellery/bookstore only, not grocery. | capability registry | Medium |
| 16 | Service-business (appointments, service+tip) | N/A for grocery. | — | — |
| 17 | Offline-first auto-sync | **Partial/real** — Drift local DB + UNS/EventDispatcher streams (`business_alerts_widget.dart`). Full sync correctness **unverified** (§12). | business_alerts_widget.dart | Medium |

---

## 3. Missing Industry-Specific Features (Grocery)

| Feature | Status | Evidence | Priority |
|---------|--------|----------|----------|
| Weighing-scale / loose-quantity billing | **Broken/orphaned** — `WeighingScaleWidget` (`Dukan_x/lib/widgets/weighing_scale_widget.dart`) is fully built (tare, kg/g toggle, ₹/kg total, "ADD TO BILL") but is referenced **nowhere** (grep `WeighingScaleWidget` = definition only). Billing's weight sheet (`bill_creation_screen_v2.dart` ~639-797) is **Mandi-only** (gross/tare/net + commission/lotId), gated for `vegetablesBroker`, not grocery. | grep + bill screen | **Critical** |
| Barcode/quick-add | **Working** in billing (`_handleBarcodeScan`), but the **dashboard** "Scan Barcode" quick action has an **empty `onTap: () {}`** (does nothing). | business_quick_actions.dart grocery case | High |
| MRP vs selling price | **Partial** — `MrpEnforcementValidator` (`utils/mrp_enforcement_validator.dart`) targets pharmacy/FMCG; PDF shows "MRP" column. Grocery item entry uses `price`/`sellingPrice` only — no separate MRP-vs-sale field in grocery config. | config + grep | Medium |
| Fast multi-item POS | **Partial** — billing supports search/scan/voice add. No dedicated grocery POS counter screen (the real one is the dead `GroceryModule` `/grocery/billing` placeholder). | grocery_routes.dart | High |
| Daily counter cash closing | **Missing** — no day-close/cash-drawer reconciliation screen found; `daily_snapshot`→`DailySnapshotScreen` is a summary, not a counter close. | grep/nav handler | High |
| Frequently-bought / credit khata customers | **Partial** — credit payment chip gated by `FeatureResolver(...).showCreditLedger` in billing (~1459). Khata ledger = party ledger. No "frequently bought" quick reorder. | bill_creation_screen_v2.dart | Medium |
| Expiry on perishables | **Inconsistent/broken** — grocery has `useBatchExpiry` capability and a "batch_tracking" sidebar item, but `BusinessCapabilities.supportsExpiry` is **hardcoded false for grocery** (`business_capabilities.dart`: `supportsExpiry: type != BusinessType.grocery && ...`). So the dashboard "Items Expiring Soon" alert is permanently suppressed even though the alert query computes `expiringSoon`. | business_capabilities.dart | High |
| Multi-rate (retail/wholesale) pricing | **Missing** — no retail/wholesale price tier in grocery config or billing; single `sellingPrice` only. | config + bill screen | Medium |

---

## 4. Missing UI Components

- **No grocery-tailored billing UI.** Grocery uses the generic `BillCreationScreenV2`. The weight-entry sheet is Mandi-specific; there is no loose-weight grocery line entry. Priority: High. (`bill_creation_screen_v2.dart`)
- **No counter/cash-drawer close UI.** Priority: High.
- **Weighing scale component exists but has no host screen.** Priority: Critical (wasted asset). (`weighing_scale_widget.dart`)
- **No quick "reorder favourites" / frequent-items panel** for fast grocery checkout. Priority: Medium.
- **Dashboard "Scan Barcode" button is a no-op** — UI present, action missing. Priority: High. (`business_quick_actions.dart`)

---

## 5. Missing Widgets & Dashboard / KPI Cards

- **Dashboard quick actions** (`business_quick_actions.dart`, grocery case): "Quick Add Item"→`stockEntry`, "Scan Barcode"→**empty onTap (bug)**, "Expiry Check"→`batchTracking`, plus shared "New Sale" and "Alerts". The "Scan Barcode" tile only appears if `caps.supportsBarcodeScan` (true for grocery) — but it does nothing. Priority: High.
- **Dashboard alerts** (`business_alerts_widget.dart`, grocery case): **uses REAL data** — `alertCountsProvider` pulls `lowStock` from `ProductsRepository.getLowStockProducts` and `expiringSoon` from Drift `productBatches` (≤7 days). This is one of the few real-data cases (most other business types use hardcoded counts like '5','15'). **However** the "Items Expiring Soon" branch is gated on `caps.supportsExpiry`, which is hardcoded false for grocery (§3), so expiring items never surface despite being computed. Priority: High.
- **KPI cards on the shared owner dashboard** (`features/dashboard/presentation/screens/owner_dashboard_screen.dart` / `dashboard_controller.dart`): not read in full — **the specific KPI set is unverified**. Recommend confirming grocery-relevant KPIs (today's sales, items sold, cash-in-drawer, top sellers, near-expiry count). Priority: Medium.

---

## 6. Navigation & Route Gaps

**Method:** Cross-checked every sidebar id grocery renders (`_getRetailSections()`) against `SidebarNavigationHandler.getScreenForItem()`.

**Result: every grocery sidebar id resolves to a real screen — none hit the `_PlaceholderScreen` ("Feature Not Found") default.** But there are many **duplicate/placeholder mappings** (multiple ids → same screen), which are effectively miscategorized links:

| Sidebar id | Resolves to | Note |
|---|---|---|
| executive_dashboard | DashboardController | ok |
| live_health | LiveBusinessHealthScreen | ok |
| alerts | AlertsNotificationsScreen | ok |
| daily_snapshot | DailySnapshotScreen | ok |
| revenue_overview / new_sale / receipt_entry / return_inwards / proforma_bids / booking_orders / dispatch_notes / sales_register | dedicated screens | ok (but return/proforma/dispatch conflict with capabilities — §13) |
| buyflow_dashboard / purchase_orders / stock_entry / stock_reversal / procurement_log / supplier_bills | dedicated screens | ok |
| **purchase_register** | **ProcurementLogScreen** | **duplicate of procurement_log** |
| stock_summary / item_stock / batch_tracking / low_stock / stock_valuation / damage_logs | dedicated screens | ok (batch_tracking gated by `useBatchExpiry` — grocery passes) |
| customers / suppliers / party_ledger / outstanding | Customers/PartyLedger screens | `suppliers`/`outstanding` reuse `PartyLedgerListScreen` with filters |
| **ledger_history** | **AllTransactionsScreen** | reused |
| **ledger_abstract** | **TrialBalanceScreen** | reused |
| analytics_hub | ReportsHubScreen | ok |
| **turnover_analysis** | **AllTransactionsScreen** | "Placeholder mapping" (comment in code) |
| product_performance | ProductPerformanceScreen | ok |
| **daily_activity** | **AllTransactionsScreen** | reused |
| procurement_insights | PurchaseReportScreen | ok |
| margin_analysis | BillWiseProfitScreen | ok |
| insights / catalogue | InsightsScreen / CatalogueScreen | ok |
| **invoice_margin** + **income_statement** | **both PnlScreen** | duplicate |
| **funds_flow** + **cash_bank** | **both CashflowScreen** | duplicate |
| financial_position | BalanceScreen | ok |
| accounting_reports / bank_accounts / daybook / credit_notes / expenses | dedicated screens | ok |
| **gstr1** + **b2b_b2c** | **both GstReportsScreen(initialIndex: 0)** | duplicate tab |
| hsn_reports / tax_liability / filing_status | GstReportsScreen(initialIndex 1/2/3) | ok |
| transaction_reports | AllTransactionsScreen | ok |
| **activity_logs** | **AllTransactionsScreen** | reused |
| **audit_trail** | **AllTransactionsScreen** | **not a real audit trail** |
| error_logs | ErrorLogsScreen | ok |
| **print_settings** + **doc_templates** | **both PrintMenuScreen** | duplicate |
| backup | BackupScreen | ok |
| **sync_status** | **BackupScreen** | reused (not a real sync dashboard) |
| device_settings | DeviceSettingsScreen | ok |

**Orphaned screens that exist but aren't reachable for grocery:**
- **`GroceryModule` routes** `/grocery/billing`, `/grocery/inventory`, `/grocery/batches`, `/grocery/reports` (`modules/grocery/routes/grocery_routes.dart`) — these are **placeholder `Text(...)` screens** AND the module router is never mounted (`ModuleLoader.initialize()` never called). The grocery-specific nav items ("Quick Billing", "Scan Bill / Purchase", "Batch & Expiry", "Reports") are unreachable. Priority: High (decide: wire up or delete).
- **`WeighingScaleWidget`** — orphaned (§3/§5).

**Miscategorized:** `audit_trail`, `sync_status`, `purchase_register`, `turnover_analysis`, `daily_activity`, `ledger_history`, `activity_logs` all point at reused generic screens, giving the illusion of distinct features. Priority: Medium (truth-in-navigation).

---

## 7. Backend Integration Gaps

- Billing barcode lookup uses `ProductsRepository.search(barcode, userId)` and `getById` for stock checks (`bill_creation_screen_v2.dart` ~1031, ~1582) — real backend. Good.
- Alerts use `ProductsRepository.getLowStockProducts` + Drift `productBatches` query (`business_alerts_widget.dart`) — real backend. Good.
- **GroceryModule sync/ws handlers** (`grocery_sync_handler.dart`, `grocery_ws_handler.dart`) are registered only through the dead `ModuleRegistry` path — **not active** since `ModuleLoader.initialize()` is never invoked. So grocery-module-scoped sync/websocket channels (`grocery:` prefix) are **not running**. Priority: High (confirm whether grocery relies on these or on the shared sync layer). 
- WhatsApp/SMS/email invoice delivery backend: **unverified** (not located).

---

## 8. Database & API Issues (Real vs Mock/Hardcoded)

- **Real data:** grocery dashboard alerts (Drift + repo), report screens read live maps (`stock_summary_report_screen.dart`, `low_stock_report_screen.dart` read `currentStock`, `purchasePriceCents`, `lowStockThreshold` from data). Billing reads products from repository.
- **Hardcoded/mock (shared widgets, not grocery-specific):** `business_alerts_widget.dart` uses **hardcoded counts** for pharmacy/restaurant/clothing/electronics/hardware/petrolPump/bookStore/autoParts/wholesale/vegetablesBroker/jewellery/service/clinic (e.g., `count: '5'`, `'15'`, `'12'`). **Grocery is NOT affected** (it computes real counts) — but the shared widget is misleading for other types. Flag: shared component.
- **Placeholder in Tally export:** `reports/services/tally_xml_service.dart` line ~267 emits `<LEDGERNAME>$partyName</LEDGERNAME> // Placeholder` — affects exports broadly. Priority: Low for grocery.
- Full `products_repository.dart` and report repositories not read end-to-end — deeper API correctness **unverified**.

---

## 9. Responsive Design Issues

- `WeighingScaleWidget` uses a fixed 48px monospace weight readout and multi-column button row — on narrow/mini sidebar layouts this could overflow, but since it's unmounted this is moot until wired. Priority: Low (until wired).
- The retail sidebar has **10 sections / ~60 items** for grocery; on `SidebarMode.mini`/`collapsed` (`sidebar_configuration.dart` enum) the cognitive load is heavy for a small grocery. Layout behavior across breakpoints **unverified** (shell layout code not read). Priority: Medium.
- `_PlaceholderScreen` was already fixed to use theme-aware colors (comment "FIXED: use theme-aware colors"). No issue there.

---

## 10. Performance Issues

- `sidebarSectionsProvider` is memoized (re-runs only on businessType/auth change) — good (`sidebar_configuration.dart` doc comment).
- `alertCountsProvider` re-fetches on every matching UNS event; the Drift batch query filters server-side — acceptable. Re-fetch frequency under heavy stock churn **unverified**. Priority: Low.
- Grocery renders ~60 sidebar items each build; `where(...).toList()` filtering runs per rebuild of the provider (memoized) — acceptable. Priority: Low.
- Bill screen re-computes cgst/sgst per line on each qty change inline — fine for typical cart sizes. Priority: Low.

---

## 11. Security Concerns

- **Hard isolation** is enforced via `FeatureResolver.canAccess` / `enforceAccess` (throws `SecurityException`) — good design (`feature_resolver.dart`).
- **Gap:** sidebar items WITHOUT a `capability:` field bypass isolation. Grocery shows `return_inwards`, `proforma_bids`, `dispatch_notes`, `booking_orders`, `stock_reversal`, `purchase_register` even though the grocery capability registry **denies** the corresponding capabilities. The capability gate only runs when `item.capability != null` (`sidebar_configuration.dart` filter). So the UI leaks features the isolation layer intends to forbid. Priority: High.
- RBAC fallback in `session_manager.dart` defaults to **owner** on errors ("NEVER unknown for authenticated users", "Ultimate fallback: owner"). This is a deliberate availability choice but means auth/Firestore failures grant **full owner permissions** — privilege-escalation risk. Priority: High (review).
- No grocery-specific network endpoints created here; no auth-less endpoint introduced. 

---

## 12. Offline Mode Gaps

- Alerts widget has an offline-first path: initial Drift fetch then stream; falls back to legacy `EventDispatcher` if UNS SDK unregistered (`business_alerts_widget.dart`). Good.
- Session has offline role caching via `SharedPreferences` (`session_manager.dart` `_cacheRole`, cached-role recovery). Good.
- **GroceryModule sync handler** (offline→cloud reconciliation for grocery batches/expiry) is **not active** (§7) — if grocery batch/expiry data depends on it, offline sync for those is broken. Priority: High (confirm).
- Conflict-resolution / queued-write behavior for offline bills **unverified** (sync engine not read).

---

## 13. Business Logic Inconsistencies

- **Capability vs sidebar mismatch:** grocery registry denies `useSalesReturn`, `useProformaInvoice`, `useDispatchNote`, `useStockReversal`, `usePurchaseRegister`, `useInventoryExport`, yet the retail sidebar shows Return Inwards, Proforma & Bids, Dispatch Notes, Booking Orders, Stock Reversal, Purchase Register. Either the registry intent or the sidebar is wrong. Priority: High.
- **Expiry contradiction:** grocery has `useBatchExpiry` (capability) + `batch_tracking` sidebar item + "Expiry Check" quick action + "Expiry & Stock Alerts" panel title, but `supportsExpiry` is hardcoded `false` for grocery (`business_capabilities.dart`), suppressing the expiry alert. Self-contradictory. Priority: High.
- **GST default 0% but gstEditable true:** grocery `defaultGstRate: 0.0` — fine for unbranded staples, but billing computes `cgst/sgst = price*(taxRate/200)` from `product.taxRate`, not the config default. Mixed source of truth (config defaultGstRate vs per-product taxRate). Priority: Medium.
- **Two `FeatureResolver` shapes:** `feature_resolver.dart` has a static `canAccess(String, BusinessCapability)`, but billing calls `FeatureResolver(type).showCreditLedger` (instance with `.showCreditLedger`) — a different class/API. Confirm there isn't a name collision causing confusion. Priority: Medium (unverified which class is imported there).

---

## 14. Data Validation Issues

- Manual item entry in billing inserts items with `gstRate: 0`, `cgst:0`, `sgst:0`, `unit:'pcs'` defaults (`bill_creation_screen_v2.dart` ~1200) — bypasses grocery unit options (kg/gm/ltr) and any GST. Loose grocery items default to `pcs`. Priority: Medium.
- Weight sheet parses `double.tryParse(v) ?? 0` for tare/gross with no upper bound or negative guard beyond `clamp(0, inf)` — acceptable but no validation messaging. Priority: Low.
- `MrpEnforcementValidator.isMrpCompliant` returns `true` when MRP is null/≤0 ("Assume compliant") — silent pass-through for grocery items lacking MRP. Priority: Low.
- Negative stock: `useNegativeStock` not granted to grocery; billing does a stock check via `getById` (~1582). Behavior when stock < qty **unverified** (only the read was seen). Priority: Medium.

---

## 15. UX Problems

- **No-op "Scan Barcode" dashboard tile** trains users that scanning is broken (it actually works inside billing). Priority: High.
- **Overwhelming sidebar:** a small grocery sees enterprise sections (Tax & Compliance/GSTR-1, Funds Flow Analysis, Trial Balance, Dispatch Notes, Proforma & Bids). High noise for the target user. Priority: Medium.
- **Duplicate menu entries** that open the same screen (invoice_margin/income_statement; funds_flow/cash_bank; gstr1/b2b_b2c; print_settings/doc_templates; purchase_register/procurement_log) erode trust. Priority: Medium.
- **Misleading labels:** "Audit Trail" and "Sync Status" open generic/backup screens. Priority: Medium.

---

## 16. Accessibility Issues

- `WeighingScaleWidget` and quick-action tiles rely on color + icon with small text (10–13px), some on dark gradients; no `Semantics` labels observed. Screen-reader/contrast compliance **unverified** (no semantics in the widgets read). Priority: Medium.
- Keyboard: billing exposes F2 for scan (good). Full keyboard nav of the 60-item sidebar **unverified**. Priority: Low.
- WCAG conformance overall requires manual AT testing — out of scope here.

---

## 17. Bugs, Errors, Crash Scenarios

- **Bug (confirmed):** dashboard grocery "Scan Barcode" `onTap: () {}` — dead button. (`business_quick_actions.dart`)
- **Bug (confirmed):** grocery expiry alert permanently hidden due to `supportsExpiry` hardcoded false. (`business_capabilities.dart`)
- **Latent crash risk:** `business_alerts_widget` uses `sl<AppDatabase>()` / `sl<ProductsRepository>()` directly inside a `StreamProvider`; if DI not ready it relies on `_resolveSdk()` try/catch, but the repo/db `sl<>()` calls are not guarded — could throw before first yield during early boot. The provider's `error` branch renders empty alerts, mitigating UI crash. Priority: Medium (unverified at runtime).
- **Dead routes:** navigating to any `/grocery/*` path would only show placeholder text, and only if the module router were mounted (it isn't). Priority: Low.

---

## 18. Unnecessary / Irrelevant Features Currently Shown

> The retail sidebar (`_getRetailSections()`) is a **shared component** used by grocery, electronics, mobileShop, computerShop, and all default types. **Do not remove items without sign-off** — changes affect multiple business types.

Irrelevant-for-grocery items currently shown (shared component):
- Tax & Compliance section in full (GSTR-1, B2B/B2C, HSN, Tax Liability, Filing Readiness) — overkill for a 0%-GST grocery. Flag: shared.
- Financial Reports: Funds Flow Analysis, Trial Balance / Ledger Abstract, Invoice Margin View — enterprise-grade. Flag: shared.
- Revenue Desk: Proforma & Bids, Dispatch Notes, Booking Orders — also contradict grocery capabilities (§13). Flag: shared + capability conflict.
- BuyFlow: Stock Reversal, Purchase Register — denied by capability registry. Flag: shared + capability conflict.

Recommendation: introduce a dedicated `_getGrocerySections()` (mirroring how clinic/pharmacy/restaurant have their own) rather than editing the shared retail list. Requires sign-off.

---

## 19. Recommendations & Prioritized Implementation Plan

**Critical**
1. **Wire the weighing-scale flow** into grocery billing (or delete `WeighingScaleWidget` if out of scope). Add a loose-weight line entry for kg/gm items using `WeighingScaleWidget.onWeightConfirmed`. (`weighing_scale_widget.dart`, `bill_creation_screen_v2.dart`)

**High**
2. Fix the dashboard **"Scan Barcode" no-op** — route to the same `_handleBarcodeScan`/`BarcodeScannerService` flow used in billing. (`business_quick_actions.dart`)
3. Resolve the **expiry contradiction** — either grant grocery real expiry support (remove the `type != BusinessType.grocery` clause) or remove the expiry UI/quick-action for grocery. (`business_capabilities.dart`)
4. **Reconcile sidebar vs capability registry** — gate retail items (returns/proforma/dispatch/reversal/purchase-register/export) with their `capability:` so isolation actually applies, or update the registry to grant them. (`sidebar_configuration.dart`, `business_capability.dart`)
5. Replace the **fake Audit Trail** mapping with a real immutable audit log, or relabel it. (`sidebar_navigation_handler.dart`)
6. **Decide on the dead module system** — either mount `ModuleLoader`/`ModuleRouteBuilder` and implement the grocery placeholder screens, or delete `modules/grocery/*` to remove confusion and dead sync/ws handlers. (`module_loader.dart`, `grocery_routes.dart`)
7. Review the **owner-on-error RBAC fallback** for privilege escalation. (`session_manager.dart`)
8. Add **daily counter cash-closing** and **fast grocery POS** screens.

**Medium**
9. Create a dedicated `_getGrocerySections()` to declutter the sidebar (with sign-off). 
10. De-duplicate/relabel reused sidebar mappings (`sync_status`, `purchase_register`, `turnover_analysis`, etc.).
11. Add MRP-vs-selling-price and multi-rate (retail/wholesale) pricing to grocery config/billing.
12. Fix manual-entry defaults to honor grocery unit options and GST.

**Low**
13. e-Way bill, multi-currency, loyalty schemes, WhatsApp/SMS share — add if roadmap requires.
14. Replace Tally export placeholder ledger name.
15. Add `Semantics` labels + contrast review to grocery-facing widgets.

---

## 20. Confidence & Coverage

**Read in full (high confidence):**
- `models/business_type.dart`, `core/billing/business_type_config.dart` (grocery + all configs, ~1022/1162 lines loaded — grocery fully visible)
- `widgets/desktop/sidebar_configuration.dart` (`_getRetailSections` fully read; other type sections sampled)
- `widgets/desktop/sidebar_navigation_handler.dart` (entire switch)
- `features/dashboard/v2/widgets/business_quick_actions.dart` (full), `business_alerts_widget.dart` (full)
- `core/isolation/business_capability.dart` (grocery key + registry), `core/isolation/feature_resolver.dart` (full)
- `core/config/business_capabilities.dart` (full)
- `core/navigation/app_screens.dart` (most), `core/session/session_manager.dart` (partial — first ~60%)
- `modules/grocery/grocery_module.dart` + `routes/grocery_routes.dart` (full), `core/module/module_loader.dart` (full)
- `widgets/weighing_scale_widget.dart` (full)

**Sampled via grep (medium confidence):**
- `features/billing/presentation/screens/bill_creation_screen_v2.dart` (barcode/weight/credit/gst sections via targeted grep, not full read)
- Report screens (`stock_summary_report_screen.dart`, `low_stock_report_screen.dart`, etc.) for real-vs-mock data
- `barcode_scanner_service.dart`, MRP validator

**Skipped / unverified (low confidence — explicitly flagged above):**
- Owner dashboard KPI cards (`owner_dashboard_screen.dart`, `dashboard_controller.dart`) — not read
- `products_repository.dart` and report repositories end-to-end
- Sync/offline engine internals, conflict resolution
- BackupScreen (encryption), CatalogueScreen (online order link), WhatsApp/SMS/email share
- Desktop shell responsive/layout code; accessibility runtime behavior
- Runtime behavior (no app run; static analysis only)

**Overall coverage estimate:** ~70% of grocery-relevant routing/config/capability/dashboard code read directly; ~20% sampled via grep; ~10% skipped (deep repositories, sync engine, shell layout, runtime).
