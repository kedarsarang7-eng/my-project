# DukanX Business-Type Audit — 📚 Book Store (`bookStore`)

**Scope:** READ-ONLY, evidence-based audit of the `bookStore` business type.
**Method:** Every claim cites a file path and (where relevant) function/line. Items that could not be verified are marked **unverified**.
**Date:** Generated from source inspection.

### Sampling statement (what was read vs skipped)
**Fully read:**
- `lib/models/business_type.dart`
- `lib/core/billing/business_type_config.dart` (bookStore config block)
- `lib/widgets/desktop/sidebar_configuration.dart` (`_getSectionsForBusiness`, `_getRetailSections`)
- `lib/widgets/desktop/sidebar_navigation_handler.dart` (`getScreenForItem`)
- `lib/widgets/desktop/content_host.dart` (`_screenBuilders`, `_buildScreen`)
- `lib/core/isolation/business_capability.dart` (`bookStore` set) + `feature_resolver.dart`
- `lib/features/dashboard/v2/widgets/business_quick_actions.dart` + `business_alerts_widget.dart`
- All 5 screens in `lib/features/book_store/presentation/screens/`
- Both widgets in `lib/features/book_store/presentation/widgets/`
- `lib/features/book_store/data/book_repository.dart`
- `lib/features/book_store/utils/book_store_business_rules.dart`
- `lib/modules/book_store/book_store_module.dart` + `routes/book_store_routes.dart`
- `lib/core/billing/strategies/book_store_strategy.dart`
- `lib/core/navigation/app_screens.dart` (id/fromId), `navigation_controller.dart`
- `lib/app/routes.dart` (book store named-route block)

**Sampled/skimmed:** `lib/core/config/business_capabilities.dart` (flag derivation only), `endpoint_results.csv` (backend endpoint inventory), `my-backend/src/handlers/book_store.ts` (signatures via grep).
**Skipped (not audited in depth):** `modules/book_store/sync/book_store_sync_handler.dart`, `modules/book_store/websocket/book_store_ws_handler.dart`, full backend handler bodies, Drift table definitions, test file `test/features/book_store/book_store_business_rules_test.dart`. These are flagged **unverified** where they would affect a conclusion.

---

## 1. Header — Resolution, Config, Capabilities

### 1.1 Sidebar resolution
- `bookStore` has **no dedicated sidebar**. In `sidebar_configuration.dart` → `_getSectionsForBusiness(BusinessType type)`, there is no `case BusinessType.bookStore:`; it falls through to `default: return _getRetailSections();`.
- **Effect:** The Book Store user sees the **generic 10-section retail sidebar** (`_getRetailSections()`): Dashboard & Control, Revenue Desk, BuyFlow, Inventory & Stock, Parties & Ledger, Business Intelligence, Financial Reports, Tax & Compliance, Operations & Logs, Utilities & System. **Zero** book-specific entries (no ISBN catalogue, no consignment, no school/institution orders, no publisher returns).

### 1.2 Config (`business_type_config.dart`, `BusinessType.bookStore` block)
- `requiredFields`: `itemName`, `quantity`, `price`
- `optionalFields`: `isbn`, `brand` (publisher), `discount`, `gst`
- `defaultGstRate`: **12.0**, `gstEditable`: **true**
- `unitOptions`: `[pcs, set]`
- `itemLabel`: `'Book'`, `addItemLabel`: `'Add Book'`, `priceLabel`: `'MRP'`
- `modules`: `['inventory', 'sales', 'school_orders', 'reports']`
- Display: `displayName` = "Book Store", `icon` = `menu_book_rounded`, `emoji` = 📚, `primaryColor`/`pdfPrimaryColor` = `#8B5CF6` (Violet).

### 1.3 Capabilities (`business_capability.dart`, `'bookStore'` set)
Granted: product add/name/salePrice/stockQty/unit/tax/category; inventory list/visibleStock/deadStock/search/**export**; invoice create/list/search/**salesReturn**; alerts lowStock/general/dailySnapshot/revenueOverview; purchase order/stockEntry/supplierBill/purchaseRegister; specialized **`useISBN`**, **`usePublisherReturns`**, **`useLoyaltyPoints`**, `useBarcodeScanner`, `useScanOCR`, `useStockManagement`.
- `FeatureResolver._normalizeType` correctly maps `bookstore`→`bookStore` (verified in `feature_resolver.dart`), so gating resolves.
- **Gap:** No capability key exists for **school/institution bulk orders** or **consignment** — these are represented only as a module string (`'school_orders'`) in config and as `featureKey`s in the module manifest, not as gateable `BusinessCapability` enum values. They cannot be RBAC/plan-gated through `FeatureResolver`.

---

## 2. Missing Generic Features (vs Vyapar benchmark)

| # | Vyapar feature | Status for bookStore | Evidence |
|---|----------------|----------------------|----------|
| 1 | Billing | Partial — generic `new_sale`→`BillCreationScreenV2` works; dedicated `BookPosScreen` is **orphaned** | `sidebar_navigation_handler.dart` (`new_sale`); §6 |
| 2 | Inventory | Generic inventory screens wired; book-specific `BookInventoryScreen` orphaned + uses mock data | §6, §8 |
| 3 | Barcode/POS | ISBN scan exists in orphaned POS; generic sidebar has no scan entry | `book_pos_screen.dart`, §6 |
| 4 | Accounting | Generic (P&L, trial balance) via retail sidebar | `_getRetailSections()` Financial Reports section |
| 5 | Receivables/Payables | Generic (`outstanding`, `party_ledger`) | retail sidebar |
| 6 | Bank/Cash | Generic (`cash_bank`, `bank_accounts`) | retail sidebar |
| 7 | Orders/Delivery | Generic booking/dispatch; no book order tracking in live UI | retail sidebar |
| 8 | OCR | `useScanOCR` granted but "ISBN Scan" quick action has **empty onTap** | `business_quick_actions.dart` (bookStore case) |
| 9 | Reports (37+) | Generic reports hub | retail sidebar |
| 10 | RBAC + audit | Generic; book named-routes guarded, but orphaned | `app/routes.dart` |
| 11 | Multi-firm | **unverified** (not inspected) | — |
| 12 | Backup | Generic `backup` | retail sidebar |
| 13 | Online store | **unverified** | — |
| 14 | e-Way bill | Not applicable to most book retail; **unverified** | — |
| 15 | Loyalty | UI present but **fake** (uses `totalPaid` proxy, no redemption) | `customer_loyalty_widget.dart`; §13 |
| 16 | Service-business | N/A | — |
| 17 | Offline-first sync | **Partial gap** — book_repository uses raw apiClient (no offline queue) | `book_repository.dart`; §12 |

**Priority — High:** The dedicated Book Store experience (POS, catalogue, consignment, school orders, returns) is built but **not reachable** from the live sidebar; the user effectively gets generic retail. See §6.

---

## 3. Missing Industry-Specific Features

| Need | Status | Evidence / Priority |
|------|--------|---------------------|
| ISBN scan & lookup | Scan UI exists (`IsbnScannerWidget`); POS looks up **local Products table** via `productsRepository.search`, **not** the backend ISBN lookup (`GET /book-store/isbn/{isbn}` exists in `endpoint_results.csv` but is **unused** by Flutter). No external ISBN metadata autofill. | **High** — `book_pos_screen.dart` `_handleIsbnScan`; backend endpoint unused |
| Title/Author/Publisher/Edition | Catalogue stores author/publisher in a local `_BookRow` model only; **not persisted** to the Products record (createProduct sends name/barcode/category/price/stock only). **Edition** field absent everywhere. | **High** — `book_inventory_screen.dart` `_showAddBookDialog` |
| Syllabus/class-wise & school bulk orders | `SchoolOrderScreen` exists (school + grade + sets fulfillment) but **orphaned** (no live entry). No syllabus/class-set composition. | **High** — `school_order_screen.dart`; §6 |
| Consignment (sale-or-return) + publisher settlement | `ConsignmentSettlementScreen` exists with received/sold/unsold + settle; **orphaned**. Settlement amount is server-provided & freely editable (no computed formula). | **High** — `consignment_settlement_screen.dart`; §13 |
| Supplier/publisher returns | `BookSupplierReturnsScreen` PO tab works; **Publisher Returns tab is a "future update" placeholder** despite `usePublisherReturns` capability + backend `createBookReturn`/`listBookReturns`. | **High** — `book_supplier_returns_screen.dart` `_showNewReturnDialog` |
| Stationery + books mixed inventory | Category dropdown is hardcoded `[All, Fiction, Classic, Textbook, Self-Help]` — no Stationery category; no GST-class separation. | **Medium** — `book_inventory_screen.dart` |
| GST slabs (books exempt vs stationery 12/18%) | Single `defaultGstRate: 12.0`; strategy comment claims "GST-exempt 0%"; POS computes **no tax at all**. | **Critical** — see §13 |
| Loyalty for students/parents | Widget shows points but value is `customer.totalPaid` proxy; no accrual/redemption logic. | **High** — `customer_loyalty_widget.dart` |
| Set/bundle (full class set) | `UnitType.set` available; no bundle/BOM composition to expand a set into constituent titles. | **Medium** — config `unitOptions` |
| Seasonal reorder (new academic year) | Not implemented anywhere. | **Medium** — **unverified beyond search** |
| Secondhand/used books | `BookStoreBusinessRules.suggestedResalePrice` + `BookCondition` exist but are **unused by any screen**; "Used Books" module route redirects to generic `/inventory`. | **High** — `book_store_business_rules.dart`; `book_store_routes.dart` |

---

## 4. Missing UI Components
- **No catalogue grid in POS:** `book_pos_screen.dart` left "Product Grid" `ListView.builder` has `itemCount: 0` with a comment "Will be populated from database" — search box does nothing; only ISBN-scan adds to cart. **High.**
- **No book detail/edit screen:** Inventory add dialog only; no edit/delete row, no per-book history. **Medium.**
- **No tax/GST line in POS totals:** totals show Subtotal → Discount → Grand Total only. **Critical** (see §13).
- **No publisher master / school master UI:** publisher is a free-text field; schools come from server with no add/edit. **Medium.**
- **No syllabus/class-set builder, no used-book intake form.** **Medium.**

---

## 5. Missing Widgets & Dashboard / KPI Cards
- **Dashboard alerts are hardcoded** (`business_alerts_widget.dart`, `case BusinessType.bookStore`): two static rows — "Bestsellers Low Stock" count **`'11'`**, "Category Stock Low" count **`'6'`**. Title returned by `_getTitle` = **"Inventory Alerts"**. Unlike the `grocery` branch (which reads live `counts['lowStock']`/`counts['expiringSoon']` from `alertCountsProvider`), the bookStore branch **never reads `counts`** — values are fabricated. **High.**
- **Quick actions** (`business_quick_actions.dart`, bookStore case): "Book Search"→`bookCatalogue`, "ISBN Scan"→empty `onTap`, "Returns"→`bookReturns`, plus common "Alerts". Two of these are dead links (§6). **High.**
- **No book-specific KPI cards** (titles in stock, consignment payable, school-order fulfillment %, returns pending). The inventory screen has 3 local stat cards (Total Titles/Total Stock/Low Stock) but computed from **mock data**. **Medium.**

---

## 6. Navigation & Route Gaps (core finding)

### 6.1 Retail sidebar IDs → resolution
All IDs emitted by `_getRetailSections()` resolve in `sidebar_navigation_handler.getScreenForItem` or `content_host._screenBuilders` (spot-checked: `executive_dashboard`, `new_sale`, `stock_summary`, `low_stock`, `customers`, `gstr1`, `backup`, etc. all map). No book IDs are present in either map, so **no book screen is reachable from the sidebar**.

### 6.2 Orphaned book_store screens
| Screen | Reachable in live app? | Evidence |
|--------|------------------------|----------|
| `BookPosScreen` | **No** — only `export`ed in `book_store.dart`; no entry in `content_host`, `getScreenForItem`, module routes, or `app/routes.dart`. | grep: only self-reference |
| `BookInventoryScreen` | **No** (live). Referenced only by unmounted `GoRoute('/books/inventory')`. | `book_store_routes.dart` |
| `BookSupplierReturnsScreen` | **No** — only barrel `export`; no route at all. | `book_store.dart` |
| `ConsignmentSettlementScreen` | **No** (live). Defined as named route `/book_store/consignments` (guarded) **but nothing navigates to it**; also unmounted `GoRoute('/books/consignment')`. | `app/routes.dart`, `book_store_routes.dart` |
| `SchoolOrderScreen` | **No** (live). Named route `/book_store/school_orders` exists, **no navigator pushes it**; also `GoRoute('/books/institutions')` (unmounted). | `app/routes.dart`, `book_store_routes.dart` |

### 6.3 Dead links from Dashboard V2
- `AppScreen.bookCatalogue` → `id` resolves to `book_catalogue` (default snake_case in `app_screens.dart`) → not in `content_host._screenBuilders` → `getScreenForItem('book_catalogue')` → `default:` → **`_PlaceholderScreen` "Feature Not Found"**.
- `AppScreen.bookReturns` → `book_returns` → same **placeholder**.
- "ISBN Scan" action `onTap: () {}` — **no-op**.
- "Alerts" action → `AppScreen.alerts` → resolves to `AlertsScreen` (OK).
**Priority — Critical:** 3 of 4 Book Store dashboard quick actions are non-functional.

### 6.4 GoRouter module not mounted
`book_store_routes.dart` and `BookStoreModule.navItems` (Billing, Inventory, Scan Bill, Consignment, Institutions, Used Books) are GoRouter constructs. Multiple in-repo comments confirm the app still uses `MaterialApp.routes` and **GoRouter is not yet wired** ("once `MaterialApp` migrates to `GoRouter`…" in `book_store_routes.dart`, `legacy_route_redirect.dart`, `auto_parts_routes.dart`). `module_loader.dart` registers `BookStoreModule()`, but its routes/navItems are not surfaced in live navigation. **High.**

### 6.5 Capability mismatches
- `usePublisherReturns` granted, but the only returns UI is a placeholder dialog. **High.**
- `useLoyaltyPoints` granted, but loyalty is a fake proxy with no redemption. **High.**
- `school_orders` module + featureKeys exist with **no `BusinessCapability`** to gate them. **Medium.**

---

## 7. Backend Integration Gaps
Backend handlers exist (`my-backend/src/handlers/book_store.ts`; `endpoint_results.csv`): `lookupBookByIsbn` (`GET /book-store/isbn/{isbn}`), `getLowStockBooks` (`GET /book-store/low-stock`), `listBookReturns`/`createBookReturn` (`GET|POST /book-store/returns`), `getConsignments` (`GET /books/consignments`), school-orders + `customerLoyaltyLookup`.

Flutter wiring (`book_repository.dart`) only calls:
- `GET /books/school-orders`, `POST /books/school-orders/{id}/fulfill`
- `GET /books/consignments`, `POST /books/consignments/{id}/settle`

**Gaps (priority High):**
- **ISBN lookup endpoint unused** — POS uses local Products search instead of `GET /book-store/isbn/{isbn}`; no server metadata enrichment.
- **Low-stock endpoint unused** — dashboard alerts hardcoded instead of `GET /book-store/low-stock`.
- **Returns endpoints unused on client** — `createBookReturn`/`listBookReturns` exist server-side; Flutter shows a "future update" placeholder.
- **Path inconsistency (unverified pairing):** client calls `/books/consignments/{id}/settle` and `/books/school-orders/{id}/fulfill`; backend inventory lists `/books/consignments` (GET) under `getConsignments`, but the **settle/fulfill POST routes were not located** in `endpoint_results.csv` — possible missing/renamed endpoints. **Verify before relying on settlement/fulfillment in production.**

---

## 8. Database & API Issues (real vs mock; hardcoded counts)
- **`BookInventoryScreen` list is mock:** `_books` is a hardcoded 5-row sample list (To Kill a Mockingbird, 1984, etc.) with comment "Sample data - will be replaced with DB query". The screen never queries the Products table for the grid; only **Add** persists via `productsRepository.createProduct`, then appends to the in-memory list. Author/Publisher are **not saved** to the product record. **High.**
- **`BookPosScreen` product grid:** `itemCount: 0` — never loads from DB. Cart works; invoice persists via `billsRepository.createBill` with `businessType: 'book_store'`, `source: 'POS'` (real, offline-capable). **High** (search/grid non-functional), POS billing itself OK.
- **Dashboard alert counts hardcoded** ('11', '6') — `business_alerts_widget.dart`. **High.**
- **School orders / consignments are real** server reads via `book_repository.dart` (`Either<Failure,...>`), but **no offline fallback** (see §12).

---

## 9. Responsive Design
- All five screens wrap content in `BoundedBox(maxWidth: 800)` and use `responsiveValue<double>(...)` for header/font sizing — reasonable for tablet/desktop.
- **Concern (Medium):** `BookPosScreen` is a fixed 3-column layout (`Expanded flex:3` products, `flex:4` cart, fixed `SizedBox(width: 320)` payment) **inside `maxWidth: 800`**. 320px is ~40% of 800, leaving ~480 split 3:4 → product/cart columns become very narrow; on small windows the fixed 320 right panel risks horizontal overflow. A real POS typically wants `maxWidth` much larger than 800. **Medium.**
- No mobile (`< tablet`) layout switch for the 3-pane POS; would be cramped. **Medium — unverified on device.**

---

## 10. Performance
- Inventory/POS use small in-memory lists; `DataTable` inside `SingleChildScrollView` is not virtualized but dataset is tiny (mock). If wired to real catalogue with thousands of titles, the non-paginated `DataTable` would be a **Medium** risk.
- `consignment_settlement` / `school_order` use `ListView.builder` (OK) but **no pagination** on the repository calls (`getConsignments`/`getSchoolOrders` return full lists). **Low/Medium** depending on volume.
- `content_host` caches built screens (`_screenCache`) and clears on business-type change — good.

---

## 11. Security (RBAC, capability-bypass)
- **Live screens bypass route guards** only in the sense that they are unreachable; the **named routes that do exist** (`/book_store/school_orders`, `/book_store/consignments`) are correctly wrapped in `VendorRoleGuard(viewReports)` + `BusinessGuard(allowedTypes: [bookStore])` (`app/routes.dart`). Good pattern, but unused.
- **In-screen RBAC missing:** `BookPosScreen._generateInvoice` and `BookInventoryScreen` add/create perform writes with **no permission check inside the widget** — they rely entirely on a route guard that is not applied (screens orphaned). If these screens are ever wired via `content_host` (which does **not** apply `VendorRoleGuard`), invoice/stock writes would be ungated. **High (latent).**
- `SchoolOrderScreen`/`ConsignmentSettlementScreen` perform settlement/fulfillment writes with no in-widget role check (settlement = money movement). Relies on the (currently unreachable) guarded route. **High (latent).**
- No capability-bypass found in `FeatureResolver` for bookStore; normalization is correct.

---

## 12. Offline Mode Gaps
- `book_repository.dart` uses `apiClient.get/post` **directly** (returns `ServerFailure` on error) — **no SyncQueue / offline-first** for school orders and consignment settlement. Offline, these screens show "Failed to load…". **High** for a desktop POS expected to work offline.
- By contrast, `BookPosScreen` invoice (`billsRepository.createBill`) and `BookInventoryScreen` add (`productsRepository.createProduct`) appear to go through the offline-capable repositories (per data-flow doc comments and repo usage) — **unverified** at the repository implementation level, but pattern matches other offline-first features.
- `book_supplier_returns` PO uses `purchaseRepository.createPurchaseOrder` (offline-first pattern); publisher returns not implemented.

---

## 13. Business Logic Inconsistencies
- **GST contradiction (Critical):** `book_store_strategy.dart` doc comment states *"Books are GST-exempt in India (0% by default)"*, but `business_type_config.dart` sets `defaultGstRate: 12.0`. India actually exempts **printed books** (0%) while **stationery/notebooks** are 12%/18% — the single flat 12% is wrong for the books portion and there is no per-item/category slab logic.
- **POS ignores GST entirely (Critical):** `book_pos_screen.dart` computes `_grandTotal = _subtotal - _billDiscount` with **no tax line**, regardless of the 12% config or the strategy's 0% claim. Tax is neither displayed nor added.
- **Strategy field mismatch (Medium):** `BookStoreStrategy.buildItemFields` doc says it "Builds ISBN, Author, Publisher fields", but the implementation renders only Quantity + Unit + Price. ISBN/Author/Publisher are never shown in the bill item row.
- **Consignment settlement math (High):** `consignment_settlement_screen.dart` pre-fills the dialog with the server's `settlementAmount` and lets the user type any amount (`amount > 0` only). There is **no client-side computation** of expected settlement (`booksSold × unit settlement price`) and **no cap** at the amount due, so over/under-settlement is possible without warning. "Unsold Return" is displayed as `received − sold` (correct arithmetic) but is informational only.
- **Loyalty proxy (High):** `customer_loyalty_widget._searchCustomer` passes `customer.totalPaid.toInt()` as "loyalty points". This is lifetime spend, **not** a points balance; POS field `_loyaltyPoints` is displayed but never applied to the bill (no redemption/accrual).

---

## 14. Data Validation Issues (ISBN focus)
- **Three different ISBN validations exist (inconsistent):**
  1. `BookStoreBusinessRules.isValidIsbn` — full ISBN-10/13 **checksum** (`book_store_business_rules.dart`). **Correct but unused by UI.**
  2. `IsbnScannerWidget.isValidIsbn` — duplicate full checksum implementation (`isbn_scanner_widget.dart`). Also **not called** by the POS flow (`onIsbnScanned` fires on any non-empty input).
  3. `BookInventoryScreen._scanIsbnToSearch` — **length-only** check (`digits.length != 10 && != 13`), no checksum.
- **Add Book dialog has no ISBN validation at all** (`_showAddBookDialog` only requires non-empty ISBN/Title and MRP>0). Invalid/duplicate ISBNs accepted. **High.**
- **POS accepts unknown ISBN** by adding a placeholder cart item at **₹0** (`_handleIsbnScan` else-branch) — risk of zero-priced sales. **Medium.**
- **Recommendation:** consolidate on `BookStoreBusinessRules.isValidIsbn` everywhere; reject invalid checksums on add and on scan.

---

## 15. UX Problems
- Generic retail sidebar gives no discoverable path to book features (catalogue/POS/consignment/school/returns) → users cannot find them at all. **Critical** (discoverability).
- POS search box present but inert (grid `itemCount:0`) — looks broken. **High.**
- "Publisher Returns" tab presents a "future update" placeholder behind a real-looking "New Return" button. **Medium.**
- Unknown-ISBN ₹0 add gives an orange snackbar but still adds the line — easy to checkout a free book. **Medium.**
- Hardcoded dashboard alert numbers ('11', '6') mislead the owner into thinking they reflect real stock. **High** (trust/UX).

---

## 16. Accessibility
- Heavy reliance on color + small font sizes (e.g., 11–13px labels, `Colors.white38`/`white24` low-contrast hints in dark mode) — likely fails WCAG AA contrast in places. **Medium — full validation requires manual testing with assistive tech.**
- ISBN/monospace cells and stat chips convey info by color (amber low-stock) with an icon fallback (good for low-stock); but category chips are color-only. **Low.**
- No `Semantics`/tooltip labels verified on icon-only buttons beyond a few `tooltip:` usages (scan buttons have tooltips; qty +/- buttons do not). **Medium — unverified comprehensively.**

---

## 17. Bugs / Errors / Crash Scenarios
- **`use_build_context_synchronously` risks:** Several `async` handlers call `ScaffoldMessenger.of(context)` / `Navigator.pop(context)` after `await` with only partial `mounted` guards:
  - `school_order_screen.dart` `_fetchOrders` calls `ScaffoldMessenger.of(context)` in the failure branch after `await` with **no `mounted` check** → potential exception if the screen was disposed. **Medium.**
  - `consignment_settlement_screen.dart` `_fetchConsignments` — same pattern, no `mounted` guard in failure branch. **Medium.**
  - In both fulfill/settle dialogs, after `await`, `ScaffoldMessenger.of(context)` uses the dialog's `context` post-`Navigator.pop` — works but fragile. **Low.**
- **`BookInventoryScreen` add flow:** uses `ScaffoldMessenger.of(context)` after `await createProduct` guarded by `if (!mounted) return;` (OK), but the early validation snackbar runs inside the dialog before await (OK).
- **Zero-price sales** (unknown ISBN) — data-integrity bug, not a crash. **Medium.**
- No try/catch around `billsRepository.createBill` result rendering — relies on `result.isSuccess`; **unverified** whether the repo can throw.

---

## 18. Unnecessary / Irrelevant Features Shown
Because bookStore uses the **full retail sidebar**, several sections are irrelevant or confusing for a book store:
- **BuyFlow → Dispatch Notes, Booking Orders, Proforma & Bids** — uncommon for a book retailer. **Low.**
- **Tax & Compliance → e-Way bill-adjacent / HSN reports, GSTR-1 B2B/B2C** — mostly irrelevant for small book shops selling exempt printed books. **Low/Medium** (still harmless if unused).
- **Inventory → Batch / Variant Tracking** (`batch_tracking`, gated by `useBatchExpiry`) — bookStore is **not** granted `useBatchExpiry`, so the item is correctly hidden by the capability filter (verified in `sidebar_configuration.dart` filter logic). Good.
- Conversely, **relevant** items are **missing** (ISBN catalogue, consignment, school orders, used books) — the inverse problem dominates. **High.**

---

## 19. Recommendations & Prioritized Implementation Plan

### Critical
1. **Add a dedicated `_getBookStoreSections()`** in `sidebar_configuration.dart` and a `case BusinessType.bookStore:` in `_getSectionsForBusiness`, surfacing: Book Catalogue, Book POS, ISBN Scan, Consignments, School/Institution Orders, Publisher Returns, Used Books — each with a stable `id`.
2. **Wire those IDs** in `sidebar_navigation_handler.getScreenForItem` (and/or `content_host._screenBuilders`) to the real screens (`BookInventoryScreen`, `BookPosScreen`, `ConsignmentSettlementScreen`, `SchoolOrderScreen`, `BookSupplierReturnsScreen`). This single step de-orphans all five screens.
3. **Fix GST:** decide policy (printed books 0%, stationery 12/18%), implement per-item/category slab, and **render a tax line in `BookPosScreen`** totals. Reconcile the `defaultGstRate: 12.0` config with the strategy's 0% comment.
4. **Fix dashboard quick-action dead links:** map `bookCatalogue`/`bookReturns` to real screens (or add `AppScreen` entries to `content_host._screenBuilders`); implement the "ISBN Scan" `onTap`.

### High
5. **Replace mock catalogue** in `BookInventoryScreen` with a real Products query; persist author/publisher/edition (extend the product write).
6. **Make dashboard alerts live** for bookStore: read `alertCountsProvider` (or call `GET /book-store/low-stock`) instead of hardcoded '11'/'6'.
7. **Implement Publisher Returns** UI against `createBookReturn`/`listBookReturns`; remove the "future update" placeholder.
8. **Real loyalty:** back the points field with an actual loyalty balance + accrual/redemption; stop using `totalPaid`.
9. **Offline-first** for `book_repository` (route via SyncQueue like bills/products).
10. **Consolidate ISBN validation** on `BookStoreBusinessRules.isValidIsbn`; validate on add and on scan; stop adding ₹0 unknown-ISBN lines (prompt to create the book first).
11. **Add in-widget RBAC** (or apply `VendorRoleGuard` in `content_host`) for invoice/stock/settlement writes before wiring screens live.

### Medium
12. Wire the unused **ISBN lookup endpoint** for metadata autofill; surface a Stationery category and mixed GST.
13. Add **set/bundle (class-set) composition** and **used-book intake** using existing `suggestedResalePrice` logic.
14. Increase POS `maxWidth` and add a responsive/stacked layout for narrow windows.
15. Add `mounted` guards in `school_order_screen`/`consignment_settlement_screen` failure branches.

### Low
16. Hide retail-only sections (dispatch notes, e-Way/HSN) for bookStore or move behind capability gates.
17. Accessibility pass on contrast and icon-button semantics.

### Sequencing
Phase 1 (Critical 1–4) unlocks the entire feature set and is mostly navigation glue. Phase 2 (High 5–11) makes data real, safe, and offline. Phase 3 (Medium/Low) polishes industry depth and a11y.

---

## 20. Confidence & Coverage

| Area | Confidence | Notes |
|------|------------|-------|
| Sidebar resolution → retail default | **High** | Directly read `_getSectionsForBusiness` |
| Config values | **High** | Read full bookStore config block |
| Capability set + normalization | **High** | Read `business_capability.dart` + `feature_resolver.dart` |
| Screen orphaning / dead links | **High** | Cross-checked `getScreenForItem`, `content_host`, `app/routes.dart`, module routes |
| Dashboard hardcoded alerts / dead actions | **High** | Read both widget files |
| Mock vs real data per screen | **High** | Read all 5 screens + repository |
| GST/loyalty/consignment logic | **High** | Read strategy, config, POS, widgets |
| Backend endpoint pairing (settle/fulfill POST) | **Medium** | Endpoint inventory checked; specific POST routes **not located** — flagged unverified |
| GoRouter mount status | **Medium-High** | Inferred from repeated in-repo comments + `module_loader`; runtime `main.dart` router not opened |
| Offline-first repo behavior | **Medium** | Pattern-based for bills/products (repo internals not read); `book_repository` raw apiClient confirmed |
| Responsive on real devices | **Medium** | Static layout reasoning only |
| Accessibility | **Low-Medium** | Requires manual AT testing |
| Sync/WebSocket handlers, Drift tables, backend bodies, tests | **Not assessed** | Listed as skipped above |

**Overall confidence: High** for the structural findings (navigation, orphaning, mock data, GST/loyalty), **Medium** for backend route pairing and runtime router mounting.
