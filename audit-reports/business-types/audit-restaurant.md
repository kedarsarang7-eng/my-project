# DukanX Business-Type Audit — Restaurant

> Read-only, evidence-based audit. Every "missing/broken/orphaned" claim cites the file/function checked. Items I could not confirm are marked **unverified**.
>
> **Sampled (read in full or near-full):** `models/business_type.dart`, `core/billing/business_type_config.dart`, `widgets/desktop/sidebar_configuration.dart` (incl. `_getRestaurantSections` + `_getCommonSections`), `widgets/desktop/sidebar_navigation_handler.dart`, `core/navigation/app_screens.dart`, `core/isolation/business_capability.dart` (`'restaurant'` key), `core/isolation/feature_resolver.dart`, `features/dashboard/v2/widgets/business_quick_actions.dart`, `features/dashboard/v2/widgets/business_alerts_widget.dart`, the 4 wired screens (`table_management_screen.dart`, `kitchen_display_screen.dart`, `food_menu_management_screen.dart`, `restaurant_daily_summary_screen.dart`), `features/restaurant/utils/restaurant_business_rules.dart`, `domain/guards/restaurant_guard.dart`, `modules/restaurant/routes/restaurant_routes.dart`, `data/models/food_order_model.dart` (enums).
> **Sampled by directory listing / targeted grep only (not opened in full):** the 10+ orphaned screens under `features/restaurant/presentation/screens/**`, the 8 repositories under `data/repositories/**`, the domain services. Their internal logic is marked **unverified** where I did not open the file.

---

## 1. Header — Business Type, Sidebar Resolution, Config Summary

**Business type:** `BusinessType.restaurant` (`Dukan_x/lib/models/business_type.dart`, 3rd enum value). `displayName` = "Restaurant / Hotel", `icon` = `restaurant_rounded`, `emoji` = 🍽️, `primaryColor` = `#EA580C` (Orange) — `business_type_config.dart` extensions.

**Sidebar resolution:** Restaurant **is** a dedicated case in `_getSectionsForBusiness()` (`sidebar_configuration.dart` → `case BusinessType.restaurant: return _getRestaurantSections();`). `_getRestaurantSections()` renders 3 dedicated sections + 3 inherited common sections (`_getCommonSections(startingIndex: 3)`):

| Section | Items (sidebar id) |
|---|---|
| 0 Restaurant Operations | `executive_dashboard`, `restaurant_tables` (cap `useTableManagement`), `kitchen_display`, `menu_management`, `daily_summary` |
| 1 Billing & Cashier | `new_sale`, `revenue_overview`, `sales_register` |
| 2 Inventory & Stock | `stock_summary`, `item_stock` (labelled "Ingredients Stock"), `low_stock` |
| 3 Parties & Ledger (common) | `customers`, `suppliers`, `party_ledger`, `outstanding` |
| 4 Reports & Analytics (common) | `analytics_hub`, `product_performance`, `invoice_margin` (labelled "Profit & Loss"), `gstr1` |
| 5 System (common) | `print_settings`, `backup`, `error_logs`, `device_settings` |

**Config summary** (`BusinessTypeRegistry._configs[BusinessType.restaurant]`):
- requiredFields: `itemName, quantity, price`
- optionalFields: `isHalf, tableNo, isParcel`
- defaultGstRate: `5.0`, gstEditable: `false` (fixed 5%, no ITC — correct for India restaurant GST)
- unitOptions: `pcs, nos`
- itemLabel: `Dish`, addItemLabel: `Add Dish`, priceLabel: `Price`
- modules: `['menu','sales','kot','tables','reports']`

**Capability registry** (`business_capability.dart`, key `'restaurant'`): product add/name/price/qty/unit/tax/category; inventory list/visible/dead/search; invoice list/search/create; `useLowStockAlert`, `useGeneralAlerts`, `useDailySnapshot`, `useRevenueOverview`; `usePurchaseOrder`, `useStockEntry`, `useSupplierBill`; specialized **`useKOT`, `useTableManagement`, `useWaiterLinking`, `useKitchenDisplay`**. **Notably NOT granted:** `useSalesReturn`, `useProformaInvoice`, `useDispatchNote`, `useStockReversal`, `usePurchaseRegister`, `useInventoryExport`, `useBarcodeScanner`, `useLoyaltyPoints`.

**Architectural note (important):** there are **TWO parallel restaurant systems** in the repo:
- **Live (sidebar):** `features/restaurant/**` screens wired into `SidebarNavigationHandler.getScreenForItem()`.
- **Parallel (GoRouter module):** `modules/restaurant/routes/restaurant_routes.dart` (registered via `modules/restaurant/restaurant_module.dart` `get routes => restaurantRoutes`). Of its 6 routes, **4 are stubs that redirect to legacy `/home` or `/billing_flow`/`/analytics`** via `LegacyRouteRedirect` (`/restaurant/tables`, `/restaurant/orders`, `/restaurant/billing`, `/restaurant/analytics`); only `/restaurant/menu` (→ `FoodMenuManagementScreen(vendorId:'SYSTEM')`) and `/restaurant/delivery` (→ `RestaurantDeliveryOpsScreen`) hit real screens. See §6.

---

## 2. Missing Generic (Vyapar Benchmark) Features

| # | Benchmark | Status for restaurant | Evidence | Priority |
|---|-----------|-----------------------|----------|----------|
| 1 | Billing/Invoicing | **Partial** — `new_sale` → `BillCreationScreenV2`. Fixed 5% GST honoured by config. Restaurant-specific bill fields `isHalf`/`isParcel` are **not rendered** (§3, §13). | nav handler; `bill_line_item_row.dart` | High |
| 2 | Inventory | **Partial** — `stock_summary`/`item_stock`/`low_stock` wired (generic inventory screens). No recipe/BOM ingredient depletion in the wired flow; `recipe_management_screen.dart` exists but is **orphaned** (§6). | nav handler; screens listing | High |
| 3 | Barcode/POS (POS counter, item/bill discount, cashier reports) | **Weak** — `useBarcodeScanner` **not granted** to restaurant (correct). No dedicated POS counter / cashier-close report found. Quick Bill = generic `new_sale`. | capability registry | Medium |
| 4 | Accounting | **Inherited generic** — `invoice_margin` (P&L), `analytics_hub`. No restaurant-specific accounting. | common sections | Low |
| 5 | Receivables/Payables | **Inherited generic** — `party_ledger`, `outstanding`. `useCreditManagement`/`useCreditLimit` **not granted** to restaurant (no running-tab/credit support). | capability registry | Medium |
| 6 | Bank/Cash | **Not in restaurant sidebar** — `bank_accounts`/`cash_bank` exist in nav handler but are not surfaced in `_getRestaurantSections`/common. | sidebar config | Low |
| 7 | Orders/Delivery | **Broken/partial** — order model only supports `dineIn`/`takeaway` (`food_order_model.dart` `enum OrderType`); **no delivery/parcel order type**. `restaurant_delivery_ops_screen.dart` exists but orphaned from sidebar (§3, §6). | `food_order_model.dart`; screens listing | High |
| 8 | OCR | **Missing** — `useScanOCR` not granted to restaurant; no OCR entry point. | capability registry | Low |
| 9 | Reports (37+) | **Partial** — `analytics_hub`, `product_performance`, `gstr1`, plus dedicated `daily_summary`. Item-wise/category sales beyond daily summary **unverified**; `kot_report_screen.dart` orphaned. | nav handler; screens listing | Medium |
| 10 | Multi-user RBAC + audit | **Weak for restaurant** — RBAC exists (`session_manager.dart`) but has **no waiter/chef/captain/cashier-specific roles** (cashier maps to `staff`). `useWaiterLinking` capability exists with **no waiter role to bind**. Audit trail generic. | `session_manager.dart` (§11) | High |
| 11 | Multi-firm | **Broken for restaurant data** — wired screens hardcode `vendorId:'SYSTEM'` instead of `currentBusinessId`, so multi-firm isolation is bypassed for restaurant tables/KOT/menu/summary (§6, §8). | nav handler; repos | **Critical** |
| 12 | Backup | **Inherited** — `backup` → `BackupScreen`. Encryption **unverified**. | nav handler | Low |
| 13 | Online store catalog + order | **Partial** — customer-facing screens exist (`customer/customer_menu_screen.dart`, `order_tracking_screen.dart`, `rate_review_screen.dart`) + `QrCodeService` table QR. Owner flow reachable via "Take Order" in table screen; standalone customer ordering link **unverified/orphaned** from owner nav. | screens listing; `table_management_screen.dart` `_navigateToMenu` | Medium |
| 14 | e-Way bill | **N/A / Missing** — not relevant to dine-in; no screen found. | grep | Low |
| 15 | Loyalty/discount | **Missing** — `useLoyaltyPoints` not granted to restaurant; happy-hour pricing helper exists (`RestaurantBusinessRules.isInHappyHour`) but is **unwired** in billing (§13). | capability registry; grep | Medium |
| 16 | Service-business | N/A. | — | — |
| 17 | Offline-first sync | **Partial/real** — Drift streams (`watchTables`, `watchPendingOrders`) + `restaurant_sync_service.dart` exists (**unverified internals**). | repos; services listing | Medium |

---

## 3. Missing Industry-Specific Features (Restaurant)

| Feature | Status | Evidence | Priority |
|---------|--------|----------|----------|
| Table / floor management | **Working (wired)** but data-scoped to `'SYSTEM'` (§8). Dedicated `floor_management_screen.dart` (multi-floor) exists but is **orphaned**. | `table_management_screen.dart`; screens listing | High |
| KOT routing to kitchen/bar | **Partial** — `kitchen_display_screen.dart` works (NEW/COOKING/READY columns from `watchPendingOrders`). **No bar vs kitchen station routing** (single queue). `kot_service.dart` + `kot_report_screen.dart` exist (report orphaned). | `kitchen_display_screen.dart`; listing | High |
| Dine-in / takeaway / delivery / parcel | **Broken** — `OrderType` enum only has `dineIn`, `takeaway` (`food_order_model.dart`). No `delivery`/`parcel` despite config `isParcel` field and a delivery-ops screen. Daily summary only buckets dine-in vs takeaway. | `food_order_model.dart`; `restaurant_daily_summary_screen.dart` `_processOrders` | High |
| Menu / recipe management | **Partial** — menu CRUD works (`food_menu_management_screen.dart`). Recipe/BOM screen (`recipe_management_screen.dart`) **orphaned** — ingredient depletion not connected to the wired flow. | screens listing | High |
| Modifiers / add-ons & half-portion | **Broken** — config declares `isHalf` optional field but `bill_line_item_row.dart` has **no `isHalf`/half-portion control** (grep `isHalf`/`showHalf` = no matches). `food_item_variation_model.dart` exists (**unverified** if surfaced in UI). | grep; `bill_line_item_row.dart` | High |
| Split / merge bills, table transfer | **Logic exists, UI unverified** — `RestaurantBusinessRules.splitBill` implemented + unit-tested (`restaurant_business_rules_test.dart`), backend has `restoSplitBill` (`my-backend/serverless.yml`). No Flutter split/merge/transfer UI found in wired screens. | `restaurant_business_rules.dart`; grep | High |
| Captain/waiter ordering, running tabs | **Missing** — `useWaiterLinking` capability with no waiter role (§11); no captain-ordering screen; no running-tab/credit (`useCreditManagement` not granted). | capability registry; session_manager | High |
| Service charge + 5% GST (no ITC) | **GST correct, service charge unwired** — config `gstEditable:false @5%` ✓. `RestaurantBusinessRules.serviceCharge(5%)` + `Bill.serviceCharge` field exist, but billing UI does **not** set/apply it (only `recurring_billing_service.dart` sets `serviceCharge: 0.0`; grep in `features/billing/**` finds no UI input). | grep `serviceCharge`; `restaurant_business_rules.dart`; `bill.dart` | High |
| Tips | **Missing** — no tip field found (grep). | grep | Medium |
| Ingredient/recipe inventory depletion (BOM) | **Missing in wired flow** — `restaurant_inventory_model.dart` + `restaurant_inventory_repository.dart` + `recipe_management_screen.dart` exist but orphaned; not tied to order completion. **Unverified** internals. | screens/repos listing | High |
| Aggregator integration (Zomato/Swiggy) | **Stub/orphaned** — `restaurant_aggregator_receipt_screen.dart` exists but orphaned; real integration **unverified/likely absent**. | screens listing | Low |
| Daily sales summary & item-wise sales | **Working (wired)** — `restaurant_daily_summary_screen.dart` (revenue, orders, AOV, top items, orders/hour, prep time) — but `vendorId:'SYSTEM'` (§8). | `restaurant_daily_summary_screen.dart` | High |
| Void / comp tracking | **Partial** — `FoodOrderStatus.cancelled` counted in summary; no "comp"/void-reason audit found. **Unverified**. | `restaurant_daily_summary_screen.dart` | Medium |

---

## 4. Missing UI Components

| Component | Status | Evidence | Priority |
|---|---|---|---|
| Half-portion toggle on bill line | **Missing** — config `isHalf` not rendered. | `bill_line_item_row.dart` (no `isHalf`) | High |
| Parcel/takeaway flag on bill line | **Missing** — config `isParcel` not rendered (only `showTableNo` present). | `bill_line_item_row.dart` | High |
| Service-charge input on bill | **Missing** — no UI to add `serviceCharge` for dine-in. | grep `features/billing/**` | High |
| Modifier/add-on picker | **Missing in wired bill flow** — variation model exists, not surfaced. **Unverified**. | model listing | Medium |
| Split/merge bill dialog, table transfer | **Missing UI** (logic present). | grep | High |
| Floor plan view | **Orphaned** — `floor_management_screen.dart` not in nav. | screens listing | Medium |
| Bar/kitchen station selector in KDS | **Missing** — single queue only. | `kitchen_display_screen.dart` | Medium |

---

## 5. Missing Widgets & Dashboard / KPI Cards

- **Restaurant dashboard = generic `DashboardController`** (`executive_dashboard`), not a restaurant command center. The dedicated `restaurant_owner_command_screen.dart` (with `_KpiTile` widgets) is **orphaned** (not wired in nav handler). — Medium.
- **`BusinessQuickActions` (restaurant case)** is real and routes correctly: "Table View" → `restaurantTables`, "Kitchen Display" → `kitchenDisplay` (gated by `caps.accessKOT`), "Menu Mgmt" → `menuManagement` (`business_quick_actions.dart`). These quick actions navigate via `NavigationController` (no `vendorId` passed there — see §6 caveat). — OK.
- **`BusinessAlertsWidget` (restaurant case)** KPI counts are **hardcoded literals**: "Active Orders" = `'7'`, "Kitchen Queue" = `'12'`, "Low Ingredients" = `'4'` (`business_alerts_widget.dart`, `case BusinessType.restaurant`). Unlike the grocery case (which reads live `counts['lowStock']`/`counts['expiringSoon']` from `alertCountsProvider`), the restaurant branch **ignores the provider entirely** and shows fake numbers. — **High** (misleading owner-facing data). 
- **KPI cards in `daily_summary`** (`_buildMetricsGrid`) are real (computed from orders), but scoped to `'SYSTEM'` (§8). — High via §8.

---

## 6. Navigation & Route Gaps

**6a. Every restaurant sidebar id → resolves?** Checked each against `SidebarNavigationHandler.getScreenForItem()`:

| Sidebar id | Resolves to | OK? |
|---|---|---|
| `executive_dashboard` | `DashboardController` | ✅ |
| `restaurant_tables` | `TableManagementScreen(vendorId:'SYSTEM')` | ✅ resolves / ⚠️ vendorId bug |
| `kitchen_display` | `KitchenDisplayScreen(vendorId:'SYSTEM')` | ✅ / ⚠️ |
| `menu_management` | `FoodMenuManagementScreen(vendorId:'SYSTEM')` | ✅ / ⚠️ |
| `daily_summary` | `RestaurantDailySummaryScreen(vendorId:'SYSTEM')` | ✅ / ⚠️ |
| `new_sale`,`revenue_overview`,`sales_register` | billing/revenue screens | ✅ |
| `stock_summary`,`item_stock`,`low_stock` | inventory screens | ✅ |
| `customers`,`suppliers`,`party_ledger`,`outstanding` | parties screens | ✅ |
| `analytics_hub`,`product_performance`,`invoice_margin`,`gstr1` | reports screens | ✅ |
| `print_settings`,`backup`,`error_logs`,`device_settings` | system screens | ✅ |

**No dead links in the restaurant sidebar** — all 23 ids resolve. The problems are (a) the `vendorId:'SYSTEM'` hardcode and (b) many real screens never reachable.

**6b. The `vendorId:'SYSTEM'` issue (confirmed bug).** In `sidebar_navigation_handler.dart`, all four restaurant screens are constructed with a literal `vendorId: 'SYSTEM'`. Those screens pass `widget.vendorId` straight into repositories that filter by it:
- `TableManagementScreen` → `_tableRepo.watchTables(widget.vendorId)`, `createTable(vendorId: widget.vendorId, ...)`, `_qrService.generateTableQrCode(widget.vendorId, ...)`.
- `KitchenDisplayScreen` → `_orderRepo.watchPendingOrders(widget.vendorId)`.
- `FoodMenuManagementScreen` → `_repository.getCategoriesByVendor(widget.vendorId)`, `watchMenuItems(widget.vendorId)`, `createMenuItem(vendorId: widget.vendorId, ...)`.
- `RestaurantDailySummaryScreen` → `_orderRepo.getOrdersByDate(widget.vendorId, date)`, `_billRepo.getDailyRevenue(widget.vendorId, date)`.

The session already exposes the correct identity: `SessionManager.userId` (Firebase UID via `odId`) and `currentBusinessId` (`activeBusinessId ?? userId`). Using the constant `'SYSTEM'` means **every restaurant reads/writes a single shared global bucket** keyed `'SYSTEM'`, breaking per-business isolation and multi-firm support, and divorcing restaurant data from any record created with the real business id elsewhere. **Priority: Critical.** **Recommended fix:** resolve `vendorId` from session at construction, e.g. `TableManagementScreen(vendorId: sl<SessionManager>().currentBusinessId!)` (and same for the other three), or refactor the screens to read `currentBusinessId` internally via Riverpod instead of taking a `vendorId` param. (Note: `modules/restaurant/routes/restaurant_routes.dart` repeats the same `vendorId:'SYSTEM'` for `/restaurant/menu`.)

**6c. Orphaned restaurant screens (exist on disk, NOT wired into `getScreenForItem`).** Verified absent from the nav handler switch (only `TableManagement`, `KitchenDisplay`, `FoodMenuManagement`, `RestaurantDailySummary` are imported/used):

| Orphaned screen (`features/restaurant/presentation/screens/`) | Reachable elsewhere? |
|---|---|
| `floor_management_screen.dart` (FloorManagementScreen) | No route found |
| `kot_report_screen.dart` (KotReportScreen) | No route found |
| `menu_item_management_screen.dart` (MenuItemManagementScreen + Detail/Edit) | No route found |
| `recipe_management_screen.dart` (RecipeManagementScreen) | No route found |
| `restaurant_inventory_screen.dart` (RestaurantInventoryScreen) | No route found |
| `restaurant_owner_command_screen.dart` (RestaurantOwnerCommandScreen) | No route found |
| `restaurant_pricing_admin_screen.dart` (RestaurantPricingAdminScreen) | No route found |
| `restaurant_table_ops_screen.dart` (RestaurantTableOpsScreen) | No route found |
| `restaurant_aggregator_receipt_screen.dart` (RestaurantAggregatorReceiptScreen) | No route found |
| `restaurant_delivery_ops_screen.dart` (RestaurantDeliveryOpsScreen) | Only via `modules/restaurant` GoRoute `/restaurant/delivery` |
| `customer/customer_menu_screen.dart` (CustomerMenuScreen) | Via `TableManagementScreen._navigateToMenu` ("Take Order") |
| `customer/order_tracking_screen.dart` (OrderTrackingScreen) | **Unverified** entry point |
| `customer/rate_review_screen.dart` (RateReviewScreen) | **Unverified** entry point |

So ~11 owner-facing restaurant screens are built but **not surfaced** in the dedicated restaurant sidebar. — **High** (large amount of dead/unreachable functionality; floor plan, recipe/BOM, KOT report, pricing admin, owner command center, delivery ops all hidden).

**6d. Miscategorized / labelling.** `item_stock` is relabelled "Ingredients Stock" and `invoice_margin` relabelled "Profit & Loss" in the restaurant sidebar but both resolve to the **generic** `InventoryDashboardScreen` / `PnlScreen` — labels imply restaurant-specific behaviour that the target screens do not have. — Low/Medium.

---

## 7. Backend Integration Gaps

- Flutter wired screens use **local Drift repositories** (`RestaurantTableRepository`, `FoodOrderRepository`, `FoodMenuRepository`, `RestaurantBillRepository`) — confirmed `_db.select(...)` queries. Cloud sync via `restaurant_sync_service.dart` (**internals unverified**).
- Backend (`my-backend`) exposes restaurant endpoints (`resto.splitBill`, `restoGetSplitBill`, delivery tracking, combos) per `serverless.yml`/`meta.json`, and invoice service supports `serviceChargeCents` + `splitPayments`. **The Flutter app does not appear to call split-bill / service-charge backend paths** in the wired flow (no Dart usage of `serviceCharge` input in `features/billing/**`; `RestaurantBusinessRules.splitBill` only used in tests). — **High** (backend capability exists, frontend does not consume it).
- Aggregator (Zomato/Swiggy) backend/integration **unverified** — only a receipt screen stub on the Flutter side.

---

## 8. Database & API Issues (real-data vs mock)

| Screen | Data source | Verdict |
|---|---|---|
| `table_management_screen.dart` | `watchTables(vendorId)` Drift stream | **Real data**, but keyed `'SYSTEM'` → wrong tenant scope. **Critical** |
| `kitchen_display_screen.dart` | `watchPendingOrders(vendorId)` Drift stream | **Real data**, keyed `'SYSTEM'`. **Critical** |
| `food_menu_management_screen.dart` | `getCategoriesByVendor`/`watchMenuItems(vendorId)` | **Real data**, keyed `'SYSTEM'`. **Critical** |
| `restaurant_daily_summary_screen.dart` | `getOrdersByDate`/`getDailyRevenue(vendorId, date)` | **Real data**, keyed `'SYSTEM'`. **Critical** |
| Dashboard `BusinessAlertsWidget` (restaurant) | **Hardcoded** `'7'`/`'12'`/`'4'` | **Mock/fake** — ignores `alertCountsProvider`. **High** |

**Hardcoded alert counts confirmed** in `business_alerts_widget.dart` restaurant branch (contrast grocery branch which uses live counts). The `alertCountsProvider` itself only computes `lowStock`/`expiringSoon` (inventory) — there is **no provider for active-orders/kitchen-queue counts**, so even a "fix" needs a new data source (e.g. `watchPendingOrders` length). — High.

---

## 9. Responsive Design Issues

- Wired restaurant screens use `BoundedBox(maxWidth: 800)` + `responsiveValue<T>(...)` (`core/responsive/responsive.dart`) — e.g. `restaurant_daily_summary_screen.dart` metrics grid uses `responsiveValue<int>(mobile:1, tablet:2, desktop:2)`. Reasonable.
- **Kitchen Display uses a fixed 3-column `Row`** (`kitchen_display_screen.dart` `_buildOrderColumn` ×3 in a `Row`) with no narrow-width fallback. On small/portrait windows the three columns will be cramped (no responsive switch to tabs/stacked). — Medium.
- KDS capped at `maxWidth: 800` is **arguably wrong for a kitchen wall display** (large screens) — content stays narrow. — Low/Medium.

---

## 10. Performance Issues

- `KitchenDisplayScreen` refresh button calls `setState((){})` to "refresh"; the underlying `StreamBuilder` is already live, so the manual refresh is redundant and rebuilds the whole tree. — Low.
- `restaurant_daily_summary_screen.dart` recomputes all aggregates in `_processOrders` on the main isolate for the full day's orders on each date change; fine for typical volumes, potentially heavy for large datasets. **Unverified** at scale. — Low.
- `food_menu_management_screen.dart` `_loadCategories()` runs in `initState` and again after add; menu items via `StreamBuilder`. No obvious leak. — OK.

---

## 11. Security Concerns

- **Tenant isolation bypass (Critical):** `vendorId:'SYSTEM'` (§6b/§8) means restaurant data is not isolated per business. In a multi-tenant deployment this is a data-leakage/integrity risk — one restaurant could see/write another's `'SYSTEM'`-bucket tables/orders/menu. **Critical.**
- **RBAC gaps (High):** `session_manager.dart` role mapping only knows `manager`/`staff`(`cashier`→staff)/`accountant`/owner. There are **no `waiter`, `chef`/`kitchen`, or `captain` roles**, so KDS, table ordering, and billing cannot be restricted by restaurant job function. `useWaiterLinking` capability is declared but unusable. **High.**
- No restaurant sidebar items (other than `restaurant_tables`'s `useTableManagement`) carry `permission`/`capability` gating — `kitchen_display`, `menu_management`, `daily_summary` have **no capability set** in `_getRestaurantSections` even though `useKitchenDisplay`/`useKOT` exist. Gating is inconsistent (not exploitable since the section is restaurant-only, but no role restriction). **Medium.**
- `RestaurantGuard.canAccess` recognises `'restaurant'`/`'hotel'`, but `'hotel'` is **not** a `BusinessType` enum value — guard accepts a type the app cannot actually set. Minor inconsistency. **Low.**

---

## 12. Offline Mode Gaps

- Reads/writes go through Drift (offline-capable) — tables/orders/menu work offline. `restaurant_sync_service.dart` presumably reconciles (**internals unverified**).
- Because data is keyed `'SYSTEM'`, offline records and any server records keyed by real business id will **not reconcile** — sync correctness is undermined by the vendorId bug. — High (consequence of §6b).
- Conflict resolution / queueing for KOT order-status transitions across devices **unverified**. — Medium.

---

## 13. Business Logic Inconsistencies

| Inconsistency | Evidence | Priority |
|---|---|---|
| Config exposes `isHalf` & `isParcel` optional fields, but billing UI renders neither (only `tableNo`). | `business_type_config.dart` vs `bill_line_item_row.dart` (`showTableNo` only; no `isHalf`/`isParcel`) | High |
| Service charge: helper + Bill field + backend exist, but **never applied** in the Flutter bill flow. | `restaurant_business_rules.dart` `serviceCharge`; `bill.dart` `serviceCharge`; grep billing | High |
| Split-bill: implemented + tested + backend endpoint, **no Flutter UI** consumes it. | `restaurant_business_rules.dart` `splitBill`; `restaurant_business_rules_test.dart`; `serverless.yml restoSplitBill` | High |
| Happy-hour pricing helper exists, **unwired** to menu/billing. | `restaurant_business_rules.dart` `isInHappyHour` (only test refs) | Medium |
| Order types limited to dine-in/takeaway; config + delivery screen imply delivery/parcel that the model can't represent. | `food_order_model.dart` `enum OrderType` | High |
| `useWaiterLinking` capability with no waiter role. | `business_capability.dart` vs `session_manager.dart` | High |

---

## 14. Data Validation Issues

- `table_management_screen.dart` bulk-add validates `count` is 1–100 ✅, but `capacity`/`startNumber` fall back to defaults via `int.tryParse(...) ?? 4/1` with **no upper bound / negative guard** beyond that. Single add only checks table number is non-empty (capacity silently defaults to 4). — Low/Medium.
- `food_menu_management_screen.dart` add item: validates name + price non-empty; price parsed with `double.tryParse(...) ?? 0` so a non-numeric price silently becomes **₹0** (no error). Negative/huge prices not rejected. — Medium.
- `_reorderCategories` reorders in memory only — comment says "Persist sort order to repository if needed in future"; **reorder is not persisted** (a functional gap masquerading as working). — Medium.
- No validation that a menu item is assigned a category (category optional in add dialog). — Low.

---

## 15. UX Problems

- Manual "Refresh" button on a live-stream KDS is confusing/redundant (`kitchen_display_screen.dart`). — Low.
- Sound toggle in KDS only shows a SnackBar; **no actual sound** is played on new orders (no audio player wired; `_soundEnabled` only gates a feedback SnackBar in `_acceptOrder`). Misleading control. — Medium.
- "Customer notified!" SnackBar on `markReady` implies a notification was sent; actual customer notification path **unverified** (`restaurant_notification_service.dart` exists but not invoked here). — Medium.
- Category reorder gives drag feedback but silently discards the new order on reload (§14). — Medium.
- Owner has no in-app way to reach floor plan, recipes, KOT report, pricing admin, delivery ops (all orphaned, §6c) — discoverability gap. — High.

---

## 16. Accessibility Issues

- Status is communicated by **colour + icon** on table cards (`_getStatusColor`/`_getStatusIcon`) and KDS columns; text labels are present (good), but heavy reliance on the futuristic colour palette with low-contrast `withOpacity` overlays may fail WCAG contrast. Full validation requires manual testing with assistive tech. — Medium (unverified).
- Veg/spicy indicators use an icon + 🌶️ emoji with no semantic label/tooltip (`food_menu_management_screen.dart`). — Low.
- Icon-only app-bar actions (`_buildAppBarAction`) — table screen provides `tooltip`, but KDS sound/refresh actions pass **no tooltip** (no accessible name). — Low/Medium.
- Charts in daily summary (`fl_chart`) have no textual alternative/semantics. — Low.

---

## 17. Bugs / Errors / Crash Scenarios

| Issue | Evidence | Severity |
|---|---|---|
| `vendorId:'SYSTEM'` → wrong/empty tenant data, broken multi-firm. | §6b/§8 | **Critical** |
| Hardcoded restaurant alert counts (`'7'/'12'/'4'`) — always wrong. | `business_alerts_widget.dart` | High |
| Daily summary `_buildOrdersChart` calls `_ordersPerHour.values.reduce(max)` — guarded by `isEmpty` check before reduce ✅ (no crash). Pie chart guarded by `total==0` ✅. | `restaurant_daily_summary_screen.dart` | OK |
| Category reorder not persisted → silent data loss of intended order. | `_reorderCategories` | Medium |
| Non-numeric price → silent ₹0 menu item. | `food_menu_management_screen.dart` | Medium |
| KDS sound toggle implies audio that never plays. | `kitchen_display_screen.dart` | Medium |
| `RestaurantGuard` accepts `'hotel'` which is not a real `BusinessType`. | `restaurant_guard.dart` | Low |

---

## 18. Unnecessary / Irrelevant Features Shown (shared components)

- **Common sections inherited by restaurant** (`_getCommonSections`): "Parties & Ledger" (`customers`/`suppliers`/`party_ledger`/`outstanding`) and "Reports & Analytics" (`analytics_hub`/`product_performance`/`invoice_margin`/`gstr1`) are **generic retail/accounting** screens. `product_performance` → generic `ProductPerformanceScreen`, `invoice_margin` → generic `PnlScreen` — neither is restaurant-aware. Reasonable for a hotel/restaurant doing accounting, but flagged as **shared, non-tailored**. — Low.
- **`suppliers`** in restaurant context maps to `PartyLedgerListScreen(initialFilter:'supplier')` — fine, but labelled generically. — Low.
- Dashboard `BusinessQuickActions`/`BusinessAlertsWidget` are **shared multi-business switch widgets** (`features/dashboard/v2/widgets/`) — restaurant just one `case`. The hardcoded restaurant alerts (§5/§8) are a direct consequence of this shared design not being finished for restaurant. — High (data correctness), Low (architecture).

---

## 19. Recommendations & Prioritized Implementation Plan

**P0 — Critical (data integrity / multi-tenancy)**
1. Replace `vendorId:'SYSTEM'` in `sidebar_navigation_handler.dart` (and `modules/restaurant/routes/restaurant_routes.dart`) with the real `SessionManager.currentBusinessId`, or refactor the 4 screens to read `currentBusinessId` via Riverpod. Add a guard that throws/blocks if business id is null rather than defaulting to a constant. (§6b, §8, §11, §12)

**P1 — High**
2. Wire real restaurant alert counts in `business_alerts_widget.dart` (active orders / kitchen queue from `watchPendingOrders(currentBusinessId)`, low ingredients from inventory) and remove the `'7'/'12'/'4'` literals. (§5, §8)
3. Surface orphaned screens in `_getRestaurantSections` + add nav-handler cases: floor plan, recipe/BOM, KOT report, restaurant inventory, pricing admin, owner command center, delivery ops. (§6c)
4. Add `isHalf` and `isParcel` controls to `bill_line_item_row.dart` (config already declares them) and a **service-charge input** that calls `RestaurantBusinessRules.serviceCharge` and the backend `serviceChargeCents`. (§3, §4, §13)
5. Add `delivery`/`parcel` to `OrderType` and propagate through KDS + daily summary buckets. (§3, §7, §13)
6. Build split/merge-bill + table-transfer UI on top of existing `splitBill` logic and backend endpoints. (§3, §13)
7. Add restaurant RBAC roles (`waiter`, `chef`/`kitchen`, `captain`) in `session_manager.dart`/`RolePermissions` and bind `useWaiterLinking`; gate KDS/menu/table items by capability+role. (§11)

**P2 — Medium**
8. Persist category reorder; validate menu price (reject non-numeric/negative); bound table capacity. (§14)
9. Make KDS responsive (stack/tab on narrow widths; allow large kitchen-display width); implement real new-order sound. (§9, §15)
10. Wire happy-hour pricing + tips + void/comp reason tracking. (§3, §13)
11. Verify/standardise customer-facing ordering (`customer/*` screens) entry points and the notification path. (§3, §15)

**P3 — Low**
12. Remove/align `'hotel'` in `RestaurantGuard`; relabel inherited generic screens or make them restaurant-aware; add tooltips/semantics to KDS actions and charts. (§11, §16, §18)

---

## 20. Confidence & Coverage

- **High confidence (opened & read):** sidebar resolution (dedicated `_getRestaurantSections` + `_getCommonSections`), config, capability registry, feature resolver, the `vendorId:'SYSTEM'` bug and its repository consumption, hardcoded dashboard alert counts, the 4 wired screens' data sources, `OrderType` enum limits, service-charge/split-bill logic existing but unwired, RBAC role list, the parallel `modules/restaurant` route stubs.
- **Medium confidence (listing + targeted grep, not fully opened):** the 11 orphaned screens' internal behaviour, the 8 repositories beyond the queried methods, domain services (`restaurant_sync_service`, `restaurant_notification_service`, `restaurant_pdf_bill_service`, `qr_code_service`), `food_item_variation_model` UI surfacing.
- **Unverified (explicitly not confirmed):** aggregator (Zomato/Swiggy) integration, encrypted backup, cross-device KOT sync/conflict handling, customer-app order/track/review entry points, WCAG contrast, performance at scale, whether any orphaned screen is reached via a route I did not enumerate.
- **Skipped:** full read of `bill_creation_screen_v2.dart` (only grepped for restaurant fields), backend handler implementations (only `serverless.yml`/`meta.json` confirmed endpoints exist), tests beyond `restaurant_business_rules_test.dart`.

**Overall:** the restaurant vertical has a genuinely rich feature set on disk (tables, KDS, menu, recipes, floor, delivery, owner command, daily summary, split/service-charge logic, customer ordering), but a large fraction is **orphaned from navigation**, the **wired screens are mis-scoped to a `'SYSTEM'` constant**, **dashboard alerts are faked**, and several India-restaurant essentials (half-portion/parcel on bill, service charge application, delivery/parcel order types, waiter/chef RBAC) are **declared but not wired**.
