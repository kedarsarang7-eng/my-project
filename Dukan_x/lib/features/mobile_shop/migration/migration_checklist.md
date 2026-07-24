# Mobile Shop Obsolete Navigation — Migration Checklist

> **Purpose:** Evidence-gated removal of obsolete parallel mobile navigation
> and dead dispatch branches. NO file is deleted without test evidence proving
> it is unreachable.
>
> **Requirements:** 1.4, 2.8, 6.22; GR-1.2  
> **Audit findings:** AF-04, AF-35  
> **Replaced by:** Tasks 13.1 (route catalog), 13.2 (quick actions/deep links),
> 11.2 (MobileSyncCoordinator), 12.3 (MobileSaleConsistencyOrchestrator)

---

## Current State Summary

| Item | Status | Evidence |
|------|--------|----------|
| `MobileShopModule` class & GoRouter routes | **REMOVED** | `lib/modules/mobile_shop/` directory absent |
| `MobileShopSyncHandler` | **REMOVED** | No file or import found |
| `MobileShopWsHandler` | **REMOVED** | No file or import found |
| `LegacyRouteRedirect` stubs in module | **REMOVED** | No class definition found |
| `billing_service.dart` mobileShop branch | **PRESENT** — awaiting orchestrator | Line ~197; defers to `manual_item_entry_sheet.dart` |
| `MaterialApp.router` + `appRouterProvider` | **ACTIVE** — sole composition | `app.dart:204`, `app_router.dart:508` |

---

## Pre-Removal Evidence Checklist

### Already verified (module removal)

- [x] Verify `MobileShopModule` is not imported anywhere in `lib/`
  - **Evidence:** `grep -r "MobileShopModule" lib/` → 0 results
  - **Date verified:** During task 13.3 implementation

- [x] Verify `modules/mobile_shop/` directory does not exist
  - **Evidence:** Directory listing shows no `modules/mobile_shop/` path
  - **Date verified:** During task 13.3 implementation

- [x] Verify no orphaned sync handler imports remain
  - **Evidence:** `grep -r "MobileShopSync|MobileShopWs" lib/` → 0 class refs
  - **Date verified:** During task 13.3 implementation

- [x] Verify `LegacyRouteRedirect` class is not defined in `lib/`
  - **Evidence:** Only references are in audit tooling (`gap_registry.dart`)
    and comments documenting Mandi replacements
  - **Date verified:** During task 13.3 implementation

### Pending verification (requires later task completion)

- [ ] Verify all mobileShop bill creation flows route through
  `MobileSaleConsistencyOrchestrator` (task 12.3)
  - **Check:** No direct `BillingService.createBill()` path for mobileShop
    tenants bypasses the orchestrator
  - **Prerequisite:** Task 12.3 complete

- [ ] Fix or remove the `billing_service.dart` mobileShop string branch
  - **Location:** `lib/features/billing/services/billing_service.dart` ~line 197
  - **Current code:** `businessType == BusinessType.mobileShop.name` enters
    the IMEI validation block, but the inner duplicate detection (`if
    (businessType == 'electronics')`) skips mobileShop — making the outer
    condition a pass-through that only hits the tenant-scoped uniqueness check
  - **Decision:** Remove mobileShop from the outer condition after task 12.3
    proves the orchestrator handles all mobileShop IMEI uniqueness
  - **Prerequisite:** Task 12.3 + task 12.4 test evidence

- [ ] Remove any remaining `LegacyRouteRedirect` stubs from orphaned module
  - **Status:** Already removed (module directory absent)
  - **Regression guard:** Task 13.5 test should assert no such class exists

- [ ] Verify all affected quick actions route through new navigation system
  - **Check:** Every mobileShop quick action in
    `mobile_shop_quick_actions.dart` resolves to a production screen
  - **Prerequisite:** Task 13.2 complete (confirmed)

- [ ] Run reachability test suite (task 13.5) to confirm
  - **Check:** All sidebar items, quick actions, deep links, and named routes
    for mobileShop render their guarded destination without exceptions
  - **Prerequisite:** Task 13.5 implementation

---

## Sole Router Composition — Invariant Documentation

The following invariant must hold and is enforced by task 13.5 tests:

1. **`app.dart` uses `MaterialApp.router`** — specifically `routerConfig: router`
   where `router` = `ref.watch(appRouterProvider)` (line 204)

2. **`appRouterProvider` is the single `GoRouter` instance** — defined at
   `lib/core/routing/app_router.dart:508` as
   `final appRouterProvider = Provider<GoRouter>((ref) => AppRouter.build(ref: ref))`

3. **No parallel `MaterialApp(routes:)` or `Navigator` composition exists** —
   the legacy `buildAppRoutes()` route map has been replaced

4. **Mobile routes integrate through** `lib/features/mobile_shop/navigation/`:
   - `mobile_shop_route_catalog.dart` — route definitions
   - `mobile_shop_route_bindings.dart` — GoRouter integration
   - `mobile_shop_sidebar_builder.dart` — sidebar entries
   - `mobile_shop_quick_actions.dart` — dashboard actions
   - `mobile_shop_deep_links.dart` — external/deep link handling
   - `mobile_shop_content_host_guard.dart` — content dispatch guard

5. **`LegacyRoutes` handles alias resolution** — not module redirects:
   - `lib/core/routing/legacy_routes.dart` provides `aliasTargetFor()`
   - Composed into `appRouterProvider`'s redirect callback
   - Resolves old string paths to canonical `RoutePaths` constants

---

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Removing mobileShop from billing_service outer condition breaks electronics | Inner `if (businessType == 'electronics')` block is independent; removal of mobileShop from outer condition does not affect electronics path |
| Future module system re-introduced | Task 13.5 regression test asserts `modules/mobile_shop/` absence and sole `appRouterProvider` composition |
| billing_service change breaks non-mobile billing | The outer condition already skips non-mobile/non-electronics types; only mobileShop pass-through changes |
| LegacyRoutes alias resolution gaps | Proven by existing `phase_a_property7_alias_idempotence_test.dart` and `phase_a_foundation_wiring_preservation_test.dart` |

---

## File References

| File | Role |
|------|------|
| `lib/app/app.dart` | App entry — sole `MaterialApp.router` composition |
| `lib/core/routing/app_router.dart` | `appRouterProvider` definition |
| `lib/core/routing/legacy_routes.dart` | `LegacyRoutes.aliasTargetFor` alias layer |
| `lib/features/mobile_shop/navigation/` | Dedicated mobileShop navigation system |
| `lib/features/billing/services/billing_service.dart` | Contains pending dead branch |
| `lib/features/mobile_shop/migration/obsolete_paths_inventory.dart` | Programmatic inventory |
| `lib/features/mobile_shop/migration/sole_router_assertion.dart` | Test assertion patterns |
