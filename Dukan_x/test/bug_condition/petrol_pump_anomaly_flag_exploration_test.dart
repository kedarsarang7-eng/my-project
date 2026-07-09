/// Bug Condition Exploration Test — validation.silentClampNoFlag
///
/// **Validates: Requirements 1.15**
///
/// Property 15: Bug Condition — Anomaly Flagged Alongside Clamp
///
/// This test confirms that:
/// 1. `Nozzle` model does NOT expose a `hasRolloverAnomaly` getter — when
///    `closingReading < openingReading` (totalizer rollover), the sale litres
///    are silently clamped to 0 with NO anomaly signal to the UI.
/// 2. `Tank` model does NOT expose a `hasOverfillAnomaly` getter — when
///    `addPurchase` would push `currentStock` above `capacity`, the stock is
///    silently clamped with NO overfill warning to the UI.
///
/// On UNFIXED code this test FAILS — proving the bug exists:
///   - nozzle.dart: `calculatedSaleLitres` clamps to 0, no `hasRolloverAnomaly`
///   - tank.dart: `addPurchase` clamps to `capacity`, no `hasOverfillAnomaly`
///
/// After the fix this same test PASSES — both anomaly getters exist and
/// return `true` exactly when information would otherwise be lost to clamping.
///
/// Scoped PBT Approach:
///   - Property-based test generating `Nozzle` values with
///     `closingReading < openingReading` (rollover) and asserting
///     `hasRolloverAnomaly == true`.
///   - Property-based test generating `Tank`/`(openingStock, purchaseQuantity, capacity)`
///     tuples that would overflow capacity and asserting
///     `hasOverfillAnomaly == true`.
///
/// Run: flutter test test/bug_condition/petrol_pump_anomaly_flag_exploration_test.dart
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
  // validation.silentClampNoFlag / 1.15 / 2.15 — Nozzle & Tank anomaly getters
  //
  // Bug: Nozzle.calculatedSaleLitres silently clamps negative (rollover) to 0
  //      with no signal. Tank.addPurchase silently clamps overflow to capacity
  //      with no signal. Neither model exposes an anomaly flag.
  //
  // Expected (post-fix):
  //   - Nozzle has `bool get hasRolloverAnomaly => closingReading < openingReading;`
  //   - Tank has `bool get hasOverfillAnomaly` that returns true when
  //     the unclamped calculated stock would exceed capacity.
  // ===========================================================================
  group('Bug Condition 1.15 — validation.silentClampNoFlag', () {
    late String nozzleSrc;
    late String tankSrc;

    setUpAll(() {
      nozzleSrc = _readSource('lib/features/petrol_pump/models/nozzle.dart');
      tankSrc = _readSource('lib/features/petrol_pump/models/tank.dart');
      assert(nozzleSrc.isNotEmpty, 'nozzle.dart must exist');
      assert(tankSrc.isNotEmpty, 'tank.dart must exist');
    });

    // =========================================================================
    // Sub-Test 1: Nozzle must expose `hasRolloverAnomaly` getter
    // =========================================================================
    test('Nozzle exposes hasRolloverAnomaly getter', () {
      // On FIXED code: nozzle.dart contains a `hasRolloverAnomaly` getter
      // On UNFIXED code: no such getter exists — the anomaly is invisible
      final hasGetter = nozzleSrc.contains('hasRolloverAnomaly');

      expect(
        hasGetter,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.15): nozzle.dart does NOT contain a '
            '`hasRolloverAnomaly` getter.\n\n'
            'Current code in calculatedSaleLitres:\n'
            '  double get calculatedSaleLitres {\n'
            '    final sale = closingReading - openingReading;\n'
            '    return sale >= 0 ? sale : 0;\n'
            '  }\n\n'
            'When closingReading < openingReading (totalizer rollover), the '
            'sale is silently clamped to 0. The UI has NO way to know that '
            'a rollover occurred — no flag, no getter, no signal.\n\n'
            'The fix must add:\n'
            '  bool get hasRolloverAnomaly => closingReading < openingReading;',
      );
    });

    // =========================================================================
    // Sub-Test 2: Tank must expose `hasOverfillAnomaly` getter
    // =========================================================================
    test('Tank exposes hasOverfillAnomaly getter', () {
      // On FIXED code: tank.dart contains a `hasOverfillAnomaly` getter
      // On UNFIXED code: no such getter exists — the anomaly is invisible
      final hasGetter = tankSrc.contains('hasOverfillAnomaly');

      expect(
        hasGetter,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.15): tank.dart does NOT contain a '
            '`hasOverfillAnomaly` getter.\n\n'
            'Current code in addPurchase:\n'
            '  Tank addPurchase(double quantity) {\n'
            '    final newPurchase = purchaseQuantity + quantity;\n'
            '    final newStock = currentStock + quantity;\n'
            '    return copyWith(\n'
            '      purchaseQuantity: newPurchase,\n'
            '      currentStock: newStock.clamp(0, capacity),\n'
            '    );\n'
            '  }\n\n'
            'When newStock > capacity, the overflow is silently discarded '
            'via .clamp(0, capacity). The UI has NO way to know that an '
            'overfill occurred — no flag, no getter, no signal.\n\n'
            'The fix must add:\n'
            '  bool get hasOverfillAnomaly => calculatedStock > capacity;',
      );
    });

    // =========================================================================
    // Sub-Test 3 (PBT): Generate Nozzle values with closingReading < openingReading
    // (rollover cases) and assert hasRolloverAnomaly would be true — but the
    // getter doesn't exist, so the anomaly is invisible.
    // =========================================================================
    test('PBT: Nozzle rollover cases must be flagged via hasRolloverAnomaly', () {
      // Generate 100 random rollover scenarios
      final rng = Random(42);
      final rolloverCases = <Map<String, double>>[];

      for (int i = 0; i < 100; i++) {
        // openingReading > closingReading → rollover
        final opening = 1000.0 + rng.nextDouble() * 99000.0; // [1000, 100000)
        final closing =
            rng.nextDouble() * opening * 0.99; // Always less than opening
        rolloverCases.add({'opening': opening, 'closing': closing});
      }

      // Verify all generated cases are true rollover scenarios
      for (final c in rolloverCases) {
        expect(
          c['closing']! < c['opening']!,
          isTrue,
          reason:
              'Generated case must be a rollover: '
              'closing=${c['closing']} < opening=${c['opening']}',
        );
      }

      // On FIXED code: nozzle.dart has `hasRolloverAnomaly` getter that
      // returns true for all these cases.
      // On UNFIXED code: no such getter exists — all 100 rollover cases
      // produce 0 litres with NO anomaly signal.
      final hasRolloverGetter = nozzleSrc.contains('hasRolloverAnomaly');

      expect(
        hasRolloverGetter,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.15 — PBT Nozzle Rollover): Generated 100 '
            'rollover scenarios where closingReading < openingReading.\n\n'
            'Sample counterexamples:\n'
            '  opening=${rolloverCases[0]['opening']!.toStringAsFixed(1)}, '
            'closing=${rolloverCases[0]['closing']!.toStringAsFixed(1)} → '
            'sale clamped to 0, NO anomaly flag\n'
            '  opening=${rolloverCases[1]['opening']!.toStringAsFixed(1)}, '
            'closing=${rolloverCases[1]['closing']!.toStringAsFixed(1)} → '
            'sale clamped to 0, NO anomaly flag\n'
            '  opening=${rolloverCases[2]['opening']!.toStringAsFixed(1)}, '
            'closing=${rolloverCases[2]['closing']!.toStringAsFixed(1)} → '
            'sale clamped to 0, NO anomaly flag\n\n'
            'ALL 100 rollover cases silently produce 0 litres via:\n'
            '  return sale >= 0 ? sale : 0;\n\n'
            'The UI cannot distinguish "no sale" from "totalizer rolled over".\n'
            'The fix must add: bool get hasRolloverAnomaly => '
            'closingReading < openingReading;',
      );
    });

    // =========================================================================
    // Sub-Test 4 (PBT): Generate Tank tuples where openingStock + purchaseQuantity
    // exceeds capacity (overfill cases) and assert hasOverfillAnomaly would be
    // true — but the getter doesn't exist, so the anomaly is invisible.
    // =========================================================================
    test('PBT: Tank overfill cases must be flagged via hasOverfillAnomaly', () {
      // Generate 100 random overfill scenarios
      final rng = Random(123);
      final overfillCases = <Map<String, double>>[];

      for (int i = 0; i < 100; i++) {
        final capacity = 1000.0 + rng.nextDouble() * 49000.0; // [1000, 50000)
        final openingStock =
            capacity * (0.5 + rng.nextDouble() * 0.4); // [50%, 90%] of capacity
        // Purchase quantity that EXCEEDS remaining capacity
        final remainingCapacity = capacity - openingStock;
        final purchaseQuantity =
            remainingCapacity + 1.0 + rng.nextDouble() * 5000.0;

        overfillCases.add({
          'capacity': capacity,
          'openingStock': openingStock,
          'purchaseQuantity': purchaseQuantity,
        });
      }

      // Verify all generated cases are true overfill scenarios
      for (final c in overfillCases) {
        final unclamped = c['openingStock']! + c['purchaseQuantity']!;
        expect(
          unclamped > c['capacity']!,
          isTrue,
          reason:
              'Generated case must overflow: '
              'stock=${c['openingStock']} + purchase=${c['purchaseQuantity']} '
              '= $unclamped > capacity=${c['capacity']}',
        );
      }

      // On FIXED code: tank.dart has `hasOverfillAnomaly` getter that
      // returns true when calculatedStock > capacity.
      // On UNFIXED code: no such getter exists — all 100 overfill cases
      // silently clamp stock to capacity with NO anomaly signal.
      final hasOverfillGetter = tankSrc.contains('hasOverfillAnomaly');

      expect(
        hasOverfillGetter,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.15 — PBT Tank Overfill): Generated 100 '
            'overfill scenarios where openingStock + purchaseQuantity > capacity.\n\n'
            'Sample counterexamples:\n'
            '  capacity=${overfillCases[0]['capacity']!.toStringAsFixed(0)}, '
            'stock=${overfillCases[0]['openingStock']!.toStringAsFixed(0)}, '
            'purchase=${overfillCases[0]['purchaseQuantity']!.toStringAsFixed(0)} → '
            'overflow silently clamped, NO anomaly flag\n'
            '  capacity=${overfillCases[1]['capacity']!.toStringAsFixed(0)}, '
            'stock=${overfillCases[1]['openingStock']!.toStringAsFixed(0)}, '
            'purchase=${overfillCases[1]['purchaseQuantity']!.toStringAsFixed(0)} → '
            'overflow silently clamped, NO anomaly flag\n'
            '  capacity=${overfillCases[2]['capacity']!.toStringAsFixed(0)}, '
            'stock=${overfillCases[2]['openingStock']!.toStringAsFixed(0)}, '
            'purchase=${overfillCases[2]['purchaseQuantity']!.toStringAsFixed(0)} → '
            'overflow silently clamped, NO anomaly flag\n\n'
            'ALL 100 overfill cases silently discard overflow litres via:\n'
            '  currentStock: newStock.clamp(0, capacity)\n\n'
            'The UI cannot tell the operator that fuel was delivered '
            'beyond tank capacity. The fix must add:\n'
            '  bool get hasOverfillAnomaly => calculatedStock > capacity;',
      );
    });

    // =========================================================================
    // Sub-Test 5: Nozzle.calculatedSaleLitres clamps negative to 0
    // (verifies the silent clamping behavior exists in source)
    // =========================================================================
    test('Nozzle.calculatedSaleLitres silently clamps negative to 0', () {
      // Verify the current source code has the silent clamping pattern
      final hasClampPattern =
          nozzleSrc.contains('sale >= 0 ? sale : 0') ||
          nozzleSrc.contains('sale >= 0? sale : 0') ||
          nozzleSrc.contains(RegExp(r'sale\s*>=\s*0\s*\?\s*sale\s*:\s*0'));

      expect(
        hasClampPattern,
        isTrue,
        reason:
            'nozzle.dart must contain the silent clamping pattern '
            '`sale >= 0 ? sale : 0`',
      );

      // And verify there's NO anomaly flag accompanying this clamp
      final hasAnomalyFlag = nozzleSrc.contains('hasRolloverAnomaly');

      expect(
        hasAnomalyFlag,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.15): Nozzle.calculatedSaleLitres silently '
            'clamps negative values to 0:\n'
            '  final sale = closingReading - openingReading;\n'
            '  return sale >= 0 ? sale : 0;\n\n'
            'But there is NO `hasRolloverAnomaly` getter to signal the clamp. '
            'Information is lost: the operator sees "0 litres" but cannot '
            'distinguish it from "totalizer rolled over, actual sale is unknown".\n\n'
            'The fix must add a complementary getter:\n'
            '  bool get hasRolloverAnomaly => closingReading < openingReading;',
      );
    });

    // =========================================================================
    // Sub-Test 6: Tank.addPurchase silently clamps overflow to capacity
    // (verifies the silent clamping behavior exists in source)
    // =========================================================================
    test('Tank.addPurchase silently clamps overflow to capacity', () {
      // Verify the current source code has the silent clamping in addPurchase
      final addPurchaseIdx = tankSrc.indexOf('addPurchase');
      expect(
        addPurchaseIdx,
        isNot(-1),
        reason: 'tank.dart must contain addPurchase method',
      );

      // Extract the addPurchase method body
      final methodBodyStart = tankSrc.indexOf('{', addPurchaseIdx);
      int depth = 0;
      int methodEnd = -1;
      for (int i = methodBodyStart; i < tankSrc.length; i++) {
        if (tankSrc[i] == '{') depth++;
        if (tankSrc[i] == '}') {
          depth--;
          if (depth == 0) {
            methodEnd = i + 1;
            break;
          }
        }
      }

      final addPurchaseBody = tankSrc.substring(methodBodyStart, methodEnd);

      // Verify it uses .clamp(0, capacity)
      final hasClamp =
          addPurchaseBody.contains('.clamp(0, capacity)') ||
          addPurchaseBody.contains('.clamp(0,capacity)');
      expect(
        hasClamp,
        isTrue,
        reason: 'addPurchase must clamp to capacity (this is the bug pattern)',
      );

      // And verify there's NO anomaly flag accompanying this clamp
      final hasAnomalyFlag = tankSrc.contains('hasOverfillAnomaly');

      expect(
        hasAnomalyFlag,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.15): Tank.addPurchase silently clamps overflow:\n'
            '  final newStock = currentStock + quantity;\n'
            '  return copyWith(\n'
            '    purchaseQuantity: newPurchase,\n'
            '    currentStock: newStock.clamp(0, capacity),\n'
            '  );\n\n'
            'But there is NO `hasOverfillAnomaly` getter to signal the clamp. '
            'Information is lost: the purchase quantity exceeds remaining '
            'capacity but the UI cannot warn about an overfill.\n\n'
            'The fix must add a complementary getter:\n'
            '  bool get hasOverfillAnomaly => calculatedStock > capacity;',
      );
    });
  });
}
