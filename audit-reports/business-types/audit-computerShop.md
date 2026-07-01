``````````````````````````````````````  # DukanX Business-Type Audit — Computer Shop

> Read-only, evidence-based audit. Every "missing/broken/orphaned" claim cites the file/function checked. Items I could not confirm are marked **unverified**.
>
> **Sampled (read in full or near-full):** `models/business_type.dart`; `core/billing/business_type_config.dart` (computerShop config + extensions); `widgets/desktop/sidebar_configuration.dart` (`_getSectionsForBusiness`, full `_getRetailSections`, restaurant/petrol/clinic/service variants); `widgets/desktop/sidebar_navigation_handler.dart` (full `getScreenForItem`); `core/isolation/business_capability.dart` (`'computerShop'` key + full registry); `app/routes.dart` (computer-shop block + service-job guards); `features/computer_shop/computer_shop.dart` (barrel); `features/computer_shop/data/repositories/computer_repository.dart` (full); `features/computer_shop/providers/computer_job_providers.dart` (full); `features/computer_shop/utils/computer_shop_business_rules.dart` (full); `features/computer_shop/presentation/widgets/computer_shop_sidebar.dart` (full); `features/computer_shop/presentation/screens/{job_card_list,warranty,create_job_card,multi_unit,serial_history}.dart` (full); `job_card_detail_screen.dart` (near-full, truncated tail); `features/dashboard/v2/widgets/business_quick_actions.dart` + `business_alerts_widget.dart` (full).
> **Sampled by directory listing / targeted grep only (internals unverified):** `features/computer_shop/presentation/widgets/{computer_barcode_scanner,job_card_dialogs,product_search_bottom_sheet}.dart`; `features/billing/presentation/screens/bill_creation_screen_v2.dart` (used by `new_sale`, not opened); `core/session/session_manager.dart` (RBAC — `Permission`/`RolePermissions.hasPermission` referenced from sidebar config only); `core/isolation/feature_resolver.dart` (`canAccess` behavior inferred from sidebar usage); `core/navigation/app_screens.dart` (`AppScreen.serviceJobs`/`AppScreen.exchanges` mappings not opened); backend Lambda endpoints behind `ApiClient` (`/computer/*`).

---

## 1. Header — Business Type, Sidebar Resolution, Config, Capabilities

**Business type:** `BusinessType.computerShop` (`Dukan_x/lib/models/business_type.dart`, 7th enum value). `displayName` = "Computer Shop", `icon` = `computer_rounded`; `emoji` = 💻, `primaryColor`/`pdfPrimaryColor` = `#3B82F6` (Blue) (`business_type_config.dart` extensions).

**Sidebar resolution:** computerShop is an explicit case in `_getSectionsForBusiness()` (`sidebar_configuration.dart`) but is **grouped with electronics + mobileShop** and returns the shared generic retail sidebar:
```dart
case BusinessType.electronics:
case BusinessType.mobileShop:
case BusinessType.computerShop:
  return _getRetailSections();
```
So computerShop renders the **generic retail sidebar** — 10 sections, ~58 items, **zero computer-shop-specific entries**: no service job-cards, no warranty register, no serial/RMA history, no multi-unit, no custom-builds/BOM, no AMC. Full id table in §6.

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

**Config summary** (`BusinessTypeRegistry._configs[BusinessType.computerShop]`):
- requiredFields: `itemName, quantity, price, brand, hsnCode`
- optionalFields: `serialNo, warrantyMonths, discount, notes` (notes used for specs: RAM/Storage)
- defaultGstRate: `18.0`, gstEditable: `false` (fixed 18%)
- unitOptions: `pcs, set, nos`
- itemLabel: `Product`, addItemLabel: `Add Product`, priceLabel: `MRP`
- modules: `['inventory','sales','repairs','custom_builds','reports']`

**Capability registry** (`business_capability.dart`, key `'computerShop'`): product add/name/salePrice/stockQty/unit/tax/category; inventory list/visibleStock/search; invoice list/search/create; `useLowStockAlert`, `useDailySnapshot`, `useRevenueOverview`; `usePurchaseOrder`, `useStockEntry`, `useSupplierBill`; specialized **`useIMEI`, `useWarranty`, `useJobSheets`, `useRepairStatus`, `useStockManagement`, `useBarcodeScanner`, `useMultiUnit`**. **Not granted:** `useSalesReturn`, `useProformaInvoice`, `useDispatchNote`, `useStockReversal`, `usePurchaseRegister`, `useInventoryExport`, `useBatchExpiry`, `useGeneralAlerts`, `useDeadStock`, `useExchange`, `useBuyback`, `useWarrantyClaim`/AMC (no such capability), `useCreditManagement`. (Compare mobileShop, which additionally gets `useBuyback`/`useExchange`.)

**Capability vs sidebar — the gates are inert.** computerShop's specialized capabilities (`useJobSheets`, `useRepairStatus`, `useWarranty`, `useMultiUnit`, `useIMEI`) gate **no item** in `_getRetailSections()`. The only capability-gated retail item is `batch_tracking` (gated `useBatchExpiry`), which computerShop **lacks**, so that single item is filtered out. Net effect: granting the computer-shop capabilities changes nothing in navigation.

**Unused dedicated sidebar widget (orphaned).** `features/computer_shop/presentation/widgets/computer_shop_sidebar.dart` defines `ComputerShopSidebarItems` (Service Job Cards / Create New Job / Warranty / Multi-Unit), `ComputerShopQuickActions`, and `ComputerShopDashboardSummary`. A workspace-wide grep for these symbols finds **only**: the class definitions themselves, the barrel `computer_shop.dart` export, golden-digest test manifests, and a markdown doc (`COMPUTER_SHOP_COMPLETE_IMPLEMENTATION.md`). **No production call site** (`ComputerShopSidebarItems.getItems(` is never invoked; `sidebar_configuration.dart` never imports it). The widget's own doc-comment says "Add these to your sidebar configuration file" — i.e. it was never wired in. **Confirmed orphaned.** Consequence: the dedicated computer-shop screens have **no sidebar entry point** for computerShop users.

---

## 2. Missing Generic (Vyapar Benchmark) Features

| # | Benchmark | Status for computerShop | Evidence | Priority |
|---|-----------|--------------------------|----------|----------|
| 1 | Billing/Invoicing | **Present (generic)** — `new_sale` → `BillCreationScreenV2`. Per-line serial/warranty rendering for computerShop **unverified** (bill screen not opened). | nav handler | — |
| 2 | Inventory (real-time, low-stock, FIFO, multi-warehouse, reorder, BOM) | **Generic only** — `stock_summary`/`item_stock`/`low_stock`/`stock_valuation`/`damage_logs`. No serial-wise stock, no FIFO/multi-warehouse/reorder, no BOM (despite `custom_builds` module). | sidebar; nav handler | High |
| 3 | Barcode/POS | **Partial** — `useBarcodeScanner` granted; a `computer_barcode_scanner.dart` widget exists but is not surfaced in the retail sidebar; quick-action "IMEI Lookup" is a dead button (`onTap: () {}`). | `business_quick_actions.dart` | High |
| 4 | Accounting | **Inherited generic** — `accounting_reports`, `income_statement`, `invoice_margin`, `daybook`. | sidebar | Low |
| 5 | Receivables/Payables | **Inherited generic** — `party_ledger`, `outstanding`, `credit_notes`. No EMI/credit (no `useCreditManagement`). | capability registry | Medium |
| 6 | Bank/Cash | **Inherited generic** — `bank_accounts`, `cash_bank`. | nav handler | Low |
| 7 | Orders/Delivery | **Partial generic** — `booking_orders`, `dispatch_notes`. No build-order with component reservation. | sidebar | Medium |
| 8 | OCR | **Missing entry point** — `useScanOCR` **not granted** to computerShop; no OCR item. | capability registry | Medium |
| 9 | Reports (37+) | **Generic hub** — `analytics_hub` → `ReportsHubScreen`. No repair-revenue, technician-productivity, warranty-liability, or serial-wise sales report. | nav handler | Medium |
| 10 | RBAC + audit | **Partial** — `audit_trail` id maps to `AllTransactionsScreen` (not a true audit log). Retail sidebar items carry no `permission` (§11). | nav handler | High |
| 11 | Multi-firm | **Unverified** — not surfaced in computerShop sidebar. | — | Medium |
| 12 | Backup | **Present** — `backup` → `BackupScreen`. | nav handler | Low |
| 13 | Online store | **Partial** — `catalogue` → `CatalogueScreen` (share only). | nav handler | Medium |
| 14 | e-Way bill | **Missing** — no e-Way bill id; relevant for high-value PCs/laptops. | sidebar grep | High |
| 15 | Loyalty | **Missing** — `useLoyaltyPoints` not granted; only line `discount`. | capability registry | Low |
| 16 | Service-business | **Exists but unreachable** — dedicated job-card system under `features/computer_shop/` is route-guarded but has **no sidebar/quick-action entry** (§6). | routes; sidebar | Critical |
| 17 | Offline-first sync | **Missing for this module** — `ComputerRepository` is REST-only via `ApiClient`; throws on non-200; no Drift/local cache (§12). | `computer_repository.dart` | High |

---

## 3. Missing Industry-Specific Features (Computer Shop)

| Need | Status | Evidence | Priority |
|---|---|---|---|
| Serial-number tracking | **Backend + read UI present** — `getSerials`, `getSerialHistory`, `serial_history_screen.dart` (timeline of jobs/RMA/warranty). No serial-wise **stock/inventory list** screen; serial entry tied only to job cards & checkout. | `computer_repository.dart`; `serial_history_screen.dart` | Medium |
| Custom PC builds (BOM → finished unit) | **Partial/Missing UI** — `modules` lists `custom_builds`; repo has `checkoutBuild(components, invoiceId)` + `getSerials`. **No build/BOM/assembly screen exists** (folder has no `build`/`bom` screen). `checkoutBuild` is an **orphaned repo method** (no UI caller found). | `computer_repository.dart`; folder listing | High |
| Component compatibility | **Missing** — no compatibility model/validator anywhere in `features/computer_shop/`. | folder listing | Medium |
| Warranty per-component & per-build | **Per-serial only** — warranty keyed on a single `serialNumber`/`productId` (`registerWarranty`). No multi-component or build-level warranty linkage. | `computer_repository.dart` (`ComputerWarranty`) | Medium |
| Repair/service job cards | **Present (core strength)** — device/fault/diagnosis/parts/labor/technician/status via `ComputerJobCard`, job_card screens, `job_card_dialogs.dart`. But **status cannot be advanced from UI** (§6, §13) and **not reachable from sidebar** (§6). | `computer_job_providers.dart`; `job_card_detail_screen.dart` | Critical |
| Multi-unit (bulk identical serials) | **Box/Pcs conversion only** — `multi_unit_screen.dart` configures product unit conversion (box→pcs). This is **not** bulk-serial intake; no bulk serial-range generation. | `multi_unit_screen.dart` | Medium |
| AMC / contracts | **Logic stub, no feature** — `ComputerShopBusinessRules.isAmcDue()` exists but is **never called** (orphaned); no AMC model, screen, repo, or route. | `computer_shop_business_rules.dart`; grep | High |
| Spare-parts inventory | **Generic inventory only** — parts added to a job via `addJobPart(productId,...)` deduct generic stock; no dedicated spares catalogue/min-stock for parts. | `computer_repository.dart` | Medium |
| RMA to vendor | **Backend + read UI; no create UI** — repo has `createRma`/`updateRmaStatus`; `serial_history_screen.dart` renders RMA list read-only. **No screen to create/update an RMA** (`createRma` orphaned in UI). | `computer_repository.dart`; `serial_history_screen.dart` | High |
| Software / license sales | **Missing** — no license/key model or field; `notes` is the only free-text field. | config; folder | Low |
| Refurbished stock | **Missing** — no condition/grade field or refurb flow. | config; folder | Low |
| EMI | **Missing** — no EMI/financing; `useCreditManagement` not granted. | capability registry | Medium |

---

## 4. Missing UI Components

- **No status-transition control** on `job_card_detail_screen.dart`. The app-bar `PopupMenuButton` exposes only `convert_invoice`, `assign_tech`, `update_labor`; the `_StatusBar` stepper is **display-only**. The provider method `JobCardDetailNotifier.updateStatus()` exists (`computer_job_providers.dart`) but **no widget calls it** (grep: only the provider's own definition). Result: a created job is stuck at `INTAKE` from the UI. Critical.
- **No product picker** in warranty register / multi-unit — `Product ID` and `Invoice ID` are raw free-text `TextFormField`s expecting UUIDs (`warranty_screen.dart` `_WarrantyRegisterTabState`; `multi_unit_screen.dart` `_ConfigureTab`/`_ConverterTab`). A `product_search_bottom_sheet.dart` widget exists in the folder but is not used by these forms (unverified usage elsewhere). High.
- **Photo upload is a URL-paste dialog**, not camera/gallery — `create_job_card_screen.dart` `_PhotoUploadSection._showAddPhotoDialog()` accepts a typed URL and renders via `NetworkImage`. Comment: "in production, integrate with camera/gallery". Medium.
- **No RMA-create / AMC / custom-build forms** (see §3). High.
- **Dead buttons:** `warranty_screen.dart` `_ErrorResult` "Register Warranty" button `onPressed` body is empty (`// Switch to register tab`); `serial_history_screen.dart` QR `IconButton` `onPressed` empty (`// Show QR code…`). Medium.

---

## 5. Missing Widgets & Dashboard / KPI Cards

- **Dashboard summary widget exists but unused.** `ComputerShopDashboardSummary` (openJobs / completedToday / warrantyExpiring) in `computer_shop_sidebar.dart` is never instantiated (grep). It also takes **caller-supplied ints** with no data source. Orphaned. Medium.
- **Dashboard alerts are HARDCODED for computerShop.** `business_alerts_widget.dart` `_buildAlertsForBusiness` (electronics/mobileShop/computerShop branch):
  - "Warranty Expiring" → `count: '5'` (gated by `caps.supportsSerialNumber`)
  - "Pending Repairs" → `count: '8'`
  These are string literals, **not** from `ComputerRepository`/job/warranty providers. (The widget's `alertCountsProvider` only fetches generic `lowStock`/`expiringSoon` from Drift and those counts are used **only** by the grocery branch.) High.
- **Quick actions don't reach the dedicated module.** `business_quick_actions.dart` computerShop branch: "New Repair" → `AppScreen.serviceJobs` (the **generic** `ServiceJobListScreen`, not `/computer-shop/job-cards`); "IMEI Lookup" → `onTap: () {}` (dead). No warranty-lookup, job-list, multi-unit, or serial-history action. High.
- **No repair-pipeline / KPI cards** (open jobs by status, technician load, warranty-expiry funnel, RMA aging). None exist. Medium.

---

## 6. Navigation & Route Gaps

**Retail sidebar id → screen resolution** (`sidebar_navigation_handler.dart getScreenForItem`). All ~58 ids in `_getRetailSections()` resolve to a real screen (none hit the `default` placeholder). Notable **alias/placeholder** mappings (same as other retail types):
- `turnover_analysis`, `daily_activity`, `ledger_history`, `transaction_reports`, `activity_logs`, **`audit_trail`** → all `AllTransactionsScreen` (audit_trail is not a real audit log).
- `invoice_margin` & `income_statement` → `PnlScreen`; `funds_flow` & `cash_bank` → `CashflowScreen`.
- `purchase_register` → `ProcurementLogScreen`; `ledger_abstract` → `TrialBalanceScreen`; `sync_status` → `BackupScreen`; `doc_templates` → `PrintMenuScreen`.

**Dedicated `/computer-shop/*` routes (all `BusinessGuard(allowedTypes:[computerShop])`, `app/routes.dart`):**

| Route | Screen | Permission | Reachable from UI? |
|---|---|---|---|
| `/computer-shop/job-cards` | `JobCardListScreen` | `viewInvoices` | **Only via named route** — referenced by the *unused* `computer_shop_sidebar.dart` (orphaned). No live sidebar/quick action. |
| `/computer-shop/create-job-card` | `CreateJobCardScreen` | `createInvoices` | Reachable from `JobCardListScreen` FAB/empty-state and `warranty_screen`/`serial_history_screen` — but only once you're already inside the (otherwise unreachable) module. |
| `/computer-shop/job-card-detail` | `JobCardDetailScreen` | `viewInvoices` | From `JobCardListScreen` tile / serial-history timeline tile. |
| `/computer-shop/warranty` | `WarrantyScreen` | `viewInvoices` | **Only via named route** / orphaned sidebar. |
| `/computer-shop/serial-history` | `SerialHistoryScreen` | `viewInvoices` | From `WarrantyScreen` result card "View History". |
| `/computer-shop/multi-unit` | `MultiUnitScreen` | `systemSettings` | **Only via named route** / orphaned sidebar. |

**Conclusion:** the entire dedicated computer-shop module is an **island** — every screen's only documented entry is the orphaned `computer_shop_sidebar.dart` or a typed named route. A real computerShop user navigating the live sidebar/dashboard **cannot reach** job-cards, warranty, serial-history, or multi-unit. The dashboard "New Repair" quick action instead routes to the **generic** service module (`AppScreen.serviceJobs`), which is a *different* job system (`features/service/`) than `features/computer_shop/`. **Critical orphaning + two parallel repair systems.**

**Also note** `app/routes.dart` `/job/create`, `/job/status`, `/job/deliver` allow `computerShop` (alongside mobileShop/service/electronics) and point at the **generic** `CreateServiceJobScreen`/`ServiceJobListScreen` — a second, overlapping job-card path with a **different permission** (`manageStaff`) than the dedicated `/computer-shop/create-job-card` (`createInvoices`). Permission inconsistency + duplication. High.

**Capability-vs-sidebar mismatch:** §1 — `useJobSheets`/`useRepairStatus`/`useWarranty`/`useMultiUnit`/`useIMEI` are granted but gate nothing in the rendered sidebar.

---

## 7. Backend Integration Gaps

- `ComputerRepository` (`computer_repository.dart`) wires a full REST surface to the Lambda backend: `/computer/job-cards` (+`/parts`,`/status`,`/assign`,`/labor`,`/convert-to-invoice`), `/computer/warranty`, `/computer/serials/{sn}/history`, `/computer/serials`, `/computer/products/multi-unit`, `/computer/stock/convert-unit`, `/computer/rma` (+`/status`), `/computer/checkout`. Endpoint existence/contracts on the server are **unverified** (backend not in scope here).
- **Orphaned backend calls (no UI caller, grep-confirmed within module):** `createRma`, `updateRmaStatus`, `checkoutBuild`, `getSerials`. These integrations are dead from the app side. High.
- **Provider method `updateStatus` orphaned** (no widget invokes it) — the `/computer/job-cards/{id}/status` PATCH is unreachable from UI. Critical.
- **Convert-to-invoice → no navigation to the invoice.** `JobCardDetailScreen._showConvertToInvoiceDialog` shows a success snackbar with `result['invoiceNumber']` but comment "// Navigate to invoice if needed" — no deep-link to the created bill. Medium.

---

## 8. Database & API Issues (Real vs Mock)

- **Job cards / warranty / serial history / multi-unit: REAL API-backed.** `computer_job_providers.dart` notifiers (`JobCardListNotifier`, `JobCardDetailNotifier`, `WarrantyNotifier`, `serialHistoryProvider`, `MultiUnitNotifier`) all call `ComputerRepository` against `ApiClient`. List screen has pagination + pull-to-refresh + infinite scroll wired to `listJobCards`. Genuinely real data. (Good.)
- **Dashboard alert counts: HARDCODED.** `business_alerts_widget.dart` computerShop branch emits literal `'5'` (warranty) and `'8'` (repairs) — not queried. The provided `alertCountsProvider` (Drift `lowStock`/`expiringSoon`) is not consumed by this branch. High. (Same class of issue documented for other retail types.)
- **Status model mismatch between layers.** `jobStatusOptionsProvider` uses `INTAKE/DIAGNOSIS/AWAITING_PARTS/REPAIRING/QC/DELIVERED`; `ComputerShopBusinessRules.ComputerJobStatus` uses `intake/diagnosis/partsOrdered/underRepair/qa/ready/delivered/cancelled`. The repo `status` is a raw `String` defaulting to `'INTAKE'`. Two incompatible vocabularies; `ready`/`cancelled` have no UI representation. Medium. (See §13.)
- **Currency inconsistency.** `job_card_list_screen.dart` and `serial_history_screen.dart` format money via `sl<CurrencyService>().symbol`, but `job_card_detail_screen.dart` `_PartsTab`/`_LaborTab` hardcode `symbol: '₹'`. Low.
- **Money unit ambiguity.** `convertJobToInvoice` takes `discountCents`; `ConvertToInvoiceDialog` passes `discountCents`; but `estimatedLaborCost`/`actualLaborCost`/`unitPrice` are plain doubles parsed from `json[...].toDouble()` with no documented paise/rupee convention (file header claims "paise on wire, rupees in models" but parsing does no division). Risk of 100× errors. **Unverified** against backend. High.

---

## 9. Responsive Design

- **Inconsistent responsive handling within the module.** `job_card_list_screen.dart`, `warranty_screen.dart`, `serial_history_screen.dart` wrap content in `BoundedBox(maxWidth: 800)` and use `responsiveValue<double>(...)` for title font. But `create_job_card_screen.dart` and `multi_unit_screen.dart` use **no `BoundedBox`** and a fixed title font (`fontSize: 20`), so on wide desktop these forms stretch edge-to-edge. Medium.
- Module screens use a hardcoded light theme (`backgroundColor: Color(0xFFF8FAFC)`, white app bars, `Color(0xFF1E293B)` text) — **ignores app dark/light theme**, unlike the themed placeholder screen in `sidebar_navigation_handler.dart` (which was fixed to use `Theme.of(context)`). Inconsistent with app theming. Medium.

---

## 10. Performance

- `JobCardListScreen` search filters **client-side only** (`_filterJobs`) over the already-paginated in-memory list, while status filter round-trips the server (`setStatusFilter`). Searching for an item not yet paged in silently returns nothing. Medium.
- `serial_history_screen.dart` uses `FutureProvider.family` with no cache invalidation strategy beyond manual `ref.refresh`; fine for the use case. Low.
- No obvious N+1 or heavy rebuild issues in the sampled screens. Low.

---

## 11. Security (RBAC, capability-bypass, route guards)

- **Route guards are correct and strict.** Every `/computer-shop/*` route is wrapped `VendorRoleGuard(...) → BusinessGuard(allowedTypes:[computerShop])` with denial messages (`app/routes.dart`). Cross-type access is blocked. Good.
- **Permission choices are weak/inconsistent for a service workflow:**
  - Creating a repair job = `Permissions.createInvoices`; viewing job-cards/warranty/serial = `viewInvoices`; multi-unit = `systemSettings`.
  - The parallel generic path `/job/create` (also allows computerShop) requires `manageStaff`. So the *same business action* (open a repair job) requires **different permissions** depending on which route is used. A user with `createInvoices` but not `manageStaff` can create via one path and not the other. Medium.
- **Retail sidebar items carry no `permission`/`capability`** (except `batch_tracking`), so RBAC is effectively not enforced at the navigation layer for computerShop — any logged-in vendor role sees all retail items. The filtering machinery exists (`sidebar_configuration.dart` evaluates `item.permission`/`item.capability`) but the retail items don't set them. High.
- Capability bypass: not observed for the dedicated routes (guarded by enum). The inert capabilities (§1) are a correctness/maintenance issue, not a bypass. 

---

## 12. Offline Mode Gaps

- **Module is online-only.** `ComputerRepository` issues `ApiClient` HTTP calls and `throw Exception(...)` on any non-200; notifiers surface the error string. There is **no Drift table, local cache, or sync queue** for job cards, warranty, serials, RMA, or multi-unit (contrast `business_alerts_widget.dart`, which reads Drift `productBatches`/products for offline counts). A computer shop with intermittent connectivity cannot intake jobs offline. High.
- No optimistic local write / replay; `Benchmark 17 (offline-first sync)` unmet for this module. High.

---

## 13. Business Logic Inconsistencies

- **Validated transition rules are never enforced.** `ComputerShopBusinessRules.isValidJobTransition()` encodes a clean lifecycle (`intake→diagnosis→{partsOrdered|underRepair}→…→ready→delivered`, cancel as sink). It is **never called** (grep). The actual UI can't change status at all (§4/§7), and even the provider's `updateStatus(String)` accepts any raw string with no validation. Dead rule + unguarded mutation path. High.
- **Two status enums + a raw string** for the same concept (§8). Medium.
- **Two parallel repair systems** for computerShop: dedicated `features/computer_shop/` job cards vs generic `features/service/` service jobs (reached by the dashboard quick action and `/job/*`). They have separate repositories, models, and status models. Data created in one is invisible to the other. High.
- **`isAmcDue` orphaned** — AMC concept defined but no feature consumes it. Medium.
- Job-card `serialNumber` is optional on intake (`create_job_card_screen.dart` no validator) yet serial is the join key for warranty/serial-history — a job created without a serial can't be tied into the serial timeline. Medium.

---

## 14. Data Validation Issues

- `create_job_card_screen.dart`: validates `brand`, `model`, and `reportedIssue` (min 10 chars). **Phone and email are not validated** — field hints say "10-digit mobile number" / "customer@example.com" but no format/length validators; any string is accepted. Medium.
- `warranty_screen.dart` register: requires serial/productId/invoiceId non-empty; **no serial format check**, no check that purchase-date + period is sane vs today (datepicker `lastDate: now` prevents future purchase — good). Product/Invoice IDs are raw UUID text (no existence check client-side). Medium.
- `multi_unit_screen.dart`: validates rate `>0`, but **allows primary unit == alternate unit** (e.g. `pcs → pcs`) with no guard; converter likewise allows `fromUnit == toUnit`. Medium.
- `create_job_card` photo: accepts any typed string as a URL → `NetworkImage(url)` with no URL validation (broken-image / crash risk on malformed input). Low.

---

## 15. UX Problems

- **No way to advance a repair.** The headline workflow (job lifecycle) dead-ends at INTAKE from the UI (§4). Critical for a repair-centric business.
- **UUID-in-textbox** for Product ID / Invoice ID / Customer ID across warranty + multi-unit forms — unusable for a shopkeeper; needs pickers/scanners. High.
- **Dead/no-op buttons:** warranty "Register Warranty" (error card) and serial-history QR icon (§4). Medium.
- **Discoverability:** dedicated features have no menu/dashboard entry (§6); only reachable by typing routes. Critical.
- `convert-to-invoice` gives a snackbar but no link to open the resulting invoice (§7). Medium.
- Module screens ignore app theme (forced light) — jarring for dark-theme users (§9). Low.

---

## 16. Accessibility

- Icon-only controls lack semantics/tooltips: `job_card_list` refresh `IconButton`, `serial_history` QR `IconButton`, photo-remove `GestureDetector` (`create_job_card`) have no `Semantics`/`tooltip`. Medium.
- Status conveyed by **color only** in `_JobCardTile`, `_StatusBar`, RMA chips (color map in `_getStatusColor`/`_getRMAStatusColor`) — though a text label accompanies most, the stepper dots in `_StatusBar` are color/checkmark only. Medium.
- Form fields rely on `labelText` (good), but hardcoded grey-on-light palette (`Color(0xFF64748B)` on `#F8FAFC`) — contrast not verified against WCAG AA; **unverified**. Full a11y validation requires manual testing with assistive tech. Low.

---

## 17. Bugs / Errors / Crash Scenarios

- **CRITICAL — `TabBar` without a `TabController`/`DefaultTabController` (likely runtime crash).** `warranty_screen.dart`, `multi_unit_screen.dart`, and `job_card_detail_screen.dart` each build a `TabBar(onTap: …, tabs: […])` inside a plain `Column` (content shown via a separate `IndexedStack` keyed on `_selectedTab`). There is **no `controller:` argument and no `DefaultTabController` ancestor** in any of the three. Per Flutter, a `TabBar` with no controller and no enclosing `DefaultTabController` throws *"No TabController for TabBar … DefaultTabController … or provide a TabController"* at build. This strongly indicates these three screens **throw on open**. (Not executed here — flagged from code reading; treat as a high-confidence crash.) Critical.
- **Photo `NetworkImage` on arbitrary user text** can throw/log image-load errors and shows broken tiles (§14). Low.
- `JobCardListScreen._filterJobs` returns empty for not-yet-paged matches — looks like "no results" bug to the user (§10). Medium.
- `convertToInvoice`/`addPart`/`assignTechnician` all `rethrow` after setting error state, and the detail screen catches and snackbars — OK; but `_showAddPartDialog`/`_showConvert…` call `Navigator.pop(context)` inside `await` callbacks without `mounted` checks → potential "use of BuildContext across async gaps" if the sheet is dismissed mid-flight. Low/Medium.

---

## 18. Unnecessary / Irrelevant Features Shown (Shared Retail Sidebar)

computerShop renders the full generic retail sidebar (§1). Items with no clear computer-shop relevance that are nonetheless shown:
- **BuyFlow §2** `dispatch_notes`, `booking_orders` (dispatch/booking flows aimed at wholesale/hardware); `stock_reversal`/`purchase_register` although `useStockReversal`/`usePurchaseRegister` are **not granted** as capabilities — the items aren't capability-gated, so they appear regardless (capability/sidebar mismatch). Medium.
- **Tax & Compliance §7** full GSTR-1/B2B-B2C/HSN suite — relevant but heavy for a small shop; fine to keep. Low.
- Meanwhile the sidebar **omits** everything computer-shop-specific (jobs, warranty, serials, builds). The mismatch is less "irrelevant items shown" and more "relevant items hidden" (§6). High.
- Flag: because the dedicated `computer_shop_sidebar.dart` was never wired, the *intended* computer-shop section is entirely absent from the live UI. High.

---

## 19. Recommendations & Prioritized Implementation Plan

**Critical**
1. **Wire the dedicated module into navigation.** Add a computer-shop sidebar section (job-cards, create-job, warranty, serial lookup, multi-unit) — either by branching `_getSectionsForBusiness` to a `_getComputerShopSections()` or by finally consuming `ComputerShopSidebarItems`. Gate items by the already-granted capabilities (`useJobSheets`, `useWarranty`, `useMultiUnit`). (`sidebar_configuration.dart`, `sidebar_navigation_handler.dart`.)
2. **Fix the `TabBar` crash** in `warranty_screen.dart`, `multi_unit_screen.dart`, `job_card_detail_screen.dart` — wrap in `DefaultTabController` (and bind the `IndexedStack`/`onTap` to its index) or pass an explicit `TabController`.
3. **Add a status-change UI** to `JobCardDetailScreen` that calls `JobCardDetailNotifier.updateStatus`, enforced through `ComputerShopBusinessRules.isValidJobTransition` (after unifying the status vocabulary).

**High**
4. Replace hardcoded dashboard counts ('5'/'8') with real queries (open jobs by status, warranty expiring) from `ComputerRepository`. (`business_alerts_widget.dart`.)
5. Point the dashboard "New Repair" quick action at `/computer-shop/job-cards`/`create-job-card` (not the generic service module); implement "IMEI Lookup". (`business_quick_actions.dart`.)
6. **Resolve the two-parallel-repair-systems problem** — pick `features/computer_shop` as canonical for computerShop and either remove computerShop from `/job/*` guards or make them redirect; align permissions.
7. Build **RMA-create** and **custom-build/BOM** screens to activate orphaned repo methods (`createRma`, `updateRmaStatus`, `checkoutBuild`, `getSerials`); add **AMC** feature consuming `isAmcDue`.
8. Add **offline support** (Drift cache + sync queue) for job cards/warranty.
9. Confirm/repair the **paise-vs-rupee** convention end-to-end (§8) before money bugs ship.
10. Replace UUID text fields with **product/customer/invoice pickers** (reuse `product_search_bottom_sheet.dart`).

**Medium**
11. Unify the job-status enum (single source of truth) across provider, business rules, and backend string.
12. Make `create_job_card` photo upload use camera/gallery; validate phone/email; require serial when warranty linkage is intended.
13. Apply `BoundedBox` + `responsiveValue` consistently; respect app theme.
14. Add repair/warranty/technician reports to the reports hub.
15. Guard `multi_unit` against `primary == alternate` unit.

**Low**
16. Centralize currency formatting via `CurrencyService` in detail tabs.
17. Add semantics/tooltips to icon buttons; ensure non-color status cues.
18. Remove/disable the dead "Register Warranty" and QR buttons or implement them.

---

## 20. Confidence & Coverage

- **High confidence (read in full):** config + enum + capability registry for computerShop; full retail sidebar + nav handler; all six `/computer-shop/*` routes & guards; the entire `features/computer_shop/` repository, providers, business-rules, the orphaned sidebar widget, and all six screens (detail screen tail truncated but all tabs/handlers seen); both dashboard widgets. Orphaning of `computer_shop_sidebar.dart`, `updateStatus`, `createRma`, `checkoutBuild`, `isValidJobTransition`, `isAmcDue` confirmed by workspace grep.
- **Medium confidence (inferred):** `TabBar`-without-controller crash (Flutter framework behavior, not executed); paise/rupee money convention (header comment vs parsing code); RBAC enforcement specifics (only `hasPermission` wiring in sidebar config seen).
- **Unverified (not opened / out of scope):** `bill_creation_screen_v2.dart` rendering of computerShop serial/warranty/notes fields; `job_card_dialogs.dart`, `computer_barcode_scanner.dart`, `product_search_bottom_sheet.dart` internals; backend Lambda `/computer/*` contracts and existence; `core/session/session_manager.dart` full RBAC matrix; `app_screens.dart` `serviceJobs`/`exchanges` target screens; WCAG contrast values.
- **Not run:** no code executed, built, or modified. This is a static, read-only review. No source files were changed; only this report was created.
