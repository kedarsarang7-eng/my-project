// ============================================================================
// Task 4.2 — PROPERTY TEST
// Feature: subscription-plan-tiers, Property 5
// **Validates: Requirements 3.5**
// ============================================================================
// Property 5: Available_Capability_Count is sourced only from the registry.
//
// For all business types, CoverageCalculator.availableCount(type) equals the
// number of distinct BusinessCapability values listed for that type in the
// Capability_Registry — and for NO other reason. We exercise this two ways in
// every iteration:
//
//   A. Real registry  — draw a type from the 19 registered types and assert
//      availableCount(type) == businessCapabilityRegistry[type].length.
//   B. Synthesized registry — inject a random subset of BusinessCapability
//      .values (including empty and tiny sets) as the sole entry of a fresh
//      registry, and assert availableCount(synthType) == subset.length.
//
// Property-based testing library: dartproptest ^0.2.1.
// Idiomatic usage (confirmed against the package source):
//   forAll(
//     (T a, U b) => <bool property>,            // closure returns bool
//     [Gen.elementOf<T>(...), Gen.set<U>(...)], // one Generator per parameter
//     numRuns: 200,                             // iteration count (>= 100)
//   );
// `forAll` returns true when the property held for every run and throws a
// shrinking Exception with a counterexample otherwise.
//
// Run: flutter test test/core/subscription/coverage_source_property_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/subscription/coverage_calculator.dart';

void main() {
  // At least 100 iterations per the spec; 200 is the dartproptest default.
  const int kNumRuns = 200;

  // The sentinel key used for synthesized single-entry registries.
  const String kSynthKey = 'pbtSynthesizedType';

  // Generators (defined once, reused across runs).
  final typeGen = Gen.elementOf<String>(
    businessCapabilityRegistry.keys.toList(),
  );
  // Random subsets of the full capability enum, including empty and tiny sets.
  final subsetGen = Gen.set<BusinessCapability>(
    Gen.elementOf<BusinessCapability>(BusinessCapability.values),
    minSize: 0,
    maxSize: 30,
  );

  group('Feature: subscription-plan-tiers, Property 5 '
      '(Available_Capability_Count is sourced only from the registry)', () {
    test('Feature: subscription-plan-tiers, Property 5 — availableCount equals '
        'the distinct registered capability count for both real and '
        'synthesized registries', () {
      final held = forAll(
        (String type, Set<BusinessCapability> subset) {
          // Direction A: the default calculator reads the real registry only.
          final realCalc = CoverageCalculator();
          final realExpected = businessCapabilityRegistry[type]!.length;
          final realOk = realCalc.availableCount(type) == realExpected;

          // Direction B: a synthesized registry is the sole source of truth.
          // The injected entry is a Set, so its length is the distinct count.
          final synthCalc = CoverageCalculator(registry: {kSynthKey: subset});
          final synthOk = synthCalc.availableCount(kSynthKey) == subset.length;

          // A synthesized calculator must NOT see the real registry's types:
          // availableCount of a real type it was not given is 0 (registry is
          // the only source — Req 3.5).
          final isolatedOk =
              synthCalc.availableCount(type) ==
              (type == kSynthKey ? subset.length : 0);

          return realOk && synthOk && isolatedOk;
        },
        [typeGen, subsetGen],
        numRuns: kNumRuns,
      );

      expect(held, isTrue);
    });

    // Deterministic examples that anchor the edge cases the property sweeps.
    test('Feature: subscription-plan-tiers, Property 5 — empty registry entry '
        'yields availableCount 0', () {
      final calc = CoverageCalculator(
        registry: {kSynthKey: <BusinessCapability>{}},
      );
      expect(calc.availableCount(kSynthKey), equals(0));
    });

    test('Feature: subscription-plan-tiers, Property 5 — unknown type yields '
        'availableCount 0', () {
      final calc = CoverageCalculator(
        registry: {
          kSynthKey: <BusinessCapability>{BusinessCapability.useInvoiceCreate},
        },
      );
      expect(calc.availableCount('no_such_type'), equals(0));
    });

    test('Feature: subscription-plan-tiers, Property 5 — count equals the '
        'distinct set size for a tiny synthesized entry', () {
      final caps = <BusinessCapability>{
        BusinessCapability.useInvoiceCreate,
        BusinessCapability.useInvoiceList,
      };
      final calc = CoverageCalculator(registry: {kSynthKey: caps});
      expect(calc.availableCount(kSynthKey), equals(2));
    });

    test('Feature: subscription-plan-tiers, Property 5 — default calculator '
        'matches the registry length for every registered type', () {
      final calc = CoverageCalculator();
      businessCapabilityRegistry.forEach((type, caps) {
        expect(
          calc.availableCount(type),
          equals(caps.length),
          reason: '$type availableCount must equal its registry set length',
        );
      });
    });
  });
}
