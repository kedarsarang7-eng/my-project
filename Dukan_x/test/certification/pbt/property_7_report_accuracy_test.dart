// Feature: comprehensive-test-certification, Property 7
// ============================================================================
// Property 7: Report-accuracy mismatch threshold.
// **Validates: Requirements 6.4**
// ============================================================================
// For any expected value and actual value, the result is classified as a
// mismatch iff the absolute difference |actual - expected| > 0.01.
//
// Unit under test: `CertificationPass.isMismatch(expected, actual)`
// from `../io/certification_pass.dart`.
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_7_report_accuracy_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import '../io/certification_pass.dart';
import 'generators.dart';

void main() {
  group('Feature: comprehensive-test-certification, Property 7: '
      'Report-accuracy mismatch threshold', () {
    test('Property 7a: isMismatch is true when |actual - expected| > 0.01', () {
      final held = forAll(
        (int baseInt, int offsetInt) {
          // Generate an expected value and an actual value whose absolute
          // difference is guaranteed to be > 0.01.
          final expected = (baseInt % 100000) / 100.0; // [-999.99, 999.99]
          // Offset guaranteed > 1 cent (at least 2 cents away)
          final offsetCents = (offsetInt.abs() % 1000) + 2; // [2, 1001] cents
          final actual = expected + offsetCents / 100.0;

          return CertificationPass.isMismatch(expected, actual) == true;
        },
        [Gen.interval(-100000, 100000), Gen.interval(0, 1000)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Property 7b: isMismatch is false when |actual - expected| < 0.01', () {
      final held = forAll(
        (int baseInt, int offsetInt) {
          // Generate an expected value and an actual value whose absolute
          // difference is guaranteed to be < 0.01 (strictly within threshold).
          // Using thousandths [0..9] gives max diff of 0.009, safely < 0.01.
          final expected = (baseInt % 100000) / 100.0; // [-999.99, 999.99]
          // Offset in thousandths: [-9..9] i.e. |diff| <= 0.009 < 0.01
          final offsetThousandths = (offsetInt % 19) - 9;
          final actual = expected + offsetThousandths / 1000.0;

          return CertificationPass.isMismatch(expected, actual) == false;
        },
        [Gen.interval(-100000, 100000), Gen.interval(0, 18)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Property 7c: isMismatch is symmetric — same result regardless of '
        'which value is expected vs actual', () {
      final held = forAll(
        (int aInt, int bInt) {
          final a = (aInt % 100000) / 100.0;
          final b = (bInt % 100000) / 100.0;

          final forward = CertificationPass.isMismatch(a, b);
          final reverse = CertificationPass.isMismatch(b, a);

          return forward == reverse;
        },
        [Gen.interval(-100000, 100000), Gen.interval(-100000, 100000)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('Property 7d: isMismatch is true iff |diff| > 0.01 for arbitrary '
        'pairs', () {
      final held = forAll(
        (int aInt, int bInt) {
          final a = (aInt % 100000) / 100.0;
          final b = (bInt % 100000) / 100.0;

          final diff = (b - a).abs();
          final expectedResult = diff > 0.01;

          return CertificationPass.isMismatch(a, b) == expectedResult;
        },
        [Gen.interval(-100000, 100000), Gen.interval(-100000, 100000)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
