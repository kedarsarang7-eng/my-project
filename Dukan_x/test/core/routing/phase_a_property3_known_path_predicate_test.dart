// ============================================================================
// PHASE A — Task 2.5 (OPTIONAL PROPERTY TEST)
// Feature: imperative-navigation-gorouter-migration
// Property 3: Known-path predicate correctness
// **Validates: Requirements 3.5, 8.4**
// ============================================================================
//
// Property 3 (design.md — Correctness Properties):
//   "For any string in `LegacyRoutes.knownLegacyPaths`, `isKnownLegacyPath`
//    returns `true`; for any generated string that is neither a registered
//    legacy route nor an alias, `isKnownLegacyPath` returns `false`. The
//    predicate is pure (no side effects, same input yields same output)."
//
// This suite proves three facets of that property:
//
//   3a. TRUE-CASE (exhaustive over the registered set): every path in
//       `LegacyRoutes.knownLegacyPaths` satisfies `isKnownLegacyPath == true`.
//       The set is iterated (never hardcoded) so this facet stays correct as
//       later tasks (4.2–4.5, 6.2, 7.1) populate the set. The set is currently
//       EMPTY (Task 2.2 skeleton), so the facet holds vacuously today and
//       tightens automatically as routes are registered.
//
//   3b. FALSE-CASE (>=100 generated iterations): for any generated string that
//       is neither a registered legacy route nor an alias (AD-6),
//       `isKnownLegacyPath` returns `false`. Strings that happen to be a known
//       path or an alias are excluded from the premise (vacuously pass) so the
//       facet remains correct as the known set grows.
//
//   3c. PURITY / DETERMINISM (>=100 generated iterations): `isKnownLegacyPath`
//       yields the same result on repeated calls for the same input (no side
//       effects) and that result equals membership in `knownLegacyPaths`.
//
// SEAM: the predicate `LegacyRoutes.isKnownLegacyPath(String)` and the
//   `LegacyRoutes.knownLegacyPaths` set are PURE — no widgets pumped, no router
//   built. This keeps 200 iterations cheap.
//
// PBT library: dartproptest ^0.2.1 (the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide; glados is unresolvable here — see the dev_dependency
//   note in pubspec.yaml). The variadic `forAll((a) => boolExpr, [genA],
//   numRuns: N)` runs `numRuns` generated cases and returns whether the
//   predicate held for all of them.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/core/routing/phase_a_property3_known_path_predicate_test.dart --reporter expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required by the spec; 200 matches the
  // dartproptest default and the convention used across the other property
  // suites in this folder.
  const int kNumRuns = 200;

  // --- Generators -----------------------------------------------------------
  // A mix of arbitrary printable strings and path-like strings ("/seg" and
  // "/seg/seg"), so the predicate is exercised against both junk input and
  // realistic-looking route strings. Empty and short segments are included to
  // cover boundary cases.
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

  group('Feature: imperative-navigation-gorouter-migration, Property 3: '
      'Known-path predicate correctness — Req 3.5, 8.4', () {
    // ----------------------------------------------------------------------
    // Property 3a — TRUE-CASE (exhaustive over the registered set).
    // Iterates the set rather than hardcoding, so it holds for the current
    // EMPTY skeleton set AND stays correct as later tasks populate it.
    // ----------------------------------------------------------------------
    test('Property 3a: every path in knownLegacyPaths is reported as known '
        '(holds vacuously for the current empty skeleton set)', () {
      for (final String path in LegacyRoutes.knownLegacyPaths) {
        expect(
          LegacyRoutes.isKnownLegacyPath(path),
          isTrue,
          reason:
              '"$path" is in knownLegacyPaths so isKnownLegacyPath must '
              'return true.',
        );
      }
    });

    // ----------------------------------------------------------------------
    // Property 3b — FALSE-CASE (generated, >=100 iterations).
    // ----------------------------------------------------------------------
    test(
      'Property 3b: any generated string that is neither a registered legacy '
      'route nor an alias is reported as NOT known',
      () {
        final held = forAll(
          (String path) {
            // Exclude the two premise carve-outs so the facet is asserted
            // only where it should be false. These vacuously pass and keep
            // the property correct as knownLegacyPaths grows.
            if (LegacyRoutes.knownLegacyPaths.contains(path)) return true;
            if (LegacyRoutes.aliasTargetFor(path) != null) return true;

            // The real assertion: an unregistered, non-alias string is never
            // reported as a known legacy path.
            return LegacyRoutes.isKnownLegacyPath(path) == false;
          },
          [pathLikeGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // Property 3c — PURITY / DETERMINISM (generated, >=100 iterations).
    // ----------------------------------------------------------------------
    test('Property 3c: isKnownLegacyPath is pure — same input yields the same '
        'result on repeated calls and equals knownLegacyPaths membership', () {
      final held = forAll(
        (String path) {
          final bool first = LegacyRoutes.isKnownLegacyPath(path);
          final bool second = LegacyRoutes.isKnownLegacyPath(path);
          final bool third = LegacyRoutes.isKnownLegacyPath(path);
          final bool membership = LegacyRoutes.knownLegacyPaths.contains(path);
          return first == second && second == third && first == membership;
        },
        [pathLikeGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
