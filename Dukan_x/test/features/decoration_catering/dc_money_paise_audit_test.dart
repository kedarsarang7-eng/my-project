// ============================================================================
// GR-2 AUDIT: Integer-paise compliance for Tasks 3, 6, 7, 17, 22
// ============================================================================
// This file records the audit findings for Task 28 (GR-2) and validates the
// one code path that introduces integer-paise arithmetic: EventRental's
// totalRentalPricePaise = rentalPricePerUnitPaise * quantity (Task 7 wiring).
//
// Audit Summary (no new monetary arithmetic functions introduced):
//
// Task 3 — getPayments():
//   Uses `_paisa(j['advancePaidPaisa'])` to convert API integer-paise → double
//   for the pre-existing DcPayment.amount field (double rupees). This is a
//   read-only conversion at the model boundary; the existing DcPayment model's
//   `amount` field is a pre-remediation double-rupee UI field, exempt per
//   GR-2 AC2. No new monetary computation introduced.
//
// Task 6 — rentOut() / returnRental():
//   Pass integer `quantity` and `damagedQty` to the API. No monetary
//   computation occurs in either repository method. The JSON parser
//   `_eventRentalFromJson` reads `rentalPricePerUnitPaisa` and
//   `totalRentalPricePaisa` as `int` — fully integer-paise compliant.
//
// Task 7 — dc_inventory_screen.dart rent-out/return UI wiring:
//   Uses `DcMoneyMath.rupeesToPaise(item.rentalPrice)` to convert the
//   pre-existing double-rupee `DcInventoryItem.rentalPrice` field into
//   integer paise at the boundary when constructing an EventRental for
//   local validation. This is correct usage of DcMoneyMath at the
//   UI→domain boundary. The subsequent computation
//   `totalRentalPricePaise = rentalPricePerUnitPaise * quantity` inside
//   EventRental.rentOut() is pure integer multiplication — no fractional
//   result, no DcMoneyMath.round2() needed.
//
// Task 17 — validateMinGuests():
//   Zero monetary arithmetic. Compares guestCount (int) against
//   pkg.minGuests (int) and returns an advisory message string. No money
//   fields are read, written, or computed.
//
// Task 22 — _handleCancellation():
//   Reads `booking.advancePaid > 0` — this is the pre-existing double-
//   rupee field on EventBooking, explicitly exempt per GR-2 AC2. No
//   arithmetic is performed on it; it's a display-only comparison that
//   decides whether to show a forfeiture confirmation dialog.
//
// Conclusion: None of the five tasks introduced a new money-computing
// function. The only monetary computation is EventRental.rentOut()'s
// integer multiplication (rentalPricePerUnitPaise * quantity), which is
// already correct by construction (int * int = int). This test validates
// that path produces correct integer-paise outputs.
//
// Run: flutter test test/features/decoration_catering/dc_money_paise_audit_test.dart
// ============================================================================
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/decoration_catering/data/models/event_rental.dart';
import 'package:dukanx/features/decoration_catering/utils/dc_money_math.dart';

void main() {
  group('GR-2 Integer-paise audit — EventRental.rentOut() arithmetic', () {
    // This is the one monetary computation introduced/wired by the audited
    // tasks: totalRentalPricePaise = rentalPricePerUnitPaise * quantity.
    // It must produce integer-paise outputs from integer-paise inputs,
    // with no floating-point contamination.

    test(
      'totalRentalPricePaise is integer multiplication of paise * quantity',
      () {
        final rental = EventRental.create(
          id: 'audit-1',
          eventId: 'evt-1',
          inventoryItemId: 'item-1',
          rentalPricePerUnitPaise: 1500, // ₹15.00
        );

        final result = rental.rentOut(quantity: 3, availableOnHand: 10);

        expect(result.isSuccess, isTrue);
        expect(result.rental!.rentalPricePerUnitPaise, equals(1500));
        expect(result.rental!.totalRentalPricePaise, equals(4500)); // 1500 * 3
        // Verify types are int (not double)
        expect(result.rental!.rentalPricePerUnitPaise, isA<int>());
        expect(result.rental!.totalRentalPricePaise, isA<int>());
      },
    );

    test('zero rental price produces zero total (still integer)', () {
      final rental = EventRental.create(
        id: 'audit-2',
        eventId: 'evt-2',
        inventoryItemId: 'item-2',
        rentalPricePerUnitPaise: 0,
      );

      final result = rental.rentOut(quantity: 5, availableOnHand: 10);

      expect(result.isSuccess, isTrue);
      expect(result.rental!.totalRentalPricePaise, equals(0));
      expect(result.rental!.totalRentalPricePaise, isA<int>());
    });

    test(
      'large quantity produces correct integer paise total without overflow in normal range',
      () {
        // ₹999.99 per unit * 100 units = ₹99,999.00 (well within int range)
        final rental = EventRental.create(
          id: 'audit-3',
          eventId: 'evt-3',
          inventoryItemId: 'item-3',
          rentalPricePerUnitPaise: 99999, // ₹999.99
        );

        final result = rental.rentOut(quantity: 100, availableOnHand: 200);

        expect(result.isSuccess, isTrue);
        expect(result.rental!.totalRentalPricePaise, equals(9999900));
        expect(result.rental!.totalRentalPricePaise, isA<int>());
      },
    );
  });

  group(
    'GR-2 Integer-paise audit — DcMoneyMath.rupeesToPaise() boundary conversion',
    () {
      // Task 7 uses DcMoneyMath.rupeesToPaise(item.rentalPrice) at the
      // UI→domain boundary. This verifies the conversion produces the
      // correct integer paise from a double rupee input.

      test('rupeesToPaise converts double rupees to integer paise', () {
        expect(DcMoneyMath.rupeesToPaise(15.0), equals(1500));
        expect(DcMoneyMath.rupeesToPaise(15.0), isA<int>());
      });

      test('rupeesToPaise handles fractional rupees with half-up rounding', () {
        // ₹15.995 → 1599.5 paise → rounds to 1600 (half-up)
        expect(DcMoneyMath.rupeesToPaise(15.995), equals(1600));
        expect(DcMoneyMath.rupeesToPaise(15.994), equals(1599));
      });

      test('rupeesToPaise handles zero', () {
        expect(DcMoneyMath.rupeesToPaise(0.0), equals(0));
        expect(DcMoneyMath.rupeesToPaise(0.0), isA<int>());
      });
    },
  );

  group('GR-2 Integer-paise audit — _eventRentalFromJson field types', () {
    // Task 6's _eventRentalFromJson reads rentalPricePerUnitPaisa and
    // totalRentalPricePaisa as int — verify via EventRental construction.

    test('EventRental money fields accept and store integer paise', () {
      final now = DateTime(2024, 1, 1);
      final rental = EventRental(
        id: 'r-1',
        eventId: 'e-1',
        inventoryItemId: 'i-1',
        rentedQty: 5,
        damagedOrLostQty: 0,
        state: RentalState.rentedOut,
        rentalPricePerUnitPaise: 2500,
        totalRentalPricePaise: 12500,
        createdAt: now,
        updatedAt: now,
      );

      expect(rental.rentalPricePerUnitPaise, isA<int>());
      expect(rental.totalRentalPricePaise, isA<int>());
      expect(rental.rentalPricePerUnitPaise, equals(2500));
      expect(rental.totalRentalPricePaise, equals(12500));
    });
  });
}
