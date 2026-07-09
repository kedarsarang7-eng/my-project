/// Bug Condition Exploration Test — bug.debugPrints
///
/// **Validates: Requirements 1.14**
///
/// Property 14: Bug Condition — No Debug Console Output
///
/// This test confirms that `PetrolPumpBillingService` and `ShiftService`
/// contain raw `print('DEBUG: ...')` statements in production code:
///   - 9 debug print calls in `petrol_pump_billing_service.dart` (createFuelBill)
///   - 5 debug print/stack calls in `shift_service.dart` (openShift/_resetNozzlesForShift)
///
/// On UNFIXED code this test FAILS — proving the bug exists:
///   - `print('DEBUG: Starting transaction for bill')`
///   - `print('DEBUG: Generating ID')`
///   - `print('DEBUG: Preparing BillCompanion for $billId')`
///   - `print('DEBUG: Inserting Bill')`
///   - `print('DEBUG: Enqueuing Bill Sync')`
///   - `print('DEBUG: Updating Tank Stock for $tankId')`
///   - `print('DEBUG: Enqueuing Tank Sync')`
///   - `print('DEBUG: Logging Stock Movement')`
///   - `print('DEBUG: Updating Nozzle Reading for ${nozzle.nozzleId}')`
///   in billing service; and:
///   - `print('DEBUG: Insert Shift Companion')`
///   - `print('DEBUG: Shift Insert Failed: $e')`
///   - `print(stack)`
///   - `print('DEBUG: Enqueue Shift Sync')`
///   - `print('DEBUG: Resetting Nozzles')`
///   in shift service.
///
/// After the fix this same test PASSES — all raw print statements are removed
/// or replaced with a proper conditional/debug-only logger.
///
/// Run: flutter test test/bug_condition/petrol_pump_debug_prints_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // bug.debugPrints / 1.14 / 2.14
  //
  // Bug: Raw `print('DEBUG: ...')` statements left in production code.
  //      They trace normal control flow, leak implementation details to the
  //      console, and add no value in production.
  //
  // Expected (post-fix):
  //   - No line in either service file starts with or contains `print('DEBUG:`
  //   - No raw `print(stack)` call in shift_service.dart
  //   - Debug output is either removed entirely or replaced with a conditional
  //     logger that is silent in production builds.
  // ===========================================================================
  group('Bug Condition 1.14 — bug.debugPrints', () {
    late String billingServiceSrc;
    late String shiftServiceSrc;

    setUpAll(() {
      billingServiceSrc = _readSource(
        'lib/features/petrol_pump/services/petrol_pump_billing_service.dart',
      );
      shiftServiceSrc = _readSource(
        'lib/features/petrol_pump/services/shift_service.dart',
      );
      assert(
        billingServiceSrc.isNotEmpty,
        'petrol_pump_billing_service.dart must exist',
      );
      assert(shiftServiceSrc.isNotEmpty, 'shift_service.dart must exist');
    });

    // =========================================================================
    // Sub-Test 1: PetrolPumpBillingService must NOT contain any print('DEBUG:
    // =========================================================================
    test(
      'PetrolPumpBillingService.createFuelBill has no DEBUG print statements',
      () {
        // Find all lines containing print('DEBUG: in the billing service
        final debugPattern = RegExp(r"print\('DEBUG:");
        final matches = debugPattern.allMatches(billingServiceSrc).toList();

        // On FIXED code: matches.length == 0 (no DEBUG prints remain)
        // On UNFIXED code: matches.length == 9 — test FAILS
        expect(
          matches.length,
          equals(0),
          reason:
              'COUNTEREXAMPLE (1.14): PetrolPumpBillingService contains '
              '${matches.length} raw print(\'DEBUG: ...\') statements in '
              'createFuelBill:\n\n'
              '  1. print(\'DEBUG: Starting transaction for bill\')\n'
              '  2. print(\'DEBUG: Generating ID\')\n'
              '  3. print(\'DEBUG: Preparing BillCompanion for \$billId\')\n'
              '  4. print(\'DEBUG: Inserting Bill\')\n'
              '  5. print(\'DEBUG: Enqueuing Bill Sync\')\n'
              '  6. print(\'DEBUG: Updating Tank Stock for \$tankId\')\n'
              '  7. print(\'DEBUG: Enqueuing Tank Sync\')\n'
              '  8. print(\'DEBUG: Logging Stock Movement\')\n'
              '  9. print(\'DEBUG: Updating Nozzle Reading for '
              '\${nozzle.nozzleId}\')\n\n'
              'These trace normal control flow and leak implementation '
              'details to the production console. The fix must remove them '
              'or replace with a conditional debug-only logger.',
        );
      },
    );

    // =========================================================================
    // Sub-Test 2: ShiftService must NOT contain any print('DEBUG:
    // =========================================================================
    test(
      'ShiftService.openShift/_resetNozzlesForShift has no DEBUG prints',
      () {
        // Find all lines containing print('DEBUG: in the shift service
        final debugPattern = RegExp(r"print\('DEBUG:");
        final matches = debugPattern.allMatches(shiftServiceSrc).toList();

        // On FIXED code: matches.length == 0
        // On UNFIXED code: matches.length == 4 — test FAILS
        expect(
          matches.length,
          equals(0),
          reason:
              'COUNTEREXAMPLE (1.14): ShiftService contains '
              '${matches.length} raw print(\'DEBUG: ...\') statements in '
              'openShift/_resetNozzlesForShift:\n\n'
              '  1. print(\'DEBUG: Insert Shift Companion\')\n'
              '  2. print(\'DEBUG: Shift Insert Failed: \$e\')\n'
              '  3. print(\'DEBUG: Enqueue Shift Sync\')\n'
              '  4. print(\'DEBUG: Resetting Nozzles\')\n\n'
              'These trace normal control flow and leak implementation '
              'details to the production console. The fix must remove them '
              'or replace with a conditional debug-only logger.',
        );
      },
    );

    // =========================================================================
    // Sub-Test 3: ShiftService must NOT contain raw print(stack)
    // =========================================================================
    test('ShiftService has no raw print(stack) call', () {
      // Find print(stack) — raw stack trace dumped to console
      final stackPrintPattern = RegExp(r'print\(stack\)');
      final matches = stackPrintPattern.allMatches(shiftServiceSrc).toList();

      // On FIXED code: matches.length == 0
      // On UNFIXED code: matches.length == 1 — test FAILS
      expect(
        matches.length,
        equals(0),
        reason:
            'COUNTEREXAMPLE (1.14): ShiftService contains a raw '
            'print(stack) call that dumps the full stack trace to the '
            'production console:\n\n'
            '  } catch (e, stack) {\n'
            '    print(\'DEBUG: Shift Insert Failed: \$e\');\n'
            '    print(stack);\n'
            '    rethrow;\n'
            '  }\n\n'
            'This exposes internal implementation details (file paths, '
            'line numbers, call chains) to the production console output. '
            'The fix must remove this or use a proper error logger.',
      );
    });

    // =========================================================================
    // Sub-Test 4: Combined count — total debug output lines across both files
    // =========================================================================
    test('Total debug output lines across both services is zero', () {
      // Count all print statements that produce debug output
      final debugPrintPattern = RegExp(r"print\('DEBUG:");
      final stackPrintPattern = RegExp(r'print\(stack\)');

      final billingDebugCount = debugPrintPattern
          .allMatches(billingServiceSrc)
          .length;
      final shiftDebugCount = debugPrintPattern
          .allMatches(shiftServiceSrc)
          .length;
      final shiftStackCount = stackPrintPattern
          .allMatches(shiftServiceSrc)
          .length;

      final totalDebugOutputs =
          billingDebugCount + shiftDebugCount + shiftStackCount;

      // On FIXED code: totalDebugOutputs == 0
      // On UNFIXED code: totalDebugOutputs == 14 (9 + 4 + 1) — test FAILS
      expect(
        totalDebugOutputs,
        equals(0),
        reason:
            'COUNTEREXAMPLE (1.14): Found $totalDebugOutputs raw debug '
            'output statements across both service files:\n\n'
            '  petrol_pump_billing_service.dart: $billingDebugCount '
            'print(\'DEBUG: ...\') calls\n'
            '  shift_service.dart: $shiftDebugCount print(\'DEBUG: ...\') '
            'calls + $shiftStackCount print(stack) call\n\n'
            'Expected: 0 debug output lines in production code.\n'
            'Actual: $totalDebugOutputs debug output lines.\n\n'
            'These statements trace normal control flow (transaction '
            'start, ID generation, insert, sync enqueue, stock update, '
            'nozzle reading update, shift creation, nozzle reset) and '
            'serve no purpose in production. They leak implementation '
            'details and add console noise.',
      );
    });

    // =========================================================================
    // Sub-Test 5: Verify specific expected DEBUG messages exist (confirms
    // we're detecting the right bug, not a false positive)
    // =========================================================================
    test('Billing service contains specific known DEBUG messages', () {
      // These are the exact known DEBUG messages in the billing service.
      // If they exist, the bug is confirmed. If they don't, code was fixed.
      final expectedMessages = [
        "print('DEBUG: Starting transaction",
        "print('DEBUG: Generating ID",
        "print('DEBUG: Preparing BillCompanion",
        "print('DEBUG: Inserting Bill",
        "print('DEBUG: Enqueuing Bill Sync",
        "print('DEBUG: Updating Tank Stock",
        "print('DEBUG: Enqueuing Tank Sync",
        "print('DEBUG: Logging Stock Movement",
        "print('DEBUG: Updating Nozzle Reading",
      ];

      final foundMessages = <String>[];
      for (final msg in expectedMessages) {
        if (billingServiceSrc.contains(msg)) {
          foundMessages.add(msg);
        }
      }

      // On FIXED code: foundMessages is empty (all removed)
      // On UNFIXED code: foundMessages.length == 9 — test FAILS
      expect(
        foundMessages,
        isEmpty,
        reason:
            'COUNTEREXAMPLE (1.14): Found ${foundMessages.length}/9 known '
            'DEBUG print statements still present in billing service:\n\n'
            '${foundMessages.map((m) => '  • $m').join('\n')}\n\n'
            'Each of these traces a normal step in createFuelBill\'s '
            'transaction. They must be removed for production.',
      );
    });

    // =========================================================================
    // Sub-Test 6: Verify specific expected DEBUG messages in shift service
    // =========================================================================
    test('Shift service contains specific known DEBUG messages', () {
      final expectedMessages = [
        "print('DEBUG: Insert Shift Companion",
        "print('DEBUG: Shift Insert Failed",
        "print(stack)",
        "print('DEBUG: Enqueue Shift Sync",
        "print('DEBUG: Resetting Nozzles",
      ];

      final foundMessages = <String>[];
      for (final msg in expectedMessages) {
        if (shiftServiceSrc.contains(msg)) {
          foundMessages.add(msg);
        }
      }

      // On FIXED code: foundMessages is empty (all removed)
      // On UNFIXED code: foundMessages.length == 5 — test FAILS
      expect(
        foundMessages,
        isEmpty,
        reason:
            'COUNTEREXAMPLE (1.14): Found ${foundMessages.length}/5 known '
            'debug output statements still present in shift service:\n\n'
            '${foundMessages.map((m) => '  • $m').join('\n')}\n\n'
            'These include:\n'
            '  - Normal flow traces (insert companion, enqueue sync, '
            'reset nozzles)\n'
            '  - Error handler that dumps full stack trace to console\n\n'
            'All must be removed or replaced with a conditional logger.',
      );
    });
  });
}
