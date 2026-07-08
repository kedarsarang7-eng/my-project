/// Bug Condition Exploration Test — Deposit Settlement Bounds (HARDWARE-018)
///
/// **Validates: Requirements 1.18, 2.18**
///
/// Property 17: When settling a material deposit, `returnedQty` must be <=
/// the original deposit's `quantity`, and `refundAmountCents` must be <=
/// the deposit's `outstandingDepositCents`. Over-bound settlements must be
/// rejected.
///
/// Bug Condition: `isBugCondition(input)` where
///   `input.surface == 'deposit.settle'` and
///   (`refund > originalOutstanding` or `returnedQty > originalQty`)
///
/// BEFORE fix: The `_showSettleDepositDialog()` only validates `qty <= 0`
/// and `refundRs < 0` (non-negative check) but does NOT validate upper
/// bounds against the original deposit record. Over-refund and over-return
/// are accepted silently.
///
/// AFTER fix: `_showSettleDepositDialog()` validates
///   `returnedQty <= dep['quantity']` and
///   `refundAmountCents <= dep['outstandingDepositCents']`
/// and rejects the settlement with a validation error when bounds are
/// exceeded.
///
/// Preservation: Within-bounds settlements (returnedQty <= quantity AND
/// refund <= outstanding) must still be accepted without error.
///
/// Run: flutter test test/bug_condition/hardware_deposit_settlement_bounds_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the project root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  group('Bug Condition HARDWARE-018 — deposit settlement bounds validation', () {
    // =======================================================================
    // Source-code probe: _showSettleDepositDialog validates upper bounds
    // =======================================================================
    group('Source-code integration probe', () {
      final operationsSrc = _readSource(
        'lib/features/hardware/presentation/screens/'
        'hardware_operations_screen.dart',
      );

      test(
        '_showSettleDepositDialog validates returnedQty <= deposit quantity',
        () {
          // The fix requires the settle dialog to check that the returned
          // quantity does not exceed the original deposit's quantity.
          // Look for evidence of upper-bound quantity validation.
          final hasQtyBoundsCheck =
              operationsSrc.contains("dep['quantity']") &&
              (operationsSrc.contains('returnedQty') ||
                  operationsSrc.contains('returned')) &&
              // Must contain a comparison against the deposit quantity
              (operationsSrc.contains('originalQty') ||
                  operationsSrc.contains('maxQty') ||
                  operationsSrc.contains("dep['quantity']"));

          // Additionally check for an actual comparison/validation pattern
          final hasUpperBoundValidation =
              operationsSrc.contains('> originalQty') ||
              operationsSrc.contains('> maxQty') ||
              operationsSrc.contains('>= originalQty') ||
              operationsSrc.contains('qty > originalQty') ||
              operationsSrc.contains('qty > maxQty') ||
              // Also allow <= comparison patterns
              operationsSrc.contains('<= originalQty') ||
              operationsSrc.contains('<= maxQty');

          expect(
            hasQtyBoundsCheck && hasUpperBoundValidation,
            isTrue,
            reason:
                'COUNTEREXAMPLE (HARDWARE-018): _showSettleDepositDialog does '
                'NOT validate returnedQty against the original deposit quantity. '
                'A user can return MORE items than were originally deposited. '
                'Fix: extract originalQty from dep["quantity"] and reject when '
                'qty > originalQty.',
          );
        },
      );

      test(
        '_showSettleDepositDialog validates refund <= outstandingDepositCents',
        () {
          // The fix requires the settle dialog to check that the refund
          // amount does not exceed the outstanding deposit amount.
          final hasRefundBoundsCheck =
              operationsSrc.contains("dep['outstandingDepositCents']") &&
              (operationsSrc.contains('refundAmountCents') ||
                  operationsSrc.contains('refundCents') ||
                  operationsSrc.contains('maxRefund') ||
                  operationsSrc.contains('originalOutstanding'));

          final hasRefundUpperBound =
              operationsSrc.contains('> originalOutstanding') ||
              operationsSrc.contains('> maxRefund') ||
              operationsSrc.contains('> maxRefundCents') ||
              operationsSrc.contains('refundCents > maxRefund') ||
              operationsSrc.contains('<= originalOutstanding') ||
              operationsSrc.contains('<= maxRefund') ||
              operationsSrc.contains('<= maxRefundCents');

          expect(
            hasRefundBoundsCheck && hasRefundUpperBound,
            isTrue,
            reason:
                'COUNTEREXAMPLE (HARDWARE-018): _showSettleDepositDialog does '
                'NOT validate refundAmount against outstandingDepositCents. '
                'A user can refund MORE than the outstanding deposit amount. '
                'Fix: extract maxRefundCents from dep["outstandingDepositCents"] '
                'and reject when refundAmountCents > maxRefundCents.',
          );
        },
      );

      test(
        '_showSettleDepositDialog shows validation error for over-bound values',
        () {
          // The fix should display a user-facing error message when bounds
          // are violated rather than silently rejecting or proceeding.
          final hasValidationError =
              operationsSrc.contains('exceeds') ||
              operationsSrc.contains('cannot exceed') ||
              operationsSrc.contains('must not exceed') ||
              operationsSrc.contains('over the') ||
              operationsSrc.contains('more than');

          expect(
            hasValidationError,
            isTrue,
            reason:
                'COUNTEREXAMPLE (HARDWARE-018): _showSettleDepositDialog does '
                'NOT show any validation error message when over-bound values '
                'are entered. The user gets no feedback about why their '
                'settlement was rejected. Fix: show a _notify() or inline '
                'error when bounds are exceeded.',
          );
        },
      );
    });

    // =======================================================================
    // Logic validation: deposit settlement bounds checking
    // =======================================================================
    group('Deposit settlement bounds logic', () {
      /// Simulates the validation logic that SHOULD exist in
      /// _showSettleDepositDialog. Returns null if valid, or an error
      /// message if bounds are exceeded.
      String? validateSettlement({
        required double returnedQty,
        required int refundAmountCents,
        required double originalQty,
        required int outstandingDepositCents,
      }) {
        // This mirrors what the FIX should do:
        if (returnedQty > originalQty) {
          return 'Returned quantity ($returnedQty) exceeds original deposit '
              'quantity ($originalQty)';
        }
        if (refundAmountCents > outstandingDepositCents) {
          return 'Refund amount ($refundAmountCents cents) exceeds '
              'outstanding deposit ($outstandingDepositCents cents)';
        }
        return null; // valid
      }

      test('over-return is rejected (returnedQty > originalQty)', () {
        final error = validateSettlement(
          returnedQty: 15,
          refundAmountCents: 5000,
          originalQty: 10,
          outstandingDepositCents: 10000,
        );

        expect(error, isNotNull);
        expect(error, contains('exceeds'));
      });

      test('over-refund is rejected (refundAmountCents > outstanding)', () {
        final error = validateSettlement(
          returnedQty: 5,
          refundAmountCents: 15000,
          originalQty: 10,
          outstandingDepositCents: 10000,
        );

        expect(error, isNotNull);
        expect(error, contains('exceeds'));
      });

      test('both over-return AND over-refund rejected', () {
        final error = validateSettlement(
          returnedQty: 20,
          refundAmountCents: 20000,
          originalQty: 10,
          outstandingDepositCents: 10000,
        );

        expect(error, isNotNull);
      });

      test('within-bounds settlement is accepted (preservation)', () {
        final error = validateSettlement(
          returnedQty: 5,
          refundAmountCents: 5000,
          originalQty: 10,
          outstandingDepositCents: 10000,
        );

        expect(error, isNull);
      });

      test(
        'exact-bounds settlement is accepted (returnedQty == originalQty)',
        () {
          final error = validateSettlement(
            returnedQty: 10,
            refundAmountCents: 10000,
            originalQty: 10,
            outstandingDepositCents: 10000,
          );

          expect(error, isNull);
        },
      );

      test('zero return with zero refund is accepted', () {
        // Edge case: settling with nothing returned and zero refund
        // This should be handled by the existing non-negative check,
        // but won't violate the upper bound.
        final error = validateSettlement(
          returnedQty: 0,
          refundAmountCents: 0,
          originalQty: 10,
          outstandingDepositCents: 10000,
        );

        expect(error, isNull);
      });
    });
  });
}
