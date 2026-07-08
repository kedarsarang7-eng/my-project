/// Bug Condition Exploration Test — HARDWARE-016 Barcode Scan Actions
///
/// **Validates: Requirements 1.16, 2.16**
///
/// Property 15: Bug Condition — Contextual barcode-scan actions for
/// Projects/Deposits tabs.
///
/// On the Deposits tab, scanning a barcode should offer an "Add to Deposit"
/// action (pre-filling item type from the scanned product). On the Projects
/// tab, scanning should offer a "Create Indent for Project" action.
///
/// Bug Condition: `isBugCondition(input)` where
///   `input.surface == 'operations.barcodeScan'` and
///   `tab in {projects, deposits}`
///
/// BEFORE fix: the barcode-scan dialog shows only an informational dialog on
/// Projects and Deposits tabs — no contextual action is offered. The "Add to
/// Indent" button only appears on the Indents tab (index == 1).
///
/// AFTER fix: the dialog offers "Create Indent for Project" on the Projects tab
/// and "Add to Deposit" on the Deposits tab.
///
/// Preservation: existing "Add to Indent" action on the Indents tab unchanged.
///
/// Run: flutter test test/bug_condition/hardware_barcode_scan_actions_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the project root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // HARDWARE-016 / 1.16 / 2.16 — Contextual barcode-scan actions
  //
  // The _scanProductBarcode() method's result dialog must offer:
  //   - Tab 0 (Projects): "Create Indent for Project" action
  //   - Tab 1 (Indents): "Add to Indent" action (existing, preservation)
  //   - Tab 2 (Deposits): "Add to Deposit" action
  //
  // Bug condition: only tab index == 1 has an action; tabs 0 and 2 show
  // a purely informational dialog with only "OK".
  // ===========================================================================
  group('Bug Condition HARDWARE-016 — barcode scan contextual actions', () {
    final src = _readSource(
      'lib/features/hardware/presentation/screens/'
      'hardware_operations_screen.dart',
    );

    test('source file exists', () {
      expect(
        src.isNotEmpty,
        isTrue,
        reason:
            'hardware_operations_screen.dart must exist to verify barcode '
            'scan actions.',
      );
    });

    test('_scanProductBarcode method exists', () {
      expect(
        src.contains('_scanProductBarcode'),
        isTrue,
        reason: '_scanProductBarcode method must exist in the source.',
      );
    });

    // =========================================================================
    // Bug Condition: Deposits tab offers "Add to Deposit" action
    // =========================================================================
    test('Deposits tab (index 2) offers "Add to Deposit" action', () {
      // The barcode scan result dialog must contain an action for deposits.
      // We look for a condition checking _tabController.index == 2 paired
      // with an 'Add to Deposit' button text.
      final hasDepositsAction = src.contains('Add to Deposit');

      expect(
        hasDepositsAction,
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-016): Scanning a barcode on the '
            'Deposits tab (index 2) does NOT offer an "Add to Deposit" action. '
            'The dialog is informational only with no contextual action. '
            'Fix: add an "Add to Deposit" button when _tabController.index == 2.',
      );
    });

    test('Deposits action is gated on tab index 2', () {
      // The 'Add to Deposit' text must be conditional on the tab being 2
      // (Deposits tab). Find the pattern near tab index check.
      final methodStart = src.indexOf('Future<void> _scanProductBarcode');
      expect(methodStart, isNot(-1));

      // Extract the scan method body (generous slice to cover entire method).
      final methodSlice = src.substring(
        methodStart,
        (methodStart + 8000).clamp(0, src.length),
      );

      // Check for tab index 2 condition near 'Add to Deposit'
      final hasTabCheck =
          methodSlice.contains('_tabController.index == 2') &&
          methodSlice.contains('Add to Deposit');

      expect(
        hasTabCheck,
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-016): The "Add to Deposit" action is '
            'not conditional on _tabController.index == 2. Fix: gate the '
            'action behind the Deposits tab check.',
      );
    });

    // =========================================================================
    // Bug Condition: Projects tab offers "Create Indent for Project" action
    // =========================================================================
    test(
      'Projects tab (index 0) offers "Create Indent for Project" action',
      () {
        final hasProjectsAction = src.contains('Create Indent for Project');

        expect(
          hasProjectsAction,
          isTrue,
          reason:
              'COUNTEREXAMPLE (HARDWARE-016): Scanning a barcode on the '
              'Projects tab (index 0) does NOT offer a "Create Indent for '
              'Project" action. The dialog is informational only. '
              'Fix: add a "Create Indent for Project" button when '
              '_tabController.index == 0.',
        );
      },
    );

    test('Projects action is gated on tab index 0', () {
      final methodStart = src.indexOf('Future<void> _scanProductBarcode');
      expect(methodStart, isNot(-1));

      final methodSlice = src.substring(
        methodStart,
        (methodStart + 8000).clamp(0, src.length),
      );

      // Check for tab index 0 condition near 'Create Indent for Project'
      final hasTabCheck =
          methodSlice.contains('_tabController.index == 0') &&
          methodSlice.contains('Create Indent for Project');

      expect(
        hasTabCheck,
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-016): The "Create Indent for Project" '
            'action is not conditional on _tabController.index == 0. Fix: '
            'gate the action behind the Projects tab check.',
      );
    });

    // =========================================================================
    // Bug Condition: _showCreateDepositDialog accepts prefill parameter
    // =========================================================================
    test('_showCreateDepositDialog accepts prefillItemType parameter', () {
      // The deposit dialog must accept a pre-fill parameter so the scanned
      // product's type can be pre-populated.
      final hasParam = src.contains('prefillItemType');

      expect(
        hasParam,
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-016): _showCreateDepositDialog does NOT '
            'accept a prefillItemType parameter. The "Add to Deposit" action '
            'cannot pre-fill the item type from the scanned product. '
            'Fix: add {String? prefillItemType} parameter.',
      );
    });

    // =========================================================================
    // Preservation: "Add to Indent" on Indents tab unchanged
    // =========================================================================
    group('Preservation — Add to Indent on Indents tab', () {
      test('Indents tab (index 1) still offers "Add to Indent" action', () {
        final methodStart = src.indexOf('Future<void> _scanProductBarcode');
        expect(methodStart, isNot(-1));

        final methodSlice = src.substring(
          methodStart,
          (methodStart + 8000).clamp(0, src.length),
        );

        final hasIndentsAction =
            methodSlice.contains('_tabController.index == 1') &&
            methodSlice.contains('Add to Indent');

        expect(
          hasIndentsAction,
          isTrue,
          reason:
              'PRESERVATION FAILURE: The "Add to Indent" action on the '
              'Indents tab (index 1) must remain unchanged.',
        );
      });

      test('_showCreateIndentDialog still accepts prefillProductName', () {
        final hasParam = src.contains('prefillProductName');

        expect(
          hasParam,
          isTrue,
          reason:
              'PRESERVATION FAILURE: _showCreateIndentDialog must still '
              'accept the prefillProductName parameter for barcode pre-fill.',
        );
      });
    });
  });
}
