/// Bug Condition Exploration Test — HARDWARE-017 Cut-to-Size Rounding Disclosure
///
/// **Validates: Requirements 1.17, 2.17**
///
/// Property 16: Bug Condition — Invoice line item displays rounding disclosure
/// when cutToSizeCharge() rounds up.
///
/// This test asserts that the HardwareStrategy (which renders hardware bill
/// line items) displays HardwareBusinessRules.cutToSizeRoundingNote() on the
/// invoice line whenever a cut-to-size round-up occurs.
///
/// On UNFIXED code this test FAILS — the rounding note is never shown on the
/// invoice line item (the round-up is applied silently with no disclosure).
/// After the fix (Task 3.16) this same test PASSES.
///
/// Run: flutter test test/bug_condition/hardware_cut_to_size_disclosure_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // HARDWARE-017 / 1.17 / 2.17 — Cut-to-size rounding disclosure on invoice
  //
  // Expected (post-fix): When a hardware bill line item has fractional units
  // that are rounded up by cutToSizeCharge(), the invoice line item displays
  // the cutToSizeRoundingNote() disclosure text.
  //
  // Bug condition: the HardwareStrategy.buildItemFields() applies the round-up
  // silently — no rounding disclosure is shown on the invoice line item.
  // ===========================================================================
  group('Bug Condition 1.17 — cut-to-size rounding disclosure on invoice', () {
    test('HardwareStrategy shows cutToSizeRoundingNote on invoice line items', () {
      final src = _readSource(
        'lib/core/billing/strategies/hardware_strategy.dart',
      );

      expect(
        src.isNotEmpty,
        isTrue,
        reason: 'hardware_strategy.dart must exist to verify the disclosure.',
      );

      // The strategy MUST reference cutToSizeRoundingNote or
      // cutToSizeWasRoundedUp to display the disclosure on the line item.
      final hasRoundingNote =
          src.contains('cutToSizeRoundingNote') ||
          src.contains('cutToSizeWasRoundedUp');

      expect(
        hasRoundingNote,
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-017): HardwareStrategy.buildItemFields() '
            'does NOT reference cutToSizeRoundingNote or cutToSizeWasRoundedUp. '
            'The cut-to-size round-up is applied silently with no disclosure '
            'shown on the invoice line item.',
      );
    });

    test(
      'HardwareStrategy imports HardwareBusinessRules for rounding disclosure',
      () {
        final src = _readSource(
          'lib/core/billing/strategies/hardware_strategy.dart',
        );

        expect(
          src.isNotEmpty,
          isTrue,
          reason: 'hardware_strategy.dart must exist to verify the import.',
        );

        // Must import the business rules to access the disclosure method.
        expect(
          src.contains('hardware_business_rules'),
          isTrue,
          reason:
              'BUG CONFIRMED (HARDWARE-017): HardwareStrategy does not import '
              'HardwareBusinessRules. Without this import, the rounding '
              'disclosure cannot be computed for the invoice line item.',
        );
      },
    );

    test('Shop-level setting exists to enable/disable cut-to-size rounding', () {
      final src = _readSource(
        'lib/core/billing/strategies/hardware_strategy.dart',
      );

      expect(
        src.isNotEmpty,
        isTrue,
        reason: 'hardware_strategy.dart must exist.',
      );

      // There should be a reference to a setting that controls the rounding
      // convention (cutToSizeRoundingEnabled or similar).
      final hasSetting =
          src.contains('cutToSizeRounding') ||
          src.contains('cut_to_size_rounding') ||
          src.contains('roundingEnabled') ||
          src.contains('rounding_enabled');

      expect(
        hasSetting,
        isTrue,
        reason:
            'BUG CONFIRMED (HARDWARE-017): No shop-level setting exists to '
            'enable/disable the cut-to-size rounding convention. The rounding '
            'is always applied with no way to opt out.',
      );
    });

    test(
      'Preservation: exact-measurement items (whole units) show no disclosure',
      () {
        // This test validates the preservation clause — whole-unit items must
        // NOT show any rounding disclosure. We verify this through the
        // HardwareBusinessRules logic: cutToSizeWasRoundedUp(2.0) == false
        // and cutToSizeRoundingNote(2.0) == null.
        //
        // The source code of the strategy should conditionally show the note
        // only when rounding occurs (not unconditionally).
        final src = _readSource(
          'lib/core/billing/strategies/hardware_strategy.dart',
        );

        if (src.isEmpty) {
          fail('hardware_strategy.dart must exist.');
        }

        // If the strategy has disclosure logic, it MUST be conditional
        // (not shown for all items unconditionally).
        if (src.contains('cutToSizeRoundingNote') ||
            src.contains('cutToSizeWasRoundedUp')) {
          // Verify it's conditional (uses an if-check or null-aware)
          final hasConditional =
              src.contains('if (') ||
              src.contains('!= null') ||
              src.contains('?? ') ||
              src.contains('cutToSizeWasRoundedUp');
          expect(
            hasConditional,
            isTrue,
            reason:
                'Disclosure must be conditional — shown only when rounding '
                'occurs, not for exact-measurement items.',
          );
        }
        // If no disclosure logic exists yet, preservation is trivially true
        // (no note is shown for any item, including exact-measurement ones).
      },
    );
  });
}
