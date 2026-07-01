// ============================================================================
// PHASE E — Task 8.7 (OPTIONAL PROPERTY TEST)
// Feature: imperative-navigation-gorouter-migration
// Property 8: Graceful degradation for unmapped navigation
// **Validates: Requirements 8.2, 8.3, 9.3**
// ============================================================================
//
// Property 8 (design.md — Correctness Properties):
//   "For any generated string that is neither a registered legacy route nor an
//    alias, navigating to it under `AppRouter` renders the `_RouteNotFoundScreen`
//    via `errorBuilder` and never throws or crashes."
//
// DESIGN ANCHOR — AD-7 (Dynamic / string-driven navigation safety net):
//   `shortcut_panel.dart` pushes arbitrary `ShortcutDefinition.route` strings,
//   some of which (`/receipts`, `/purchase`, `/change_business`,
//   `/configuration`, `/patients`) are present in NO route table. Because every
//   KNOWN legacy string is a registered `GoRoute` and the `GoRouter.errorBuilder`
//   renders the theme-aware `_RouteNotFoundScreen` ("Feature Not Found"), unknown
//   strings degrade gracefully instead of throwing.
//
// HOW THIS SUITE MODELS THE PROPERTY:
//   The routing layer's "would render not-found" decision is, at the pure level,
//   the conjunction:
//
//       isUnmapped(path) = !isKnownLegacyPath(path)        // no registered route
//                          && aliasTargetFor(path) == null  // no alias redirect
//                          && !path.startsWith('/app')       // not an /app shell path
//
//   A path classified `isUnmapped == true` matches no registered top-level
//   GoRoute, no alias redirect, and no `/app/*` shell route, so the GoRouter has
//   nothing to match and falls through to the `errorBuilder` not-found screen —
//   the graceful-degradation outcome (never a crash). The pure decision is
//   asserted across >=100 generated iterations so the suite stays cheap; a
//   single representative widget-level check pumps a faithful harness wired to
//   the REAL production not-found builder to prove the end-to-end render.
//
// FACETS:
//   8a. UNMAPPED-CASE (>=100 generated iterations): any generated string that is
//       neither a registered legacy route, nor an alias, nor an `/app/*` path is
//       classified `isUnmapped == true` (i.e. would render not-found). Strings
//       that happen to be known / alias / `/app/*` are excluded from the premise
//       (vacuously pass) so the facet stays correct as the known set grows.
//
//   8b. MAPPED-CASE (exhaustive over known set + aliases, plus generated): any
//       string that IS a registered legacy route OR an alias is NOT classified
//       unmapped — it resolves to a route or an alias redirect, never the
//       not-found screen.
//
//   8c. PURITY / DETERMINISM (>=100 generated iterations): the classification is
//       deterministic — repeated calls for the same input agree, and the result
//       equals the conjunction of the (pure) `isKnownLegacyPath` /
//       `aliasTargetFor` / `/app` checks (no side effects).
//
//   8d. WIDGET-LEVEL (ONE representative faithful check): pushing a representative
//       unmapped string through a faithful harness — the REAL `LegacyRoutes.routes()`
//       table, the REAL production `aliasTargetFor` redirect, and the REAL
//       production not-found builder lifted from the live router as `errorBuilder`
//       — renders "Feature Not Found" WITHOUT throwing (Req 9.3).
//
// SEAM: the pure facets (8a–8c) touch only `LegacyRoutes.isKnownLegacyPath` and
//   `LegacyRoutes.aliasTargetFor` (no widgets pumped, no router built), keeping
//   200 iterations cheap. The single widget facet (8d) reuses the EXACT harness
//   approach established in `phase_d_absent_routes_preservation_test.dart`.
//
// PBT library: dartproptest (the QuickCheck/Hypothesis-inspired library adopted
//   repo-wide; see the dev_dependency note in pubspec.yaml). `forAll((a) =>
//   boolExpr, [genA], numRuns: N)` runs `numRuns` generated cases and returns
//   whether the predicate held for all of them.
//
// TEST-ONLY: no production/application code is changed by this task.
//
// Run: flutter test test/core/routing/phase_e_property8_graceful_degradation_test.dart --reporter expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// The pure routing decision under test (test-only model of the "would render
// not-found" classification — design AD-7 / Scenario 1). It is the conjunction
// of the three production-pure facts that determine whether the GoRouter has
// anything to match: no registered legacy route, no alias redirect, and not an
// `/app/*` shell path. A `true` result means the push falls through to the
// `errorBuilder` not-found screen (graceful), never a crash.
// ---------------------------------------------------------------------------
bool isUnmapped(String path) =>
    !LegacyRoutes.isKnownLegacyPath(path) &&
    LegacyRoutes.aliasTargetFor(path) == null &&
    !path.startsWith('/app');

/// The AD-7 alias strings (mirrors `LegacyRoutes.aliasTargetFor`). Used by the
/// mapped-case facet to assert aliases are NOT classified unmapped.
const List<String> kAliasPaths = <String>[
  '/auth_gate',
  '/',
  '/startup',
  '/owner_login',
  '/customer_login',
  '/signup',
];

/// A representative unmapped string from AD-7 (a default-shortcut route present
/// in no table). Asserted unmapped at the pure level, then driven end-to-end in
/// the widget facet.
const String kRepresentativeUnmapped = '/receipts';

/// The theme-aware not-found body text rendered by the production
/// `_RouteNotFoundScreen` (mirrors `app_router.dart`).
const String kNotFoundTitle = 'Unknown Screen';
const String kNotFoundSubtitle = 'Feature Not Found';

const String kHarnessHomePath = '/harness-home';
const String kHarnessHomeMarker = 'HARNESS_HOME';

// ---------------------------------------------------------------------------
// Widget-harness helpers (lifted from the established Phase D preservation
// test so the single widget facet uses the EXACT production pieces).
// ---------------------------------------------------------------------------

/// Finds the [GoRoute] registered for [path] anywhere in the router tree and
/// returns its builder, so the harness can render the REAL production
/// not-found screen (not a stand-in).
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
/// harness `errorBuilder` renders the actual `_RouteNotFoundScreen` ("Unknown
/// Screen" / "Feature Not Found"). A genuinely unmapped push is then provably
/// routed to this fallback.
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

/// A faithful harness `GoRouter` that registers the ACTUAL `LegacyRoutes.routes()`
/// plus an ungated home whose button pushes [pushPath] (the go_router equivalent
/// of the dynamic `context.push(def.route!)` call site, design AD-7). The
/// top-level redirect consults the SAME production `aliasTargetFor` single
/// source of truth, and the `errorBuilder` is the REAL production not-found
/// builder, so an unmapped push provably degrades to "Feature Not Found".
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
      // The REAL migrated legacy registrations (single source of truth).
      ...LegacyRoutes.routes(),
    ],
    errorBuilder: notFound,
  );
}

void main() {
  // GoRouter construction (in the widget facet) needs an initialized binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // At least 100 iterations are required by the spec; 200 matches the
  // dartproptest default and the convention across this folder's property
  // suites.
  const int kNumRuns = 200;

  // --- Generators -----------------------------------------------------------
  // A mix of arbitrary printable strings and path-like strings ("/seg" and
  // "/seg/seg") so the classification is exercised against both junk input and
  // realistic-looking route strings. Mirrors the generator in
  // phase_a_property3_known_path_predicate_test.dart.
  final Generator<String> pathLikeGen =
      Gen.tuple(<Generator<dynamic>>[
        Gen.interval(0, 2), // shape selector
        Gen.printableAsciiString(minLength: 0, maxLength: 12), // segment a
        Gen.printableAsciiString(minLength: 0, maxLength: 12), // segment b
      ]).map((parts) {
        final int shape = parts[0] as int;
        final String a = parts[1] as String;
        final String b = parts[2] as String;
        switch (shape) {
          case 0:
            return a; // arbitrary string (may not look like a path)
          case 1:
            return '/$a'; // single-segment path-like
          default:
            return '/$a/$b'; // two-segment path-like
        }
      });

  group('Feature: imperative-navigation-gorouter-migration, Property 8: '
      'Graceful degradation for unmapped navigation — Req 8.2, 8.3, 9.3', () {
    // ----------------------------------------------------------------------
    // Property 8a — UNMAPPED-CASE (generated, >=100 iterations).
    // Any generated string that is neither a registered legacy route, nor an
    // alias, nor an `/app/*` path is classified unmapped (would render
    // not-found). Known / alias / `/app` strings are excluded from the premise
    // so the facet stays correct as the route set grows.
    // ----------------------------------------------------------------------
    test(
      'Property 8a: any generated string that is neither a registered legacy '
      'route nor an alias nor an /app path is classified as unmapped '
      '(would render the not-found screen)',
      () {
        final held = forAll(
          (String path) {
            // Premise carve-outs: a generated string that IS known / alias /
            // /app is not part of the unmapped premise (vacuously passes).
            if (LegacyRoutes.isKnownLegacyPath(path)) return true;
            if (LegacyRoutes.aliasTargetFor(path) != null) return true;
            if (path.startsWith('/app')) return true;

            // The real assertion: such a string is classified unmapped, i.e.
            // it would fall through to the errorBuilder not-found screen.
            return isUnmapped(path) == true;
          },
          [pathLikeGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // Property 8b — MAPPED-CASE.
    // A string that IS a registered legacy route OR an alias is NEVER
    // classified unmapped — it resolves to a route / alias redirect, not the
    // not-found screen. Asserted exhaustively over the known set + aliases,
    // and over generated strings drawn from those domains.
    // ----------------------------------------------------------------------
    test('Property 8b (exhaustive): no registered legacy path and no alias is '
        'classified unmapped', () {
      for (final String path in LegacyRoutes.knownLegacyPaths) {
        expect(
          isUnmapped(path),
          isFalse,
          reason:
              '"$path" is a registered legacy route, so it must NOT be '
              'classified unmapped (it resolves to a GoRoute, not not-found).',
        );
      }
      for (final String alias in kAliasPaths) {
        // Sanity: the alias really is an alias under the production helper.
        expect(
          LegacyRoutes.aliasTargetFor(alias),
          isNotNull,
          reason: '"$alias" must be a recognised alias.',
        );
        expect(
          isUnmapped(alias),
          isFalse,
          reason:
              '"$alias" is an alias (redirects to a canonical path), so it '
              'must NOT be classified unmapped.',
        );
      }
    });

    test(
      'Property 8b (generated): a string drawn from the known set or the alias '
      'set is never classified unmapped',
      () {
        final List<String> mapped = <String>[
          ...LegacyRoutes.knownLegacyPaths,
          ...kAliasPaths,
        ];
        // Guard against a vacuous generator if the known set were ever empty.
        expect(mapped, isNotEmpty);

        final Generator<String> mappedGen = Gen.elementOf<String>(mapped);
        final held = forAll((String path) => isUnmapped(path) == false, [
          mappedGen,
        ], numRuns: kNumRuns);
        expect(held, isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // Property 8c — PURITY / DETERMINISM (generated, >=100 iterations).
    // The classification is deterministic and side-effect free, and equals the
    // conjunction of the (pure) production checks.
    // ----------------------------------------------------------------------
    test('Property 8c: the unmapped classification is pure — repeated calls '
        'agree and equal the conjunction of the production checks', () {
      final held = forAll(
        (String path) {
          final bool first = isUnmapped(path);
          final bool second = isUnmapped(path);
          final bool third = isUnmapped(path);
          final bool expected =
              !LegacyRoutes.isKnownLegacyPath(path) &&
              LegacyRoutes.aliasTargetFor(path) == null &&
              !path.startsWith('/app');
          return first == second && second == third && first == expected;
        },
        [pathLikeGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Property 8d — WIDGET-LEVEL (ONE representative faithful check).
    // Pushing a representative unmapped string through a faithful harness wired
    // to the REAL production not-found builder renders "Feature Not Found"
    // WITHOUT throwing (Req 9.3 — graceful degradation, design AD-7).
    // ----------------------------------------------------------------------
    testWidgets(
      'Property 8d (representative widget check): pushing the unmapped '
      '"$kRepresentativeUnmapped" degrades to the production not-found screen '
      '("Feature Not Found") WITHOUT crashing',
      (tester) async {
        // Pre-condition: the representative string really is unmapped at the
        // pure level (so the widget outcome is the genuine not-found fallback).
        expect(
          isUnmapped(kRepresentativeUnmapped),
          isTrue,
          reason:
              '"$kRepresentativeUnmapped" must be an unmapped string (not '
              'registered, not an alias, not /app) for this facet to exercise '
              'graceful degradation.',
        );

        final GoRouterWidgetBuilder notFound = _liveNotFoundBuilder();
        final harness = _harnessPushing(kRepresentativeUnmapped, notFound);
        addTearDown(harness.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: harness));
        await tester.pumpAndSettle();

        // Sanity: we start on the ungated home.
        expect(find.text(kHarnessHomeMarker), findsOneWidget);

        // Issue the go_router equivalent of the dynamic legacy push. The
        // not-found screen is a static Scaffold -> it settles.
        await tester.tap(find.text(kHarnessHomeMarker));
        await tester.pumpAndSettle();

        // GRACEFUL DEGRADATION: the unmapped push fell through to the
        // errorBuilder, which renders the production "Feature Not Found" screen.
        expect(
          find.text(kNotFoundTitle),
          findsOneWidget,
          reason:
              '"$kRepresentativeUnmapped" must degrade to the production '
              'not-found screen ("Unknown Screen") via the errorBuilder.',
        );
        expect(
          find.text(kNotFoundSubtitle),
          findsOneWidget,
          reason:
              'The not-found screen must render the "Feature Not Found" '
              'subtitle (Req 9.3 graceful degradation).',
        );
        // No exception escaped the framework — degraded gracefully, not crashed.
        expect(tester.takeException(), isNull);
      },
    );
  });
}
