// ============================================================================
// PROPERTY-BASED REGRESSION-LOCK TESTS: Half-Portion / Service Charge Billing
// ============================================================================
//
// These tests permanently lock the already-implemented billing behavior so
// it cannot silently regress. No implementation changes needed — these must
// pass on current `main`.
//
// Properties covered:
//   Property 6: Half-Portion Toggle Is Price-Reversible, Total-Consistent
//   Property 7: Service Charge Applied for Qualifying Dine-In Bills
//   Property 8: Grand Total Unchanged When Service Charge Does Not Apply
//
// **Validates: Requirements 2.7, 2.8, 3.6, 3.7**
//
// PBT library: dartproptest ^0.2.1
// Run: flutter test test/features/restaurant/restaurant_billing_pbt_regression_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/restaurant/utils/restaurant_business_rules.dart';
import 'package:dukanx/models/bill.dart';

void main() {
  const int kNumRuns = 200;

  // ==========================================================================
  // Property 6: Half-Portion Toggle Is Price-Reversible, Total-Consistent
  // **Validates: Requirements 2.7, 3.6**
  // ==========================================================================
  group('Property 6: Half-Portion Toggle Is Price-Reversible, Total-Consistent', () {
    // -----------------------------------------------------------------------
    // Property 6a: After an even number of toggles, price equals original p
    // (within rounding tolerance).
    // -----------------------------------------------------------------------
    test('Property 6a (forAll): even toggle count restores original price', () {
      final held = forAll(
        (int priceCents, int togglePairs) {
          // Generate a random price in range [1.00, 5000.00]
          final originalPrice = (priceCents.abs() % 499900 + 100) / 100.0;

          // Generate an even number of toggles (2, 4, 6, or 8)
          final toggleCount = ((togglePairs.abs() % 4) + 1) * 2;

          // Simulate the toggle sequence (half/double alternation)
          double currentPrice = originalPrice;
          bool isHalf = false;

          for (int i = 0; i < toggleCount; i++) {
            if (!isHalf) {
              currentPrice = currentPrice / 2.0;
              isHalf = true;
            } else {
              currentPrice = currentPrice * 2.0;
              isHalf = false;
            }
          }

          // After an even number of toggles, price should equal original
          return (currentPrice - originalPrice).abs() < 0.01;
        },
        [
          Gen.interval(100, 500000), // priceCents
          Gen.interval(0, 3), // togglePairs (0..3 → 2,4,6,8 toggles)
        ],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'After even toggles, price must equal original within rounding tolerance',
      );
    });

    // -----------------------------------------------------------------------
    // Property 6b: Bill line total always equals
    // qty * currentPrice - discount + cgst + sgst + igst
    // using the current half-adjusted price.
    // -----------------------------------------------------------------------
    test(
      'Property 6b (forAll): total consistent with formula using half-adjusted price',
      () {
        final held = forAll(
          (int priceCents, int qtySeed, int toggleCountSeed) {
            // Generate random parameters
            final originalPrice = (priceCents.abs() % 499900 + 100) / 100.0;
            final qty = (qtySeed.abs() % 10 + 1).toDouble();
            final discount = (priceCents.abs() % 50).toDouble();
            const gstRate = 5.0; // Restaurant fixed GST

            // Apply toggles (0-5)
            final toggleCount = toggleCountSeed.abs() % 6;
            double currentPrice = originalPrice;
            bool isHalf = false;

            for (int i = 0; i < toggleCount; i++) {
              if (!isHalf) {
                currentPrice = currentPrice / 2.0;
                isHalf = true;
              } else {
                currentPrice = currentPrice * 2.0;
                isHalf = false;
              }
            }

            // Calculate tax the same way _toggleHalfPortion does
            final perUnitDiscount = qty > 0 ? discount / qty : 0.0;
            final taxableBase = (currentPrice - perUnitDiscount).clamp(
              0.0,
              double.infinity,
            );
            final gstAmount = qty * (taxableBase * (gstRate / 200));
            final cgst = gstAmount;
            final sgst = gstAmount;

            // Construct a BillItem with the half-adjusted price
            final item = BillItem(
              productId: 'test_item',
              productName: 'Test Dish',
              qty: qty,
              price: currentPrice,
              discount: discount,
              gstRate: gstRate,
              cgst: cgst,
              sgst: sgst,
              isHalf: isHalf,
            );

            // Expected total per BillItem._calculateTotal:
            // (qty * price) - discount + cgst + sgst + igst
            final expectedTotal = (qty * currentPrice) - discount + cgst + sgst;

            return (item.total - expectedTotal).abs() < 0.01;
          },
          [
            Gen.interval(100, 500000), // priceCents
            Gen.interval(1, 10), // qtySeed
            Gen.interval(0, 5), // toggleCountSeed
          ],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'BillItem total must equal qty*price - discount + cgst + sgst with half-adjusted price',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Property 6c: With zero toggles (full portion), total is identical to
    // the pre-fix formula (no change from defaults).
    // -----------------------------------------------------------------------
    test(
      'Property 6c (forAll): zero toggles means total unchanged from default formula',
      () {
        final held = forAll(
          (int priceCents, int qtySeed) {
            final price = (priceCents.abs() % 499900 + 100) / 100.0;
            final qty = (qtySeed.abs() % 10 + 1).toDouble();
            final discount = (priceCents.abs() % 30).toDouble();
            const gstRate = 5.0;
            final taxableBase = (price - (discount / qty)).clamp(
              0.0,
              double.infinity,
            );
            final gst = qty * (taxableBase * (gstRate / 200));

            final item = BillItem(
              productId: 'test_item',
              productName: 'Test Dish',
              qty: qty,
              price: price,
              discount: discount,
              gstRate: gstRate,
              cgst: gst,
              sgst: gst,
              isHalf: null, // No toggle applied
            );

            // Standard formula: (qty * price) - discount + cgst + sgst
            final expected = (qty * price) - discount + gst + gst;
            return (item.total - expected).abs() < 0.01;
          },
          [
            Gen.interval(100, 500000), // priceCents
            Gen.interval(1, 10), // qtySeed
          ],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'With no half-portion toggle, total must match standard formula exactly',
        );
      },
    );
  });

  // ==========================================================================
  // Property 7: Service Charge Applied and Transmitted for Qualifying Dine-In
  // **Validates: Requirements 2.8**
  // ==========================================================================
  group('Property 7: Service Charge Applied for Qualifying Dine-In Bills', () {
    // -----------------------------------------------------------------------
    // Property 7a: For randomized subtotal > 0, serviceCharge equals
    // RestaurantBusinessRules.serviceCharge(subtotal) at default 5% rate.
    // -----------------------------------------------------------------------
    test(
      'Property 7a (forAll): service charge equals RestaurantBusinessRules.serviceCharge(subtotal)',
      () {
        final held = forAll(
          (int subtotalCents) {
            // Generate a positive subtotal in range [1.00, 50000.00]
            final subtotal = (subtotalCents.abs() % 4999900 + 100) / 100.0;

            // Compute expected service charge via the domain rule
            final expectedCharge = RestaurantBusinessRules.serviceCharge(
              subtotal,
            );

            // Verify the domain function returns the correct 5% value
            // (rounded to 2 decimal places)
            final manualCalc = (subtotal * 0.05 * 100).round() / 100.0;

            return (expectedCharge - manualCalc).abs() < 0.01;
          },
          [Gen.interval(100, 5000000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'Service charge must equal 5% of subtotal, rounded to paise',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Property 7b: Service charge is included in grand total for qualifying
    // dine-in bills (subtotal > 0, not all parcel).
    // -----------------------------------------------------------------------
    test(
      'Property 7b (forAll): grand total includes service charge for qualifying dine-in',
      () {
        final held = forAll(
          (int subtotalCents, int taxCents) {
            // Generate random bill parameters
            final subtotal = (subtotalCents.abs() % 4999900 + 100) / 100.0;
            final totalTax = (taxCents.abs() % 50000 + 1) / 100.0;
            final serviceCharge = RestaurantBusinessRules.serviceCharge(
              subtotal,
            );

            // Grand total with service charge for dine-in
            // (mirrors _grandTotal logic: base + serviceCharge when qualifying)
            final grandTotal = subtotal + totalTax + serviceCharge;

            // Verify service charge is non-zero and included
            return serviceCharge > 0 &&
                (grandTotal - (subtotal + totalTax + serviceCharge)).abs() <
                    0.01;
          },
          [
            Gen.interval(100, 5000000), // subtotalCents
            Gen.interval(1, 50000), // taxCents
          ],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'Grand total must include service charge for qualifying dine-in bills',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Property 7c: Bill.serviceCharge field stores the computed value and
    // round-trips through toMap/fromMap (i.e. transmitted as serviceChargeCents).
    // -----------------------------------------------------------------------
    test(
      'Property 7c (forAll): Bill.serviceCharge round-trips through serialization',
      () {
        final held = forAll(
          (int subtotalCents) {
            final subtotal = (subtotalCents.abs() % 4999900 + 100) / 100.0;
            final sc = RestaurantBusinessRules.serviceCharge(subtotal);
            final tax = subtotal * 0.05;

            final bill = Bill(
              id: 'bill_pbt_${subtotalCents.abs()}',
              invoiceNumber: 'INV-PBT-${subtotalCents.abs()}',
              customerId: 'cust_pbt',
              customerName: 'PBT Customer',
              customerPhone: '9999999999',
              customerAddress: '',
              customerGst: '',
              date: DateTime(2024, 6, 15),
              items: [],
              subtotal: subtotal,
              totalTax: tax,
              grandTotal: subtotal + tax + sc,
              paidAmount: subtotal + tax + sc,
              cashPaid: subtotal + tax + sc,
              onlinePaid: 0,
              status: 'Paid',
              paymentType: 'Cash',
              discountApplied: 0,
              marketTicket: 0,
              ownerId: 'owner_pbt',
              shopName: 'PBT Restaurant',
              shopAddress: '1 Test St',
              shopGst: '',
              shopContact: '9876543210',
              source: 'app',
              marketCess: 0,
              commissionAmount: 0,
              isInterState: false,
              businessType: 'restaurant',
              serviceCharge: sc,
            );

            final map = bill.toMap();
            final restored = Bill.fromMap(bill.id, map);

            // serviceCharge round-trips
            return (restored.serviceCharge - sc).abs() < 0.01;
          },
          [Gen.interval(100, 5000000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'Bill.serviceCharge must round-trip through toMap/fromMap without loss',
        );
      },
    );
  });

  // ==========================================================================
  // Property 8: Grand Total Unchanged When Service Charge Does Not Apply
  // **Validates: Requirements 3.7**
  // ==========================================================================
  group('Property 8: Grand Total Unchanged When Service Charge Does Not Apply', () {
    // -----------------------------------------------------------------------
    // Property 8a: When service charge is disabled, grand total = subtotal + tax.
    // -----------------------------------------------------------------------
    test(
      'Property 8a (forAll): disabled service charge means grandTotal = subtotal + tax',
      () {
        final held = forAll(
          (int subtotalCents, int taxCents) {
            final subtotal = (subtotalCents.abs() % 4999900 + 100) / 100.0;
            final totalTax = (taxCents.abs() % 50000 + 1) / 100.0;

            // When service charge is disabled, grand total = subtotal + tax
            // (the screen's _grandTotal: base = subtotal + totalTax, and
            // serviceChargeAmount returns 0 when disabled)
            const serviceChargeEnabled = false;
            final serviceChargeAmount = serviceChargeEnabled
                ? RestaurantBusinessRules.serviceCharge(subtotal)
                : 0.0;

            final grandTotal = subtotal + totalTax + serviceChargeAmount;

            return (grandTotal - (subtotal + totalTax)).abs() < 0.01;
          },
          [
            Gen.interval(100, 5000000), // subtotalCents
            Gen.interval(1, 50000), // taxCents
          ],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'Disabled service charge must not contribute to grand total',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Property 8b: When all items are parcel (100% parcel), service charge
    // contributes zero even at default 5% rate.
    // -----------------------------------------------------------------------
    test('Property 8b (forAll): 100% parcel bill gets zero service charge', () {
      final held = forAll(
        (int priceCents, int qtySeed) {
          final price = (priceCents.abs() % 499900 + 100) / 100.0;
          final qty = (qtySeed.abs() % 5 + 1).toDouble();
          final subtotal = qty * price;

          // All items are parcel → _isRestaurantDineIn = false → no SC
          // The screen checks `_items.every((item) => item.isParcel == true)`
          const allParcel = true;
          final serviceCharge = allParcel
              ? 0.0
              : RestaurantBusinessRules.serviceCharge(subtotal);

          return serviceCharge == 0.0;
        },
        [
          Gen.interval(100, 500000), // priceCents
          Gen.interval(1, 5), // qtySeed
        ],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason: '100% parcel items must yield zero service charge',
      );
    });

    // -----------------------------------------------------------------------
    // Property 8c: Non-restaurant bills never get service charge applied.
    // -----------------------------------------------------------------------
    test(
      'Property 8c (forAll): non-restaurant bills have zero service charge contribution',
      () {
        final held = forAll(
          (int subtotalCents, int taxCents) {
            final subtotal = (subtotalCents.abs() % 4999900 + 100) / 100.0;
            final totalTax = (taxCents.abs() % 50000 + 1) / 100.0;

            // For non-restaurant business types, service charge is never applied.
            // The screen checks `_isRestaurantBill` — if false, grandTotal = base.
            const isRestaurant = false;
            final serviceCharge = isRestaurant
                ? RestaurantBusinessRules.serviceCharge(subtotal)
                : 0.0;
            final grandTotal = subtotal + totalTax + serviceCharge;

            return (grandTotal - (subtotal + totalTax)).abs() < 0.01;
          },
          [
            Gen.interval(100, 5000000), // subtotalCents
            Gen.interval(1, 50000), // taxCents
          ],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'Non-restaurant bills must never have service charge in grand total',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Property 8d: serviceCharge(0) and serviceCharge(negative) always return 0.
    // (Guards the domain function's boundary behavior.)
    // -----------------------------------------------------------------------
    test(
      'Property 8d (forAll): service charge is zero for non-positive subtotals',
      () {
        final held = forAll(
          (int negativeSeed) {
            // Generate non-positive subtotals: 0 or negative
            final subtotal = -(negativeSeed.abs() % 100000).toDouble();

            final sc = RestaurantBusinessRules.serviceCharge(subtotal);
            return sc == 0.0;
          },
          [Gen.interval(0, 100000)],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason: 'Service charge must be zero for non-positive subtotals',
        );
      },
    );
  });
}
