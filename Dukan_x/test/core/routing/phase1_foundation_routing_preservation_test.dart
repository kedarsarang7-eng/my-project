// ============================================================================
// Foundation routing PRESERVATION test (go_router navigation)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 2.4 (PHASE 1) — original preservation test (flag OFF vs ON).
// Task 9.3 (PHASE 8 — legacy removal) — the `useGoRouterShell` flag is gone and
// go_router is the SOLE navigation path, so the "flag OFF vs flag ON" dimension
// is collapsed. This test now PRESERVES the two remaining guarantees:
// Validates: Requirements 2.2, 2.3, 4.1, 4.3
//
//   1) PER-TYPE SHELL RESOLUTION (Req 4.3 / non-regression): the
//      login->shell section resolution for grocery, pharmacy, and the
//      default/retail fallback is the documented per-type shell. The same
//      `sidebarSectionsProvider` the `ShellRoute` builder renders. Other
//      in-scope types (restaurant, clinic, wholesale) keep their own shells
//      (Req 2.3 non-regression).
//
//   2) GO_ROUTER FOUNDATION REACHES THE SHELL (Req 4.1, 4.3):
//      `appRouterProvider` builds a usable `GoRouter` whose configuration
//      exposes the four foundation routes (/splash, /login, /auth-gate) plus a
//      `ShellRoute` (the main shell, child `/app`).
//
// SEAM CHOSEN (and the explicit limitation):
//   `sidebarSectionsProvider` is the stable proxy for "which shell loads for
//   business type X" — the ShellRoute builder renders `AdaptiveShell`, which
//   renders its sidebar from exactly this provider (design Req 4.4). Driving
//   the FULL GoRouter widget (pumping `MaterialApp.router` and navigating
//   splash->auth-gate->shell) is NON-DETERMINISTIC in a unit/widget test —
//   `SplashScreen`, `AuthGate`, and `AdaptiveShell` reach into GetIt,
//   `SessionManager`, network/auth, and `SharedPreferences`. So the router half
//   asserts at the strongest feasible seam: the router constructs without
//   throwing and its route configuration exposes the foundation routes + the
//   `ShellRoute`. Full end-to-end login->shell widget navigation is covered by
//   the Phase 8 multi-type integration regression.
// ============================================================================

import 'package:dukanx/core/models/user_role.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Fake [BusinessTypeNotifier] that pins the active business type WITHOUT
/// touching SharedPreferences / license providers.
class _FakeBusinessTypeNotifier extends BusinessTypeNotifier {
  _FakeBusinessTypeNotifier(this._type);

  final BusinessType _type;

  @override
  BusinessTypeState build() => BusinessTypeState(type: _type);
}

/// Fake [AuthStateNotifier] representing a completed (post-login)
/// authentication WITHOUT reaching into the GetIt service locator.
class _FakeAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated);
}

/// Builds a container whose provider graph resolves the shell sidebar for
/// [type] as it would right after a successful login.
ProviderContainer _shellContainer(BusinessType type) {
  final container = ProviderContainer(
    overrides: [
      businessTypeProvider.overrideWith(() => _FakeBusinessTypeNotifier(type)),
      authStateProvider.overrideWith(() => _FakeAuthStateNotifier()),
      // Neutralize RBAC so the ungated dashboard sections we assert on survive
      // the filter; capability filtering (FeatureResolver) stays real.
      currentUserRoleProvider.overrideWithValue(UserRole.owner),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// The ordered list of resolved shell section titles for [type].
List<String> _sectionTitles(BusinessType type) {
  final sections = _shellContainer(type).read(sidebarSectionsProvider);
  return sections.map((s) => s.title).toList();
}

/// Recursively collects every [GoRoute] in a route tree (descending through
/// [ShellRoute]s and nested routes).
Iterable<GoRoute> _allGoRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
      yield* _allGoRoutes(route.routes);
    } else if (route is ShellRoute) {
      yield* _allGoRoutes(route.routes);
    } else {
      yield* _allGoRoutes(route.routes);
    }
  }
}

/// True if [routes] contains a [ShellRoute] with a direct child [GoRoute] whose
/// path equals [childPath].
bool _hasShellRouteWithChild(List<RouteBase> routes, String childPath) {
  for (final route in routes) {
    if (route is ShellRoute) {
      final hasChild = route.routes.whereType<GoRoute>().any(
        (g) => g.path == childPath,
      );
      if (hasChild) return true;
    }
  }
  return false;
}

void main() {
  // GoRouter construction needs an initialized binding (it wires up route
  // information providers). Plain `test()` bodies don't auto-initialize it.
  TestWidgetsFlutterBinding.ensureInitialized();

  const grocery = BusinessType.grocery;
  const pharmacy = BusinessType.pharmacy;
  const other = BusinessType.other; // default/retail fallback

  group('Feature: gorouter-navigation-migration — foundation routing '
      'PRESERVATION (Req 2.2, 2.3, 4.1, 4.3)', () {
    // ----------------------------------------------------------------------
    // PER-TYPE SHELL RESOLUTION (the login->shell outcome per business type).
    // ----------------------------------------------------------------------
    group('per-type shell resolution', () {
      test('grocery resolves the RETAIL shell (Dashboard & Control)', () {
        final titles = _sectionTitles(grocery);
        expect(titles, isNotEmpty);
        expect(titles.first, 'Dashboard & Control');
        expect(titles, isNot(contains('Pharmacy Control')));
      });

      test('pharmacy resolves the dedicated PHARMACY shell', () {
        final titles = _sectionTitles(pharmacy);
        expect(titles, isNotEmpty);
        expect(titles.first, 'Pharmacy Control');
        expect(titles, contains('Dispensing & Sales'));
      });

      test('default/retail (other) resolves the RETAIL shell fallback', () {
        final titles = _sectionTitles(other);
        expect(titles, isNotEmpty);
        expect(titles.first, 'Dashboard & Control');
        expect(titles, isNot(contains('Pharmacy Control')));
      });

      test('pharmacy shell stays distinct from grocery/retail (invariant)', () {
        final g = _sectionTitles(grocery);
        final p = _sectionTitles(pharmacy);
        final r = _sectionTitles(other);
        expect(g.first, r.first);
        expect(p.first, isNot(g.first));
      });
    });

    // ----------------------------------------------------------------------
    // GO_ROUTER FOUNDATION REACHES THE SHELL (Req 4.1, 4.3).
    // ----------------------------------------------------------------------
    group('go_router foundation reaches the shell', () {
      test('appRouterProvider builds a usable GoRouter without crashing', () {
        final container = _shellContainer(grocery);

        late final GoRouter router;
        expect(
          () => router = container.read(appRouterProvider),
          returnsNormally,
          reason: 'AppRouter must build the foundation GoRouter without error.',
        );
        addTearDown(router.dispose);

        expect(router.configuration.routes, isNotEmpty);
      });

      test('router config exposes the four foundation routes + ShellRoute', () {
        final container = _shellContainer(grocery);
        final router = container.read(appRouterProvider);
        addTearDown(router.dispose);

        final topLevel = router.configuration.routes;
        final paths = _allGoRoutes(topLevel).map((r) => r.path).toSet();

        // Foundation routes (Req 4.1): splash, login, business-type
        // resolution (auth-gate), and the shell base under the ShellRoute.
        expect(paths, contains(RoutePaths.splash)); // '/splash'
        expect(paths, contains(RoutePaths.login)); // '/login'
        expect(paths, contains(RoutePaths.authGate)); // '/auth-gate'
        expect(paths, contains(RoutePaths.shell)); // '/app' (shell child)

        expect(
          _hasShellRouteWithChild(topLevel, RoutePaths.shell),
          isTrue,
          reason: 'The main shell must be a ShellRoute hosting the /app child.',
        );
      });
    });

    // ----------------------------------------------------------------------
    // NON-REGRESSION — other in-scope business types keep their own shells
    // (Requirement 2.3).
    //
    // Representatives chosen to cover distinct resolution branches:
    //   * restaurant -> dedicated `_getRestaurantSections()`
    //   * clinic     -> dedicated `_getClinicSections()`
    //   * wholesale  -> default branch -> `_getRetailSections()`
    // ----------------------------------------------------------------------
    group(
      'NON-REGRESSION — other in-scope types keep their shells (Req 2.3)',
      () {
        const expectedFirstSection = <BusinessType, String>{
          BusinessType.restaurant: 'Restaurant Operations',
          BusinessType.clinic: 'Clinic Dashboard',
          BusinessType.wholesale: 'Dashboard & Control', // retail default
        };

        expectedFirstSection.forEach((type, firstTitle) {
          test('${type.name}: stable first section', () {
            final titles = _sectionTitles(type);
            expect(
              titles,
              isNotEmpty,
              reason: '${type.name} must resolve a shell.',
            );
            expect(
              titles.first,
              firstTitle,
              reason: '${type.name} must keep its expected first section.',
            );
            if (type != BusinessType.pharmacy) {
              expect(titles, isNot(contains('Pharmacy Control')));
            }
          });
        });
      },
    );
  });
}
