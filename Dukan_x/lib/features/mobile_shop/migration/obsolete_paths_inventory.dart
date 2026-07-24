/// Inventory of obsolete mobile-shop navigation and dispatch paths.
///
/// Each entry documents:
/// - What it is
/// - Where it was (file + line/pattern reference)
/// - Why it's obsolete (which new system replaces it)
/// - Prerequisite evidence needed before removal
/// - AF reference from audit-mobileShop.md
/// - VERIFIED REMOVAL status with date and evidence
///
/// This inventory exists for safe, evidence-gated removal. Items marked
/// VERIFIED REMOVED have been confirmed absent through filesystem inspection,
/// import analysis, and reachability tests (tasks 13.3, 13.5).
///
/// Requirements: 1.4, 2.8, 6.1–6.2, 6.22, 6.24; GR-1.2
/// Audit: AF-04, AF-35
/// Task: 8.4 — Non-authoritative persistence path documentation
library;

/// Inventory of paths that are confirmed obsolete based on architectural
/// evidence gathered during remediation tasks 13.1–13.3.
///
/// Current state (post-remediation):
/// - The app uses `MaterialApp.router` with `routerConfig: router` where
///   `router` is obtained from `appRouterProvider` (lib/app/app.dart:204).
/// - `appRouterProvider` (lib/core/routing/app_router.dart:508) is the SOLE
///   navigation source via `AppRouter.build(ref: ref)`.
/// - The dedicated mobileShop navigation system (task 13.1, 13.2) lives at
///   `lib/features/mobile_shop/navigation/` and integrates through route
///   bindings, sidebar builder, quick actions, deep links, and content-host
///   guard — all flowing through the same `appRouterProvider` GoRouter.
///
/// VERIFICATION SUMMARY (Task 8.4):
/// ┌─────────────────────────────────┬─────────────────┬─────────────────┐
/// │ Item                            │ Status          │ Verified Date   │
/// ├─────────────────────────────────┼─────────────────┼─────────────────┤
/// │ MobileShopModule                │ VERIFIED REMOVED│ 2025-07-19      │
/// │ Orphaned Sync Handlers          │ VERIFIED REMOVED│ 2025-07-19      │
/// │ Legacy Route Redirects          │ VERIFIED REMOVED│ 2025-07-19      │
/// │ billing_service dead branch     │ PENDING (12.3)  │ —               │
/// └─────────────────────────────────┴─────────────────┴─────────────────┘
///
/// Evidence methodology:
/// 1. Filesystem inspection — directories/files confirmed absent
/// 2. Import analysis — no active source references these paths
/// 3. Router composition — `appRouterProvider` is the sole GoRouter creation
/// 4. Reachability tests — task 13.5 test suite validates all routes
///
/// Sole deployment path: `Dukan_x/my-backend` (see design.md §Architecture)
abstract class ObsoletePathsInventory {
  const ObsoletePathsInventory._();

  // ===========================================================================
  // AF-04: MobileShopModule — orphaned GoRouter module (ALREADY REMOVED)
  // ===========================================================================

  /// **What:** `MobileShopModule` class exposing GoRouter `routes` and 6
  /// `navItems` (Billing, Scan Bill, IMEI Track, Repair, Exchange, EMI).
  ///
  /// **Original location:**
  /// - `lib/modules/mobile_shop/mobile_shop_module.dart`
  /// - `lib/modules/mobile_shop/routes/mobile_shop_routes.dart`
  ///
  /// **Why obsolete:** The app never mounted `MaterialApp.router` with module
  /// routes; it used the legacy `MaterialApp(routes: buildAppRoutes())` map.
  /// Post-remediation, `MaterialApp.router` uses `appRouterProvider` as the
  /// sole composition. The dedicated navigation system (task 13.1) at
  /// `lib/features/mobile_shop/navigation/mobile_shop_route_bindings.dart`
  /// replaces all module route definitions.
  ///
  /// **Current status:** VERIFIED REMOVED — 2025-07-19
  /// Files confirmed absent from the filesystem. The `modules/mobile_shop/`
  /// directory no longer exists. No imports reference these paths.
  ///
  /// **Evidence (task 13.3, 13.5):**
  /// - `find lib/ -path "*modules/mobile_shop*"` → 0 results
  /// - `grep -r "MobileShopModule" lib/` → 0 results
  /// - `appRouterProvider` is the sole `GoRouter` creation point (verified)
  /// - Navigation reachability tests pass (task 13.5)
  ///
  /// **Replaced by:** `lib/features/mobile_shop/navigation/` route bindings
  /// integrated through `appRouterProvider` GoRouter composition.
  ///
  /// **AF reference:** AF-04 (obsolete parallel-router/module architecture)
  static const mobileShopModule =
      'MobileShopModule (GoRouter routes/navItems) — ALREADY REMOVED';

  // ===========================================================================
  // AF-35: Dead business-type string branch in billing_service
  // ===========================================================================

  /// **What:** A conditional branch in `billing_service.dart` that gates
  /// mobile-shop IMEI validation logic using `BusinessType.mobileShop.name`
  /// (which evaluates to `"mobileShop"` per Dart enum semantics).
  ///
  /// **Location:**
  /// - `lib/features/billing/services/billing_service.dart` (~line 197–202)
  /// - Pattern: `businessType == BusinessType.mobileShop.name`
  ///
  /// **Why obsolete:** The original audit found a string comparison using
  /// `"mobile_shop"` (snake_case) that never matched `enum.name` which is
  /// `"mobileShop"` (camelCase). This has since been corrected to use
  /// `BusinessType.mobileShop.name` directly. However, the mobileShop branch
  /// body for within-bill duplicate detection defers to
  /// `manual_item_entry_sheet.dart`'s async check — making the `billing_service`
  /// branch a pass-through/no-op for mobileShop (only electronics executes the
  /// inner duplicate detection block).
  ///
  /// **Replaced by:** `MobileSaleConsistencyOrchestrator` (task 12.3) handles
  /// all mobileShop sale validation, IMEI uniqueness, and consistency through
  /// the authoritative backend path. The billing_service mobileShop entry in
  /// the outer condition can be removed once evidence proves:
  /// 1. All mobileShop bill creation flows route through the orchestrator
  /// 2. No direct `BillingService.createBill()` call bypasses the orchestrator
  ///    for mobileShop tenants
  ///
  /// **Evidence patterns to assert:**
  /// - mobileShop bills are gated by `MobileSaleConsistencyOrchestrator`
  /// - The `billing_service.dart` mobileShop branch body is unreachable for
  ///   mobileShop tenants when the orchestrator is active
  /// - Removal does not affect `electronics` validation (separate inner branch)
  ///
  /// **AF reference:** AF-35 (dead business-type string branch)
  static const billingServiceDeadBranch =
      'billing_service.dart mobileShop string branch (line ~197)';

  // ===========================================================================
  // Orphaned sync handlers (registered via former module system)
  // ===========================================================================

  /// **What:** `MobileShopSyncHandler` and `MobileShopWsHandler` classes that
  /// were registered through the former `MobileShopModule` system.
  ///
  /// **Original location:**
  /// - `lib/modules/mobile_shop/sync/mobile_shop_sync_handler.dart`
  /// - `lib/modules/mobile_shop/websocket/mobile_shop_ws_handler.dart`
  ///
  /// **Why obsolete:** The module registration system is removed. The new
  /// `MobileSyncCoordinator` (task 11.2) at
  /// `lib/features/mobile_shop/` provides tenant-bound, durable, idempotent
  /// synchronization through `appRouterProvider`-integrated paths.
  ///
  /// **Current status:** VERIFIED REMOVED — 2025-07-19
  /// Files confirmed absent from the filesystem (removed with the
  /// `modules/mobile_shop/` directory). No active imports remain.
  ///
  /// **Evidence (task 13.3, 13.5):**
  /// - `find lib/ -name "*mobile_shop_sync_handler*"` → 0 results
  /// - `find lib/ -name "*mobile_shop_ws_handler*"` → 0 results
  /// - `grep -r "MobileShopSyncHandler\|MobileShopWsHandler" lib/` → 0 results
  /// - `MobileSyncCoordinator` is the active sync system (task 11.2)
  ///
  /// **Replaced by:** `MobileSyncCoordinator` at
  /// `lib/features/mobile_shop/sync/` with durable outbox, tenant binding,
  /// and authoritative backend push/pull.
  ///
  /// **AF reference:** AF-04 (part of orphaned module architecture)
  static const orphanedSyncHandlers =
      'MobileShopSyncHandler/WsHandler in module — ALREADY REMOVED';

  // ===========================================================================
  // Legacy route redirects (from orphaned module)
  // ===========================================================================

  /// **What:** `LegacyRouteRedirect` stubs that the module system used to
  /// redirect old paths like `/mobile/emi` to generic screens.
  ///
  /// **Original location:**
  /// - Within `modules/mobile_shop/routes/mobile_shop_routes.dart`
  ///
  /// **Why obsolete:** The `LegacyRoutes` system in
  /// `lib/core/routing/legacy_routes.dart` now handles all legacy path aliases
  /// through `LegacyRoutes.aliasTargetFor()`, which is composed into the
  /// `appRouterProvider` redirect callback. Module-level redirects are
  /// superseded.
  ///
  /// **Current status:** VERIFIED REMOVED — 2025-07-19
  /// Files confirmed absent (removed with module directory). The active
  /// `LegacyRoutes` class handles alias resolution for all business types.
  ///
  /// **Evidence (task 13.3, 13.5):**
  /// - `grep -r "LegacyRouteRedirect" lib/` → 0 results
  /// - `LegacyRoutes.aliasTargetFor` handles all known legacy aliases
  /// - No route registration references `modules/mobile_shop`
  /// - Navigation reachability tests pass (task 13.5)
  ///
  /// **Replaced by:** `LegacyRoutes.aliasTargetFor()` in
  /// `lib/core/routing/legacy_routes.dart`, composed into `appRouterProvider`
  /// redirect callback.
  ///
  /// **AF reference:** AF-04 (orphaned module routes)
  static const legacyRouteRedirects =
      'LegacyRouteRedirect stubs in module — ALREADY REMOVED';

  // ===========================================================================
  // Summary of removal readiness
  // ===========================================================================

  /// VERIFIED REMOVED (filesystem absent, no imports, no traffic):
  /// - [mobileShopModule] — removed 2025-07-19, replaced by route bindings
  /// - [orphanedSyncHandlers] — removed 2025-07-19, replaced by MobileSyncCoordinator
  /// - [legacyRouteRedirects] — removed 2025-07-19, replaced by LegacyRoutes
  ///
  /// PENDING REMOVAL (requires orchestrator integration evidence):
  /// - [billingServiceDeadBranch] — safe to remove after task 12.3 proves
  ///   all mobileShop flows use the consistency orchestrator
  ///
  /// SOLE DEPLOYMENT PATH: `Dukan_x/my-backend` (design.md §Architecture)
  /// NON-AUTHORITATIVE PATHS DOCUMENTATION: See backend module
  ///   `src/modules/mobile-shop/migration/non-authoritative-paths.ts`
  ///
  /// The sole router composition assertion (see [assertSoleRouterComposition])
  /// provides the runtime/test check to prevent regression.
  static const List<String> allEntries = [
    mobileShopModule,
    billingServiceDeadBranch,
    orphanedSyncHandlers,
    legacyRouteRedirects,
  ];
}
