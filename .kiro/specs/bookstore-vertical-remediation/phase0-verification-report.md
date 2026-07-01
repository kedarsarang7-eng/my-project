# Phase 0 — Verification Report (Read-Only Pre-Flight)

**Spec:** bookstore-vertical-remediation
**Requirement covered:** Requirement 3 (3.1–3.10)
**Mode:** READ-ONLY. This document is the *only* file created by Task 1.1. No application
source, configuration, or build file was created, modified, or deleted (Requirement 3.1).
**Method:** Every claim cites a file path and (where relevant) line/symbol. Claims that
cannot be statically verified are marked **UNVERIFIABLE** and never fabricated
(Requirement 1.13, 1.14). Finding IDs (F1–F35) follow the numbering used in `requirements.md`,
`design.md`, and `audit-reports/business-types/audit-bookStore.md`.

> **Read this first — three Phase 0 findings contradict later-phase assumptions and BLOCK
> those phases until resolved by sign-off (Requirement 3.10). See §9.**

---

## Evidence base (files read)

Flutter app (`Dukan_x/`):
- `lib/features/book_store/data/book_repository.dart`
- `lib/features/book_store/presentation/screens/{book_pos_screen,book_inventory_screen,book_supplier_returns_screen,consignment_settlement_screen,school_order_screen}.dart`
- `lib/features/book_store/presentation/widgets/{customer_loyalty_widget,isbn_scanner_widget}.dart`
- `lib/features/book_store/utils/book_store_business_rules.dart`
- `lib/core/billing/strategies/book_store_strategy.dart`
- `lib/core/billing/business_type_config.dart` (bookStore block)
- `lib/widgets/desktop/sidebar_configuration.dart`
- `lib/features/dashboard/v2/widgets/{business_quick_actions,business_alerts_widget}.dart`
- `lib/core/navigation/app_screens.dart` (bookStore enum entries)
- `lib/core/routing/{app_router,legacy_routes}.dart`, `lib/app/app.dart`, `lib/main.dart`
- `lib/core/isolation/business_capability.dart` (bookStore set)
- `lib/core/repository/products_repository.dart` (`createProduct`)
- `lib/core/database/tables.dart` (`Products`, `Customers`)
- `lib/models/customer.dart`

Backend (`my-backend/`):
- `src/handlers/book_store.ts` (full handler)
- `serverless.yml` (bookStore route registrations, lines ~4701–4749)

Tests:
- `Dukan_x/test/features/book_store/book_store_business_rules_test.dart` (executed — see §4)

---

## 3.2 — GoRouter mount status of `lib/modules/book_store/` (F4, report-only)

**Status: `not-mounted`.**

**Evidence:**
- The directory `lib/modules/` **does not exist** in the current codebase (`Dukan_x/lib`
  contains: `app, auth, components, config, core, data, features, generated, guards, l10n,
  models, providers, screens, security, services, utils, widgets` — no `modules`). There is
  therefore no `lib/modules/book_store/book_store_module.dart`, no
  `routes/book_store_routes.dart`, and no `BookStoreModule`.
- A repository-wide search for `BookStoreModule|book_store_routes|book_store_module|modules/book_store`
  across `Dukan_x/**/*.dart` returned **zero matches**.
- There is no `module_loader.dart` / `module_registry.dart` in the repo (search returned
  zero files), so nothing registers a book-store GoRouter module.

**Classification of F4:** report-only (Requirement 2.4, 5.10). No GoRouter module is mounted
because none exists.

**Contradiction flagged (see §9, blocks Phase 2):** The audit and `design.md` describe a
GoRouter module *under `lib/modules/book_store/`* and the requirements Glossary defines
`Go_Router_Module` as `lib/modules/book_store/book_store_module.dart` + `routes/book_store_routes.dart`.
Those artifacts **do not exist**. Separately, the design Glossary states the live named-route
table is `lib/app/routes.dart` using `MaterialApp.routes`; that is also false (see §3.3 note
and §9).

---

## 3.3 — Settle / fulfill route pairing (F24)

Both client-called routes are **`paired`** with a deployed `Book_Store_Handler` route.
The audit flagged these as "not located / possibly missing" (Medium confidence); that flag is
**Not_Reproduced** — both routes are registered in the authoritative `serverless.yml`.

| Client call (observed) | Client evidence | Backend route (expected/registered) | Backend evidence | Result |
|---|---|---|---|---|
| `POST /books/consignments/{id}/settle` | `book_repository.dart` `processSettlement` → `apiClient.post('/books/consignments/$consignmentId/settle')` | `POST /books/consignments/{id}/settle` → `book_store.settleConsignment` | `serverless.yml` `bookStoreSettleConsignment` (path `/books/consignments/{id}/settle`, method POST, ~line 4744–4749); handler `settleConsignment` in `book_store.ts` | **paired** |
| `POST /books/school-orders/{id}/fulfill` | `book_repository.dart` `fulfillSchoolOrder` → `apiClient.post('/books/school-orders/$orderId/fulfill')` | `POST /books/school-orders/{id}/fulfill` → `book_store.fulfillSchoolOrder` | `serverless.yml` `bookStoreFulfillSchoolOrder` (path `/books/school-orders/{id}/fulfill`, method POST, ~line 4711–4715); handler `fulfillSchoolOrder` in `book_store.ts` | **paired** |

**Caveat (documentation, not a wiring gap):** The doc-comment above `settleConsignment` in
`book_store.ts` reads `POST /book-store/consignments/{id}/settlement` — this stale comment does
**not** match the registered route. The authoritative `serverless.yml` registration
(`/books/consignments/{id}/settle`) governs and matches the client. Recommend correcting the
comment in a later phase (cosmetic).

**Also observed (adjacent, informational):** `GET /books/school-orders`, `POST /books/school-orders`
(institutional order create), `GET /books/consignments`, and `POST /books/consignments` (consignment
create) are all registered in `serverless.yml` and paired to handlers. The `getSchoolOrders`
handler maps `INSTORDER#` items → `{schoolName, grade, totalSets, fulfilledSets, status}`, and
`getConsignments` maps `CONSIGNMENT#` items → `{publisherName, totalBooksReceived, totalBooksSold,
settlementAmount, status}`, matching the client `SchoolOrder`/`Consignment` `fromJson` shapes.

---

## 3.4 — Hardcoded tenant literals & unscoped reads/writes (F29)

**Result: none found** (no hardcoded `tenantId`/`vendorId`/`'SYSTEM'` literals) in either scope.

- `lib/features/book_store/**`: search for `tenantId|vendorId|'SYSTEM'|"SYSTEM"` across all
  `.dart` files returned **zero matches**. **none found.**
- `my-backend/src/handlers/book_store.ts` (bookStore path): search for
  `'SYSTEM'|"SYSTEM"|tenantId = '...'` returned **zero matches**. **none found.**

**Tenant-scoping posture (context for Phase 1, Requirement 4):**
- **Backend (`book_store.ts`)** — every read/write derives the tenant boundary from the
  authenticated context via `Keys.tenantPK(auth.tenantId)` (used in `getBooks`,
  `getLowStockBooks`, `createBookReturn`, `listBookReturns`, `customerLoyaltyLookup`,
  `lookupBookByIsbn`, `createInstitutionalOrder`, `createConsignment`, `settleConsignment`,
  `getSchoolOrders`, `fulfillSchoolOrder`, `getConsignments`). Correctly tenant-scoped; no gap.
  Note: `createBookReturn`/`createConsignment` also store a `vendorId` taken from the request
  body — that is a *publisher/supplier* id, not a tenant id, so it is not a scoping concern.
- **Client (`book_repository.dart`)** — calls `/books/school-orders`, `/books/consignments`,
  and the settle/fulfill POSTs with **no explicit `tenantId` in the request**; scoping relies
  entirely on the server-side `auth.tenantId` (from the auth token injected by `ApiClient`).
  This is not a hardcoded-literal violation, but the repository performs **no client-side tenant
  assertion** and has no explicit unresolved-tenant guard. This is the surface Phase 1 (4.1,
  4.2, 4.4) is expected to harden; recorded here as context, classified below under F29.

---

## 3.5 — Existing `test/features/book_store/**` suite

**Command:** `flutter test test/features/book_store/` (run in `Dukan_x/`, exit code 0).

| Metric | Count |
|---|---|
| Total | 7 |
| Passed | 7 |
| Failed | 0 |

Only one test file exists: `test/features/book_store/book_store_business_rules_test.dart`.
It covers `BookStoreBusinessRules.isValidIsbn` (ISBN-10 with `X`, ISBN-13, bad checksum,
wrong length) and `suggestedResalePrice` (brand-new 5% off, damaged 75% off, negative→0).
No screen, repository, navigation, or backend tests exist for the book-store vertical.

---

## 3.6 — Persisted shape of Product and Customer (author / publisher / edition / loyalty)

### Product

**Drift table `Products` (`lib/core/database/tables.dart`, `class Products`, ~lines 394–443)**
already contains dedicated **Book Store fields**:
- `TextColumn get isbn` (nullable)
- `TextColumn get author` (nullable)
- `TextColumn get publisher` (nullable)
- (plus `hsnCode`, `brand`, `category`, `sellingPrice`/`costPrice`/`taxRate` as `RealColumn`
  doubles, `stockQuantity`, `lowStockThreshold`, `cgstRate`/`sgstRate`/`igstRate`.)
- **`edition` — NOT present** anywhere in the `Products` table.

**Write path gap (F12):** `ProductsRepository.createProduct(...)`
(`lib/core/repository/products_repository.dart`, ~line 203) accepts
`name, sku, barcode, category, unit, sellingPrice, costPrice, taxRate, stockQuantity,
lowStockThreshold, size, color, brand, hsnCode, altBarcodes, drugSchedule, groupId,
variantAttributes, initialBatches, initialImeis` — it does **not** accept or persist
`isbn`, `author`, or `publisher`. So although the columns exist, the create path never
populates them. `BookInventoryScreen._showAddBookDialog` sends author/publisher only into an
in-memory `_BookRow`; ISBN is passed as `barcode`.

**Schema_Gate implication for Phase 4 (7.4, 7.5):** Persisting `author`/`publisher`/`isbn`
requires **only a write-path change** (extend `createProduct` + the Add/Edit dialog) — the
Drift columns already exist, so **no Drift column addition is needed** for those three.
Persisting **`edition`** *would* require a Drift schema change → Schema_Gate.

Backend DynamoDB product items already carry `isbn`, `author`, `publisher`, `hsnCode`,
`salePriceCents`, `mrpCents` (read by `getBooks`, `lookupBookByIsbn`, `getLowStockBooks` in
`book_store.ts`).

### Customer

**Drift table `Customers` (`lib/core/database/tables.dart`, `class Customers`, ~lines 318–378)**
contains, among others: `id, userId, name, phone, email, address, gstin, totalBilled (RealColumn),
totalPaid (RealColumn)`, and — critically — **`IntColumn get loyaltyPoints` with default `0`
(line ~377, under a `// Loyalty system` comment)**.

**Domain model divergence (relevant to F17 / Phase 6):**
- The Drift `Customers` table **has a real `loyaltyPoints` integer column**.
- The backend `customerLoyaltyLookup` returns `loyaltyPoints` (and `totalBilled`/`totalPaid`).
- BUT the Dart domain model `Customer` (`lib/models/customer.dart`) exposes **no `loyaltyPoints`
  field** (it has name/phone/address/email/gstin/totalDues/cashDues/onlineDues/… but no loyalty
  balance).
- The loyalty widget (`customer_loyalty_widget.dart` `_searchCustomer`) passes
  `customer.totalPaid.toInt()` as points — the `totalPaid` proxy (F17).

**Schema_Gate implication for Phase 6 (9.8):** A persisted loyalty balance already exists at the
Drift table level (`Customers.loyaltyPoints`). Reading/writing a real balance likely needs the
**`Customer` domain model + mapper** to surface `loyaltyPoints` (code change), and may not need a
new Drift column. Confirm mapper/consumer impact under Schema_Gate before Phase 6.

**Money-type note (Requirement 1):** `Products` prices, `Bills` totals, and `Customers.totalPaid`
are `RealColumn` (double). `Customers.loyaltyPoints` is `IntColumn`. Per Requirement 1.1–1.3, new
touched money must be integer paise; any migration of existing double columns is a Schema_Gate
concern, not a silent change.

---

## 3.7 / 3.8 — Finding classification (F1–F35)

Each evaluated finding is marked exactly one of **CONFIRMED**, **Not_Reproduced**, or
**UNVERIFIABLE**, with evidence. Non-reproducing findings are recorded, never omitted (3.8).

| F | Summary | Status | Evidence (file · location) |
|---|---|---|---|
| F1 | No `case BusinessType.bookStore` in `_getSectionsForBusiness`; falls through to retail | **CONFIRMED** | `sidebar_configuration.dart` — only a comment mentions `bookStore` (~line 1352); no `case BusinessType.bookStore:` exists → `default: _getRetailSections()` |
| F2 | Five `Book*Screen` widgets orphaned; no sidebar id resolves to them | **CONFIRMED** | Search for `book_catalogue\|book_pos\|book_returns\|book_consignments\|book_school_orders\|BookInventoryScreen\|BookPosScreen` across `lib/widgets/desktop/**` → zero matches (no nav-handler/content-host mapping) |
| F3 | Dashboard quick actions: Book Search & Returns → placeholder; ISBN Scan no-op | **CONFIRMED** | `business_quick_actions.dart` bookStore case (~line 337): `Book Search → AppScreen.bookCatalogue`, `ISBN Scan → onTap: () {}` (empty), `Returns → AppScreen.bookReturns`; `bookCatalogue`/`bookReturns` have no screen mapping (F2) |
| F4 | GoRouter module not mounted | **CONFIRMED (report-only)** | See §3.2 — module directory absent entirely; `not-mounted` |
| F5 | Named-route guards exist for `/book_store/school_orders` & `/book_store/consignments` | **CONFIRMED** (but location differs) | Routes are `GoRoute`s in `lib/core/routing/legacy_routes.dart` (~lines 1440, 1459) wrapped in `VendorRoleGuard(viewReports)` + `BusinessGuard([bookStore])` — NOT in `lib/app/routes.dart` (which does not exist). See §9 contradiction. |
| F6 | GST contradiction: strategy 0% vs config 12.0 vs POS no-tax | **CONFIRMED** | `book_store_strategy.dart` doc: "Books are GST-exempt in India (0% by default)"; `business_type_config.dart` bookStore `defaultGstRate: 12.0, gstEditable: true` (~line 656); `book_pos_screen.dart` `_grandTotal = _subtotal - _billDiscount` (no tax line) |
| F7 | Single flat `defaultGstRate`; no per-item/HSN slab | **CONFIRMED** | `business_type_config.dart` bookStore block has one `defaultGstRate: 12.0`; no per-line tax computation in `book_pos_screen.dart` |
| F8 | Consignment settlement: no computed cap, freely editable | **CONFIRMED** | `consignment_settlement_screen.dart` `_showSettlementDialog`: pre-fills `item.settlementAmount`, validates only `amount <= 0`; no `booksSold × unitPrice` cap |
| F9 | `BookInventoryScreen` catalogue is mock data | **CONFIRMED** | `book_inventory_screen.dart` `_books` = hardcoded 5-row list, comment "Sample data - will be replaced with DB query" (~line 35) |
| F10 | `BookPosScreen` product grid `itemCount: 0`; search inert | **CONFIRMED** | `book_pos_screen.dart` product grid `ListView.builder(itemCount: 0, // Will be populated from database)`; search `onChanged: (_) => setState((){})` filters nothing |
| F11 | Dashboard alert counts hardcoded `'11'`/`'6'` | **CONFIRMED** | `business_alerts_widget.dart` bookStore case (~line 1520): "Bestsellers Low Stock" `count: '11'`, "Category Stock Low" `count: '6'`; `_getTitle` returns "Inventory Alerts"; never reads `counts` map |
| F12 | author/publisher/edition not persisted to Product | **CONFIRMED (with nuance)** | `createProduct` (products_repository.dart ~line 203) has no isbn/author/publisher params; Add Book dialog stores them only in in-memory `_BookRow`. NUANCE: `Products` Drift table already has `isbn`/`author`/`publisher` columns; `edition` absent. See §3.6 |
| F13 | Three divergent ISBN validators | **CONFIRMED** | Checksum in `book_store_business_rules.dart` `isValidIsbn` (authoritative, unused by UI); duplicate checksum `IsbnScannerWidget.isValidIsbn` (static, not called on scan — `onIsbnScanned` fires on any non-empty input); length-only check in `book_inventory_screen.dart` `_scanIsbnToSearch` (`digits.length != 10 && != 13`) |
| F14 | Add Book dialog performs no ISBN validation | **CONFIRMED** | `book_inventory_screen.dart` Save handler validates only `isbn.isEmpty \|\| title.isEmpty \|\| mrp <= 0`; no checksum |
| F15 | POS adds unknown ISBN as ₹0 placeholder line | **CONFIRMED** | `book_pos_screen.dart` `_handleIsbnScan` else-branch adds `_CartItem(... mrp: 0.0 ...)` + orange "added with ₹0 price" snackbar |
| F16 | Publisher Returns is a "future update" placeholder | **CONFIRMED** | `book_supplier_returns_screen.dart` `_showNewReturnDialog` shows construction icon + "Publisher returns tracking will be available in a future update."; returns list is a static empty-state; no call to `POST/GET /book-store/returns` |
| F17 | Loyalty is a `totalPaid` proxy, no accrual/redemption | **CONFIRMED** | `customer_loyalty_widget.dart` `_searchCustomer`: `customer.totalPaid.toInt() // Use totalPaid as loyalty proxy`. POS `_loyaltyPoints` displayed, never applied to bill. NUANCE: real `Customers.loyaltyPoints` column exists (§3.6) |
| F18 | ISBN-lookup endpoint unused by client | **CONFIRMED** | `book_repository.dart` has no `/book-store/isbn/{isbn}` call; `book_pos_screen.dart` `_handleIsbnScan` uses `productsRepository.search`. Backend `lookupBookByIsbn` (`GET /book-store/isbn/{isbn}`) exists and is registered but never called from Flutter |
| F19 | Low-stock endpoint unused; dashboard count hardcoded | **CONFIRMED** | Backend `getLowStockBooks` (`GET /book-store/low-stock`) registered; no client call in `book_repository.dart`; alerts hardcoded (F11) |
| F20 | No `BusinessCapability` for school/institutional orders or consignment | **CONFIRMED** | `business_capability.dart` bookStore set (~lines 834–839) grants `useISBN, usePublisherReturns, useLoyaltyPoints, useBarcodeScanner, useScanOCR, useStockManagement` — no school-orders/consignment capability enum |
| F21 | Used-books flow unused (`suggestedResalePrice`/`BookCondition` unwired) | **CONFIRMED** | `book_store_business_rules.dart` defines `suggestedResalePrice` + `BookCondition`; no screen references them (no Used Books UI). Backlog (Phase 9) |
| F22 | Set/bundle (class-set) composition missing | **CONFIRMED (by absence)** | `UnitType.set` in config `unitOptions`; no bundle/BOM composition code in book_store feature. Backlog (Phase 9) |
| F23 | Stationery category + mixed GST missing | **CONFIRMED** | `book_inventory_screen.dart` category dropdown hardcoded `['All','Fiction','Classic','Textbook','Self-Help']` — no Stationery; single `defaultGstRate`. Backlog (Phase 9) |
| F24 | settle/fulfill POST routes possibly missing | **Not_Reproduced** | Both POST routes ARE registered & paired — see §3.3 (`serverless.yml` ~lines 4711, 4744) |
| F25 | `book_repository` online-only, no Sync_Queue | **CONFIRMED** | `book_repository.dart` uses `apiClient.get/post` directly; returns `ServerFailure` on error; no offline queue/pending state |
| F26 | Publisher-returns offline path undefined | **CONFIRMED (by absence)** | Publisher returns unimplemented (F16), so no offline path exists to define. Depends on Phase 6 (F16) first |
| F27 | `BookPosScreen`/`BookInventoryScreen` writes lack in-widget RBAC | **CONFIRMED** | `book_pos_screen.dart` `_generateInvoice` and `book_inventory_screen.dart` Save call `billsRepository.createBill` / `productsRepository.createProduct` with no permission check inside the widget |
| F28 | Settlement/fulfillment writes lack in-widget RBAC | **CONFIRMED** | `consignment_settlement_screen.dart` `processSettlement` and `school_order_screen.dart` `fulfillSchoolOrder` invoked from dialogs with no in-widget role check |
| F29 | Hardcoded tenant literals / unscoped reads-writes | **Not_Reproduced (literals) / CONFIRMED (client not explicitly scoped)** | No hardcoded `tenantId`/`vendorId`/`'SYSTEM'` literals in either scope (§3.4 — "none found"). Backend is fully `auth.tenantId`-scoped. Client `book_repository.dart` relies on server-side auth scoping with no explicit tenant assertion/unresolved-tenant guard — the Phase 1 hardening surface |
| F30 | POS 3-pane layout overflow risk on narrow windows | **CONFIRMED** | `book_pos_screen.dart` fixed `SizedBox(width: 320)` payment pane + `Expanded(flex:3)`/`flex:4)` inside `BoundedBox(maxWidth: 800)` |
| F31 | No book detail/edit screen; no publisher/school master UI | **CONFIRMED** | `book_inventory_screen.dart` has Add dialog only (no edit/delete row); publisher is free-text; schools come from server with no add/edit UI. Backlog (Phase 9) |
| F32 | Repository calls unpaginated | **CONFIRMED** | `book_repository.dart` `getSchoolOrders`/`getConsignments` fetch full lists with no page/limit params (backend `getSchoolOrders`/`getConsignments` also return full lists) |
| F33 | Missing `mounted` guards after `await` in async failure branches | **CONFIRMED** | `school_order_screen.dart` `_fetchOrders` failure branch calls `ScaffoldMessenger.of(context)` after `await` with no `mounted` check; same in `consignment_settlement_screen.dart` `_fetchConsignments` |
| F34 | Retail-only sidebar sections shown to book store | **CONFIRMED (consequence of F1)** | Because F1 falls through to `_getRetailSections()`, bookStore shows the generic 10-section retail sidebar (BuyFlow/Dispatch, e-Way/HSN, etc.) |
| F35 | Accessibility: low contrast + missing semantics | **UNVERIFIABLE (static)** | Low-contrast hints (`Colors.white38`/`white24`) and color-only category chips observed in `book_pos_screen.dart`/`book_inventory_screen.dart`; qty +/- `IconButton`s lack tooltips. Full WCAG AA validation requires manual assistive-technology testing, so this is flagged UNVERIFIABLE per Requirement 1.13 |

**Summary counts (F1–F35, 35 findings evaluated):**
- **CONFIRMED: 30** — F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, F13, F14, F15, F16, F17, F18, F19, F20, F21, F22, F23, F25, F26, F27, F28, F30, F31, F32, F33, F34 *(F29 client-scoping aspect also confirmed)*
- **Not_Reproduced: 2** — F24 (routes are paired), F29 (no hardcoded tenant literals; note the client-scoping hardening aspect is confirmed separately)
- **UNVERIFIABLE: 1** — F35 (accessibility contrast/semantics needs manual AT testing)

> Count reconciliation: 35 findings. F29 is dual-natured — the *hardcoded-literal* claim is
> Not_Reproduced ("none found"), while the *client-side explicit tenant scoping* gap is
> Confirmed as the Phase 1 surface. F4 is Confirmed and simultaneously report-only. Every one
> of F1–F35 has a recorded status; none omitted (3.8, 3.9).

---

## 3.9 — Completeness check

Every check defined in 3.2–3.8 has a recorded result and nothing is left unclassified:

| Check | Recorded? | Result |
|---|---|---|
| 3.2 GoRouter mount status | ✅ | `not-mounted` (module absent); F4 report-only |
| 3.3 settle/fulfill pairing | ✅ | both `paired` (F24 Not_Reproduced) |
| 3.4 tenant literals / unscoped I/O | ✅ | "none found" (literals); client relies on server-side scoping |
| 3.5 existing tests | ✅ | 7 total / 7 passed / 0 failed |
| 3.6 Product/Customer shape | ✅ | isbn/author/publisher columns exist; edition absent; Customers.loyaltyPoints exists |
| 3.7/3.8 finding classification | ✅ | 30 CONFIRMED / 2 Not_Reproduced / 1 UNVERIFIABLE (F1–F35) |

---

## 3.10 — Contradictions that BLOCK later phases (require sign-off to resolve)

Three Phase 0 findings contradict assumptions later phases depend on. Per Requirement 3.10, the
dependent phase is **blocked until the contradiction is resolved by sign-off**.

### C1 — The `lib/modules/book_store/` GoRouter module does not exist
- **Assumption contradicted:** `requirements.md` Glossary (`Go_Router_Module`), `design.md`
  ("GoRouter module under `lib/modules/book_store/`"), and Task 5.4 all reference this module as
  the F4 report-only artifact.
- **Reality (§3.2):** No `lib/modules/` directory; no `BookStoreModule`; zero references.
- **Blocks:** **Phase 2** (Task 5.4 "keep GoRouter module report-only"). There is no module to
  report on. F4 remains report-only, but the phase text must be reconciled (report "module
  absent" rather than "present-but-not-mounted").

### C2 — Routing is GoRouter, not `MaterialApp.routes`; book-store routes live in `legacy_routes.dart`
- **Assumption contradicted:** `requirements.md` Glossary and `design.md` state the live
  named-route table is **`lib/app/routes.dart`** using `MaterialApp.routes`, and frame the
  GoRouter migration as out-of-scope (Requirement 2.4).
- **Reality:** `lib/app/routes.dart` **does not exist**. The app uses **GoRouter as the sole
  navigation path** — `lib/app/app.dart` builds `MaterialApp.router(routerConfig: appRouterProvider)`;
  `lib/main.dart` states "Navigation is driven by go_router via MaterialApp.router … The legacy
  named-route table was removed"; `lib/core/routing/app_router.dart` owns the single `GoRouter`
  and spreads `...LegacyRoutes.routes()`. The guarded book-store routes
  `/book_store/school_orders` and `/book_store/consignments` are `GoRoute`s inside
  `LegacyRoutes.routes()` (`lib/core/routing/legacy_routes.dart` ~lines 1440 & 1459) and are
  therefore **already mounted** in the active router (an in-code comment in `app_router.dart`
  claiming `routes()` is "currently empty (skeleton)" is stale — `routes()` is populated from
  ~line 506 through 1470+).
- **Blocks:** **Phase 2** (Tasks 5.4, 5.9 — "route through the existing guarded
  `/book_store/school_orders` / `/book_store/consignments` in `lib/app/routes.dart`"). The target
  file and mechanism are wrong; wiring must target the GoRouter routes in `legacy_routes.dart`.
  Also affects the Requirement 2.4 framing (GoRouter is already the router, so "no app-wide
  GoRouter migration" is trivially satisfied — there is nothing to migrate).

### C3 — Product/Customer schema already carries most "missing" fields
- **Assumption contradicted:** F12 (author/publisher/edition "not persisted") and F17 (loyalty
  needs a real balance) imply Phase 4 / Phase 6 must add persisted fields (Schema_Gate).
- **Reality (§3.6):** `Products` already has `isbn`/`author`/`publisher` columns (only `edition`
  is missing); `Customers` already has a `loyaltyPoints` integer column.
- **Blocks (soft):** Not a hard blocker, but it **narrows the Schema_Gate scope** for **Phase 4
  (7.5)** and **Phase 6 (9.8)**: persisting author/publisher/isbn is a write-path change (no new
  Drift column); only `edition` (Phase 4) and surfacing `loyaltyPoints` on the `Customer` domain
  model + mapper (Phase 6) need review. Confirm before those phases assume a full schema
  addition.

---

## Bottom line

Phase 0 is complete and read-only: this Verification_Report is the only file produced; no
application/config/build file was touched (3.1). Every 3.2–3.8 check is recorded and every
finding F1–F35 is classified (30 CONFIRMED, 2 Not_Reproduced, 1 UNVERIFIABLE). Two audit
concerns did not reproduce (F24 routes are paired; F29 no hardcoded tenant literals). Three
contradictions (C1–C3) block or narrow Phase 2 / Phase 4 / Phase 6 assumptions and must be
resolved by sign-off before those phases proceed. The Phase 0 checkpoint text and
`PHASE 0 COMPLETE — AWAITING APPROVAL` gate are intentionally **not** written here — that is the
separate checkpoint task.
