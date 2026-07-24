/// Asserts that `MaterialApp.router` / `appRouterProvider` is the sole
/// navigation composition and no parallel module routes are mounted.
///
/// Use in tests (task 13.5) to prevent regression of the sole-router
/// composition invariant established by tasks 13.1–13.3.
///
/// Requirements: 1.4, 2.8, 6.22; GR-1.2
/// Audit: AF-04
library;

/// Patterns that MUST be absent from the active codebase to confirm the
/// sole-router composition. Used by reachability tests (task 13.5).
abstract class SoleRouterPatterns {
  const SoleRouterPatterns._();

  // ===========================================================================
  // Positive evidence: patterns that MUST exist
  // ===========================================================================

  /// The app entry point file that declares the sole router composition.
  /// Expected: `lib/app/app.dart`
  static const appEntryFile = 'lib/app/app.dart';

  /// The router provider file that creates the sole GoRouter instance.
  /// Expected: `lib/core/routing/app_router.dart`
  static const routerProviderFile = 'lib/core/routing/app_router.dart';

  /// The provider symbol name that is the single source of GoRouter.
  /// Expected: `appRouterProvider`
  static const routerProviderName = 'appRouterProvider';

  /// The pattern proving MaterialApp uses routerConfig (not routes map).
  /// Expected match in app.dart: `routerConfig: router`
  static const routerConfigPattern = r'routerConfig:\s*\w+';

  /// The dedicated mobile navigation barrel file.
  /// Expected: `lib/features/mobile_shop/navigation/mobile_shop_navigation.dart`
  static const mobileNavigationBarrel =
      'lib/features/mobile_shop/navigation/mobile_shop_navigation.dart';

  /// The route bindings file that integrates mobile routes into GoRouter.
  /// Expected: `lib/features/mobile_shop/navigation/mobile_shop_route_bindings.dart`
  static const mobileRouteBindings =
      'lib/features/mobile_shop/navigation/mobile_shop_route_bindings.dart';

  // ===========================================================================
  // Negative evidence: patterns that MUST be absent
  // ===========================================================================

  /// The obsolete module directory path — must not exist.
  static const obsoleteModulePath = 'lib/modules/mobile_shop';

  /// Import pattern for the obsolete module — must have zero matches.
  static const obsoleteModuleImport = r'import.*modules/mobile_shop';

  /// The obsolete module class name — must not be defined or referenced.
  static const obsoleteModuleClass = 'MobileShopModule';

  /// Legacy `MaterialApp(routes:` pattern that would indicate the old
  /// string-keyed route map is still in use — must be absent from app.dart.
  static const legacyRoutesMapPattern = r'MaterialApp\(\s*routes:';

  /// Pattern for `buildAppRoutes()` which was the old route-map builder.
  static const legacyRouteBuilder = 'buildAppRoutes';

  /// The obsolete sync handler that was part of the module system.
  static const obsoleteSyncHandler = 'MobileShopSyncHandler';

  /// The obsolete WebSocket handler from the module system.
  static const obsoleteWsHandler = 'MobileShopWsHandler';
}

/// Runtime/test assertion that the sole router composition invariant holds.
///
/// This function documents what patterns to check in tests. It is structured
/// for use by task 13.5's reachability test suite, which will:
///
/// 1. Verify `app.dart` uses `MaterialApp.router` (not `MaterialApp.routes`
///    or raw `Navigator`)
/// 2. Verify `appRouterProvider` is the single `GoRouter` creation point
/// 3. Verify no `MobileShopModule` routes are registered or importable
/// 4. Verify the dedicated mobile navigation system at
///    `features/mobile_shop/navigation/` is the sole mobile route source
/// 5. Verify no `LegacyRouteRedirect` class exists (alias resolution uses
///    `LegacyRoutes.aliasTargetFor` in the composed redirect)
///
/// The function itself is a documentation marker. The actual assertions are
/// implemented as test expectations in task 13.5.
void assertSoleRouterComposition() {
  // -------------------------------------------------------------------------
  // CHECK 1: App entry point uses MaterialApp.router
  // -------------------------------------------------------------------------
  // Verify: app.dart contains `routerConfig:` and does NOT contain
  // `MaterialApp(routes:` or `Navigator(` as the primary nav composition.
  //
  // Evidence source: lib/app/app.dart line 204:
  //   routerConfig: router,
  // where `router` comes from `ref.watch(appRouterProvider)`.
  //
  // Pattern match:
  //   PRESENT:  RegExp(r'routerConfig:\s*\w+') matches in app.dart
  //   ABSENT:   RegExp(r'MaterialApp\(\s*routes:') has no match in app.dart

  // -------------------------------------------------------------------------
  // CHECK 2: appRouterProvider is the single source of route configuration
  // -------------------------------------------------------------------------
  // Verify: Only one `Provider<GoRouter>` exists in the app (appRouterProvider
  // at lib/core/routing/app_router.dart:508).
  //
  // Pattern match:
  //   UNIQUE:  `Provider<GoRouter>` appears exactly once across lib/
  //   PRESENT: `appRouterProvider` definition in app_router.dart

  // -------------------------------------------------------------------------
  // CHECK 3: No MobileShopModule routes registered in the active router
  // -------------------------------------------------------------------------
  // Verify: The `modules/mobile_shop/` directory does not exist, no file
  // imports `MobileShopModule`, and no GoRouter route list references module
  // routes.
  //
  // Pattern match:
  //   ABSENT:  Directory `lib/modules/mobile_shop/` does not exist
  //   ABSENT:  grep for `MobileShopModule` yields zero results in lib/
  //   ABSENT:  grep for `mobileShopRoutes` yields zero results in lib/

  // -------------------------------------------------------------------------
  // CHECK 4: Dedicated mobile navigation is the sole mobile route source
  // -------------------------------------------------------------------------
  // Verify: Mobile routes flow through the dedicated navigation system at
  // `lib/features/mobile_shop/navigation/` which integrates into the
  // single GoRouter via route bindings.
  //
  // Pattern match:
  //   PRESENT: mobile_shop_route_bindings.dart exists
  //   PRESENT: mobile_shop_route_catalog.dart exists
  //   PRESENT: mobile_shop_sidebar_builder.dart exists
  //   PRESENT: mobile_shop_navigation.dart barrel exports all of above

  // -------------------------------------------------------------------------
  // CHECK 5: No parallel navigation system for mobileShop exists
  // -------------------------------------------------------------------------
  // Verify: No competing route registration, handler, or redirect targets
  // mobile_shop outside the dedicated navigation directory.
  //
  // Pattern match:
  //   ABSENT:  `MobileShopSyncHandler` class definition
  //   ABSENT:  `MobileShopWsHandler` class definition
  //   ABSENT:  `LegacyRouteRedirect` class definition
  //   ABSENT:  Any `GoRoute` outside navigation/ that targets mobile_shop paths
}
