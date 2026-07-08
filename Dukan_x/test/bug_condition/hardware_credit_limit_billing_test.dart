/// Bug Condition Exploration Test — Credit Limit Enforcement at Billing Time (HARDWARE-012)
///
/// **Validates: Requirements 1.12, 2.12**
///
/// Property 12: At invoice-creation time, if a party has a non-zero credit
/// limit and `outstandingBalance + newInvoiceAmount > creditLimit`, the sale
/// must be warned/blocked — not allowed silently.
///
/// Bug Condition: `isBugCondition(input)` where
///   `input.surface == 'billing.creditSale'` and `wouldExceedLimit == true`
///
/// BEFORE fix: Over-limit credit sales are allowed silently with no warning.
/// The billing screen (`BillCreationScreenV2`) has NO credit limit check at
/// all — the `_handleSave()` flow never queries the party's creditLimit or
/// outstandingBalance.
///
/// AFTER fix: A `CreditLimitValidator.check()` call is made before creating
/// the bill. If `exceedsLimit == true`, a warning dialog is shown. The user
/// can override (it's a warning, not a hard block).
///
/// Strategy:
///   1. Source-code probe: assert that `_handleSave()` in `BillCreationScreenV2`
///      references credit limit validation (the validator or the dialog).
///   2. Unit test: assert `CreditLimitValidator.check()` correctly detects
///      over-limit scenarios and allows no-limit/in-limit scenarios.
///   3. Preservation: `creditLimit == 0` (no limit) and within-limit sales
///      must NOT trigger any warning.
///
/// Run: flutter test test/bug_condition/hardware_credit_limit_billing_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/hardware/utils/credit_limit_validator.dart';

/// Reads a source file relative to the project root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  group('Bug Condition HARDWARE-012 — credit limit enforcement at billing', () {
    // =========================================================================
    // Source-code probe: billing screen references credit limit validation
    // =========================================================================
    group('Source-code integration probe', () {
      final billingSrc = _readSource(
        'lib/features/billing/presentation/screens/'
        'bill_creation_screen_v2.dart',
      );

      test(
        '_handleSave references CreditLimitValidator or credit limit check',
        () {
          // The fix requires the billing screen to check credit limits before
          // saving. Look for evidence of credit limit validation in the file.
          final hasCreditLimitCheck =
              billingSrc.contains('CreditLimitValidator') ||
              billingSrc.contains('creditLimit') ||
              billingSrc.contains('credit_limit_validator');

          expect(
            hasCreditLimitCheck,
            isTrue,
            reason:
                'COUNTEREXAMPLE (HARDWARE-012): BillCreationScreenV2 has NO '
                'credit limit validation. Over-limit credit sales are allowed '
                'silently. Fix: import CreditLimitValidator and call '
                'CreditLimitValidator.check() in _handleSave() before creating '
                'the bill, showing a warning dialog when exceedsLimit is true.',
          );
        },
      );

      test('billing screen imports credit_limit_validator.dart', () {
        final importsValidator =
            billingSrc.contains('credit_limit_validator') ||
            billingSrc.contains('CreditLimitValidator');

        expect(
          importsValidator,
          isTrue,
          reason:
              'COUNTEREXAMPLE (HARDWARE-012): BillCreationScreenV2 does not '
              'import the credit limit validator. The over-limit check cannot '
              'be performed without it.',
        );
      });

      test('billing screen shows a warning dialog for over-limit sales', () {
        // After the credit limit check, a dialog/warning must be shown.
        // Look for evidence of a credit-limit-specific dialog.
        final hasOverLimitDialog =
            billingSrc.contains('Credit Limit') ||
            billingSrc.contains('credit limit') ||
            billingSrc.contains('exceedsLimit') ||
            billingSrc.contains('exceeds.*limit');

        expect(
          hasOverLimitDialog,
          isTrue,
          reason:
              'COUNTEREXAMPLE (HARDWARE-012): No credit-limit warning dialog '
              'found in BillCreationScreenV2. Over-limit sales proceed '
              'silently without user acknowledgment.',
        );
      });
    });

    // =========================================================================
    // Unit tests: CreditLimitValidator logic
    // =========================================================================
    group('CreditLimitValidator.check() logic', () {
      test(
        'over-limit sale is flagged (outstandingBalance + amount > limit)',
        () {
          // Party has credit limit of 50000, outstanding 45000, new sale 10000
          // Projected: 55000 > 50000 → exceeds
          final result = CreditLimitValidator.check(
            creditLimit: 50000,
            outstandingBalance: 45000,
            newInvoiceAmount: 10000,
          );

          expect(result.exceedsLimit, isTrue);
          expect(result.overageAmount, equals(5000));
          expect(result.warningMessage, isNotEmpty);
        },
      );

      test('exactly at limit is NOT flagged (boundary case)', () {
        // Party has credit limit of 50000, outstanding 40000, new sale 10000
        // Projected: 50000 == 50000 → does NOT exceed
        final result = CreditLimitValidator.check(
          creditLimit: 50000,
          outstandingBalance: 40000,
          newInvoiceAmount: 10000,
        );

        expect(result.exceedsLimit, isFalse);
        expect(result.overageAmount, equals(0));
      });

      test('within limit is NOT flagged (preservation)', () {
        // Party has credit limit of 100000, outstanding 20000, new sale 5000
        // Projected: 25000 < 100000 → within limit
        final result = CreditLimitValidator.check(
          creditLimit: 100000,
          outstandingBalance: 20000,
          newInvoiceAmount: 5000,
        );

        expect(result.exceedsLimit, isFalse);
        expect(result.overageAmount, equals(0));
      });

      test('no limit (creditLimit == 0) is NEVER flagged (preservation)', () {
        // Party has creditLimit == 0 (no limit), any outstanding, any sale
        final result = CreditLimitValidator.check(
          creditLimit: 0,
          outstandingBalance: 999999,
          newInvoiceAmount: 999999,
        );

        expect(result.exceedsLimit, isFalse);
        expect(result.overageAmount, equals(0));
      });

      test('zero outstanding + over-limit sale is flagged', () {
        // Party has credit limit of 5000, outstanding 0, new sale 6000
        // Projected: 6000 > 5000 → exceeds
        final result = CreditLimitValidator.check(
          creditLimit: 5000,
          outstandingBalance: 0,
          newInvoiceAmount: 6000,
        );

        expect(result.exceedsLimit, isTrue);
        expect(result.overageAmount, equals(1000));
      });

      test('warningMessage is empty when not exceeding', () {
        final result = CreditLimitValidator.check(
          creditLimit: 50000,
          outstandingBalance: 10000,
          newInvoiceAmount: 5000,
        );

        expect(result.warningMessage, isEmpty);
      });

      test('warningMessage contains relevant amounts when exceeding', () {
        final result = CreditLimitValidator.check(
          creditLimit: 50000,
          outstandingBalance: 45000,
          newInvoiceAmount: 10000,
        );

        expect(result.warningMessage, contains('50000'));
        expect(result.warningMessage, contains('55000'));
      });
    });
  });
}
