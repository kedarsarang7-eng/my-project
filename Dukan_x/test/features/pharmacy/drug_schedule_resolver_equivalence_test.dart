// ============================================================================
// Feature: pharmacy-vertical-remediation — Task 2.4
// Example-based unit test: H/H1/X string-vs-enum equivalence.
// **Validates: Requirements 22.5**
// ============================================================================
//
// Requirement 22.5:
//   "THE System SHALL include a test verifying that schedule matching produces
//    identical results across the string representation and the enum
//    representation for each of the schedule values H, H1, and X."
//
// Where the companion property test (Property 22) exhaustively samples the
// reconciliation space across randomized casing/whitespace/separators, THIS
// test is the explicit, example-based proof mandated by Requirement 22.5: for
// each of H, H1, and X it pins concrete string spellings (plus a couple of
// casing / spacing variants) and asserts they resolve to the SAME canonical
// value as both legacy enums:
//
//     fromRaw("H"|"H1"|"X" + variants)
//       == fromBusinessRules(rules.DrugSchedule.<h|h1|x>)
//       == fromInventory(inventory.DrugSchedule.schedule<H|H1|X>)
//       == the expected CanonicalDrugSchedule.
//
// Run: flutter test test/features/pharmacy/drug_schedule_resolver_equivalence_test.dart
// ============================================================================

import 'package:dukanx/features/pharmacy/utils/drug_schedule_resolver.dart';
import 'package:dukanx/features/pharmacy/utils/pharmacy_business_rules.dart'
    as rules;
import 'package:dukanx/features/inventory/services/drug_schedule_service.dart'
    as inventory;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Requirement 22.5: H/H1/X string-vs-enum resolution equivalence', () {
    // Each entry: the canonical schedule, its two legacy enum forms, and a
    // set of string spellings (canonical + casing/spacing variants) that
    // must all resolve identically to it.
    void expectEquivalent({
      required String label,
      required CanonicalDrugSchedule expected,
      required rules.DrugSchedule rulesEnum,
      required inventory.DrugSchedule inventoryEnum,
      required List<String> strings,
    }) {
      final byRules = DrugScheduleResolver.fromBusinessRules(rulesEnum);
      final byInventory = DrugScheduleResolver.fromInventory(inventoryEnum);

      // Both enum representations resolve to the expected canonical value.
      expect(
        byRules,
        expected,
        reason: '$label: business-rules enum must resolve to $expected.',
      );
      expect(
        byInventory,
        expected,
        reason: '$label: inventory enum must resolve to $expected.',
      );

      // Every string spelling resolves to the same canonical value as the
      // two enums (and to the expected value).
      for (final raw in strings) {
        final byRaw = DrugScheduleResolver.fromRaw(raw);
        expect(
          byRaw,
          expected,
          reason: '$label: string "$raw" must resolve to $expected.',
        );
        expect(
          byRaw,
          byRules,
          reason:
              '$label: string "$raw" must resolve identically to the '
              'business-rules enum.',
        );
        expect(
          byRaw,
          byInventory,
          reason:
              '$label: string "$raw" must resolve identically to the '
              'inventory enum.',
        );
      }
    }

    test('Schedule H: string and enum representations resolve identically', () {
      expectEquivalent(
        label: 'Schedule H',
        expected: CanonicalDrugSchedule.scheduleH,
        rulesEnum: rules.DrugSchedule.h,
        inventoryEnum: inventory.DrugSchedule.scheduleH,
        strings: const ['H', 'h', ' H ', 'Schedule H', 'scheduleH'],
      );
    });

    test(
      'Schedule H1: string and enum representations resolve identically',
      () {
        expectEquivalent(
          label: 'Schedule H1',
          expected: CanonicalDrugSchedule.scheduleH1,
          rulesEnum: rules.DrugSchedule.h1,
          inventoryEnum: inventory.DrugSchedule.scheduleH1,
          strings: const ['H1', 'h1', ' H1 ', 'Schedule-H1', 'scheduleH1'],
        );
      },
    );

    test('Schedule X: string and enum representations resolve identically', () {
      expectEquivalent(
        label: 'Schedule X',
        expected: CanonicalDrugSchedule.scheduleX,
        rulesEnum: rules.DrugSchedule.x,
        inventoryEnum: inventory.DrugSchedule.scheduleX,
        strings: const ['X', 'x', ' X ', 'Schedule X', 'scheduleX'],
      );
    });
  });
}
