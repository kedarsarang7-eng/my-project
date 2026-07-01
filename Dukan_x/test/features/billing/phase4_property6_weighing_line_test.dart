// ============================================================================
// PHASE 4 — Task 5.3: PROPERTY TEST
// Feature: gorouter-navigation-migration, Property 6: Weighing-scale line
// mapping
// **Validates: Requirements 7.1**
// ============================================================================
//
// Property 6 (design.md):
//   "For any positive net weight and price-per-kg, confirming a loose-weight
//    grocery item produces a bill line whose quantity equals the captured net
//    weight (in the chosen kg/gm unit) and whose line total equals net weight ×
//    price-per-kg."
//
// This suite drives the SAME math seam Task 5.2 introduced in production
// (`_addWeighedGroceryItem` in bill_creation_screen_v2.dart) without pumping the
// heavy billing screen (which pulls Riverpod + Drift + the service locator).
// The pure helper `buildWeighedGroceryLine` below is a byte-for-byte mirror of
// the production line construction (and of the helper in the Task 5.2 unit test
// `grocery_weighing_line_test.dart`):
//
//     qty       = net weight (kg)                 // weight as quantity
//     price     = product rate per kg
//     halfGst   = qty * (price * (taxRate / 200)) // CGST == SGST
//     lineTotal = (qty * price) + cgst + sgst      // BillItem._calculateTotal
//
// For >=100 generated iterations over (positive net weight) × (positive
// price-per-kg) × (taxRate ∈ {0,5,12,18}) the property asserts:
//
//   (a) line.qty == net weight               (weight is the quantity)
//   (b) line.unit == 'kg'                     (the captured kg/gm unit)
//   (c) line.netWeight == net weight         (net weight recorded on the line)
//   (d) subtotal (qty*price) == weight × rate (within float tolerance)
//   (e) taxRate == 0  => line.total == qty*price            (no GST)
//   (f) taxRate  > 0  => line.total == base + base*taxRate/100
//                        AND cgst == sgst == base*taxRate/200 (split evenly)
//
// Money math is double-based exactly as production; equalities that cross
// different floating-point evaluation orders are asserted with a tolerance
// (relative 1e-9 with a 1e-6 absolute floor) — tight enough to catch a real
// rounding/formula defect, loose enough to ignore last-bit FP noise.
//
// PBT library: dartproptest ^0.2.1 (glados is unresolvable here — see the
//   dev_dependency note in pubspec.yaml). `forAll((args...) => <bool>,
//   [gen1, gen2, ...], numRuns: N)` runs `numRuns` generated cases and returns
//   whether the predicate held for all of them (throwing a shrinking
//   counterexample otherwise).
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/features/billing/phase4_property6_weighing_line_test.dart
// ============================================================================

import 'dart:math' as math;

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the production line-item construction in `_addWeighedGroceryItem`
/// (bill_creation_screen_v2.dart) and the Task 5.2 unit-test helper.
BillItem buildWeighedGroceryLine({
  required String productId,
  required String productName,
  required double netWeightKg,
  required double ratePerKg,
  required double taxRate,
}) {
  final double qty = netWeightKg;
  final double price = ratePerKg;
  final double halfGst = qty * (price * (taxRate / 200));
  return BillItem(
    productId: productId,
    productName: productName,
    qty: qty,
    price: price,
    unit: 'kg',
    gstRate: taxRate,
    cgst: halfGst,
    sgst: halfGst,
    netWeight: qty,
  );
}

/// Float comparison with a relative tolerance and a small absolute floor.
/// Returns true when [a] and [b] agree to within the tolerance.
bool _approx(double a, double b, {double rel = 1e-9, double absFloor = 1e-6}) {
  final double diff = (a - b).abs();
  final double scale = math.max(a.abs(), b.abs());
  return diff <= math.max(absFloor, rel * scale);
}

void main() {
  // At least 100 iterations are required by the spec; 200 matches the default
  // and the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // --- Generators -----------------------------------------------------------
  // Net weight: 0.001 .. 100.000 kg (1 g .. 100 kg), 3-decimal precision —
  // realistic loose-weight grocery range, always positive.
  final Generator<double> netWeightGen = Gen.interval(
    1,
    100000,
  ).map((i) => (i as int) / 1000.0);

  // Price per kg: ₹1.00 .. ₹100000.00, paise (2-decimal) precision — includes
  // realistic decimals, always positive.
  final Generator<double> ratePerKgGen = Gen.interval(
    100,
    10000000,
  ).map((i) => (i as int) / 100.0);

  // Tax rate over the realistic GST slab set.
  final Generator<double> taxRateGen = Gen.elementOf<int>(<int>[
    0,
    5,
    12,
    18,
  ]).map((i) => (i as int).toDouble());

  group('Feature: gorouter-navigation-migration, Property 6: Weighing-scale '
      'line mapping — Req 7.1', () {
    test(
      'Property 6: for any positive net weight, price-per-kg and GST slab, the '
      'weighed grocery line has qty == net weight and total == weight × rate '
      '(+ GST)',
      () {
        final held = forAll(
          (double netWeightKg, double ratePerKg, double taxRate) {
            final line = buildWeighedGroceryLine(
              productId: 'p1',
              productName: 'Loose Item',
              netWeightKg: netWeightKg,
              ratePerKg: ratePerKg,
              taxRate: taxRate,
            );

            final double base = netWeightKg * ratePerKg;

            // (a) quantity equals the captured net weight.
            if (!_approx(line.qty, netWeightKg)) return false;
            // (b) the captured unit is kg.
            if (line.unit != 'kg') return false;
            // (c) net weight is recorded on the line.
            if (line.netWeight == null ||
                !_approx(line.netWeight!, netWeightKg)) {
              return false;
            }
            // (d) subtotal (qty * price) equals weight × rate.
            if (!_approx(line.qty * line.price, base)) return false;

            if (taxRate == 0) {
              // (e) no GST => total is exactly the base.
              if (!_approx(line.total, base)) return false;
              if (!_approx(line.taxAmount, 0.0)) return false;
            } else {
              // (f) total == base + base*taxRate/100; CGST == SGST ==
              //     base*taxRate/200.
              final double expectedHalf = base * taxRate / 200;
              final double expectedTotal = base + base * taxRate / 100;
              if (!_approx(line.cgst, expectedHalf)) return false;
              if (!_approx(line.sgst, expectedHalf)) return false;
              if (!_approx(line.cgst, line.sgst)) return false;
              if (!_approx(line.total, expectedTotal)) return false;
            }
            return true;
          },
          [netWeightGen, ratePerKgGen, taxRateGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );
  });
}
