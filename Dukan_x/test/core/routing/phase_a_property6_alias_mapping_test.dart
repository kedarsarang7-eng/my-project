// ============================================================================
// PHASE A — Task 2.3: PROPERTY TEST
// Feature: imperative-navigation-gorouter-migration, Property 6: Alias mapping
// **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**
// ============================================================================
//
// Property 6 (design.md):
//   "For any alias path, `LegacyRoutes.aliasTargetFor` returns its canonical
//    target — `/auth_gate`->`/auth-gate`, `/`->`/splash`, `/startup`->`/auth-gate`,
//    and `/owner_login`/`/customer_login`/`/signup`->`/login` — and for any
//    non-alias path it returns `null`."
//
// `aliasTargetFor` is a PURE, TOTAL function over `String` (AD-6), so it is
// asserted directly with no widget pumping. Canonical targets are pinned to the
// `RoutePaths` constants (never hardcoded strings) so the test tracks the
// foundation routes exactly as the production decision function does.
//
// This suite proves two facets of Property 6:
//
//   6a. ALIAS -> CANONICAL (Req 7.1-7.4): for every one of the six alias inputs,
//       `aliasTargetFor` returns the EXACT canonical `RoutePaths` target. Driven
//       as a property over a generator that draws from the alias set, so each
//       alias is exercised across the run (>= 100 iterations).
//
//   6b. NON-ALIAS -> null (Req 7.5): for any generated string that is NOT one of
//       the six aliases, `aliasTargetFor` returns `null`. Driven over a
//       printable-ASCII string generator (plus path-shaped strings) with the six
//       aliases excluded by construction (>= 100 iterations).
//
// PBT library: dartproptest (NOT glados), matching the other property suites in
//   this folder. `forAll((x) => boolExpr, [gen], numRuns: N)` runs `numRuns`
//   generated cases and returns whether the predicate held for all of them.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/core/routing/phase_a_property6_alias_mapping_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required by the spec; 200 matches the
  // convention used across the other property suites in this folder.
  const int kNumRuns = 200;

  // --- Input space ----------------------------------------------------------
  // The six alias inputs paired with their EXACT canonical target. Targets are
  // the RoutePaths constants (AD-6) — never hardcoded — so this stays in sync
  // with the foundation routes by construction.
  final Map<String, String> aliasToCanonical = <String, String>{
    '/auth_gate': RoutePaths.authGate, // Req 7.1
    '/': RoutePaths.splash, // Req 7.2 (logout/splash)
    '/startup': RoutePaths.authGate, // Req 7.3 (legacy AuthGate entry)
    '/owner_login': RoutePaths.login, // Req 7.4
    '/customer_login': RoutePaths.login, // Req 7.4
    '/signup': RoutePaths.login, // Req 7.4
  };

  final List<String> aliasPaths = aliasToCanonical.keys.toList();
  // The exact alias set, used to EXCLUDE aliases from the non-alias generator.
  final Set<String> aliasSet = aliasToCanonical.keys.toSet();

  // --- Generators -----------------------------------------------------------
  // 6a generator: draw from the six alias inputs.
  final Generator<String> aliasGen = Gen.elementOf<String>(aliasPaths);

  // 6b generator: arbitrary printable-ASCII strings (covers empty, random
  // tokens, and path-like values) for the "non-alias -> null" facet. Aliases
  // are filtered out inside the predicate so generation stays unconstrained.
  final Generator<String> arbitraryGen = Gen.printableAsciiString(
    minLength: 0,
    maxLength: 24,
  );

  group('Feature: imperative-navigation-gorouter-migration, Property 6: '
      'Alias mapping — Req 7.1, 7.2, 7.3, 7.4, 7.5', () {
    // ----------------------------------------------------------------------
    // Property 6a — every alias input resolves to its EXACT canonical target.
    // ----------------------------------------------------------------------
    test('Property 6: every alias path maps to its exact canonical RoutePaths '
        'target (/auth_gate->authGate, /->splash, /startup->authGate, '
        '/owner_login|/customer_login|/signup->login)', () {
      final bool held = forAll(
        (String alias) {
          final String expected = aliasToCanonical[alias]!;
          return LegacyRoutes.aliasTargetFor(alias) == expected;
        },
        [aliasGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Property 6b — any NON-alias string returns null.
    // ----------------------------------------------------------------------
    test(
      'Property 6: any non-alias string returns null from aliasTargetFor',
      () {
        final bool held = forAll(
          (String s) {
            // Exclude the six aliases by construction; for everything else
            // the function must return null (Req 7.5). Generated aliases are
            // covered by Property 6a, so treat them as vacuously holding.
            if (aliasSet.contains(s)) return true;
            return LegacyRoutes.aliasTargetFor(s) == null;
          },
          [arbitraryGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ----------------------------------------------------------------------
    // Deterministic anchors — pin each named mapping explicitly so a wrong
    // target is caught with a precise message (complements the properties).
    // ----------------------------------------------------------------------
    test('Property 6 (anchors): the six named aliases map exactly', () {
      expect(LegacyRoutes.aliasTargetFor('/auth_gate'), RoutePaths.authGate);
      expect(LegacyRoutes.aliasTargetFor('/'), RoutePaths.splash);
      expect(LegacyRoutes.aliasTargetFor('/startup'), RoutePaths.authGate);
      expect(LegacyRoutes.aliasTargetFor('/owner_login'), RoutePaths.login);
      expect(LegacyRoutes.aliasTargetFor('/customer_login'), RoutePaths.login);
      expect(LegacyRoutes.aliasTargetFor('/signup'), RoutePaths.login);
    });

    test('Property 6 (anchors): representative non-aliases return null', () {
      for (final String s in <String>[
        '',
        '/login', // a canonical target is NOT an alias
        '/splash',
        '/auth-gate',
        '/app/new-sale',
        '/unknown',
        'auth_gate', // missing leading slash
        '/AUTH_GATE', // case-sensitive
      ]) {
        expect(
          LegacyRoutes.aliasTargetFor(s),
          isNull,
          reason: '"$s" is not an alias and must return null.',
        );
      }
    });
  });
}
