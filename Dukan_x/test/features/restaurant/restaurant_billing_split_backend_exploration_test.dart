// ============================================================================
// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition: split-bill dialog never calls the backend (Property 9)
//
// `_showSplitBillDialog()` in `bill_creation_screen_v2.dart` computes split
// amounts client-side via `RestaurantBusinessRules.splitBill(...)` and displays
// them informally in a dialog. It NEVER persists the split by calling
// `RestaurantOpsRepository.splitBill(...)` or hitting the backend endpoint
// `/resto/bills/{id}/split`.
//
// Meanwhile, `restaurant_table_ops_screen.dart` DOES call the backend endpoint
// via `_repo.splitBill(...)` — proving the endpoint works and is implemented,
// just not wired into the bill-creation flow.
//
// This test asserts the POSITIVE expectation: that `_showSplitBillDialog` in
// `bill_creation_screen_v2.dart` calls the backend to persist split-bill data.
// On UNFIXED code this FAILS because the dialog is informational-only (comment
// literally says "Informational only — does not create separate bills").
//
// **Validates: Requirements 2.9, 2.14**
//
// COUNTEREXAMPLE (documented after first run):
// `_showSplitBillDialog()` in bill_creation_screen_v2.dart calls
// `RestaurantBusinessRules.splitBill(...)` for CLIENT-SIDE computation only,
// displays the result in a dialog with a "Close" button, and NEVER calls
// `RestaurantOpsRepository.splitBill(...)` or any HTTP endpoint. The backend
// `/resto/bills/{id}/split` is only called from restaurant_table_ops_screen.dart
// — never from the bill-creation split action.
// ============================================================================
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bug Condition Property 9 — split-bill dialog never calls the backend', () {
    late String billCreationSource;
    late String tableOpsSource;
    late String splitBillDialogBody;

    setUpAll(() {
      // Read bill_creation_screen_v2.dart source
      final billFile = File(
        'lib/features/billing/presentation/screens/bill_creation_screen_v2.dart',
      );
      expect(
        billFile.existsSync(),
        isTrue,
        reason: 'bill_creation_screen_v2.dart must exist',
      );
      billCreationSource = billFile.readAsStringSync();

      // Read restaurant_table_ops_screen.dart source
      final tableOpsFile = File(
        'lib/features/restaurant/presentation/screens/restaurant_table_ops_screen.dart',
      );
      expect(
        tableOpsFile.existsSync(),
        isTrue,
        reason: 'restaurant_table_ops_screen.dart must exist',
      );
      tableOpsSource = tableOpsFile.readAsStringSync();

      // Extract the _showSplitBillDialog method body
      final methodDef = '_showSplitBillDialog()';
      final methodIdx = billCreationSource.indexOf(methodDef);
      expect(
        methodIdx,
        isNot(-1),
        reason:
            '_showSplitBillDialog() must exist in bill_creation_screen_v2.dart',
      );

      // Find the opening brace of the method body
      final blockStart = billCreationSource.indexOf('{', methodIdx);
      expect(
        blockStart,
        isNot(-1),
        reason: '_showSplitBillDialog() must have a body block',
      );

      // Walk braces to find the matching close
      int depth = 0;
      int blockEnd = -1;
      for (int i = blockStart; i < billCreationSource.length; i++) {
        if (billCreationSource[i] == '{') depth++;
        if (billCreationSource[i] == '}') {
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
            'Could not find matching closing brace for _showSplitBillDialog()',
      );

      splitBillDialogBody = billCreationSource.substring(blockStart, blockEnd);
    });

    // =========================================================================
    // Sub-Test 1: Confirm _showSplitBillDialog uses client-side splitBill.
    // This PASSES on both unfixed and fixed code (the client-side computation
    // should always exist for displaying amounts).
    // =========================================================================
    test(
      '_showSplitBillDialog calls RestaurantBusinessRules.splitBill (client-side)',
      () {
        final usesClientSideSplit = splitBillDialogBody.contains(
          'RestaurantBusinessRules.splitBill',
        );

        expect(
          usesClientSideSplit,
          isTrue,
          reason:
              '_showSplitBillDialog must call RestaurantBusinessRules.splitBill '
              'for client-side amount computation',
        );
      },
    );

    // =========================================================================
    // Sub-Test 2: Confirm restaurant_table_ops_screen.dart calls the backend
    // splitBill endpoint — proving the repository method works and is reachable
    // from at least one screen.
    // This PASSES on both unfixed and fixed code.
    // =========================================================================
    test(
      'restaurant_table_ops_screen.dart calls _repo.splitBill (backend)',
      () {
        // The table ops screen calls _repo.splitBill(...) which hits the
        // PUT /resto/bills/{id}/split endpoint
        final callsBackendSplit =
            tableOpsSource.contains('.splitBill(') ||
            tableOpsSource.contains('splitBill(');

        expect(
          callsBackendSplit,
          isTrue,
          reason:
              'restaurant_table_ops_screen.dart must call '
              'RestaurantOpsRepository.splitBill(...) — this proves the '
              'backend endpoint works, it is just not wired into the bill '
              'creation flow',
        );
      },
    );

    // =========================================================================
    // Sub-Test 3: Assert _showSplitBillDialog calls the backend to persist
    // the split.
    // On UNFIXED code this FAILS — the dialog is purely informational and
    // never calls RestaurantOpsRepository.splitBill or any API endpoint.
    // =========================================================================
    test(
      '_showSplitBillDialog persists split via RestaurantOpsRepository.splitBill',
      () {
        // Check for any reference to repository splitBill call in the dialog
        final callsRepoSplitBill =
            splitBillDialogBody.contains('RestaurantOpsRepository') ||
            splitBillDialogBody.contains('_restaurantOpsRepository') ||
            splitBillDialogBody.contains('_restoOpsRepo') ||
            splitBillDialogBody.contains('restoOps') ||
            splitBillDialogBody.contains("splitBill(") &&
                !splitBillDialogBody.contains(
                  'RestaurantBusinessRules.splitBill',
                );

        // Also check for direct API path reference
        final callsApiEndpoint =
            splitBillDialogBody.contains('/resto/bills') ||
            splitBillDialogBody.contains('/split');

        // Also check if there's any await or async call that could be a
        // backend persistence call (beyond the client-side computation)
        final hasBackendPersistenceCall =
            callsRepoSplitBill || callsApiEndpoint;

        expect(
          hasBackendPersistenceCall,
          isTrue,
          reason:
              'COUNTEREXAMPLE (Property 9 / Req 2.9, 2.14): '
              '_showSplitBillDialog() in bill_creation_screen_v2.dart '
              'NEVER calls RestaurantOpsRepository.splitBill(...) or any '
              'backend endpoint.\n\n'
              'The method calls RestaurantBusinessRules.splitBill(...) for '
              'CLIENT-SIDE amount computation only, displays per-guest amounts '
              'in a dialog, and provides only a "Close" button — no "Confirm" '
              'or "Save" action that persists the split server-side.\n\n'
              'The dialog\'s own doc comment confirms: "Informational only — '
              'does not create separate bills."\n\n'
              'Meanwhile, restaurant_table_ops_screen.dart DOES call:\n'
              '  await _repo.splitBill(\n'
              '    billId: billId.text.trim(),\n'
              '    mode: \'equal\',\n'
              '    peopleCount: int.tryParse(people.text) ?? 2,\n'
              '  );\n\n'
              'This proves the backend endpoint (PUT /resto/bills/{id}/split) '
              'is implemented and functional — it is simply never invoked from '
              'the bill-creation split-bill action.\n\n'
              'Expected: _showSplitBillDialog should call '
              'RestaurantOpsRepository.splitBill(...) to persist the split '
              'on the backend after the user confirms.',
        );
      },
    );

    // =========================================================================
    // Sub-Test 4: Assert that bill_creation_screen_v2.dart imports or
    // references RestaurantOpsRepository at all (for the split-bill flow).
    // On UNFIXED code this FAILS — no import or reference exists.
    // =========================================================================
    test(
      'bill_creation_screen_v2.dart references RestaurantOpsRepository for split-bill',
      () {
        // Check if the file even imports RestaurantOpsRepository
        final importsRestoRepo = billCreationSource.contains(
          'restaurant_ops_repository',
        );
        final referencesRestoRepo = billCreationSource.contains(
          'RestaurantOpsRepository',
        );

        final hasRestoRepoReference = importsRestoRepo || referencesRestoRepo;

        expect(
          hasRestoRepoReference,
          isTrue,
          reason:
              'COUNTEREXAMPLE (Property 9 / Req 2.14): '
              'bill_creation_screen_v2.dart does NOT import or reference '
              'RestaurantOpsRepository at all.\n\n'
              'The file has no import for restaurant_ops_repository.dart and '
              'no usage of RestaurantOpsRepository anywhere in its source.\n\n'
              'This means the split-bill backend endpoint '
              '(PUT /resto/bills/{id}/split) is structurally unreachable from '
              'the bill-creation screen — there is no code path that could '
              'possibly call it.\n\n'
              'Expected: bill_creation_screen_v2.dart should import and use '
              'RestaurantOpsRepository to persist split-bill data when the '
              'user confirms the split action.',
        );
      },
    );
  });
}
