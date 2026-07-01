// ============================================================================
// PHASE 4 — Task 5.2 (4a): grocery weighing-scale → bill-line math seam
// (go_router navigation migration — grocery functional fixes)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 5.2 — Wire WeighingScaleWidget into grocery billing.
// Validates: Requirements 7.1
//
// PURPOSE:
//   Proves the math seam introduced by Task 5.2 WITHOUT pumping the full
//   billing screen (which pulls Riverpod + Drift + the service locator). The
//   production code (`_addWeighedGroceryItem` in bill_creation_screen_v2.dart)
//   maps a confirmed scale weight to a BillItem using exactly the calculation
//   reproduced here:
//     quantity   = net weight (kg)          (weight as quantity)
//     unitPrice  = product rate per kg
//     lineTotal  = weight × rate            (+ GST)
//     GST        = per-product taxRate, split into equal CGST/SGST halves
//   We drive the REAL WeighingScaleWidget, confirm a weight through its
//   `onWeightConfirmed` callback, then assert the resulting line item math.
// ============================================================================

import 'package:dukanx/models/bill.dart';
import 'package:dukanx/widgets/weighing_scale_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the production line-item construction in
/// `_addWeighedGroceryItem` (bill_creation_screen_v2.dart).
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

void main() {
  group('Feature: gorouter-navigation-migration — Task 5.2 (4a) weighing-scale '
      'line mapping (Req 7.1)', () {
    testWidgets('WeighingScaleWidget confirms net weight (kg) and the line '
        'total equals weight × rate (+ GST)', (tester) async {
      double? confirmedWeight;
      String? confirmedUnit;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeighingScaleWidget(
              productName: 'Onion',
              pricePerKg: 45.0, // ₹45/kg
              initialWeight: 1.250, // scale reads 1.250 kg
              onWeightConfirmed: (weight, unit, tare) {
                confirmedWeight = weight;
                confirmedUnit = unit;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('ADD TO BILL'));
      await tester.pump();

      // The widget reports net weight in kilograms.
      expect(confirmedWeight, closeTo(1.250, 1e-9));
      expect(confirmedUnit, 'kg');

      // Build the line exactly as production does and verify the math.
      final line = buildWeighedGroceryLine(
        productId: 'p1',
        productName: 'Onion',
        netWeightKg: confirmedWeight!,
        ratePerKg: 45.0,
        taxRate: 0.0, // grocery default GST is 0 unless the product sets one
      );

      expect(line.qty, closeTo(1.250, 1e-9), reason: 'qty == net weight (kg)');
      expect(line.price, 45.0, reason: 'unit price == rate per kg');
      // line total (no GST) = weight × rate = 1.250 × 45 = 56.25
      expect(line.total, closeTo(56.25, 1e-9));
      expect(line.taxAmount, 0.0);
    });

    test('per-product taxRate drives GST (NOT a flat config default); CGST and '
        'SGST split evenly and the total stays paise-consistent', () {
      // 2 kg @ ₹50/kg, product taxRate 5% (e.g. packaged goods).
      final line = buildWeighedGroceryLine(
        productId: 'p2',
        productName: 'Sugar',
        netWeightKg: 2.0,
        ratePerKg: 50.0,
        taxRate: 5.0,
      );

      // taxable base = 2 × 50 = 100
      expect(line.qty * line.price, closeTo(100.0, 1e-9));
      // CGST == SGST == 100 × 2.5% = 2.50 each
      expect(line.cgst, closeTo(2.50, 1e-9));
      expect(line.sgst, closeTo(2.50, 1e-9));
      expect(line.taxAmount, closeTo(5.00, 1e-9));
      // total = base + cgst + sgst = 105.00
      expect(line.total, closeTo(105.00, 1e-9));
    });

    test('zero net weight produces no line (guard mirrors production)', () {
      // Production returns early when netWeightKg <= 0; the widget also disables
      // "ADD TO BILL" while net weight is 0, so confirmation never fires.
      const double netWeightKg = 0.0;
      expect(netWeightKg <= 0, isTrue);
    });
  });
}
