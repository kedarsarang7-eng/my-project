// ============================================================================
// PROPERTY TEST: MOQ Line Validation
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 11: MOQ line validation
//
// **Validates: Requirements 7.3**
//
// For any item with minimum-order quantity `m` and any bill-line quantity `q`,
// the line SHALL be accepted if and only if `q >= m` AND `m > 0`; a rejected
// line SHALL persist nothing and SHALL surface a validation error identifying `m`.
//
// ForAll 200 iterations: generate random (moq, qty) pairs and verify:
//   - When qty >= moq AND moq > 0: validateLine returns ValidationSuccess
//   - When qty < moq AND moq > 0: validateLine returns ValidationFailure
//   - When moq <= 0: validateLine returns ValidationFailure
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_moq_line_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/moq_validator.dart';
import 'package:dukanx/features/wholesale/domain/validation_result.dart';

void main() {
  const int kNumRuns = 200;
  const validator = MoqValidator();

  group(
    'Feature: wholesale-vertical-remediation, Property 11: MOQ line validation',
    () {
      // -----------------------------------------------------------------------
      // Property 11a: When qty >= moq AND moq > 0, validateLine accepts.
      // -----------------------------------------------------------------------
      test(
        'Property 11a (forAll): validateLine accepts when qty >= moq and moq > 0',
        () {
          final held = forAll(
            (int seed) {
              // Generate a positive moq (1..500) and a qty >= moq
              final moq = (seed.abs() % 500) + 1; // 1..500
              final excess = seed.abs() % 1000; // 0..999
              final qty = moq + excess; // qty >= moq guaranteed

              final result = validator.validateLine(moq: moq, qty: qty);
              return result is ValidationSuccess;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'validateLine must return ValidationSuccess when qty >= moq and moq > 0',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 11b: When qty < moq AND moq > 0, validateLine rejects.
      // -----------------------------------------------------------------------
      test(
        'Property 11b (forAll): validateLine rejects when qty < moq and moq > 0',
        () {
          final held = forAll(
            (int seed) {
              // Generate a positive moq (2..500) and a qty strictly below it
              final moq = (seed.abs() % 499) + 2; // 2..500 (need room below)
              final qty = seed.abs() % (moq); // 0..(moq-1), so qty < moq

              final result = validator.validateLine(moq: moq, qty: qty);
              if (result is! ValidationFailure) return false;
              // The failure message should identify the minimum
              return result.reason.contains('$moq');
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'validateLine must return ValidationFailure naming the MOQ when qty < moq',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 11c: When moq <= 0, validateLine always rejects.
      // -----------------------------------------------------------------------
      test('Property 11c (forAll): validateLine rejects when moq <= 0', () {
        final held = forAll(
          (int seed) {
            // Generate a non-positive moq: 0, -1, -2, ...
            final moq = -(seed.abs() % 500); // -499..0
            final qty = (seed.abs() % 1000) + 1; // arbitrary positive qty

            final result = validator.validateLine(moq: moq, qty: qty);
            return result is ValidationFailure;
          },
          [Gen.interval(-100000, 100000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'validateLine must return ValidationFailure when moq <= 0',
        );
      });
    },
  );
}
