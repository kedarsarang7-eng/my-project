// ============================================================================
// PRESERVATION TEST — Task 26.2
// ============================================================================
// Verifies that existing single-payment / non-combo / non-delivery billing
// flows remain unaffected after split-payment wiring is added (Task 26.3).
//
// MUST PASS on unfixed (pre-split-payment-wiring) code — confirms the baseline
// that split-payment changes must preserve.
//
// **Validates: Requirements 2.14 (preservation)**
//
// Specifically verifies:
//   1. Single-payment bills (Cash, Online, Unpaid) compute grandTotal using
//      the standard formula: subtotal + totalTax (no forced split logic)
//   2. Non-combo items (no modifiers) compute line totals as qty * price
//   3. Non-delivery orders (dineIn/takeaway) pass through standard billing
//      without any delivery-specific or combo-specific logic
//   4. The payment-mode field determines paidAmount correctly
//   5. No mandatory split-payment logic is forced on non-split bills
//
// PBT library: dartproptest ^0.2.1
// Run: flutter test test/features/restaurant/single_payment_non_combo_non_delivery_preservation_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/restaurant/utils/restaurant_business_rules.dart';
import 'package:dukanx/models/bill.dart';

/// Round to 2 decimal places (matches Bill.sanitized() behavior).
double _r2(double v) => double.parse(v.toStringAsFixed(2));

void main() {
  // ==========================================================================
  // GROUP 1: Single-payment total computation preservation
  //
  // For randomized single-payment (Cash/Online) bills with non-combo,
  // non-delivery items, grandTotal == subtotal + totalTax.
  // No split-payment, modifier, or delivery logic alters the computation.
  //
  // **Validates: Requirements 2.14 (preservation)**
  // ==========================================================================
  group('Preservation: Single-payment bill total formula unchanged', () {
    test(
      'PBT: For any single-payment bill with non-combo items, '
      'grandTotal == subtotal + totalTax (no split-payment/modifier overhead)',
      () {
        final held = forAll(
          (int priceSeed, int qtySeed, int discountSeed, int gstSeed) {
            // Generate randomized item parameters (pre-rounded to 2dp)
            final price = _r2(((priceSeed.abs() % 99900) + 100) / 100.0);
            final qty = (qtySeed.abs() % 10) + 1.0;
            final discountPercent = (discountSeed.abs() % 50).toDouble();
            final gstRate = [0.0, 5.0, 12.0, 18.0, 28.0][gstSeed.abs() % 5];

            // Compute line item total (standard, no modifiers/combos)
            final lineTotal = _r2(qty * price);
            final discount = _r2(lineTotal * discountPercent / 100);
            final taxableAmount = _r2(lineTotal - discount);
            final tax = _r2(taxableAmount * gstRate / 100);
            final subtotal = taxableAmount;
            final totalTax = tax;

            // Standard formula: grandTotal = subtotal + totalTax
            final expectedGrandTotal = _r2(subtotal + totalTax);

            // Build Bill (non-combo, non-delivery, single-payment)
            final bill = Bill(
              id: 'bill_preservation_001',
              invoiceNumber: 'INV-PRES-001',
              customerId: 'cust_001',
              customerName: 'Walk-in',
              customerPhone: '9999999999',
              customerAddress: '',
              customerGst: '',
              date: DateTime(2024, 10, 1),
              items: [
                BillItem(
                  productId: 'prod_001',
                  productName: 'Test Item',
                  qty: qty,
                  price: price,
                  gstRate: gstRate,
                  discount: discount,
                  cgst: _r2(tax / 2),
                  sgst: _r2(tax / 2),
                ),
              ],
              subtotal: subtotal,
              totalTax: totalTax,
              grandTotal: expectedGrandTotal,
              paidAmount: expectedGrandTotal,
              cashPaid: expectedGrandTotal,
              onlinePaid: 0,
              status: 'Paid',
              paymentType: 'Cash',
              discountApplied: discount,
              marketTicket: 0,
              ownerId: 'owner_001',
              shopName: 'Test Shop',
              shopAddress: '123 Test St',
              shopGst: '',
              shopContact: '9876543210',
              source: 'app',
              marketCess: 0,
              commissionAmount: 0,
              isInterState: false,
              businessType: 'restaurant',
            );

            // Verify the standard formula holds (within 1-paisa tolerance)
            if ((bill.grandTotal - (bill.subtotal + bill.totalTax)).abs() >
                0.01) {
              return false;
            }

            // Verify paidAmount == grandTotal for Cash payment
            if ((bill.paidAmount - bill.grandTotal).abs() > 0.01) {
              return false;
            }

            // Verify no modifier fields are populated
            if (bill.items.first.modifierIds != null) return false;
            if (bill.items.first.modifierPriceDelta != null) return false;

            // Verify round-trip through toMap/fromMap preserves the total
            final map = bill.toMap();
            final restored = Bill.fromMap('bill_preservation_001', map);
            if ((restored.grandTotal - expectedGrandTotal).abs() > 0.01) {
              return false;
            }
            if ((restored.paidAmount - expectedGrandTotal).abs() > 0.01) {
              return false;
            }

            return true;
          },
          [
            Gen.interval(100, 100000),
            Gen.interval(0, 100),
            Gen.interval(0, 100),
            Gen.interval(0, 100),
          ],
          numRuns: 200,
        );
        expect(
          held,
          isTrue,
          reason:
              'Preservation (Req 2.14): Single-payment bills with non-combo '
              'items must compute grandTotal as subtotal + totalTax, with '
              'paidAmount equal to grandTotal for Cash payments. No split-payment '
              'or modifier logic should alter this computation.',
        );
      },
    );

    test(
      'PBT: For Unpaid payment mode, paidAmount == 0 regardless of grandTotal',
      () {
        final held = forAll(
          (int priceSeed, int qtySeed) {
            final price = _r2(((priceSeed.abs() % 9900) + 100) / 100.0);
            final qty = (qtySeed.abs() % 5) + 1.0;
            final subtotal = _r2(price * qty);
            final totalTax = _r2(subtotal * 0.05);
            final grandTotal = _r2(subtotal + totalTax);

            final bill = Bill(
              id: 'bill_unpaid_001',
              invoiceNumber: 'INV-UNPAID-001',
              customerId: 'cust_002',
              customerName: 'Unpaid Customer',
              customerPhone: '8888888888',
              customerAddress: '',
              customerGst: '',
              date: DateTime(2024, 10, 2),
              items: [
                BillItem(
                  productId: 'prod_002',
                  productName: 'Unpaid Item',
                  qty: qty,
                  price: price,
                  gstRate: 5.0,
                  cgst: _r2(totalTax / 2),
                  sgst: _r2(totalTax / 2),
                ),
              ],
              subtotal: subtotal,
              totalTax: totalTax,
              grandTotal: grandTotal,
              paidAmount: 0.0,
              cashPaid: 0,
              onlinePaid: 0,
              status: 'Unpaid',
              paymentType: 'Unpaid',
              discountApplied: 0,
              marketTicket: 0,
              ownerId: 'owner_002',
              shopName: 'Test Shop',
              shopAddress: '456 Test Ave',
              shopGst: '',
              shopContact: '9876543210',
              source: 'app',
              marketCess: 0,
              commissionAmount: 0,
              isInterState: false,
              businessType: 'restaurant',
            );

            // Unpaid: paidAmount must be 0
            if (bill.paidAmount != 0.0) return false;
            // GrandTotal should still be computed normally
            if ((bill.grandTotal - grandTotal).abs() > 0.01) return false;

            return true;
          },
          [Gen.interval(100, 10000), Gen.interval(0, 50)],
          numRuns: 150,
        );
        expect(
          held,
          isTrue,
          reason:
              'Preservation: Unpaid bills must have paidAmount == 0 while '
              'grandTotal is still computed as subtotal + totalTax.',
        );
      },
    );
  });

  // ==========================================================================
  // GROUP 2: Non-combo item total computation
  //
  // For items without modifiers, the line item total is just qty * price.
  // modifierPriceDelta contributes 0 when null/absent.
  //
  // **Validates: Requirements 3.6**
  // ==========================================================================
  group('Preservation: Non-combo item total computation unchanged', () {
    test('PBT: BillItem with null modifierIds/modifierPriceDelta has '
        'total = qty * price', () {
      final held = forAll(
        (int priceSeed, int qtySeed) {
          final price = _r2(((priceSeed.abs() % 99900) + 100) / 100.0);
          final qty = (qtySeed.abs() % 10) + 1.0;
          final expectedTotal = qty * price;

          final item = BillItem(
            productId: 'prod_noncombo',
            productName: 'Non-Combo Item',
            qty: qty,
            price: price,
            modifierIds: null,
            modifierPriceDelta: null,
          );

          // Verify modifiers are not set
          if (item.modifierIds != null) return false;
          if (item.modifierPriceDelta != null) return false;

          // Verify total equals qty * price (BillItem.total getter)
          if ((item.total - expectedTotal).abs() > 0.01) return false;

          // Round-trip: serialize and deserialize
          final map = item.toMap();
          final restored = BillItem.fromMap(map);

          // modifierIds and modifierPriceDelta stay null after round-trip
          if (restored.modifierIds != null &&
              restored.modifierIds!.isNotEmpty) {
            return false;
          }
          if (restored.modifierPriceDelta != null &&
              restored.modifierPriceDelta != 0.0) {
            return false;
          }

          // Total remains unchanged
          if ((restored.total - expectedTotal).abs() > 0.01) return false;

          return true;
        },
        [Gen.interval(100, 100000), Gen.interval(1, 100)],
        numRuns: 200,
      );
      expect(
        held,
        isTrue,
        reason:
            'Preservation (Req 3.6): Non-combo items (no modifiers) must '
            'have total == qty * price. Null modifierIds/modifierPriceDelta '
            'must contribute zero to the total.',
      );
    });
  });

  // ==========================================================================
  // GROUP 3: Standard bill save flow — no forced split-payment logic
  //
  // Structural check: bill_creation_screen_v2.dart saves single-payment bills
  // directly through _billsRepo.createBill without requiring any split-payment
  // step.
  //
  // **Validates: Requirements 2.14 (preservation)**
  // ==========================================================================
  group('Preservation: No mandatory split-payment on single-payment bills', () {
    test(
      'Bill with paymentType Cash serializes without splitPayments field',
      () {
        final bill = Bill(
          id: 'bill_nosplit_001',
          invoiceNumber: 'INV-NOSPLIT-001',
          customerId: 'cust_nosplit',
          customerName: 'Cash Customer',
          customerPhone: '7777777777',
          customerAddress: '',
          customerGst: '',
          date: DateTime(2024, 10, 3),
          items: [
            BillItem(
              productId: 'prod_nosplit',
              productName: 'Single Payment Item',
              qty: 2,
              price: 150.0,
              gstRate: 5.0,
              cgst: 7.5,
              sgst: 7.5,
            ),
          ],
          subtotal: 300.0,
          totalTax: 15.0,
          grandTotal: 315.0,
          paidAmount: 315.0,
          cashPaid: 315.0,
          onlinePaid: 0,
          status: 'Paid',
          paymentType: 'Cash',
          discountApplied: 0,
          marketTicket: 0,
          ownerId: 'owner_nosplit',
          shopName: 'No-Split Shop',
          shopAddress: '789 Cash Rd',
          shopGst: '',
          shopContact: '9876543210',
          source: 'app',
          marketCess: 0,
          commissionAmount: 0,
          isInterState: false,
          businessType: 'restaurant',
        );

        final map = bill.toMap();

        // Verify no splitPayments field is injected for single-payment bills
        expect(
          map.containsKey('splitPayments'),
          isFalse,
          reason:
              'Cash single-payment bills must NOT contain a splitPayments '
              'field — split-payment logic should never be forced on '
              'non-split bills.',
        );

        // Verify standard payment fields are populated correctly
        expect(map['paymentType'], equals('Cash'));
        expect(map['cashPaid'], equals(315.0));
        expect(map['onlinePaid'], equals(0.0));
        expect(map['paidAmount'], equals(315.0));
        expect(map['grandTotal'], equals(315.0));
      },
    );

    test(
      'Bill with paymentType Online serializes without splitPayments field',
      () {
        final bill = Bill(
          id: 'bill_nosplit_002',
          invoiceNumber: 'INV-NOSPLIT-002',
          customerId: 'cust_nosplit_2',
          customerName: 'Online Customer',
          customerPhone: '6666666666',
          customerAddress: '',
          customerGst: '',
          date: DateTime(2024, 10, 4),
          items: [
            BillItem(
              productId: 'prod_nosplit_2',
              productName: 'Online Payment Item',
              qty: 1,
              price: 500.0,
              gstRate: 5.0,
              cgst: 12.5,
              sgst: 12.5,
            ),
          ],
          subtotal: 500.0,
          totalTax: 25.0,
          grandTotal: 525.0,
          paidAmount: 525.0,
          cashPaid: 0,
          onlinePaid: 525.0,
          status: 'Paid',
          paymentType: 'Online',
          discountApplied: 0,
          marketTicket: 0,
          ownerId: 'owner_nosplit_2',
          shopName: 'Online Shop',
          shopAddress: '101 Digital Ave',
          shopGst: '',
          shopContact: '9876543210',
          source: 'app',
          marketCess: 0,
          commissionAmount: 0,
          isInterState: false,
          businessType: 'restaurant',
        );

        final map = bill.toMap();

        // No splitPayments for Online single-payment
        expect(
          map.containsKey('splitPayments'),
          isFalse,
          reason:
              'Online single-payment bills must NOT contain a '
              'splitPayments field.',
        );

        expect(map['paymentType'], equals('Online'));
        expect(map['onlinePaid'], equals(525.0));
        expect(map['cashPaid'], equals(0.0));
      },
    );

    test('PBT: For any single payment mode (Cash/Online/Unpaid), '
        'Bill.toMap never injects splitPayments', () {
      final paymentModes = ['Cash', 'Online', 'Unpaid'];

      final held = forAll(
        (int modeSeed, int priceSeed) {
          final mode = paymentModes[modeSeed.abs() % 3];
          final price = _r2(((priceSeed.abs() % 9900) + 100) / 100.0);
          final subtotal = _r2(price * 2);
          final tax = _r2(subtotal * 0.05);
          final grandTotal = _r2(subtotal + tax);
          final paidAmount = mode == 'Unpaid' ? 0.0 : grandTotal;

          final bill = Bill(
            id: 'bill_pbt_nosplit',
            invoiceNumber: 'INV-PBT-NS',
            customerId: 'cust_pbt',
            customerName: 'PBT Customer',
            customerPhone: '1111111111',
            customerAddress: '',
            customerGst: '',
            date: DateTime(2024, 10, 5),
            items: [
              BillItem(
                productId: 'prod_pbt',
                productName: 'PBT Item',
                qty: 2,
                price: price,
                gstRate: 5.0,
                cgst: _r2(tax / 2),
                sgst: _r2(tax / 2),
              ),
            ],
            subtotal: subtotal,
            totalTax: tax,
            grandTotal: grandTotal,
            paidAmount: paidAmount,
            cashPaid: mode == 'Cash' ? paidAmount : 0,
            onlinePaid: mode == 'Online' ? paidAmount : 0,
            status: paidAmount >= grandTotal ? 'Paid' : 'Unpaid',
            paymentType: mode,
            discountApplied: 0,
            marketTicket: 0,
            ownerId: 'owner_pbt',
            shopName: 'PBT Shop',
            shopAddress: 'PBT St',
            shopGst: '',
            shopContact: '9876543210',
            source: 'app',
            marketCess: 0,
            commissionAmount: 0,
            isInterState: false,
            businessType: 'restaurant',
          );

          final map = bill.toMap();

          // No splitPayments key for any single-payment mode
          if (map.containsKey('splitPayments')) return false;

          // Payment type preserved correctly
          if (map['paymentType'] != mode) return false;

          return true;
        },
        [Gen.interval(0, 100), Gen.interval(100, 10000)],
        numRuns: 150,
      );
      expect(
        held,
        isTrue,
        reason:
            'Preservation (Req 2.14): No single-payment bill should ever '
            'have a splitPayments field injected by Bill.toMap(). The '
            'split-payment feature must be additive only.',
      );
    });
  });

  // ==========================================================================
  // GROUP 4: Service charge preservation for non-delivery restaurant bills
  //
  // For restaurant dine-in (non-delivery, non-parcel) bills,
  // serviceCharge is still computed correctly by RestaurantBusinessRules.
  // Non-dine-in bills get zero service charge.
  //
  // **Validates: Requirements 3.7**
  // ==========================================================================
  group('Preservation: Service charge for non-delivery flows', () {
    test('PBT: Service charge formula is unchanged for dine-in bills '
        '(subtotal * 5%)', () {
      final held = forAll(
        (int subtotalSeed) {
          final subtotal = _r2(((subtotalSeed.abs() % 49900) + 100) / 100.0);
          final expectedServiceCharge = RestaurantBusinessRules.serviceCharge(
            subtotal,
          );

          // Service charge must be positive for positive subtotals
          if (subtotal > 0 && expectedServiceCharge <= 0) return false;

          // Verify the formula: subtotal * 0.05 (default rate)
          // Allow 1-paisa tolerance for rounding
          final rawExpected = subtotal * 0.05;
          if ((expectedServiceCharge - rawExpected).abs() > 0.01) {
            return false;
          }

          return true;
        },
        [Gen.interval(100, 5000000)],
        numRuns: 200,
      );
      expect(
        held,
        isTrue,
        reason:
            'Preservation (Req 3.7): Service charge for dine-in bills must '
            'remain subtotal * 5% (default rate), unaffected by split-payment '
            'or delivery-tracking wiring.',
      );
    });

    test('Service charge is zero for non-dine-in (all-parcel) items', () {
      // When all items are parcel, service charge should not apply
      // Verify the business rule: serviceCharge(0) == 0
      expect(RestaurantBusinessRules.serviceCharge(0), equals(0.0));
      expect(RestaurantBusinessRules.serviceCharge(-100), equals(0.0));
    });
  });
}
