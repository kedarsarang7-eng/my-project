// Feature: comprehensive-test-certification, Property 2
// ============================================================================
// Task 2.2 — PROPERTY TEST
// **Validates: Requirements 2.2, 2.3**
// ============================================================================
// Property 2: Currency rounding is half-up at scale 2 and results carry the
// fixed scale.
//
//   For any raw Decimal value, `roundCurrency` returns that value rounded
//   half-up to 2 decimal places, and every monetary result from the engine is
//   at scale 2 while every quantity result from the engine is at scale 3.
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_2_currency_rounding_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:decimal/decimal.dart';

import '../pbt/generators.dart';
import '../core/calculation_engine.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns the number of significant decimal places in a Decimal's string
/// representation. The Decimal package strips trailing zeros from toString(),
/// so Decimal.parse('5.00').toString() == '5' (0 dp).
int _decimalPlaces(Decimal d) {
  final str = d.toString();
  final dotIndex = str.indexOf('.');
  if (dotIndex == -1) return 0;
  return str.length - dotIndex - 1;
}

/// Returns true if [d] is representable at scale [n] — i.e. it has at most
/// [n] decimal places. The Decimal package strips trailing zeros, so "5.00"
/// becomes "5" (0 dp) which is still valid at scale 2 since 5 == 5.00.
bool _isAtScale(Decimal d, int n) => _decimalPlaces(d) <= n;

/// Computes the expected half-up rounding to 2 decimal places independently
/// of the CalculationEngine. Uses the mathematical definition:
///   round_half_up(x) = floor(x * 100 + 0.5) / 100  (for non-negative)
///   round_half_up(x) = ceil(x * 100 - 0.5) / 100   (for negative)
Decimal _expectedRoundHalfUp2(Decimal value) {
  final shifted = value * Decimal.fromInt(100);
  final BigInt truncated;
  if (shifted >= Decimal.zero) {
    truncated = (shifted + Decimal.parse('0.5')).floor().toBigInt();
  } else {
    truncated = (shifted - Decimal.parse('0.5')).ceil().toBigInt();
  }
  final intVal = truncated.toInt();
  final sign = intVal < 0 ? '-' : '';
  final abs = intVal.abs();
  final whole = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  return Decimal.parse('$sign$whole.$frac');
}

// ---------------------------------------------------------------------------
// A generator for arbitrary Decimal values (including values outside the
// monetary domain) to thoroughly test roundCurrency, which does NOT validate
// against the domain.
// ---------------------------------------------------------------------------

/// Generates Decimal values across a wide range including negatives, zero,
/// values with many decimal places, and very large values. This exercises
/// roundCurrency which is a pure rounding operation without domain validation.
final Generator<Decimal> arbitraryDecimalGen =
    Gen.tuple([
      Gen.interval(-999999999, 999999999), // integer part
      Gen.interval(0, 99999), // fractional part (up to 5 digits)
      Gen.interval(1, 5), // number of fractional digits
      Gen.interval(0, 7), // selector for edge cases
    ]).map((parts) {
      final int selector = parts[3] as int;

      switch (selector) {
        case 0:
          return Decimal.zero; // zero
        case 1:
          return Decimal.parse('0.005'); // half-up boundary at 0
        case 2:
          return Decimal.parse('-0.005'); // negative half-up boundary
        case 3:
          return Decimal.parse('1.235'); // classic .xx5 boundary
        case 4:
          return Decimal.parse('-1.235'); // negative .xx5 boundary
        default:
          // Random value with variable fractional digits
          final int intPart = parts[0] as int;
          final int fracPart = (parts[1] as int).abs();
          final int fracDigits = parts[2] as int;
          final String fracStr = fracPart.toString().padLeft(fracDigits, '0');
          // Truncate to requested number of fractional digits
          final String trimmedFrac = fracStr.length > fracDigits
              ? fracStr.substring(0, fracDigits)
              : fracStr;
          return Decimal.parse('$intPart.$trimmedFrac');
      }
    });

void main() {
  group('Feature: comprehensive-test-certification, Property 2 '
      '(Currency rounding is half-up at scale 2)', () {
    // -----------------------------------------------------------------------
    // Property 2a: roundCurrency returns the value rounded half-up to 2dp
    // -----------------------------------------------------------------------
    test('roundCurrency returns the half-up rounded value to 2 decimal places '
        'for any raw Decimal', () {
      final held = forAll(
        (Decimal raw) {
          final result = CalculationEngine().roundCurrency(raw);

          // Must be a CalcValue (roundCurrency never returns an error)
          if (result is! CalcValue) return false;

          final rounded = result.value;
          final expected = _expectedRoundHalfUp2(raw);

          // The rounded value must equal the expected half-up result
          return rounded == expected;
        },
        [arbitraryDecimalGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -----------------------------------------------------------------------
    // Property 2b: Every monetary result from roundCurrency is at scale 2
    // -----------------------------------------------------------------------
    test('roundCurrency always produces a result at scale 2 (at most 2 decimal '
        'places) for any raw Decimal', () {
      final held = forAll(
        (Decimal raw) {
          final result = CalculationEngine().roundCurrency(raw);

          if (result is! CalcValue) return false;

          // The result must be representable at scale 2 (≤ 2 dp)
          return _isAtScale(result.value, 2);
        },
        [arbitraryDecimalGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -----------------------------------------------------------------------
    // Property 2c: Every monetary result from the engine (tax, GST, VAT, etc.)
    // is at scale 2
    // -----------------------------------------------------------------------
    test('every monetary calculation result from the engine is at scale 2', () {
      final engine = CalculationEngine();

      final held = forAll(
        (Decimal amount) {
          // Use a fixed valid rate to focus on the monetary output scale
          final rate = Decimal.parse('0.18');

          // Tax total
          final taxResult = engine.taxTotal(amount, rate);
          if (taxResult is CalcValue && !_isAtScale(taxResult.value, 2)) {
            return false;
          }

          // GST
          final gstResult = engine.gst(amount, rate);
          if (gstResult is CalcValue && !_isAtScale(gstResult.value, 2)) {
            return false;
          }

          // VAT
          final vatResult = engine.vat(amount, rate);
          if (vatResult is CalcValue && !_isAtScale(vatResult.value, 2)) {
            return false;
          }

          // Discount
          final discResult = engine.discount(amount, rate);
          if (discResult is CalcValue && !_isAtScale(discResult.value, 2)) {
            return false;
          }

          // Credit entry
          final creditResult = engine.creditEntry(amount);
          if (creditResult is CalcValue && !_isAtScale(creditResult.value, 2)) {
            return false;
          }

          // Debit entry
          final debitResult = engine.debitEntry(amount);
          if (debitResult is CalcValue && !_isAtScale(debitResult.value, 2)) {
            return false;
          }

          return true;
        },
        [moneyGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -----------------------------------------------------------------------
    // Property 2d: Every quantity result from the engine is at scale 3
    // -----------------------------------------------------------------------
    test('every quantity calculation result from the engine is at scale 3', () {
      final engine = CalculationEngine();

      final held = forAll(
        (Decimal qty) {
          // Use a small positive adjustment
          final adjustment = Decimal.parse('1.000');

          final result = engine.inventoryAdjustment(qty, adjustment);
          if (result is CalcValue && !_isAtScale(result.value, 3)) {
            return false;
          }

          return true;
        },
        [quantityGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
