// =============================================================================
// AppRouter — go_router (DukanX navigation)
// =============================================================================
//
// This file owns the application's single `GoRouter` instance and is the SOLE
// navigation path for the app (Task 9.3 — legacy removal). It is consumed by
// the app root (`app.dart`) via `MaterialApp.router(routerConfig: ...)`. The
// former `useGoRouterShell` flag and the legacy `MaterialApp.routes`
// (`buildAppRoutes()`) path have been removed.
//
// Foundation routes (design.md, Component 1):
//   * `/splash`    — the existing animated `SplashScreen` (initial location).
//   * `/login`     — the existing `LoginPage`.
//   * `/auth-gate` — business-type resolution, reusing the existing `AuthGate`
//                    single entry point (auth + onboarding + business type).
//   * `/app`       — the main shell as a `ShellRoute` whose builder renders the
//                    EXISTING shell scaffold + sidebar (`AdaptiveShell`, which
//                    renders the sidebar from `sidebarSectionsProvider`). The
//                    routed child is a placeholder body in Phase 1; per-item
//                    screen routing arrives in Phase 2.
//
// PHASE 2 (Task 3.3) — Named GoRoutes registered under the ShellRoute.
//   This task registers ONE child `GoRoute` per legacy sidebar `itemId`
//   (90 total, from `RoutePaths.knownItemIds`) under the main `ShellRoute`.
//   Each route's builder returns the IDENTICAL screen widget + constructor
//   args the legacy `SidebarNavigationHandler.getScreenForItem` returns.
//
//   DRY / single source of truth: rather than re-transcribing the ~90-case
//   switch (which would inevitably drift), every route builder DELEGATES to
//   `SidebarNavigationHandler.getScreenForItem(itemId, context)`. The legacy
//   switch therefore remains the ONE authority for `itemId -> widget`; the
//   routes simply call it. This keeps legacy behavior byte-identical (the
//   switch is untouched) and guarantees route/screen parity by construction
//   (the Task 3.2 exploration baseline stays green).
//
//   It also wires a theme-aware "Feature Not Found" placeholder (mirroring the
//   legacy switch `default:` `_PlaceholderScreen`) as BOTH the go_router
//   `errorBuilder` (unknown deep links) AND the `RoutePaths.notFound`
//   sentinel route.
//
//   Preserved AS-IS (flagged out-of-scope): the restaurant screens still pass
//   the hardcoded `vendorId: 'SYSTEM'` tenant id — a known multi-tenant defect
//   that is intentionally NOT fixed here (carried forward via the legacy
//   switch verbatim).
//   UPDATE: vendorId is now session-resolved in SidebarNavigationHandler
//   (restaurant-vertical-remediation P0 fix). Route builders delegate to
//   screenForItemId which calls the fixed handler.
//
// What Phase 2 Task 3.3 deliberately does NOT do:
//   * It does NOT change the shell sidebar-tap dispatch (Task 3.4).
//   * It does NOT add the router-level capability `redirect` guard (Phase 3);
//     the `ref` plumbed through `build` is reserved for that guard.
//   * It does NOT rewrite `AdaptiveShell` / `DesktopRootShell` / the sidebar
//     provider, the legacy switch, the flag default, or capability filtering.
//   * It registers routes only — they are consumed only when the flag is ON,
//     which nothing flips yet (zero default behavior change).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/global_keys.dart';
import '../../core/auth/auth_gate.dart';
import '../../core/isolation/business_capability.dart';
import '../../core/isolation/feature_resolver.dart';
import '../../core/responsive/adaptive_shell.dart';
import '../../components/auth/login_page.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/purchase/presentation/screens/scan_bill_image_picker_screen.dart';
import '../../providers/app_state_providers.dart';
import '../../widgets/desktop/sidebar_navigation_handler.dart';
import 'legacy_routes.dart';
import 'route_paths.dart';

/// Owns the application's single [GoRouter] instance — the sole navigation
/// path for the app. Consumed by the app root via `MaterialApp.router`.
abstract final class AppRouter {
  const AppRouter._();

  /// Builds the application [GoRouter] with the Phase 1 foundation routes.
  ///
  /// [ref] is the Riverpod [Ref] of the owning provider. It is plumbed through
  /// for the Phase 3 router-level capability `redirect` guard (which needs to
  /// read the active business type / capability registry); Phase 1 does not yet
  /// consume it for route definitions.
  ///
  /// Prefer obtaining the router via [appRouterProvider] so it is created once
  /// and not rebuilt on every widget rebuild (which would reset navigation).
  static GoRouter build({required Ref ref}) {
    return GoRouter(
      // Attach the shared navigator key so out-of-context navigation utilities
      // resolve to this router's navigator when the flag is ON.
      navigatorKey: globalNavigatorKey,
      initialLocation: RoutePaths.splash,
      // -----------------------------------------------------------------------
      // PHASE 3 (Task 4.3) — router-level capability guard (security fix S3).
      // Runs on EVERY navigation, including direct/deep links, BEFORE any
      // screen is built. It reads the active business type from [ref] and
      // redirects to the theme-aware deny screen when the type is isolated from
      // the capability bound to the target route. See [capabilityRedirect].
      //
      // COMPOSED (Task 2.6, design.md Component 2 / AD-6): the redirect first
      // consults the legacy alias mapping (LegacyRoutes.aliasTargetFor) so old
      // string-driven callers resolve to the canonical foundation paths, then
      // falls through to the existing capability guard unchanged. The alias
      // check is PREPENDED only — `capabilityRedirect` and its arguments are
      // preserved verbatim.
      // -----------------------------------------------------------------------
      redirect: (BuildContext context, GoRouterState state) {
        final String? alias = LegacyRoutes.aliasTargetFor(
          state.matchedLocation,
        );
        if (alias != null) return alias;
        return capabilityRedirect(
          state,
          ref.read(businessTypeProvider).type.name,
        );
      },
      routes: <RouteBase>[
        // ---------------------------------------------------------------------
        // Legacy-compatible top-level routes (Task 2.6, design.md Component 1 /
        // AD-1). Spread in additively from the single source of truth in
        // legacy_routes.dart. `LegacyRoutes.routes()` is currently empty
        // (skeleton), so this is a no-op at runtime until later tasks register
        // the migrated legacy named routes — the wiring is in place here.
        // ---------------------------------------------------------------------
        ...LegacyRoutes.routes(),
        // ---------------------------------------------------------------------
        // Foundation route 1: splash (initial location).
        // ---------------------------------------------------------------------
        GoRoute(
          path: RoutePaths.splash,
          name: RoutePaths.splashName,
          builder: (BuildContext context, GoRouterState state) => SplashScreen(
            // On completion, hand off to the business-type resolution step
            // (the existing AuthGate), mirroring the legacy splash handoff.
            onComplete: () => context.go(RoutePaths.authGate),
          ),
        ),

        // ---------------------------------------------------------------------
        // Foundation route 2: login.
        // ---------------------------------------------------------------------
        GoRoute(
          path: RoutePaths.login,
          name: RoutePaths.loginName,
          builder: (BuildContext context, GoRouterState state) =>
              const LoginPage(),
        ),

        // ---------------------------------------------------------------------
        // Foundation route 3: business-type resolution.
        // Reuses the existing AuthGate single entry point, which resolves
        // authentication, onboarding, and the active business type, then shows
        // the appropriate destination. This is the seam through which login
        // reaches the shell for grocery / pharmacy / default-retail types.
        // ---------------------------------------------------------------------
        GoRoute(
          path: RoutePaths.authGate,
          name: RoutePaths.authGateName,
          builder: (BuildContext context, GoRouterState state) =>
              const AuthGate(),
        ),

        // ---------------------------------------------------------------------
        // Foundation route 4: main shell (ShellRoute).
        // The builder renders the EXISTING shell scaffold + sidebar
        // (AdaptiveShell -> DesktopRootShell, which renders the sidebar from
        // sidebarSectionsProvider). Phase 1 reuses it verbatim; the routed
        // `child` is a placeholder body until Phase 2 registers per-item routes.
        // ---------------------------------------------------------------------
        ShellRoute(
          // Task 3.4: forward go_router's routed `child` into the shell's
          // content area via [shellBuilder]. The shell renders this child in
          // the exact region the legacy `DesktopContentHost` fills, so under
          // the flag a sidebar tap (which calls `context.go(...)`) actually
          // displays the routed screen body. The sidebar/topbar/layout are
          // unchanged.
          builder: shellBuilder,
          routes: _shellChildRoutes(),
        ),
      ],
      // Theme-aware "Feature Not Found" placeholder (mirrors the legacy switch
      // `default:` `_PlaceholderScreen`) so unknown deep links never render a
      // red screen. Task 3.3.
      errorBuilder: (BuildContext context, GoRouterState state) =>
          const _RouteNotFoundScreen(),
    );
  }

  /// Builds the main-shell chrome for the `ShellRoute`, forwarding go_router's
  /// routed [child] into the shell content area (Task 3.4).
  ///
  /// The shell ([AdaptiveShell]) is reused VERBATIM — same sidebar, topbar, and
  /// layout. The only change is that the routed [child] is handed to the shell
  /// so it can render the routed screen body in the same region the
  /// `DesktopContentHost` fills.
  ///
  /// It deliberately ignores [state]: the active-item highlight is derived
  /// inside the shell from the current routed location (so this stays a pure
  /// pass-through that is trivial to unit-test — see
  /// `phase2_sidebar_dispatch_test.dart`).
  @visibleForTesting
  static Widget shellBuilder(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    return AdaptiveShell(routedChild: child);
  }

  /// Resolves a legacy sidebar [itemId] to its in-shell screen widget.
  ///
  /// DELEGATES to [SidebarNavigationHandler.getScreenForItem] so the legacy
  /// switch remains the SINGLE source of truth for `itemId -> widget` (incl.
  /// constructor args like `GstReportsScreen.initialIndex`,
  /// `PartyLedgerListScreen.initialFilter`, and the restaurant screens with
  /// session-resolved `vendorId`). Every per-item route
  /// builder calls this, guaranteeing route/screen parity by construction.
  ///
  /// Exposed for the Task 3.3 route-registration parity test.
  @visibleForTesting
  static Widget screenForItemId(String itemId, BuildContext context) =>
      SidebarNavigationHandler.getScreenForItem(itemId, context);

  /// Builds the OCR scan-bill screen for [verticalType] (Phase 5, Task 6.2).
  ///
  /// REUSES the existing AWS Textract "Smart Inventory Import" pipeline by
  /// returning its entry screen, [ScanBillImagePickerScreen] — it does NOT
  /// build any new OCR. [verticalType] is the active business type name (e.g.
  /// `grocery`), which the pipeline uses to scope the scan-bill session.
  ///
  /// Exposed for the Task 6.2 route-registration test (constructing the widget
  /// runs no `createState()`/IO, so it is a pure, deterministic seam).
  @visibleForTesting
  static Widget buildScanBillScreen(String verticalType) =>
      ScanBillImagePickerScreen(verticalType: verticalType);

  // ===========================================================================
  // PHASE 3 (Task 4.3) — Capability route guard (security fix S3).
  //
  // Closes the audit's S3 "route-guard bypass": today capability isolation
  // lives ONLY in the sidebar MENU-FILTERING layer (`sidebarSectionsProvider`),
  // so a direct/deep-link navigation reaches the real screen with no check.
  // The guard below re-applies the SAME isolation authority
  // (`FeatureResolver` / `businessCapabilityRegistry`) at the router boundary,
  // so navigation itself is enforced — hidden-menu and deep-link paths alike.
  //
  // This is purely additive: it does NOT touch `sidebar_configuration.dart`'s
  // menu filtering or the shared `getScreenForItem` resolver. It only affects
  // routing enforcement on the go_router path.
  // ===========================================================================

  /// Route (`itemId`) -> required [BusinessCapability] binding.
  ///
  /// `null` (absence from this map) == the route has NO capability gate.
  ///
  /// MIRRORED bindings — transcribed 1:1 from the `capability:` fields that
  /// `sidebar_configuration.dart` already uses for menu filtering, so the guard
  /// matches the menu-filtering bindings exactly:
  ///   * `scan_qr`           -> usePatientRegistry  (sidebar "Scan Patient QR")
  ///   * `prescriptions`     -> usePrescription
  ///   * `medicine_master`   -> usePrescription
  ///   * `batch_tracking`    -> useBatchExpiry
  ///   * `restaurant_tables` -> useTableManagement
  ///
  /// NEW bindings (Task 4.3 / Req 6.4) — the previously-UNGATED grocery items
  /// that had no `capability:` field in the sidebar and so were never gated at
  /// all. These close the S3 bypass for grocery (and any type lacking them):
  ///   * `return_inwards`    -> useSalesReturn
  ///   * `proforma_bids`     -> useProformaInvoice
  ///   * `dispatch_notes`    -> useDispatchNote
  ///   * `booking_orders`    -> useDispatchNote   (Task 4.1 business decision)
  ///   * `stock_reversal`    -> useStockReversal
  ///   * `purchase_register` -> usePurchaseRegister
  static const Map<String, BusinessCapability>
  _routeCapabilityBindings = <String, BusinessCapability>{
    // --- Mirrored from sidebar_configuration.dart `capability:` fields ---
    'scan_qr': BusinessCapability.usePatientRegistry,
    'prescriptions': BusinessCapability.usePrescription,
    'medicine_master': BusinessCapability.usePrescription,
    'batch_tracking': BusinessCapability.useBatchExpiry,
    'restaurant_tables': BusinessCapability.useTableManagement,
    // --- New bindings for the previously-ungated grocery items (Req 6.4) ---
    'return_inwards': BusinessCapability.useSalesReturn,
    'proforma_bids': BusinessCapability.useProformaInvoice,
    'dispatch_notes': BusinessCapability.useDispatchNote,
    'booking_orders': BusinessCapability.useDispatchNote, // Task 4.1 decision
    'stock_reversal': BusinessCapability.useStockReversal,
    'purchase_register': BusinessCapability.usePurchaseRegister,
    // --- New post-legacy route (Phase 5, Task 6.2) ---
    // The OCR scan-bill route reuses the existing AWS Textract pipeline and is
    // gated by useScanOCR, so grocery (granted useScanOCR) is allowed and types
    // without it are denied at the router boundary. `scan_bill` is NOT a legacy
    // dispatch itemId, so it is absent from `RoutePaths.knownItemIds`; the
    // guard still gates it because `_itemIdForState` resolves new routes via
    // `RoutePaths.isNavItemId` / `navItemIdForPath`.
    'scan_bill': BusinessCapability.useScanOCR,
  };

  /// Returns the [BusinessCapability] bound to [routeNameOrItemId], or `null`
  /// if the route has no capability gate.
  ///
  /// Per-item GoRoutes are registered with `name == itemId`
  /// (see [_shellChildRoutes]), so this accepts either the route name or the
  /// legacy sidebar `itemId` interchangeably. Pure / total — unit-testable.
  static BusinessCapability? requiredCapabilityFor(String routeNameOrItemId) =>
      _routeCapabilityBindings[routeNameOrItemId];

  /// Resolves the legacy sidebar `itemId` for a navigation [state], or `null`
  /// for foundation/sentinel routes (splash, login, auth-gate, `/app` base,
  /// not-found, denied) that carry no itemId.
  ///
  /// Prefers the route `name` (which equals the `itemId` for per-item routes),
  /// then falls back to a path lookup so direct/deep-link navigation by URL
  /// (where the name may be absent) still resolves correctly.
  static String? _itemIdForState(GoRouterState state) {
    final String? name = state.name;
    if (name != null && RoutePaths.isNavItemId(name)) {
      return name;
    }
    return RoutePaths.navItemIdForPath(state.matchedLocation) ??
        RoutePaths.navItemIdForPath(state.uri.path);
  }

  /// Router-level capability guard (Phase 3, Task 4.3).
  ///
  /// Evaluates [activeBusinessType] against the capability bound to the route
  /// targeted by [state] and returns:
  ///   * [RoutePaths.denied] when a capability is required AND the type lacks
  ///     it (access denied — never leak the protected screen), or
  ///   * `null` (allow) when the route is ungated or the type has the
  ///     capability.
  ///
  /// Enforcement runs on EVERY navigation (the GoRouter `redirect`), including
  /// direct and deep-link navigation — not merely sidebar-menu visibility.
  ///
  /// The decision honors [FeatureResolver.enforceAccess]/[SecurityException]
  /// semantics at the boundary: it calls `enforceAccess` and converts a thrown
  /// [SecurityException] into the deny redirect, so the SAME isolation
  /// authority that protects the repository layer governs navigation.
  ///
  /// Pure (given [activeBusinessType]) — unit-testable without pumping widgets.
  static String? capabilityRedirect(
    GoRouterState state,
    String activeBusinessType,
  ) {
    return redirectDecision(_itemIdForState(state), activeBusinessType);
  }

  /// Pure allow/deny decision for a resolved [itemId] (or `null` for
  /// foundation/sentinel routes) under [activeBusinessType].
  ///
  /// Returns [RoutePaths.denied] when the route is gated and the type lacks the
  /// capability; `null` (allow) otherwise. Extracted from [capabilityRedirect]
  /// so the security-critical decision is unit-testable without constructing a
  /// [GoRouterState] or pumping (heavy) screens.
  @visibleForTesting
  static String? redirectDecision(String? itemId, String activeBusinessType) {
    if (itemId == null) {
      // Foundation / sentinel route — no capability gate.
      return null;
    }
    final BusinessCapability? cap = requiredCapabilityFor(itemId);
    if (cap == null) {
      // Ungated route — allow.
      return null;
    }
    try {
      // Honor enforceAccess/SecurityException semantics at the router boundary.
      FeatureResolver.enforceAccess(activeBusinessType, cap);
      return null; // allowed
    } on SecurityException {
      // Denied — redirect to the theme-aware deny screen; never render/leak the
      // protected screen. The deny route carries no binding, so no loop.
      return RoutePaths.denied;
    }
  }

  /// Builds the child routes registered under the main [ShellRoute].
  ///
  /// In addition to the Phase 1 shell-base placeholder, this registers:
  ///   * the [RoutePaths.notFound] sentinel route -> theme-aware placeholder,
  ///     so [RoutePaths.pathForItemId] of an unknown id resolves to the same
  ///     "Feature Not Found" screen the legacy switch `default:` shows; and
  ///   * one named [GoRoute] per legacy sidebar `itemId`
  ///     ([RoutePaths.knownItemIds], 90 total), each delegating to
  ///     [screenForItemId] for byte-identical screen+args parity.
  static List<RouteBase> _shellChildRoutes() {
    return <RouteBase>[
      // Phase 1 shell-base placeholder body route.
      GoRoute(
        path: RoutePaths.shell,
        name: RoutePaths.shellName,
        builder: (BuildContext context, GoRouterState state) =>
            const _ShellPlaceholderBody(),
      ),

      // Unknown / not-found sentinel route (Task 3.3). Mirrors the legacy
      // switch `default:` `_PlaceholderScreen` so `pathForItemId` of an unknown
      // itemId resolves to the same theme-aware "Feature Not Found" screen.
      GoRoute(
        path: RoutePaths.notFound,
        name: RoutePaths.notFoundName,
        builder: (BuildContext context, GoRouterState state) =>
            const _RouteNotFoundScreen(),
      ),

      // Capability-denied screen (Task 4.3). The router guard
      // ([capabilityRedirect]) redirects here when the active business type is
      // isolated from the capability bound to the requested route. It carries
      // NO capability binding, so the guard always allows it (no redirect
      // loop). Rendered inside the shell so the sidebar stays available.
      GoRoute(
        path: RoutePaths.denied,
        name: RoutePaths.deniedName,
        builder: (BuildContext context, GoRouterState state) =>
            const _AccessDeniedScreen(),
      ),

      // OCR "Scan Bill / Purchase Entry" route (Phase 5, Task 6.2). REUSES the
      // existing AWS Textract "Smart Inventory Import" pipeline by rendering its
      // entry screen (ScanBillImagePickerScreen) — NO new OCR is built. This is
      // a NEW post-legacy route (not a `getScreenForItem` case), so it is NOT
      // part of `RoutePaths.knownItemIds`; it is registered explicitly here.
      // The router capability guard gates it via the `scan_bill -> useScanOCR`
      // binding, so grocery (granted useScanOCR) is allowed and types without
      // it are redirected to the deny screen.
      GoRoute(
        path: RoutePaths.scanBill,
        name: RoutePaths.scanBillName,
        builder: (BuildContext context, GoRouterState state) => Consumer(
          // The pipeline entry screen needs the active business type as its
          // `verticalType`; read it from the single source of truth, exactly
          // as the capability guard does (`businessTypeProvider.type.name`).
          builder: (BuildContext context, WidgetRef ref, _) =>
              buildScanBillScreen(ref.watch(businessTypeProvider).type.name),
        ),
      ),

      // =====================================================================
      // MANDI (vegetablesBroker) — Phase 4, Task 18.2
      // Real Mandi routes replacing former LegacyRouteRedirect stubs. Each
      // opens its corresponding Phase 3 screen with no legacy redirect.
      // On builder failure the user stays on the current screen and sees a
      // navigation-failed error (Req 12.2, 12.5).
      // =====================================================================
      for (final String mandiItemId in RoutePaths.mandiItemIds)
        GoRoute(
          path: RoutePaths.navPathForItemId(mandiItemId),
          name: mandiItemId,
          builder: (BuildContext context, GoRouterState state) =>
              _buildMandiScreen(mandiItemId, context),
        ),

      // One route per legacy sidebar itemId (Task 3.3). The builder returns the
      // IDENTICAL screen + args the legacy switch returns via [screenForItemId]
      // (single source of truth). The route `name` is the stable `itemId`.
      for (final String itemId in RoutePaths.knownItemIds)
        GoRoute(
          path: RoutePaths.pathForItemId(itemId),
          name: itemId,
          builder: (BuildContext context, GoRouterState state) =>
              screenForItemId(itemId, context),
        ),
    ];
  }

  /// Builds a Mandi screen for [itemId], with navigation-failure error
  /// handling (Req 12.5). If the screen cannot be resolved, returns an
  /// in-place error indicator and shows a snackbar — no legacy redirect.
  static Widget _buildMandiScreen(String itemId, BuildContext context) {
    final Widget? screen = SidebarNavigationHandler.tryGetScreenForItem(
      itemId,
      context,
    );
    if (screen != null) return screen;

    // Navigation failed — show snackbar error (Req 12.5).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Navigation failed: could not open the requested screen',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    // Return an empty container so the shell stays rendered (user stays on
    // current visual) — the not-found screen is avoided (no legacy redirect).
    return const SizedBox.shrink();
  }
}

/// Provides the application's single [GoRouter], created once.
///
/// Using a [Provider] memoizes the router so it is NOT rebuilt on every app
/// rebuild (rebuilding would reset navigation state). The provider's [Ref] is
/// a real provider ref that the Phase 3 capability guard can use to read the
/// active business type / capability registry.
///
/// The app root reads this to drive `MaterialApp.router`; it is the app's sole
/// navigation source.
final appRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.build(ref: ref);
});

/// Placeholder body for the Phase 1 shell child route.
///
/// Not normally visible (the shell hosts its own content); it exists so the
/// `ShellRoute` has a valid child destination at `/app` during Phase 1.
class _ShellPlaceholderBody extends StatelessWidget {
  const _ShellPlaceholderBody();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Theme-aware "Feature Not Found" placeholder for unknown routes (Task 3.3).
///
/// Mirrors the legacy `SidebarNavigationHandler` switch `default:`
/// `_PlaceholderScreen` (same theme-aware visual + the "Feature Not Found"
/// badge), wrapped in a [Scaffold] because — unlike the in-shell legacy
/// placeholder — this renders at the router boundary (errorBuilder /
/// `RoutePaths.notFound`) where no surrounding shell scaffold exists.
class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.help_outline,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unknown Screen',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Feature Not Found',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'This screen could not be located. Please select from the sidebar.',
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Theme-aware capability "deny" screen (Phase 3, Task 4.3).
///
/// Shown when the router guard ([AppRouter.capabilityRedirect]) blocks a
/// navigation because the active business type is isolated from the capability
/// bound to the requested route (security fix S3). It deliberately does NOT
/// crash and is NOT blank: it explains the screen is unavailable for this
/// business type and offers a clear way back to a permitted area (the shell /
/// dashboard, reachable via the sidebar).
///
/// This is registered as a child of the main `ShellRoute`, so the surrounding
/// shell scaffold + sidebar remain visible; this widget only fills the content
/// area. It is wrapped in a [Material] so it renders correctly even if pumped
/// without a surrounding [Scaffold] (e.g. in a focused widget test).
class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.error.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.lock_outline,
                size: 36,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Not Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.error.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Restricted for your business type',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This feature is not available for your business type. '
                'Choose another option from the sidebar to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.hintColor.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Way back to a permitted area: the shell base (always ungated),
            // which restores the dashboard/sidebar so the user is never stuck.
            FilledButton.icon(
              onPressed: () => context.go(RoutePaths.shell),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
