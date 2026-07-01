// Feature: comprehensive-test-certification, Property 1
// ============================================================================
// Property 1: Coverage-gap shortfall arithmetic.
// **Validates: Requirements 1.8, 1.9**
// ============================================================================
// For any expected count E and actual count A, record a gap iff A < E, with
// shortfall = E − A (non-negative).
//
// Unit under test: `CoverageGapCalculator.checkCount(kind, expected, actual)`
// from `../core/coverage_gap.dart`.
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_1_coverage_gap_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/coverage_gap.dart';
import 'generators.dart';

void main() {
  final calculator = CoverageGapCalculator();

  group('Feature: comprehensive-test-certification, Property 1: '
      'Coverage-gap shortfall arithmetic', () {
    test('Property 1a: For any E >= 0 and A >= 0 where A < E, checkCount '
        'returns a CoverageGap with expected=E, actual=A, shortfall=E-A', () {
      final held = forAll(
        (int expected, int actualOffset) {
          // Generate E in [1, 1000] and A in [0, E-1] to guarantee A < E.
          final e = expected.abs() + 1; // Ensure E >= 1
          final a = actualOffset.abs() % e; // Ensure 0 <= A < E

          final result = calculator.checkCount('test', e, a);

          // A gap must be recorded.
          if (result == null) return false;

          // The gap must state the correct expected, actual, and shortfall.
          return result.expected == e &&
              result.actual == a &&
              result.shortfall == e - a;
        },
        [Gen.interval(1, 1000), Gen.interval(0, 999)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Property 1b: For any E >= 0 and A >= E, checkCount returns null '
        '(no gap)', () {
      final held = forAll(
        (int expected, int surplus) {
          // Generate E in [0, 500] and A = E + surplus where surplus in [0, 500].
          final e = expected.abs() % 501; // E in [0, 500]
          final a = e + (surplus.abs() % 501); // A >= E

          final result = calculator.checkCount('test', e, a);

          // No gap should be recorded.
          return result == null;
        },
        [Gen.interval(0, 500), Gen.interval(0, 500)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Property 1c: Shortfall is always non-negative when a gap is '
        'recorded', () {
      final held = forAll(
        (int expected, int actual) {
          // Generate arbitrary E and A in [0, 1000].
          final e = expected.abs() % 1001;
          final a = actual.abs() % 1001;

          final result = calculator.checkCount('test', e, a);

          if (result != null) {
            // Shortfall must be non-negative.
            return result.shortfall >= 0 && result.shortfall == e - a;
          }
          // When no gap is recorded, A >= E — no shortfall to check.
          return a >= e;
        },
        [Gen.interval(0, 1000), Gen.interval(0, 1000)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
