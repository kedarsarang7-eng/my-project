// ============================================================================
// PHASE E — Task 8.6: PROPERTY TEST
// Feature: imperative-navigation-gorouter-migration, Property 1: Navigation-
//          verb mapping
// **Validates: Requirements 2.2, 2.3, 2.4, 6.1**
// ============================================================================
//
// Property 1 (design.md):
//   "For any inventoried call site, mapping its legacy navigation verb to the
//    go_router replacement is deterministic and total: `pushNamed` maps to
//    `push`, `pushReplacementNamed` maps to `pushReplacement`, and a
//    stack-clearing `pushNamedAndRemoveUntil` maps to `go`; any call site that
//    consumes a return value maps to `push` regardless of its legacy verb."
//
// AD-5 verb-mapping table (design.md):
//   pushNamed                          -> push            (Req 2.2)
//   await pushNamed (result)           -> push            (Req 6.1 override)
//   pushReplacementNamed               -> pushReplacement (Req 2.3)
//   pushNamedAndRemoveUntil(clear)     -> go              (Req 2.4)
//
// The verb mapping is a PURE, TOTAL function over
//   (LegacyVerb legacyVerb, bool consumesReturnValue)
// so it is modelled directly in this test and asserted with no widget pumping.
// This mirrors the dartproptest harness used by the other property suites in
// this folder (phase_a_property6_alias_mapping_test.dart).
//
// The Req 6.1 return-value override takes precedence: ANY call site that
// consumes a return value MUST map to `push`, regardless of the legacy verb it
// was written with (because `go`/`pushReplacement` do not return a result
// Future — see AD-4). The model below encodes that precedence rule explicitly.
//
// This suite proves three facets of Property 1 over all
// (legacyVerb, consumesReturnValue) combinations:
//
//   1a. TOTAL + per-verb mapping: every generated combination yields exactly
//       one defined go_router verb, matching the AD-5 table (with the Req 6.1
//       override applied).
//   1b. DETERMINISTIC: the same input always produces the same output.
//   1c. RETURN-VALUE OVERRIDE: consumesReturnValue == true always maps to
//       `push`, regardless of legacy verb (Req 6.1).
//
// PBT library: dartproptest (NOT glados), matching the sibling property suites.
//   `forAll((a, b) => boolExpr, [genA, genB], numRuns: N)` runs `numRuns`
//   generated cases and returns whether the predicate held for all of them.
//
// TEST-ONLY: no production code is changed by this task. The mapping is modelled
// here as the contract the mechanical call-site conversion (Component 3) must
// follow; it is the design-time decision table, not lifted production code.
//
// Run: flutter test test/core/routing/phase_e_property1_verb_mapping_test.dart \
//        --reporter expanded
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Model under test (pure): the legacy navigation verbs and their go_router
// replacements, plus the deterministic, total mapping function per AD-5.
// ---------------------------------------------------------------------------

/// The legacy `Navigator.*Named` verbs inventoried for migration.
enum LegacyVerb {
  /// `Navigator.pushNamed(...)`            -> `context.push`   (Req 2.2)
  pushNamed,

  /// `Navigator.pushReplacementNamed(...)` -> `context.pushReplacement` (Req 2.3)
  pushReplacementNamed,

  /// `Navigator.pushNamedAndRemoveUntil(..., (r) => false)` (stack-clearing)
  /// -> `context.go` (Req 2.4)
  pushNamedAndRemoveUntilClearStack,
}

/// The go_router replacement verbs.
enum GoRouterVerb { push, pushReplacement, go }

/// Pure, total mapping of a legacy call site to its go_router verb per AD-5.
///
/// The Req 6.1 return-value override takes precedence: any call site that
/// consumes a return value maps to [GoRouterVerb.push] regardless of the
/// legacy verb (because `go`/`pushReplacement` return no result Future).
GoRouterVerb mapVerb(LegacyVerb legacyVerb, bool consumesReturnValue) {
  // Req 6.1 — return-value override wins over the base verb mapping.
  if (consumesReturnValue) return GoRouterVerb.push;

  // AD-5 base table.
  switch (legacyVerb) {
    case LegacyVerb.pushNamed:
      return GoRouterVerb.push; // Req 2.2
    case LegacyVerb.pushReplacementNamed:
      return GoRouterVerb.pushReplacement; // Req 2.3
    case LegacyVerb.pushNamedAndRemoveUntilClearStack:
      return GoRouterVerb.go; // Req 2.4
  }
}

void main() {
  // At least 100 iterations are required by the spec; 200 matches the
  // convention used across the other property suites in this folder.
  const int kNumRuns = 200;

  // --- Input space ----------------------------------------------------------
  // The full input space is the cross product of the three legacy verbs and
  // the {true, false} return-value flag — six combinations total. Both
  // generators draw across their entire domain so every combination is
  // exercised across kNumRuns iterations.
  final Generator<LegacyVerb> verbGen = Gen.elementOf<LegacyVerb>(
    LegacyVerb.values,
  );
  final Generator<bool> consumesGen = Gen.elementOf<bool>(<bool>[true, false]);

  // Expected base mapping (no return value), pinned to AD-5 so a future edit
  // to either the table or the model is caught here.
  final Map<LegacyVerb, GoRouterVerb> baseExpected = <LegacyVerb, GoRouterVerb>{
    LegacyVerb.pushNamed: GoRouterVerb.push,
    LegacyVerb.pushReplacementNamed: GoRouterVerb.pushReplacement,
    LegacyVerb.pushNamedAndRemoveUntilClearStack: GoRouterVerb.go,
  };

  // Sanity-check the input space matches the design/task description.
  setUpAll(() {
    expect(
      LegacyVerb.values,
      hasLength(3),
      reason: 'Property 1 legacy-verb domain is exactly the three AD-5 verbs.',
    );
    expect(
      baseExpected.keys.toSet(),
      LegacyVerb.values.toSet(),
      reason: 'Every legacy verb must have a pinned AD-5 base mapping.',
    );
  });

  group('Feature: imperative-navigation-gorouter-migration, Property 1: '
      'Navigation-verb mapping — Req 2.2, 2.3, 2.4, 6.1', () {
    // ----------------------------------------------------------------------
    // Property 1a — TOTAL + per-verb mapping (generated, >=100 iters).
    // Every (legacyVerb, consumesReturnValue) combination yields exactly one
    // defined go_router verb, matching AD-5 with the Req 6.1 override applied.
    // ----------------------------------------------------------------------
    test('Property 1a: the mapping is total — every (legacyVerb, '
        'consumesReturnValue) yields exactly one AD-5 go_router verb '
        '(pushNamed->push, pushReplacementNamed->pushReplacement, '
        'pushNamedAndRemoveUntil(clear)->go)', () {
      final bool held = forAll(
        (LegacyVerb verb, bool consumes) {
          final GoRouterVerb result = mapVerb(verb, consumes);
          // Totality: the result is always one of the three defined verbs.
          if (!GoRouterVerb.values.contains(result)) return false;
          // Correctness: matches the AD-5 base table unless the return-value
          // override applies (asserted in Property 1c).
          final GoRouterVerb expected = consumes
              ? GoRouterVerb.push
              : baseExpected[verb]!;
          return result == expected;
        },
        [verbGen, consumesGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Property 1b — DETERMINISTIC (generated, >=100 iters).
    // The same input always produces the same output: two independent calls
    // with identical arguments must agree.
    // ----------------------------------------------------------------------
    test('Property 1b: the mapping is deterministic — same input always yields '
        'the same go_router verb', () {
      final bool held = forAll(
        (LegacyVerb verb, bool consumes) {
          return mapVerb(verb, consumes) == mapVerb(verb, consumes);
        },
        [verbGen, consumesGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Property 1c — RETURN-VALUE OVERRIDE (generated, >=100 iters).
    // Req 6.1: consumesReturnValue == true ALWAYS maps to `push`, regardless
    // of the legacy verb. When false, the result must NOT be forced to push by
    // the override (it follows the AD-5 base table instead).
    // ----------------------------------------------------------------------
    test('Property 1c: any call site that consumes a return value maps to push '
        'regardless of its legacy verb (Req 6.1)', () {
      final bool held = forAll(
        (LegacyVerb verb, bool consumes) {
          final GoRouterVerb result = mapVerb(verb, consumes);
          if (consumes) {
            // Override: must always be push.
            return result == GoRouterVerb.push;
          }
          // No override: must equal the AD-5 base mapping for this verb.
          return result == baseExpected[verb]!;
        },
        [verbGen, consumesGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ----------------------------------------------------------------------
    // Deterministic anchors — pin every one of the six combinations explicitly
    // so a wrong mapping is caught with a precise message (complements the
    // properties by exhaustively enumerating the finite input space).
    // ----------------------------------------------------------------------
    test('Property 1 (anchors): all six (verb, consumesReturnValue) '
        'combinations map exactly per AD-5', () {
      // consumesReturnValue == false -> AD-5 base table.
      expect(mapVerb(LegacyVerb.pushNamed, false), GoRouterVerb.push);
      expect(
        mapVerb(LegacyVerb.pushReplacementNamed, false),
        GoRouterVerb.pushReplacement,
      );
      expect(
        mapVerb(LegacyVerb.pushNamedAndRemoveUntilClearStack, false),
        GoRouterVerb.go,
      );

      // consumesReturnValue == true -> push for ALL verbs (Req 6.1 override).
      expect(mapVerb(LegacyVerb.pushNamed, true), GoRouterVerb.push);
      expect(mapVerb(LegacyVerb.pushReplacementNamed, true), GoRouterVerb.push);
      expect(
        mapVerb(LegacyVerb.pushNamedAndRemoveUntilClearStack, true),
        GoRouterVerb.push,
      );
    });
  });
}
