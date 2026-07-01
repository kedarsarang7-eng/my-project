// ============================================================================
// PHASE B — Task 4.1: EXPLORATION TESTS per representative route family
// Feature: imperative-navigation-gorouter-migration
// **Validates: Requirements 10.1**
// ============================================================================
//
// WHAT THIS PROVES (and WHY it must PASS against the CURRENT, UNCHANGED code):
//
//   Phase A (Tasks 2.x) wired the Legacy-Compatible Route Layer
//   (`LegacyRoutes`) into the live `AppRouter`: `AppRouter.build` spreads
//   `...LegacyRoutes.routes()` into its top-level `routes:` list and PREPENDS
//   the pure `LegacyRoutes.aliasTargetFor` alias check to the composed
//   `redirect`. BUT `LegacyRoutes.routes()` is still an EMPTY list and
//   `LegacyRoutes.knownLegacyPaths` is still EMPTY — the 121 guarded legacy
//   `GoRoute`s are registered only by the upcoming Phase B tasks (4.2 auth/
//   entry/dashboard, 4.3 billing, 4.4 settings + reports, 4.5 verticals).
//
//   So TODAY, a representative guarded legacy push for each core family does
//   NOT resolve to its target screen — it is neither a registered `GoRoute`
//   nor an alias the redirect can rescue, so it falls through to the AppRouter
//   `errorBuilder` -> the theme-aware "Feature Not Found" (`_RouteNotFoundScreen`).
//   THIS is the per-family gap Phase B closes. Pinning it now lets the Task 4.8
//   preservation tests prove, family by family, that registration closed it.
//
// THE FOUR REPRESENTATIVE FAMILIES (one legacy string each, from INVENTORY §2):
//
//   | Family (Phase B task)            | Representative legacy path | Legacy guard         |
//   |----------------------------------|----------------------------|----------------------|
//   | auth / entry / dashboard (4.2)   | /home                      | viewInvoices (RBAC)  |
//   | billing (4.3)                    | /proforma                  | createInvoices       |
//   | settings / admin (4.4)           | /vendor_profile            | systemSettings       |
//   | reports / analytics (4.4)        | /gst-reports               | viewReports          |
//
//   Each is a REAL guarded route in the legacy `buildAppRoutes()` table
//   (INVENTORY.md §2) that the corresponding Phase B task will register. None
//   of the four is an AD-6 alias (`aliasTargetFor` returns `null` for each), so
//   the composed redirect cannot rescue them — they can only resolve once
//   their `GoRoute` is registered.
//
// TWO COMPLEMENTARY ASSERTIONS PER FAMILY (mirroring
// `imperative_nav_exploration_test.dart`):
//
//   (1) CONFIG-LEVEL (deterministic): the LIVE `appRouterProvider` router
//       configuration does NOT register a `GoRoute` whose path/name is the
//       family's representative string; `LegacyRoutes.aliasTargetFor` returns
//       `null` for it (no redirect rescue); and `LegacyRoutes.isKnownLegacyPath`
//       reports `false` (the parity set has not yet claimed it).
//
//   (2) WIDGET-LEVEL (deterministic, faithful harness): pumping a minimal
//       `MaterialApp.router` and issuing the go_router equivalent of the legacy
//       push (`context.push('<family path>')`) lands on the REAL production
//       not-found screen — proving the family target is unreachable today.
//
// DETERMINISM (documented, mirroring the established harness rationale in
// `imperative_nav_exploration_test.dart`):
//   The live router's `initialLocation` is `/splash`, whose `SplashScreen` runs
//   a REPEATING animation controller plus audio/GetIt init and delayed timers —
//   pumping it whole never settles. So the widget-level half does NOT pump the
//   heavy `/splash` entry. Instead it pumps a MINIMAL `MaterialApp.router` that
//   reuses the EXACT production pieces that matter for the gap claim:
//     * a route table that genuinely has NO family route (the gap — proven
//       independently by assertion (1) against the live config), and
//     * the REAL production not-found builder, lifted verbatim from the live
//       router's `RoutePaths.notFound` route, so what renders is the actual
//       `_RouteNotFoundScreen`, not a stand-in.
//
// TEST-ONLY: no production/application code is changed by this task.
//
// Run: flutter test test/core/routing/phase_b_family_exploration_test.dart \
//        --reporter expanded
// ============================================================================

import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// One representative legacy named string per core route family (INVENTORY §2).
/// Each is a guarded legacy route the matching Phase B task (4.2–4.4) will
/// register; today none resolves under the go_router-only root.
const Map<String, String> kFamilyRepresentativePaths = <String, String>{
  // auth / entry / dashboard (Task 4.2) — legacy guard: viewInvoices.
  'auth/entry/dashboard': '/home',
  // billing (Task 4.3) — legacy guard: createInvoices.
  'billing': '/proforma',
  // settings / admin (Task 4.4) — legacy guard: systemSettings.
  'settings/admin': '/vendor_profile',
  // reports / analytics (Task 4.4) — legacy guard: viewReports.
  'reports/analytics': '/gst-reports',
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

/// Finds the [GoRoute] registered for [path] anywhere in the router
/// configuration and returns its builder, so the harness renders the REAL
/// production screen (not a stand-in). Mirrors the helper in
/// `imperative_nav_exploration_test.dart`.
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

void main() {
  // GoRouter construction needs an initialized binding (it wires up route
  // information providers). Plain `test()` bodies don't auto-initialize it.
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Feature: imperative-navigation-gorouter-migration — Phase B '
    'EXPLORATION: representative legacy pushes per family do NOT resolve today '
    '(Req 10.1)',
    () {
      // --------------------------------------------------------------------
      // (1) CONFIG-LEVEL: per family, the representative legacy route is
      //     UNWIRED, is not an alias, and is not yet a known legacy path.
      // --------------------------------------------------------------------
      test(
        'the live AppRouter registers NONE of the four family representative '
        'legacy paths — LegacyRoutes.routes() is still empty (Phase B '
        'registration pending)',
        () {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final router = container.read(appRouterProvider);
          addTearDown(router.dispose);

          final registered = _allGoRoutes(router.configuration.routes).toList();
          final paths = registered.map((r) => r.path).toSet();
          final names = registered
              .map((r) => r.name)
              .whereType<String>()
              .toSet();

          // Sanity: this really IS the go_router-only root — its foundation
          // routes are present (so the missing family routes are the GAP, not
          // a mis-built router).
          expect(
            paths,
            contains(RoutePaths.splash),
            reason:
                'The go_router-only root must expose the /splash foundation '
                'route.',
          );
          expect(
            paths,
            contains(RoutePaths.shell),
            reason: 'The go_router-only root must expose the /app shell route.',
          );

          // Sanity: the legacy layer has registered nothing yet (Phase B
          // tasks 4.2–4.5 populate it). If this set is non-empty, this
          // exploration test is being run AFTER registration and must be
          // re-evaluated.
          expect(
            LegacyRoutes.knownLegacyPaths,
            isEmpty,
            reason:
                'LegacyRoutes.routes() must still be empty before Phase B '
                'registers the family routes.',
          );

          // THE GAP, per family: each representative legacy string is NOT a
          // registered GoRoute (by path OR name), is NOT an AD-6 alias (so the
          // composed redirect cannot rescue it), and is NOT yet a known legacy
          // path.
          kFamilyRepresentativePaths.forEach((family, legacyPath) {
            expect(
              paths,
              isNot(contains(legacyPath)),
              reason:
                  '[$family] "$legacyPath" must be absent from the live router '
                  'today — its GoRoute is registered only in Phase B.',
            );
            expect(
              names,
              isNot(contains(legacyPath)),
              reason:
                  '[$family] no registered route is named for "$legacyPath" '
                  'today.',
            );
            expect(
              LegacyRoutes.aliasTargetFor(legacyPath),
              isNull,
              reason:
                  '[$family] "$legacyPath" is a guarded family route, NOT an '
                  'AD-6 alias — the composed redirect must not rescue it.',
            );
            expect(
              LegacyRoutes.isKnownLegacyPath(legacyPath),
              isFalse,
              reason:
                  '[$family] "$legacyPath" must not be a known legacy path '
                  'until Phase B registers its GoRoute.',
            );
          });
        },
      );

      // --------------------------------------------------------------------
      // (2) WIDGET-LEVEL: per family, pushing the representative legacy path
      //     lands on the production not-found screen.
      // --------------------------------------------------------------------
      for (final MapEntry<String, String> entry
          in kFamilyRepresentativePaths.entries) {
        final String family = entry.key;
        final String legacyPath = entry.value;

        testWidgets(
          '[$family] pumping MaterialApp.router and pushing "$legacyPath" '
          'resolves to the production not-found screen today',
          (tester) async {
            // Lift the REAL production not-found builder from the live router so
            // the harness renders the actual `_RouteNotFoundScreen` an unmatched
            // legacy push lands on today.
            final container = ProviderContainer();
            addTearDown(container.dispose);
            final liveRouter = container.read(appRouterProvider);
            addTearDown(liveRouter.dispose);

            final notFoundBuilder = _findBuilderForPath(
              liveRouter.configuration.routes,
              RoutePaths.notFound,
            );
            expect(
              notFoundBuilder,
              isNotNull,
              reason:
                  'The live router must register the not-found route '
                  '(${RoutePaths.notFound}) whose builder renders the '
                  'production "Feature Not Found" screen.',
            );

            // Minimal harness: an ungated home + the production not-found
            // builder as the errorBuilder. Crucially, it registers NO family
            // route — exactly the production reality proven by assertion (1).
            final harness = GoRouter(
              initialLocation: kHarnessHomePath,
              routes: <RouteBase>[
                GoRoute(
                  path: kHarnessHomePath,
                  builder: (BuildContext context, GoRouterState state) =>
                      Scaffold(
                        body: Center(
                          child: ElevatedButton(
                            // The go_router equivalent of the legacy
                            // `Navigator.of(context).pushNamed('$legacyPath')`
                            // call site — the very navigation Phase B will fix.
                            onPressed: () => context.push(legacyPath),
                            child: const Text(kHarnessHomeMarker),
                          ),
                        ),
                      ),
                ),
              ],
              errorBuilder: notFoundBuilder,
            );
            addTearDown(harness.dispose);

            await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
            await tester.pumpAndSettle();

            // Sanity: we start on the ungated home.
            expect(find.text(kHarnessHomeMarker), findsOneWidget);

            // Issue the imperative legacy push for this family.
            await tester.tap(find.text(kHarnessHomeMarker));
            await tester.pumpAndSettle();

            // THE GAP, demonstrated per family: the legacy string did NOT
            // resolve to its target screen. It fell through to the production
            // not-found screen.
            expect(
              find.text('Unknown Screen'),
              findsOneWidget,
              reason:
                  '[$family] the production not-found screen must render for '
                  '"$legacyPath" today.',
            );
            expect(
              find.text('Feature Not Found'),
              findsOneWidget,
              reason:
                  '[$family] the production not-found screen must render for '
                  '"$legacyPath" today.',
            );
          },
        );
      }
    },
    skip:
        'Superseded by Phase B registration (Tasks 4.2–4.5) and '
        'phase_b_guarded_resolution_preservation_test.dart — the per-family gap '
        'is now closed',
  );
}
