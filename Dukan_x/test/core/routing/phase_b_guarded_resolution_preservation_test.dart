// ============================================================================
// PHASE B — Task 4.8: PRESERVATION TEST for guarded resolution
// Feature: imperative-navigation-gorouter-migration
// **Validates: Requirements 4.6, 10.2, 10.3**
// ============================================================================
//
// WHAT THIS PROVES (and WHY it must PASS against the CHANGED code):
//
//   This is the inverse of the Task 4.1 EXPLORATION test
//   (`phase_b_family_exploration_test.dart`). That test pinned the per-family
//   GAP: BEFORE Phase B registration, a representative guarded legacy push for
//   each core family did NOT resolve under the go_router-only root — it fell
//   through to the production "Feature Not Found" screen because
//   `LegacyRoutes.routes()` was empty.
//
//   Phase B tasks 4.2–4.5 then registered one guard-wrapped `GoRoute` per
//   legacy named string (builders lifted verbatim from `buildAppRoutes()`).
//   This preservation test proves the GAP is now CLOSED, family by family:
//   each representative legacy string resolves to its REGISTERED, guard-wrapped
//   builder under the live `AppRouter` — and the guards are WIDGET-wrapped
//   (`VendorRoleGuard` / `BusinessGuard`), NOT folded into the router-level
//   capability guard (design AD-2, Req 4.6).
//
// THE SEVEN REPRESENTATIVE FAMILIES (legacy string + legacy guard):
//
//   | Family (Phase B task)            | Representative path     | Legacy guard          |
//   |----------------------------------|-------------------------|-----------------------|
//   | auth / entry / dashboard (4.2)   | /home                   | viewInvoices (RBAC)   |
//   | billing (4.3)                    | /proforma               | createInvoices        |
//   | settings / admin (4.4)           | /vendor_profile         | systemSettings        |
//   | reports / analytics (4.4)        | /gst-reports            | viewReports           |
//   | reports / sync (4.4)             | /sync-status            | viewReports           |
//   | clinic vertical (4.5)            | /clinic/appointment     | viewClients + clinic  |
//   | decoration/catering vertical 4.5 | /dc/dashboard           | viewInvoices + dc     |
//
// THREE COMPLEMENTARY ASSERTION LAYERS:
//
//   (1) CONFIG-LEVEL (deterministic, all seven families): the LIVE
//       `appRouterProvider` configuration now registers a top-level `GoRoute`
//       whose `path` equals each representative legacy string, and
//       `LegacyRoutes.isKnownLegacyPath` reports `true` for each (parity by
//       construction). The foundation + `/app` shell routes are STILL present
//       alongside the new legacy routes (Req 10.3 non-regression), and the set
//       is identical across In_Scope_Business_Types (legacy/foundation routes
//       are not capability-bound at the router level).
//
//   (2) WIDGET-LEVEL (faithful harness, representative subset): a minimal
//       `MaterialApp.router` that registers the ACTUAL `LegacyRoutes.routes()`
//       and drives `context.push('<path>')` — the exact go_router equivalent of
//       the legacy `Navigator.pushNamed('<path>')` call site Phase B fixed.
//       Two families are pumped, chosen because their guard renders cleanly
//       (no heavy screen init):
//         * /proforma  — pumped with the session still resolving, so the
//           lifted `VendorRoleGuard` renders its "Verifying access..." gate
//           (proves the guard-wrapped builder resolved, NOT the not-found
//           screen) without constructing the heavy ProformaScreen.
//         * /clinic/appointment — pumped as an authenticated owner whose active
//           business type is NOT clinic, so the lifted
//           `VendorRoleGuard(child: BusinessGuard(...))` resolves to the
//           BusinessGuard DENY screen ("Only Clinics can access Appointments")
//           — exercising the real guard-wrapped builder and its denialMessage.
//       The other five families are config-asserted (their target screens are
//       heavy to pump), per design's "assert at the config/builder level" rule.
//
//   (3) WIDGET-GUARD-ONLY (Req 4.6 / AD-2): the AppRouter capability registry
//       (`_routeCapabilityBindings`, surfaced via the pure
//       `AppRouter.requiredCapabilityFor`) contains NONE of the legacy paths /
//       itemIds — so migrated legacy routes rely on their widget-wrapped guards
//       and the router-level capability guard is a NO-OP for them
//       (`RoutePaths.navItemIdForPath` returns `null`, so the guard never gates
//       a legacy path). This proves the guards were NOT folded into the
//       router-level redirect.
//
// DETERMINISM (mirrors the established harness rationale in
// `phase_b_family_exploration_test.dart` / `phase_a_foundation_wiring_*`):
//   The live router's `initialLocation` is `/splash`, whose `SplashScreen` runs
//   a repeating animation + audio/GetIt init that never settles, so we do NOT
//   pump the heavy `/splash` entry. The widget-level layer pumps a MINIMAL
//   `MaterialApp.router` that reuses the EXACT production pieces that matter:
//   the real `LegacyRoutes.routes()` table and the real production not-found
//   builder (lifted from the live router) as the errorBuilder, so a resolved
//   guard render is provably distinct from the not-found fallback.
//
// TEST-ONLY: no production/application code is changed by this task.
//
// Run: flutter test \
//   test/core/routing/phase_b_guarded_resolution_preservation_test.dart \
//   --reporter expanded
// ============================================================================

import 'package:dukanx/core/auth/auth_loading_screen.dart';
import 'package:dukanx/core/auth/role_guard.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/core/auth/business_type_guard.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

/// One representative legacy named string per core route family (INVENTORY §2).
/// Each is a guarded legacy route registered by the matching Phase B task; this
/// test proves each now resolves to its guard-wrapped builder under AppRouter.
const Map<String, String> kFamilyRepresentativePaths = <String, String>{
  // auth / entry / dashboard (Task 4.2) — legacy guard: viewInvoices.
  'auth/entry/dashboard': '/home',
  // billing (Task 4.3) — legacy guard: createInvoices.
  'billing': '/proforma',
  // settings / admin (Task 4.4) — legacy guard: systemSettings.
  'settings/admin': '/vendor_profile',
  // reports / analytics (Task 4.4) — legacy guard: viewReports.
  'reports/analytics': '/gst-reports',
  // reports / sync (Task 4.4) — legacy guard: viewReports.
  'reports/sync': '/sync-status',
  // clinic vertical (Task 4.5) — viewClients + BusinessGuard([clinic]).
  'clinic/vertical': '/clinic/appointment',
  // decoration & catering vertical (Task 4.5) — viewInvoices + BusinessGuard.
  'decoration_catering/vertical': '/dc/dashboard',
};

/// Lightweight home for the widget-level harness (an ungated, always-matched
/// route) whose button issues the imperative go_router push under test.
const String kHarnessHomePath = '/harness-home';
const String kHarnessHomeMarker = 'HARNESS_HOME';

/// Recursively collects every [GoRoute] in a route tree (descending through
/// [ShellRoute]s and nested routes). Mirrors the established routing-test
/// helper so the assertion tracks the live configuration exactly.
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
/// production not-found screen (not a stand-in). Mirrors the helper in
/// `phase_b_family_exploration_test.dart`.
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
/// harness errorBuilder renders the actual `_RouteNotFoundScreen` (whose body
/// shows "Unknown Screen" / "Feature Not Found"). A resolved guard render is
/// then provably distinct from this fallback.
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
/// (the go_router equivalent of the legacy `Navigator.pushNamed(pushPath)`).
///
/// The top-level redirect consults the SAME production `aliasTargetFor` single
/// source of truth (faithful composition); it deliberately does NOT add the
/// router-level capability guard — which is exactly the point of Req 4.6:
/// legacy routes are protected by their WIDGET guards, not the router guard.
GoRouter _harnessPushing(String pushPath, GoRouterWidgetBuilder notFound) {
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
              onPressed: () => context.push(pushPath),
              child: const Text(kHarnessHomeMarker),
            ),
          ),
        ),
      ),
      // The REAL migrated guard-wrapped legacy routes (single source of truth).
      ...LegacyRoutes.routes(),
    ],
    errorBuilder: notFound,
  );
}

/// A lightweight fake [SessionManager] whose auth-state getters are fixed via
/// the constructor. [SessionManager] is a [ChangeNotifier], so
/// `VendorRoleGuard`'s `ListenableBuilder` can listen to it; `Mock` provides
/// the inherited `addListener`/`removeListener` no-ops via `noSuchMethod`,
/// while the five boolean getters `VendorRoleGuard` reads are overridden with
/// real backing values (mockito's null-safe `when` stubbing is not used — the
/// non-nullable getters are satisfied by these overrides instead).
class FakeSessionManager extends Mock implements SessionManager {
  FakeSessionManager({
    this.isLoading = false,
    this.isInitialized = true,
    this.isAuthenticated = true,
    this.isOwner = true,
    this.isCustomerOnlyMode = false,
  });

  /// Session still resolving -> `VendorRoleGuard` shows the "Verifying
  /// access..." gate (builds no child screen, schedules no redirect).
  factory FakeSessionManager.resolving() =>
      FakeSessionManager(isLoading: true, isInitialized: false);

  /// Authenticated owner -> `VendorRoleGuard` passes through to its child
  /// (e.g. the inner `BusinessGuard`).
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
/// [businessTypeProvider] without touching SharedPreferences (the real
/// notifier's `build()` kicks off an async prefs load). Mirrors the helper in
/// `phase_a_foundation_wiring_preservation_test.dart`.
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

  group('Feature: imperative-navigation-gorouter-migration — Phase B '
      'PRESERVATION: representative legacy pushes per family NOW resolve to '
      'their guard-wrapped builders (Req 4.6, 10.2, 10.3)', () {
    // ======================================================================
    // (1) CONFIG-LEVEL — every representative family path is now a registered
    //     top-level GoRoute under the live AppRouter, and a known legacy path.
    // ======================================================================
    test('the live AppRouter now registers a GoRoute for EVERY family '
        'representative legacy path, and isKnownLegacyPath is true for each '
        '(Req 10.2 — gap closed)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);

      final registered = _allGoRoutes(router.configuration.routes).toList();
      final paths = registered.map((r) => r.path).toSet();

      // The legacy layer is no longer empty — Phase B registered its routes.
      expect(
        LegacyRoutes.knownLegacyPaths,
        isNotEmpty,
        reason:
            'Phase B (tasks 4.2–4.5) must have registered the legacy routes; '
            'knownLegacyPaths is no longer empty.',
      );

      kFamilyRepresentativePaths.forEach((family, legacyPath) {
        // The representative legacy string resolves to a REGISTERED top-level
        // GoRoute whose path equals that string (Req 3.1 / 2.6).
        expect(
          paths,
          contains(legacyPath),
          reason:
              '[$family] "$legacyPath" must now be a registered GoRoute path '
              'under the live AppRouter (Phase B registration).',
        );
        // Parity: the path set claims it too (Req 3.4 / 3.5).
        expect(
          LegacyRoutes.isKnownLegacyPath(legacyPath),
          isTrue,
          reason:
              '[$family] LegacyRoutes.isKnownLegacyPath("$legacyPath") must be '
              'true now that its GoRoute is registered.',
        );
      });
    });

    // ======================================================================
    // (3) WIDGET-GUARD-ONLY (Req 4.6 / AD-2) — the router-level capability
    //     registry excludes ALL legacy paths/itemIds; migrated legacy routes
    //     rely on their widget-wrapped guards, not the router guard.
    // ======================================================================
    test('the AppRouter capability registry binds NONE of the legacy paths — '
        'migrated routes use widget-wrapped guards, not the router guard '
        '(Req 4.6)', () {
      // No registered legacy path is bound to a capability in the router-level
      // registry (surfaced via the pure `requiredCapabilityFor`). If any were,
      // the route would be double-guarded by the router redirect.
      for (final String legacyPath in LegacyRoutes.knownLegacyPaths) {
        expect(
          AppRouter.requiredCapabilityFor(legacyPath),
          isNull,
          reason:
              'Legacy path "$legacyPath" must NOT be bound in the router '
              'capability registry (AD-2 widget-guard-only rule).',
        );
        // And it does not resolve to a capability-gated /app sidebar itemId, so
        // the router capability guard is a NO-OP for it (never redirects it).
        expect(
          RoutePaths.navItemIdForPath(legacyPath),
          isNull,
          reason:
              'Legacy path "$legacyPath" must not map to an /app sidebar '
              'itemId — the router capability guard must not gate it.',
        );
      }

      // Spot-check the representative families explicitly (the families that
      // DO carry widget guards in their builders): none is router-bound.
      kFamilyRepresentativePaths.forEach((family, legacyPath) {
        expect(
          AppRouter.requiredCapabilityFor(legacyPath),
          isNull,
          reason:
              '[$family] "$legacyPath" must rely on its widget-wrapped guard, '
              'not a router-level capability binding.',
        );
      });
    });

    // ======================================================================
    // (Req 10.3) NON-REGRESSION — foundation + /app shell routes are STILL
    //     present alongside the new legacy routes, and identical across
    //     In_Scope_Business_Types (foundation/legacy routes are not
    //     capability-bound at the router level).
    // ======================================================================
    test('the foundation + /app shell routes remain registered ALONGSIDE the '
        'new legacy routes, identically across business types (Req 10.3)', () {
      const List<BusinessType> types = <BusinessType>[
        BusinessType.grocery,
        BusinessType.pharmacy,
        BusinessType.restaurant,
        BusinessType.clinic,
        BusinessType.decorationCatering,
      ];

      const Set<String> foundationPaths = <String>{
        RoutePaths.splash,
        RoutePaths.login,
        RoutePaths.authGate,
        RoutePaths.shell,
        RoutePaths.notFound,
      };

      final Set<String> representativeLegacyPaths = kFamilyRepresentativePaths
          .values
          .toSet();

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
              '${type.name} after Phase B added the legacy routes.',
        );
        // The /app shell is still a real ShellRoute (not flattened).
        expect(
          _hasShellRoute(router.configuration.routes),
          isTrue,
          reason: 'The /app shell must remain a ShellRoute for ${type.name}.',
        );
        // The NEW legacy routes coexist with the foundation routes.
        expect(
          paths,
          containsAll(representativeLegacyPaths),
          reason:
              'The migrated legacy routes must coexist with the foundation '
              'routes for ${type.name}.',
        );

        // The foundation + representative-legacy slice is identical across
        // every business type (no type-dependent divergence in wiring).
        final slice = paths.intersection(
          foundationPaths.union(representativeLegacyPaths),
        );
        reference ??= slice;
        expect(
          slice,
          equals(reference),
          reason:
              'Route slice for ${type.name} must match the other business '
              'types (foundation + legacy routes are not capability-bound).',
        );
      }

      expect(
        reference,
        equals(foundationPaths.union(representativeLegacyPaths)),
      );
    });

    // ======================================================================
    // (2) WIDGET-LEVEL — faithful harness, representative subset.
    // ======================================================================

    // ---- billing family: /proforma resolves to its VendorRoleGuard ----------
    testWidgets(
      '[billing] pushing "/proforma" resolves to its lifted VendorRoleGuard '
      '(session-resolving gate), NOT the not-found screen',
      (tester) async {
        final mock = FakeSessionManager.resolving();
        await GetIt.I.reset();
        GetIt.I.registerSingleton<SessionManager>(mock);
        addTearDown(() async => GetIt.I.reset());

        final harness = _harnessPushing('/proforma', _liveNotFoundBuilder());
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();

        // Sanity: we start on the ungated home.
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        // Issue the go_router equivalent of the legacy push. Use fixed pumps
        // (NOT pumpAndSettle): the resolving guard shows AuthLoadingScreen whose
        // CircularProgressIndicator animates forever and would never settle.
        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // GAP CLOSED: the legacy string resolved to its guard-wrapped builder.
        expect(
          find.byType(VendorRoleGuard),
          findsOneWidget,
          reason:
              '"/proforma" must resolve to its lifted VendorRoleGuard wrapper.',
        );
        // The guard is mid-resolution, so it shows its loading gate (not the
        // heavy ProformaScreen) — deterministic.
        expect(find.byType(AuthLoadingScreen), findsOneWidget);
        expect(find.text('Verifying access...'), findsOneWidget);
        // And it is NOT the production not-found screen.
        expect(
          find.text('Unknown Screen'),
          findsNothing,
          reason:
              '"/proforma" must no longer fall through to the not-found '
              'screen — its GoRoute is registered (Phase B).',
        );
      },
    );

    // ---- clinic vertical: /clinic/appointment resolves to its nested -------
    // ---- VendorRoleGuard(child: BusinessGuard) and renders the deny screen --
    testWidgets(
      '[clinic/vertical] pushing "/clinic/appointment" as an authenticated '
      'owner whose business type is NOT clinic resolves to the lifted '
      'VendorRoleGuard(child: BusinessGuard) and renders its denialMessage',
      (tester) async {
        final mock = FakeSessionManager.authenticatedOwner();
        await GetIt.I.reset();
        GetIt.I.registerSingleton<SessionManager>(mock);
        addTearDown(() async => GetIt.I.reset());

        // Active business type is grocery (NOT clinic) -> BusinessGuard denies.
        final container = ProviderContainer(
          overrides: [
            businessTypeProvider.overrideWith(
              () => _FixedBusinessTypeNotifier(BusinessType.grocery),
            ),
          ],
        );
        addTearDown(container.dispose);

        final harness = _harnessPushing(
          '/clinic/appointment',
          _liveNotFoundBuilder(),
        );
        addTearDown(harness.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: harness),
          ),
        );
        await tester.pumpAndSettle();

        // Sanity: start on the ungated home.
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pumpAndSettle();

        // GAP CLOSED: the legacy string resolved to its nested guard-wrapped
        // builder (both guards present, lifted verbatim from buildAppRoutes()).
        expect(
          find.byType(VendorRoleGuard),
          findsOneWidget,
          reason:
              '"/clinic/appointment" must resolve to its lifted VendorRoleGuard '
              'wrapper.',
        );
        expect(
          find.byType(BusinessGuard),
          findsOneWidget,
          reason:
              '"/clinic/appointment" must resolve to the inner BusinessGuard '
              '(business-type isolation preserved).',
        );
        // The DENY screen renders with the verbatim denialMessage (Req 4.3/4.5)
        // — proving the widget guard, not the router guard, enforced isolation.
        expect(
          find.text('Only Clinics can access Appointments'),
          findsOneWidget,
          reason:
              'The BusinessGuard denialMessage must render for a non-clinic '
              'business type (preserved verbatim).',
        );
        // And it is NOT the production not-found screen.
        expect(
          find.text('Unknown Screen'),
          findsNothing,
          reason:
              '"/clinic/appointment" must no longer fall through to the '
              'not-found screen — its GoRoute is registered (Phase B).',
        );
      },
    );
  });
}
