# Phase 0 Findings — Electronics Vertical Remediation (READ-ONLY)

> Property 2 (Phase 0): Investigation gates resolved before action.
> This note records the evidence-based answer to each Phase 0 gate (2.1–2.4),
> re-verified against the **live** codebase under `Dukan_x/lib/`. No code was
> modified. Source paths below are relative to `Dukan_x/lib/` unless absolute.
>
> Verdict legend: **CONFIRMED** (assumption holds, dependent phase may proceed) ·
> **REFUTED** (assumption is wrong) · **DECISION REQUIRED** (a choice must be
> recorded before the dependent phase).

---

## Gate 2.1 — Route mounting (blocks Phase 2 route edits)

**Verdict: CONFIRMED — all six routes are live `GoRoute`s mounted on the active
router. The sibling-audit "GoRouter not mounted" note is STALE/REFUTED.**

### Active router is GoRouter via `MaterialApp.router`

- `app/app.dart` (lines ~174–207) builds the app with `MaterialApp.router(... routerConfig: router ...)`, where `router = ref.watch(appRouterProvider)`. go_router is the sole navigation path.
- `core/routing/app_router.dart` owns the single `GoRouter` instance:
  - Header (lines ~6–9): "This file owns the application's single `GoRouter` instance and is the SOLE navigation path for the app … the former `useGoRouterShell` flag and the legacy `MaterialApp.routes` (`buildAppRoutes()`) path have been removed."
  - `appRouterProvider` (lines ~505–509): "The app root reads this to drive `MaterialApp.router`; it is the app's sole navigation source."
  - Line ~128: `...LegacyRoutes.routes(),` — the legacy `GoRoute`s are spread into the active GoRouter's `routes:` list.
- `core/routing/legacy_routes.dart` header (lines ~6–12) reconciles the audit note explicitly: "The just-completed `gorouter-navigation-migration` spec made `MaterialApp.router` the SOLE navigation root, leaving the old `MaterialApp.routes` table (`buildAppRoutes()`) unwired." So the thing that is *not* mounted is the **legacy `MaterialApp.routes` table**, NOT GoRouter. The routes were re-registered as top-level `GoRoute`s in this file.

> Reconciliation: the sibling-audit "GoRouter not mounted" claim is inverted relative to current reality. GoRouter **is** mounted and is the only router; the legacy named-route map is the unwired/removed one.

### Each target route is a registered live `GoRoute`

All six paths appear both in `LegacyRoutes._knownLegacyPaths` (the parity set) and as concrete `GoRoute` entries returned by `LegacyRoutes.routes()`:

| Route | `_knownLegacyPaths` | `GoRoute` def | Guard stack (live) |
|---|---|---|---|
| `/computer-shop/warranty` | line ~414 | line ~2572 | `VendorRoleGuard(viewInvoices)` → `BusinessGuard([computerShop, mobileShop])` → `CapabilityGate(useWarranty, [computerShop, mobileShop])` → `WarrantyScreen` |
| `/computer-shop/serial-history` | line ~415 | line ~2596 | `VendorRoleGuard(viewInvoices)` → `BusinessGuard([computerShop, mobileShop])` → `CapabilityGate(useIMEI, [computerShop, mobileShop])` → `SerialHistoryScreen` |
| `/computer-shop/multi-unit` | line ~419 | line ~2676 | `VendorRoleGuard(systemSettings)` → `BusinessGuard([computerShop])` → `MultiUnitScreen` (NO inner `CapabilityGate`) |
| `/job/create` | line ~359 | line ~1502 | `VendorRoleGuard(manageStaff)` → `BusinessGuard([mobileShop, computerShop, service, electronics])` → `CreateServiceJobScreen` |
| `/job/status` | line ~360 | line ~1530 | `VendorRoleGuard(manageStaff)` → `BusinessGuard([mobileShop, computerShop, service, electronics])` → `ServiceJobListScreen` |
| `/job/deliver` | line ~361 | line ~1557 | `VendorRoleGuard(manageStaff)` → `BusinessGuard([mobileShop, computerShop, service, electronics])` → `ServiceJobListScreen` |

**Impact on later phases:** Phase 2 route edits are UNBLOCKED — they target real, mounted `GoRoute`s in `legacy_routes.dart`. Editing the allow-lists there takes effect at runtime.

---

## Gate 2.2 — Access decision per screen (allow-list vs capability)

**Verdict: CONFIRMED. Electronics holds `useIMEI` + `useWarranty` and LACKS
`useMultiUnit`/`useJobSheets`/`useRepairStatus`/`useBuyback`/`useExchange`.
Confirms D6.**

Evidence — `core/isolation/business_capability.dart`, `'electronics'` capability set (lines ~367–411). Electronics **holds**:
`useProductAdd, useProductName, useProductSalePrice, useProductStockQty, useProductUnit, useProductTax, useProductCategory, useInventoryList, useVisibleStock, useInventorySearch, useInvoiceList, useInvoiceSearch, useInvoiceCreate, useLowStockAlert, useDailySnapshot, useRevenueOverview, usePurchaseOrder, useStockEntry, useSupplierBill, **useIMEI**, **useWarranty**, useBarcodeScanner, useScanOCR, useStockManagement`.

Electronics **does NOT hold** (absent from the set): `useMultiUnit`, `useJobSheets`, `useRepairStatus`, `useBuyback`, `useExchange`.

### Per-screen access decision

| Screen / route | Current guard | Electronics capability | Decision |
|---|---|---|---|
| Warranty (`/computer-shop/warranty`) | `BusinessGuard([computerShop, mobileShop])` + `CapabilityGate(useWarranty)` | HAS `useWarranty` | **Allow-list widening only** — add `electronics` to BOTH the `BusinessGuard.allowedTypes` and the inner `CapabilityGate.allowedTypes`. Capability predicate already passes. |
| Serial-History (`/computer-shop/serial-history`) | `BusinessGuard([computerShop, mobileShop])` + `CapabilityGate(useIMEI)` | HAS `useIMEI` | **Allow-list widening only** — same two lists. |
| IMEI/Serial Tracking (`ImeiTrackingStatementScreen`) | none (orphaned — no route) | HAS `useIMEI` | **New route + sidebar entry**; gate with `CapabilityGate(useIMEI, [electronics, …])`. Capability already satisfied. |
| Multi-Unit (`/computer-shop/multi-unit`) | `VendorRoleGuard(systemSettings)` + `BusinessGuard([computerShop])`, NO `CapabilityGate` | LACKS `useMultiUnit` | **DECISION REQUIRED (Phase 2):** either (a) grant `useMultiUnit` to electronics in `business_capability.dart` AND widen the `BusinessGuard` allow-list, or (b) **park** Multi-Unit and document the deferral. Not a pure allow-list widen. Recommended: **park** unless multi-unit is a stated Electronics requirement (it is not enumerated in scope). |
| Service/Repair Jobs (`/job/create|status|deliver`) | `VendorRoleGuard(manageStaff)` + `BusinessGuard([…, electronics])`, NO `CapabilityGate(useJobSheets)` | (jobs gated by RBAC `manageStaff`, not capability) | **No route/guard change** — electronics already allowed (see Gate 2.1 / D7). Note: these `/job/*` routes do NOT use `CapabilityGate(useJobSheets)`, so electronics lacking `useJobSheets` is irrelevant here. Surface via a Phase 4 sidebar entry only. |

**Parked capabilities:** `useBuyback` and `useExchange` are NOT held by electronics and are explicitly **out of scope** (parked) per `bugfix.md` and design "Out of scope". Do not grant.

> Caveat on job-cards vs jobs: `/computer-shop/job-cards`, `/computer-shop/job-card-detail`, `/computer-shop/create-job-card` DO use `CapabilityGate(useJobSheets, [computerShop, mobileShop])` (lines ~2544, ~2620, ~2646). These are a different family from `/job/*` and are NOT in the Phase 2 scope; electronics lacking `useJobSheets` means those job-card routes remain closed to electronics, which is consistent with surfacing only `/job/*` (the service-job flow) for electronics.

---

## Gate 2.3 — `getImeiTrackingStatement` tenant scope (blocks Phase 2 screen wiring)

**Verdict: CONFIRMED tenant-scoped. The `userId` parameter IS the correct tenant
boundary because the value flowing into it is always `ownerId` (DukanX's explicit
owner-isolation field). No separate `vendorId` filter is required. Confirms D4 as a
resolved concern — the query is tenant-scoped and never relies on `SYSTEM`.**

### The query filters by `userId`

- `core/repository/statements_repository.dart`, `getImeiTrackingStatement` (lines ~716–823):
  ```dart
  var query = database.select(database.iMEISerials)
    ..where((i) => i.userId.equals(userId));
  ```
  Optional `productId` / `status` filters narrow further; no `vendorId` column is referenced (the table has no `vendorId`).

### The value passed as `userId` is the tenant owner id

- `core/services/statements_service.dart`, `generateImeiTrackingStatement` (line ~331):
  ```dart
  final userId = _sessionManager.ownerId;
  if (userId == null) throw Exception('User not authenticated');
  final result = await _repository.getImeiTrackingStatement(userId: userId, ...);
  ```
- `core/session/session_manager.dart` (line ~198): `String? get ownerId => _currentSession.ownerId ?? userId;`
- `core/database/tables.dart` (lines ~111–112) documents the boundary: *"NEW: Owner Isolation (Explicit) — Prevents cross-tenant data leaks even if userId is ambiguous"* (`ownerId` column). `ownerId` is DukanX's tenant boundary.

### Read and write boundaries agree (no `userId` vs `ownerId` mismatch)

- Write/validation at billing — `core/repository/bills_repository.dart`:
  - Line ~232: tenant guard `if (bill.ownerId.isEmpty) { ... abort ... }` (no `SYSTEM` fallback).
  - Line ~239: `validateBillItems(userId: bill.ownerId, ...)`.
  - Line ~616: `markIMEIsAsSoldSafe(userId: bill.ownerId, ...)`.
- `IMEISerials` unique key — `core/database/tables.dart` (lines ~2414–2484): `uniqueKeys => [{userId, imeiOrSerial}]`.
- `features/service/data/repositories/imei_serial_repository.dart`: EVERY method (`createIMEISerial`, `getByNumber`, `exists`, `isAvailableForSale`, `markAsSold`, `getAll`, `getInStock`, `getInStockCount`, `softDelete`, …) scopes by the `userId` parameter, and the value supplied by callers is `ownerId`.

**Conclusion:** the column named `userId` consistently carries the `ownerId` value on both read and write. The boundary is internally consistent and tenant-isolated. The historical `vendorId:'SYSTEM'` leak pattern does **not** apply here — there is no `SYSTEM` default and the billing path aborts on empty `ownerId`.

**Minor observation (not a blocker):** inside `getImeiTrackingStatement`, the nested lookups for product (`products.id`), bill (`bills.id`), and bill item (`billItems.billId & productId`) are filtered by id only, not by an independent tenant predicate. They are reached only via ids that belong to the tenant's own `IMEISerials` rows (UUID/RID ids, collision-negligible), so this is indirect tenant scoping rather than a leak. Phase 2 may optionally add an explicit `userId`/`ownerId` predicate to those nested reads as defense-in-depth, but it is not required for correctness.

**Impact on later phases:** Phase 2 may wire `ImeiTrackingStatementScreen` — the backing query is tenant-scoped. Continue to pass `ownerId` (via `_sessionManager.ownerId` / `bill.ownerId`); do not introduce a `SYSTEM` or unscoped read.

---

## Gate 2.4 — Route-file location (corrects stale audit citations)

**Verdict: CONFIRMED. The live route file is
`core/routing/legacy_routes.dart`. The stale `app/routes.dart` citations are
invalid — that file no longer exists. Confirms D3.**

- `file_search` for `Dukan_x/lib/app/routes.dart` → **no file found**. The legacy `buildAppRoutes()` table has been removed (corroborated by `app_router.dart` header: "the legacy `MaterialApp.routes` (`buildAppRoutes()`) path have been removed").
- All computer-shop / job device-route `GoRoute`s live in `core/routing/legacy_routes.dart` (see Gate 2.1 line references).
- `main.dart` (lines ~50–53): "Navigation is driven by go_router via MaterialApp.router, configured in lib/app/app.dart. The legacy named-route table was removed."

**Impact on later phases:** every Phase 2 guard/route edit MUST target `core/routing/legacy_routes.dart`. Do not act on the audit's `app/routes.dart` line numbers (1110–1142) — that file is gone.

---

## Supporting finding — `ImeiTrackingStatementScreen` is orphaned (supports 1.9 / Phase 2 task 8.2)

- The screen exists: `features/statements/presentation/screens/imei_tracking_statement_screen.dart` (class `ImeiTrackingStatementScreen`, ctor takes optional `productId` / `productName`).
- A repo-wide grep for `ImeiTrackingStatementScreen` returns ONLY its own definition file — there is **no route registration and no sidebar reference** anywhere. It is fully unreachable today, confirming the need for the new `GoRoute` + sidebar entry in Phases 2/4.

---

## D-item reconciliation summary

| D-item | Status from live re-verification |
|---|---|
| **D1** (serial validator null for electronics) | Out of Phase 0 read scope to fully re-derive here, but consistent: `imei_validation_service.validateBillItems` only adds a blank-serial error when `businessType` contains `'mobile'` (line ~99), so electronics blanks pass. Phase 1 concern. |
| **D3** (route file location) | **CONFIRMED** — `app/routes.dart` deleted; live file is `core/routing/legacy_routes.dart` (Gate 2.4). |
| **D4** (IMEI query tenant scope) | **CONFIRMED & RESOLVED** — `userId` param carries `ownerId`; tenant-scoped, non-`SYSTEM` (Gate 2.3). |
| **D6** (device-route guards already widened to `[computerShop, mobileShop]` + inner `CapabilityGate`) | **CONFIRMED** — warranty + serial-history use that exact two-layer guard; electronics absent from both lists; multi-unit still `[computerShop]` only with no `CapabilityGate` (Gates 2.1, 2.2). |
| **D7** (`/job/*` already allow electronics + `manageStaff`) | **CONFIRMED** — all three `/job/*` routes include `BusinessType.electronics` and require `Permissions.manageStaff`; no `CapabilityGate` on them (Gates 2.1, 2.2). |

## Phase 2 readiness gates

- **2.1 route mounting:** RESOLVED → Phase 2 route edits UNBLOCKED (target `legacy_routes.dart`).
- **2.2 access decision:** RESOLVED for Warranty/Serial-History/ImeiTracking (allow-list widening). **DECISION REQUIRED** for Multi-Unit (grant `useMultiUnit` vs park — recommend park). Buyback/Exchange parked.
- **2.3 tenant scope:** RESOLVED → `ImeiTrackingStatementScreen` safe to wire with `ownerId`-scoped query.
- **2.4 route-file location:** RESOLVED → use `core/routing/legacy_routes.dart`.
