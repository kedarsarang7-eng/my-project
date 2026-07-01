// ============================================================================
// PHASE C — Task 6.4: PRESERVATION TEST for argument routes
// Feature: imperative-navigation-gorouter-migration
// **Validates: Requirements 10.2, 10.3**
// ============================================================================
//
// WHAT THIS PROVES (and WHY it must PASS against the CHANGED code):
//
//   This is the inverse of the Task 6.1 EXPLORATION test
//   (`phase_c_arg_fallback_exploration_test.dart`). That test pinned the GAP:
//   BEFORE Phase C registration, the 13 argument-bearing legacy routes were NOT
//   registered under the live `AppRouter` (their GoRoute was deferred from
//   Phase B), so navigating to them fell through to the not-found screen — while
//   the LEGACY builders in `lib/app/routes.dart` already carried the defensive
//   `is`-type-check + safe fallback contract.
//
//   Phase C Task 6.2 then registered one arg-bearing `GoRoute` per legacy
//   string in `LegacyRoutes.routes()`, lifting each builder body
//   CHARACTER-FOR-CHARACTER from `buildAppRoutes()` and swapping ONLY the
//   arguments-read (`ModalRoute.of(context)?.settings.arguments` ->
//   `GoRouterState.extra`). This preservation test proves the GAP is now CLOSED:
//   each arg route resolves under the live `AppRouter` via `state.extra` with
//   the SAME defensive fallbacks the legacy builders had — no crash on `null` or
//   wrong-typed `extra` (Req 5.3 / 5.4 emphasis), and the fallback text is
//   IDENTICAL to the legacy behavior captured in 6.1.
//
// THE 13 ARGUMENT ROUTES (registered in Task 6.2; INVENTORY.md §2):
//
//   /clinic/consultation, /clinic/history, /clinic/labs, /clothing/variants,
//   /advanced_bill_creation, /invoice_preview, /hardware/operations,
//   /customer_portal, /customer_report, /customer_app, /notifications,
//   /cloud_sync_settings, /editable_invoice
//
// TWO COMPLEMENTARY ASSERTION LAYERS:
//
//   (1) CONFIG-LEVEL (deterministic, all 13 arg routes): the LIVE
//       `appRouterProvider` configuration now registers a top-level `GoRoute`
//       whose `path` equals each arg-route string, and
//       `LegacyRoutes.isKnownLegacyPath` reports `true` for each (parity by
//       construction). This is the direct inverse of the 6.1 config-level
//       assertion that pinned each as ABSENT.
//
//   (2) WIDGET-LEVEL (faithful harness, representative subset): a minimal
//       `MaterialApp.router` registering the ACTUAL `LegacyRoutes.routes()` and
//       driving `context.push('<path>', extra: <value>)` — the exact go_router
//       equivalent of the legacy `Navigator.pushNamed('<path>', arguments: ...)`
//       call site Phase C fixed. Two routes are pumped, chosen because their
//       fallback renders deterministically:
//
//         * /customer_portal (guard-free fallback):
//             - VALID (non-empty String) extra -> CustomerRoleGuard(child:
//               CustomerDashboardScreen). Pumped with a RESOLVING session so the
//               guard short-circuits to its "Verifying access..." gate (proving
//               the guard-wrapped builder resolved, NOT the not-found screen)
//               without constructing the heavy CustomerDashboardScreen.
//             - null extra        -> plain "Invalid customer portal access.
//               Please login again." Scaffold (NO crash).
//             - wrong-typed (int) -> same plain fallback Scaffold (NO crash).
//           This mirrors/inverts the 6.1 exploration approach exactly.
//
//         * /invoice_preview (VendorRoleGuard-wrapped fallback):
//             A valid EditableInvoice is heavy to construct/pump, so per the
//             task's "assert the null/wrong-typed fallback only" guidance, this
//             route is pumped ONLY for the fallback branch. Pumped as an
//             authenticated owner (so the lifted VendorRoleGuard(viewReports)
//             passes through to its child):
//             - null extra        -> "No invoice data provided for preview"
//               Scaffold renders (NO crash).
//             - wrong-typed (int) -> same fallback Scaffold (NO crash).
//
//       The remaining 11 arg routes (whose target screens are heavy to pump or
//       whose fallback constructs a real screen with defaults) are asserted at
//       the CONFIG/builder level — the route resolves rather than hitting
//       not-found — per design's "assert at the config/builder level" rule.
//
//   (Req 10.3) NON-REGRESSION (light): the foundation + `/app` shell routes
//       remain registered ALONGSIDE the arg routes, and the arg-route slice is
//       identical across In_Scope_Business_Types (legacy/arg routes are not
//       capability-bound at the router level, so other business types are
//       unaffected).
//
// DETERMINISM (mirrors the established harness rationale in
// `phase_b_guarded_resolution_preservation_test.dart` /
// `phase_c_arg_fallback_exploration_test.dart`):
//   The live router's `initialLocation` is `/splash`, whose `SplashScreen` runs
//   a repeating animation + audio/GetIt init that never settles, so we do NOT
//   pump the heavy `/splash` entry. The widget-level layer pumps a MINIMAL
//   `MaterialApp.router` that reuses the EXACT production pieces that matter: the
//   real `LegacyRoutes.routes()` table and the real production not-found builder
//   (lifted from the live router) as the errorBuilder, so a resolved fallback
//   render is provably distinct from the not-found fallback.
//
// TEST-ONLY: no production/application code is changed by this task.
//
// Run: flutter test \
//   test/core/routing/phase_c_arg_routes_preservation_test.dart \
//   --reporter expanded
// ============================================================================

import 'package:dukanx/core/auth/auth_loading_screen.dart';
import 'package:dukanx/core/auth/role_guard.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

/// The 13 argument-bearing legacy routes registered by Task 6.2 (INVENTORY §2).
/// This preservation test proves each now resolves to its arg-aware,
/// `state.extra`-reading builder under the live AppRouter — the direct inverse
/// of the 6.1 exploration test which pinned each as UNREGISTERED.
const List<String> kArgRoutePaths = <String>[
  '/clinic/consultation',
  '/clinic/history',
  '/clinic/labs',
  '/clothing/variants',
  '/advanced_bill_creation',
  '/invoice_preview',
  '/hardware/operations',
  '/customer_portal',
  '/customer_report',
  '/customer_app',
  '/notifications',
  '/cloud_sync_settings',
  '/editable_invoice',
];

/// The guard-free arg route whose safe fallback is a plain, deterministic
/// `Scaffold` — mirrors the 6.1 exploration subject.
const String kCustomerPortalPath = '/customer_portal';
const String kCustomerPortalFallbackText =
    'Invalid customer portal access. Please login again.';

/// The VendorRoleGuard-wrapped arg route whose fallback Scaffold renders
/// deterministically once the guard passes through (authenticated owner).
const String kInvoicePreviewPath = '/invoice_preview';
const String kInvoicePreviewFallbackText =
    'No invoice data provided for preview';

/// Lightweight ungated home for the widget-level harness whose button issues the
/// imperative go_router push (with `extra`) under test.
const String kHarnessHomePath = '/harness-home';
const String kHarnessHomeMarker = 'HARNESS_HOME';

/// Recursively collects every [GoRoute] in a route tree (descending through
/// [ShellRoute]s and nested routes). Mirrors the established routing-test helper
/// so the assertion tracks the live configuration exactly.
Iterable<GoRoute> _allGoRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
      yield* _allGoRoutes(route.routes);
    } else if (route is ShellRouteBase) {
      yield* _allGoRoutes(route.routes);
    } else {
      yield* _allGoRoutes(route.routes);
    }
  }
}

/// Whether the route tree contains a top-level [ShellRoute] (the `/app` shell).
bool _hasShellRoute(List<RouteBase> routes) {
  for (final route in routes) {
    if (route is ShellRoute) return true;
  }
  return false;
}

/// Finds the [GoRoute] registered for [path] anywhere in the router
/// configuration and returns its builder, so the harness can render the REAL
/// production not-found screen (not a stand-in).
GoRouterWidgetBuilder? _findBuilderForPath(
  List<RouteBase> routes,
  String path,
) {
  for (final route in routes) {
    if (route is GoRoute) {
      if (route.path == path) return route.builder;
      final nested = _findBuilderForPath(route.routes, path);
      if (nested != null) return nested;
    } else if (route is ShellRouteBase) {
      final nested = _findBuilderForPath(route.routes, path);
      if (nested != null) return nested;
    }
  }
  return null;
}

/// Lifts the REAL production not-found builder from the live router so the
/// harness errorBuilder renders the actual not-found screen (whose body shows
/// "Unknown Screen" / "Feature Not Found"). A resolved fallback render is then
/// provably distinct from this not-found fallback.
GoRouterWidgetBuilder _liveNotFoundBuilder() {
  final container = ProviderContainer();
  final router = container.read(appRouterProvider);
  final builder = _findBuilderForPath(
    router.configuration.routes,
    RoutePaths.notFound,
  );
  router.dispose();
  container.dispose();
  if (builder == null) {
    throw StateError(
      'The live router must register the not-found route '
      '(${RoutePaths.notFound}) whose builder renders the production '
      '"Feature Not Found" screen.',
    );
  }
  return builder;
}

/// Builds a minimal harness `GoRouter` that registers the ACTUAL
/// `LegacyRoutes.routes()` plus an ungated home whose button pushes [pushPath]
/// WITH [extra] (the go_router equivalent of the legacy
/// `Navigator.pushNamed(pushPath, arguments: extra)`).
///
/// The top-level redirect consults the SAME production `aliasTargetFor` single
/// source of truth; it deliberately does NOT add the router-level capability
/// guard — arg routes are protected by their WIDGET guards, not the router.
GoRouter _harnessPushingExtra(
  String pushPath,
  Object? extra,
  GoRouterWidgetBuilder notFound,
) {
  return GoRouter(
    initialLocation: kHarnessHomePath,
    redirect: (BuildContext context, GoRouterState state) =>
        LegacyRoutes.aliasTargetFor(state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(
        path: kHarnessHomePath,
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push(pushPath, extra: extra),
              child: const Text(kHarnessHomeMarker),
            ),
          ),
        ),
      ),
      // The REAL migrated arg-aware legacy routes (single source of truth).
      ...LegacyRoutes.routes(),
    ],
    errorBuilder: notFound,
  );
}

/// A lightweight fake [SessionManager] whose auth-state getters are fixed via
/// the constructor (mirrors the helper in the Phase B preservation test).
/// [SessionManager] is a [ChangeNotifier], so the guards' `ListenableBuilder`
/// can listen to it; `Mock` provides the inherited listener no-ops, while the
/// boolean getters the guards read are overridden with real backing values.
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager({
    this.isLoading = false,
    this.isInitialized = true,
    this.isAuthenticated = true,
    this.isOwner = true,
    this.isCustomerOnlyMode = false,
  });

  /// Session still resolving -> guards show the "Verifying access..." gate
  /// (build no child screen, schedule no redirect). Used for the VALID
  /// /customer_portal push so the CustomerRoleGuard short-circuits before it
  /// reads `isCustomer` and before the heavy CustomerDashboardScreen is built.
  factory FakeSessionManager.resolving() =>
      FakeSessionManager(isLoading: true, isInitialized: false);

  /// Authenticated owner -> VendorRoleGuard passes through to its child (used
  /// for the /invoice_preview fallback so its child Scaffold renders).
  factory FakeSessionManager.authenticatedOwner() => FakeSessionManager();

  @override
  final bool isLoading;
  @override
  final bool isInitialized;
  @override
  final bool isAuthenticated;
  @override
  final bool isOwner;
  @override
  final bool isCustomerOnlyMode;
}

/// A [BusinessTypeNotifier] pinned to a fixed type, used to override
/// [businessTypeProvider] without touching SharedPreferences.
class _FixedBusinessTypeNotifier extends BusinessTypeNotifier {
  _FixedBusinessTypeNotifier(this._fixed);
  final BusinessType _fixed;

  @override
  BusinessTypeState build() => BusinessTypeState(type: _fixed);
}

void main() {
  // GoRouter construction needs an initialized binding (it wires up route
  // information providers). Plain `test()` bodies don't auto-initialize it.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: imperative-navigation-gorouter-migration — Phase C '
      'PRESERVATION: argument routes NOW resolve via GoRouterState.extra with '
      'identical defensive fallbacks and no crash (Req 10.2, 10.3)', () {
    // ======================================================================
    // (1) CONFIG-LEVEL — every arg route is now a registered top-level
    //     GoRoute under the live AppRouter, and a known legacy path
    //     (inverse of the 6.1 exploration "ABSENT" assertion).
    // ======================================================================
    test('the live AppRouter now registers a GoRoute for EVERY argument route, '
        'and isKnownLegacyPath is true for each (Req 10.2 — gap closed)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);

      final registered = _allGoRoutes(router.configuration.routes).toList();
      final paths = registered.map((r) => r.path).toSet();

      // Foundation sanity: the go_router-only root still exposes /splash + /app.
      expect(paths, contains(RoutePaths.splash));
      expect(paths, contains(RoutePaths.shell));

      for (final argPath in kArgRoutePaths) {
        // The arg route resolves to a REGISTERED top-level GoRoute whose path
        // equals the legacy string (Req 3.1 / 2.6) — no longer not-found.
        expect(
          paths,
          contains(argPath),
          reason:
              '"$argPath" must now be a registered GoRoute path under the live '
              'AppRouter (Phase C Task 6.2 registration). It was pinned ABSENT '
              'by the 6.1 exploration test.',
        );
        // Parity: the known-path set claims it too (Req 3.4 / 3.5).
        expect(
          LegacyRoutes.isKnownLegacyPath(argPath),
          isTrue,
          reason:
              'LegacyRoutes.isKnownLegacyPath("$argPath") must be true now that '
              'its arg-aware GoRoute is registered.',
        );
        // Defensive: it is still NOT an AD-6 alias (arg routes resolve directly,
        // they are never redirect-rescued).
        expect(
          LegacyRoutes.aliasTargetFor(argPath),
          isNull,
          reason:
              '"$argPath" is an argument-bearing route, not an alias — the '
              'composed redirect must not rewrite it.',
        );
      }
    });

    // ======================================================================
    // (Req 10.3) NON-REGRESSION (light) — foundation + /app shell routes
    //     remain registered ALONGSIDE the arg routes, and the arg-route slice
    //     is identical across business types (other business types unaffected).
    // ======================================================================
    test('the foundation + /app shell routes remain registered alongside the '
        'arg routes, identically across business types (Req 10.3)', () {
      const List<BusinessType> types = <BusinessType>[
        BusinessType.grocery,
        BusinessType.clinic,
        BusinessType.hardware,
        BusinessType.clothing,
      ];

      const Set<String> foundationPaths = <String>{
        RoutePaths.splash,
        RoutePaths.login,
        RoutePaths.authGate,
        RoutePaths.shell,
        RoutePaths.notFound,
      };

      final Set<String> argPathSet = kArgRoutePaths.toSet();

      Set<String>? reference;
      for (final type in types) {
        final container = ProviderContainer(
          overrides: [
            businessTypeProvider.overrideWith(
              () => _FixedBusinessTypeNotifier(type),
            ),
          ],
        );
        addTearDown(container.dispose);

        final router = container.read(appRouterProvider);
        addTearDown(router.dispose);

        final paths = _allGoRoutes(
          router.configuration.routes,
        ).map((r) => r.path).toSet();

        // Foundation routes still present for THIS business type.
        expect(
          paths,
          containsAll(foundationPaths),
          reason:
              'Foundation routes must remain registered for business type '
              '${type.name} after Phase C added the arg routes.',
        );
        // The /app shell is still a real ShellRoute (not flattened).
        expect(
          _hasShellRoute(router.configuration.routes),
          isTrue,
          reason: 'The /app shell must remain a ShellRoute for ${type.name}.',
        );
        // All arg routes coexist with the foundation routes.
        expect(
          paths,
          containsAll(argPathSet),
          reason:
              'All arg routes must be registered for ${type.name} (they are '
              'not capability-bound, so business type does not gate them).',
        );

        // The foundation + arg-route slice is identical across every business
        // type (no type-dependent divergence — other business types unaffected).
        final slice = paths.intersection(foundationPaths.union(argPathSet));
        reference ??= slice;
        expect(
          slice,
          equals(reference),
          reason:
              'Route slice for ${type.name} must match the other business '
              'types (foundation + arg routes are not capability-bound).',
        );
      }

      expect(reference, equals(foundationPaths.union(argPathSet)));
    });

    // ======================================================================
    // (2) WIDGET-LEVEL — faithful harness, representative subset.
    // ======================================================================

    // ---- /customer_portal: VALID String extra resolves to CustomerRoleGuard --
    testWidgets(
      '[customer_portal] pushing "/customer_portal" with VALID (non-empty '
      'String) extra resolves to its CustomerRoleGuard (session-resolving gate), '
      'NOT the fallback Scaffold and NOT the not-found screen',
      (tester) async {
        final mock = FakeSessionManager.resolving();
        await GetIt.I.reset();
        GetIt.I.registerSingleton<SessionManager>(mock);
        addTearDown(() async => GetIt.I.reset());

        final harness = _harnessPushingExtra(
          kCustomerPortalPath,
          'customer-123', // valid, non-empty String customerId
          _liveNotFoundBuilder(),
        );
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();

        // Sanity: start on the ungated home.
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        // Issue the go_router equivalent of the legacy push. Use fixed pumps
        // (NOT pumpAndSettle): the resolving guard shows AuthLoadingScreen whose
        // CircularProgressIndicator animates forever and would never settle.
        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // GAP CLOSED: valid String extra resolved to the guard-wrapped builder.
        expect(
          find.byType(CustomerRoleGuard),
          findsOneWidget,
          reason:
              '"/customer_portal" with a valid String extra must resolve to its '
              'lifted CustomerRoleGuard wrapper (the valid-arg branch).',
        );
        // Guard is mid-resolution -> shows its loading gate (NOT the heavy
        // CustomerDashboardScreen) — deterministic.
        expect(find.byType(AuthLoadingScreen), findsOneWidget);
        expect(find.text('Verifying access...'), findsOneWidget);
        // It did NOT take the fallback branch.
        expect(
          find.text(kCustomerPortalFallbackText),
          findsNothing,
          reason:
              'With a valid String extra the safe-fallback Scaffold must NOT '
              'render — the guarded valid branch is taken instead.',
        );
        // And it is NOT the production not-found screen.
        expect(find.text('Unknown Screen'), findsNothing);
        // NO CRASH (Req 5.3/5.4 emphasis).
        expect(tester.takeException(), isNull);
      },
    );

    // ---- /customer_portal: null extra renders the identical legacy fallback --
    testWidgets(
      '[customer_portal] pushing "/customer_portal" with NULL extra renders the '
      'identical legacy fallback Scaffold and does NOT crash (Req 5.3/5.4)',
      (tester) async {
        // The null/wrong-typed branch is a guard-free plain Scaffold and never
        // touches SessionManager — but register one for harness consistency.
        final mock = FakeSessionManager.authenticatedOwner();
        await GetIt.I.reset();
        GetIt.I.registerSingleton<SessionManager>(mock);
        addTearDown(() async => GetIt.I.reset());

        final harness = _harnessPushingExtra(
          kCustomerPortalPath,
          null, // MISSING args
          _liveNotFoundBuilder(),
        );
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pumpAndSettle();

        // IDENTICAL legacy fallback (captured verbatim in the 6.1 exploration).
        expect(
          find.text(kCustomerPortalFallbackText),
          findsOneWidget,
          reason:
              'With null extra, "/customer_portal" must fall back to the SAME '
              'safe "Invalid customer portal access" Scaffold the legacy builder '
              'rendered (contract preserved).',
        );
        // The guarded valid branch was NOT taken.
        expect(find.byType(CustomerRoleGuard), findsNothing);
        // And it is NOT the production not-found screen.
        expect(find.text('Unknown Screen'), findsNothing);
        // NO CRASH on null extra.
        expect(tester.takeException(), isNull);
      },
    );

    // ---- /customer_portal: wrong-typed extra renders the identical fallback --
    testWidgets(
      '[customer_portal] pushing "/customer_portal" with WRONG-TYPED (int) '
      'extra renders the identical legacy fallback Scaffold and does NOT crash '
      '(never an unconditional cast; Req 5.3/5.4)',
      (tester) async {
        final mock = FakeSessionManager.authenticatedOwner();
        await GetIt.I.reset();
        GetIt.I.registerSingleton<SessionManager>(mock);
        addTearDown(() async => GetIt.I.reset());

        final harness = _harnessPushingExtra(
          kCustomerPortalPath,
          12345, // WRONG-TYPED args (int, not String)
          _liveNotFoundBuilder(),
        );
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pumpAndSettle();

        // IDENTICAL legacy fallback — the `args is String` check rejects the int
        // (never an unconditional cast), exactly as the legacy builder did.
        expect(
          find.text(kCustomerPortalFallbackText),
          findsOneWidget,
          reason:
              'With wrong-typed (int) extra, "/customer_portal" must fall back '
              'to the SAME safe Scaffold (defensive `is`-check preserved).',
        );
        expect(find.byType(CustomerRoleGuard), findsNothing);
        expect(find.text('Unknown Screen'), findsNothing);
        // NO CRASH on wrong-typed extra.
        expect(tester.takeException(), isNull);
      },
    );

    // ---- /invoice_preview: null extra renders its guarded fallback Scaffold --
    testWidgets(
      '[invoice_preview] pushing "/invoice_preview" with NULL extra renders the '
      'identical "No invoice data provided for preview" fallback inside its '
      'VendorRoleGuard and does NOT crash (Req 5.3/5.4)',
      (tester) async {
        // Authenticated owner -> the lifted VendorRoleGuard(viewReports) passes
        // through to its child so the fallback Scaffold renders.
        final mock = FakeSessionManager.authenticatedOwner();
        await GetIt.I.reset();
        GetIt.I.registerSingleton<SessionManager>(mock);
        addTearDown(() async => GetIt.I.reset());

        final harness = _harnessPushingExtra(
          kInvoicePreviewPath,
          null, // MISSING args (a valid EditableInvoice is too heavy to pump)
          _liveNotFoundBuilder(),
        );
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pumpAndSettle();

        // The arg route resolved to its guard-wrapped builder (not not-found).
        expect(
          find.byType(VendorRoleGuard),
          findsOneWidget,
          reason:
              '"/invoice_preview" must resolve to its lifted VendorRoleGuard '
              'wrapper.',
        );
        // IDENTICAL legacy fallback Scaffold renders for the missing-arg branch.
        expect(
          find.text(kInvoicePreviewFallbackText),
          findsOneWidget,
          reason:
              'With null extra, "/invoice_preview" must render the SAME "No '
              'invoice data provided for preview" fallback the legacy builder '
              'used (contract preserved).',
        );
        expect(find.text('Unknown Screen'), findsNothing);
        // NO CRASH on null extra.
        expect(tester.takeException(), isNull);
      },
    );

    // ---- /invoice_preview: wrong-typed extra renders the guarded fallback ----
    testWidgets(
      '[invoice_preview] pushing "/invoice_preview" with WRONG-TYPED (int) '
      'extra renders the identical fallback Scaffold and does NOT crash '
      '(never an unconditional cast; Req 5.3/5.4)',
      (tester) async {
        final mock = FakeSessionManager.authenticatedOwner();
        await GetIt.I.reset();
        GetIt.I.registerSingleton<SessionManager>(mock);
        addTearDown(() async => GetIt.I.reset());

        final harness = _harnessPushingExtra(
          kInvoicePreviewPath,
          42, // WRONG-TYPED args (int, not EditableInvoice)
          _liveNotFoundBuilder(),
        );
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pumpAndSettle();

        expect(find.byType(VendorRoleGuard), findsOneWidget);
        // IDENTICAL legacy fallback — the `args is EditableInvoice` check
        // rejects the int (never an unconditional cast).
        expect(
          find.text(kInvoicePreviewFallbackText),
          findsOneWidget,
          reason:
              'With wrong-typed (int) extra, "/invoice_preview" must render the '
              'SAME safe fallback Scaffold (defensive `is`-check preserved).',
        );
        expect(find.text('Unknown Screen'), findsNothing);
        // NO CRASH on wrong-typed extra.
        expect(tester.takeException(), isNull);
      },
    );
  });
}
