// ============================================================================
// PHASE A — Task 2.4: PROPERTY TEST
// Feature: imperative-navigation-gorouter-migration
// Property 7: Alias idempotence and loop-freedom
// **Validates: Requirements 7.7**
// ============================================================================
//
// Property 7 (design.md, Correctness Properties):
//   "For all alias paths, applying the alias resolution to an already-canonical
//    target returns that target unchanged or null, so that resolution is
//    idempotent and introduces no redirect loop."
//
// Unit under test: the PURE, TOTAL function
//   `LegacyRoutes.aliasTargetFor(String) -> String?` (design.md AD-6,
//   Component 1). It maps a legacy alias path to its canonical go_router target
//   (drawn from `RoutePaths`) or `null` for a non-alias. Having no Flutter /
//   platform dependencies, it is fully property-testable in isolation — no
//   widget pumping, no GoRouterState construction.
//
// What the property pins down:
//   * ONE-HOP TERMINATION (loop-freedom): for ANY string s, if s is an alias
//     (`aliasTargetFor(s) != null`) then its target is itself NOT an alias key,
//     i.e. `aliasTargetFor(aliasTargetFor(s)!) == null`. The redirect chain can
//     never cycle — every resolution settles on a canonical target in exactly
//     one hop.
//   * CANONICAL TARGETS ARE FIXED POINTS: each canonical target produced by the
//     map (`/auth-gate`, `/splash`, `/login`) is NOT an alias key, so resolving
//     an already-canonical target yields `null` (no further redirect).
//   * NON-ALIAS -> null: any generated string that is neither an alias key
//     resolves to `null` (it is left unchanged by the redirect layer).
//   * DETERMINISM / PURITY: same input always yields the same output.
//
// PBT library: dartproptest ^0.2.1 — the QuickCheck/Hypothesis-inspired library
//   adopted repo-wide (glados is unresolvable here; see the dev_dependency note
//   in pubspec.yaml). The variadic `forAll((a) => boolExpr, [gen], numRuns: N)`
//   runs `numRuns` generated cases and returns whether the predicate held.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/core/routing/phase_a_property7_alias_idempotence_test.dart --reporter expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/routing/legacy_routes.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required by the spec; 200 matches the default
  // and the convention used across the other property suites in this folder.
  const int kNumRuns = 200;

  // --- Input space ----------------------------------------------------------
  // The complete set of legacy alias keys (design.md AD-6 / Req 7.2-7.5).
  const List<String> aliasKeys = <String>[
    '/auth_gate',
    '/',
    '/startup',
    '/owner_login',
    '/customer_login',
    '/signup',
  ];

  // The canonical targets the alias map can produce. Sourced from RoutePaths so
  // the test tracks the production constants (no hand-copied strings to rot).
  final List<String> canonicalTargets = <String>[
    RoutePaths.authGate, // '/auth-gate'  <- /auth_gate, /startup
    RoutePaths.splash, // '/splash'      <- /
    RoutePaths
        .login, // '/login'        <- /owner_login, /customer_login, /signup
  ];

  // --- Generators -----------------------------------------------------------
  final Generator<String> aliasGen = Gen.elementOf<String>(aliasKeys);
  final Generator<String> canonicalGen = Gen.elementOf<String>(
    canonicalTargets,
  );
  // Arbitrary strings to probe the non-alias -> null and universal
  // loop-freedom boundary. A generated string could, in principle, collide with
  // an alias key; each predicate handles that case explicitly so it stays
  // correct regardless of collision.
  final Generator<String> arbitraryStringGen = Gen.string(
    minLength: 0,
    maxLength: 16,
  );

  group('Feature: imperative-navigation-gorouter-migration, Property 7: Alias '
      'idempotence and loop-freedom — Req 7.7', () {
    // --------------------------------------------------------------------
    // Sanity: the alias keys and canonical targets are exactly what AD-6
    // describes, so a future edit to the map that changes the surface is
    // caught here too.
    // --------------------------------------------------------------------
    setUpAll(() {
      // Every alias key resolves to a non-null canonical target...
      for (final key in aliasKeys) {
        expect(
          LegacyRoutes.aliasTargetFor(key),
          isNotNull,
          reason: 'alias key "$key" must resolve to a canonical target.',
        );
      }
      // ...and the produced targets are exactly the three canonical paths.
      expect(
        aliasKeys.map(LegacyRoutes.aliasTargetFor).toSet(),
        canonicalTargets.toSet(),
        reason: 'alias map must produce exactly the canonical RoutePaths.',
      );
      // No canonical target is itself an alias key (disjoint), which is the
      // structural reason loop-freedom holds.
      for (final target in canonicalTargets) {
        expect(
          aliasKeys.contains(target),
          isFalse,
          reason: 'canonical target "$target" must not be an alias key.',
        );
      }
    });

    // --------------------------------------------------------------------
    // Property 7a — ONE-HOP TERMINATION over the alias keys.
    // For every alias key, the target is non-null AND resolving the target
    // again yields null: the chain settles on a canonical path in one hop.
    // --------------------------------------------------------------------
    test(
      'Property 7: every alias resolves to a canonical target in exactly one '
      'hop (re-resolving the target yields null)',
      () {
        final held = forAll(
          (String alias) {
            final String? target = LegacyRoutes.aliasTargetFor(alias);
            if (target == null) return false; // every alias key has a target
            // The target is canonical -> NOT itself an alias -> null.
            return LegacyRoutes.aliasTargetFor(target) == null;
          },
          [aliasGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // --------------------------------------------------------------------
    // Property 7b — CANONICAL TARGETS ARE FIXED POINTS.
    // Applying alias resolution to an already-canonical target returns null
    // (it is left unchanged by the redirect layer — no second redirect).
    // --------------------------------------------------------------------
    test('Property 7: an already-canonical target is not an alias '
        '(aliasTargetFor returns null) — idempotent, no further redirect', () {
      final held = forAll(
        (String canonical) {
          return LegacyRoutes.aliasTargetFor(canonical) == null;
        },
        [canonicalGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // --------------------------------------------------------------------
    // Property 7c — UNIVERSAL LOOP-FREEDOM over arbitrary strings.
    // For ANY string s: either s is a non-alias (target == null, left
    // unchanged) OR its target is canonical and re-resolving terminates
    // (aliasTargetFor(target) == null). In neither case is there a cycle.
    // --------------------------------------------------------------------
    test(
      'Property 7: for any input string, alias resolution terminates within '
      'one hop with no cycle (non-alias -> null; alias -> canonical -> null)',
      () {
        final held = forAll(
          (String s) {
            final String? target = LegacyRoutes.aliasTargetFor(s);
            if (target == null) {
              // Non-alias: left unchanged, no redirect, trivially loop-free.
              return true;
            }
            // Alias: the one-hop target must be a terminal canonical path
            // (resolving it again must not produce another redirect).
            if (target == s) return false; // a self-alias would loop
            return LegacyRoutes.aliasTargetFor(target) == null;
          },
          [arbitraryStringGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // --------------------------------------------------------------------
    // Property 7d — DETERMINISM / PURITY.
    // Same input always yields the same output (no side effects, total).
    // --------------------------------------------------------------------
    test('Property 7: aliasTargetFor is deterministic — repeated calls on the '
        'same input return the same result', () {
      final held = forAll(
        (String s) {
          return LegacyRoutes.aliasTargetFor(s) ==
              LegacyRoutes.aliasTargetFor(s);
        },
        [arbitraryStringGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
