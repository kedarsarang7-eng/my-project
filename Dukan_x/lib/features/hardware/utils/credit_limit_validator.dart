// ============================================================================
// CREDIT LIMIT VALIDATOR — Hardware credit sale enforcement (bugfix.md 2.12)
// ============================================================================
// At invoice-creation time, checks the party's outstanding balance + new
// invoice amount against their creditLimit. Returns a validation result:
//   • creditLimit == 0 → no limit → always allowed
//   • outstandingBalance + newAmount <= creditLimit → within limit → allowed
//   • outstandingBalance + newAmount > creditLimit → over limit → warn/block
//
// Preservation: in-limit and no-limit sales pass through without warning.
// ============================================================================

/// Result of a credit-limit check at billing time.
class CreditLimitCheckResult {
  /// Whether the sale exceeds the credit limit.
  final bool exceedsLimit;

  /// The party's credit limit (0 = no limit).
  final double creditLimit;

  /// The party's current outstanding balance.
  final double outstandingBalance;

  /// The new invoice amount being attempted.
  final double newInvoiceAmount;

  /// How much over the limit this sale would push the balance.
  /// Zero if within limit or no limit.
  final double overageAmount;

  const CreditLimitCheckResult({
    required this.exceedsLimit,
    required this.creditLimit,
    required this.outstandingBalance,
    required this.newInvoiceAmount,
    this.overageAmount = 0,
  });

  /// Human-readable warning message for UI display.
  String get warningMessage {
    if (!exceedsLimit) return '';
    return 'This sale of ₹${newInvoiceAmount.toStringAsFixed(2)} will push '
        'the outstanding balance to '
        '₹${(outstandingBalance + newInvoiceAmount).toStringAsFixed(2)}, '
        'exceeding the credit limit of ₹${creditLimit.toStringAsFixed(2)} '
        'by ₹${overageAmount.toStringAsFixed(2)}.';
  }
}

/// Pure-logic credit limit validator for hardware billing.
///
/// Usage:
/// ```dart
/// final result = CreditLimitValidator.check(
///   creditLimit: party.creditLimit.toDouble(),
///   outstandingBalance: party.totalDues,
///   newInvoiceAmount: invoiceTotal,
/// );
/// if (result.exceedsLimit) { /* show warning dialog */ }
/// ```
class CreditLimitValidator {
  CreditLimitValidator._();

  /// Check whether a new credit sale would exceed the party's credit limit.
  ///
  /// Rules:
  /// - [creditLimit] == 0 means "no limit" → never warns.
  /// - [outstandingBalance] + [newInvoiceAmount] > [creditLimit] → exceeds.
  /// - Otherwise → within limit, allowed.
  static CreditLimitCheckResult check({
    required double creditLimit,
    required double outstandingBalance,
    required double newInvoiceAmount,
  }) {
    // No limit set → always allowed
    if (creditLimit <= 0) {
      return CreditLimitCheckResult(
        exceedsLimit: false,
        creditLimit: creditLimit,
        outstandingBalance: outstandingBalance,
        newInvoiceAmount: newInvoiceAmount,
      );
    }

    final projectedBalance = outstandingBalance + newInvoiceAmount;

    if (projectedBalance > creditLimit) {
      return CreditLimitCheckResult(
        exceedsLimit: true,
        creditLimit: creditLimit,
        outstandingBalance: outstandingBalance,
        newInvoiceAmount: newInvoiceAmount,
        overageAmount: projectedBalance - creditLimit,
      );
    }

    return CreditLimitCheckResult(
      exceedsLimit: false,
      creditLimit: creditLimit,
      outstandingBalance: outstandingBalance,
      newInvoiceAmount: newInvoiceAmount,
    );
  }
}
