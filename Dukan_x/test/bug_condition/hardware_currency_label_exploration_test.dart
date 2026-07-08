/// Bug Condition Exploration Test — HARDWARE-007 Currency Label
///
/// **Validates: Requirements 1.7, 2.7**
///
/// Property 7: Bug Condition — Record Payment dialog renders ₹ via shared formatter
///
/// This test asserts that the Record Payment dialog in the Hardware Supplier
/// Management Screen uses the shared ₹ currency symbol rather than the
/// hardcoded 'Amount (Rs)' label.
///
/// On UNFIXED code this test FAILS — the label contains 'Rs' instead of '₹'.
/// After the fix (Task 3.7) this same test PASSES.
///
/// Run: flutter test test/bug_condition/hardware_currency_label_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads the shipping source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // HARDWARE-007 / 1.7 / 2.7 — Currency label in Record Payment dialog
  //
  // Expected (post-fix): the TextField label in _showRecordPaymentDialog
  // uses the ₹ symbol (via the shared _currency formatter or inline '₹')
  // instead of the hardcoded 'Amount (Rs)' string.
  //
  // Bug condition: the label text contains 'Rs' — an outdated/informal
  // currency abbreviation that doesn't match the rest of the app's ₹ usage.
  // ===========================================================================
  group('Bug Condition 1.7 — currency label in Record Payment dialog', () {
    test('Record Payment dialog label uses ₹ symbol, not hardcoded Rs', () {
      final src = _readSource(
        'lib/features/hardware/presentation/screens/'
        'hardware_supplier_management_screen.dart',
      );

      expect(
        src.isNotEmpty,
        isTrue,
        reason:
            'hardware_supplier_management_screen.dart must exist to verify '
            'the currency label.',
      );

      // Find the _showRecordPaymentDialog method body.
      // Find the _showRecordPaymentDialog method definition (not call site).
      final methodStart = src.indexOf('Future<void> _showRecordPaymentDialog');
      expect(
        methodStart,
        isNot(-1),
        reason: '_showRecordPaymentDialog method must exist in the source.',
      );

      // Extract a generous slice after the method start to cover the dialog.
      final slice = src.substring(
        methodStart,
        (methodStart + 3000).clamp(0, src.length),
      );

      // The label MUST contain the ₹ symbol (shared formatter output).
      expect(
        slice.contains('\u20B9'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.7): the Record Payment dialog label does NOT '
            'contain the \u20B9 symbol. It uses the hardcoded "Amount (Rs)" '
            'string, which is inconsistent with the rest of the app.',
      );

      // The label MUST NOT contain the outdated 'Rs' abbreviation
      // in the Amount field labelText.
      final hasHardcodedRs = slice.contains('Amount (Rs)');
      expect(
        hasHardcodedRs,
        isFalse,
        reason:
            'COUNTEREXAMPLE (1.7): the Record Payment dialog still uses '
            '"Amount (Rs)" in the labelText. Expected the \u20B9 symbol via '
            'the shared currency formatter.',
      );
    });

    test('Preservation: other amount displays in the file use ₹ formatter', () {
      final src = _readSource(
        'lib/features/hardware/presentation/screens/'
        'hardware_supplier_management_screen.dart',
      );

      // The file has a _currency field using NumberFormat.currency(symbol: '₹')
      // which is used for KPI cards, ledger amounts, etc. Those must remain.
      expect(
        src.contains("symbol: '\u20B9'"),
        isTrue,
        reason:
            'The shared _currency formatter with \u20B9 symbol must still be '
            'present in the file for other amount displays.',
      );

      // _currency.format is used in multiple places — confirm it still exists.
      expect(
        src.contains('_currency.format'),
        isTrue,
        reason:
            'Other amount displays using _currency.format must remain '
            'unchanged after the fix.',
      );
    });
  });
}
