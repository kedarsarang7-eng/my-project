// ============================================================================
// Tasks 4.13, 4.14, 4.15, 4.16 — PROPERTY + EXAMPLE TESTS
// Feature: jewellery-vertical-remediation, Properties 13, 14, 15
// ============================================================================
//
// Property 13: GST is split between metal value and making charges.
//   **Validates: Requirements 8.1**
//   For any inputs, total GST = metalValue * 3% + makingCharges * 5%
//   (not a single flat rate on the subtotal).
//
// Property 14: Wastage is counted exactly once.
//   **Validates: Requirements 8.2**
//   For any inputs with wastage > 0, the total with wastage equals
//   totalWithoutWastage + wastageAmount — wastage contributes exactly once.
//
// Property 15: Stone charge is linear in stone count.
//   **Validates: Requirements 8.3**
//   For any stoneCount n > 0, stone charge = n * perStoneCharge.
//   Doubling the count doubles the charge.
//
// Task 4.16: Pricing-engine equivalence example test.
//   **Validates: Requirements 7.3, 7.5**
//   Concrete worked examples (including a 10g 22K example at stated rates)
//   asserting calculator and canonical engine agree to the paise and equal
//   weight×rate + making + tax − discount.
//
// PBT library: dartproptest ^0.2.1.
// Run: flutter test test/features/jewellery/phase2_gst_wastage_stone_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/jewellery/utils/jewellery_business_rules.dart';
import 'package:dukanx/features/jewellery/data/services/making_charges_calculator.dart';
import 'package:dukanx/features/jewellery/data/models/making_charges_model.dart';

/// Number of property-test iterations (spec minimum: 100).
const int kNumRuns = 100;

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Metal weight in grams: 0.5g to 200g (realistic jewellery range).
final Generator<double> _weightGen = Gen.interval(5, 2000).map((v) => v / 10.0);

/// Metal rate in paise per gram: ₹2000 to ₹8000 per gram.
final Generator<int> _rateGen = Gen.interval(200000, 800000);

/// Making charges rate per gram in paise: ₹100 to ₹3000 per gram.
final Generator<int> _makingRateGen = Gen.interval(10000, 300000);

/// Wastage percentage: 1% to 20%.
final Generator<double> _wastageGen = Gen.interval(
  1,
  20,
).map((v) => v.toDouble());

/// Stone count: 1 to 20 stones.
final Generator<int> _stoneCountGen = Gen.interval(1, 20);

/// Per-stone charge in paise: ₹50 to ₹2000.
final Generator<int> _perStoneChargeGen = Gen.interval(5000, 200000);

/// Purity selector.
final Generator<GoldPurity> _purityGen = Gen.interval(
  0,
  3,
).map((i) => GoldPurity.values[i]);

// ---------------------------------------------------------------------------
// Helper: create a simple per-gram MakingChargesConfig
// ---------------------------------------------------------------------------

MakingChargesConfig _perGramConfig({
  required int ratePaisaPerGram,
  int? stoneMakingChargePaisa,
}) {
  return MakingChargesConfig(
    id: 'test-config',
    tenantId: 'test-tenant',
    name: 'Test Per Gram Config',
    type: MakingChargeType.perGram,
    ratePaisaPerGram: ratePaisaPerGram,
    stoneMakingChargePaisa: stoneMakingChargePaisa,
    includeStoneWeight: stoneMakingChargePaisa != null,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

/// Helper: compute metal value in paise using the same half-up logic as the engine.
int _computeMetalValuePaisa(int weightMg, GoldPurity purity, int rate24K) {
  final BigInt dividend =
      BigInt.from(weightMg) *
      BigInt.from(purity.finenessNumerator) *
      BigInt.from(rate24K);
  const int divisor = 1000000;
  return ((dividend + BigInt.from(divisor ~/ 2)) ~/ BigInt.from(divisor))
      .toInt();
}

// ---------------------------------------------------------------------------
// TESTS
// ---------------------------------------------------------------------------

void main() {
  // ==========================================================================
  // Property 13: GST is split between metal value and making charges
  // Feature: jewellery-vertical-remediation, Property 13
  // **Validates: Requirements 8.1**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, Property 13: '
      'GST is split between metal value and making charges', () {
    test('Property 13: total GST = metalValue * 3% + makingCharges * 5% '
        '(not a flat rate on subtotal)', () {
      final bool held = forAll(
        (List<dynamic> args) {
          final double weight = args[0] as double;
          final int rate = args[1] as int;
          final int makingRate = args[2] as int;
          final GoldPurity purity = args[3] as GoldPurity;

          final config = _perGramConfig(ratePaisaPerGram: makingRate);

          final result = MakingChargesCalculator.calculateTotalPrice(
            metalWeightGrams: weight,
            metalRatePaisaPerGram: rate,
            makingChargesConfig: config,
            purity: purity,
          );

          final int metalValuePaisa = result['metalValuePaisa'] as int;
          final int metalValueGstPaisa = result['metalValueGstPaisa'] as int;
          final int makingChargesGstPaisa =
              result['makingChargesGstPaisa'] as int;
          final int totalGstPaisa = result['gstPaisa'] as int;

          // Independent oracle: split GST per Indian GST treatment.
          final int expectedMetalGst = metalValuePaisa * 3 ~/ 100;
          // For this test (no wastage, no stone): aggregate = making charges
          final int makingChargesPaisa = result['makingChargesPaisa'] as int;
          final int expectedMakingGst = makingChargesPaisa * 5 ~/ 100;
          final int expectedTotalGst = expectedMetalGst + expectedMakingGst;

          if (metalValueGstPaisa != expectedMetalGst) return false;
          if (makingChargesGstPaisa != expectedMakingGst) return false;
          if (totalGstPaisa != expectedTotalGst) return false;

          return true;
        },
        [
          Gen.tuple(<Generator<dynamic>>[
            _weightGen,
            _rateGen,
            _makingRateGen,
            _purityGen,
          ]),
        ],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason: 'GST must be split: 3% on metal value + 5% on making charges',
      );
    });
  });

  // ==========================================================================
  // Property 14: Wastage is counted exactly once
  // Feature: jewellery-vertical-remediation, Property 14
  // **Validates: Requirements 8.2**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, Property 14: '
      'Wastage is counted exactly once', () {
    test('Property 14: total with wastage = totalWithoutWastage + wastageAmount '
        '(wastage contributes exactly once)', () {
      final bool held = forAll(
        (List<dynamic> args) {
          final double weight = args[0] as double;
          final int rate = args[1] as int;
          final int makingRate = args[2] as int;
          final double wastage = args[3] as double;
          final GoldPurity purity = args[4] as GoldPurity;

          final config = _perGramConfig(ratePaisaPerGram: makingRate);

          // Compute WITH wastage.
          final resultWith = MakingChargesCalculator.calculateTotalPrice(
            metalWeightGrams: weight,
            metalRatePaisaPerGram: rate,
            makingChargesConfig: config,
            purity: purity,
            wastagePercent: wastage,
          );

          // Compute WITHOUT wastage.
          final resultWithout = MakingChargesCalculator.calculateTotalPrice(
            metalWeightGrams: weight,
            metalRatePaisaPerGram: rate,
            makingChargesConfig: config,
            purity: purity,
          );

          final int totalWithWastage = resultWith['totalPaisa'] as int;
          final int totalWithoutWastage = resultWithout['totalPaisa'] as int;
          final int wastageValuePaisa = resultWith['wastageValuePaisa'] as int;

          // Wastage must be positive when wastage% > 0.
          if (wastageValuePaisa <= 0) return false;

          // Without wastage, wastage value must be zero.
          final int wastageWithout = resultWithout['wastageValuePaisa'] as int;
          if (wastageWithout != 0) return false;

          // The structural invariant for "counted exactly once":
          // aggregateWith = makingCharges + wastage
          // aggregateWithout = makingCharges
          // totalDiff = wastage + (gstOn(aggregateWith) - gstOn(aggregateWithout))
          //
          // Due to integer floor division, (a+w)*5~/100 may differ from
          // a*5~/100 + w*5~/100 by at most 1. We compute the exact GST
          // delta as the difference of the actual floor-divided values.
          final int makingChargesPaisa =
              resultWith['makingChargesPaisa'] as int;
          final int aggregateWith = makingChargesPaisa + wastageValuePaisa;
          final int aggregateWithout = makingChargesPaisa;
          final int gstDelta =
              (aggregateWith * 5 ~/ 100) - (aggregateWithout * 5 ~/ 100);

          final int expectedDifference = wastageValuePaisa + gstDelta;
          final int actualDifference = totalWithWastage - totalWithoutWastage;

          return actualDifference == expectedDifference;
        },
        [
          Gen.tuple(<Generator<dynamic>>[
            _weightGen,
            _rateGen,
            _makingRateGen,
            _wastageGen,
            _purityGen,
          ]),
        ],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason: 'Wastage must contribute exactly once to the total',
      );
    });
  });

  // ==========================================================================
  // Property 15: Stone charge is linear in stone count
  // Feature: jewellery-vertical-remediation, Property 15
  // **Validates: Requirements 8.3**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, Property 15: '
      'Stone charge is linear in stone count', () {
    test('Property 15: stone charge = n * perStoneCharge; '
        'doubling count doubles charge', () {
      final bool held = forAll(
        (List<dynamic> args) {
          final int stoneCount = args[0] as int;
          final int perStoneCharge = args[1] as int;
          final double weight = args[2] as double;
          final int rate = args[3] as int;

          final config = _perGramConfig(
            ratePaisaPerGram: 50000,
            stoneMakingChargePaisa: perStoneCharge,
          );

          // Calculate with stoneCount = n
          final resultN = MakingChargesCalculator.calculate(
            CalculateMakingChargesRequest(
              config: config,
              metalWeightGrams: weight,
              metalRatePaisaPerGram: rate,
              stoneWeightGrams: 1.0, // needed to trigger stone calc
              stoneCount: stoneCount,
            ),
          );

          // Stone charge must equal n * perStoneCharge.
          final int expectedStoneCharge = stoneCount * perStoneCharge;
          if (resultN.stoneChargePaisa != expectedStoneCharge) return false;

          // Doubling the count must double the charge.
          final int doubledCount = stoneCount * 2;
          final resultDouble = MakingChargesCalculator.calculate(
            CalculateMakingChargesRequest(
              config: config,
              metalWeightGrams: weight,
              metalRatePaisaPerGram: rate,
              stoneWeightGrams: 1.0,
              stoneCount: doubledCount,
            ),
          );

          final int doubledExpected = doubledCount * perStoneCharge;
          if (resultDouble.stoneChargePaisa != doubledExpected) return false;

          // Linearity: 2n charge = 2 * n charge.
          if (resultDouble.stoneChargePaisa != 2 * resultN.stoneChargePaisa!) {
            return false;
          }

          return true;
        },
        [
          Gen.tuple(<Generator<dynamic>>[
            _stoneCountGen,
            _perStoneChargeGen,
            _weightGen,
            _rateGen,
          ]),
        ],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason: 'Stone charge must be linear: n * perStoneCharge',
      );
    });
  });

  // ==========================================================================
  // Task 4.16: Pricing-engine equivalence example test
  // **Validates: Requirements 7.3, 7.5**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, Task 4.16: '
      'Pricing-engine equivalence example test', () {
    test('Worked example: 10g 22K at ₹6000/g, ₹500/g making, '
        '5% wastage, 2 stones at ₹200 each, ₹1000 discount', () {
      // Inputs
      const double weightGrams = 10.0;
      const int ratePaisaPerGram = 600000; // ₹6000.00/g (effective 22K rate)
      const int makingRatePaisaPerGram = 50000; // ₹500/g
      const GoldPurity purity = GoldPurity.k22;
      const double wastagePercent = 5.0;
      const int stoneCount = 2;
      const int perStoneChargePaisa = 20000; // ₹200/stone
      const int discountPaisa = 100000; // ₹1000

      // --- Manual reference calculation (integer paise) ---
      // rate24K = ratePaisaPerGram * 1000 / finenessNumerator(22K=916)
      final int rate24K =
          (ratePaisaPerGram * GoldPurity.finenessDenominator) ~/
          purity.finenessNumerator;
      final int weightMg = (weightGrams * 1000).round(); // 10000

      // Metal value via half-up rounding (same as engine)
      final int metalValuePaisa = _computeMetalValuePaisa(
        weightMg,
        purity,
        rate24K,
      );

      // Making charges (perGram) = weight * makingRate
      final int makingChargesPaisa = (weightGrams * makingRatePaisaPerGram)
          .round();

      // Wastage = metalValue * wastage% ~/ 100
      final int wastagePaisa = metalValuePaisa * wastagePercent.toInt() ~/ 100;

      // Stone charges = stoneCount * perStoneCharge
      final int stoneChargePaisa = stoneCount * perStoneChargePaisa;

      // Aggregate = making + wastage + stone
      final int aggregateMaking =
          makingChargesPaisa + wastagePaisa + stoneChargePaisa;

      // Split GST
      final int metalGst = metalValuePaisa * 3 ~/ 100;
      final int makingGst = aggregateMaking * 5 ~/ 100;
      final int totalGst = metalGst + makingGst;

      // Total = metalValue + aggregate + GST - discount
      final int expectedTotal =
          metalValuePaisa + aggregateMaking + totalGst - discountPaisa;

      // --- Calculator result ---
      final config = _perGramConfig(
        ratePaisaPerGram: makingRatePaisaPerGram,
        stoneMakingChargePaisa: perStoneChargePaisa,
      );

      final result = MakingChargesCalculator.calculateTotalPrice(
        metalWeightGrams: weightGrams,
        metalRatePaisaPerGram: ratePaisaPerGram,
        makingChargesConfig: config,
        purity: purity,
        wastagePercent: wastagePercent,
        stoneCount: stoneCount,
        stoneWeightGrams: 0.5, // needed to trigger stone calc
        discountPaisa: discountPaisa,
      );

      // --- Canonical engine result ---
      final int canonicalTotal = JewelleryBusinessRules.billTotalPaisa(
        grossWeightMilligrams: weightMg,
        purity: purity,
        ratePerGram24KPaisa: rate24K,
        makingChargesPaisa: aggregateMaking,
        taxPaisa: totalGst,
        discountPaisa: discountPaisa,
      );

      // Assert all three agree to the paise.
      expect(
        result['totalPaisa'],
        equals(expectedTotal),
        reason: 'Calculator total must equal reference formula',
      );
      expect(
        canonicalTotal,
        equals(expectedTotal),
        reason: 'Canonical engine must equal reference formula',
      );
      expect(
        result['totalPaisa'],
        equals(canonicalTotal),
        reason: 'Calculator and canonical engine must agree',
      );

      // Verify the formula: total = weight×rate + making + tax − discount
      expect(
        expectedTotal,
        equals(metalValuePaisa + aggregateMaking + totalGst - discountPaisa),
        reason: 'Total must equal weight×rate + making + tax − discount',
      );

      // Verify split GST values individually.
      expect(result['metalValueGstPaisa'], equals(metalGst));
      expect(result['makingChargesGstPaisa'], equals(makingGst));
      expect(result['gstPaisa'], equals(totalGst));
    });

    test('Worked example: 5g 24K at ₹7500/g, fixed ₹2000 making, '
        'no wastage, no stones, no discount', () {
      const double weightGrams = 5.0;
      const int ratePaisaPerGram = 750000; // ₹7500/g
      const GoldPurity purity = GoldPurity.k24;
      const int fixedMakingPaisa = 200000; // ₹2000

      final config = MakingChargesConfig(
        id: 'test-fixed',
        tenantId: 'test-tenant',
        name: 'Fixed Making',
        type: MakingChargeType.fixed,
        fixedAmountPaisa: fixedMakingPaisa,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final result = MakingChargesCalculator.calculateTotalPrice(
        metalWeightGrams: weightGrams,
        metalRatePaisaPerGram: ratePaisaPerGram,
        makingChargesConfig: config,
        purity: purity,
      );

      // Manual calculation
      final int rate24K =
          (ratePaisaPerGram * GoldPurity.finenessDenominator) ~/
          purity.finenessNumerator;
      const int weightMg = 5000;
      final int metalValuePaisa = _computeMetalValuePaisa(
        weightMg,
        purity,
        rate24K,
      );

      const int aggregateMaking = fixedMakingPaisa;
      final int metalGst = metalValuePaisa * 3 ~/ 100;
      final int makingGst = aggregateMaking * 5 ~/ 100;
      final int totalGst = metalGst + makingGst;
      final int expectedTotal = metalValuePaisa + aggregateMaking + totalGst;

      // Canonical engine
      final int canonicalTotal = JewelleryBusinessRules.billTotalPaisa(
        grossWeightMilligrams: weightMg,
        purity: purity,
        ratePerGram24KPaisa: rate24K,
        makingChargesPaisa: aggregateMaking,
        taxPaisa: totalGst,
      );

      expect(result['totalPaisa'], equals(expectedTotal));
      expect(canonicalTotal, equals(expectedTotal));
      expect(result['totalPaisa'], equals(canonicalTotal));
    });

    test('Worked example: 2g 18K at ₹4500/g, percentage making 10%, '
        'no wastage, no stones, ₹200 discount', () {
      const double weightGrams = 2.0;
      const int ratePaisaPerGram = 450000; // ₹4500/g
      const GoldPurity purity = GoldPurity.k18;
      const double percentageMaking = 10.0;
      const int discountPaisa = 20000; // ₹200

      final config = MakingChargesConfig(
        id: 'test-pct',
        tenantId: 'test-tenant',
        name: 'Percentage Making',
        type: MakingChargeType.percentage,
        percentageOfMetalValue: percentageMaking,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final result = MakingChargesCalculator.calculateTotalPrice(
        metalWeightGrams: weightGrams,
        metalRatePaisaPerGram: ratePaisaPerGram,
        makingChargesConfig: config,
        purity: purity,
        discountPaisa: discountPaisa,
      );

      // Manual calculation
      final int rate24K =
          (ratePaisaPerGram * GoldPurity.finenessDenominator) ~/
          purity.finenessNumerator;
      const int weightMg = 2000;
      final int metalValuePaisa = _computeMetalValuePaisa(
        weightMg,
        purity,
        rate24K,
      );

      // Making charges: percentage calc uses weight * rate * pct / 100
      // (the calculator does: metalValue = weight * metalRatePaisaPerGram)
      final int makingChargesPaisa =
          (weightGrams * ratePaisaPerGram * (percentageMaking / 100)).round();

      final int aggregateMaking = makingChargesPaisa;
      final int metalGst = metalValuePaisa * 3 ~/ 100;
      final int makingGst = aggregateMaking * 5 ~/ 100;
      final int totalGst = metalGst + makingGst;
      final int expectedTotal =
          metalValuePaisa + aggregateMaking + totalGst - discountPaisa;

      final int canonicalTotal = JewelleryBusinessRules.billTotalPaisa(
        grossWeightMilligrams: weightMg,
        purity: purity,
        ratePerGram24KPaisa: rate24K,
        makingChargesPaisa: aggregateMaking,
        taxPaisa: totalGst,
        discountPaisa: discountPaisa,
      );

      expect(result['totalPaisa'], equals(expectedTotal));
      expect(canonicalTotal, equals(expectedTotal));
      expect(result['totalPaisa'], equals(canonicalTotal));
    });
  });
}
