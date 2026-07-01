// ============================================================================
// PHASE B — Task 4.6 (OPTIONAL PROPERTY TEST)
// Feature: imperative-navigation-gorouter-migration
// Property 2: Every known legacy string resolves to exactly one registered route
// **Validates: Requirements 2.6, 3.1, 3.4, 9.2**
// ============================================================================
//
// Property 2 (design.md — Correctness Properties):
//   "For any string in `LegacyRoutes.knownLegacyPaths`, navigating to that
//    string under `AppRouter` resolves to exactly one registered top-level
//    `GoRoute` whose `path` equals that string, and never falls through to the
//    empty-root-table failure. The registered legacy path set and the
//    inventoried legacy string set are equal (parity)."
//
// This suite proves the two facets of that property against the PURE route
// list produced by `LegacyRoutes.routes()` (no router pumped, no widgets
// built — the GoRoute `path` strings are inspected directly), so 100+
// iterations stay cheap:
//
//   2a. RESOLUTION (property, >=100 generated iterations): for every string in
//       `LegacyRoutes.knownLegacyPaths`, there is EXACTLY ONE top-level
//       `GoRoute` in `LegacyRoutes.routes()` whose `path` equals that string.
//       Exactly-one (not zero, not two) means the string resolves to a single
//       registered route and never hits the empty-root failure, and that no
//       duplicate registration exists. The known set has ~120 entries, so an
//       index generator over the set produces well over 100 distinct cases;
//       repetition across `numRuns` simply re-checks the invariant.
//
//   2b. PARITY (exhaustive set equality): the set of `path`s registered by
//       `routes()` equals `knownLegacyPaths` exactly — no path registered
//       without being declared known, and no known path without a route.
//
// SEAM: `LegacyRoutes.routes()` returns a `List<RouteBase>` whose `GoRoute`
//   entries expose `path` synchronously; `LegacyRoutes.knownLegacyPaths` is a
//   pure set. Neither requires a `WidgetTester` or a live `GoRouter`.
//
// PBT library: dartproptest ^0.2.1 (the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide; see the dev_dependency note in pubspec.yaml). The
//   variadic `forAll((a) => boolExpr, [genA], numRuns: N)` runs `numRuns`
//   generated cases and returns whether the predicate held for all of them.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/core/routing/phase_b_property2_resolution_parity_test.dart --reporter expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Recursively collects every `GoRoute.path` reachable from [routes],
/// descending into any nested `routes` (sub-routes / shell children) so the
/// walk stays correct even if the legacy layer grows nested entries later.
List<String> _collectGoRoutePaths(List<RouteBase> routes) {
  final List<String> paths = <String>[];
  for (final RouteBase route in routes) {
    if (route is GoRoute) {
      paths.add(route.path);
    }
    // RouteBase exposes its children via `routes`; recurse for completeness.
    if (route.routes.isNotEmpty) {
      paths.addAll(_collectGoRoutePaths(route.routes));
    }
  }
  return paths;
}

void main() {
  // At least 100 iterations are required by the spec; 200 matches the
  // dartproptest default and the convention used across the other property
  // suites in this folder.
  const int kNumRuns = 200;

  // The registered route paths, captured ONCE (pure, no widgets). A List (not
  // a Set) so duplicate registrations are detectable.
  final List<String> registeredPaths = _collectGoRoutePaths(
    LegacyRoutes.routes(),
  );
  final Set<String> registeredPathSet = registeredPaths.toSet();

  // Frequency of each registered path — used to assert exactly-one resolution.
  final Map<String, int> registeredCounts = <String, int>{};
  for (final String p in registeredPaths) {
    registeredCounts[p] = (registeredCounts[p] ?? 0) + 1;
  }

  // The inventoried known set, as an indexable list for the generator. Sorted
  // for deterministic indexing.
  final List<String> knownList = LegacyRoutes.knownLegacyPaths.toList()..sort();

  group('Feature: imperative-navigation-gorouter-migration, Property 2: Every '
      'known legacy string resolves to exactly one registered route — '
      'Req 2.6, 3.1, 3.4, 9.2', () {
    // Guard: the property is meaningless if the inventory is empty. Phase B
    // registers ~120 routes, so this also documents the expectation.
    test('precondition: knownLegacyPaths is populated (Phase B registered the '
        'legacy families)', () {
      expect(
        knownList,
        isNotEmpty,
        reason:
            'Property 2 requires a populated known-path inventory; '
            'LegacyRoutes.routes() must register the Phase B families.',
      );
    });

    // ----------------------------------------------------------------------
    // Property 2a — RESOLUTION (generated, >=100 iterations).
    // For an index drawn over knownLegacyPaths, the corresponding string is
    // registered by EXACTLY ONE GoRoute (never zero -> would be the empty-root
    // failure; never >1 -> would be a duplicate registration).
    // ----------------------------------------------------------------------
    test(
      'Property 2a: every string in knownLegacyPaths resolves to exactly one '
      'registered GoRoute (never the empty-root failure)',
      () {
        // Generator over indices into the known set. `Gen.interval` is
        // inclusive, so [0, length-1] covers every entry; across kNumRuns
        // (>=100) the invariant is re-checked with repetition for small sets.
        final Generator<int> indexGen = Gen.interval(0, knownList.length - 1);

        final held = forAll(
          (int index) {
            final String path = knownList[index];
            final int count = registeredCounts[path] ?? 0;
            // Exactly one registered route with this path.
            return count == 1;
          },
          [indexGen],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'Each known legacy path must be registered by exactly one '
              'top-level GoRoute. Counts: '
              '${{for (final p in knownList) p: registeredCounts[p] ?? 0}}',
        );
      },
    );

    // ----------------------------------------------------------------------
    // Property 2b — PARITY (exhaustive set equality).
    // The registered path set equals the known set: no orphan registration,
    // no known path missing a route.
    // ----------------------------------------------------------------------
    test('Property 2b: registered GoRoute path set equals knownLegacyPaths '
        '(parity — no orphan routes, no unregistered known paths)', () {
      final Set<String> known = LegacyRoutes.knownLegacyPaths;

      final Set<String> registeredButNotKnown = registeredPathSet.difference(
        known,
      );
      final Set<String> knownButNotRegistered = known.difference(
        registeredPathSet,
      );

      expect(
        registeredButNotKnown,
        isEmpty,
        reason:
            'These paths are registered by routes() but absent from '
            'knownLegacyPaths (orphan registrations): $registeredButNotKnown',
      );
      expect(
        knownButNotRegistered,
        isEmpty,
        reason:
            'These paths are declared in knownLegacyPaths but have no '
            'registered GoRoute (resolution gap): $knownButNotRegistered',
      );
      expect(registeredPathSet, equals(known));
    });

    // ----------------------------------------------------------------------
    // No-duplicate sanity (reinforces 2a): the registered list has no repeats,
    // so |list| == |set|.
    // ----------------------------------------------------------------------
    test('Property 2 (no duplicates): routes() registers each path at most '
        'once', () {
      expect(
        registeredPaths.length,
        equals(registeredPathSet.length),
        reason:
            'Duplicate GoRoute path registration detected. Registered '
            'count=${registeredPaths.length}, unique=${registeredPathSet.length}.',
      );
    });
  });
}
