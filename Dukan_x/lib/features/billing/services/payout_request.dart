/// Payment mode for a farmer payout.
///
/// Must be explicitly selected — no default to cash.
/// (Requirements 10.1, 10.2)
enum PaymentMode { cash, bank }

/// Encapsulates all data required to initiate a farmer payout.
///
/// Validates:
/// - Payment mode must be explicitly set (not null) — Requirement 10.1, 10.2
/// - For bank mode, bankAccountRef and paymentRef are required — Requirement 10.3, 10.4
/// - Authorization must be explicitly true to post — Requirement 10.5, 10.6
///
/// On successful post, the accounting entry records the mode and bank details
/// (Requirement 10.7).
class PayoutRequest {
  /// The farmer to pay out.
  final String farmerId;

  /// Payout amount in rupees (passed through to accounting layer as-is).
  final double amount;

  /// Description / memo for the payout.
  final String description;

  /// Payment mode: cash or bank. Must be explicitly set (non-null).
  final PaymentMode? paymentMode;

  /// Bank account reference — required when [paymentMode] is [PaymentMode.bank].
  final String? bankAccountRef;

  /// Payment reference (e.g. UTR, cheque number) — required when [paymentMode] is [PaymentMode.bank].
  final String? paymentRef;

  /// Explicit authorization confirmation. Must be `true` to post.
  final bool authorized;

  const PayoutRequest({
    required this.farmerId,
    required this.amount,
    required this.description,
    this.paymentMode,
    this.bankAccountRef,
    this.paymentRef,
    this.authorized = false,
  });

  /// Validates the payout request and returns an error message if invalid,
  /// or null if all validations pass.
  ///
  /// Validation order:
  /// 1. Payment mode must be selected (Requirement 10.2)
  /// 2. For bank: bank account ref and payment ref required (Requirement 10.4)
  /// 3. Authorization must be true (Requirement 10.6)
  String? validate() {
    // Requirement 10.1, 10.2: Require explicit payment mode selection.
    if (paymentMode == null) {
      return 'payment mode required';
    }

    // Requirement 10.3, 10.4: For bank mode, require bank details.
    if (paymentMode == PaymentMode.bank) {
      if (bankAccountRef == null || bankAccountRef!.trim().isEmpty) {
        return 'bank account reference required';
      }
      if (paymentRef == null || paymentRef!.trim().isEmpty) {
        return 'payment reference required';
      }
    }

    // Requirement 10.5, 10.6: Require explicit authorization.
    if (!authorized) {
      return 'authorization required';
    }

    return null;
  }

  /// Returns the payment mode string for persistence in the accounting layer.
  String get paymentModeString {
    switch (paymentMode!) {
      case PaymentMode.cash:
        return 'CASH';
      case PaymentMode.bank:
        return 'BANK';
    }
  }
}
