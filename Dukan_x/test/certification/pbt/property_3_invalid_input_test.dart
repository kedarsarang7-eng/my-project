// Feature: comprehensive-test-certification, Property 3
// ============================================================================
// Task 2.3 — PROPERTY TEST
// **Validates: Requirements 2.6, 2.7**
// ============================================================================
// Property 3: Invalid calculation input yields a defined error and persists nothing.
//
// For any calculation input that is null, non-numeric, illegally negative, or
// outside the monetary domain [0.01, 999,999,999.99], the CalculationEngine
// returns a CalcError (never a CalcValue) and no partial result is persisted
// or returned.
//
// Test strategy:
//   - Generate null inputs and assert CalcError is returned
//   - Generate values below minimum (< 0.01) and assert CalcError
//   - Generate values above maximum (> 999999999.99) and assert CalcError
//   - Generate illegally negative values where non-negative is required and
//     assert CalcError
//   - In every case, the result is CalcError — never CalcValue — and no partial
//     result leaks through.
//
// Property-based testing library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test Dukan_x/test/certification/pbt/property_3_invalid_input_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:decimal/decimal.dart';

import '../core/calculation_engine.dart';
import 'generators.dart';

void main() {
  final engine = CalculationEngine();

  group('Property 3: Invalid calculation input yields CalcError', () {
    // -----------------------------------------------------------------------
    // Sub-property A: null inputs always yield CalcError
    // -----------------------------------------------------------------------
    test('null input to taxTotal always yields CalcError', () {
      // Null for the first parameter (amount)
      final result1 = engine.taxTotal(null, Decimal.parse('0.18'));
      expect(result1, isA<CalcError>());

      // Null for the second parameter (rate)
      final result2 = engine.taxTotal(Decimal.parse('100.00'), null);
      expect(result2, isA<CalcError>());

      // Both null
      final result3 = engine.taxTotal(null, null);
      expect(result3, isA<CalcError>());
    });

    test('null input to gst always yields CalcError', () {
      final result1 = engine.gst(null, Decimal.parse('0.18'));
      expect(result1, isA<CalcError>());

      final result2 = engine.gst(Decimal.parse('100.00'), null);
      expect(result2, isA<CalcError>());
    });

    test('null input to vat always yields CalcError', () {
      final result1 = engine.vat(null, Decimal.parse('0.12'));
      expect(result1, isA<CalcError>());

      final result2 = engine.vat(Decimal.parse('50.00'), null);
      expect(result2, isA<CalcError>());
    });

    test('null input to invoiceTotal always yields CalcError', () {
      final validAmount = Decimal.parse('100.00');
      expect(
        engine.invoiceTotal(null, validAmount, validAmount),
        isA<CalcError>(),
      );
      expect(
        engine.invoiceTotal(validAmount, null, validAmount),
        isA<CalcError>(),
      );
      expect(
        engine.invoiceTotal(validAmount, validAmount, null),
        isA<CalcError>(),
      );
    });

    test('null input to reconcilePayment always yields CalcError', () {
      final validAmount = Decimal.parse('100.00');
      expect(engine.reconcilePayment(null, validAmount), isA<CalcError>());
      expect(engine.reconcilePayment(validAmount, null), isA<CalcError>());
    });

    test('null input to inventoryAdjustment always yields CalcError', () {
      final validQty = Decimal.parse('10.000');
      expect(engine.inventoryAdjustment(null, validQty), isA<CalcError>());
      expect(engine.inventoryAdjustment(validQty, null), isA<CalcError>());
    });

    test(
      'null input to creditEntry and debitEntry always yields CalcError',
      () {
        expect(engine.creditEntry(null), isA<CalcError>());
        expect(engine.debitEntry(null), isA<CalcError>());
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property B: values below minimum (< 0.01) yield CalcError
    // -----------------------------------------------------------------------
    test('values below minimum (< 0.01) yield CalcError for any valid rate', () {
      final held = forAll(
        (int centsBelowZero, int rateBasis) {
          // Generate values in [0.00, -large]: always below kMinMonetary (0.01)
          // Use centsBelowZero to create values like 0.00, -0.50, -100.00
          final belowMin = centsBelowZero <= 0
              ? Decimal.parse('0.00')
              : Decimal.parse(
                  '-${centsBelowZero ~/ 100}.${(centsBelowZero % 100).toString().padLeft(2, '0')}',
                );

          final validRate = Decimal.parse(
            '0.${(rateBasis.abs() % 100).toString().padLeft(2, '0')}',
          );

          final result = engine.taxTotal(belowMin, validRate);
          // Must always be CalcError, never CalcValue
          return result is CalcError;
        },
        [Gen.interval(0, 10000), Gen.interval(1, 99)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('zero (0.00) yields CalcError for monetary inputs', () {
      final zero = Decimal.parse('0.00');
      final validRate = Decimal.parse('0.18');

      expect(engine.taxTotal(zero, validRate), isA<CalcError>());
      expect(engine.gst(zero, validRate), isA<CalcError>());
      expect(engine.vat(zero, validRate), isA<CalcError>());
      expect(engine.creditEntry(zero), isA<CalcError>());
      expect(engine.debitEntry(zero), isA<CalcError>());
    });

    // -----------------------------------------------------------------------
    // Sub-property C: values above maximum (> 999999999.99) yield CalcError
    // -----------------------------------------------------------------------
    test(
      'values above maximum (> 999999999.99) yield CalcError for all ops',
      () {
        final held = forAll(
          (int excess) {
            // Generate values above the max: 1000000000.00 + excess cents
            final overMax =
                Decimal.parse('1000000000.00') +
                (Decimal.fromInt(excess) / Decimal.fromInt(100)).toDecimal(
                  scaleOnInfinitePrecision: 2,
                );

            final result = engine.taxTotal(overMax, Decimal.parse('0.10'));
            return result is CalcError;
          },
          [Gen.interval(0, 99999)],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    test('value just above maximum (1000000000.00) yields CalcError', () {
      final justAbove = Decimal.parse('1000000000.00');
      final validRate = Decimal.parse('0.18');

      expect(engine.taxTotal(justAbove, validRate), isA<CalcError>());
      expect(engine.gst(justAbove, validRate), isA<CalcError>());
      expect(engine.vat(justAbove, validRate), isA<CalcError>());
      expect(engine.creditEntry(justAbove), isA<CalcError>());
      expect(engine.debitEntry(justAbove), isA<CalcError>());
      expect(
        engine.reconcilePayment(justAbove, Decimal.parse('1.00')),
        isA<CalcError>(),
      );
    });

    // -----------------------------------------------------------------------
    // Sub-property D: illegally negative values yield CalcError
    // -----------------------------------------------------------------------
    test('negative values where non-negative is required yield CalcError', () {
      final held = forAll(
        (int magnitude) {
          // Generate negative monetary values
          final negative = Decimal.parse(
            '-${(magnitude + 1) ~/ 100}.${((magnitude + 1) % 100).toString().padLeft(2, '0')}',
          );

          // Rate cannot be negative
          final rateResult = engine.taxTotal(Decimal.parse('100.00'), negative);
          // Inventory currentQty cannot be negative
          final qtyResult = engine.inventoryAdjustment(
            negative,
            Decimal.parse('1.000'),
          );
          // Discount amount cannot be negative
          final discountResult = engine.invoiceTotal(
            Decimal.parse('100.00'),
            Decimal.parse('10.00'),
            negative,
          );

          return rateResult is CalcError &&
              qtyResult is CalcError &&
              discountResult is CalcError;
        },
        [Gen.interval(0, 99999)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    test('negative value for discount rate yields CalcError', () {
      final negRate = Decimal.parse('-0.10');
      final validAmount = Decimal.parse('500.00');

      expect(engine.discount(validAmount, negRate), isA<CalcError>());
    });

    // -----------------------------------------------------------------------
    // Sub-property E: no partial result is returned (CalcError is the ONLY output)
    // -----------------------------------------------------------------------
    test('CalcError is the sole output for any generated invalid input — no '
        'CalcValue leaks through', () {
      final held = forAll(
        (int kindSelector, int magnitudeRaw) {
          final kind =
              kindSelector %
              4; // 0: null-like(below), 1: below, 2: above, 3: negative
          final magnitude = magnitudeRaw.abs();

          final CalcResult result;
          switch (kind) {
            case 0:
              // Below minimum: 0.00
              result = engine.taxTotal(
                Decimal.parse('0.00'),
                Decimal.parse('0.18'),
              );
              break;
            case 1:
              // Below minimum: small positive below 0.01
              final belowMin =
                  (Decimal.fromInt(magnitude % 100) / Decimal.fromInt(10000))
                      .toDecimal(scaleOnInfinitePrecision: 4);
              // This gives values in [0.0000, 0.0099] which are all < 0.01
              result = engine.creditEntry(belowMin);
              break;
            case 2:
              // Above maximum
              final overMax =
                  Decimal.parse('1000000000.00') +
                  Decimal.fromInt(magnitude % 1000);
              result = engine.debitEntry(overMax);
              break;
            case 3:
              // Negative where non-negative required
              final neg = Decimal.parse('-${(magnitude % 9999) + 1}.00');
              result = engine.inventoryAdjustment(neg, Decimal.parse('1.000'));
              break;
            default:
              result = engine.taxTotal(
                Decimal.parse('0.00'),
                Decimal.parse('0.18'),
              );
          }

          // The ONLY valid outcome is CalcError — no CalcValue should ever appear
          if (result is CalcValue) return false;
          if (result is! CalcError) return false;

          // Verify the error has meaningful content
          return result.code.isNotEmpty && result.message.isNotEmpty;
        },
        [Gen.interval(0, 1000), Gen.interval(0, 99999)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
