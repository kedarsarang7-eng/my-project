// ============================================================================
// PHASE 4 - Task 5.7 (4d): manual-entry defaults respect grocery config
// (go_router navigation migration - grocery functional fixes)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 5.7 - Manual-entry unit defaults from grocery `unitOptions`.
// Validates: Requirements 7.4
//
// PURPOSE (default-derivation test for the FIX - full preservation is 5.9):
//   The grocery manual-entry sheet must source its unit dropdown from grocery's
//   configured `unitOptions` (pcs, kg, gm, ltr, nos) so loose-weight units
//   (kg/gm) are selectable, defaulting to pcs. Non-grocery types must keep the
//   legacy fixed unit list (no regression). This pumps the self-contained
//   `ManualItemEntrySheet` (no Riverpod) and inspects the rendered dropdown.
// ============================================================================

import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/features/billing/presentation/widgets/manual_item_entry_sheet.dart';
import 'package:dukanx/models/bill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(BusinessType type) {
  return MaterialApp(
    home: Scaffold(
      body: ManualItemEntrySheet(
        businessType: type,
        onItemAdded: (BillItem _) {},
      ),
    ),
  );
}

/// Scrolls the unit dropdown into view and opens it (robust against the sheet
/// being taller than the test surface for types with extra fields).
Future<void> _openUnitDropdown(WidgetTester tester) async {
  final dropdown = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
}

void main() {
  group('Feature: gorouter-navigation-migration - Task 5.7 (4d) grocery '
      'manual-entry unit defaults (Req 7.4)', () {
    testWidgets('grocery unit dropdown is SOURCED from grocery unitOptions '
        '(kg & gm selectable, defaulting to pcs)', (tester) async {
      await tester.pumpWidget(_host(BusinessType.grocery));
      await tester.pumpAndSettle();

      // Default selected unit is the first grocery option (pcs).
      expect(find.text('pcs'), findsWidgets);

      await _openUnitDropdown(tester);

      expect(
        find.text('kg'),
        findsWidgets,
        reason: 'grocery unitOptions include kg - it must be selectable.',
      );
      expect(
        find.text('gm'),
        findsWidgets,
        reason: 'grocery unitOptions include gm (the config label, not "g").',
      );
      expect(
        find.text('ltr'),
        findsWidgets,
        reason: 'grocery unitOptions include ltr.',
      );
    });

    testWidgets('non-grocery (pharmacy) keeps the legacy unit list '
        '(no regression - legacy "g" present, grocery-only "gm" absent)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(BusinessType.pharmacy));
      await tester.pumpAndSettle();

      await _openUnitDropdown(tester);

      // The legacy fixed list uses the short label "g" (NOT the grocery config
      // label "gm"). Its presence proves pharmacy still uses the legacy list.
      expect(
        find.text('g'),
        findsWidgets,
        reason:
            'pharmacy keeps the legacy fixed unit list (contains "g"), '
            'proving non-grocery behavior is unchanged.',
      );
      expect(
        find.text('gm'),
        findsNothing,
        reason:
            'the grocery-only config label "gm" must NOT leak into the '
            'legacy list (the legacy list uses "g").',
      );
    });

    test('grocery config remains the source of truth for unit derivation', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.grocery);
      // The fix derives the default from the FIRST configured option.
      expect(config.unitOptions.first.label.toLowerCase(), 'pcs');
      expect(
        config.unitOptions.map((u) => u.label.toLowerCase()),
        containsAll(<String>['kg', 'gm', 'ltr', 'nos']),
      );
    });
  });
}
