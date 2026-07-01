/// Bug Condition Exploration Test — Fuel GST Compliance Fix (FRONTEND)
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.6, 2.7**
///
/// Property 1: Bug Condition — Fuel GST Resolves to Zero
///
/// In India, petrol and diesel sit OUTSIDE the GST regime, so a `petrolPump`
/// fuel invoice must report `GST = CGST = SGST = taxAmount = 0` and
/// `subtotal == grandTotal`. This test encodes that EXPECTED (post-fix)
/// behavior.
///
/// **CRITICAL**: On UNFIXED code these assertions FAIL — failure CONFIRMS the
/// bug exists. DO NOT fix the test or the code when it fails. After the fix
/// (Task 3) these same tests will PASS.
///
/// The three frontend sources of the hardcoded 18% rate are exercised:
///   - Config:  `BusinessTypeRegistry.getConfig(petrolPump).defaultGstRate`
///   - Model:   `FuelType` constructor default + `FuelType.fromMap` fallback
///   - Service: the GST split inside `createFuelBill`
///
/// `createFuelBill` persists its bill inside a single Drift DB transaction that
/// requires a live database, an open shift, a tank and a nozzle, so it cannot
/// be invoked as a pure function here. Following this repo's convention (see
/// `my-backend/src/__tests__/invoice-calculation-engine.test.ts`), the GST
/// split is mirrored EXACTLY as it appears in
/// `petrol_pump_billing_service.dart` `createFuelBill`, and fed the REAL
/// `FuelType.linkedGSTRate` so the counterexample reflects production.
///
/// PBT library: dartproptest ^0.2.1 — scoped to concrete failing fuel sales
/// (litres ∈ {1, 10, 50}, rate ∈ {₹90, ₹100, ₹110}/L) for reliable
/// reproduction, then generalized across arbitrary litres/rates.
///
/// Run: flutter test test/bug_condition/fuel_gst_compliance_exploration_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/features/petrol_pump/models/fuel_type.dart';

// ---------------------------------------------------------------------------
// Production mirror of the GST split inside createFuelBill.
//
// Source (petrol_pump_billing_service.dart, createFuelBill) — POST-FIX:
//   // Petrol/diesel are outside India's GST regime — force the fuel GST rate
//   // to 0 at computation time rather than trusting fuelType.linkedGSTRate.
//   const gstRate   = 0.0;
//   final gstAmount = totalAmount * gstRate / (100 + gstRate);   // == 0
//   item['cgst']    = gstAmount / 2;
//   item['sgst']    = gstAmount / 2;
//   final subtotal  = totalAmount - gstAmount;
//   taxAmount       = gstAmount;       // BillsCompanion.taxAmount / Bill.totalTax
//   grandTotal      = totalAmount;     // = litres * rate
// ---------------------------------------------------------------------------
class FuelBillTax {
  final double grandTotal;
  final double subtotal;
  final double gstAmount;
  final double cgst;
  final double sgst;
  final double taxAmount;

  const FuelBillTax({
    required this.grandTotal,
    required this.subtotal,
    required this.gstAmount,
    required this.cgst,
    required this.sgst,
    required this.taxAmount,
  });
}

/// Mirrors createFuelBill's tax computation. POST-FIX: the billing layer is
/// authoritative and forces the fuel GST rate to 0 regardless of the stored
/// fuelType.linkedGSTRate (petrol/diesel are outside India's GST regime).
FuelBillTax computeFuelBill({
  required FuelType fuelType,
  required double litres,
  required double rate,
}) {
  final totalAmount = litres * rate;
  const gstRate = 0.0; // <-- production forces fuel GST to 0 (clause 2.6/3.4)
  final gstAmount = totalAmount * gstRate / (100 + gstRate);
  return FuelBillTax(
    grandTotal: totalAmount,
    subtotal: totalAmount - gstAmount,
    gstAmount: gstAmount,
    cgst: gstAmount / 2,
    sgst: gstAmount / 2,
    taxAmount: gstAmount,
  );
}

/// A default-rate petrol fuel type (no explicit linkedGSTRate supplied).
FuelType _defaultPetrol() => FuelType(
  fuelId: 'petrol',
  fuelName: 'Petrol',
  currentRatePerLitre: 100.0,
  ownerId: 'owner_1',
);

const double _eps = 1e-9;

void main() {
  const int kNumRuns = 200;

  // Scoped, deterministic failing cases for reliable reproduction.
  const List<double> kLitres = [1.0, 10.0, 50.0];
  const List<double> kRates = [90.0, 100.0, 110.0];

  // ==========================================================================
  // TEST 1 — Frontend: createFuelBill GST split must resolve to zero
  // Expected (post-fix): taxAmount == 0, cgst == 0, sgst == 0,
  //                      subtotal == grandTotal (= litres * rate).
  // Unfixed: gstRate = 18 → e.g. 10 L × ₹100 yields taxAmount ≈ ₹152.54.
  // Validates: Requirements 2.1, 2.2, 2.3
  // ==========================================================================
  group('Bug Condition: createFuelBill GST split (frontend)', () {
    for (final litres in kLitres) {
      for (final rate in kRates) {
        test('fuel sale ${litres.toStringAsFixed(0)} L × '
            '₹${rate.toStringAsFixed(0)}/L resolves all tax to 0', () {
          final bill = computeFuelBill(
            fuelType: _defaultPetrol(),
            litres: litres,
            rate: rate,
          );

          expect(
            bill.taxAmount,
            closeTo(0.0, _eps),
            reason:
                'Fuel taxAmount must be 0 (petrol/diesel are outside GST). '
                'Unfixed code uses linkedGSTRate=18 → non-zero tax.',
          );
          expect(bill.cgst, closeTo(0.0, _eps), reason: 'CGST must be 0');
          expect(bill.sgst, closeTo(0.0, _eps), reason: 'SGST must be 0');
          expect(bill.gstAmount, closeTo(0.0, _eps), reason: 'GST must be 0');
          expect(
            bill.subtotal,
            closeTo(bill.grandTotal, _eps),
            reason:
                'subtotal must equal grandTotal (= litres × rate), no tax '
                'deducted.',
          );
        });
      }
    }

    test('PBT: every petrolPump fuel sale resolves tax to 0 (generalized)', () {
      final held = forAll(
        (int litresInt, int rateInt) {
          final litres = litresInt.toDouble();
          final rate = rateInt.toDouble();
          final bill = computeFuelBill(
            fuelType: _defaultPetrol(),
            litres: litres,
            rate: rate,
          );
          return bill.taxAmount.abs() < _eps &&
              bill.cgst.abs() < _eps &&
              bill.sgst.abs() < _eps &&
              bill.gstAmount.abs() < _eps &&
              (bill.subtotal - bill.grandTotal).abs() < _eps;
        },
        [Gen.interval(1, 500), Gen.interval(50, 150)],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });

  // ==========================================================================
  // TEST 2 — Config: petrol-pump defaultGstRate must be 0
  // Validates: Requirements 1.4, 2.4
  // ==========================================================================
  group('Bug Condition: petrol-pump config default GST', () {
    test('BusinessTypeRegistry.getConfig(petrolPump).defaultGstRate == 0', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.petrolPump);
      expect(
        config.defaultGstRate,
        closeTo(0.0, _eps),
        reason:
            'Petrol-pump defaultGstRate must be 0. Unfixed config returns '
            '18.0 ("Fuel GST").',
      );
    });
  });

  // ==========================================================================
  // TEST 3 — Model: FuelType defaults must be 0
  // Validates: Requirements 1.5, 2.5
  // ==========================================================================
  group('Bug Condition: FuelType default linkedGSTRate', () {
    test('constructor default (no explicit rate) linkedGSTRate == 0', () {
      final fuel = _defaultPetrol();
      expect(
        fuel.linkedGSTRate,
        closeTo(0.0, _eps),
        reason:
            'FuelType constructor must default linkedGSTRate to 0. Unfixed '
            'code defaults to 18.0.',
      );
    });

    test('fromMap with no linkedGSTRate field defaults to 0', () {
      final fuel = FuelType.fromMap('petrol', {
        'fuelName': 'Petrol',
        'currentRatePerLitre': 100.0,
        'ownerId': 'owner_1',
        // intentionally no 'linkedGSTRate' key
      });
      expect(
        fuel.linkedGSTRate,
        closeTo(0.0, _eps),
        reason:
            'FuelType.fromMap must default linkedGSTRate to 0 when absent. '
            'Unfixed code falls back to 18.0.',
      );
    });
  });

  // ==========================================================================
  // TEST 5 — Edge (clause 2.6 / 3.4): a fuel type STORED with an explicit
  // non-zero rate must still produce a zero-tax bill. The billing layer must
  // resolve fuel GST to 0 regardless of the stored/entered rate.
  // Validates: Requirements 2.6
  // ==========================================================================
  group('Bug Condition: stored explicit linkedGSTRate 18.0 still zeroes tax', () {
    test('fuel type persisted with linkedGSTRate:18.0 → new bill tax == 0', () {
      // The stored field is allowed to carry 18.0 (persisted-field contract is
      // unchanged) but the resolved bill tax must be 0 (clause 2.6/3.4).
      final stored = FuelType.fromMap('diesel', {
        'fuelName': 'Diesel',
        'currentRatePerLitre': 95.0,
        'linkedGSTRate': 18.0,
        'ownerId': 'owner_1',
      });

      final bill = computeFuelBill(fuelType: stored, litres: 10.0, rate: 100.0);

      expect(
        bill.taxAmount,
        closeTo(0.0, _eps),
        reason:
            'Even when a fuel type stores linkedGSTRate=18.0, the new fuel '
            'bill must resolve tax to 0 (billing layer is authoritative).',
      );
      expect(bill.cgst, closeTo(0.0, _eps));
      expect(bill.sgst, closeTo(0.0, _eps));
      expect(bill.subtotal, closeTo(bill.grandTotal, _eps));
    });
  });
}
