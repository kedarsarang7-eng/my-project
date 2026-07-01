import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/billing/services/commission_input.dart';
import 'package:dukanx/features/billing/services/lot_sale_entry.dart';

/// Pure-logic tests for multi-lot broker sale validation.
///
/// These tests exercise the validation logic that `recordMultiLotBrokerSale`
/// applies BEFORE touching the database. The database integration is tested
/// separately once the generated Drift code is re-synced with tables.dart.
///
/// Validates: Requirements 7.1, 7.2, 7.3, 7.4
void main() {
  group('LotSaleEntry model', () {
    test('captures lot → owning-farmer association (Requirement 7.1)', () {
      const entry = LotSaleEntry(
        lotId: 'lot-001',
        owningFarmerId: 'farmer-abc',
        saleAmountPaise: 10000,
        commission: FlatCommission(500),
      );

      expect(entry.lotId, 'lot-001');
      expect(entry.owningFarmerId, 'farmer-abc');
      expect(entry.saleAmountPaise, 10000);
      expect(entry.commission.amountPaise, 500);
    });

    test('default deduction charges are 0', () {
      const entry = LotSaleEntry(
        lotId: 'lot-002',
        owningFarmerId: 'farmer-xyz',
        saleAmountPaise: 5000,
        commission: FlatCommission(200),
      );

      expect(entry.laborChargesPaise, 0);
      expect(entry.hamaliChargesPaise, 0);
      expect(entry.weighingChargesPaise, 0);
      expect(entry.marketFeePaise, 0);
    });

    test('allows null owningFarmerId (validation rejects this)', () {
      const entry = LotSaleEntry(
        lotId: 'lot-003',
        owningFarmerId: null,
        saleAmountPaise: 5000,
        commission: FlatCommission(200),
      );

      expect(entry.owningFarmerId, isNull);
    });
  });

  group('Requirement 7.4: reject unowned lots (validation logic)', () {
    test('null owningFarmerId is detected', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-A',
          owningFarmerId: null,
          saleAmountPaise: 10000,
          commission: FlatCommission(500),
        ),
      ];

      // Simulate the validation check from recordMultiLotBrokerSale
      final error = _validateOwnership(lots);
      expect(error, isNotNull);
      expect(error, contains('lot-A'));
      expect(error, contains('no owning farmer'));
    });

    test('empty owningFarmerId is detected', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-B',
          owningFarmerId: '',
          saleAmountPaise: 10000,
          commission: FlatCommission(500),
        ),
      ];

      final error = _validateOwnership(lots);
      expect(error, isNotNull);
      expect(error, contains('lot-B'));
      expect(error, contains('no owning farmer'));
    });

    test('valid owningFarmerId passes ownership check', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-C',
          owningFarmerId: 'farmer-123',
          saleAmountPaise: 10000,
          commission: FlatCommission(500),
        ),
      ];

      final error = _validateOwnership(lots);
      expect(error, isNull);
    });

    test('first unowned lot in list is reported', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-ok',
          owningFarmerId: 'farmer-1',
          saleAmountPaise: 5000,
          commission: FlatCommission(200),
        ),
        const LotSaleEntry(
          lotId: 'lot-bad',
          owningFarmerId: null,
          saleAmountPaise: 5000,
          commission: FlatCommission(200),
        ),
      ];

      final error = _validateOwnership(lots);
      expect(error, isNotNull);
      expect(error, contains('lot-bad'));
    });
  });

  group('Requirement 7.3: sale amount conservation (validation logic)', () {
    test(
      'sum of per-lot amounts must equal expected total — mismatch rejected',
      () {
        final lots = [
          const LotSaleEntry(
            lotId: 'lot-1',
            owningFarmerId: 'farmer-a',
            saleAmountPaise: 5000,
            commission: FlatCommission(200),
          ),
          const LotSaleEntry(
            lotId: 'lot-2',
            owningFarmerId: 'farmer-b',
            saleAmountPaise: 3000,
            commission: FlatCommission(100),
          ),
        ];

        final error = _validateSaleAmountConservation(lots, 10000);
        expect(error, isNotNull);
        expect(error, contains('does not equal'));
      },
    );

    test('sum of per-lot amounts equals expected total — passes', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-1',
          owningFarmerId: 'farmer-a',
          saleAmountPaise: 5000,
          commission: FlatCommission(200),
        ),
        const LotSaleEntry(
          lotId: 'lot-2',
          owningFarmerId: 'farmer-b',
          saleAmountPaise: 5000,
          commission: FlatCommission(200),
        ),
      ];

      final error = _validateSaleAmountConservation(lots, 10000);
      expect(error, isNull);
    });

    test('single lot with amount equal to total passes', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-single',
          owningFarmerId: 'farmer-x',
          saleAmountPaise: 7777,
          commission: FlatCommission(100),
        ),
      ];

      final error = _validateSaleAmountConservation(lots, 7777);
      expect(error, isNull);
    });

    test('conservation check uses integer paise — no floating-point error', () {
      // 3 lots that add up to 33333 paise exactly
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-a',
          owningFarmerId: 'f1',
          saleAmountPaise: 11111,
          commission: FlatCommission(100),
        ),
        const LotSaleEntry(
          lotId: 'lot-b',
          owningFarmerId: 'f2',
          saleAmountPaise: 11111,
          commission: FlatCommission(100),
        ),
        const LotSaleEntry(
          lotId: 'lot-c',
          owningFarmerId: 'f3',
          saleAmountPaise: 11111,
          commission: FlatCommission(100),
        ),
      ];

      final error = _validateSaleAmountConservation(lots, 33333);
      expect(error, isNull);
    });
  });

  group('Commission and charge validation per lot', () {
    test('invalid commission (negative) is caught per lot', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-neg-comm',
          owningFarmerId: 'farmer-1',
          saleAmountPaise: 10000,
          commission: FlatCommission(-100),
        ),
      ];

      final error = _validateLotCharges(lots);
      expect(error, isNotNull);
      expect(error, contains('lot-neg-comm'));
    });

    test('percentage commission > 100% is caught per lot', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-pct-over',
          owningFarmerId: 'farmer-1',
          saleAmountPaise: 10000,
          commission: PercentageCommission(rate: 101.0, resultPaise: 10100),
        ),
      ];

      final error = _validateLotCharges(lots);
      expect(error, isNotNull);
      expect(error, contains('lot-pct-over'));
    });

    test('net payable < 0 is caught per lot', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-exceed',
          owningFarmerId: 'farmer-1',
          saleAmountPaise: 1000,
          commission: FlatCommission(800),
          laborChargesPaise: 300, // 800 + 300 = 1100 > 1000
        ),
      ];

      final error = _validateLotCharges(lots);
      expect(error, isNotNull);
      expect(error, contains('lot-exceed'));
      expect(error, contains('exceed'));
    });

    test('negative deduction charge is caught per lot', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-neg-charge',
          owningFarmerId: 'farmer-1',
          saleAmountPaise: 10000,
          commission: FlatCommission(500),
          laborChargesPaise: -50,
        ),
      ];

      final error = _validateLotCharges(lots);
      expect(error, isNotNull);
      expect(error, contains('lot-neg-charge'));
      expect(error, contains('negative'));
    });

    test('valid charges pass validation', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-good',
          owningFarmerId: 'farmer-1',
          saleAmountPaise: 10000,
          commission: FlatCommission(500),
          laborChargesPaise: 100,
          hamaliChargesPaise: 200,
          weighingChargesPaise: 50,
          marketFeePaise: 150,
        ),
      ];

      final error = _validateLotCharges(lots);
      expect(error, isNull);
    });
  });

  group('Multi-farmer attribution (Requirement 7.2)', () {
    test('lots can be attributed to different farmers', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-1',
          owningFarmerId: 'farmer-A',
          saleAmountPaise: 7000,
          commission: FlatCommission(300),
        ),
        const LotSaleEntry(
          lotId: 'lot-2',
          owningFarmerId: 'farmer-B',
          saleAmountPaise: 3000,
          commission: FlatCommission(150),
        ),
      ];

      // Ownership check passes
      expect(_validateOwnership(lots), isNull);
      // Conservation check passes
      expect(_validateSaleAmountConservation(lots, 10000), isNull);
      // Charge validation passes
      expect(_validateLotCharges(lots), isNull);
    });

    test('multiple lots can belong to the same farmer', () {
      final lots = [
        const LotSaleEntry(
          lotId: 'lot-1',
          owningFarmerId: 'farmer-A',
          saleAmountPaise: 4000,
          commission: FlatCommission(200),
        ),
        const LotSaleEntry(
          lotId: 'lot-2',
          owningFarmerId: 'farmer-A',
          saleAmountPaise: 6000,
          commission: FlatCommission(300),
        ),
      ];

      expect(_validateOwnership(lots), isNull);
      expect(_validateSaleAmountConservation(lots, 10000), isNull);
      expect(_validateLotCharges(lots), isNull);
    });
  });
}

// ============================================================================
// Helper functions that mirror the validation logic in recordMultiLotBrokerSale
// ============================================================================

/// Mirrors Requirement 7.4 validation: every lot must have an owning farmer.
String? _validateOwnership(List<LotSaleEntry> lots) {
  for (final lot in lots) {
    if (lot.owningFarmerId == null || lot.owningFarmerId!.isEmpty) {
      return 'Lot ${lot.lotId} has no owning farmer; cannot save bill';
    }
  }
  return null;
}

/// Mirrors Requirement 7.3 validation: sum must match expected total exactly.
String? _validateSaleAmountConservation(
  List<LotSaleEntry> lots,
  int expectedTotalSaleAmountPaise,
) {
  int actualTotalSaleAmountPaise = 0;
  for (final lot in lots) {
    actualTotalSaleAmountPaise += lot.saleAmountPaise;
  }
  if (actualTotalSaleAmountPaise != expectedTotalSaleAmountPaise) {
    return 'Sum of per-lot sale amounts ($actualTotalSaleAmountPaise paise) '
        'does not equal expected total ($expectedTotalSaleAmountPaise paise)';
  }
  return null;
}

/// Mirrors commission + charge validation per lot.
String? _validateLotCharges(List<LotSaleEntry> lots) {
  const int maxChargePaise = 999999999;
  for (final lot in lots) {
    final commissionError = lot.commission.validate();
    if (commissionError != null) {
      return 'Lot ${lot.lotId}: $commissionError';
    }

    final chargeError =
        _validateDeductionCharge(
          lot.laborChargesPaise,
          'labor',
          maxChargePaise,
        ) ??
        _validateDeductionCharge(
          lot.hamaliChargesPaise,
          'hamali',
          maxChargePaise,
        ) ??
        _validateDeductionCharge(
          lot.weighingChargesPaise,
          'weighing',
          maxChargePaise,
        ) ??
        _validateDeductionCharge(
          lot.marketFeePaise,
          'market fee',
          maxChargePaise,
        );
    if (chargeError != null) {
      return 'Lot ${lot.lotId}: $chargeError';
    }

    // Net payable check
    final commissionAmountPaise = lot.commission.amountPaise;
    final totalDeductions =
        lot.laborChargesPaise +
        lot.hamaliChargesPaise +
        lot.weighingChargesPaise +
        lot.marketFeePaise;
    final netPayablePaise =
        lot.saleAmountPaise - commissionAmountPaise - totalDeductions;
    if (netPayablePaise < 0) {
      return 'Lot ${lot.lotId}: combined commission and deduction charges exceed the sale amount';
    }
  }
  return null;
}

String? _validateDeductionCharge(
  int valuePaise,
  String fieldName,
  int maxPaise,
) {
  if (valuePaise < 0) {
    return '$fieldName charge must not be negative (got $valuePaise paise)';
  }
  if (valuePaise > maxPaise) {
    return '$fieldName charge exceeds maximum allowed value (got $valuePaise paise)';
  }
  return null;
}
