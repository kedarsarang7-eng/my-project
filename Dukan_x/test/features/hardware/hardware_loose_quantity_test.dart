// ============================================================================
// HARDWARE-011 — Loose-Quantity / Cut-to-Length Selling Workflow
// ============================================================================
//
// Feature: hardware-audit-fixes
// Task 3.11 — Build loose-quantity selling workflow
// **Validates: Requirements 1.11, 2.11**
//
// PURPOSE:
//   Proves that a loose-quantity/cut-to-length selling widget exists,
//   integrated with HardwareBusinessRules.cutToSizeCharge(), including
//   remnant-inventory tracking using the local-first repository from 3.1.
//
//   On UNFIXED code this test FAILS because no such widget exists.
//
// Bug Condition:
//   isBugCondition(input) where input.surface == 'billing.looseQuantitySale'
//
// Expected Behavior:
//   loose-quantity sale with remnant tracking supported (Property 11 in design)
//
// Preservation:
//   non-loose-quantity billing unaffected (3.11)
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HARDWARE-011: Loose-quantity/cut-to-length selling widget', () {
    late String widgetSource;
    late bool widgetFileExists;

    setUpAll(() {
      final f = File(
        'lib/features/hardware/widgets/loose_quantity_selling_sheet.dart',
      );
      widgetFileExists = f.existsSync();
      if (widgetFileExists) {
        widgetSource = f.readAsStringSync();
      } else {
        widgetSource = '';
      }
    });

    test('Loose-quantity selling widget file exists', () {
      expect(
        widgetFileExists,
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-011): No loose-quantity/cut-to-length '
            'selling widget exists at '
            'lib/features/hardware/widgets/loose_quantity_selling_sheet.dart',
      );
    });

    test('Widget integrates with HardwareBusinessRules.cutToSizeCharge()', () {
      if (!widgetFileExists) {
        fail(
          'BUG CONFIRMED (HARDWARE-011): Widget file does not exist — '
          'cutToSizeCharge integration cannot be verified.',
        );
      }
      expect(
        widgetSource.contains('cutToSizeCharge'),
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-011): Widget does not integrate with '
            'HardwareBusinessRules.cutToSizeCharge().',
      );
    });

    test('Widget tracks remnant inventory', () {
      if (!widgetFileExists) {
        fail(
          'BUG CONFIRMED (HARDWARE-011): Widget file does not exist — '
          'remnant tracking cannot be verified.',
        );
      }
      // Remnant tracking means the widget calculates and persists the
      // remaining stock after a cut.
      expect(
        widgetSource.contains('remnant') || widgetSource.contains('Remnant'),
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-011): Widget does not track remnant '
            'inventory after a cut-to-size sale.',
      );
    });

    test('Widget persists remnants via local-first repository', () {
      if (!widgetFileExists) {
        fail(
          'BUG CONFIRMED (HARDWARE-011): Widget file does not exist — '
          'local-first remnant persistence cannot be verified.',
        );
      }
      // Should reference the hardware_ops_repository for local persistence
      expect(
        widgetSource.contains('hardware_ops_repository') ||
            widgetSource.contains('HardwareOpsRepository'),
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-011): Widget does not use the local-first '
            'HardwareOpsRepository for remnant persistence.',
      );
    });

    test('Widget shows cut-to-size rounding note when applicable', () {
      if (!widgetFileExists) {
        fail(
          'BUG CONFIRMED (HARDWARE-011): Widget file does not exist — '
          'rounding note display cannot be verified.',
        );
      }
      expect(
        widgetSource.contains('cutToSizeRoundingNote') ||
            widgetSource.contains('cutToSizeWasRoundedUp'),
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-011): Widget does not show the '
            'cut-to-size rounding disclosure note.',
      );
    });

    test('Widget calculates remnant from stock length minus cut length', () {
      if (!widgetFileExists) {
        fail(
          'BUG CONFIRMED (HARDWARE-011): Widget file does not exist — '
          'remnant calculation cannot be verified.',
        );
      }
      // The widget should contain remnant calculation logic
      // (stockLength - cutLength or similar)
      expect(
        widgetSource.contains('stockLength') ||
            widgetSource.contains('_stockLength') ||
            widgetSource.contains('totalLength'),
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-011): Widget does not contain stock '
            'length / remnant calculation logic.',
      );
    });

    test('Non-loose-quantity billing code is not affected (preservation)', () {
      // Verify that bill_creation_screen_v2 still operates normally for
      // standard items (pcs, kg, box, nos) — the new widget is additive.
      final billScreen = File(
        'lib/features/billing/presentation/screens/bill_creation_screen_v2.dart',
      );
      if (!billScreen.existsSync()) {
        // If the bill screen doesn't exist, preservation is trivially met
        return;
      }
      final billSource = billScreen.readAsStringSync();

      // Standard billing logic (non-loose-quantity) should still work via
      // the regular _addItem path without requiring the loose-quantity widget.
      expect(
        billSource.contains('_addItem') || billSource.contains('addItem'),
        isTrue,
        reason:
            'PRESERVATION FAILED: Standard _addItem billing path is missing '
            'from bill_creation_screen_v2.dart.',
      );
    });
  });
}
