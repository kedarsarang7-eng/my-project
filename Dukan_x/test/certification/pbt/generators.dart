// Feature: comprehensive-test-certification, Property generators
//
// Shared PBT generators for the certification suite. Used by all property tests
// (Properties 1–19) to synthesize randomized evidence covering domain edges,
// boundary values, and rejection-direction mutations.
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Requirements: 2.2, 2.5
library;

import 'package:dartproptest/dartproptest.dart';
import 'package:decimal/decimal.dart';

import '../core/domain.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

/// Standard number of PBT iterations for the certification suite.
const int kNumRuns = 200;

/// Property-tagging comment convention:
/// Each property test file begins with:
/// // Feature: comprehensive-test-certification, Property {n}

// ============================================================================
// DOMAIN BOUNDARIES
// ============================================================================

/// Minimum valid monetary value (scale 2).
final Decimal kMoneyMin = Decimal.parse('0.01');

/// Maximum valid monetary value (scale 2).
final Decimal kMoneyMax = Decimal.parse('999999999.99');

// ============================================================================
// BUSINESS TYPE GENERATORS
// ============================================================================

/// Generates a random BusinessType from all 19 enum values.
final Generator<BusinessType> businessTypeGen = Gen.elementOf<BusinessType>(
  BusinessType.values,
);

/// Generates only from the 4 service-only types (no product/inventory).
final Generator<BusinessType> serviceOnlyTypeGen = Gen.elementOf<BusinessType>(
  kServiceOnlyTypes.toList(),
);

// ============================================================================
// MONEY GENERATOR (scale 2)
// ============================================================================

/// Generates Decimal monetary values at scale 2 within the valid domain
/// [0.01, 999_999_999.99]. With ~25% probability it emits a domain-edge value
/// (0.01, 999999999.99, or a .xx5 half-up boundary); otherwise it generates a
/// uniformly random value in the domain.
///
/// Domain edges exercised:
///   - 0.01          (minimum)
///   - 999999999.99  (maximum)
///   - values ending in .xx5 (half-up rounding boundary, e.g. 1.235 → 1.24)
final Generator<Decimal> moneyGen =
    Gen.tuple([
      // Integer part [0, 999999999]
      Gen.interval(0, 999999999),
      // Fractional cents [1, 99] (we ensure >= 0.01 by keeping cents >= 1 when
      // integer part is 0, otherwise [0, 99])
      Gen.interval(0, 99),
      // Selector: 0–2 => edge value, 3+ => random
      Gen.interval(0, 11),
    ]).map((parts) {
      final int selector = parts[2] as int;

      // Edge cases (~25% of the time)
      switch (selector) {
        case 0:
          return kMoneyMin; // 0.01
        case 1:
          return kMoneyMax; // 999999999.99
        case 2:
          // .xx5 half-up boundary: generate a value like N.N5
          final int intPart = parts[0] as int;
          // Clamp integer part for boundary value
          final int clampedInt = intPart.clamp(0, 999999999);
          // Use the tens digit from cents for the first decimal, always 5 for second
          final int tensDigit = ((parts[1] as int) % 10);
          return Decimal.parse('$clampedInt.${tensDigit}5');
        default:
          // Random value in domain [0.01, 999999999.99]
          final int intPart = parts[0] as int;
          int cents = parts[1] as int;
          // Ensure minimum 0.01 when integer part is 0
          if (intPart == 0 && cents == 0) cents = 1;
          final String centsStr = cents.toString().padLeft(2, '0');
          return Decimal.parse('$intPart.$centsStr');
      }
    });

// ============================================================================
// QUANTITY GENERATOR (scale 3)
// ============================================================================

/// Generates Decimal quantity values at scale 3 for inventory quantities.
/// Produces values in the range [0.001, 999999.999] with occasional edge values.
final Generator<Decimal> quantityGen =
    Gen.tuple([
      // Integer part [0, 999999]
      Gen.interval(0, 999999),
      // Fractional thousandths [0, 999]
      Gen.interval(0, 999),
      // Selector for edge cases
      Gen.interval(0, 7),
    ]).map((parts) {
      final int selector = parts[2] as int;

      switch (selector) {
        case 0:
          // Minimum quantity
          return Decimal.parse('0.001');
        case 1:
          // Maximum quantity
          return Decimal.parse('999999.999');
        default:
          // Random quantity at scale 3
          final int intPart = parts[0] as int;
          int thousandths = parts[1] as int;
          // Ensure minimum 0.001 when integer part is 0
          if (intPart == 0 && thousandths == 0) thousandths = 1;
          final String fracStr = thousandths.toString().padLeft(3, '0');
          return Decimal.parse('$intPart.$fracStr');
      }
    });

// ============================================================================
// RATE GENERATOR
// ============================================================================

/// Generates rates in [0, 1] for tax/discount percentages.
/// Emits boundary values (0, 0.5, 1) with ~25% probability.
final Generator<Decimal> rateGen =
    Gen.tuple([
      Gen.interval(0, 10000), // basis points for [0.0000, 1.0000]
      Gen.interval(0, 11), // selector
    ]).map((parts) {
      final int selector = parts[1] as int;

      switch (selector) {
        case 0:
          return Decimal.zero; // 0%
        case 1:
          return Decimal.parse('0.5'); // 50%
        case 2:
          return Decimal.one; // 100%
        default:
          // Random rate in [0, 1] at up to 4 decimal places
          final int basisPoints = parts[0] as int;
          final int clamped = basisPoints.clamp(0, 10000);
          return (Decimal.parse(clamped.toString()) / Decimal.parse('10000'))
              .toDecimal(scaleOnInfinitePrecision: 4);
      }
    });

// ============================================================================
// ONE-RULE MUTATION GENERATOR
// ============================================================================

/// Describes which single field was mutated to invalidate a structure.
enum MutationKind {
  /// Remove or null-out a required identifier
  dropId,

  /// Set severity to an out-of-set value
  corruptSeverity,

  /// Empty the reproduction steps list
  emptyReproSteps,

  /// Set resolution status to an out-of-set value
  corruptStatus,

  /// Remove the gap category (set to null or invalid)
  dropCategory,
}

/// Result of a one-rule mutation: the kind of mutation applied.
class Mutation<T> {
  /// The mutated (now-invalid) value.
  final T value;

  /// Which rule was broken.
  final MutationKind kind;

  const Mutation({required this.value, required this.kind});
}

/// Generates a MutationKind — picks exactly one rule to break.
final Generator<MutationKind> mutationKindGen = Gen.elementOf<MutationKind>(
  MutationKind.values,
);
