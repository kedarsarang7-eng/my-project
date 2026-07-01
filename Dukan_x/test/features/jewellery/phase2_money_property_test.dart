// ============================================================================
// JEWELLERY VERTICAL REMEDIATION — Phase 2 Money Correctness Property Tests
//
// Feature: jewellery-vertical-remediation
//
// Tasks 4.6, 4.7, 4.8, 4.9:
//   Property 9: Per-10g to per-gram conversion is a single floor division
//   Bidirectional rate-conversion unit tests (example-based)
//   Property 1: Money path is integer paise
//   Property 2: RID identifiers are well-formed
//
// **Validates: Requirements 1.1, 1.2, 1.3, 6.1, 6.2, 6.3, 6.4, 8.4**
//
// PBT library: dartproptest ^0.2.1
// Run: flutter test test/features/jewellery/phase2_money_property_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/utils/rid_generator.dart';
import 'package:dukanx/features/jewellery/utils/jewellery_business_rules.dart';
import 'package:dukanx/features/jewellery/utils/jewellery_rate_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ==========================================================================
  // Task 4.6 — Property 9: Per-10g to per-gram conversion is a single floor
  //            division.
  // Feature: jewellery-vertical-remediation, Property 9
  // **Validates: Requirements 6.1, 6.2, 6.3, 6.4**
  // ==========================================================================
  group(
    'Feature: jewellery-vertical-remediation, '
    'Property 9: Per-10g to per-gram conversion is a single floor division',
    () {
      test('Property 9: For any non-negative per-10g paise value, '
          'perGramFromPer10g(x) == x ~/ 10', () {
        // Generator: non-negative integers in paise range (0 to 100_000_00,
        // representing up to ₹1,00,000 per 10g which exceeds any realistic rate).
        final Generator<int> per10gGen = Gen.interval(0, 10000000);

        final bool held = forAll(
          (int per10gPaisa) {
            final int result = JewelleryRateUnit.perGramFromPer10g(per10gPaisa);
            final int expected = per10gPaisa ~/ 10;
            return result == expected;
          },
          [per10gGen],
          numRuns: 100,
        );

        expect(
          held,
          isTrue,
          reason:
              'perGramFromPer10g(x) must equal x ~/ 10 for all non-negative '
              'paise values (Requirements 6.1, 6.2, 6.4).',
        );
      });
    },
  );

  // ==========================================================================
  // Task 4.7 — Bidirectional rate-conversion unit tests (example-based).
  // **Validates: Requirement 6.3**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Bidirectional rate-conversion unit tests', () {
    // Representative per-10g paise values for 24K/22K/18K gold rates,
    // including non-multiples of 10 to exercise the truncation rule.
    final testCases = <({String label, int per10gPaisa})>[
      // 24K rates
      (label: '24K ₹72,000/10g (exact)', per10gPaisa: 7200000),
      (label: '24K ₹72,345/10g (non-multiple)', per10gPaisa: 7234500),
      (label: '24K ₹72,001.23/10g (non-multiple)', per10gPaisa: 7200123),
      (label: '24K ₹72,009.99/10g (non-multiple of 10)', per10gPaisa: 7200999),
      // 22K rates
      (label: '22K ₹66,000/10g (exact)', per10gPaisa: 6600000),
      (label: '22K ₹66,543/10g (non-multiple)', per10gPaisa: 6654300),
      (label: '22K ₹66,001.07/10g (non-multiple)', per10gPaisa: 6600107),
      (label: '22K ₹66,999.99/10g (non-multiple of 10)', per10gPaisa: 6699999),
      // 18K rates
      (label: '18K ₹54,000/10g (exact)', per10gPaisa: 5400000),
      (label: '18K ₹54,321/10g (non-multiple)', per10gPaisa: 5432100),
      (label: '18K ₹54,321.01/10g (non-multiple)', per10gPaisa: 5432101),
      (label: '18K ₹54,321.09/10g (non-multiple of 10)', per10gPaisa: 5432109),
    ];

    for (final tc in testCases) {
      test('${tc.label}: perGram = per10g ~/ 10', () {
        final int perGram = JewelleryRateUnit.perGramFromPer10g(tc.per10gPaisa);
        final int expectedPerGram = tc.per10gPaisa ~/ 10;
        expect(
          perGram,
          equals(expectedPerGram),
          reason:
              'perGramFromPer10g(${tc.per10gPaisa}) should be '
              '$expectedPerGram',
        );
      });

      test('${tc.label}: reconstruction error below 10 paise', () {
        final int perGram = JewelleryRateUnit.perGramFromPer10g(tc.per10gPaisa);
        final int reconstructed = JewelleryRateUnit.per10gFromPerGram(perGram);
        final int error = (tc.per10gPaisa - reconstructed).abs();
        expect(
          error,
          lessThan(10),
          reason:
              'Round-trip error from per10g → perGram → per10g must be '
              '< 10 paise (the lossy truncation is at most 9 paise). '
              'Got error=$error for per10g=${tc.per10gPaisa}.',
        );
      });
    }
  });

  // ==========================================================================
  // Task 4.8 — Property 1: Money path is integer paise.
  // Feature: jewellery-vertical-remediation, Property 1
  // **Validates: Requirements 1.1, 1.2, 8.4**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 1: Money path is integer paise', () {
    test('Property 1: For any valid combination of inputs to billTotalPaisa, '
        'the result is an integer equal to the reference computation', () {
      // Generators for valid jewellery billing inputs.
      // grossWeightMilligrams: 1mg to 1kg (1_000_000 mg)
      final Generator<int> weightGen = Gen.interval(1, 1000000);
      // ratePerGram24KPaisa: ₹1 to ₹1,00,000 per gram (100 to 10_000_000 paise)
      final Generator<int> rateGen = Gen.interval(100, 10000000);
      // makingChargesPaisa: 0 to ₹50,000 (0 to 5_000_000 paise)
      final Generator<int> makingGen = Gen.interval(0, 5000000);
      // taxPaisa: 0 to ₹10,000 (0 to 1_000_000 paise)
      final Generator<int> taxGen = Gen.interval(0, 1000000);
      // discountPaisa: 0 to ₹5,000 (0 to 500_000 paise)
      final Generator<int> discountGen = Gen.interval(0, 500000);
      // purity index: 0-3 mapping to GoldPurity values
      final Generator<int> purityIndexGen = Gen.interval(0, 3);

      final bool held = forAll(
        (
          int weight,
          int rate,
          int making,
          int tax,
          int discount,
          int purityIdx,
        ) {
          final purity = GoldPurity.values[purityIdx];

          final int result = JewelleryBusinessRules.billTotalPaisa(
            grossWeightMilligrams: weight,
            purity: purity,
            ratePerGram24KPaisa: rate,
            makingChargesPaisa: making,
            taxPaisa: tax,
            discountPaisa: discount,
          );

          // Property 1a: The result is an int (guaranteed by the type system,
          // but verify no floating-point was used by recomputing the reference).
          // Property 1b: The result equals the integer-paise reference
          // computation.

          // Reference computation (same formula as the implementation):
          // metalValue = halfUp(weight * fineness * rate / 1_000_000)
          final BigInt dividend =
              BigInt.from(weight) *
              BigInt.from(purity.finenessNumerator) *
              BigInt.from(rate);
          const int divisorInt = 1000 * GoldPurity.finenessDenominator;
          final BigInt divisor = BigInt.from(divisorInt);
          final BigInt metalValue =
              (dividend + divisor ~/ BigInt.two) ~/ divisor;

          final int referenceTotal =
              metalValue.toInt() + making + tax - discount;

          // Apply the same clamping as the implementation.
          final int expected;
          if (referenceTotal < 0) {
            expected = 0;
          } else if (referenceTotal > JewelleryBusinessRules.maxTotalPaisa) {
            expected = JewelleryBusinessRules.maxTotalPaisa;
          } else {
            expected = referenceTotal;
          }

          // The result must exactly equal the integer-paise reference.
          return result == expected;
        },
        [weightGen, rateGen, makingGen, taxGen, discountGen, purityIndexGen],
        numRuns: 100,
      );

      expect(
        held,
        isTrue,
        reason:
            'billTotalPaisa must produce an integer result equal to the '
            'integer-paise reference computation for all valid inputs '
            '(Requirements 1.1, 1.2, 8.4).',
      );
    });
  });

  // ==========================================================================
  // Task 4.9 — Property 2: RID identifiers are well-formed.
  // Feature: jewellery-vertical-remediation, Property 2
  // **Validates: Requirement 1.3**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 2: RID identifiers are well-formed', () {
    test('Property 2: For any tenantId, RidGenerator.next(tenantId) produces '
        'a string matching {tenantId}-{timestamp_ms}-{uuid_v4_short} '
        '(8 hex chars)', () {
      // Generator: alphanumeric tenantIds (no hyphens, so split('-') is exact).
      const alphaNum = [
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
        'g',
        'h',
        'i',
        'j',
        'k',
        'l',
        'm',
        'n',
        'o',
        'p',
        'q',
        'r',
        's',
        't',
        'u',
        'v',
        'w',
        'x',
        'y',
        'z',
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
        'P',
        'Q',
        'R',
        'S',
        'T',
        'U',
        'V',
        'W',
        'X',
        'Y',
        'Z',
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
      ];

      final Generator<String> tenantIdGen = Gen.array<String>(
        Gen.elementOf<String>(alphaNum),
        minLength: 1,
        maxLength: 20,
      ).map((chars) => chars.join());

      // Regex for 8 lowercase hex chars (uuid_v4_short segment).
      final hexPattern = RegExp(r'^[0-9a-f]{8}$');

      final bool held = forAll(
        (String tenantId) {
          final int beforeMs = DateTime.now().toUtc().millisecondsSinceEpoch;
          final String rid = RidGenerator.next(tenantId);
          final int afterMs = DateTime.now().toUtc().millisecondsSinceEpoch;

          // Structure: {tenantId}-{timestamp_ms}-{uuid_v4_short}
          // Since tenantId is hyphen-free, split('-') yields exactly 3 parts.
          final parts = rid.split('-');
          if (parts.length != 3) return false;

          // Segment 1: tenantId verbatim.
          if (parts[0] != tenantId) return false;

          // Segment 2: integer milliseconds since epoch, within bounds.
          final int? ts = int.tryParse(parts[1]);
          if (ts == null) return false;
          if (ts < beforeMs || ts > afterMs) return false;

          // Segment 3: exactly 8 hex characters (uuid_v4_short).
          if (!hexPattern.hasMatch(parts[2])) return false;

          return true;
        },
        [tenantIdGen],
        numRuns: 100,
      );

      expect(
        held,
        isTrue,
        reason:
            'RidGenerator.next(tenantId) must produce '
            '{tenantId}-{timestamp_ms}-{uuid_v4_short} where uuid_v4_short '
            'is 8 hex chars (Requirement 1.3).',
      );
    });
  });
}
