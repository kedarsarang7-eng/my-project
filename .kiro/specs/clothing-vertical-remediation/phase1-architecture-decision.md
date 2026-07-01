# Phase 1 — Architecture Decision Record: Clothing Route Surface

> **Status:** PROPOSED — awaiting approval  
> **Date:** 2025-07-21  
> **Decision Maker:** Maintainer (human sign-off required)  
> **Scope:** Clothing vertical navigation reachability (Requirement 4)

---

## Context

The clothing vertical (`BusinessType.clothing`) ships multiple screens — `ClothingInventoryScreen`, `VariantManagementScreen`, `TailoringMeasurementsScreen`, `VariantGridWidget`, `ClothingVariantScannerWidget` — but almost none are reachable from the live app's sidebar or quick actions.

### Current navigation reality (confirmed in Phase 0)

- **The app root** (`lib/app/app.dart`) uses `MaterialApp.router(routerConfig: appRouterProvider)` — GoRouter is the **sole navigation path**. The former `MaterialApp(routes: buildAppRoutes())` legacy table is **completely unwired** and has been removed from the app root.
- **`AppRouter.build()`** (`lib/core/routing/app_router.dart`) constructs the single `GoRouter` instance. It spreads `LegacyRoutes.routes()` at the top level and registers per-sidebar-item `GoRoute`s under a `ShellRoute` via `_shellChildRoutes()`.
- **`LegacyRoutes.routes()`** (`lib/core/routing/legacy_routes.dart`) is the list of `GoRoute` objects that were lifted verbatim from the former `buildAppRoutes()` table during the go_router migration. This is where the existing `/clothing/variants` route lives (lines 2718–2735), wrapped in `VendorRoleGuard(Permissions.manageStaff)` + `BusinessGuard([BusinessType.clothing])`.
- **`_shellChildRoutes()`** registers one `GoRoute` per known legacy sidebar `itemId` (90 total from `RoutePaths.knownItemIds`), each delegating to `SidebarNavigationHandler.getScreenForItem`. This is the surface where sidebar-driven navigation is resolved.
- **The `ClothingModule` GoRouter system** described in the original audit (`lib/modules/clothing/`) does **not exist** in the current codebase. The `lib/modules/` directory is entirely absent. There is no `ClothingModule`, no `clothingRoutes`, no `navItems` to mount.
- **The `buildAppRoutes()` function** still exists in source but is **not wired** into any `MaterialApp` — it is dead code retained only as migration reference.

### Problem to solve

The clothing screens need to become reachable via sidebar items and quick actions. This requires registering navigation routes on the live route surface and adding clothing entries to the sidebar configuration. Two architectural approaches exist.

---

## Options Considered

### Option A — Mount the full GoRouter module system

Register a `ClothingModule` as a separate GoRouter route sub-tree (analogous to the pattern the audit described) with its own route list and `navItems`, mounted as a nested route group in the main `GoRouter`.

**Characteristics:**
- Would create a new `lib/modules/clothing/` directory with a module class, a route list, nav items, and potentially its own sync/ws handlers.
- Requires adding a module registry system that doesn't currently exist in the codebase (the `modules/` directory is absent — it would need to be built from scratch).
- Would introduce a parallel navigation registration pattern that no other vertical currently uses in the live app.
- The module's `navItems` would need a consumer — the sidebar is currently driven by `sidebar_configuration.dart` / `sidebarSectionsProvider`, not by a module registry. A bridge between the module nav system and the sidebar provider would be needed.

**Trade-offs:**
- (+) Clean separation of the clothing route namespace into a self-contained module.
- (+) Hypothetically reusable pattern for other verticals in the future.
- (−) Introduces a new architectural pattern (module system) that doesn't exist in the live codebase — no `modules/` directory, no module registry, no consumers.
- (−) The sidebar is not driven by module `navItems`; building a bridge adds complexity and risk.
- (−) Violates the scope boundary (Requirement 2.2): "SHALL NOT perform an app-wide GoRouter migration" — adding a module system changes the app's navigation architecture.
- (−) Risks regressing the 8 other verticals whose routes currently work through `legacy_routes.dart` + `_shellChildRoutes()`.
- (−) Significantly larger blast radius for a first-phase decision.

### Option B — Register scoped clothing routes on the existing GoRouter route surface

Register the clothing screens as guard-wrapped `GoRoute` entries in the **existing** route registration surfaces:
- **Top-level routes** (in `LegacyRoutes.routes()` within `lib/core/routing/legacy_routes.dart`) for routes needing arguments or special guards.
- **Shell child routes** (in `_shellChildRoutes()` within `lib/core/routing/app_router.dart`) for sidebar-navigable screens, following the same `RoutePaths.knownItemIds` pattern every other vertical uses.

**Characteristics:**
- Uses the identical pattern every other vertical already uses for route registration.
- The existing `/clothing/variants` route is already registered this way (lines 2718–2735 of `legacy_routes.dart`).
- Clothing sidebar items register via `_getClothingSections()` in `sidebar_configuration.dart` → sidebar taps dispatch via `context.go(RoutePaths.navPathForItemId(itemId))` → resolved by the `GoRoute` in `_shellChildRoutes()` → delegated to `SidebarNavigationHandler.getScreenForItem`.
- No new architectural patterns, no module system, no module registry.

**Trade-offs:**
- (+) Additive and surgical — follows the exact pattern the other 8 verticals use.
- (+) The existing `/clothing/variants` route already proves this pattern works for clothing.
- (+) Sidebar integration is straightforward — add a case to `SidebarNavigationHandler` and register the `itemId` in `RoutePaths`.
- (+) Fully within scope boundary (Requirement 2.1, 2.2) — no app-wide migration.
- (+) Reversible — routes can be removed by deleting entries without architectural rollback.
- (−) Clothing routes are co-located with all other verticals' routes in shared files rather than isolated in a module directory.
- (−) No module-level encapsulation (sync/ws handlers would live under `features/clothing/` instead).

---

## Decision

**Option B is selected** — register scoped clothing routes on the existing GoRouter route surface.

---

## Rationale

1. **The module system does not exist.** The `lib/modules/` directory is absent from the codebase. Building it from scratch for a single vertical introduces unjustified architectural complexity with no proven consumer.

2. **The live surface is GoRouter via `LegacyRoutes.routes()` + `_shellChildRoutes()`.** Every vertical in the app registers routes this way. The existing `/clothing/variants` GoRoute already proves clothing works on this surface. Following the established pattern is the lowest-risk, most predictable approach.

3. **Scope boundary compliance.** Requirement 2.2 explicitly states the remediation "SHALL NOT perform an app-wide GoRouter migration." Creating a module system and wiring it into the router is an architectural change that extends well beyond the clothing vertical's needs.

4. **Sidebar integration is already solved.** The sidebar dispatches `context.go(path)` for each `itemId`. Adding clothing items means adding `itemId` entries to `RoutePaths`, registering matching `GoRoute`s in `_shellChildRoutes()`, and handling them in `SidebarNavigationHandler`. This is the same three-step process used for every other vertical — well-tested and well-understood.

5. **Minimal blast radius.** Option B touches only the clothing case in shared files (sidebar config, route paths, navigation handler) plus `legacy_routes.dart` for argument-bearing routes. Option A would require creating new infrastructure (`modules/`, registry, nav-item bridge) with unknown interactions.

6. **Reversibility.** Route entries added under Option B can be individually removed without affecting the navigation architecture. A module system, once introduced, creates coupling that is harder to roll back.

---

## Documented Route Surface

**All subsequent clothing routes SHALL be registered on a single documented route surface:**

- **Surface:** The `GoRouter` route tree constructed by `AppRouter.build()` in `lib/core/routing/app_router.dart`
- **Registration points:**
  - **Sidebar-navigable screens:** Registered as `GoRoute` entries in `_shellChildRoutes()` (inside the `ShellRoute`), following the `RoutePaths.knownItemIds` pattern, with builders delegating to `SidebarNavigationHandler.getScreenForItem`.
  - **Argument-bearing or specially-guarded routes:** Registered as `GoRoute` entries in `LegacyRoutes.routes()` within `lib/core/routing/legacy_routes.dart`, following the existing `/clothing/variants` pattern.
- **Guard pattern:** Each clothing route is wrapped in `BusinessGuard(allowedTypes: [BusinessType.clothing])` and the appropriate `VendorRoleGuard(requiredPermission: ...)` — matching the established guard convention.
- **Capability enforcement:** The router-level capability guard (`AppRouter.capabilityRedirect`) gates routes via `_routeCapabilityBindings`; new clothing capabilities are added to this map.

---

## Consequences

### Positive
- Clothing screens become reachable through the same navigation path every other vertical uses.
- No new infrastructure or patterns to maintain.
- The existing `/clothing/variants` route continues working without modification.
- Sidebar → screen resolution uses the proven `SidebarNavigationHandler` pipeline.
- Phase 2 (sidebar wiring) and subsequent phases can proceed with well-understood integration points.

### Negative
- Clothing routes are not isolated in their own module — they coexist with other verticals' routes in `legacy_routes.dart` and `_shellChildRoutes()`.
- Future module-level refactoring (if desired) would require extracting the routes from these shared files.

### Neutral
- The `ClothingModule` concept described in the audit is acknowledged as non-existent; this decision does not preclude creating one in a future milestone if the app adopts a module architecture.
- The `buildAppRoutes()` function remains dead code; this decision neither uses nor removes it.

---

## Phase 1 Gate

No sidebar wiring, no route registration, and no application source code changes have been performed. This decision record is the sole artifact of Phase 1.

If this decision is **rejected or returned with changes**, the record will be retained, requested changes applied, and the Phase 1 gate re-emitted without beginning any wiring work.

---

PHASE 1 COMPLETE — AWAITING APPROVAL
