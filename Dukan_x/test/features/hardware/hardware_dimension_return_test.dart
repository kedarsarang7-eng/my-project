// ============================================================================
// HARDWARE-013 — Dimension-aware sales return
// ============================================================================
//
// Feature: hardware-audit-fixes
// Task 3.13 — Add dimension-aware sales return in ReturnInwardsScreen.
// **Validates: Requirements 1.13, 2.13**
//
// PURPOSE:
//   Proves that when a dimension-billed item (unit in {sqft, sqmtr, ft, mtr})
//   is being returned via ReturnInwardsScreen for a hardware business type,
//   the dimension metadata from the original sale is carried through and
//   a DimensionCalculator is available for partial-area return-quantity entry.
//
//   On UNFIXED code this test FAILS because _buildReturnItemsCard uses only
//   a generic quantity-based CheckboxListTile — no dimension metadata is
//   carried and no DimensionCalculator is shown for dimension-billed items.
//
// Bug Condition:
//   isBugCondition(input) where input.surface == 'returnInwards.dimensionBilledItem'
//
// Expected Behavior:
//   dimension metadata carried through; partial-area return entry available
//   (Property 13 in design)
//
// Preservation:
//   Non-dimension-billed returns and other verticals' use of the shared screen
//   unchanged (3.13)
// ============================================================================

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Dimension units that should trigger the DimensionCalculator on return path
/// for hardware business type.
const _dimensionUnits = {'sqft', 'sqmtr', 'ft', 'mtr'};

void main() {
  group('HARDWARE-013: Dimension-aware sales return', () {
    late String returnScreenSource;

    setUpAll(() {
      // Read the production source for return_inwards_screen.dart
      final file = File(
        'lib/features/revenue/screens/return_inwards_screen.dart',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'ReturnInwardsScreen file must exist',
      );
      returnScreenSource = file.readAsStringSync();
    });

    test('return screen checks for dimension metadata on bill items', () {
      // The fix must detect dimension-billed items from the original bill.
      // It should check the item's `dimensions` field or `unit` to determine
      // if DimensionCalculator should be shown.
      final hasDimensionCheck =
          returnScreenSource.contains('dimensions') &&
          (returnScreenSource.contains('DimensionCalculator') ||
              returnScreenSource.contains('dimension_calculator'));

      expect(
        hasDimensionCheck,
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-013): ReturnInwardsScreen does not check '
            'for dimension metadata on bill items. Dimension-billed items get '
            'generic quantity-only return without area-based partial return.',
      );
    });

    test('DimensionCalculator import present in return_inwards_screen', () {
      // The fix must import the DimensionCalculator widget so it can be
      // shown for dimension-billed items during returns.
      expect(
        returnScreenSource.contains('dimension_calculator'),
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-013): return_inwards_screen.dart does not '
            'import DimensionCalculator — dimension-aware partial-area return '
            'entry is impossible.',
      );
    });

    test(
      'return screen checks business type for hardware before showing dimensions',
      () {
        // The dimension-aware return should ONLY activate for hardware business
        // type. Other verticals must not see the DimensionCalculator.
        final hasBusinessTypeCheck =
            returnScreenSource.contains('BusinessType.hardware') ||
            returnScreenSource.contains('businessType') &&
                returnScreenSource.contains('hardware');

        expect(
          hasBusinessTypeCheck,
          isTrue,
          reason:
              'BUG CONFIRMED (HARDWARE-013): ReturnInwardsScreen does not check '
              'business type before showing dimension-aware return. The fix must '
              'scope this to hardware only.',
        );
      },
    );

    test('ReturnItem model or return context carries dimension metadata', () {
      // Read the revenue_models.dart to check if ReturnItem has dimensions
      final modelsFile = File(
        'lib/features/revenue/models/revenue_models.dart',
      );
      expect(modelsFile.existsSync(), isTrue);
      final modelsSource = modelsFile.readAsStringSync();

      // Extract the ReturnItem class
      final returnItemStart = modelsSource.indexOf('class ReturnItem');
      final returnItemEnd = modelsSource.indexOf(
        '}',
        modelsSource.indexOf('Map<String, dynamic> toMap()', returnItemStart),
      );
      final returnItemSource = modelsSource.substring(
        returnItemStart,
        returnItemEnd + 1,
      );

      // ReturnItem should have a dimensions field
      expect(
        returnItemSource.contains('dimensions'),
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-013): ReturnItem model does not carry '
            'dimension metadata (length, width, unit, area). Dimension-billed '
            'items lose their dimension context during returns.',
      );
    });

    test('dimension-billed return items show area-based entry, not just qty', () {
      // The return items card should have logic for dimension-unit items
      // to show area-based return entry (DimensionCalculator or similar).
      // Check for dimension unit detection in the return screen.
      final hasDimensionUnitCheck = _dimensionUnits.any(
        (unit) => returnScreenSource.contains("'$unit'"),
      );

      expect(
        hasDimensionUnitCheck,
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-013): ReturnInwardsScreen has no dimension '
            'unit detection (sqft/sqmtr/ft/mtr). All items use the same generic '
            'quantity-only return regardless of billing method.',
      );
    });
  });
}
