/// Preservation Property Test — Shift-Close Reconciliation/Cash-Variance Logic Preserved
///
/// **Validates: Requirements 3.3**
///
/// Property 16: Preservation — Shift-Close Reconciliation/Cash-Variance Logic Preserved
///
/// This test confirms that the three shift-close decision mechanisms remain
/// unchanged by the fix:
/// 1. `closeShift` uses `reconciliation.isWithinTolerance` to gate shift closure
/// 2. A `cashVarianceThreshold` (₹100) exists and is used for the cash-declaration check
/// 3. A `forceClose` parameter exists for owner-override with audit logging (`SHIFT_FORCE_CLOSE`)
///
/// The fix only changes `calculateShiftSales`'s inputs (rollover-aware litres,
/// real billed litres) but does NOT alter the close-decision thresholds or
/// tolerance logic itself.
///
/// Methodology (source-reading / observation-first):
///   - Read `shift_service.dart` and `shift_reconciliation.dart` via `dart:io`
///     and verify each mechanism exists at the correct location with correct values.
///   - Property-based: generate arbitrary `ShiftReconciliation` inputs within/at
///     tolerance boundaries and assert the tolerance/variance decision logic is
///     unchanged — `isWithinTolerance` depends only on `toleranceLitres` (0.5L).
///
/// This test MUST PASS on UNFIXED code — it captures baseline behavior that
/// the fix must preserve.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/bug_condition/petrol_pump_preservation_shift_close_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/features/petrol_pump/models/shift_reconciliation.dart';

const double _eps = 1e-9;
const int kNumRuns = 200;

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ==========================================================================
  // PRESERVATION 3.3 — Mechanism #1: isWithinTolerance gates shift closure
  // ==========================================================================
  group('Preservation 3.3: closeShift uses isWithinTolerance to gate closure', () {
    late String shiftServiceSrc;
    late String closeShiftBody;

    setUpAll(() {
      shiftServiceSrc = _readSource(
        'lib/features/petrol_pump/services/shift_service.dart',
      );
      assert(shiftServiceSrc.isNotEmpty, 'shift_service.dart must exist');

      // Extract the closeShift method body — method is ~110 lines,
      // need a 7000-char window to capture full body including audit log
      final methodIdx = shiftServiceSrc.indexOf('Future<void> closeShift(');
      assert(methodIdx != -1, 'closeShift method must exist');

      final windowEnd = (methodIdx + 7000).clamp(0, shiftServiceSrc.length);
      closeShiftBody = shiftServiceSrc.substring(methodIdx, windowEnd);
    });

    test('closeShift source contains isWithinTolerance check', () {
      expect(
        closeShiftBody.contains('isWithinTolerance'),
        isTrue,
        reason:
            'closeShift must reference isWithinTolerance for the '
            'reconciliation tolerance gate. This fraud-prevention check '
            'must remain after the fix.',
      );
    });

    test(
      'closeShift blocks closure when NOT within tolerance (unless forceClose)',
      () {
        // The pattern: `if (!reconciliation.isWithinTolerance && !forceClose)`
        final hasToleranceGate = RegExp(
          r'!reconciliation\.isWithinTolerance\s*&&\s*!forceClose',
        ).hasMatch(closeShiftBody);

        expect(
          hasToleranceGate,
          isTrue,
          reason:
              'closeShift must contain the pattern '
              '`!reconciliation.isWithinTolerance && !forceClose` — '
              'this is the fraud-prevention gate that blocks closure when '
              'variance exceeds tolerance unless the owner force-closes.',
        );
      },
    );

    test(
      'closeShift throws ShiftReconciliationException on tolerance failure',
      () {
        expect(
          closeShiftBody.contains('ShiftReconciliationException'),
          isTrue,
          reason:
              'closeShift must throw ShiftReconciliationException when '
              'variance exceeds tolerance. This exception type must remain.',
        );
      },
    );

    test('ShiftReconciliation model defines toleranceLitres = 0.5', () {
      final reconcSrc = _readSource(
        'lib/features/petrol_pump/models/shift_reconciliation.dart',
      );
      expect(
        reconcSrc.isNotEmpty,
        isTrue,
        reason: 'shift_reconciliation.dart must exist',
      );

      // Check for the static tolerance constant
      final hasToleranceConst = RegExp(
        r'toleranceLitres\s*=\s*0\.5',
      ).hasMatch(reconcSrc);

      expect(
        hasToleranceConst,
        isTrue,
        reason:
            'ShiftReconciliation must define toleranceLitres = 0.5. '
            'This threshold must remain unchanged after the fix — only '
            'the inputs (rollover-aware litres) change, not the threshold.',
      );
    });

    test('ShiftReconciliation.isWithinTolerance uses toleranceLitres', () {
      final reconcSrc = _readSource(
        'lib/features/petrol_pump/models/shift_reconciliation.dart',
      );

      // Check that isWithinTolerance references toleranceLitres
      final hasIsWithinTolerance = reconcSrc.contains('isWithinTolerance');
      final referencesTolerance = RegExp(
        r'isWithinTolerance.*toleranceLitres|toleranceLitres.*isWithinTolerance',
      ).hasMatch(reconcSrc.replaceAll('\n', ' '));

      // Also check by extracting the getter body
      final getterIdx = reconcSrc.indexOf('isWithinTolerance');
      expect(getterIdx, isNot(-1));
      final getterWindow = reconcSrc.substring(
        getterIdx,
        (getterIdx + 200).clamp(0, reconcSrc.length),
      );
      final usesTolerance = getterWindow.contains('toleranceLitres');

      expect(
        hasIsWithinTolerance && usesTolerance,
        isTrue,
        reason:
            'isWithinTolerance getter must reference toleranceLitres. '
            'The decision logic itself must not change.',
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.3 — Mechanism #2: cashVarianceThreshold for cash-declaration
  // ==========================================================================
  group('Preservation 3.3: cashVarianceThreshold gates cash-declaration check', () {
    late String closeShiftBody;

    setUpAll(() {
      final shiftServiceSrc = _readSource(
        'lib/features/petrol_pump/services/shift_service.dart',
      );
      assert(shiftServiceSrc.isNotEmpty);

      final methodIdx = shiftServiceSrc.indexOf('Future<void> closeShift(');
      assert(methodIdx != -1);

      final windowEnd = (methodIdx + 7000).clamp(0, shiftServiceSrc.length);
      closeShiftBody = shiftServiceSrc.substring(methodIdx, windowEnd);
    });

    test('closeShift defines cashVarianceThreshold = 100.0', () {
      final hasThreshold = RegExp(
        r'cashVarianceThreshold\s*=\s*100\.0',
      ).hasMatch(closeShiftBody);

      expect(
        hasThreshold,
        isTrue,
        reason:
            'closeShift must define cashVarianceThreshold = 100.0 (₹100 tolerance). '
            'This value must remain unchanged after the fix.',
      );
    });

    test('closeShift computes cashVariance from declared vs expected', () {
      final hasVarianceCalc =
          closeShiftBody.contains('cashDeclared - expectedCash') ||
          closeShiftBody.contains('cashDeclared - reconciliation.cashAmount');

      expect(
        hasVarianceCalc,
        isTrue,
        reason:
            'closeShift must compute cashVariance as the difference between '
            'cashDeclared and expectedCash. This logic must remain.',
      );
    });

    test(
      'closeShift blocks close when cash variance exceeds threshold (unless forceClose)',
      () {
        final hasCashGate = RegExp(
          r'cashVariance\.abs\(\)\s*>\s*cashVarianceThreshold\s*&&\s*!forceClose',
        ).hasMatch(closeShiftBody);

        expect(
          hasCashGate,
          isTrue,
          reason:
              'closeShift must contain the pattern '
              '`cashVariance.abs() > cashVarianceThreshold && !forceClose` — '
              'this is the cash accountability gate.',
        );
      },
    );

    test(
      'closeShift throws CashDeclarationException on cash variance failure',
      () {
        expect(
          closeShiftBody.contains('CashDeclarationException'),
          isTrue,
          reason:
              'closeShift must throw CashDeclarationException when cash '
              'variance exceeds threshold. This exception must remain.',
        );
      },
    );

    test('closeShift logs CASH_VARIANCE_ALERT when threshold exceeded', () {
      expect(
        closeShiftBody.contains('CASH_VARIANCE_ALERT'),
        isTrue,
        reason:
            'closeShift must log CASH_VARIANCE_ALERT for audit when '
            'cash variance exceeds threshold. This audit logging must remain.',
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.3 — Mechanism #3: forceClose owner-override with audit logging
  // ==========================================================================
  group('Preservation 3.3: forceClose owner-override with audit logging', () {
    late String closeShiftBody;

    setUpAll(() {
      final shiftServiceSrc = _readSource(
        'lib/features/petrol_pump/services/shift_service.dart',
      );
      assert(shiftServiceSrc.isNotEmpty);

      final methodIdx = shiftServiceSrc.indexOf('Future<void> closeShift(');
      assert(methodIdx != -1);

      final windowEnd = (methodIdx + 7000).clamp(0, shiftServiceSrc.length);
      closeShiftBody = shiftServiceSrc.substring(methodIdx, windowEnd);
    });

    test('closeShift has forceClose parameter with default false', () {
      final hasForceClose = RegExp(
        r'bool\s+forceClose\s*=\s*false',
      ).hasMatch(closeShiftBody);

      expect(
        hasForceClose,
        isTrue,
        reason:
            'closeShift must have `bool forceClose = false` parameter. '
            'This owner-override mechanism must remain after the fix.',
      );
    });

    test('closeShift logs SHIFT_FORCE_CLOSE when forceClose is used', () {
      expect(
        closeShiftBody.contains('SHIFT_FORCE_CLOSE'),
        isTrue,
        reason:
            'closeShift must log SHIFT_FORCE_CLOSE as an audit action when '
            'the owner uses forceClose to override reconciliation/cash checks. '
            'This audit trail must remain.',
      );
    });

    test('forceClose distinguishes audit action from normal SHIFT_CLOSE', () {
      // Check that both SHIFT_FORCE_CLOSE and SHIFT_CLOSE exist
      expect(
        closeShiftBody.contains('SHIFT_CLOSE'),
        isTrue,
        reason: 'closeShift must have a normal SHIFT_CLOSE audit action',
      );

      // Check that forceClose determines which action is logged
      final hasConditionalAudit = RegExp(
        r"forceClose\s*\?\s*'SHIFT_FORCE_CLOSE'\s*:\s*'SHIFT_CLOSE'",
      ).hasMatch(closeShiftBody);

      expect(
        hasConditionalAudit,
        isTrue,
        reason:
            'closeShift must use a conditional `forceClose ? SHIFT_FORCE_CLOSE : SHIFT_CLOSE` '
            'for the audit action. This differentiation must remain.',
      );
    });

    test('forceClose bypasses BOTH tolerance and cash variance checks', () {
      // Count how many times !forceClose appears as a gate
      final forceCloseGates = RegExp(r'!forceClose').allMatches(closeShiftBody);

      expect(
        forceCloseGates.length,
        greaterThanOrEqualTo(2),
        reason:
            'forceClose must gate at least two checks: '
            '(1) reconciliation tolerance and (2) cash variance threshold. '
            'Both gates must remain after the fix.',
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.3 — PBT: ShiftReconciliation tolerance decision is unchanged
  // ==========================================================================
  group('Preservation 3.3 PBT: tolerance decision logic is invariant', () {
    test(
      'PBT: isWithinTolerance depends only on varianceLitres vs 0.5L threshold',
      () {
        forAll(
          (int varianceTimes1000) {
            // Generate variance from -5.0L to +5.0L in 0.001L increments
            final variance = varianceTimes1000 / 1000.0;

            final reconciliation = ShiftReconciliation(
              nozzleLitres: 100.0 + variance,
              billedLitres: 100.0,
              tankDeducted: 100.0,
              varianceLitres: variance,
              cashAmount: 5000.0,
              upiAmount: 1000.0,
              cardAmount: 500.0,
              creditAmount: 200.0,
            );

            // The decision must depend ONLY on |varianceLitres| <= 0.5
            final expected =
                variance.abs() <= ShiftReconciliation.toleranceLitres;
            expect(
              reconciliation.isWithinTolerance,
              equals(expected),
              reason:
                  'isWithinTolerance must be true iff |varianceLitres| <= 0.5. '
                  'Got variance=$variance, expected isWithinTolerance=$expected. '
                  'The threshold itself must not change — only inputs to '
                  'calculateShiftSales become more accurate.',
            );
            return true;
          },
          [Gen.interval(-5000, 5000)],
          numRuns: kNumRuns,
        );
      },
    );

    test(
      'PBT: toleranceLitres constant is always exactly 0.5 regardless of input',
      () {
        forAll(
          (int nozzleLitresTimes10, int billedLitresTimes10) {
            // Generate arbitrary nozzle and billed litres
            final nozzleLitres = nozzleLitresTimes10 / 10.0;
            final billedLitres = billedLitresTimes10 / 10.0;

            // The static tolerance constant must always be 0.5
            expect(
              ShiftReconciliation.toleranceLitres,
              closeTo(0.5, _eps),
              reason:
                  'toleranceLitres must always be 0.5 regardless of any '
                  'nozzleLitres ($nozzleLitres) or billedLitres ($billedLitres). '
                  'The fix changes inputs, not thresholds.',
            );
            return true;
          },
          [Gen.interval(0, 100000), Gen.interval(0, 100000)],
          numRuns: kNumRuns,
        );
      },
    );

    test('PBT: cashVarianceThreshold source value is always 100.0', () {
      final shiftServiceSrc = _readSource(
        'lib/features/petrol_pump/services/shift_service.dart',
      );

      forAll(
        (int cashDeclaredTimes100) {
          // Generate arbitrary cashDeclared values (₹0 to ₹99,999)
          final cashDeclared = cashDeclaredTimes100 / 100.0;

          // The source-level threshold must always be 100.0
          final thresholdMatch = RegExp(
            r'cashVarianceThreshold\s*=\s*(\d+\.?\d*)',
          ).firstMatch(shiftServiceSrc);

          expect(thresholdMatch, isNotNull);
          final thresholdValue = double.parse(thresholdMatch!.group(1)!);
          expect(
            thresholdValue,
            closeTo(100.0, _eps),
            reason:
                'cashVarianceThreshold must always be 100.0 in source, '
                'regardless of arbitrary cashDeclared ($cashDeclared). '
                'The fix does not alter this threshold.',
          );
          return true;
        },
        [Gen.interval(0, 9999900)],
        numRuns: kNumRuns,
      );
    });

    test('PBT: boundary variance at exactly 0.5L is within tolerance', () {
      forAll(
        (int cashAmountTimes100) {
          // Generate arbitrary cash amounts
          final cashAmount = cashAmountTimes100 / 100.0;

          // At exactly 0.5L variance, should be within tolerance
          final reconciliation = ShiftReconciliation(
            nozzleLitres: 100.5,
            billedLitres: 100.0,
            tankDeducted: 100.0,
            varianceLitres: 0.5,
            cashAmount: cashAmount,
            upiAmount: 0.0,
            cardAmount: 0.0,
            creditAmount: 0.0,
          );

          expect(
            reconciliation.isWithinTolerance,
            isTrue,
            reason:
                'Variance of exactly 0.5L must be within tolerance '
                '(boundary inclusive). cashAmount=$cashAmount should not '
                'affect this decision.',
          );

          // At 0.501L variance, should NOT be within tolerance
          final overReconciliation = ShiftReconciliation(
            nozzleLitres: 100.501,
            billedLitres: 100.0,
            tankDeducted: 100.0,
            varianceLitres: 0.501,
            cashAmount: cashAmount,
            upiAmount: 0.0,
            cardAmount: 0.0,
            creditAmount: 0.0,
          );

          expect(
            overReconciliation.isWithinTolerance,
            isFalse,
            reason:
                'Variance of 0.501L must be outside tolerance (> 0.5L). '
                'cashAmount=$cashAmount should not affect this decision.',
          );
          return true;
        },
        [Gen.interval(0, 1000000)],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.3 — Combined: All three mechanisms coexist in source
  // ==========================================================================
  group('Preservation 3.3: all three shift-close mechanisms coexist', () {
    test('all three mechanisms are simultaneously present in closeShift', () {
      final shiftServiceSrc = _readSource(
        'lib/features/petrol_pump/services/shift_service.dart',
      );
      expect(shiftServiceSrc.isNotEmpty, isTrue);

      // Mechanism #1: isWithinTolerance
      expect(
        shiftServiceSrc.contains('isWithinTolerance'),
        isTrue,
        reason: 'isWithinTolerance check must exist in shift_service.dart',
      );

      // Mechanism #2: cashVarianceThreshold
      expect(
        shiftServiceSrc.contains('cashVarianceThreshold'),
        isTrue,
        reason: 'cashVarianceThreshold must exist in shift_service.dart',
      );

      // Mechanism #3: forceClose with SHIFT_FORCE_CLOSE audit
      expect(
        shiftServiceSrc.contains('forceClose'),
        isTrue,
        reason: 'forceClose parameter must exist in shift_service.dart',
      );
      expect(
        shiftServiceSrc.contains('SHIFT_FORCE_CLOSE'),
        isTrue,
        reason:
            'SHIFT_FORCE_CLOSE audit action must exist in shift_service.dart',
      );

      // Also verify the reconciliation model has the tolerance constant
      final reconcSrc = _readSource(
        'lib/features/petrol_pump/models/shift_reconciliation.dart',
      );
      expect(reconcSrc.isNotEmpty, isTrue);
      expect(
        reconcSrc.contains('toleranceLitres'),
        isTrue,
        reason:
            'toleranceLitres constant must exist in shift_reconciliation.dart',
      );
    });
  });
}
