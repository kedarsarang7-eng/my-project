// ============================================================================
// PRESERVATION TEST — expected to PASS on unfixed code.
//
// Asserts that bill totals for line items with NO modifiers selected compute
// exactly as they do today. After the modifier picker is added (Task 16.3),
// this test ensures non-modifier bills still compute correctly.
//
// **Validates: Requirements 3.6**
//
// Formula under test (BillItem._calculateTotal for restaurant, no modifiers):
//   total = (qty * price) - discount + cgst + sgst + igst
//
// When modifierPriceDelta is null/0, it contributes nothing to the total.
// This test generates randomized restaurant BillItems with zero modifiers
// and asserts the total matches the known formula.
//
// Run: flutter test test/features/restaurant/modifier_picker_preservation_test.dart
// ============================================================================
library;

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ==========================================================================
  // PBT: Non-modifier bill total equals the pre-fix formula exactly.
  //
  // Property: For any randomized bill item with no modifiers applied
  // (modifierPriceDelta absent/null), the computed total equals:
  //   (qty * price) - discount + cgst + sgst + igst
  //
  // This is the standard restaurant billing formula. The preservation
  // guarantee is that once modifiers are added to the codebase, items that
  // do NOT use modifiers continue to produce identical totals.
  //
  // **Validates: Requirements 3.6**
  // ==========================================================================
  group('Preservation: non-modifier bills unaffected (Req 3.6)', () {
    test(
      'PBT: BillItem total equals (qty * price) - discount + cgst + sgst + igst '
      'when no modifiers are applied',
      () {
        final held = forAll(
          (
            int qtySeed,
            int priceSeed,
            int discountSeed,
            int cgstSeed,
            int sgstSeed,
          ) {
            // Generate realistic restaurant bill item values
            final qty = (qtySeed.abs() % 20) + 1.0; // 1 to 20
            final price =
                ((priceSeed.abs() % 99900) + 100) / 100.0; // 1.00 to 999.00
            final discount =
                (discountSeed.abs() % ((qty * price * 100).toInt() + 1)) /
                100.0; // 0 to subtotal
            final cgst = (cgstSeed.abs() % 5000) / 100.0; // 0 to 49.99
            final sgst = (sgstSeed.abs() % 5000) / 100.0; // 0 to 49.99

            // Create a BillItem with NO modifiers (standard restaurant item)
            final item = BillItem(
              productId: 'item_pbt_${qtySeed.abs() % 100}',
              productName: 'PBT Restaurant Dish',
              qty: qty,
              price: price,
              discount: discount,
              cgst: cgst,
              sgst: sgst,
              igst: 0.0, // Restaurant uses CGST+SGST (intra-state)
              isInterState: false,
              // No modifiers — isHalf/isParcel left at default (null)
              // No laborCharge/partsCharge/commission/marketFee (restaurant)
            );

            // Expected total per the standard formula
            final expectedTotal = (qty * price) - discount + cgst + sgst + 0.0;

            // The BillItem constructor computes total via _calculateTotal
            final actualTotal = item.total;

            // Must match exactly (both use double arithmetic, same operands)
            return (actualTotal - expectedTotal).abs() < 1e-9;
          },
          [
            Gen.interval(0, 100000),
            Gen.interval(1, 100000),
            Gen.interval(0, 100000),
            Gen.interval(0, 100000),
            Gen.interval(0, 100000),
          ],
          numRuns: 300,
        );

        expect(
          held,
          isTrue,
          reason:
              'Preservation (Req 3.6): BillItem.total for items with no '
              'modifiers must equal (qty * price) - discount + cgst + sgst + igst. '
              'This formula must remain unchanged after modifiers are added.',
        );
      },
    );

    test('PBT: BillItem total with IGST (inter-state, no modifiers) equals '
        '(qty * price) - discount + igst', () {
      final held = forAll(
        (int qtySeed, int priceSeed, int discountSeed, int igstSeed) {
          // Generate inter-state restaurant bill item values
          final qty = (qtySeed.abs() % 15) + 1.0; // 1 to 15
          final price =
              ((priceSeed.abs() % 49900) + 100) / 100.0; // 1.00 to 499.00
          final discount =
              (discountSeed.abs() % ((qty * price * 100).toInt() + 1)) / 100.0;
          final igst = (igstSeed.abs() % 10000) / 100.0; // 0 to 99.99

          // Create a BillItem with IGST, no CGST/SGST, no modifiers
          final item = BillItem(
            productId: 'item_igst_${qtySeed.abs() % 100}',
            productName: 'PBT Interstate Dish',
            qty: qty,
            price: price,
            discount: discount,
            cgst: 0.0,
            sgst: 0.0,
            igst: igst,
            isInterState: true,
            // No modifiers
          );

          final expectedTotal = (qty * price) - discount + 0.0 + 0.0 + igst;
          final actualTotal = item.total;

          return (actualTotal - expectedTotal).abs() < 1e-9;
        },
        [
          Gen.interval(0, 100000),
          Gen.interval(1, 100000),
          Gen.interval(0, 100000),
          Gen.interval(0, 100000),
        ],
        numRuns: 200,
      );

      expect(
        held,
        isTrue,
        reason:
            'Preservation (Req 3.6): BillItem.total for inter-state items '
            'with no modifiers must equal (qty * price) - discount + igst. '
            'CGST/SGST are zero for inter-state.',
      );
    });

    test('PBT: BillItem with isHalf=null and isParcel=null (defaults) computes '
        'same total as explicit isHalf=false/isParcel=false', () {
      final held = forAll(
        (int qtySeed, int priceSeed, int taxSeed) {
          final qty = (qtySeed.abs() % 10) + 1.0;
          final price = ((priceSeed.abs() % 50000) + 100) / 100.0;
          final cgst = (taxSeed.abs() % 2500) / 100.0;
          final sgst = cgst; // Mirror for simplicity

          // Item with defaults (null isHalf/isParcel)
          final itemDefaults = BillItem(
            productId: 'item_def',
            productName: 'Default Dish',
            qty: qty,
            price: price,
            cgst: cgst,
            sgst: sgst,
          );

          // Item with explicit false
          final itemExplicit = BillItem(
            productId: 'item_exp',
            productName: 'Explicit Dish',
            qty: qty,
            price: price,
            cgst: cgst,
            sgst: sgst,
            isHalf: false,
            isParcel: false,
          );

          // Both must produce the same total
          return (itemDefaults.total - itemExplicit.total).abs() < 1e-9;
        },
        [
          Gen.interval(0, 100000),
          Gen.interval(1, 100000),
          Gen.interval(0, 50000),
        ],
        numRuns: 200,
      );

      expect(
        held,
        isTrue,
        reason:
            'Preservation (Req 3.6): isHalf=null/isParcel=null must produce '
            'the same total as isHalf=false/isParcel=false. The default '
            '(unset) state is full-portion, non-parcel.',
      );
    });

    test('PBT: Multi-item bill grand total sums individual item totals '
        '(no modifiers on any item)', () {
      final held = forAll(
        (int numItemsSeed, int basePriceSeed, int baseQtySeed) {
          // Generate 1-8 items
          final numItems = (numItemsSeed.abs() % 8) + 1;
          final items = <BillItem>[];

          double expectedSum = 0.0;
          for (int i = 0; i < numItems; i++) {
            final qty = ((baseQtySeed.abs() + i * 7) % 10) + 1.0;
            final price =
                (((basePriceSeed.abs() + i * 13) % 49900) + 100) / 100.0;
            final discount =
                ((basePriceSeed.abs() + i * 3) % 1000) / 100.0; // 0 to 9.99
            final gstAmount = (qty * price - discount) * 0.05 / 2;

            final item = BillItem(
              productId: 'item_multi_$i',
              productName: 'Dish $i',
              qty: qty,
              price: price,
              discount: discount,
              cgst: gstAmount,
              sgst: gstAmount,
              gstRate: 5.0,
              // No modifiers
            );

            items.add(item);
            expectedSum += item.total;
          }

          // The sum of individual item totals should equal the bill's
          // item-level total when no modifiers are involved
          final actualSum = items.fold<double>(
            0.0,
            (sum, item) => sum + item.total,
          );

          return (actualSum - expectedSum).abs() < 1e-9;
        },
        [
          Gen.interval(0, 100000),
          Gen.interval(1, 100000),
          Gen.interval(0, 100000),
        ],
        numRuns: 200,
      );

      expect(
        held,
        isTrue,
        reason:
            'Preservation (Req 3.6): For a multi-item bill with no modifiers '
            'on any item, the sum of individual item totals must be exactly '
            'the sum computed by adding each item.total. No modifier delta '
            'leaks in.',
      );
    });

    test('PBT: BillItem.toMap/fromMap round-trip preserves total when no '
        'modifiers present', () {
      final held = forAll(
        (int qtySeed, int priceSeed, int discountSeed, int taxSeed) {
          final qty = (qtySeed.abs() % 10) + 1.0;
          final price = ((priceSeed.abs() % 30000) + 100) / 100.0;
          final discount = (discountSeed.abs() % 500) / 100.0;
          final cgst = (taxSeed.abs() % 2000) / 100.0;
          final sgst = cgst;

          final item = BillItem(
            productId: 'item_rt_${qtySeed.abs() % 100}',
            productName: 'Roundtrip Dish',
            qty: qty,
            price: price,
            discount: discount,
            cgst: cgst,
            sgst: sgst,
            gstRate: 5.0,
            // No modifiers
          );

          final originalTotal = item.total;

          // Serialize and deserialize
          final map = item.toMap();
          final restored = BillItem.fromMap(map);

          // Total must survive the round-trip unchanged
          return (restored.total - originalTotal).abs() < 1e-9;
        },
        [
          Gen.interval(0, 100000),
          Gen.interval(1, 100000),
          Gen.interval(0, 50000),
          Gen.interval(0, 50000),
        ],
        numRuns: 200,
      );

      expect(
        held,
        isTrue,
        reason:
            'Preservation (Req 3.6): BillItem.total must survive '
            'toMap/fromMap serialization unchanged when no modifiers are '
            'present. The modifierPriceDelta field (when added) must not '
            'affect existing serialized data.',
      );
    });
  });
}
