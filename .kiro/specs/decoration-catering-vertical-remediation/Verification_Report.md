# Verification Report — Decoration & Catering Vertical (Phase 0)

**Generated:** Phase 0 read-only backend reality check  
**Scope:** Classify all 17 `/dc/*` endpoints, confirm/flag audit findings, dead-code status,
profitability formula, and Phase-0-pending field/endpoint names.  
**Source changes:** ZERO (read-only artifact)

---

## 1. Endpoint Classification (17 `/dc/*` logical endpoint groups)

Each endpoint group is classified as one of:
- **non-stub handler deployed** — a real Lambda handler exists in `my-backend/src/handlers/dc.ts`
  with full business logic (DynamoDB reads/writes, validation, tenant scoping)
- **stub handler deployed** — a handler exists but returns hardcoded/placeholder data
- **no handler deployed** — no matching Lambda function exists in `serverless.yml`

| # | Endpoint Group | Classification | Evidence |
|---|---------------|---------------|----------|
| 1 | **Events CRUD** (`GET/POST/PUT/DELETE /dc/events`, `GET /dc/events/{id}`) | non-stub handler deployed | `my-backend/src/handlers/dc.ts` lines 74–410; `serverless.yml` lines 4764–4807 |
| 2 | **Staff** (`GET/POST/PUT/DELETE /dc/staff`) | non-stub handler deployed | `dc.ts` lines 683–780; `serverless.yml` lines 4908–4935 |
| 3 | **Staff/Attendance** (`POST/GET /dc/staff/attendance`) | non-stub handler deployed | `dc.ts` lines 784–829; `serverless.yml` lines 4939–4951 |
| 4 | **Vendors** (`GET/POST/PUT/DELETE /dc/vendors`) | non-stub handler deployed | `dc.ts` lines 834–950; `serverless.yml` lines 4955–4983 |
| 5 | **Inventory** (`GET/POST/PUT/DELETE /dc/inventory`) | non-stub handler deployed | `dc.ts` lines 955–1047; `serverless.yml` lines 4987–5015 |
| 6 | **Menu** (`GET/POST/PUT/DELETE /dc/menu`) | non-stub handler deployed | `dc.ts` lines 504–590; `serverless.yml` lines 4843–4871 |
| 7 | **Packages** (`GET/POST/PUT/DELETE /dc/packages`) | non-stub handler deployed | `dc.ts` lines 595–678; `serverless.yml` lines 4875–4903 |
| 8 | **Themes** (`GET/POST/PUT/DELETE /dc/themes`) | non-stub handler deployed | `dc.ts` lines 415–499; `serverless.yml` lines 4811–4839 |
| 9 | **Expenses** (`GET/POST/GET/{id}/PUT/DELETE /dc/expenses`) | non-stub handler deployed | `dc.ts` lines 1236–1376; `serverless.yml` lines 5043–5079 |
| 10 | **Invoices** (`GET/POST /dc/invoices`, `POST /dc/invoices/{id}/payment`) | non-stub handler deployed | `dc.ts` lines 1052–1230; `serverless.yml` lines 5019–5039 |
| 11 | **Quotes** (`GET/POST/PUT/DELETE /dc/quotes`, `GET /dc/quotes/{id}`) | non-stub handler deployed | `dc.ts` lines 1490–1592; `serverless.yml` lines 5091–5127 |
| 12 | **Payments** (`POST /dc/events/{id}/payments`) | non-stub handler deployed | `dc.ts` lines 317–390 (`recordEventPayment`); `serverless.yml` lines 4795–4799 |
| 13 | **Dashboard** (`GET /dc/dashboard`) | non-stub handler deployed | `dc.ts` lines 1381–1486 (`getDashboard`); `serverless.yml` lines 4755–4759 |
| 14 | **Profitability** (`GET /dc/events/{id}/profitability`) | non-stub handler deployed | `dc.ts` lines 1671–1704 (`getEventProfitability`); `serverless.yml` lines 5147–5151 |
| 15 | **Shopping-list** (`GET /dc/events/{id}/shopping-list`) | non-stub handler deployed | `dc.ts` lines 1628–1666 (`getShoppingList`); `serverless.yml` lines 5139–5143 |
| 16 | **Vendor Payments** (`POST/GET /dc/vendors/{id}/payments`) | non-stub handler deployed | `dc.ts` lines 1712–1757; `serverless.yml` lines 5155–5167 |
| 17 | **Reports Summary** (`GET /dc/reports/summary`) | non-stub handler deployed | `dc.ts` lines 1761–1812 (`getReportsSummary`); `serverless.yml` lines 5083–5087 |

**Result:** All 17 endpoint groups have **non-stub handlers deployed**. No backend gaps identified
for the core endpoints.

**Note:** Additional endpoints exist that were not in the original 17 enumeration:
- KOT (Kitchen Order Tickets): `POST/GET /dc/events/{id}/kot`, `PUT /dc/kot/{id}` — non-stub
  handlers deployed (`dc.ts` lines 1819–1943; `serverless.yml` lines 5171–5191).
- Event Notes: `POST /dc/events/{id}/notes` — non-stub handler deployed (`dc.ts` line 1594;
  `serverless.yml` lines 5131–5135).

---

## 2. Audit Finding Confirmations (with file path + line evidence)

### 2.1 Sidebar Gap — no `decorationCatering` case

**Status:** CONFIRMED  
**File:** `Dukan_x/lib/widgets/desktop/sidebar_configuration.dart`  
**Lines:** 129–163 (`_getSectionsForBusiness` switch statement)  
**Evidence:** The switch has explicit cases for `clinic`, `pharmacy`, `restaurant`, `petrolPump`,
`electronics`/`mobileShop`/`computerShop`, `service`, `hardware`, and `vegetablesBroker`. There
is no `case BusinessType.decorationCatering` — it falls through to `default: _getRetailSections()`.

### 2.2 Navigation Gap — no DC ids in `sidebar_navigation_handler.dart`

**Status:** CONFIRMED  
**File:** `Dukan_x/lib/widgets/desktop/sidebar_navigation_handler.dart`  
**Lines:** 203–605 (`getScreenForItem` / `tryGetScreenForItem` switch)  
**Evidence:** grep for `dc`, `decoration`, or `catering` in the handler's item-id switch returns
zero matches. No DC sidebar item ids are registered.

### 2.3 Barrel Gap — 4 missing exports

**Status:** CONFIRMED  
**File:** `Dukan_x/lib/features/decoration_catering/decoration_catering.dart`  
**Lines:** 1–33 (entire file)  
**Evidence:** The barrel exports 13 screens but omits:
- `dc_event_detail_screen.dart` (exists at `presentation/screens/dc_event_detail_screen.dart`)
- `dc_quote_conversion_screen.dart` (exists at `presentation/screens/dc_quote_conversion_screen.dart`)
- `dc_staff_attendance_screen.dart` (exists at `presentation/screens/dc_staff_attendance_screen.dart`)
- `dc_vendor_rating_dialog.dart` (exists at `presentation/widgets/dc_vendor_rating_dialog.dart`)

### 2.4 `/dc/vendors` maps to `DcStaffScreen` (bug)

**Status:** CONFIRMED  
**File:** `Dukan_x/lib/core/routing/legacy_routes.dart`  
**Lines:** 1559–1576 (the `/dc/vendors` `GoRoute` builder)  
**Evidence:** The `child:` is `const DcStaffScreen()` rather than `DcVendorPaymentsScreen`.
The original comment also shows `child: const DcStaffScreen()` — this is the documented bug.

### 2.5 Rental price hardcoded to `0`

**Status:** CONFIRMED  
**File:** `Dukan_x/lib/features/decoration_catering/data/repositories/dc_repository.dart`  
**Lines:** 229–239 (`_inventoryFromJson`)  
**Evidence:** Line 236: `rentalPrice: 0` — hardcoded literal, not read from any API field.

### 2.6 `_expenseFromJson` hardcodes `PaymentMethod.cash`

**Status:** CONFIRMED  
**File:** `Dukan_x/lib/features/decoration_catering/data/repositories/dc_repository.dart`  
**Lines:** 298–307 (`_expenseFromJson`)  
**Evidence:** Line 304: `paymentMethod: PaymentMethod.cash` — ignores any stored payment method.

### 2.7 `_vendorPaymentFromJson` reads `paymentMode` with `'cash'` default

**Status:** CONFIRMED (partial — reads field but defaults to `'cash'` string)  
**File:** `Dukan_x/lib/features/decoration_catering/data/repositories/dc_repository.dart`  
**Lines:** 286–297 (`_vendorPaymentFromJson`)  
**Evidence:** Line 293: `paymentMode: j['paymentMode'] as String? ?? 'cash'` — reads the stored
field but applies a hard `'cash'` default when missing. This is NOT the same pattern as
`_expenseFromJson` (which always hardcodes).

### 2.8 Non-atomic inventory adjustment (`adjustInventory`)

**Status:** CONFIRMED  
**File:** `Dukan_x/lib/features/decoration_catering/data/repositories/dc_repository.dart`  
**Lines:** 507–514 (`adjustInventory`)  
**Evidence:** Calls `getInventory()` (reads ALL items from the API), finds the item, then
calls `PUT /dc/inventory/{id}` with a computed `currentStock`. This is a read-all-then-PUT
pattern, not an atomic delta.

### 2.9 `_bookingFromJson` non-null-safe casts

**Status:** CONFIRMED  
**File:** `Dukan_x/lib/features/decoration_catering/data/repositories/dc_repository.dart`  
**Lines:** 148–176 (`_bookingFromJson`)  
**Evidence:**
- Line 150: `j['id'] as String` — no null guard
- Line 152: `j['customerName'] as String` — no null guard
- Line 153: `j['customerPhone'] as String` — no null guard
- Line 156: `DateTime.parse(j['eventDate'] as String)` — throws on null/malformed
- Line 159: `(j['guestCount'] as num).toInt()` — throws on null
- Line 164: `DateTime.parse(j['createdAt'] as String)` — throws on null/malformed
- No `eventEndDate` mapping present.

### 2.10 Routes registered as guarded GoRoutes (DC routes in `legacy_routes.dart`)

**Status:** CONFIRMED — all DC routes ARE registered as `GoRoute`s with guards  
**File:** `Dukan_x/lib/core/routing/legacy_routes.dart`  
**Lines:** 1436–1718 (DC route block)  
**Evidence:** 14 DC routes are registered, each wrapped in `VendorRoleGuard` + `BusinessGuard(allowedTypes: [BusinessType.decorationCatering])`:
- `/dc/dashboard` → `DcDashboardScreen` (line 1445)
- `/dc/bookings` → `DcBookingsScreen` (line 1468)
- `/dc/bookings/new` → `DcBookingsScreen` (line 1488)
- `/dc/decoration` → `DcDecorationScreen` (line 1508)
- `/dc/catering` → `DcCateringScreen` (line 1528)
- `/dc/staff` → `DcStaffScreen` (line 1548)
- `/dc/vendors` → `DcStaffScreen` (**BUG** — line 1574)
- `/dc/inventory` → `DcInventoryScreen` (line 1588)
- `/dc/inventory_low` → `DcInventoryScreen` (line 1608)
- `/dc/reports` → `DcReportsScreen` (line 1628)
- `/dc/expense_report` → `DcReportsScreen` (line 1648)
- `/dc/billing` → `DcBillingScreen` (line 1668)
- `/dc/kitchen` → `DcCateringScreen` (line 1688)
- `/dc/venue` → `DcDecorationScreen` (line 1708)

**Note:** The design references "screens with NO route" (dc_calendar, dc_quotes, dc_profitability,
dc_shopping_list, dc_vendor_payments, dc_event_detail, dc_quote_conversion, dc_staff_attendance).
These 8 screens have no registered route — confirmed by absence from `_knownLegacyPaths` and
the `routes()` list.

---

## 3. `decoration_catering_module.dart` — Dead Code Status

**Status:** FILE DOES NOT EXIST ON DISK  
**Expected path:** `Dukan_x/lib/modules/decoration_catering/decoration_catering_module.dart`  
**Evidence:**
- The `lib/modules/` directory does not exist in the current project structure.
- `file_search` and `list_directory` return no results for this path.
- The file IS referenced in test golden digests:
  - `test/preservation/__goldens__/clean_file_digests.json` (line 7033, digest 1099497724, size 2879)
  - `test/preservation/__goldens__/d2_clean_ui_files.json` (line 2844)
- The audit report (`audit-decorationCatering.md`) references it at §6.3 as defining 8 `navItems` and
  routes via `decoration_catering_routes.dart`.

**Conclusion:** The file existed at the time of the audit/golden generation but has since been
deleted (likely during the `gorouter-navigation-migration` spec work that refactored routes into
`legacy_routes.dart`). The `modules/` directory and all its contents are gone. The DC routes that
were in `decoration_catering_routes.dart` are now registered directly in `legacy_routes.dart`.

**Classification:** The go_router DC_Module is **confirmed dead/removed** — the file no longer
exists on disk. Its functionality (route registration) was subsumed by `legacy_routes.dart`.
The golden digests retain a historical reference but the live code has no trace of it.

---

## 4. `getEventProfitability` Formula

**File:** `my-backend/src/handlers/dc.ts`  
**Lines:** 1671–1704  
**Formula (server-side computation):**

```typescript
const totalRevenuePaisa = invoices.reduce((s, i) => s + (i.totalPaisa || 0), 0);
const totalCollectedPaisa = invoices.reduce((s, i) => s + (i.advancePaidPaisa || 0), 0);
const totalExpensesPaisa = expenses.reduce((s, e) => s + (e.amountPaisa || 0), 0);
const netProfitPaisa = totalCollectedPaisa - totalExpensesPaisa;
const marginPct = totalRevenuePaisa > 0
    ? Math.round(netProfitPaisa * 100 / totalRevenuePaisa)
    : 0;
```

**Analysis:**
- `totalRevenuePaisa` = sum of `totalPaisa` across all invoices for the event
- `totalCollectedPaisa` = sum of `advancePaidPaisa` across all invoices for the event
- `totalExpensesPaisa` = sum of `amountPaisa` across all expenses for the event
- `netProfitPaisa` = totalCollected − totalExpenses (uses COLLECTED, not revenue)
- `marginPct` = netProfit / totalRevenue × 100 (rounded)

**Flag: FORMULA CORRECTNESS IS QUESTIONABLE**  
The `netProfitPaisa` uses `totalCollectedPaisa` (advance payments collected) rather than
`totalRevenuePaisa` (invoice totals). This means profit is computed against what's been
_collected_ (partial payments), not what's been _invoiced_ (total revenue). For events where
full payment hasn't been received, profit will be understated. Whether this is intentional
("cash-basis" accounting) or a bug is **unverified** — it depends on the business's accounting
model. Flagging for review.

**Client-side mapping:**  
**File:** `Dukan_x/lib/features/decoration_catering/data/repositories/dc_repository.dart`  
**Lines:** 732–749 (`getEventProfitability`)  
The client simply reads the server-computed values and converts from paise to rupees. No
additional formula applied client-side.

---

## 5. Phase-0-Pending Field/Endpoint Name Confirmations

### 5.1 Inventory rental-price API field name

**Status:** `unverified` — **NO SUCH FIELD EXISTS IN THE BACKEND**  
**Reason:** The backend `createInventoryItem` handler (`dc.ts` lines 972–996) stores only:
`name`, `category`, `unit`, `currentStock`, `reorderPoint`, `costPaisaPerUnit`, `description`.
The `updateInventoryItem` handler (`dc.ts` lines 1000–1027) allows updates to: `name`,
`category`, `unit`, `description`, `currentStock`, `reorderPoint`, `costPaisaPerUnit`.

**There is no `rentalPricePaisa` field stored or returned by the backend.** The client-side
`_inventoryFromJson` hardcodes `rentalPrice: 0` because no such field exists in the API response.

**Implication for Phase 4:** Populating `rentalPrice` from the API requires a backend schema
change to add the `rentalPricePaisa` field to DC inventory items. This is a **backend gap** —
the field must be added to the `createInventoryItem` and `updateInventoryItem` handlers' allowed
fields list, and existing items would need a migration or graceful default.

### 5.2 Atomic inventory-delta endpoint

**Status:** `unverified` — **NO ATOMIC DELTA ENDPOINT EXISTS**  
**Reason:** The backend offers only:
- `PUT /dc/inventory/{id}` — a full-record update that accepts `currentStock` as an absolute
  value (not a delta). See `dc.ts` lines 1000–1027.

There is no `POST /dc/inventory/{id}/adjust` or similar atomic delta endpoint. The client's
`adjustInventory` method reads all inventory, computes the new stock locally, then PUTs the
absolute value — confirming the race-prone pattern.

**Implication for Phase 4:** Implementing atomic stock adjustment requires either:
1. A new backend endpoint (e.g. `POST /dc/inventory/{id}/adjust { deltaQty }`)
2. Or a DynamoDB `ADD` expression in the existing `PUT` handler

This is a **backend gap** to be documented.

---

## 6. Backend Gaps Summary

| Gap | Endpoint/Field | Impact | Phase |
|-----|---------------|--------|-------|
| No `rentalPricePaisa` field in inventory schema | `POST/PUT /dc/inventory` | Rental pricing cannot be populated from API | Phase 4 |
| No atomic inventory delta endpoint | Missing `POST /dc/inventory/{id}/adjust` | Race-prone read-all-then-PUT | Phase 4 |
| `/dc/vendors` route maps to wrong screen | `legacy_routes.dart` line 1574 | Vendors unreachable | Phase 1 |
| 8 screens have no registered route | dc_calendar, dc_quotes, dc_profitability, dc_shopping_list, dc_vendor_payments, dc_event_detail, dc_quote_conversion, dc_staff_attendance | Screens unreachable by deep link | Phase 1 |

---

## 7. Ground Truth vs. Live Code Discrepancy Check

| Audit Claim | Live Code | Status |
|-------------|-----------|--------|
| Barrel omits 4 exports | Confirmed — barrel has 13 screen exports, 4 missing | ✓ Match |
| Sidebar has no DC case | Confirmed — falls through to `_getRetailSections()` | ✓ Match |
| No DC ids in sidebar_navigation_handler | Confirmed — zero matches | ✓ Match |
| `/dc/vendors` → `DcStaffScreen` | Confirmed — line 1574 | ✓ Match |
| `rentalPrice` hardcoded `0` | Confirmed — line 236 | ✓ Match |
| `_expenseFromJson` hardcodes `PaymentMethod.cash` | Confirmed — line 304 | ✓ Match |
| `adjustInventory` is read-all-then-PUT | Confirmed — lines 507–514 | ✓ Match |
| `_bookingFromJson` non-null-safe casts | Confirmed — lines 148–176 | ✓ Match |
| go_router DC_Module is dead code | **File deleted** — no longer on disk | ✓ Match (stronger: removed entirely) |
| DC routes exist in legacy routes | Confirmed — 14 routes in `legacy_routes.dart` 1436–1718 | ✓ Match |
| `getEventProfitability` is server-computed | Confirmed — formula in `dc.ts` 1671–1704 | ✓ Match |
| No `rentalPricePaisa` API field | Confirmed — backend schema has no such field | ✓ Match |
| No atomic delta endpoint | Confirmed — only `PUT` with absolute `currentStock` | ✓ Match |

**No Ground Truth / audit claim contradicts the live code.** All findings are confirmed or
stronger than stated (DC_Module file is outright deleted rather than merely dormant).

---

## 8. Summary

- **All 17 `/dc/*` endpoint groups:** non-stub handlers deployed ✓
- **Sidebar/Navigation/Barrel gaps:** confirmed ✓
- **`/dc/vendors` → wrong screen:** confirmed ✓
- **DC_Module (`decoration_catering_module.dart`):** confirmed dead — file deleted from disk ✓
- **`getEventProfitability` formula:** recorded, flagged as questionable (uses collected vs revenue for profit)
- **`rentalPricePaisa` API field:** does NOT exist — backend gap ⚠️
- **Atomic inventory delta endpoint:** does NOT exist — backend gap ⚠️
- **Ground Truth vs. live code:** zero contradictions — proceed with Phase 1

---

*End of Verification Report — Phase 0*
