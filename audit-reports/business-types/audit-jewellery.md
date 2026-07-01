# DukanX Business-Type Audit — Jewellery Shop (`BusinessType.jewellery`)

**Scope:** READ-ONLY, evidence-based audit of the Jewellery vertical in the DukanX Flutter app (`Dukan_x/`).
**Method:** Source inspection + grep across `Dukan_x/lib`. Every claim cites a file path. Items that could not be verified by reading source are marked **unverified**.
**Date generated:** from current workspace state.

---

## 0. What was sampled vs skipped

**Sampled (read in full or in relevant part):**
- `lib/models/business_type.dart` (enum, displayName, icon)
- `lib/core/billing/business_type_config.dart` (jewellery config + ItemField enum)
- `lib/widgets/desktop/sidebar_configuration.dart` (section resolver + retail sections)
- `lib/widgets/desktop/sidebar_navigation_handler.dart` (`getScreenForItem`)
- `lib/core/isolation/business_capability.dart` (`jewellery` capability set)
- `lib/features/dashboard/v2/widgets/business_quick_actions.dart`
- `lib/features/dashboard/v2/widgets/business_alerts_widget.dart`
- `lib/features/jewellery/**` (all 8 screens enumerated; integration, business rules, making-charges calculator, online + offline repositories read)
- `lib/modules/jewellery/jewellery_module.dart`, `lib/modules/jewellery/routes/jewellery_routes.dart`
- `lib/core/module/module_loader.dart`, `module_route_builder.dart`, `module_registry.dart` (route wiring)
- `lib/app/app.dart`, `lib/app/routes.dart` (live MaterialApp route map)
- `lib/features/billing/presentation/widgets/bill_line_item_row.dart`, `bill_creation_tokens.dart` (billing field config)

**Skipped / not fully read (flagged where it matters):**
- Freezed model internals (`*.freezed.dart`, `*.g.dart`) — generated, not audited line-by-line.
- `gold_scheme_repository.dart`, `jewellery_repair_repository.dart`, `gold_rate_alert_repository.dart`, `making_charges_repository.dart` — existence confirmed via directory listing + screen imports; internal logic **not** line-audited.
- Backend (Node/DynamoDB) endpoint implementations for `/jewellery/*` — out of Flutter scope, marked **unverified**.
- `BillCreationScreenV2` end-to-end total math for weight×rate — **partially unverified** (see §13).
- WebSocket/sync handlers (`jewellery_sync_handler.dart`, `jewellery_ws_handler.dart`) — referenced only.

---

## 1. Header — Resolution, Config, Capabilities

### 1.1 Enum & identity
- `lib/models/business_type.dart`: `BusinessType.jewellery` exists; `displayName` = `'Jewellery Shop'`; `icon` = `Icons.diamond_rounded`.
- `lib/core/billing/business_type_config.dart`: `emoji` = `💍`; `primaryColor` = `0xFFD97706` (Amber/Gold); `pdfPrimaryColor` = `#D97706`.

### 1.2 Billing config (`BusinessTypeRegistry._configs[BusinessType.jewellery]`)
- `requiredFields`: `itemName, quantity, price, metalWeight`
- `optionalFields`: `makingCharges, purity, gst, discount`
- `defaultGstRate`: `3.0`; `gstEditable`: `false`
- `unitOptions`: `gm, pcs`
- `itemLabel`: `'Jewellery'`; `addItemLabel`: `'Add Item'`; `priceLabel`: `'Rate/Gm'`
- `modules`: `['inventory','sales','custom_orders','reports']`

### 1.3 Sidebar resolution — **generic retail fallback**
- `lib/widgets/desktop/sidebar_configuration.dart` → `_getSectionsForBusiness(BusinessType type)` has **no `case BusinessType.jewellery`**. It hits `default: return _getRetailSections();`.
- Consequence: a jewellery shop sees the generic 10-section retail enterprise sidebar (Dashboard & Control, Revenue Desk, BuyFlow, Inventory & Stock, Parties & Ledger, Business Intelligence, Financial Reports, Tax & Compliance, Operations & Logs, Utilities & System). **No jewellery-specific section, item, or icon.**

### 1.4 Capabilities (`businessCapabilityRegistry['jewellery']`, `business_capability.dart`)
Granted: `useProductAdd, useProductName, useProductSalePrice, useProductStockQty, useProductCategory, useInventoryList, useVisibleStock, useInventorySearch, useInvoiceCreate, useInvoiceList, useInvoiceSearch, useDailySnapshot, useRevenueOverview, usePurchaseOrder, useStockEntry, useSupplierBill, useBarcodeScanner, useLoyaltyPoints, useStockManagement`.

Notably **absent**: `useProductUnit`, `useProductTax`, `useSalesReturn`, `useLowStockAlert`, `useGeneralAlerts`, and **every jewellery-domain capability** (there is no capability flag for gold-rate, making-charges, purity, hallmark/HUID, old-gold exchange, custom orders, repairs, or gold schemes). The only "jewellery" comment in the registry maps to `useLoyaltyPoints` — a generic loyalty flag.

### 1.5 The rich-but-orphaned feature module (headline)
`lib/features/jewellery/` is a substantial, well-structured module:
- **8 screens** (`presentation/screens/`): `custom_order_management_screen.dart`, `gold_rate_alert_screen.dart`, `gold_rate_management_screen.dart`, `gold_scheme_screen.dart`, `hallmark_inventory_screen.dart`, `jewellery_repair_screen.dart`, `making_charges_calculator_screen.dart`, `old_gold_exchange_screen.dart`.
- **5 model groups** + freezed, **6 repositories**, **1 service** (`making_charges_calculator.dart`), **1 utils** (`jewellery_business_rules.dart`), **1 integration** (`jewellery_integration.dart`).
- A registered module: `lib/modules/jewellery/jewellery_module.dart` (`JewelleryModule`) with 8 `navItems` and 7 GoRoutes, registered in `lib/core/module/module_loader.dart`.

**But none of it is reachable in the running app** (see §6 for the full proof chain). This is the single most important finding of this audit.

---

## 2. Missing Generic Features

| # | Missing / gap | Evidence | Priority |
|---|---|---|---|
| 2.1 | **Sales Return / Credit Note not enabled** for jewellery. Sidebar `return_inwards` item has no capability gate so it *appears*, but `useSalesReturn` is **not** in `businessCapabilityRegistry['jewellery']`. | `business_capability.dart` jewellery set; `sidebar_configuration.dart` `return_inwards` item (no `capability:`). | High |
| 2.2 | **Low-stock alerts absent.** `useLowStockAlert` not granted. The retail sidebar `low_stock` item has no capability flag so it still renders, but the dashboard "Alerts" quick-action is gated on `caps.accessLowStockAlert` and will be hidden. | `business_capability.dart`; `business_quick_actions.dart` (`if (caps.accessLowStockAlert)`). | Medium |
| 2.3 | **Unit & tax product capabilities missing** (`useProductUnit`, `useProductTax`) while the billing config offers `unitOptions:[gm,pcs]` and optional `gst`. Config and capability layer disagree. | `business_type_config.dart` vs `business_capability.dart`. | Medium |
| 2.4 | **No dedicated dashboard.** Jewellery falls back to generic `executive_dashboard` (`DashboardController`). No gold-rate ticker, no day-rate card, no metal-stock-by-weight KPI. | `sidebar_navigation_handler.dart` `executive_dashboard`. | High |
| 2.5 | **OCR / scan-bill purchase** advertised by the module (`navItems` → `/purchase/scan-bill`) is unreachable in live nav. | `jewellery_module.dart` navItems; §6 reachability. | Low |

---

## 3. Missing Industry-Specific Features (Jewellery domain)

These features **exist as code** but are **unreachable** (orphaned, §6), so functionally they are missing from the shipped product. Where a feature does not exist at all, it is marked "absent".

| # | Domain need | Status | Evidence | Priority |
|---|---|---|---|---|
| 3.1 | Live daily gold/silver rate by purity (24K/22K/18K) | Code exists, orphaned | `gold_rate_management_screen.dart`; `jewellery_repository_offline.dart` `setGoldRate/getTodayGoldRate` (24K/22K/18K/silver/platinum paisa). | Critical |
| 3.2 | Making charges (% / flat / per-gram / tiered / complexity / combination) | Code exists, orphaned | `data/services/making_charges_calculator.dart`; `making_charges_calculator_screen.dart`. | Critical |
| 3.3 | Wastage % | Code exists (in calculator), orphaned | `making_charges_calculator.dart` `wastagePercent` / `applyOnWastage`. | High |
| 3.4 | Metal + stone + net weight | Code exists | `JewelleryProduct` (`metalWeightGrams/grossWeightGrams/netWeightGrams`); calculator stone path. | High |
| 3.5 | Purity/karat & BIS hallmark / HUID register | Code exists, orphaned | `hallmark_inventory_screen.dart`; `HallmarkRegisterEntry`, `registerHallmark()` (HUID, BIS, assaying mark). | Critical |
| 3.6 | Old-gold exchange / buyback with purity testing (PMLA KYC) | Code exists, orphaned | `old_gold_exchange_screen.dart`; `createOldGoldExchange()` (customer ID type/number, purity test method, PMLA `pmlCompliant`). | Critical |
| 3.7 | Gold savings schemes (monthly installment) | Code exists, orphaned | `gold_scheme_screen.dart`, `gold_scheme_repository.dart`, `gold_scheme_model.dart` (`SchemePayment`). | High |
| 3.8 | Custom / bespoke orders with advance | Code exists, orphaned | `custom_order_management_screen.dart`; `createOrder()` (`advanceReceivedPaisa`, `promisedDeliveryDate`, status history). | High |
| 3.9 | Repair / service jobs | Code exists, orphaned | `jewellery_repair_screen.dart`, `jewellery_repair_repository.dart`, `jewellery_repair_model.dart` (`RepairStatus/RepairPriority`). | High |
| 3.10 | 3% GST (metal) + making-charges GST | Partial | Config `defaultGstRate 3.0`; calculator `calculateTotalPrice(gstPercent=3.0)` applies flat 3% to whole subtotal (metal+wastage+making+stone). India treats making charges at 5% in some interpretations; flat-3%-on-all is a simplification. | Medium |
| 3.11 | Certificate / certification tracking | Absent | No certificate field/model found in `features/jewellery/data/models/`. | Medium |
| 3.12 | Stock by weight (not just qty) | Partial | `JewelleryProduct` carries weights, but inventory sidebar (`stock_summary`, `item_stock`) routes to generic qty-based screens (`StockSummaryScreen`, `InventoryDashboardScreen`). | High |
| 3.13 | Daily rate-linked repricing of inventory | Absent / unverified | No repricing job found tying `GoldRateCard` updates to `JewelleryProduct.pricePerGramPaisa`. | High |
| 3.14 | Gold-rate alerts (threshold notifications) | Code exists, orphaned **and double-orphaned** | `gold_rate_alert_screen.dart` is referenced **only** in `jewellery_integration.dart` (itself dead) — it is not even in `modules/jewellery/routes/jewellery_routes.dart`. | High |

---

## 4. Missing UI Components

| # | Gap | Evidence | Priority |
|---|---|---|---|
| 4.1 | No purity selector (24K/22K/18K/14K) in the live billing line item — purity is a **read-only Text cell** showing `widget.item.purity ?? '—'`, not an editable dropdown. | `bill_line_item_row.dart` (`if (widget.fieldConfig.showPurity) … Text(widget.item.purity ?? '—')`). | High |
| 4.2 | No making-charges input column rendered in billing even though `showMakingCharges` is computed. Only `Purity` and `Wt (g)` headers/cells are emitted in the sampled rows; a making-charges column/header was not found. | `bill_line_item_row.dart` header builder shows `Purity` + `Wt (g)` only. **Partially unverified** (full file not exhaustively read). | High |
| 4.3 | No gold-rate ticker/day-rate card widget on dashboard. | No widget referencing `GoldRateCard` under `features/dashboard/`. | Medium |
| 4.4 | Garbled glyphs in calculator output strings (mojibake `Ã—` for `×`, `â‚¹` for `₹`). User-facing breakdown text will render corrupted. | `making_charges_calculator.dart` `_buildBreakdown`, step formulas; same mojibake in `jewellery_business_rules.dart` comments. | Medium |

---

## 5. Missing Widgets & Dashboard / KPI Cards

- `business_quick_actions.dart` jewellery branch provides exactly **two** buttons: **"Custom Order"** (`Icons.diamond_outlined`) and **"Gold Rate"** (`Icons.trending_up_outlined`). **Both have `onTap: () {}` — dead no-ops.** Verified diamond icon as described. (Priority: **High** — dead buttons.)
- The common leading "New Sale" button shows (jewellery has `useInvoiceCreate`); the trailing "Alerts" button is gated on `caps.accessLowStockAlert`, which jewellery lacks → no alerts shortcut.
- `business_alerts_widget.dart` jewellery title = **'Custom Order Alerts'** (matches expectation). Its two alert rows are **hardcoded**: `'Custom Orders Ready' count '3'` and `'Gold Rate Alert' count '!'`. The widget's real `alertCountsProvider` (low-stock/expiring from Drift) is **ignored** by the jewellery branch. (Priority: **High** — fabricated counts.)
- **No KPI cards** for: today's gold rate, metal stock by weight, pending custom orders, scheme collections due, repair jobs in progress. None exist.

---

## 6. Navigation & Route Gaps — the orphaned-module proof chain

### 6.1 Retail sidebar item IDs → do they resolve?
For each ID emitted by `_getRetailSections()` I checked `SidebarNavigationHandler.getScreenForItem`:
- **Resolve to real screens:** `executive_dashboard, live_health, alerts, daily_snapshot, revenue_overview, new_sale, receipt_entry, return_inwards, proforma_bids, booking_orders, dispatch_notes, sales_register, buyflow_dashboard, purchase_orders, stock_entry, stock_reversal, procurement_log, supplier_bills, purchase_register, stock_summary, item_stock, batch_tracking, low_stock, stock_valuation, damage_logs, customers, suppliers, party_ledger, ledger_history, ledger_abstract, outstanding, analytics_hub, turnover_analysis, product_performance, daily_activity, procurement_insights, margin_analysis, invoice_margin, income_statement, funds_flow, financial_position, cash_bank, gstr1, b2b_b2c, hsn_reports, tax_liability, filing_status, transaction_reports, activity_logs, audit_trail, error_logs, print_settings, doc_templates, backup, sync_status, device_settings`. All present in the switch. ✔
- **Several are placeholder/reuse mappings** (not real distinct screens): `turnover_analysis → AllTransactionsScreen`, `daily_activity → AllTransactionsScreen`, `activity_logs → AllTransactionsScreen`, `audit_trail → AllTransactionsScreen`, `ledger_history → AllTransactionsScreen`, `purchase_register → ProcurementLogScreen`, `sync_status → BackupScreen`, `doc_templates → PrintMenuScreen`. (Priority: **Low/Medium** — generic, but acceptable.)
- **No `default` dead links** for retail IDs (every ID has a case); unknown IDs fall to `_buildPlaceholderScreen('Unknown Screen')`.

### 6.2 The 8 jewellery screens — reachable or orphaned?
**Orphaned. Proof:**
1. `SidebarNavigationHandler.getScreenForItem` (`sidebar_navigation_handler.dart`) contains **no jewellery cases** — grep for the 8 class names returns matches only inside `features/jewellery/**`, `modules/jewellery/routes/jewellery_routes.dart`, and `jewellery_integration.dart`. No sidebar/desktop reference.
2. The live app router is **legacy MaterialApp `routes:`**, not GoRouter: `lib/app/app.dart` → `routes: buildAppRoutes()`. Grep for `routerConfig:` in `Dukan_x/lib` → **no match**.
3. `lib/app/routes.dart` `buildAppRoutes()` — the single source of truth for live named routes — contains a "CUSTOM BUSINESS MODULES" section with clinic, clothing, book_store, service/repair, petrol pump routes, **but zero jewellery routes** (grep `jewellery|gold|Hallmark|…` in `routes.dart` → no matches).
4. The module GoRoutes (`modules/jewellery/routes/jewellery_routes.dart`, wired via `JewelleryModule.routes` → `ModuleRegistry.buildRoutes()` → `ModuleRouteBuilder.buildRoutes`) are **never consumed**: grep `ModuleRouteBuilder.instance.buildRoutes` in live wiring → only doc-comment occurrences. `module_route_builder.dart`/`auto_parts_routes.dart`/`legacy_route_redirect.dart` all explicitly note the GoRouter migration "will be wired in once `MaterialApp` migrates from `routes:` to `routerConfig:`" — **it has not.**
5. `features/jewellery/jewellery_integration.dart` (`JewelleryIntegration` with `getRoutes/getGoRoutes/getMenuItems/getQuickActions`) is **dead code** — grep `JewelleryIntegration` returns only its own definition; nothing imports/instantiates it. It even declares **local fake `RouteBase`/`GoRoute` classes** at the bottom (shadowing `go_router`), confirming it was never integrated.

**Net:** On desktop, a jewellery vendor reaches **none** of: gold rate management, gold-rate alerts, making-charges calculator, hallmark inventory, old-gold exchange, custom orders, repairs, gold schemes. (Priority: **Critical**.)

### 6.3 Capability mismatches in the retail sidebar shown to jewellery
- `return_inwards` shown but `useSalesReturn` not granted. (mismatch)
- `proforma_bids`, `dispatch_notes`, `booking_orders` shown but `useProformaInvoice`/`useDispatchNote` not granted. (mismatch)
- `low_stock` shown but `useLowStockAlert` not granted. (mismatch)
- `batch_tracking` is correctly hidden (gated by `useBatchExpiry`, not granted). ✔
(Priority: **Medium** — capability layer is bypassed for un-flagged sidebar items.)

### 6.4 Inconsistent route surfaces within the module itself
- `modules/jewellery/routes/jewellery_routes.dart` exposes 7 routes (billing→`LegacyRouteRedirect`, inventory→Hallmark, rates, orders, exchange, repair, schemes) but **omits** `GoldRateAlertScreen` and `MakingChargesCalculatorScreen`.
- `jewellery_integration.dart` exposes those 2 extra screens but omits `CustomOrderManagementScreen`.
- So even if one surface were wired, the set of reachable screens would differ. (Priority: **Medium**.)

---

## 7. Backend Integration Gaps

- Online repo `jewellery_repository.dart` calls REST endpoints: `GET/DELETE/POST/PATCH /jewellery/custom-orders[...]`. Offline repo `jewellery_repository_offline.dart` syncs to `POST /jewellery/products`, `/jewellery/gold-rate`, `/jewellery/old-gold-exchange`, `/jewellery/custom-orders`, `/jewellery/hallmark-inventory`.
- Whether these endpoints exist server-side is **unverified** (backend not in Flutter scope). If absent, every sync throws and items stay `synced:false`.
- `gold_rate_alert`, `gold_scheme`, `making_charges`, `jewellery_repair` repositories: endpoint surface **not line-audited** (skipped).
- No evidence of a market-data feed integration for live gold rates — rate entry is `source: 'MANUAL'` by default (`setGoldRate`). (Priority: **High** for "live rate" expectation.)

---

## 8. Database & API Issues (real vs mock; hardcoded; offline vs online)

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 8.1 | **Hardcoded dashboard alert counts** for jewellery ('3', '!') — not from DB. | `business_alerts_widget.dart` jewellery case. | High |
| 8.2 | **Two divergent repositories.** `custom_order_management_screen.dart` uses the **online-only** `JewelleryRepository` (throws when offline), while `gold_rate_management`, `hallmark_inventory`, `old_gold_exchange` use the **offline-first** `JewelleryRepositoryOffline`. Inconsistent offline behaviour across the same module. | screen imports (grep), `jewellery_repository.dart` (ApiClient, throws), `jewellery_repository_offline.dart` (Hive + sync queue). | High |
| 8.3 | Offline repo is otherwise solid: Hive boxes for products/rates/exchanges/orders/hallmark + sync queue with retry cap (5) and soft-delete with invoice-history guard. | `jewellery_repository_offline.dart` `syncAll`, `deleteProduct(checkInvoices)`. | (strength) |
| 8.4 | Gold-rate storage unit inconsistency risk: rates stored **per-10g** (`gold24KPer10gPaisa`) but billing rules consume **per-gram** (`ratePerGram24K`). No conversion helper found bridging the two. | `jewellery_repository_offline.dart` (`*Per10gPaisa`) vs `jewellery_business_rules.dart` (`ratePerGram24K`). | High |
| 8.5 | `_calculateStoneCharge` uses a flat per-stone charge regardless of stone count ("Assume 1 stone per gram … In real implementation, this would use actual stone count"). | `making_charges_calculator.dart` `_calculateStoneCharge`. | Medium |

---

## 9. Responsive Design

- Jewellery screens import a shared responsive helper (`package:dukanx/core/responsive/responsive.dart`) — e.g., `old_gold_exchange_screen.dart`, `making_charges_calculator_screen.dart`, `hallmark_inventory_screen.dart`, `gold_rate_management_screen.dart`. A repo-wide responsive-fix script also lists `gold_rate_alert_screen.dart` (`scripts/batch_responsive_fix.dart`).
- **Cannot be exercised at runtime** because the screens are unreachable. Layout correctness on phone/tablet/desktop is therefore **unverified** beyond the presence of the helper import.
- Tests `test/responsive/back_affordance_enumeration_test.dart` note the two jewellery rate/making-charges screens were previously a back-affordance gap (R9.2) and now carry their own AppBar — suggests prior responsive remediation. (Priority: **Low**, pending reachability.)

---

## 10. Performance

- Offline repo added bounded pagination (`paginate(..., limit, offset)`) for products/exchanges/orders/hallmark with a documented "return everything when limit null" legacy contract (D9 fix). Good. (`jewellery_repository_offline.dart`.)
- Risk: list screens that call `getProducts()`/`getOrders()` without passing `limit` will still load the entire box into memory and sort in Dart. **Unverified** which screens pass limits.
- Making-charges calculator is pure/synchronous and cheap. No perf concern.

---

## 11. Security (RBAC, capability bypass)

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 11.1 | **No RBAC/BusinessGuard on jewellery screens.** Other verticals wrap routes in `VendorRoleGuard` + `BusinessGuard(allowedTypes:[...])` in `routes.dart`. The jewellery GoRoutes (`jewellery_routes.dart`) have **no guards**. If GoRouter is ever wired, jewellery screens would lack role and business-type isolation. | `routes.dart` guard pattern vs `jewellery_routes.dart` (bare `GoRoute`). | High (latent) |
| 11.2 | **Capability layer bypassed** for un-flagged retail sidebar items shown to jewellery (return inwards, proforma, dispatch, low stock) — see §6.3. Hard-isolation intent (`business_capability.dart` "STRICTLY FORBIDDEN if not listed") is not enforced for these UI entries because the sidebar items omit `capability:`. | `sidebar_configuration.dart` retail items. | Medium |
| 11.3 | Old-gold exchange stores customer KYC (ID type/number, photo URL) — PMLA-sensitive PII. No field-level encryption or redaction evident in the Hive model. | `jewellery_repository_offline.dart` `OldGoldExchange` (customerIdNumber, customerPhotoUrl). | Medium |

---

## 12. Offline Mode Gaps

- Custom orders are **online-only** (§8.2) — creating/listing custom orders fails without connectivity, unlike the rest of the module.
- Gold-rate alerts / schemes / repairs offline behaviour **unverified** (repos not line-audited).
- Sync conflict resolution: offline repo uses `version`+`pendingOperation` and a retry queue but **last-write-wins** on push (`_syncProduct` posts and marks synced) — no server-version reconciliation visible. (Priority: **Medium**.)

---

## 13. Business Logic Inconsistencies (making charges / wastage / GST / gold rate)

| # | Finding | Evidence | Priority |
|---|---|---|---|
| 13.1 | **Two parallel pricing engines.** `JewelleryBusinessRules.billTotal` does `grossWeight × fineness × ratePerGram24K + making + tax − discount` (purity-aware, Decimal-based). `MakingChargesCalculator.calculateTotalPrice` does `metalWeight × metalRatePaisaPerGram + wastage + making + stone, then ×(1+gst)` (purity **not** applied — assumes the rate already matches the metal). These can disagree for the same sale. | `jewellery_business_rules.dart` vs `making_charges_calculator.dart`. | High |
| 13.2 | **Generic bill total likely qty-based, not weight-based.** Config `priceLabel:'Rate/Gm'` + required `quantity` + required `metalWeight`. Whether `BillCreationScreenV2` multiplies Rate/Gm × `metalWeight` (correct) or × `quantity` (wrong for jewellery) is **unverified**; unit test `test/unit/calculation_engine_test.dart` only checks 3% tax on a flat ₹25000, not weight×rate. If qty-based, jewellery bills are wrong. | `business_type_config.dart`; `calculation_engine_test.dart`. | High (unverified) |
| 13.3 | **GST simplification.** Flat 3% applied to entire subtotal incl. making/stone (`calculateTotalPrice`). Indian practice commonly treats making charges/labour at 5% — single-rate-on-all may misreport tax. | `making_charges_calculator.dart`. | Medium |
| 13.4 | **Per-10g vs per-gram rate mismatch** (see §8.4) — high risk of 10× pricing error if a per-10g card value is fed into a per-gram formula without dividing by 10. No bridging conversion found. | `jewellery_repository_offline.dart` vs `jewellery_business_rules.dart`. | High |
| 13.5 | Wastage only added to making charges when `applyOnWastage` true; metal-value wastage is computed separately in `calculateTotalPrice`. Double-counting risk if both paths used. | `making_charges_calculator.dart` `_calculatePerGram` + `calculateTotalPrice`. | Medium |

---

## 14. Data Validation Issues (weight, purity, rate)

- `JewelleryBusinessRules.billTotal`/`exchangeCredit` guard only `grossWeightGrams < 0` (returns 0). No upper bound, no NaN guard. (`jewellery_business_rules.dart`.)
- `MakingChargesCalculator` does not validate negative `metalWeightGrams`, negative rates, or `percentage > 100`; tiered path throws a bare `Exception('No tier found…')` if tiers list is empty and weight unmatched. (`making_charges_calculator.dart`.) (Priority: **Medium**.)
- Purity is a free-text `String?` on the bill item (`widget.item.purity`) rather than a constrained enum at the billing layer, even though `JewelleryBusinessRules.GoldPurity` and `PurityStandard` enums exist elsewhere — inconsistent typing invites bad data. (`bill_line_item_row.dart` vs `jewellery_business_rules.dart`.) (Priority: **Medium**.)
- HUID uniqueness: hallmark register uses HUID as the Hive key (`registerHallmark` `id: huid`) — duplicate HUID silently overwrites. No explicit duplicate check. (`jewellery_repository_offline.dart`.) (Priority: **Medium**.)
- Gold-rate entry (`setGoldRate`) accepts any non-negative paisa ints; no sanity bounds / day-over-day spike validation. (Priority: **Low**.)

---

## 15. UX Problems

- Dead dashboard quick actions (Custom Order, Gold Rate) — tapping does nothing (`business_quick_actions.dart`). (High)
- Fabricated alert counts mislead the user ('3' custom orders, '!' rate) (`business_alerts_widget.dart`). (High)
- Garbled `×`/`₹` glyphs in making-charges breakdown text (`making_charges_calculator.dart`). (Medium)
- Jewellery vendor is presented a generic retail sidebar full of items irrelevant or mismatched to their workflow (Tax B2B/HSN, dispatch notes, booking orders) while their actual tools (gold rate, hallmark, schemes) are absent. (High)

---

## 16. Accessibility

- Quick-action and alert widgets use icon + text labels (good for screen readers) but rely on color for state; no `Semantics` wrappers observed in `business_quick_actions.dart` / `business_alerts_widget.dart`.
- Count badge `'!'` (string) for the gold-rate alert conveys state by glyph only — not meaningful to assistive tech. (`business_alerts_widget.dart`.) (Priority: **Low/Medium**.)
- Full WCAG validation requires manual testing with assistive technologies and expert review — **not performed**.

---

## 17. Bugs / Errors / Crash Scenarios

| # | Scenario | Evidence | Priority |
|---|---|---|---|
| 17.1 | Tiered making charges throws uncaught `Exception` when `tieredRates` empty and weight unmatched. | `making_charges_calculator.dart` `_calculateTiered`. | Medium |
| 17.2 | Custom orders screen throws/blank when offline (online-only repo). | `jewellery_repository.dart` (throws on non-200). | High |
| 17.3 | Potential 10× pricing error from per-10g vs per-gram mismatch. | §8.4 / §13.4. | High |
| 17.4 | Garbled currency/multiplication glyphs render in calculation breakdown UI. | `making_charges_calculator.dart`. | Medium |
| 17.5 | Unknown sidebar IDs (none for jewellery today) would show the "Feature Not Found" placeholder — not a crash but a dead end. | `sidebar_navigation_handler.dart` `_buildPlaceholderScreen`. | Low |
| 17.6 | `jewellery_integration.dart` defines local `RouteBase`/`GoRoute` shadow classes — if ever imported alongside `go_router`, causes type collisions. | `jewellery_integration.dart` bottom. | Low |

---

## 18. Unnecessary / Irrelevant Features Shown

Because jewellery uses the generic retail sidebar (`_getRetailSections`), the following are shown but are off-workflow or capability-mismatched for a jeweller:
- `dispatch_notes`, `booking_orders`, `proforma_bids` (no proforma/dispatch capability) — **Medium**.
- `return_inwards` (no sales-return capability) — **Medium**.
- Full **Tax & Compliance** block (GSTR-1, B2B/B2C, HSN) — partially relevant (jewellery is 3% GST, HSN 7113) but presented generically — **Low**.
- `stock_valuation`/`turnover_analysis` are qty/amount based, not weight/purity based — misleading for metal stock — **Medium**.

Conversely, the jeweller is **missing** every tool they actually need (§3) — the inverse problem is the more serious one.

---

## 19. Recommendations & Prioritized Implementation Plan

### P0 — Critical (make the existing module reachable)
1. **Add a `case BusinessType.jewellery: return _getJewellerySections();`** in `sidebar_configuration.dart` with sections: Daily Rates (gold rate mgmt + alerts), Billing, Inventory (hallmark/by-weight), Old Gold Exchange, Custom Orders, Repairs, Gold Schemes, Making-Charges Calculator.
2. **Register jewellery IDs in `SidebarNavigationHandler.getScreenForItem`** mapping to the 8 existing screens, OR add guarded named routes in `lib/app/routes.dart` under "CUSTOM BUSINESS MODULES" following the existing `VendorRoleGuard`+`BusinessGuard(allowedTypes:[BusinessType.jewellery])` pattern.
3. **Pick one route surface** and delete/inline the dead `jewellery_integration.dart` to avoid drift; reconcile the screen set so all 8 are reachable (currently split across two surfaces, §6.4).

### P1 — High
4. Wire the two dashboard quick actions to real navigation (currently `onTap: () {}`), and source `business_alerts_widget` jewellery counts from the offline repo (pending custom orders, today's rate change) instead of hardcoded `'3'`/`'!'`.
5. Resolve **per-10g vs per-gram** rate units with a single conversion helper and unit tests; make `GoldRateCard` → `JewelleryProduct.pricePerGramPaisa` repricing explicit.
6. Unify pricing on **one** engine (prefer `JewelleryBusinessRules` Decimal path) and confirm `BillCreationScreenV2` multiplies Rate/Gm × metalWeight (not quantity); add a weight×rate calculation-engine test.
7. Make custom orders **offline-first** (migrate `custom_order_management_screen` to `JewelleryRepositoryOffline` or add a Hive-backed orders path) to match the rest of the module.
8. Add jewellery-domain capabilities to `business_capability.dart` (e.g., `useGoldRate`, `useMakingCharges`, `useHallmark`, `useOldGoldExchange`, `useCustomOrders`, `useGoldSchemes`, `useJewelleryRepair`) and gate the new sidebar items with them.

### P2 — Medium
9. Replace free-text purity in billing with the `GoldPurity`/`PurityStandard` enum; add weight/rate/percentage validation in the calculator; guard empty tiered-rate config.
10. Fix mojibake (`×`, `₹`) in `making_charges_calculator.dart` strings (save as UTF-8).
11. Correct GST treatment (separate making-charges GST if required) and remove wastage double-count risk.
12. Add HUID duplicate detection; consider encryption/redaction for old-gold KYC PII.
13. Add `Semantics` to dashboard widgets; replace glyph-only `'!'` badge with text.

### P3 — Low
14. Add certificate/certification model + screen (§3.11).
15. Add a live rate-feed integration option (vs MANUAL only).
16. Tidy placeholder route reuse and remove shadow `RouteBase`/`GoRoute` classes.

---

## 20. Confidence & Coverage

**Confidence: High** on the headline findings (orphaned module, retail-sidebar fallback, hardcoded dashboard data, empty quick-action handlers, capability set). These are backed by direct reads of the config, sidebar, nav handler, capability registry, dashboard widgets, the live `app.dart`/`routes.dart`, and grep proving no jewellery references in the live route map and no `routerConfig:`/`ModuleRouteBuilder.buildRoutes` wiring.

**Coverage:**
- Config / enum / sidebar / nav handler / capabilities / dashboard widgets: **fully read**.
- 8 screens: enumerated; reachability proven via grep + live router inspection. Individual screen widget internals (form layouts) **not** exhaustively read.
- Repositories: `jewellery_repository.dart` and `jewellery_repository_offline.dart` **fully read**; `gold_scheme`, `jewellery_repair`, `gold_rate_alert`, `making_charges` repositories **not line-audited**.
- Business logic: `jewellery_business_rules.dart` and `making_charges_calculator.dart` **fully read**.

**Key unverified items (explicitly flagged):**
- Whether `BillCreationScreenV2` total is weight-based vs qty-based (§13.2).
- Whether making-charges has an editable billing column (§4.2).
- Backend `/jewellery/*` endpoint existence/behaviour (§7).
- Runtime responsive correctness of the (unreachable) screens (§9).
- Internal logic of the four un-read jewellery repositories (§12).

---
*End of audit — Jewellery Shop.*
