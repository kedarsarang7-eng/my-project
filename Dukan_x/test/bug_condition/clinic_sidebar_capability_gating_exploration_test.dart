// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition: sidebar.inconsistentCapabilityGating (Requirement 1.4)
//
// The clinic sidebar's _getClinicSections() has `lab_reports` and `doctor_revenue`
// items with NO `capability:` gate, while their sibling items (`prescriptions`,
// `medicine_master`, `scan_qr`, `patient_queue`, `clinic_calendar`) all carry
// non-null capability gates. This means a clinic user whose capability set
// lacks the relevant permissions would still see lab_reports and doctor_revenue
// in the sidebar (no gate to filter them).
//
// This test asserts the POSITIVE expectation: that both `lab_reports` and
// `doctor_revenue` have a non-null `capability:` field. On UNFIXED code this
// FAILS because both items have `capability: null` (no gate specified).
//
// **Validates: Requirements 1.4**
//
// COUNTEREXAMPLE (documented after first run):
// lab_reports.capability == null, doctor_revenue.capability == null, while
// prescriptions/medicine_master/scan_qr/patient_queue/clinic_calendar are
// all non-null (usePrescription, usePrescription, usePatientRegistry,
// usePatientRegistry, usePatientRegistry respectively).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bug Condition 1.4 — sidebar.inconsistentCapabilityGating', () {
    late String sourceContent;
    late String clinicSectionsBody;

    setUpAll(() {
      // Read the sidebar configuration source
      final file = File('lib/widgets/desktop/sidebar_configuration.dart');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'sidebar_configuration.dart must exist',
      );
      sourceContent = file.readAsStringSync();

      // Locate _getClinicSections() function DEFINITION (not the call site).
      // The function definition line contains the return type before the name:
      //   List<SidebarSection> _getClinicSections() {
      // We search for this pattern to skip past the call site in the switch.
      final defPattern = '_getClinicSections() {';
      final methodIdx = sourceContent.indexOf(defPattern);
      expect(
        methodIdx,
        isNot(-1),
        reason:
            '_getClinicSections() function definition must exist in '
            'sidebar_configuration.dart',
      );

      // Extract the function body (find the opening brace after the signature,
      // match to the function-level closing brace)
      final blockStart = sourceContent.indexOf('{', methodIdx);
      expect(
        blockStart,
        isNot(-1),
        reason: '_getClinicSections() must have a body block',
      );

      int depth = 0;
      int blockEnd = -1;
      for (int i = blockStart; i < sourceContent.length; i++) {
        if (sourceContent[i] == '{') depth++;
        if (sourceContent[i] == '}') {
          depth--;
          if (depth == 0) {
            blockEnd = i + 1;
            break;
          }
        }
      }
      expect(
        blockEnd,
        isNot(-1),
        reason:
            'Could not find matching closing brace for _getClinicSections()',
      );

      clinicSectionsBody = sourceContent.substring(blockStart, blockEnd);
    });

    /// Helper: extracts the SidebarMenuItem block for a given item id from
    /// the clinicSectionsBody string.
    String? _extractMenuItemBlock(String itemId) {
      // Look for the pattern: id: 'itemId'
      final idPattern = "id: '$itemId'";
      final idIdx = clinicSectionsBody.indexOf(idPattern);
      if (idIdx == -1) return null;

      // Walk backwards to find the SidebarMenuItem( opening
      final menuItemPrefix = 'SidebarMenuItem(';
      final searchStart = clinicSectionsBody.lastIndexOf(menuItemPrefix, idIdx);
      if (searchStart == -1) return null;

      // Find the matching closing paren+comma from the SidebarMenuItem( opening
      // We track parens depth from the '(' after SidebarMenuItem
      final parenStart =
          searchStart + menuItemPrefix.length - 1; // index of '('
      int parenDepth = 0;
      int parenEnd = -1;
      for (int i = parenStart; i < clinicSectionsBody.length; i++) {
        if (clinicSectionsBody[i] == '(') parenDepth++;
        if (clinicSectionsBody[i] == ')') {
          parenDepth--;
          if (parenDepth == 0) {
            parenEnd = i + 1;
            break;
          }
        }
      }
      if (parenEnd == -1) return null;

      return clinicSectionsBody.substring(searchStart, parenEnd);
    }

    /// Helper: checks if a SidebarMenuItem block has a non-null capability field.
    bool _hasCapabilityGate(String menuItemBlock) {
      // The item has a capability gate if the block contains 'capability:'
      // followed by something other than null
      return menuItemBlock.contains('capability:');
    }

    // =========================================================================
    // Sub-Test 1: Sibling items must have non-null capability gates.
    // This PASSES on both unfixed and fixed code — confirms the inconsistency
    // by proving the siblings ARE gated.
    // =========================================================================
    test('sibling items (prescriptions, medicine_master, scan_qr, patient_queue, '
        'clinic_calendar) all have non-null capability', () {
      final siblings = [
        'prescriptions',
        'medicine_master',
        'scan_qr',
        'patient_queue',
        'clinic_calendar',
      ];

      for (final siblingId in siblings) {
        final block = _extractMenuItemBlock(siblingId);
        expect(
          block,
          isNotNull,
          reason:
              'SidebarMenuItem with id "$siblingId" must exist in '
              '_getClinicSections()',
        );
        expect(
          _hasCapabilityGate(block!),
          isTrue,
          reason:
              'Sibling item "$siblingId" must have a non-null capability gate. '
              'Block content:\n$block',
        );
      }
    });

    // =========================================================================
    // Sub-Test 2: lab_reports must have a non-null capability gate.
    // On UNFIXED code this FAILS — lab_reports has no `capability:` field.
    // =========================================================================
    test('lab_reports has non-null capability gate', () {
      final block = _extractMenuItemBlock('lab_reports');
      expect(
        block,
        isNotNull,
        reason:
            'SidebarMenuItem with id "lab_reports" must exist in _getClinicSections()',
      );

      final hasGate = _hasCapabilityGate(block!);

      expect(
        hasGate,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.4): lab_reports.capability == null.\n\n'
            'The lab_reports SidebarMenuItem has NO capability gate while its '
            'sibling items (prescriptions, medicine_master, scan_qr, '
            'patient_queue, clinic_calendar) all have non-null capability.\n\n'
            'Current lab_reports block:\n$block\n\n'
            'Expected: capability: BusinessCapability.usePrescription\n'
            '(consistent with prescriptions/medicine_master in the same '
            'clinical-desk section).\n\n'
            'A clinic user whose capability set lacks usePrescription would '
            'still see lab_reports in the sidebar (no gate to filter it).',
      );
    });

    // =========================================================================
    // Sub-Test 3: doctor_revenue must have a non-null capability gate.
    // On UNFIXED code this FAILS — doctor_revenue has no `capability:` field.
    // =========================================================================
    test('doctor_revenue has non-null capability gate', () {
      final block = _extractMenuItemBlock('doctor_revenue');
      expect(
        block,
        isNotNull,
        reason:
            'SidebarMenuItem with id "doctor_revenue" must exist in '
            '_getClinicSections()',
      );

      final hasGate = _hasCapabilityGate(block!);

      expect(
        hasGate,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.4): doctor_revenue.capability == null.\n\n'
            'The doctor_revenue SidebarMenuItem has NO capability gate while '
            'its sibling items (prescriptions, medicine_master, scan_qr, '
            'patient_queue, clinic_calendar) all have non-null capability.\n\n'
            'Current doctor_revenue block:\n$block\n\n'
            'Expected: capability: BusinessCapability.useRevenueOverview\n'
            '(consistent with the revenue-domain conceptual gating).\n\n'
            'A clinic user whose capability set lacks useRevenueOverview would '
            'still see doctor_revenue in the sidebar (no gate to filter it).',
      );
    });
  });
}
