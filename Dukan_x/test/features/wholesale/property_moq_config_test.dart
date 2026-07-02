// ============================================================================
// PROPERTY TEST: MOQ/Conversion-Factor Input Validation
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 12: MOQ/conversion-factor input validation
//
// **Validates: Requirements 7.7**
//
// For any MOQ or conversion-factor value that is zero, negative, or non-numeric
// (null), configuration SHALL reject the entry, persist nothing, and surface a
// validation error.
//
// ForAll 200 iterations: generate random (moq, conversionFactor) pairs and verify:
//   - When both > 0: validateConfig returns ValidationSuccess
//   - When moq is null/zero/negative: validateConfig returns ValidationFailure
//   - When conversionFactor is null/zero/negative: validateConfig returns ValidationFailure
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_moq_config_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/wholesale/domain/moq_validator.dart';
import 'package:dukanx/features/wholesale/domain/validation_result.dart';

void main() {
  const int kNumRuns = 200;
  const validator = MoqValidator();

  group(
    'Feature: wholesale-vertical-remediation, Property 12: MOQ/conversion-factor input validation',
    () {
      // -----------------------------------------------------------------------
      // Property 12a: When both moq > 0 AND conversionFactor > 0, config is valid.
      // -----------------------------------------------------------------------
      test(
        'Property 12a (forAll): validateConfig accepts when both moq and conversionFactor > 0',
        () {
          final held = forAll(
            (int seed) {
              // Generate two positive values
              final moq = (seed.abs() % 500) + 1; // 1..500
              final conversionFactor = ((seed.abs() + 37) % 100) + 1; // 1..100

              final result = validator.validateConfig(
                moq: moq,
                conversionFactor: conversionFactor,
              );
              return result is ValidationSuccess;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'validateConfig must return ValidationSuccess when both values are positive',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 12b: When moq is null, config is rejected.
      // -----------------------------------------------------------------------
      test(
        'Property 12b (forAll): validateConfig rejects when moq is null',
        () {
          final held = forAll(
            (int seed) {
              final conversionFactor = (seed.abs() % 100) + 1; // positive

              final result = validator.validateConfig(
                moq: null,
                conversionFactor: conversionFactor,
              );
              return result is ValidationFailure;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'validateConfig must reject when moq is null',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 12c: When moq is zero or negative, config is rejected.
      // -----------------------------------------------------------------------
      test('Property 12c (forAll): validateConfig rejects when moq <= 0', () {
        final held = forAll(
          (int seed) {
            final moq = -(seed.abs() % 500); // -499..0
            final conversionFactor = (seed.abs() % 100) + 1; // positive

            final result = validator.validateConfig(
              moq: moq,
              conversionFactor: conversionFactor,
            );
            return result is ValidationFailure;
          },
          [Gen.interval(-100000, 100000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'validateConfig must reject when moq <= 0',
        );
      });

      // -----------------------------------------------------------------------
      // Property 12d: When conversionFactor is null, config is rejected.
      // -----------------------------------------------------------------------
      test(
        'Property 12d (forAll): validateConfig rejects when conversionFactor is null',
        () {
          final held = forAll(
            (int seed) {
              final moq = (seed.abs() % 500) + 1; // positive

              final result = validator.validateConfig(
                moq: moq,
                conversionFactor: null,
              );
              return result is ValidationFailure;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'validateConfig must reject when conversionFactor is null',
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 12e: When conversionFactor is zero or negative, config is rejected.
      // -----------------------------------------------------------------------
      test(
        'Property 12e (forAll): validateConfig rejects when conversionFactor <= 0',
        () {
          final held = forAll(
            (int seed) {
              final moq = (seed.abs() % 500) + 1; // positive
              final conversionFactor = -(seed.abs() % 500); // -499..0

              final result = validator.validateConfig(
                moq: moq,
                conversionFactor: conversionFactor,
              );
              return result is ValidationFailure;
            },
            [Gen.interval(-100000, 100000)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason: 'validateConfig must reject when conversionFactor <= 0',
          );
        },
      );
    },
  );
}
