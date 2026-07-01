# DukanX Audit — Business Type: `autoParts` (Auto Parts Shop)

> READ-ONLY, evidence-based audit. No source files were modified. Every "missing/broken/orphaned"
> claim cites the file/function checked. Items I could not verify are explicitly marked **unverified**.
>
> **Method / Sampling:** I read the verified starting points (enum, config, sidebar, nav handler,
> capability registry, feature resolver, dashboard widgets, the full `features/auto_parts/` folder,
> `modules/auto_parts/` routes, and the backend `auto-parts.ts` handler header). I grep-verified
> orphan/reachability claims across `lib/**`. I did **not** exhaustively read every retail screen
> implementation (e.g. each report screen body) — those are noted as "shared retail screen, behavior
> assumed from other audits / unverified for auto-parts specifics". Backend logic below line 80 of
> `auto-parts.ts` was sampled by schema + endpoint comments, not line-by-line.

---

## 1. Header — Resolution, Config, Capabilities

**Business type enum:** `BusinessType.autoParts` — defined in
`Dukan_x/lib/models/business_type.dart` (displayName `'Auto Parts'`, icon `Icons.build_rounded`).

**Sidebar resolution (verified):** `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart` →
`_getSectionsForBusiness(BusinessType type)` has **no `case BusinessType.autoParts`**. It therefore
falls through to `default: return _getRetailSections();`. **Auto Parts shows the generic 9-section
retail sidebar** (Dashboard & Control, Revenue Desk, BuyFlow, Inventory & Stock, Parties & Ledger,
Business Intelligence, Financial Reports, Tax & Compliance, Operations & Logs, Utilities & System).
There is **zero** auto-parts-specific navigation.

**Billing config (verified):** `Dukan_x/lib/core/billing/business_type_config.dart`
`BusinessType.autoParts`:
- `requiredFields`: `itemName`, `quantity`, `price`
- `optionalFields`: `vehicleModel`, `brand`, `hsnCode`, `discount`, `gst`
- `defaultGstRate: 28.0`, `gstEditable: true`
- `unitOptions`: `pcs`, `nos`, `set`
- `itemLabel: 'Part'`, `addItemLabel: 'Add Part'`, `priceLabel: 'MRP'`
- `modules: ['inventory','sales','returns','reports']`

**Capabilities (verified):** `Dukan_x/lib/core/isolation/business_capability.dart`
`businessCapabilityRegistry['autoParts']` grants: product add/name/salePrice/stockQty/unit/tax/category;
inventoryList/visibleStock/inventorySearch; invoiceCreate/List/Search; lowStockAlert/dailySnapshot/
revenueOverview; purchaseOrder/stockEntry/supplierBill; and specialized: **`useJobSheets`,
`useRepairStatus`, `useWarranty`, `useBarcodeScanner`, `useStockManagement`**.

**Capability gate engine (verified):** `Dukan_x/lib/core/isolation/feature_resolver.dart`
`canAccess()` is strict-deny; `_normalizeType` maps `'autoparts' → 'autoParts'`.

**Headline contradiction:** Auto Parts is granted `useJobSheets`/`useRepairStatus`/`useWarranty`
in the registry, but the **retail sidebar exposes none of them** and the nav handler maps none of
them (see §6). The capabilities are dead grants.

---

## 2. Missing Generic Features (Vyapar benchmark)

Retail sidebar items resolve to shared screens via
`Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart getScreenForItem()`. Against the Vyapar
benchmark:

| # | Vyapar feature | Status for autoParts | Evidence |
|---|----------------|----------------------|----------|
| 1 | Billing | Present (generic) | `new_sale → BillCreationScreenV2` |
| 2 | Inventory | Present (generic) | `stock_summary`, `item_stock → InventoryDashboardScreen` |
| 3 | Barcode/POS | **Capability only, no UI** | `useBarcodeScanner` granted but no scan item in `_getRetailSections()` | 
| 4 | Accounting | Present (generic) | `accounting_reports → AccountingReportsScreen` |
| 5 | Receivables/Payables | Present (generic) | `outstanding → PartyLedgerListScreen(receivable)` |
| 6 | Bank/Cash | Present (generic) | `cash_bank → CashflowScreen`, `bank_accounts → BankScreen` |
| 7 | Orders/Delivery | Present (generic) | `booking_orders`, `dispatch_notes` |
| 8 | OCR | **Missing** | autoParts lacks `useScanOCR` in registry; no OCR entry |
| 9 | Reports | Present (generic) | reports hub + GST screens |
| 10 | RBAC + audit | Present (generic) | `audit_trail → AllTransactionsScreen` (placeholder, see §11) |
| 11 | Multi-firm | **unverified** — not in sidebar scope reviewed |
| 12 | Backup | Present | `backup → BackupScreen` |
| 13 | Online store | **Missing** | no catalogue-commerce; `catalogue → CatalogueScreen` is share-only |
| 14 | e-Way bill | **Missing** | no e-Way item in sidebar; GST screens only (GSTR-1/HSN) |
| 15 | Loyalty | **Missing** | autoParts lacks `useLoyaltyPoints` (cf. jewellery/bookStore) |
| 16 | Service | **Orphaned** | job-card module exists but unreachable (see §6) |
| 17 | Offline-first sync | Partial/unmounted | `modules/auto_parts/sync/auto_parts_sync_handler.dart` exists but module not mounted (see §7) |

**Priority callouts:**
- **OCR missing (Medium):** Bill/part-invoice OCR would speed supplier-bill entry. Add `useScanOCR`
  to `autoParts` registry + scan entry, or document as out-of-scope.
- **e-Way bill missing (Medium):** Auto parts move physical goods (28% GST, often inter-state
  B2B) — e-Way is materially relevant. Recommended: surface e-Way generation in Tax & Compliance.

---

## 3. Missing Industry-Specific Features (Auto Parts domain)

The **backend already implements** most of these (`my-backend/src/handlers/auto-parts.ts`), but the
**Flutter app surfaces none** because there is no auto-parts sidebar/screen wiring.

| Domain need | Backend support | Flutter UI | Priority |
|-------------|-----------------|-----------|----------|
| Part number / SKU | `addPartSchema.sku` (POST `/auto-parts/parts`) | **No parts screen** in app (only generic inventory) | High |
| OEM number lookup / cross-reference | `oemCrossRefSchema`, `POST /auto-parts/oem-cross-ref`, `GET /auto-parts/oem-cross-ref/{number}` | **None** | High |
| Vehicle make/model/year fitment | `vehicleSchema`, `compatibleVehicles[]`, `POST /auto-parts/vehicle-lookup` | **None** (only optional `vehicleModel` free-text field on bill) | High |
| Aftermarket/alternate/quality grade | `quality: OEM\|OES\|Aftermarket\|Refurbished` | **None** | High |
| Brand-wise | `brand` (optional bill field + cross-ref) | Partial (free-text brand) | Medium |
| Garage/mechanic B2B credit | autoParts registry **lacks** `useCreditManagement`/`useCreditLimit` | **None** (generic party ledger only) | High |
| Shelf/bin/rack location | `addPartSchema.rackLocation` | **None** | Medium |
| Reorder level | `addPartSchema.reorderLevel` (default 5) | Generic low-stock only | Medium |
| Warranty on parts | `warrantyMonths`; registry grants `useWarranty` | **No warranty screen/field** for autoParts | High |
| Core-charge / exchange (old-part return) | **No backend field**; dashboard shows "Core Deposits"/"Core Forecast" labels only | **Label-only, no logic** | High |
| Job-card / fitment service | `createJobCardSchema`, `JobCardManagementScreen` | **Orphaned** (see §6) | Critical |
| 28% GST | `gstRate default 28` (backend) + `defaultGstRate 28.0` (config) | Present | OK |
| Supplier-wise procurement & rate | Generic BuyFlow supplier bills | Partial (not parts-rate-aware) | Medium |

**Top gap (Critical):** the entire job-card lifecycle (intake → diagnosis → … → delivered) is built
end-to-end (`features/auto_parts/...` + backend) but is **not reachable** from the running app.

**"Core Deposits" KPI with no backing (High):**
`Dukan_x/lib/features/dashboard/v2/config/dashboard_business_config.dart` sets
`kpi3Label: 'Core Deposits'` and `forecastLabel: 'Core Forecast'` for `autoParts`, but there is **no
core-charge data model anywhere** (not in `job_card_model.dart`, not in `addPartSchema`). The KPI is
a label with no data source.

---

## 4. Missing UI Components

- **No vehicle/fitment selector widget.** `vehicleModel` is only an optional free-text `ItemField`
  in `business_type_config.dart`; there is no make/model/year picker despite backend `vehicleSchema`.
  **Priority: High.**
- **No OEM cross-reference search component.** Backend `oem-cross-ref` endpoints have no Flutter
  consumer (grep: only `entity_action_service.dart` + the orphaned screen call `/auto-parts/*`).
  **Priority: High.**
- **No parts-catalog screen.** `addPartSchema`/`GET /auto-parts/parts` unused by Flutter.
  **Priority: High.**
- **Job-card create form is a stub.**
  `features/auto_parts/presentation/screens/job_card_management_screen.dart` →
  `_createNewJobCard()` does `Navigator.pushNamed(context, '/auto-parts/job-cards/create')`, and
  `JobCardEditScreen.build()` renders literal text `'… implement fields here'`. **Priority: High.**
- **No rack/bin location field** in any add-item UI (backend `rackLocation` exists). **Medium.**

---

## 5. Missing Widgets & Dashboard / KPI Cards

Dashboard V2 config (`dashboard_business_config.dart`, `BusinessType.autoParts`):
`revenueCardLabel: 'Parts Revenue'`, `kpi2Label: 'Part Requests'`, `kpi3Label: 'Core Deposits'`,
`invoiceTableName: 'Parts Invoice'`, `forecastLabel: 'Core Forecast'`.

**Alerts widget (verified):** `Dukan_x/lib/features/dashboard/v2/widgets/business_alerts_widget.dart`
- Title for autoParts (`_getAlertsTitle`): `'Parts & Request Alerts'`.
- `case BusinessType.autoParts` in `_buildAlertsForBusiness`:
  - `'Part Requests Pending'` → **`count: '9'` (HARDCODED string literal)**.
  - `'Warranty Claims'` → `count: '4'` (HARDCODED) **but gated by `caps.supportsSerialNumber`**.
- **BUG (High):** `caps.supportsSerialNumber` is derived in
  `Dukan_x/lib/core/config/business_capabilities.dart` as
  `FeatureResolver.canAccess(t, BusinessCapability.useIMEI)`. **autoParts does NOT have `useIMEI`**
  (it has `useWarranty`). Therefore `supportsSerialNumber == false` for autoParts and the
  **"Warranty Claims" alert never renders**, even though autoParts is granted `useWarranty`. Wrong
  capability gate. Recommended: gate on `useWarranty`, not `supportsSerialNumber`.
- **Hardcoded counts (High):** `'9'` and `'4'` are static literals, not sourced from any repository.
  No `AutoPartsRepository` call feeds them. (Pattern matches the computerShop/mobileShop audits.)

**Quick actions (verified):** `Dukan_x/lib/features/dashboard/v2/widgets/business_quick_actions.dart`
`case BusinessType.autoParts`:
- `'Part Search'` (icon `search_outlined`) → `nav.navigateTo(AppScreen.itemStock)`.
- `'Request Part'` (icon `minor_crash_outlined`) → `nav.navigateTo(AppScreen.purchaseOrders)`.
- **Missing actions:** New Job Card, Vehicle Lookup, OEM Cross-Ref, New Parts Invoice, Warranty Claim.
  **Priority: Medium-High.**

**Missing KPI cards (High):** open job cards by status (data exists in `AutoPartsRepository.getJobCards`),
warranty claims open/closed, parts-fitment hit rate, fast-moving SKU list, core-deposit balance
(no data) — none are surfaced.

---

## 6. Navigation & Route Gaps

**Each retail sidebar id → does it resolve in `getScreenForItem()`?** (verified against
`sidebar_navigation_handler.dart`)

- Dashboard & Control: `executive_dashboard`✔, `live_health`✔, `alerts`✔, `daily_snapshot`✔
- Revenue Desk: `revenue_overview`✔, `new_sale`✔, `receipt_entry`✔, `return_inwards`✔,
  `proforma_bids`✔, `booking_orders`✔, `dispatch_notes`✔, `sales_register`✔
- BuyFlow: `buyflow_dashboard`✔, `purchase_orders`✔, `stock_entry`✔, `stock_reversal`✔,
  `procurement_log`✔, `supplier_bills`✔, **`purchase_register`✔ but reuses `ProcurementLogScreen`**
  (duplicate mapping — Low).
- Inventory: `stock_summary`✔, `item_stock`✔, **`batch_tracking`** (gated by `useBatchExpiry`) →
  **filtered out for autoParts** because the registry does not grant `useBatchExpiry`; the screen
  exists but the item is hidden (correct isolation, noted for completeness), `low_stock`✔,
  `stock_valuation`✔, `damage_logs`✔
- Parties & Ledger: `customers`✔, `suppliers`✔, `party_ledger`✔, `ledger_history`✔,
  **`ledger_abstract` → `TrialBalanceScreen`** (semantic mismatch — Low), `outstanding`✔
- Business Intelligence: `analytics_hub`✔, **`turnover_analysis` → `AllTransactionsScreen`
  (placeholder mapping, Low)**, `product_performance`✔, **`daily_activity` → `AllTransactionsScreen`**,
  `procurement_insights`✔, `margin_analysis`✔, `insights`✔, `catalogue`✔
- Financial Reports: `invoice_margin → PnlScreen`, **`income_statement` → `PnlScreen` (same as
  invoice_margin, Low)**, `funds_flow`✔, `financial_position`✔, **`cash_bank` → `CashflowScreen`
  (same screen as funds_flow, Low)**, `accounting_reports`✔, `bank_accounts`✔, `daybook`✔,
  `credit_notes`✔, `expenses`✔
- Tax & Compliance: `gstr1`/`b2b_b2c`/`hsn_reports`/`tax_liability`/`filing_status` → all
  `GstReportsScreen(initialIndex: …)` ✔ (`gstr1` and `b2b_b2c` both use index 0 — Low).
- Operations & Logs: **`transaction_reports`, `activity_logs`, `audit_trail` all →
  `AllTransactionsScreen`** (three different sidebar items resolve to the same screen — Medium; in
  particular `audit_trail` is not a real audit-log view), `error_logs`✔
- Utilities & System: `print_settings`/`doc_templates` → both `PrintMenuScreen` (Low), `backup`✔,
  **`sync_status` → `BackupScreen` (reuse, Low)**, `device_settings`✔

**Is `JobCardManagementScreen` reachable or orphaned? — ORPHANED (Critical).**
- grep for `JobCardManagementScreen` across `lib/**` returns exactly two files: its definition
  (`features/auto_parts/presentation/screens/job_card_management_screen.dart`) and
  `Dukan_x/lib/modules/auto_parts/routes/auto_parts_routes.dart` (GoRoute `/auto-parts/jobcards`).
- It is **not** referenced in `sidebar_navigation_handler.dart` (no `case` for it) and **not** in the
  retail sidebar items. The running app uses the legacy `MaterialApp.routes` map, not the GoRouter
  module (per the header comment in `auto_parts_routes.dart`: routes "will be wired in" once GoRouter
  migration lands). **Net: the job-card screen cannot be opened by any autoParts user.**

**Dead link inside the orphaned screen (High):** `_createNewJobCard()` →
`Navigator.pushNamed(context, '/auto-parts/job-cards/create')`. grep finds **no route registration**
for `/auto-parts/job-cards/create` anywhere (only `/auto-parts/jobcards` in the unmounted GoRouter
module). Even if the screen were reachable, the "New Job Card" FAB would fail to navigate.

**Capability mismatch (High):** `useJobSheets` + `useRepairStatus` are granted to autoParts but no
sidebar item references them, so the grant is inert. Conversely, the dashboard "Warranty Claims"
alert is gated on `useIMEI`-derived `supportsSerialNumber` (false), not the granted `useWarranty`
(see §5).

---

## 7. Backend Integration Gaps

- **Rich backend, no Flutter consumer.** `my-backend/src/handlers/auto-parts.ts` implements
  job-cards (CRUD + status), parts (`POST/GET /auto-parts/parts`), `vehicle-lookup`, and
  `oem-cross-ref`. In Flutter, only `AutoPartsRepository`
  (`features/auto_parts/data/repositories/auto_parts_repository.dart`) calls the **job-card**
  endpoints, and that repository is only used by the **orphaned** `JobCardManagementScreen`. So
  vehicle-lookup, parts, and OEM cross-ref endpoints have **no Flutter client at all** (grep). 
  **Priority: High.**
- **GoRouter module not mounted.** `Dukan_x/lib/modules/auto_parts/auto_parts_module.dart` declares
  nav entries (Billing/Inventory/Job Cards/Vehicle Lookup) and `auto_parts_routes.dart`, plus
  `sync/auto_parts_sync_handler.dart` (`apiBasePath '/auto-parts/products'`) and a WS handler. The
  routes file's own comment states it is not wired into the running app. **Offline sync for parts is
  therefore not active in the shipped app. Priority: High (unverified whether any loader mounts it —
  I did not find a mount; marked unverified).**
- **Status enum mismatch across 3 layers (Critical) — see §13.**

---

## 8. Database & API Issues (real vs mock)

- **`AutoPartsRepository` uses the real API** (`core/api/api_client.dart`), not mock data. Endpoints:
  `GET/POST/PUT/PATCH/DELETE /auto-parts/job-cards[...]` + `/restore`. Response parsing is defensive
  (`data['items'] ?? data['jobCards'] ?? (data is List ? data : [])`). **No mock fallback** — if the
  endpoint is unreachable the screen shows an error (good), but the screen is orphaned anyway.
- **Hardcoded dashboard alert counts (High):** `business_alerts_widget.dart` autoParts case →
  `'9'` and `'4'` are literals (verified). They are **not** wired to `AutoPartsRepository` or any
  provider.
- **`estimatedCostPaisa` naming/units bug (Medium):** `job_card_model.dart` parses
  `estimatedCostPaisa` then the UI renders `'₹${job.estimatedCostPaisa.toStringAsFixed(2)}'` — i.e.
  it treats a *paise* field as *rupees*. If the backend sends paise (consistent with backend
  `estimatedCost … // in paise`), the displayed amount is **100× too large**. Verified in
  `job_card_management_screen.dart` `_buildJobCardRow` / `JobCardDetailScreen`.
- **No pagination** in `AutoPartsRepository.getJobCards` (loads all). High-SKU / high-volume garages
  could load large lists. **Medium.**

---

## 9. Responsive Design

`JobCardManagementScreen.build()` switches on `MediaQuery.size.width > 900` →
`_buildDesktopView()` (a `DataTable2` inside a fixed `SizedBox(width: 1200)` with horizontal scroll)
vs `_buildMobileView()` (`ListView` of cards). This is reasonable. **However** the desktop view uses
a hard-coded `width: 1200` / `minWidth: 1100`, which forces horizontal scrolling on smaller desktop
panes inside the shell. **Priority: Low.** (Other autoParts surfaces are shared retail screens;
their responsiveness is **unverified** here.)

---

## 10. Performance

- **No pagination / no lazy loading** in job-card list (§8). On large datasets the single
  `getJobCards()` call + full `DataTable2` build is O(n). `_buildDesktopView()` wraps in
  `RepaintBoundary` (good). **Priority: Medium.**
- **`setState` full-list rebuilds** on every status change (`_loadJobCards()` re-fetches all rather
  than patching one row). **Low.**
- Shared retail screens' performance is **unverified** for auto-parts data volumes.

---

## 11. Security (RBAC, capability-bypass)

- **Capability isolation is enforced server-side and client-side.** Backend `AUTOPARTS_OPTS` requires
  `requiredBusinessType: BusinessType.AUTO_PARTS` + `requiredFeature: AUTOPARTS_VEHICLE_LOOKUP`
  (`auto-parts.ts`). Client `FeatureResolver.canAccess` is strict-deny.
- **RBAC on sidebar** is applied in `sidebar_configuration.dart` via `RolePermissions.hasPermission`
  for items carrying a `permission`. **No retail item carries a `permission` string** in
  `_getRetailSections()` (only `capability` on `batch_tracking`), so **staff-role gating of
  individual retail menu items is effectively absent** for autoParts. **Priority: Medium** (a
  cashier sees Financial Reports / Tax / Audit items). Recommended: attach `permission:` to sensitive
  sections (financials, tax, audit).
- **`audit_trail` is not a real audit view** — it maps to `AllTransactionsScreen` (§6). Presenting a
  transaction list as "Audit Trail" is misleading for compliance. **Priority: Medium.**
- No capability-bypass found in the orphaned job-card screen (it goes through the authorized API).

---

## 12. Offline Mode Gaps

- **Parts offline sync handler exists but is in the unmounted module** (`auto_parts_sync_handler.dart`,
  collection `auto_parts_products`, `apiBasePath '/auto-parts/products'`). Since the GoRouter module
  is not wired into the running app (§7), **auto-parts-specific offline sync is not active**.
  Job-card reads/writes via `AutoPartsRepository` are **online-only** (direct `ApiClient` calls, no
  local cache/queue). **Priority: High** (a garage with intermittent connectivity cannot create job
  cards offline). *Whether the generic billing/inventory offline layer covers parts is unverified.*

---

## 13. Business Logic Inconsistencies

- **CRITICAL — Job-card status enum mismatch across three layers:**
  - UI options (`job_card_management_screen.dart` `_statusOptions`):
    `INTAKE, DIAGNOSIS, IN_PROGRESS, WAITING_PARTS, QUALITY_CHECK, READY, DELIVERED, CANCELLED`.
  - Domain rules (`utils/auto_parts_business_rules.dart` `JobCardStatus`):
    `intake, diagnosis, inProgress, waitingParts, qa, completed, delivered, cancelled`.
  - Backend (`auto-parts.ts` `updateJobCardSchema.status` enum):
    `INTAKE, DIAGNOSIS, AWAITING_PARTS, REPAIRING, QC, READY, DELIVERED, CANCELLED`.
  The UI sends `IN_PROGRESS` / `WAITING_PARTS` / `QUALITY_CHECK`, but the backend Zod enum expects
  `REPAIRING` / `AWAITING_PARTS` / `QC`. **A status update from the UI would be rejected by backend
  validation** (and the `completed` state in the domain rules exists in neither the UI nor backend).
  **Priority: Critical.** Recommended: define one canonical status enum and share it.
- **`_getNextStatuses` (UI) bypasses `AutoPartsBusinessRules.isValidTransition`.** The screen has its
  own hard-coded transition map; the audited, unit-tested `isValidTransition` in
  `auto_parts_business_rules.dart` is **never called by the screen** (it is only exercised by
  `test/features/auto_parts/auto_parts_business_rules_test.dart`). Duplicate, divergent state
  machines. **Priority: High.**
- **28% GST:** correct and consistent (`business_type_config.dart defaultGstRate 28.0`,
  backend `gstRate default 28`). But `gstEditable: true` allows lowering below 28% — auto parts are
  largely 28%; consider validation/warning. **Priority: Low.**
- **Fitment:** there is no compatibility/fitment enforcement in the bill flow — `vehicleModel` is a
  free-text optional field, so a part can be sold against any vehicle with no fitment check, despite
  the backend modeling `compatibleVehicles`. **Priority: High.**

---

## 14. Data Validation Issues

- **Free-text vehicle model** (`ItemField.vehicleModel`) — no make/model/year structure, no
  validation, no link to `vehicleSchema`. **Medium.**
- **Job-card create form is a stub** — no field validation exists because the form is unimplemented
  (`JobCardEditScreen` literal placeholder). **High.**
- **Paise/rupee ambiguity** for `estimatedCostPaisa` (§8) is also a validation/units defect.
  **Medium.**
- `JobCard.fromJson` defaults missing `status` to `'INTAKE'` and swallows bad dates
  (`DateTime.tryParse(...) ?? DateTime.now()`) — silent data coercion. **Low.**

---

## 15. UX Problems

- **No way to reach job cards / vehicle lookup / OEM cross-ref** from the UI (orphaned). For an
  auto-parts shop this is the core workflow. **Critical.**
- **"Request Part" quick action → Purchase Orders** (`AppScreen.purchaseOrders`) is a confusing
  mapping; a customer part-request is not a purchase order. **Medium.**
- **"Part Search" → generic `itemStock`** screen, which has no part-number/OEM search semantics.
  **Medium.**
- **Dashboard shows "Core Deposits" with no feature behind it** — users will expect a core-charge
  ledger that doesn't exist. **High (sets false expectations).**
- Generic retail sidebar exposes ~60 items irrelevant to a small parts shop (e.g. `dispatch_notes`,
  `proforma_bids`, full Tax suite) — cognitive overload. **Medium.**

---

## 16. Accessibility

- Job-card screen relies on color-coded status chips (`_getStatusColor`) with the status text
  alongside (text present — good), but action affordance is a bare `Icon(Icons.more_vert)` inside
  `PopupMenuButton` with **no tooltip/semantic label**. **Priority: Low-Medium.**
- FAB has a text label (good). Color contrast of status chips at 0.1 alpha backgrounds is
  **unverified** against WCAG. Full a11y validation requires manual AT testing.

---

## 17. Bugs / Errors / Crash Scenarios

1. **Status update rejected by backend** due to enum mismatch (§13). User sees "Failed to update
   status" on legitimate actions. **Critical.**
2. **"New Job Card" FAB dead-ends** — `Navigator.pushNamed('/auto-parts/job-cards/create')` has no
   registered route → navigation throws / no-op (§6). **High.**
3. **Cost displayed 100× too large** if backend returns paise (§8). **High.**
4. **Warranty alert silently never shows** for autoParts (wrong capability gate, §5). **High.**
5. **DI failure handling:** `JobCardManagementScreen.initState` guards `sl<…>()` and sets `_diError`,
   but the error is only rendered inside `_buildDesktopView()`; in **mobile view** (`width ≤ 900`)
   `_diReady`/`_diError` is **not checked**, so on DI failure the mobile list builds against an
   uninitialized `_repository` path (the list would just be empty, but `_loadJobCards` is skipped via
   early `return` in initState — net effect: silent empty screen, no error shown on mobile).
   **Medium.**

---

## 18. Unnecessary / Irrelevant Features Shown

Because autoParts uses `_getRetailSections()` verbatim, these are shown but of low/no relevance to a
typical parts shop, and several are duplicate-mapped:
- `proforma_bids`, `dispatch_notes`, `booking_orders` (full order/delivery suite) — Medium.
- Three items (`transaction_reports`, `activity_logs`, `audit_trail`) all open
  `AllTransactionsScreen` — redundant. **Medium.**
- `income_statement` and `invoice_margin` both open `PnlScreen`; `funds_flow` and `cash_bank` both
  open `CashflowScreen` — redundant. **Low.**
- Full GST/HSN/filing suite for a small parts shop may be excessive (but 28% B2B parts do file GST —
  keep). **Low.**

---

## 19. Recommendations & Prioritized Implementation Plan

**P0 — Critical**
1. **Unify job-card status enum** across UI / `auto_parts_business_rules.dart` / backend
   `updateJobCardSchema`; have the UI call `AutoPartsBusinessRules.isValidTransition`. (§13)
2. **Wire the job-card workflow into navigation.** Add a dedicated `_getAutoPartsSections()` in
   `sidebar_configuration.dart` (case `BusinessType.autoParts`) with Job Cards / Vehicle Lookup /
   OEM Cross-Ref / Parts Catalog, and add the corresponding `case`s in
   `sidebar_navigation_handler.getScreenForItem()` pointing at `JobCardManagementScreen` (etc.). (§6)
3. **Register the `/auto-parts/job-cards/create` route** (or convert the FAB to an in-place
   dialog/form). (§6)

**P1 — High**
4. Fix the **warranty-alert capability gate** to use `useWarranty` instead of `supportsSerialNumber`.
   (§5)
5. Replace **hardcoded dashboard counts** ('9','4') with real `AutoPartsRepository`-backed providers.
   (§5, §8)
6. Fix **paise→rupee** rendering of `estimatedCostPaisa`. (§8)
7. Build **fitment / OEM cross-ref / parts-catalog** Flutter clients for the existing backend
   endpoints, plus structured vehicle selector. (§3, §4, §7)
8. Add **garage/mechanic B2B credit** (grant `useCreditManagement`/`useCreditLimit` + UI). (§3)
9. Either implement **core-charge/exchange** or remove the "Core Deposits"/"Core Forecast" labels.
   (§3, §15)
10. Implement the **job-card create/edit form** (currently a stub). (§4, §14)
11. Provide **offline support** for job cards / parts (mount the module sync handler or add a local
    cache+queue). (§12)

**P2 — Medium**
12. De-duplicate redundant sidebar mappings; make `audit_trail` a real audit view. (§6, §11, §18)
13. Add part-number/OEM **barcode scan** entry (capability already granted). (§2)
14. Add **rack/bin location** + **reorder level** to part UI. (§3)
15. Attach RBAC `permission:` to sensitive sections (financials/tax/audit). (§11)
16. Trim irrelevant retail items for the parts vertical; add **pagination** to job-card list.
    (§10, §18)

**P3 — Low**
17. e-Way bill + OCR consideration; status-chip a11y labels; contrast review. (§2, §16)

---

## 20. Confidence & Coverage

**Confidence: High** on the structural findings (sidebar resolution, config, capability registry,
nav-handler mappings, orphaned job-card screen, hardcoded alert counts, status-enum mismatch, wrong
warranty capability gate) — all verified by direct file reads and grep.

**Coverage:**
- **Fully read:** `models/business_type.dart`; `core/billing/business_type_config.dart`;
  `widgets/desktop/sidebar_configuration.dart` (retail + other sections; ~1022/1162 lines loaded —
  remaining ~140 lines are additional `_get*Sections`/`_getCommonSections` not affecting autoParts
  resolution); `widgets/desktop/sidebar_navigation_handler.dart` (full); `core/isolation/
  feature_resolver.dart` (full); `core/isolation/business_capability.dart` (autoParts block + all
  registries, ~955/1129 lines — tail is the subscription-tier layer, sampled not full); the entire
  `features/auto_parts/` folder (4 files, full); `modules/auto_parts/` routes + module + sync (via
  grep); dashboard config + alerts + quick-actions autoParts branches; `business_capabilities.dart`
  `supportsSerialNumber` derivation; backend `auto-parts.ts` header + all Zod schemas + endpoint
  comments (lines 1–80 fully; remainder by schema/endpoint sampling).
- **Sampled / not exhaustively read (unverified specifics):** the bodies of shared retail screens
  (`InventoryDashboardScreen`, `BillCreationScreenV2`, report screens, etc.) for auto-parts-specific
  behavior; `session_manager.dart` RBAC matrix internals (only its use in the sidebar verified);
  whether any loader actually mounts the GoRouter auto-parts module; generic offline layer coverage
  for parts; WCAG contrast values.
- **Not in scope:** other business types except for cross-reference comparison.

---

### Top findings (summary)
1. **Auto Parts has no dedicated UI** — `sidebar_configuration.dart` falls to `default →
   _getRetailSections()`; the whole vertical runs on the generic retail sidebar.
2. **The job-card workflow is fully built but ORPHANED** — `JobCardManagementScreen` is referenced
   only by the unmounted GoRouter `modules/auto_parts/routes/auto_parts_routes.dart`, never by
   `sidebar_navigation_handler.dart` (grep-verified); its "New Job Card" FAB targets an unregistered
   route `/auto-parts/job-cards/create`.
3. **Critical status-enum mismatch** across UI / `auto_parts_business_rules.dart` / backend
   `updateJobCardSchema` (`IN_PROGRESS/WAITING_PARTS/QUALITY_CHECK` vs `REPAIRING/AWAITING_PARTS/QC`)
   — status updates would be rejected server-side; the audited `isValidTransition` is never called.
4. **Dashboard is fake/mis-gated** — autoParts alert counts `'9'`/`'4'` are hardcoded, and the
   "Warranty Claims" alert is gated on `useIMEI`-derived `supportsSerialNumber` (false for autoParts)
   instead of the granted `useWarranty`, so it never shows.
5. **Rich backend, no Flutter consumer** — `auto-parts.ts` ships vehicle-lookup, OEM cross-ref, and
   parts endpoints; only job-cards have a Flutter repository, and it's behind the orphaned screen.
6. **Industry essentials missing in-app:** fitment/compatibility, OEM cross-reference, core-charge
   (label-only KPI), B2B mechanic credit, rack/bin location — despite backend support for most.
