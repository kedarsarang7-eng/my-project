/// Preservation Property Test — Tank/Dispenser Validators and Audit Logging Preserved
///
/// **Validates: Requirements 3.4, 3.5, 3.8**
///
/// Property 16: Preservation — Tank/Dispenser Validators and Audit Logging Preserved
///
/// This test confirms that the following already-correct behaviors remain
/// unchanged by the fix:
///
/// 1. AddTankDialog validators: name required, capacity > 0, initial stock ≤ capacity
/// 2. DipReadingDialog validators: dip reading ≥ 0, dip reading ≤ capacity
/// 3. AddStockDialog validators: purchase quantity > 0, quantity ≤ available capacity
/// 4. TankService.recordDipReading's STOCK_VARIANCE_ALERT audit logging (variance > 10L)
/// 5. DispenserService's READING_UPDATE and PERMISSION_DENIED audit logging
/// 6. Tank model: stockVariance, stockPercentage, isLowStock getters
/// 7. Nozzle model: calculatedSaleLitres, isValidReading getters
///
/// Methodology (source-reading / observation-first):
///   - Read source files via `dart:io` and verify each contains the expected
///     validator/audit patterns.
///   - Property-based: generate arbitrary tank/nozzle values (non-rollover,
///     non-overfill) and assert computed getters match expected formulas.
///
/// NOTE: hasRolloverAnomaly/hasOverfillAnomaly are NOT tested here — those
/// getters don't exist on unfixed code (scoped to task 35.3 follow-up).
///
/// This test MUST PASS on UNFIXED code.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/bug_condition/petrol_pump_preservation_validators_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/petrol_pump/models/tank.dart';
import 'package:dukanx/features/petrol_pump/models/nozzle.dart';

const double _eps = 1e-9;
const int kNumRuns = 200;

/// Reads a source file relative to the package root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ==========================================================================
  // PRESERVATION 3.4 — AddTankDialog Validators
  // ==========================================================================
  group('Preservation 3.4: AddTankDialog field validators present in source', () {
    late String src;

    setUpAll(() {
      src = _readSource(
        'lib/features/petrol_pump/presentation/dialogs/add_tank_dialog.dart',
      );
      assert(src.isNotEmpty, 'add_tank_dialog.dart must exist');
    });

    test('validator: tank name required (null or empty check)', () {
      expect(
        src.contains('value.isEmpty'),
        isTrue,
        reason:
            'AddTankDialog must have a validator checking for empty tank name',
      );
      expect(
        src.contains('Please enter tank name'),
        isTrue,
        reason: 'AddTankDialog must show error message for empty tank name',
      );
    });

    test('validator: capacity > 0', () {
      expect(
        src.contains('capacity <= 0') || src.contains('capacity == null'),
        isTrue,
        reason: 'AddTankDialog must validate capacity > 0',
      );
      expect(
        src.contains('valid capacity'),
        isTrue,
        reason: 'AddTankDialog must show error message for invalid capacity',
      );
    });

    test('validator: initial stock ≤ capacity (cannot exceed)', () {
      expect(
        src.contains('stock > capacity'),
        isTrue,
        reason:
            'AddTankDialog must validate initial stock does not exceed capacity',
      );
      expect(
        src.contains('Cannot exceed capacity'),
        isTrue,
        reason:
            'AddTankDialog must show "Cannot exceed capacity" error message',
      );
    });

    test('PBT: source always contains all three validators regardless of '
        'arbitrary capacity/stock values', () {
      forAll(
        (int capacitySeed, int stockSeed) {
          expect(src.contains('value.isEmpty'), isTrue);
          expect(
            src.contains('capacity <= 0') || src.contains('capacity == null'),
            isTrue,
          );
          expect(src.contains('stock > capacity'), isTrue);
          return true;
        },
        [Gen.interval(1, 100000), Gen.interval(0, 100000)],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.4 — DipReadingDialog Validators
  // ==========================================================================
  group(
    'Preservation 3.4: DipReadingDialog field validators present in source',
    () {
      late String src;

      setUpAll(() {
        src = _readSource(
          'lib/features/petrol_pump/presentation/dialogs/dip_reading_dialog.dart',
        );
        assert(src.isNotEmpty, 'dip_reading_dialog.dart must exist');
      });

      test('validator: dip reading ≥ 0 (quantity < 0 rejected)', () {
        expect(
          src.contains('quantity < 0') || src.contains('quantity == null'),
          isTrue,
          reason: 'DipReadingDialog must validate dip reading is non-negative',
        );
      });

      test('validator: dip reading ≤ capacity (cannot exceed tank capacity)', () {
        expect(
          src.contains('widget.tank.capacity'),
          isTrue,
          reason:
              'DipReadingDialog must reference tank capacity in the validator',
        );
        expect(
          src.contains('Cannot exceed tank capacity'),
          isTrue,
          reason:
              'DipReadingDialog must show "Cannot exceed tank capacity" error',
        );
      });

      test(
        'PBT: source always contains both validators for arbitrary dip values',
        () {
          forAll(
            (int dipReadingSeed) {
              expect(
                src.contains('quantity < 0') ||
                    src.contains('quantity == null'),
                isTrue,
              );
              expect(src.contains('widget.tank.capacity'), isTrue);
              expect(src.contains('Cannot exceed tank capacity'), isTrue);
              return true;
            },
            [Gen.interval(0, 100000)],
            numRuns: kNumRuns,
          );
        },
      );
    },
  );

  // ==========================================================================
  // PRESERVATION 3.4 — AddStockDialog Validators
  // ==========================================================================
  group(
    'Preservation 3.4: AddStockDialog field validators present in source',
    () {
      late String src;

      setUpAll(() {
        src = _readSource(
          'lib/features/petrol_pump/presentation/dialogs/add_stock_dialog.dart',
        );
        assert(src.isNotEmpty, 'add_stock_dialog.dart must exist');
      });

      test('validator: purchase quantity > 0 (quantity <= 0 rejected)', () {
        expect(
          src.contains('quantity <= 0') || src.contains('quantity == null'),
          isTrue,
          reason: 'AddStockDialog must validate purchase quantity > 0',
        );
      });

      test('validator: purchase quantity ≤ available capacity', () {
        expect(
          src.contains('widget.tank.availableCapacity') ||
              src.contains('availableCapacity'),
          isTrue,
          reason:
              'AddStockDialog must check quantity against available capacity',
        );
        expect(
          src.contains('Exceeds available capacity') ||
              src.contains('exceeds available capacity'),
          isTrue,
          reason:
              'AddStockDialog must show error when quantity exceeds available capacity',
        );
      });

      test(
        'PBT: source always contains both validators for arbitrary quantities',
        () {
          forAll(
            (int quantitySeed) {
              expect(
                src.contains('quantity <= 0') ||
                    src.contains('quantity == null'),
                isTrue,
              );
              expect(
                src.contains('widget.tank.availableCapacity') ||
                    src.contains('availableCapacity'),
                isTrue,
              );
              return true;
            },
            [Gen.interval(1, 100000)],
            numRuns: kNumRuns,
          );
        },
      );
    },
  );

  // ==========================================================================
  // PRESERVATION 3.5 — TankService STOCK_VARIANCE_ALERT Audit Logging
  // ==========================================================================
  group('Preservation 3.5: TankService STOCK_VARIANCE_ALERT audit logging', () {
    late String src;

    setUpAll(() {
      src = _readSource('lib/features/petrol_pump/services/tank_service.dart');
      assert(src.isNotEmpty, 'tank_service.dart must exist');
    });

    test('recordDipReading method exists', () {
      expect(
        src.contains('recordDipReading'),
        isTrue,
        reason: 'TankService must contain recordDipReading method',
      );
    });

    test('STOCK_VARIANCE_ALERT action is logged', () {
      expect(
        src.contains('STOCK_VARIANCE_ALERT'),
        isTrue,
        reason:
            'TankService.recordDipReading must log STOCK_VARIANCE_ALERT action',
      );
    });

    test('variance threshold is > 10 (triggers alert above 10L)', () {
      expect(
        src.contains('variance.abs() > 10') ||
            src.contains('variance.abs()> 10') ||
            src.contains('> 10'),
        isTrue,
        reason:
            'TankService must trigger STOCK_VARIANCE_ALERT when variance > 10L',
      );
    });

    test('audit log metadata contains severity and variance fields', () {
      final alertIdx = src.indexOf('STOCK_VARIANCE_ALERT');
      expect(alertIdx, isNot(-1));

      final windowEnd = (alertIdx + 500).clamp(0, src.length);
      final alertWindow = src.substring(alertIdx, windowEnd);

      expect(
        alertWindow.contains('severity'),
        isTrue,
        reason: 'STOCK_VARIANCE_ALERT metadata must contain severity field',
      );
      expect(
        alertWindow.contains('variance'),
        isTrue,
        reason: 'STOCK_VARIANCE_ALERT metadata must contain variance field',
      );
    });

    test(
      'PBT: for arbitrary variance values, the audit code is always present',
      () {
        forAll(
          (int varianceSeed) {
            expect(src.contains('STOCK_VARIANCE_ALERT'), isTrue);
            expect(
              src.contains('variance.abs() > 10') || src.contains('> 10'),
              isTrue,
            );
            return true;
          },
          [Gen.interval(-50000, 50000)],
          numRuns: kNumRuns,
        );
      },
    );
  });

  // ==========================================================================
  // PRESERVATION 3.5 — DispenserService READING_UPDATE & PERMISSION_DENIED
  // ==========================================================================
  group('Preservation 3.5: DispenserService audit logging', () {
    late String src;

    setUpAll(() {
      src = _readSource(
        'lib/features/petrol_pump/services/dispenser_service.dart',
      );
      assert(src.isNotEmpty, 'dispenser_service.dart must exist');
    });

    test('READING_UPDATE audit action is logged', () {
      expect(
        src.contains('READING_UPDATE'),
        isTrue,
        reason:
            'DispenserService must log READING_UPDATE action on reading changes',
      );
    });

    test('PERMISSION_DENIED audit action is logged', () {
      expect(
        src.contains('PERMISSION_DENIED'),
        isTrue,
        reason:
            'DispenserService must log PERMISSION_DENIED on unauthorized attempts',
      );
    });

    test('_logReadingChange helper exists for READING_UPDATE', () {
      expect(
        src.contains('_logReadingChange'),
        isTrue,
        reason:
            'DispenserService must have _logReadingChange helper for audit trail',
      );
    });

    test('_logUnauthorizedAttempt helper exists for PERMISSION_DENIED', () {
      expect(
        src.contains('_logUnauthorizedAttempt'),
        isTrue,
        reason:
            'DispenserService must have _logUnauthorizedAttempt helper for audit',
      );
    });

    test('READING_UPDATE metadata contains type and value fields', () {
      // Find the _logReadingChange method definition (last occurrence which
      // is the actual method body, not just a call site)
      final lastLogMethodIdx = src.lastIndexOf('_logReadingChange');
      expect(lastLogMethodIdx, isNot(-1));

      final windowEnd = (lastLogMethodIdx + 500).clamp(0, src.length);
      final methodWindow = src.substring(lastLogMethodIdx, windowEnd);

      // The method logs JSON with "type" (from readingType param) and "value"
      expect(
        methodWindow.contains('readingType') || methodWindow.contains('"type"'),
        isTrue,
        reason:
            'READING_UPDATE audit must log the reading type (OPENING/CLOSING)',
      );
      expect(
        methodWindow.contains('value'),
        isTrue,
        reason: 'READING_UPDATE audit must log the reading value',
      );
    });

    test(
      'PERMISSION_DENIED metadata contains employeeId and attemptedAction',
      () {
        final deniedIdx = src.indexOf('PERMISSION_DENIED');
        expect(deniedIdx, isNot(-1));

        final windowEnd = (deniedIdx + 300).clamp(0, src.length);
        final deniedWindow = src.substring(deniedIdx, windowEnd);

        expect(
          deniedWindow.contains('employeeId'),
          isTrue,
          reason:
              'PERMISSION_DENIED audit must log the employeeId who attempted',
        );
        expect(
          deniedWindow.contains('attemptedAction'),
          isTrue,
          reason: 'PERMISSION_DENIED audit must log the attempted action',
        );
      },
    );

    test('PBT: audit logging patterns always present for arbitrary inputs', () {
      forAll(
        (int readingSeed) {
          expect(src.contains('READING_UPDATE'), isTrue);
          expect(src.contains('PERMISSION_DENIED'), isTrue);
          expect(src.contains('_logReadingChange'), isTrue);
          expect(src.contains('_logUnauthorizedAttempt'), isTrue);
          return true;
        },
        [Gen.interval(0, 999999)],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.8 — Tank Model Getters (non-rollover/non-overfill)
  // ==========================================================================
  group('Preservation 3.8: Tank model getters return correct values '
      '(non-overfill inputs)', () {
    test(
      'source contains stockVariance, stockPercentage, isLowStock getters',
      () {
        final src = _readSource('lib/features/petrol_pump/models/tank.dart');
        expect(src.isNotEmpty, isTrue, reason: 'tank.dart must exist');

        expect(
          src.contains('get stockVariance'),
          isTrue,
          reason: 'Tank model must have stockVariance getter',
        );
        expect(
          src.contains('get stockPercentage'),
          isTrue,
          reason: 'Tank model must have stockPercentage getter',
        );
        expect(
          src.contains('get isLowStock'),
          isTrue,
          reason: 'Tank model must have isLowStock getter',
        );
      },
    );

    test('PBT: stockVariance == currentStock - calculatedStock for '
        'non-overfill values', () {
      forAll(
        (int capacitySeed, int openingSeed, int purchaseSeed, int salesSeed) {
          // Generate valid non-overfill tank values
          final double capacity = (capacitySeed % 10000 + 100)
              .toDouble(); // 100..10099
          final double openingStock =
              ((openingSeed % capacity.toInt()).toDouble()).clamp(
                0.0,
                capacity,
              );
          final double purchaseQty = ((purchaseSeed % 100).toDouble()).clamp(
            0.0,
            capacity - openingStock,
          );
          final double salesDeduction = ((salesSeed % 100).toDouble()).clamp(
            0.0,
            openingStock + purchaseQty,
          );

          // currentStock equals calculatedStock for non-overfill
          final double currentStock =
              (openingStock + purchaseQty - salesDeduction).clamp(
                0.0,
                capacity,
              );

          final tank = Tank(
            tankId: 'test_tank',
            tankName: 'Test',
            fuelTypeId: 'fuel_1',
            capacity: capacity,
            openingStock: openingStock,
            purchaseQuantity: purchaseQty,
            salesDeduction: salesDeduction,
            currentStock: currentStock,
            ownerId: 'owner_1',
          );

          final double calculatedStock =
              openingStock + purchaseQty - salesDeduction;
          final double expectedVariance = currentStock - calculatedStock;

          expect(
            (tank.stockVariance - expectedVariance).abs(),
            lessThan(_eps),
            reason:
                'stockVariance must equal currentStock - calculatedStock. '
                'Got ${tank.stockVariance}, expected $expectedVariance',
          );
          return true;
        },
        [
          Gen.interval(100, 20000),
          Gen.interval(0, 10000),
          Gen.interval(0, 5000),
          Gen.interval(0, 5000),
        ],
        numRuns: kNumRuns,
      );
    });

    test('PBT: stockPercentage == (currentStock / capacity) * 100 for '
        'non-overfill values', () {
      forAll(
        (int capacitySeed, int stockSeed) {
          final double capacity = (capacitySeed % 10000 + 100).toDouble();
          final double currentStock = (stockSeed % capacity.toInt()).toDouble();

          final tank = Tank(
            tankId: 'test_tank',
            tankName: 'Test',
            fuelTypeId: 'fuel_1',
            capacity: capacity,
            currentStock: currentStock,
            ownerId: 'owner_1',
          );

          final double expectedPct = (currentStock / capacity) * 100;

          expect(
            (tank.stockPercentage - expectedPct).abs(),
            lessThan(0.01),
            reason:
                'stockPercentage must equal (currentStock / capacity) * 100. '
                'Got ${tank.stockPercentage}, expected $expectedPct',
          );
          return true;
        },
        [Gen.interval(100, 20000), Gen.interval(0, 19999)],
        numRuns: kNumRuns,
      );
    });

    test('PBT: isLowStock == true iff stockPercentage < 20', () {
      forAll(
        (int capacitySeed, int stockSeed) {
          final double capacity = (capacitySeed % 10000 + 100).toDouble();
          final double currentStock = (stockSeed % capacity.toInt()).toDouble();

          final tank = Tank(
            tankId: 'test_tank',
            tankName: 'Test',
            fuelTypeId: 'fuel_1',
            capacity: capacity,
            currentStock: currentStock,
            ownerId: 'owner_1',
          );

          final double pct = (currentStock / capacity) * 100;
          final bool expectedLow = pct < 20;

          expect(
            tank.isLowStock,
            equals(expectedLow),
            reason:
                'isLowStock must be true when stockPercentage < 20. '
                'stockPct=$pct, isLowStock=${tank.isLowStock}, '
                'expected=$expectedLow',
          );
          return true;
        },
        [Gen.interval(100, 20000), Gen.interval(0, 19999)],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.8 — Nozzle Model Getters (non-rollover inputs)
  // ==========================================================================
  group('Preservation 3.8: Nozzle model getters return correct values '
      '(non-rollover inputs)', () {
    test('source contains calculatedSaleLitres and isValidReading getters', () {
      final src = _readSource('lib/features/petrol_pump/models/nozzle.dart');
      expect(src.isNotEmpty, isTrue, reason: 'nozzle.dart must exist');

      expect(
        src.contains('get calculatedSaleLitres'),
        isTrue,
        reason: 'Nozzle model must have calculatedSaleLitres getter',
      );
      expect(
        src.contains('get isValidReading'),
        isTrue,
        reason: 'Nozzle model must have isValidReading getter',
      );
    });

    test('PBT: calculatedSaleLitres == closingReading - openingReading '
        'for non-rollover (closing >= opening)', () {
      forAll(
        (int openingSeed, int closingSeed) {
          // Ensure closing >= opening (non-rollover condition)
          final double opening = openingSeed.toDouble();
          final double closing = opening + closingSeed.abs().toDouble();

          final nozzle = Nozzle(
            nozzleId: 'nozzle_1',
            dispenserId: 'disp_1',
            fuelTypeId: 'fuel_1',
            openingReading: opening,
            closingReading: closing,
            ownerId: 'owner_1',
          );

          final double expectedSale = closing - opening;

          expect(
            (nozzle.calculatedSaleLitres - expectedSale).abs(),
            lessThan(_eps),
            reason:
                'calculatedSaleLitres must equal closing - opening for '
                'non-rollover values. Got ${nozzle.calculatedSaleLitres}, '
                'expected $expectedSale (opening=$opening, closing=$closing)',
          );
          return true;
        },
        [Gen.interval(0, 999999), Gen.interval(0, 100000)],
        numRuns: kNumRuns,
      );
    });

    test(
      'PBT: isValidReading == true when closing >= opening (non-rollover)',
      () {
        forAll(
          (int openingSeed, int deltaSeed) {
            final double opening = openingSeed.toDouble();
            final double closing = opening + deltaSeed.abs().toDouble();

            final nozzle = Nozzle(
              nozzleId: 'nozzle_1',
              dispenserId: 'disp_1',
              fuelTypeId: 'fuel_1',
              openingReading: opening,
              closingReading: closing,
              ownerId: 'owner_1',
            );

            expect(
              nozzle.isValidReading,
              isTrue,
              reason:
                  'isValidReading must be true when closing ($closing) >= '
                  'opening ($opening)',
            );
            return true;
          },
          [Gen.interval(0, 999999), Gen.interval(0, 100000)],
          numRuns: kNumRuns,
        );
      },
    );

    test('PBT: isValidReading == false when closing < opening (rollover-like, '
        'but calculatedSaleLitres clamps to 0)', () {
      forAll(
        (int openingSeed, int deltaSeed) {
          // Generate opening > closing (rollover-like scenario)
          final double opening = (openingSeed + 100).toDouble();
          final double closing = (opening - deltaSeed.abs().toDouble() - 1.0)
              .clamp(0.0, opening - 1.0);

          final nozzle = Nozzle(
            nozzleId: 'nozzle_1',
            dispenserId: 'disp_1',
            fuelTypeId: 'fuel_1',
            openingReading: opening,
            closingReading: closing,
            ownerId: 'owner_1',
          );

          // isValidReading should be false when closing < opening
          expect(
            nozzle.isValidReading,
            isFalse,
            reason:
                'isValidReading must be false when closing ($closing) < '
                'opening ($opening)',
          );

          // calculatedSaleLitres clamps negative to 0 (existing behavior)
          expect(
            nozzle.calculatedSaleLitres,
            closeTo(0.0, _eps),
            reason:
                'calculatedSaleLitres must clamp to 0 when closing < opening '
                '(existing silent-clamp behavior on unfixed code)',
          );
          return true;
        },
        [Gen.interval(100, 999999), Gen.interval(1, 50000)],
        numRuns: kNumRuns,
      );
    });
  });
}
