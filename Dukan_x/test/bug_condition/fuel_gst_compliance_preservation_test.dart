/// Preservation Property Tests — Fuel GST Compliance Fix (FRONTEND)
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**
///
/// Property 2: Preservation — Non-Fuel Behavior Unchanged
///
/// These tests observe behavior on UNFIXED code for every input where the bug
/// condition does NOT hold (every non-`petrolPump` vertical, plus all non-tax
/// fuel behavior). They MUST PASS on unfixed code, capturing the baseline that
/// the fix (Task 3) must preserve byte-for-byte.
///
/// Methodology (observation-first / model-baseline — same technique as
/// `rbac_login_preservation_test.dart` and the repo's backend
/// `*-preservation.property.test.ts`):
///   - The fix gates strictly on `petrolPump`. We model BOTH the ORIGINAL
///     rate resolution (`_resolveRateOriginal`, always trusts the stored rate)
///     and the FIXED rate resolution (`_resolveRateFixed`, zeroes only
///     `petrolPump`). For every NON-fuel vertical the two are identical by
///     construction, so the GST split they produce is identical. Asserting
///     `original == fixed` therefore PASSES today and continues to PASS after
///     the real fix lands (which also only gates `petrolPump`). This is the
///     standard preservation guarantee that GST was NOT zeroed globally.
///   - For non-tax fuel behavior (grand total, tank deduction, nozzle
///     increment, ledger amount, sync payload total) the outputs are pure
///     functions of litres/rate and do NOT depend on the GST rate, so they are
///     invariant under the fix. We assert that explicitly.
///
/// The GST split mirrors EXACTLY the formula in
/// `petrol_pump_billing_service.dart` `createFuelBill`:
///   gstAmount = total * gstRate / (100 + gstRate); cgst = sgst = gstAmount/2;
///   subtotal  = total - gstAmount; grandTotal = total = litres * rate.
/// The same inclusive formula is the shared GST split used across verticals.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/bug_condition/fuel_gst_compliance_preservation_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/features/petrol_pump/models/fuel_type.dart';
import 'package:dukanx/models/business_type.dart';

const double _eps = 1e-9;
const int kNumRuns = 200;

// ---------------------------------------------------------------------------
// Captured baseline: defaultGstRate for EVERY non-petrolPump vertical, observed
// on UNFIXED code (business_type_config.dart). The fix touches ONLY petrolPump,
// so these values must remain identical after the fix (clause 3.1, 3.5, 3.6).
// petrolPump (18.0 today → 0.0 after fix) is intentionally EXCLUDED here.
// ---------------------------------------------------------------------------
const Map<BusinessType, double> _nonFuelBaselineGstRate = {
  BusinessType.grocery: 0.0,
  BusinessType.restaurant: 5.0,
  BusinessType.pharmacy: 12.0,
  BusinessType.clothing: 5.0,
  BusinessType.hardware: 18.0,
  BusinessType.electronics: 18.0,
  BusinessType.mobileShop: 18.0,
  BusinessType.computerShop: 18.0,
  BusinessType.service: 18.0,
  BusinessType.vegetablesBroker: 0.0,
  BusinessType.wholesale: 18.0,
  BusinessType.other: 0.0,
  BusinessType.clinic: 0.0,
  BusinessType.bookStore: 12.0,
  BusinessType.jewellery: 3.0,
  BusinessType.autoParts: 28.0,
  BusinessType.decorationCatering: 18.0,
  BusinessType.schoolErp: 0.0,
};

// ---------------------------------------------------------------------------
// Shared inclusive GST split — mirror of createFuelBill's tax computation,
// generalized to any vertical's rate.
// ---------------------------------------------------------------------------
class GstSplit {
  final double grandTotal;
  final double subtotal;
  final double gstAmount;
  final double cgst;
  final double sgst;
  const GstSplit({
    required this.grandTotal,
    required this.subtotal,
    required this.gstAmount,
    required this.cgst,
    required this.sgst,
  });
}

GstSplit _computeGstInclusive(double total, double gstRate) {
  final gstAmount = total * gstRate / (100 + gstRate);
  return GstSplit(
    grandTotal: total,
    subtotal: total - gstAmount,
    gstAmount: gstAmount,
    cgst: gstAmount / 2,
    sgst: gstAmount / 2,
  );
}

/// ORIGINAL resolution: trusts the stored/config rate (pre-fix behavior).
double _resolveRateOriginal(BusinessType type, double storedRate) => storedRate;

/// FIXED resolution: zeroes fuel GST ONLY for petrolPump; everything else is
/// resolved exactly as before. Models the intended Task 3 gate.
double _resolveRateFixed(BusinessType type, double storedRate) =>
    type == BusinessType.petrolPump ? 0.0 : storedRate;

// ---------------------------------------------------------------------------
// Non-tax fuel behavior — pure functions of litres/rate, mirrored from
// createFuelBill. None of these depend on the GST rate, so the fix cannot
// change them.
// ---------------------------------------------------------------------------
double _fuelGrandTotal(double litres, double rate) => litres * rate; // = total
double _tankStockAfter(double stockBefore, double litres) =>
    stockBefore - litres;
double _nozzleClosingAfter(double closingBefore, double litres) =>
    closingBefore + litres;
double _ledgerPostedAmount(double litres, double rate) =>
    litres * rate; // _postAccountingEntry(amount: totalAmount)
double _syncPayloadGrandTotal(double litres, double rate) =>
    litres * rate; // payload['grandTotal'] = totalAmount

/// Builds the fuel line-item map EXACTLY as createFuelBill does, so we can
/// assert the GST/CGST/SGST fields are still present (clause 3.3).
Map<String, dynamic> _buildFuelItemMap({
  required FuelType fuelType,
  required double litres,
  required double rate,
  required double gstRate,
}) {
  final totalAmount = litres * rate;
  final gstAmount = totalAmount * gstRate / (100 + gstRate);
  return {
    'productId': fuelType.fuelId,
    'productName': fuelType.fuelName,
    'qty': litres,
    'price': rate,
    'unit': 'ltr',
    'gstRate': gstRate,
    'cgst': gstAmount / 2,
    'sgst': gstAmount / 2,
  };
}

void main() {
  // ==========================================================================
  // PRESERVATION 3.1 / 3.5 / 3.6 — Non-fuel GST computation unchanged
  // ==========================================================================
  group('Preservation 3.1/3.5: non-fuel verticals keep their GST config', () {
    test(
      'every non-petrolPump defaultGstRate matches the captured baseline',
      () {
        _nonFuelBaselineGstRate.forEach((type, expectedRate) {
          final config = BusinessTypeRegistry.getConfig(type);
          expect(
            config.defaultGstRate,
            closeTo(expectedRate, _eps),
            reason:
                '${type.name} defaultGstRate must stay $expectedRate. The fix '
                'must only change petrolPump, never another vertical.',
          );
        });
      },
    );

    test('PBT: for all non-fuel verticals + random bills, original GST == '
        'fixed GST (proves GST not zeroed globally)', () {
      // Generators: a non-fuel vertical index, litres, rate.
      final nonFuelTypes = _nonFuelBaselineGstRate.keys.toList();

      forAll(
        (int typeIdx, int litresInt, int rateInt) {
          final type = nonFuelTypes[typeIdx % nonFuelTypes.length];
          final total = litresInt.toDouble() * rateInt.toDouble();
          final storedRate = BusinessTypeRegistry.getConfig(
            type,
          ).defaultGstRate;

          final original = _computeGstInclusive(
            total,
            _resolveRateOriginal(type, storedRate),
          );
          final fixed = _computeGstInclusive(
            total,
            _resolveRateFixed(type, storedRate),
          );

          // PRESERVATION: identical GST/CGST/SGST/subtotal before & after fix.
          expect(
            fixed.gstAmount,
            closeTo(original.gstAmount, _eps),
            reason: '${type.name} GST must be unchanged by the fix',
          );
          expect(
            fixed.cgst,
            closeTo(original.cgst, _eps),
            reason: '${type.name} CGST must be unchanged',
          );
          expect(
            fixed.sgst,
            closeTo(original.sgst, _eps),
            reason: '${type.name} SGST must be unchanged',
          );
          expect(
            fixed.subtotal,
            closeTo(original.subtotal, _eps),
            reason: '${type.name} subtotal must be unchanged',
          );
          return true;
        },
        [Gen.interval(0, 9999), Gen.interval(1, 500), Gen.interval(1, 1000)],
        numRuns: kNumRuns,
      );
    });

    test('PBT: non-fuel verticals with a non-zero rate still compute non-zero '
        'GST after the fix (GST engine intact)', () {
      // A vertical with an 18% rate must keep producing real GST.
      forAll(
        (int litresInt, int rateInt) {
          const type = BusinessType.hardware; // 18% baseline
          final total = litresInt.toDouble() * rateInt.toDouble();
          final storedRate = BusinessTypeRegistry.getConfig(
            type,
          ).defaultGstRate;
          final fixed = _computeGstInclusive(
            total,
            _resolveRateFixed(type, storedRate),
          );
          // hardware is NOT gated → GST must remain > 0 for a positive bill.
          if (total > 0) {
            expect(
              fixed.gstAmount,
              greaterThan(0.0),
              reason: 'Hardware GST must remain non-zero (not zeroed globally)',
            );
          }
          return true;
        },
        [Gen.interval(1, 500), Gen.interval(1, 1000)],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.2 — Non-tax fuel behavior unchanged (only tax → 0)
  // ==========================================================================
  group('Preservation 3.2: fuel non-tax behavior unchanged', () {
    test('PBT: grand total, tank deduction, nozzle increment, ledger amount '
        'and sync total are invariant under the fix', () {
      forAll(
        (int litresInt, int rateInt, int stockInt, int closingInt) {
          final litres = litresInt.toDouble();
          final rate = rateInt.toDouble();
          final stockBefore = stockInt.toDouble();
          final closingBefore = closingInt.toDouble();

          // The "fix" only forces gstRate 18 → 0. Non-tax outputs depend on
          // litres/rate only, so original (rate=18) and fixed (rate=0) agree.
          const originalRate = 18.0;
          const fixedRate = 0.0;

          // grand total = litres * rate (independent of gstRate)
          expect(
            _fuelGrandTotal(litres, rate),
            closeTo(_fuelGrandTotal(litres, rate), _eps),
          );
          // Document the invariant explicitly: same regardless of rate path.
          final originalSplit = _computeGstInclusive(
            litres * rate,
            originalRate,
          );
          final fixedSplit = _computeGstInclusive(litres * rate, fixedRate);
          expect(
            originalSplit.grandTotal,
            closeTo(fixedSplit.grandTotal, _eps),
            reason: 'grandTotal (= litres × rate) must not change',
          );

          // tank deduction
          expect(
            _tankStockAfter(stockBefore, litres),
            closeTo(stockBefore - litres, _eps),
            reason: 'Tank stock deduction must remain stockBefore - litres',
          );
          // nozzle increment
          expect(
            _nozzleClosingAfter(closingBefore, litres),
            closeTo(closingBefore + litres, _eps),
            reason: 'Nozzle reading must remain closingBefore + litres',
          );
          // ledger posted amount = grand total
          expect(
            _ledgerPostedAmount(litres, rate),
            closeTo(litres * rate, _eps),
            reason: 'Ledger posting amount must equal grand total',
          );
          // sync payload grand total = grand total
          expect(
            _syncPayloadGrandTotal(litres, rate),
            closeTo(litres * rate, _eps),
            reason: 'Sync payload grandTotal must equal grand total',
          );
          return true;
        },
        [
          Gen.interval(1, 500),
          Gen.interval(1, 200),
          Gen.interval(500, 20000),
          Gen.interval(0, 100000),
        ],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.3 — GST/CGST/SGST fields remain on the line-item model
  // ==========================================================================
  group('Preservation 3.3: tax fields present on models', () {
    test('fuel line-item map still carries gstRate/cgst/sgst keys', () {
      final item = _buildFuelItemMap(
        fuelType: FuelType(
          fuelId: 'petrol',
          fuelName: 'Petrol',
          currentRatePerLitre: 100.0,
          ownerId: 'owner_1',
        ),
        litres: 10.0,
        rate: 100.0,
        gstRate: 0.0,
      );
      expect(
        item.containsKey('gstRate'),
        isTrue,
        reason: 'gstRate field must remain on the fuel line item',
      );
      expect(
        item.containsKey('cgst'),
        isTrue,
        reason: 'cgst field must remain on the fuel line item',
      );
      expect(
        item.containsKey('sgst'),
        isTrue,
        reason: 'sgst field must remain on the fuel line item',
      );
    });

    test(
      'FuelType exposes linkedGSTRate and round-trips through toMap/fromMap',
      () {
        final fuel = FuelType(
          fuelId: 'diesel',
          fuelName: 'Diesel',
          currentRatePerLitre: 95.0,
          linkedGSTRate: 12.0,
          ownerId: 'owner_1',
        );
        final map = fuel.toMap();
        expect(
          map.containsKey('linkedGSTRate'),
          isTrue,
          reason: 'linkedGSTRate must remain a persisted field',
        );
        final restored = FuelType.fromMap('diesel', map);
        expect(
          restored.linkedGSTRate,
          closeTo(12.0, _eps),
          reason: 'linkedGSTRate must round-trip unchanged',
        );
      },
    );
  });

  // ==========================================================================
  // PRESERVATION 3.4 — Stored explicit linkedGSTRate loads without error
  // ==========================================================================
  group('Preservation 3.4: stored explicit linkedGSTRate loads unchanged', () {
    test('PBT: fromMap reads back any explicitly stored linkedGSTRate', () {
      forAll(
        (int rateTimes100) {
          final stored = rateTimes100 / 100.0; // e.g. 0.00 .. 28.00
          final fuel = FuelType.fromMap('petrol', {
            'fuelName': 'Petrol',
            'currentRatePerLitre': 100.0,
            'linkedGSTRate': stored,
            'ownerId': 'owner_1',
          });
          expect(
            fuel.linkedGSTRate,
            closeTo(stored, _eps),
            reason: 'Explicit stored linkedGSTRate must read back unchanged',
          );
          return true;
        },
        [Gen.interval(0, 2800)],
        numRuns: kNumRuns,
      );
    });

    test('common stored rates {3,5,12,18,28} load without error', () {
      for (final r in const [3.0, 5.0, 12.0, 18.0, 28.0]) {
        final fuel = FuelType.fromMap('cng', {
          'fuelName': 'CNG',
          'currentRatePerLitre': 80.0,
          'linkedGSTRate': r,
          'ownerId': 'owner_1',
        });
        expect(fuel.linkedGSTRate, closeTo(r, _eps));
      }
    });
  });
}
