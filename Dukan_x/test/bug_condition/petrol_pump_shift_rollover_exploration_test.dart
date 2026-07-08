/// Bug Condition Exploration Test — shift.rolloverAndBilledLitres
///
/// **Validates: Requirements 1.10**
///
/// Property 10: Bug Condition — Rollover-Aware, Real Billed Litres
///
/// This test confirms that `ShiftService.calculateShiftSales`:
/// 1. Does NOT call `PetrolPumpBusinessRules.dispensedLitres` — it uses
///    raw subtraction `closingReading - openingReading` which produces
///    large negative values when the totalizer has rolled over.
/// 2. Hardcodes `billedLitres: 0` and `variance: 0` in the
///    `NozzleReconciliation(...)` construction, meaning per-nozzle
///    billing attribution is never computed.
///
/// On UNFIXED code this test FAILS — proving the bug exists:
///   - The litres calculation does NOT delegate to the rollover-aware
///     `PetrolPumpBusinessRules.dispensedLitres`, so a nozzle with
///     openingReading: 999900 and closingReading: 100 yields -999800
///     instead of the correct ~200.
///   - Every NozzleReconciliation gets billedLitres: 0, variance: 0
///     regardless of actual bills attributed to that nozzle.
///
/// After the fix this same test PASSES — `calculateShiftSales` calls
/// `PetrolPumpBusinessRules.dispensedLitres` and computes real
/// per-nozzle billedLitres/variance from bill items.
///
/// Run: flutter test test/bug_condition/petrol_pump_shift_rollover_exploration_test.dart
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // shift.rolloverAndBilledLitres / 1.10 / 2.10 — ShiftService.calculateShiftSales
  // does raw subtraction (closingReading - openingReading) instead of calling the
  // rollover-aware PetrolPumpBusinessRules.dispensedLitres; also hardcodes
  // billedLitres: 0 and variance: 0 in NozzleReconciliation.
  //
  // Concrete case: openingReading: 999900, closingReading: 100
  //   BUG:   100 - 999900 = -999800 (large negative)
  //   FIXED: PetrolPumpBusinessRules.dispensedLitres(999900, 100) = ~200
  //
  // Expected (post-fix):
  //   - calculateShiftSales calls PetrolPumpBusinessRules.dispensedLitres
  //   - NozzleReconciliation.billedLitres and .variance are computed from
  //     actual bill data, not hardcoded to 0.
  // ===========================================================================
  group('Bug Condition 1.10 — shift.rolloverAndBilledLitres', () {
    late String shiftServiceSrc;

    setUpAll(() {
      shiftServiceSrc = _readSource(
        'lib/features/petrol_pump/services/shift_service.dart',
      );
      assert(shiftServiceSrc.isNotEmpty, 'shift_service.dart must exist');
    });

    // =========================================================================
    // Property-Based Sub-Test: For random (openingReading, closingReading) pairs
    // where closingReading < openingReading (rollover region), the code MUST
    // call PetrolPumpBusinessRules.dispensedLitres instead of raw subtraction.
    // =========================================================================
    test(
      'calculateShiftSales calls PetrolPumpBusinessRules.dispensedLitres (not raw subtraction)',
      () {
        // Locate calculateShiftSales method
        final methodPattern = 'calculateShiftSales';
        final methodIdx = shiftServiceSrc.indexOf(methodPattern);
        expect(
          methodIdx,
          isNot(-1),
          reason: 'calculateShiftSales method must exist in shift_service.dart',
        );

        // Extract the method body — find the opening brace and then the next
        // top-level method definition to bound the extraction.
        final methodBodyStart = shiftServiceSrc.indexOf('{', methodIdx);

        final nextMethodPatterns = [
          'Future<List<StaffSalesSummary>> calculateStaffSales',
          'Future<void> createStaffSettlements',
          'Future<void> _resetNozzlesForShift',
        ];

        int methodEndIdx = shiftServiceSrc.length;
        for (final pat in nextMethodPatterns) {
          final idx = shiftServiceSrc.indexOf(pat, methodBodyStart + 1);
          if (idx != -1 && idx < methodEndIdx) {
            methodEndIdx = idx;
          }
        }

        final methodBody = shiftServiceSrc.substring(
          methodBodyStart,
          methodEndIdx,
        );

        // On FIXED code: calculateShiftSales MUST call
        // PetrolPumpBusinessRules.dispensedLitres (or dispensedLitres from
        // that class) to compute litres — this handles totalizer rollover.
        //
        // On UNFIXED code: it uses raw subtraction:
        //   `final litresSold = nozzleEntity.closingReading - nozzleEntity.openingReading;`
        // and does NOT reference PetrolPumpBusinessRules or dispensedLitres.

        final callsDispensedLitres =
            methodBody.contains('PetrolPumpBusinessRules.dispensedLitres') ||
            methodBody.contains('dispensedLitres(');

        expect(
          callsDispensedLitres,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.10): calculateShiftSales uses raw subtraction '
              '`nozzleEntity.closingReading - nozzleEntity.openingReading` '
              'instead of calling PetrolPumpBusinessRules.dispensedLitres.\n\n'
              'Concrete rollover case:\n'
              '  openingReading: 999900, closingReading: 100\n'
              '  BUG RESULT:   100 - 999900 = -999800 litres (NEGATIVE)\n'
              '  CORRECT:      dispensedLitres(999900, 100) = 200 litres\n\n'
              'The raw subtraction produces large negative values whenever the '
              'mechanical totalizer wraps past 1,000,000 litres, corrupting '
              'the entire shift reconciliation.',
        );
      },
    );

    test('calculateShiftSales does NOT use raw subtraction for litres', () {
      // Double-check: the raw subtraction pattern should NOT be present
      // in the method body after the fix.
      final methodIdx = shiftServiceSrc.indexOf('calculateShiftSales');
      final methodBodyStart = shiftServiceSrc.indexOf('{', methodIdx);

      final nextMethodPatterns = [
        'Future<List<StaffSalesSummary>> calculateStaffSales',
        'Future<void> createStaffSettlements',
        'Future<void> _resetNozzlesForShift',
      ];

      int methodEndIdx = shiftServiceSrc.length;
      for (final pat in nextMethodPatterns) {
        final idx = shiftServiceSrc.indexOf(pat, methodBodyStart + 1);
        if (idx != -1 && idx < methodEndIdx) {
          methodEndIdx = idx;
        }
      }

      final methodBody = shiftServiceSrc.substring(
        methodBodyStart,
        methodEndIdx,
      );

      // The buggy pattern: direct subtraction of closingReading - openingReading
      // to compute litresSold
      final rawSubtractionPattern = RegExp(
        r'closingReading\s*-\s*\w*\.?openingReading',
      );
      final usesRawSubtraction = rawSubtractionPattern.hasMatch(methodBody);

      // On FIXED code: raw subtraction is REMOVED (replaced by dispensedLitres call)
      // On UNFIXED code: raw subtraction IS present → this test FAILS
      expect(
        usesRawSubtraction,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.10): calculateShiftSales still contains '
            '`closingReading - openingReading` raw subtraction.\n\n'
            'This produces negative litres when totalizer rolls over:\n'
            '  openingReading: 999900, closingReading: 100\n'
            '  100 - 999900 = -999800 (INCORRECT)\n\n'
            'Must be replaced with PetrolPumpBusinessRules.dispensedLitres() '
            'which correctly computes: 1000000 - 999900 + 100 = 200 litres.',
      );
    });

    // =========================================================================
    // Property-Based Sub-Test: For ANY nozzle with bills attributed to it,
    // NozzleReconciliation.billedLitres and .variance must NOT be hardcoded 0.
    // =========================================================================
    test(
      'NozzleReconciliation billedLitres is computed from actual bills (not hardcoded 0)',
      () {
        // Locate the NozzleReconciliation construction within calculateShiftSales
        final methodIdx = shiftServiceSrc.indexOf('calculateShiftSales');
        final methodBodyStart = shiftServiceSrc.indexOf('{', methodIdx);

        final nextMethodPatterns = [
          'Future<List<StaffSalesSummary>> calculateStaffSales',
          'Future<void> createStaffSettlements',
          'Future<void> _resetNozzlesForShift',
        ];

        int methodEndIdx = shiftServiceSrc.length;
        for (final pat in nextMethodPatterns) {
          final idx = shiftServiceSrc.indexOf(pat, methodBodyStart + 1);
          if (idx != -1 && idx < methodEndIdx) {
            methodEndIdx = idx;
          }
        }

        final methodBody = shiftServiceSrc.substring(
          methodBodyStart,
          methodEndIdx,
        );

        // On UNFIXED code: NozzleReconciliation is constructed with
        //   billedLitres: 0,
        //   variance: 0,
        // (hardcoded zero — no actual bill data is aggregated per nozzle)
        //
        // On FIXED code: billedLitres should reference a computed value from
        // actual bill items (e.g. billedLitresByNozzle[nozzleId])

        // Check for the hardcoded pattern
        final hardcodedBilledLitres = RegExp(
          r'billedLitres\s*:\s*0',
        ).hasMatch(methodBody);

        // On FIXED code: billedLitres should NOT be hardcoded to 0
        // On UNFIXED code: billedLitres IS hardcoded to 0 → this test FAILS
        expect(
          hardcodedBilledLitres,
          isFalse,
          reason:
              'COUNTEREXAMPLE (1.10): NozzleReconciliation is constructed with '
              '`billedLitres: 0` (hardcoded). Per-nozzle billing attribution '
              'is never computed.\n\n'
              'The code has:\n'
              '  NozzleReconciliation(\n'
              '    ...\n'
              '    billedLitres: 0, // Simplified: Not tracking per-nozzle billing yet\n'
              '    variance: 0,\n'
              '  )\n\n'
              'The fix must aggregate bill item quantities per nozzle (from '
              'itemsJson entries containing a nozzleId) and use the real sum.',
        );
      },
    );

    test('NozzleReconciliation variance is computed (not hardcoded 0)', () {
      final methodIdx = shiftServiceSrc.indexOf('calculateShiftSales');
      final methodBodyStart = shiftServiceSrc.indexOf('{', methodIdx);

      final nextMethodPatterns = [
        'Future<List<StaffSalesSummary>> calculateStaffSales',
        'Future<void> createStaffSettlements',
        'Future<void> _resetNozzlesForShift',
      ];

      int methodEndIdx = shiftServiceSrc.length;
      for (final pat in nextMethodPatterns) {
        final idx = shiftServiceSrc.indexOf(pat, methodBodyStart + 1);
        if (idx != -1 && idx < methodEndIdx) {
          methodEndIdx = idx;
        }
      }

      final methodBody = shiftServiceSrc.substring(
        methodBodyStart,
        methodEndIdx,
      );

      // On UNFIXED code: variance: 0 is hardcoded in NozzleReconciliation
      // On FIXED code: variance = litresSold - billedLitres (computed)
      final hardcodedVariance = RegExp(
        r'variance\s*:\s*0',
      ).hasMatch(methodBody);

      expect(
        hardcodedVariance,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.10): NozzleReconciliation is constructed with '
            '`variance: 0` (hardcoded). The per-nozzle variance (litresSold '
            'minus billedLitres for that nozzle) is never computed.\n\n'
            'The code has:\n'
            '  NozzleReconciliation(\n'
            '    ...\n'
            '    billedLitres: 0,\n'
            '    variance: 0, // Always zero — no fraud detection per nozzle\n'
            '  )\n\n'
            'The fix must compute: variance = litresSold - '
            'billedLitresByNozzle[nozzleEntity.nozzleId] ?? 0',
      );
    });

    // =========================================================================
    // Property-Based: Generate random rollover reading pairs and verify that
    // PetrolPumpBusinessRules.dispensedLitres produces positive results, while
    // raw subtraction would produce negative — demonstrating why the fix matters.
    // =========================================================================
    test(
      'PBT: rollover reading pairs produce negative values with raw subtraction',
      () {
        // Generate 100 random (openingReading, closingReading) pairs in the
        // rollover region: closingReading < openingReading.
        final rng = Random(42); // Deterministic seed for reproducibility
        const totalizerMax = 1000000.0;

        for (int i = 0; i < 100; i++) {
          // Opening reading: high value (900000..999999)
          final openingReading = 900000.0 + rng.nextDouble() * 99999.0;
          // Closing reading: low value (0..5000) — rolled over
          final closingReading = rng.nextDouble() * 5000.0;

          // Raw subtraction (the bug):
          final rawResult = closingReading - openingReading;

          // Rollover-aware computation (what the fix uses):
          final correctResult = totalizerMax - openingReading + closingReading;

          // The raw subtraction ALWAYS produces a large negative number
          // in the rollover region
          expect(
            rawResult < 0,
            isTrue,
            reason:
                'Sanity: raw subtraction should be negative for rollover case '
                '(opening=$openingReading, closing=$closingReading, raw=$rawResult)',
          );

          // The correct computation ALWAYS produces a positive number
          expect(
            correctResult > 0,
            isTrue,
            reason:
                'Sanity: rollover-aware computation should be positive '
                '(opening=$openingReading, closing=$closingReading, correct=$correctResult)',
          );
        }

        // Now verify the SOURCE CODE still uses the buggy pattern:
        // If calculateShiftSales uses raw subtraction, a rollover pair like
        // (999900, 100) would produce 100 - 999900 = -999800.
        //
        // The fact that we verified raw subtraction is STILL in the source
        // (from the tests above) means these 100 random rollover cases would
        // ALL produce incorrect negative values in the running system.
        //
        // This test documents the property that MUST hold after the fix:
        // For all (open, close) where close < open, calculateShiftSales must
        // call dispensedLitres and return a POSITIVE value.
        //
        // On UNFIXED code: the earlier tests already FAIL. This test itself
        // passes (it's just math verification), but the overall group FAILS
        // because the source-level checks above fail first.
      },
    );

    test('shift_service.dart imports petrol_pump_business_rules.dart', () {
      // On FIXED code: shift_service.dart must import the business rules
      // utility that provides the rollover-aware dispensedLitres function.
      //
      // On UNFIXED code: there is NO such import — proving the method
      // is never called.
      final hasBusinessRulesImport =
          shiftServiceSrc.contains('petrol_pump_business_rules') ||
          shiftServiceSrc.contains('PetrolPumpBusinessRules');

      expect(
        hasBusinessRulesImport,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.10): shift_service.dart does NOT import '
            'petrol_pump_business_rules.dart and has ZERO references to '
            'PetrolPumpBusinessRules. The rollover-aware dispensedLitres '
            'method (which correctly handles totalizer wrap at 1,000,000L) '
            'is never called from calculateShiftSales.\n\n'
            'The file calculates litres via raw subtraction:\n'
            '  final litresSold = nozzleEntity.closingReading - '
            'nozzleEntity.openingReading;\n\n'
            'This must be replaced with:\n'
            '  final litresSold = PetrolPumpBusinessRules.dispensedLitres(\n'
            '    startReading: nozzleEntity.openingReading,\n'
            '    endReading: nozzleEntity.closingReading,\n'
            '  );',
      );
    });
  });
}
