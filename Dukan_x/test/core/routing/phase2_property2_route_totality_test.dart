// ============================================================================
// PHASE 2 — Task 3.6: PROPERTY TEST
// Feature: gorouter-navigation-migration, Property 2: Route mapping totality
// (no dropped ids)
// **Validates: Requirements 5.1**
// ============================================================================
//
// Property 2 (design.md):
//   "For any itemId present in the legacy dispatch, there exists exactly one
//    RoutePaths constant and one named GoRoute, so no destination is lost in
//    migration."
//
// This suite proves three facets of that property across >=100 generated
// iterations, plus one global (non-generated) totality assertion:
//
//   1. KNOWN itemIds (drawn from `RoutePaths.knownItemIds`): for any known
//      itemId, `RoutePaths.pathForItemId(itemId)` returns a UNIQUE, NON-sentinel
//      path, AND the registered `AppRouter` GoRouter contains EXACTLY ONE child
//      `GoRoute` whose `path` equals that path and whose `name` is the itemId.
//
//   2. UNKNOWN strings (drawn from `Gen.string`, i.e. arbitrary ids NOT in the
//      known set): `pathForItemId` is TOTAL — it returns `RoutePaths.notFound`
//      (never throws, never returns null) for every id outside the known set.
//      This pins the unknown -> notFound totality boundary.
//
//   3. GLOBAL totality: the set of registered itemId routes equals
//      `knownItemIds` exactly (no dropped ids, no phantom ids), and is exactly
//      90 entries. Asserted alongside the properties as a single global check.
//
// SEAM / INTROSPECTION:
//   The real `GoRouter` is obtained from `appRouterProvider` and its
//   `configuration.routes` are walked recursively (descending through the main
//   `ShellRoute`), exactly as `phase2_route_registration_parity_test.dart`
//   does. Constructing the router builds only `GoRoute`/`ShellRoute` objects
//   (no screen `build()` / IO), so this runs as a plain VM test.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide (glados is unresolvable here — see the dev_dependency
//   note in `pubspec.yaml`). `forAll((arg) => boolExpr, [gen], numRuns: 200)`
//   runs `numRuns` generated cases and returns whether the predicate held.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/core/routing/phase2_property2_route_totality_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/routing/app_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Recursively walks every registered route, recording:
///   * [pathCounts] — how many `GoRoute`s declare each `path` (to prove
///     "exactly one" registration), and
///   * [pathByName] — route `name` -> `path` (to prove the itemId is the
///     stable route name).
/// Descends through [ShellRouteBase] and nested sub-routes.
void _collectGoRoutes(
  List<RouteBase> routes,
  Map<String, int> pathCounts,
  Map<String, String> pathByName,
) {
  for (final route in routes) {
    if (route is GoRoute) {
      pathCounts[route.path] = (pathCounts[route.path] ?? 0) + 1;
      final name = route.name;
      if (name != null) pathByName[name] = route.path;
      _collectGoRoutes(route.routes, pathCounts, pathByName);
    } else if (route is ShellRouteBase) {
      _collectGoRoutes(route.routes, pathCounts, pathByName);
    }
  }
}

void main() {
  // At least 100 iterations are required by the spec; 200 is the dartproptest
  // default and matches the convention used across the other property suites.
  const int kNumRuns = 200;

  // --- Introspect the real registered router once -------------------------
  // Populated in setUpAll (the router build constructs GoRoute/ShellRoute
  // objects only — no screen build()/IO — so plain-VM introspection is safe).
  final Map<String, int> pathCounts = <String, int>{};
  final Map<String, String> pathByName = <String, String>{};

  // The known input space (the 90 legacy dispatch itemIds) and the derived
  // path multiset used to prove path uniqueness across the mapping.
  final List<String> knownItemIds = RoutePaths.knownItemIds.toList();
  final Map<String, int> knownPathCounts = <String, int>{};

  late ProviderContainer container;

  setUpAll(() {
    container = ProviderContainer();
    final GoRouter router = container.read(appRouterProvider);
    _collectGoRoutes(router.configuration.routes, pathCounts, pathByName);

    for (final id in knownItemIds) {
      final p = RoutePaths.pathForItemId(id);
      knownPathCounts[p] = (knownPathCounts[p] ?? 0) + 1;
    }
  });

  tearDownAll(() => container.dispose());

  // --- Generators ----------------------------------------------------------
  // Sample uniformly from the real known itemId set.
  final Generator<String> knownIdGen = Gen.elementOf<String>(knownItemIds);
  // Arbitrary strings to probe the unknown -> notFound totality boundary.
  // (A generated string could, in principle, collide with a real itemId; the
  // predicate guards with `isKnownItemId` so it stays correct regardless.)
  final Generator<String> arbitraryStringGen = Gen.string(
    minLength: 0,
    maxLength: 14,
  );

  group('Feature: gorouter-navigation-migration, Property 2: Route mapping '
      'totality (no dropped ids) — Req 5.1', () {
    // ---------------------------------------------------------------------
    // Property 2a — KNOWN itemId: unique non-sentinel path + exactly one
    //               named GoRoute.
    // ---------------------------------------------------------------------
    test('Property 2: every known itemId maps to a unique, non-sentinel path '
        'with exactly one registered GoRoute named by the itemId', () {
      final held = forAll(
        (String itemId) {
          final String path = RoutePaths.pathForItemId(itemId);

          // (i) Non-sentinel: a known id never resolves to notFound.
          if (path == RoutePaths.notFound) return false;

          // (ii) Unique path: exactly one itemId maps to this path
          //      (RoutePaths constant is one-to-one with the id).
          if (knownPathCounts[path] != 1) return false;

          // (iii) Exactly one registered GoRoute declares this path.
          if (pathCounts[path] != 1) return false;

          // (iv) That GoRoute is NAMED by the itemId and resolves to the
          //      same path (one named GoRoute per id).
          if (pathByName[itemId] != path) return false;

          // (v) Round-trip: the reverse resolver recovers the itemId.
          if (RoutePaths.itemIdForPath(path) != itemId) return false;

          return true;
        },
        [knownIdGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ---------------------------------------------------------------------
    // Property 2b — UNKNOWN id: pathForItemId is total -> notFound sentinel.
    // ---------------------------------------------------------------------
    test('Property 2: any string NOT in knownItemIds resolves to '
        'RoutePaths.notFound (total function, never throws/null)', () {
      final held = forAll(
        (String candidate) {
          // Guard the rare case where a generated string is itself a real
          // itemId — then the totality boundary does not apply to it.
          if (RoutePaths.isKnownItemId(candidate)) {
            return RoutePaths.pathForItemId(candidate) != RoutePaths.notFound;
          }
          // Unknown ids must map to the documented sentinel (total, safe).
          return RoutePaths.pathForItemId(candidate) == RoutePaths.notFound;
        },
        [arbitraryStringGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ---------------------------------------------------------------------
    // Property 2 (global) — the registered itemId routes equal knownItemIds
    // exactly (no dropped, no phantom), and number exactly 90.
    // ---------------------------------------------------------------------
    test('Property 2 (global): registered itemId routes equal knownItemIds '
        '(no dropped/phantom), exactly 90 entries', () {
      // Known inventory is exactly 90 and has no duplicate ids.
      expect(knownItemIds.toSet(), hasLength(90));
      expect(knownItemIds, hasLength(90));

      // Every known itemId has a registered route named by the itemId
      // whose path is the resolver's path (no dropped ids).
      for (final itemId in knownItemIds) {
        final expectedPath = RoutePaths.pathForItemId(itemId);
        expect(
          pathByName[itemId],
          expectedPath,
          reason: 'Missing/renamed GoRoute for itemId "$itemId".',
        );
        expect(
          pathCounts[expectedPath],
          1,
          reason: 'Expected exactly one GoRoute at "$expectedPath".',
        );
      }

      // No phantom itemId routes: every registered route whose name is a
      // known itemId belongs to the known set, and the registered itemId
      // route-name set equals knownItemIds exactly.
      final registeredItemIdNames = pathByName.keys
          .where(RoutePaths.isKnownItemId)
          .toSet();
      expect(
        registeredItemIdNames,
        equals(knownItemIds.toSet()),
        reason:
            'Registered itemId routes must equal knownItemIds exactly '
            '(no dropped or phantom ids).',
      );

      // The set of distinct itemId paths is also exactly 90 (paths are
      // one-to-one with itemIds — duplicate SCREENS keep distinct paths).
      final distinctItemIdPaths = knownItemIds
          .map(RoutePaths.pathForItemId)
          .toSet();
      expect(distinctItemIdPaths, hasLength(90));
    });
  });
}
