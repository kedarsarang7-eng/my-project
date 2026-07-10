// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition: navigation.patientManagementOrphaned (Requirement 1.5)
//
// PatientManagementScreen (lib/features/clinic/presentation/screens/
// patient_management_screen.dart) is a fully working archive/undo-restore flow
// (ClinicRepository.deletePatient/restorePatient, DeleteConfirmationDialog,
// SnackBarAction(label: 'UNDO', ...)) that NO user can ever open. There is:
//   - No sidebar item id 'patient_management' in _getClinicSections()
//   - No case 'patient_management' in SidebarNavigationHandler
//
// This test asserts the POSITIVE expectation: that at least one sidebar item id
// in the clinic domain resolves to PatientManagementScreen via the navigation
// handler. On UNFIXED code this FAILS because zero ids resolve to it — the
// screen is completely orphaned / unreachable.
//
// **Validates: Requirements 1.5**
//
// COUNTEREXAMPLE (documented after first run):
// PatientManagementScreen has zero reachable sidebar id in _getClinicSections();
// archive/undo-restore workflow is completely inaccessible. Neither
// sidebar_configuration.dart contains an item id 'patient_management', nor does
// sidebar_navigation_handler.dart contain any case resolving to
// PatientManagementScreen.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bug Condition 1.5 — navigation.patientManagementOrphaned', () {
    late String sidebarConfigSource;
    late String navigationHandlerSource;
    late String clinicSectionsBody;

    setUpAll(() {
      // Read sidebar configuration source
      final configFile = File('lib/widgets/desktop/sidebar_configuration.dart');
      expect(
        configFile.existsSync(),
        isTrue,
        reason: 'sidebar_configuration.dart must exist',
      );
      sidebarConfigSource = configFile.readAsStringSync();

      // Read sidebar navigation handler source
      final handlerFile = File(
        'lib/widgets/desktop/sidebar_navigation_handler.dart',
      );
      expect(
        handlerFile.existsSync(),
        isTrue,
        reason: 'sidebar_navigation_handler.dart must exist',
      );
      navigationHandlerSource = handlerFile.readAsStringSync();

      // Locate _getClinicSections() function DEFINITION
      final defPattern = '_getClinicSections() {';
      final methodIdx = sidebarConfigSource.indexOf(defPattern);
      expect(
        methodIdx,
        isNot(-1),
        reason:
            '_getClinicSections() function definition must exist in '
            'sidebar_configuration.dart',
      );

      // Extract the function body
      final blockStart = sidebarConfigSource.indexOf('{', methodIdx);
      expect(
        blockStart,
        isNot(-1),
        reason: '_getClinicSections() must have a body block',
      );

      int depth = 0;
      int blockEnd = -1;
      for (int i = blockStart; i < sidebarConfigSource.length; i++) {
        if (sidebarConfigSource[i] == '{') depth++;
        if (sidebarConfigSource[i] == '}') {
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

      clinicSectionsBody = sidebarConfigSource.substring(blockStart, blockEnd);
    });

    /// Extracts ALL item ids from the _getClinicSections() body.
    List<String> _extractAllClinicItemIds() {
      final ids = <String>[];
      final idPattern = RegExp(r"id:\s*'([^']+)'");
      for (final match in idPattern.allMatches(clinicSectionsBody)) {
        ids.add(match.group(1)!);
      }
      return ids;
    }

    // =========================================================================
    // Sub-Test 1: Verify PatientManagementScreen file exists (it's a real,
    // built screen — confirming the orphaning is not due to absence).
    // This PASSES on both unfixed and fixed code.
    // =========================================================================
    test('PatientManagementScreen source file exists', () {
      final screenFile = File(
        'lib/features/clinic/presentation/screens/patient_management_screen.dart',
      );
      expect(
        screenFile.existsSync(),
        isTrue,
        reason:
            'PatientManagementScreen source file must exist — the screen is '
            'built but orphaned (no sidebar entry or navigation case resolves '
            'to it)',
      );
    });

    // =========================================================================
    // Sub-Test 2: Verify _getClinicSections() contains a 'patient_management'
    // item id.
    // On UNFIXED code this FAILS — no such item exists.
    // =========================================================================
    test('_getClinicSections() contains patient_management item id', () {
      final allIds = _extractAllClinicItemIds();

      expect(
        allIds,
        isNotEmpty,
        reason: '_getClinicSections() must define at least one item id',
      );

      final hasPatientManagementId = allIds.contains('patient_management');

      expect(
        hasPatientManagementId,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.5): PatientManagementScreen has zero reachable '
            'sidebar id in _getClinicSections().\n\n'
            'All clinic sidebar item ids found: $allIds\n\n'
            'None of these is "patient_management". The archive/undo-restore '
            'workflow provided by PatientManagementScreen is completely '
            'inaccessible from the clinic sidebar.\n\n'
            'Expected: a SidebarMenuItem(id: \'patient_management\', ...) in '
            'the "Patient Management" section of _getClinicSections().',
      );
    });

    // =========================================================================
    // Sub-Test 3: SidebarNavigationHandler contains a case resolving to
    // PatientManagementScreen.
    // On UNFIXED code this FAILS — no such case exists.
    // =========================================================================
    test(
      'SidebarNavigationHandler has a case resolving to PatientManagementScreen',
      () {
        // Check if the navigation handler source contains any reference to
        // PatientManagementScreen (either as a case return or an import).
        final hasPatientManagementScreenRef = navigationHandlerSource.contains(
          'PatientManagementScreen',
        );

        expect(
          hasPatientManagementScreenRef,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.5): SidebarNavigationHandler has zero cases '
              'that resolve to PatientManagementScreen.\n\n'
              'The file sidebar_navigation_handler.dart does not contain any '
              'reference to "PatientManagementScreen" — neither as an import '
              'nor as a return value in tryGetScreenForItem().\n\n'
              'PatientManagementScreen exists at:\n'
              '  lib/features/clinic/presentation/screens/'
              'patient_management_screen.dart\n\n'
              'But no sidebar item id maps to it, making the screen\'s '
              'archive/undo-restore workflow completely unreachable through '
              'normal navigation.',
        );
      },
    );

    // =========================================================================
    // Sub-Test 4 (composite): At least one clinic sidebar id resolves to
    // PatientManagementScreen in the navigation handler.
    // On UNFIXED code this FAILS — confirms the full "orphaned" condition.
    // =========================================================================
    test(
      'at least one clinic sidebar id resolves to PatientManagementScreen',
      () {
        final allIds = _extractAllClinicItemIds();

        // For each clinic item id, check if the navigation handler has a
        // `case '<id>':` that eventually references PatientManagementScreen.
        bool anyIdResolvesToPatientManagementScreen = false;

        for (final id in allIds) {
          // Find the case for this id in the handler
          final casePattern = "case '$id':";
          final caseIdx = navigationHandlerSource.indexOf(casePattern);
          if (caseIdx == -1) continue;

          // Look at the next ~500 chars after the case statement for the return
          final caseSlice = navigationHandlerSource.substring(
            caseIdx,
            (caseIdx + 500).clamp(0, navigationHandlerSource.length),
          );

          // Check if this case returns PatientManagementScreen before the next
          // case or default
          final nextCaseIdx = caseSlice.indexOf("case '", 1);
          final relevantSlice = nextCaseIdx > 0
              ? caseSlice.substring(0, nextCaseIdx)
              : caseSlice;

          if (relevantSlice.contains('PatientManagementScreen')) {
            anyIdResolvesToPatientManagementScreen = true;
            break;
          }
        }

        expect(
          anyIdResolvesToPatientManagementScreen,
          isTrue,
          reason:
              'COUNTEREXAMPLE (1.5): PatientManagementScreen has zero '
              'reachable sidebar id; archive/undo-restore workflow is '
              'completely inaccessible.\n\n'
              'Enumerated all ${allIds.length} clinic sidebar item ids from '
              '_getClinicSections(): $allIds\n\n'
              'For each id, checked SidebarNavigationHandler.tryGetScreenForItem '
              'cases — NONE resolves to PatientManagementScreen.\n\n'
              'The screen at lib/features/clinic/presentation/screens/'
              'patient_management_screen.dart exists with a fully working '
              'archive (soft-delete) + undo-restore flow, but no navigation '
              'path reaches it.',
        );
      },
    );
  });
}
