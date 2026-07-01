# Phase 0 — Verification Report (Clothing Vertical)

> **Generated:** Phase 0, Task 1.1  
> **Scope:** Read-only. Zero application source, configuration, or build files were created, modified, or deleted.  
> **Source audit:** `audit-reports/business-types/audit-clothing.md`

---

## 3.2 Widget Internals — `variant_cell.dart`, `size_curve_chip.dart`, `clothing_variant_scanner_widget.dart`

### `variant_cell.dart`

- **Path:** `lib/features/clothing/widgets/variant_grid/variant_cell.dart`
- **Lines:** 1–119 (entire file)
- **What it does:** A `StatefulWidget` representing a single editable cell in the size × color variant grid. In non-header mode, it renders a quantity input as a centered `TextField` flanked by decrement (−) and increment (+) `InkWell` buttons. It maintains an internal `_value` (int, defaults to `initialValue`), updates it on button press or text entry, rejects negative values (`if (newValue < 0) return`), and propagates changes via `onChanged(int)`. The default `onChanged` is a static no-op (`_noopOnChanged`). In header mode (`isHeader: true`), it renders a themed container with bold text. It uses `Theme.of(context).colorScheme` for all colors (theme-aware — NOT hardcoded), and displays a tinted background when quantity is > 0.

### `size_curve_chip.dart`

- **Path:** `lib/features/clothing/widgets/variant_grid/size_curve_chip.dart`
- **Lines:** 1–25 (entire file)
- **What it does:** A `StatelessWidget` that renders a single `ActionChip` labelled with the curve name (e.g., "Bell Curve"), showing an `Icons.auto_graph` avatar. It accepts a `curveRatios` map (`Map<String, int>`) and displays them in the chip's `tooltip`. When pressed, it invokes the `onApply` callback — the parent (VariantGridWidget) uses this to apply the size-curve distribution ratios to all color rows in the grid.

### `clothing_variant_scanner_widget.dart`

- **Path:** `lib/features/barcode/widgets/clothing_variant_scanner_widget.dart`
- **Lines:** 1–375 (entire file)
- **What it does:** A `StatefulWidget` presented as a `Dialog` implementing a 3-step clothing-specific barcode scanner flow:
  1. **Step 0 — Scan:** A hidden `TextField` with `focusNode` auto-focuses on mount. On barcode submission, it first tries a variant-level lookup (`GET /clothing/barcode/{barcode}`) to resolve the exact variant (size/color/stock/priceCents) directly. If that succeeds, it jumps to the confirm step. Otherwise, it falls back to a product-level lookup via `BarcodeLookupService.lookupBarcode`.
  2. **Step 1 — Select Variant:** Displays the scanned product info, a size picker (`ChoiceChip` wrap from available sizes or defaults `[XS, S, M, L, XL, XXL, XXXL]`), a color picker (with a `CircleAvatar` color swatch), and a quantity selector (±1 buttons).
  3. **Step 2 — Confirm:** Fires `onComplete(ClothingVariantScanResult)` with the product, selected size, selected color, quantity, and timestamp.
  
  The widget uses audio feedback (`audioplayers` package) for success/error beeps and a 50ms debounce on barcode submission.

**Audit disposition:** All three widget internals were marked **unverified** in the audit. They are now **CONFIRMED** — their behaviour matches the audit's high-level descriptions (editable cell, size-curve application chip, read-then-select scanner) with the additional detail documented above.

---

## 3.3 Handler Liveness — `clothing_sync_handler.dart` and `clothing_ws_handler.dart`

### Classification: **not-active**

- **Expected paths (per audit):** `lib/modules/clothing/sync/clothing_sync_handler.dart` and `lib/modules/clothing/websocket/clothing_ws_handler.dart`
- **Verification result:** The directory `lib/modules/clothing/` does **not exist** in the live codebase. A recursive directory listing of `Dukan_x/lib/` shows no `modules/` directory at all. Grep searches for `ClothingSyncHandler`, `ClothingWsHandler`, `clothing_sync_handler`, `clothing_ws_handler`, `ClothingModule`, and `modules/clothing` all return zero results across the entire workspace.
- **Conclusion:** The handlers referenced in the audit (`ClothingSyncHandler` / `ClothingWsHandler`) are **not present** in the codebase and therefore **not-active** in the live app. The audit's description of them being "wired through the unmounted module system" is now superseded: the module system itself (the `modules/` directory) has been removed or was never present in the current codebase state.
- **File path + lines:** N/A — files do not exist. The closest related code is the backend manifest `my-backend/src/modules/clothing/manifest.ts` (line 19: `wsChannelPrefix: 'clothing:'`), which declares intent but has no corresponding client handler.

---

## 3.4 AppScreen Targets — `AppScreen.itemStock` and `AppScreen.categories`

- **File:** `lib/core/navigation/app_screens.dart`
  - `AppScreen.itemStock` — line 32 (enum declaration)
  - `AppScreen.categories` — line 38 (enum declaration)

- **Resolution (screen instantiation):**
  - **File:** `lib/widgets/desktop/content_host.dart`
  - `AppScreen.itemStock` → `InventoryDashboardScreen()` (line 156)
  - `AppScreen.categories` → `CategoriesScreen()` (line 157)

- **Sidebar id mapping (in `app_screens.dart`):**
  - `AppScreen.itemStock.id` returns `'item_stock'` (line 209–211)
  - `AppScreen.categories.id` returns `'categories'` (via the default `name.replaceAllMapped` camelCase→snake_case converter — no explicit `case`)

- **Sidebar Navigation Handler dispatch:**
  - `'item_stock'` → `InventoryDashboardScreen()` (`sidebar_navigation_handler.dart` line 350–352)
  - `'categories'` — has no explicit `case` in `sidebar_navigation_handler.dart`; not a retail sidebar item (the retail sidebar does not surface a `categories` id). It is only reached via the `content_host.dart` `AppScreen` dispatch map.

**Summary:** `AppScreen.itemStock` resolves to `InventoryDashboardScreen` (the generic item-wise stock view). `AppScreen.categories` resolves to `CategoriesScreen` (a product categories listing). The audit's finding that the "Variants" quick action navigates to `AppScreen.categories` (a generic categories screen, NOT the variant matrix) is **CONFIRMED**.

---

## 3.5 RBAC Matrix — Does `session_manager.dart` gate the retail sidebar items shown to clothing?

### Classification: **not-gated**

- **File:** `lib/core/session/session_manager.dart` (lines 1–1262)
- **RBAC mechanism:** `UserSession.hasPermission(Permission)` checks `staffPermissions.contains(permission)`. Permissions are loaded from `RolePermissions.getPermissions(role)` at session resolution / role selection (lines 225–233, 258–266).

- **Sidebar filtering (in `sidebar_configuration.dart`):**
  - The `sidebarSectionsProvider` (lines 82–112) filters items by:
    1. `capability` → `FeatureResolver.canAccess()` — strict-deny
    2. `permission` → `RolePermissions.hasPermission(userRole, permission)` — only evaluated IF the item has a non-null `permission` field

- **Retail sidebar items (`_getRetailSections`, lines 1120–1591):**
  - **Only two items carry a `capability`:** `batch_tracking` (gated by `useBatchExpiry`) and `scan_bill` (gated by `useScanOCR`).
  - **Zero items carry a `permission` tag.** The financial/compliance/admin items (`audit_trail`, `bank_accounts`, `accounting_reports`, `gstr1`, `gstr2` [not present — only `b2b_b2c`], `expenses`, `credit_notes`, `backup`) have NO `permission` field.

- **Conclusion:** The RBAC matrix in `session_manager.dart` defines permissions per role, but it is **never consulted** for retail sidebar items because those items carry no `permission` tag. The retail sidebar items shown to clothing (which falls through to `_getRetailSections()`) are **not-gated** by RBAC. Any authenticated user of any role sees all items (except `batch_tracking` which is hidden by capability denial, and `scan_bill` which is shown because clothing holds `useScanOCR`).

---

## 3.6 Billing Line-Item UI — Does it render `size`/`color` per line?

### Classification: **does-not-render**

- **File:** `lib/features/billing/presentation/widgets/bill_line_item_row.dart` (lines 1–773)
- **Evidence:** The `BillFieldConfig` class (lines 20–62) defines the extra columns rendered per line item: `showBatchNo`, `showExpiryDate`, `showSerialNo`, `showPurity`, `showWeight`, `showMakingCharges`, `showIsbn`, `showVehicleModel`, `showTableNo`, `showNozzleId`, `showCommission`. There is **no** `showSize` or `showColor` field. The `BillFieldConfig.fromBusinessType` factory (lines 51–62) maps from `BusinessTypeRegistry.getConfig(type)` fields — none of which include `size` or `color` as renderable columns.
- **Additionally:** A grep for `size` and `color` in `bill_line_item_row.dart` returns only CSS/layout `size` references (icon sizes, font sizes, SizedBox) and color theme references (BillTokens color constants) — zero hits for variant/product size or color rendering.
- **Conclusion:** Although the clothing `BusinessTypeConfig` declares `size` as a `requiredField` (for the *add-item* form), the billing line-item row widget does **not render** size or color per line. The audit's claim "whether the bill UI renders size/color per line is unverified" is resolved: it **does-not-render**.

---

## 3.7 Backend Response Shape — `/clothing/variants/{id}`, `/clothing/tailoring-notes`, `/clothing/variants/bulk`

### `/clothing/variants/{productId}` — **deployed-non-stub**

- **Handler:** `my-backend/src/handlers/clothing.ts`, lines 24–46 (`getVariants`)
- **Behaviour:** Queries DynamoDB with `VARIANT#{productId}#` prefix, maps results to `{id, productId, size, color, sku, priceCents, stock}`, and returns via `response.success(items)`.
- **Response envelope:** The standard `response.success(data)` produces `{ status:'success', code:200, data: <items array>, meta:{...} }`.
- **Observed response-key contract:** The variant array is at the `data` key of the envelope. On the Flutter side, `ApiClient._parseResponse` decodes the full JSON body as `response.data` (a `Map<String, dynamic>`). Therefore `response.data['data']` would contain the array.
- **Mismatch confirmed:**
  - `variant_repository.dart` (line 57) reads `response.data!['variants']` — **key does not exist** in the envelope.
  - `clothing_inventory_screen.dart` (line 87) reads `response.data?['items']` — **key does not exist** in the envelope.
  - Both consumers will receive `null` and either throw (cast failure) or return empty. **Neither key matches the backend contract (`data`).**
- **Classification:** deployed-non-stub handler. The endpoint is fully implemented with real DynamoDB queries, tenant isolation, and soft-delete filtering.

### `/clothing/tailoring-notes` — **deployed-non-stub**

- **Handler:** `my-backend/src/handlers/clothing.ts`, lines 109–171 (`createTailoringNote` — POST), lines 236–268 (`listTailoringNotes` — GET)
- **Additional routes:** `GET /clothing/tailoring-notes/{tailoringId}` (lines 173–188, `getTailoringNote`), `PUT /clothing/tailoring-notes/{tailoringId}/status` (lines 194–248, `updateTailoringStatus`), `PUT /clothing/tailoring-notes/{tailoringId}/measurements` (lines 254–294, `updateTailoringMeasurements`)
- **Response-key contract:** POST returns `response.success({ id, message }, 201)` — data at envelope `data.id`. PUT returns `response.success({ message })`. GET returns `response.success(result)` (the full tailoring record).
- **Classification:** deployed-non-stub. Full CRUD implementation with DynamoDB operations, schema validation, revision history, and tenant isolation.

### `/clothing/variants/bulk` — **deployed-non-stub**

- **Handler:** `my-backend/src/handlers/clothing.ts`, lines 51–103 (`bulkUpdateVariants` — PUT)
- **Behaviour:** Parses body via `bulkVariantUpdateSchema`, creates DynamoDB `TransactWrite` items for each variant (chunked at 25 per transaction), records revision, returns `response.success({ message, count })`.
- **Response-key contract:** Envelope `data` contains `{ message: 'Variants updated successfully', count: N }`.
- **Classification:** deployed-non-stub. Full implementation with transactional writes, schema validation, and revision history.

---

## 3.8 / 3.9 / 3.10 — Previously Unverified Audit Items — Disposition

The audit marked these items as **unverified** (sampled by grep/listing only, not opened in full). Each is now resolved:

| # | Audit Item | Disposition | Evidence |
|---|-----------|-------------|----------|
| 1 | `variant_cell.dart` internals | **CONFIRMED** — editable quantity cell with ± buttons, no-op default `onChanged`, rejects negative | `lib/features/clothing/widgets/variant_grid/variant_cell.dart` lines 1–119 |
| 2 | `size_curve_chip.dart` internals | **CONFIRMED** — ActionChip that shows curve ratios in tooltip, fires `onApply` to distribute quantities | `lib/features/clothing/widgets/variant_grid/size_curve_chip.dart` lines 1–25 |
| 3 | `clothing_variant_scanner_widget.dart` internals | **CONFIRMED** — 3-step dialog: scan → select size/color → confirm. Uses `BarcodeLookupService` + variant-level barcode lookup + audio feedback | `lib/features/barcode/widgets/clothing_variant_scanner_widget.dart` lines 1–375 |
| 4 | `clothing_sync_handler.dart` / `clothing_ws_handler.dart` liveness | **FALSIFIED** — Files do not exist in the codebase. The `lib/modules/` directory is absent. The audit described them as "registered through the unmounted module system" but the entire module directory is gone | Expected path: `lib/modules/clothing/sync/` and `lib/modules/clothing/websocket/` — NOT FOUND |
| 5 | `ClothingModule` and GoRouter module system | **FALSIFIED** — `ClothingModule`, `clothing_module.dart`, and the `lib/modules/clothing/` directory do not exist. Grep for `ClothingModule` returns zero hits. The audit's description of an unmounted parallel GoRouter module system for clothing is not present in the current codebase | Expected path: `lib/modules/clothing/clothing_module.dart` — NOT FOUND |
| 6 | `app_screens.dart` exact targets of `AppScreen.itemStock` / `AppScreen.categories` | **CONFIRMED** — `itemStock` → `InventoryDashboardScreen`, `categories` → `CategoriesScreen` | `content_host.dart` lines 156–157; `app_screens.dart` lines 32, 38 |
| 7 | `session_manager.dart` RBAC matrix gating retail sidebar | **CONFIRMED (not-gated)** — RBAC matrix exists but retail sidebar items carry no `permission` tag, so the matrix is never consulted for sidebar visibility | `sidebar_configuration.dart` lines 1120–1591 (zero `permission:` in retail items); `session_manager.dart` RBAC logic lines 97–112 of provider |
| 8 | Bill creation row widget rendering `size`/`color` per line | **CONFIRMED (does-not-render)** — `BillFieldConfig` has no size/color fields; the line-item row renders none | `bill_line_item_row.dart` lines 20–62 (`BillFieldConfig` definition) |
| 9 | Backend endpoints `/clothing/variants/{id}`, `/clothing/tailoring-notes`, `/clothing/variants/bulk` existence/shape | **CONFIRMED (all deployed-non-stub)** — full implementations in `my-backend/src/handlers/clothing.ts` | `my-backend/src/handlers/clothing.ts` lines 24–103 (variants), 109–294 (tailoring), 51–103 (bulk) |
| 10 | Response-key mismatch (`items` vs `variants`) | **CONFIRMED** — both keys are WRONG. Backend returns data at envelope key `data` (via `response.success(items)`). `variant_repository.dart` reads `['variants']`, `clothing_inventory_screen.dart` reads `['items']` — neither matches the backend contract | `variant_repository.dart` line 57; `clothing_inventory_screen.dart` line 87; `my-backend/src/handlers/clothing.ts` line 44; `my-backend/src/utils/response.ts` lines 28–36 |
| 11 | `ClothingSyncHandler` syncing `veg_rate_entries` at `/veg-broker/rates` | **FALSIFIED** — the handler file does not exist. No such sync code is present in the current codebase | Grep for `clothing_sync_handler`, `ClothingSyncHandler` — zero results |
| 12 | Whether the entire clothing module nav system is orphaned | **CONFIRMED (stronger: absent)** — the audit said it was "registered but unmounted." In the current codebase, the module directory and all module files (`clothing_module.dart`, `clothing_routes.dart`) are completely absent. Only the clothing *feature* code under `lib/features/clothing/` and the single legacy route `/clothing/variants` in `legacy_routes.dart` exist | `lib/modules/` — directory does not exist; `legacy_routes.dart` lines 2714–2735 (`/clothing/variants` GoRoute) |
| 13 | Tailoring measurement validation bypass (`> 0` only, not `ClothingBusinessRules`) | **CONFIRMED** — `tailoring_measurements_screen.dart` uses inline validators; `ClothingBusinessRules` is imported by nothing (dead code) | `tailoring_measurements_screen.dart`; grep for `ClothingBusinessRules` imports — zero consumers |
| 14 | Clothing screens crash offline (direct `ApiClient`, no cache) | **CONFIRMED** — all three screens (`ClothingInventoryScreen`, `VariantManagementScreen`, `TailoringMeasurementsScreen`) call `ApiClient` directly with no offline-first repository | `clothing_inventory_screen.dart` line 85; `variant_repository.dart` lines 55, 70; `tailoring_measurements_screen.dart` lines 140, 145 |
| 15 | `VariantManagementScreen` route guarded by `Permissions.manageStaff` | **CONFIRMED** — the `/clothing/variants` GoRoute in `legacy_routes.dart` wraps the screen in `VendorRoleGuard(requiredPermission: Permissions.manageStaff)` | `lib/core/routing/legacy_routes.dart` lines 2718–2735 |
| 16 | "Variants" quick action routes to `AppScreen.categories` | **CONFIRMED** — `business_quick_actions.dart` clothing case: `onTap: () => nav.navigateTo(AppScreen.categories)` for the "Variants" action | `business_quick_actions.dart` line 229 |

---

## Discrepancies with Audit / Ground Truth

### DISCREPANCY REPORTED: `lib/modules/clothing/` directory does not exist

The audit and the spec's requirements/design documents reference:
- `lib/modules/clothing/clothing_module.dart`
- `lib/modules/clothing/routes/clothing_routes.dart`
- `lib/modules/clothing/sync/clothing_sync_handler.dart`
- `lib/modules/clothing/websocket/clothing_ws_handler.dart`

**Reality:** The `lib/modules/` directory does not exist at all under `Dukan_x/lib/`. There is no `ClothingModule`, no `clothingRoutes`, no `ClothingSyncHandler`, no `ClothingWsHandler` anywhere in the codebase. The only clothing-specific code lives under `lib/features/clothing/` (screens, widgets, data, utils) and a single GoRoute at `/clothing/variants` in `lib/core/routing/legacy_routes.dart`.

**Impact on subsequent phases:**
- Phase 6 (Requirement 12.5) references "activate or remove `Clothing_Sync_Handler` / `Clothing_Ws_Handler` based on the Phase 0 finding." The finding is: **they do not exist** — there is nothing to activate or remove.
- The design's description of the "unmounted GoRouter module system" with 5 `navItems` and `LegacyRouteRedirect` stubs is **not present** in the current codebase. This entire subsystem appears to have been removed or was described based on a different codebase state.
- The single live clothing route (`/clothing/variants` in `legacy_routes.dart`) is a GoRoute registered in the `GoRouter` route tree, not in the legacy `MaterialApp.routes` map — confirming that clothing screens ARE registered on the GoRouter surface (Option B's scoped legacy `MaterialApp.routes` section does not apply to the current state; the route is already in `legacy_routes.dart` which is a GoRouter route list).

**Per the Operating Rules:** "If any audit/Ground Truth claim contradicts the code → STOP and report the discrepancy; do not route around it." This discrepancy is reported. The codebase state differs from the audit's description of the module system, but the *net effect* (clothing screens are orphaned/unreachable from the sidebar, variant persistence is broken, etc.) remains the same.

---

## Summary of All Unverified Items — Final Resolution

| Item | Resolution | Key Evidence |
|------|-----------|-------------|
| `variant_cell.dart` internals | CONFIRMED | Lines 1–119 — editable quantity cell |
| `size_curve_chip.dart` internals | CONFIRMED | Lines 1–25 — ActionChip with curve ratios |
| `clothing_variant_scanner_widget.dart` internals | CONFIRMED | Lines 1–375 — 3-step barcode scanner dialog |
| `clothing_sync_handler.dart` active/not-active | FALSIFIED (not present) | File does not exist; `lib/modules/` absent |
| `clothing_ws_handler.dart` active/not-active | FALSIFIED (not present) | File does not exist; `lib/modules/` absent |
| `AppScreen.itemStock` target | CONFIRMED → `InventoryDashboardScreen` | `content_host.dart` line 156 |
| `AppScreen.categories` target | CONFIRMED → `CategoriesScreen` | `content_host.dart` line 157 |
| `session_manager.dart` RBAC gating retail sidebar | CONFIRMED: not-gated | `sidebar_configuration.dart` — zero `permission:` on retail items |
| Billing line-item renders size/color | CONFIRMED: does-not-render | `bill_line_item_row.dart` — no size/color in `BillFieldConfig` |
| `/clothing/variants/{id}` backend shape | CONFIRMED: deployed-non-stub | `handlers/clothing.ts` lines 24–46 |
| `/clothing/tailoring-notes` backend shape | CONFIRMED: deployed-non-stub | `handlers/clothing.ts` lines 109–294 |
| `/clothing/variants/bulk` backend shape | CONFIRMED: deployed-non-stub | `handlers/clothing.ts` lines 51–103 |
| Response-key mismatch (`items` vs `variants`) | CONFIRMED (both wrong — correct key is `data`) | Response envelope wraps at `data`; neither consumer reads it |
| `ClothingModule` / GoRouter module system | FALSIFIED (absent from codebase) | `lib/modules/` does not exist |
| Offline mode gap (direct `ApiClient`) | CONFIRMED | All 3 screens call `ApiClient` directly |
| `Permissions.manageStaff` on variant route | CONFIRMED | `legacy_routes.dart` lines 2718–2735 |
| "Variants" quick action → `AppScreen.categories` | CONFIRMED | `business_quick_actions.dart` line 229 |

**All previously unverified audit items are resolved.** Zero items remain still-unverified.
