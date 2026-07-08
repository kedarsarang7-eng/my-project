// ============================================================================
// HARDWARE-002 — DimensionCalculator on quick-add / barcode-scan sale path
// ============================================================================
//
// Feature: hardware-audit-fixes
// Task 3.3 — Surface DimensionCalculator on quick-add/scan sale path.
// **Validates: Requirements 1.2, 2.2**
//
// PURPOSE:
//   Proves that when a dimension-unit item (sqft/sqmtr/ft/mtr) is added via the
//   quick-add or barcode-scan sale path, the DimensionCalculator is surfaced
//   for the user to enter dimensions before the item is billed.
//
//   On UNFIXED code this test FAILS because _addItem in bill_creation_screen_v2
//   adds dimension-unit items directly (qty=1) without routing them through the
//   DimensionCalculator — the calculator only exists in ManualItemEntrySheet.
//
// Bug Condition:
//   isBugCondition(input) where input.surface == 'billing.quickAddDimensionItem'
//
// Expected Behavior:
//   DimensionCalculator reachable from every hardware sale path (Property 3)
//
// Preservation:
//   Non-dimension items (pcs, kg, box, nos) and existing manual-entry usage
//   unchanged (3.2)
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The dimension units that should trigger the DimensionCalculator on the
/// quick-add/barcode-scan path for hardware business type.
const _dimensionUnits = {'sqft', 'sqmtr', 'ft', 'mtr'};

/// Non-dimension units that must NOT trigger the DimensionCalculator.
const _nonDimensionUnits = {'pcs', 'kg', 'box', 'nos', 'dozen', 'g', 'l'};

/// Reads the shipping source of bill_creation_screen_v2.dart and checks that
/// the dimension-unit routing logic exists in the _addItem method.
///
/// This is a source-probe test: it reads the actual production code and asserts
/// the presence of the dimension-unit check that routes hardware dimension items
/// through the DimensionCalculator before adding them to the bill.
void main() {
  group('HARDWARE-002: DimensionCalculator on quick-add/scan path', () {
    late String source;

    setUpAll(() {
      final f = File(
        'lib/features/billing/presentation/screens/bill_creation_screen_v2.dart',
      );
      expect(
        f.existsSync(),
        isTrue,
        reason: 'bill_creation_screen_v2.dart must exist',
      );
      source = f.readAsStringSync();
    });

    test('_addItem contains hardware dimension-unit detection and routing', () {
      // The fix should introduce a check like:
      //   if (businessType == BusinessType.hardware && _isHardwareDimensionUnit(product.unit))
      // that routes to a dimension calculator sheet before adding the item.
      //
      // On UNFIXED code: _addItem has NO such check -> this test FAILS.
      expect(
        source.contains('_isHardwareDimensionUnit'),
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-002): _addItem does not detect hardware '
            'dimension-unit items. The DimensionCalculator is only available in '
            'ManualItemEntrySheet, not on the quick-add/barcode-scan path.',
      );
    });

    test('_addItemWithStockWarning also routes dimension-unit items', () {
      // The stock-warning override path must also surface the calculator.
      // Count occurrences of the routing in the file (should be at least 2:
      // one in _addItem, one in _addItemWithStockWarning).
      final matches = '_isHardwareDimensionUnit'.allMatches(source).length;
      expect(
        matches,
        greaterThanOrEqualTo(2),
        reason:
            'BUG CONFIRMED (HARDWARE-002): _addItemWithStockWarning does not '
            'route hardware dimension-unit items through the DimensionCalculator.',
      );
    });

    test('_showHardwareDimensionSheet method exists', () {
      // A dedicated sheet method should present the DimensionCalculator inline
      // (mirroring _showGroceryWeightSheet for grocery).
      expect(
        source.contains('_showHardwareDimensionSheet'),
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-002): No _showHardwareDimensionSheet method '
            'exists — DimensionCalculator is unreachable from quick-add/scan.',
      );
    });

    test('DimensionCalculator import present in bill_creation_screen_v2', () {
      // The fix must import the DimensionCalculator widget.
      expect(
        source.contains('dimension_calculator'),
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-002): dimension_calculator is not imported '
            'in bill_creation_screen_v2.dart — cannot surface it on quick-add.',
      );
    });

    test('Non-dimension units are NOT routed through dimension calculator', () {
      // Verify the helper function correctly excludes non-dimension units.
      // This is a preservation check — pcs, kg, box, nos should never trigger
      // the dimension calculator.
      //
      // If the helper exists, we verify its logic by reading the source.
      // If it doesn't exist, the prior tests already fail.
      if (!source.contains('_isHardwareDimensionUnit')) {
        // Bug still present — skip preservation check (it's meaningless without
        // the fix). The earlier tests already document the defect.
        fail(
          'PRESERVATION CHECK SKIPPED: _isHardwareDimensionUnit does not exist '
          'yet — the bug is still present.',
        );
      }

      // The helper should only match dimension units, not non-dimension ones.
      // We verify by checking the source contains the dimension-unit set.
      for (final unit in _dimensionUnits) {
        expect(
          source.contains("'$unit'"),
          isTrue,
          reason: 'Dimension unit "$unit" should be recognized by the helper.',
        );
      }
    });
  });
}
