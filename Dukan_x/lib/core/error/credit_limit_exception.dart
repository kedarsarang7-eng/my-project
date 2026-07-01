/// Exception thrown when a credit sale would exceed customer's credit limit
///
/// FRAUD PREVENTION: This exception blocks unauthorized credit extension.
/// Staff cannot bypass this without owner override.
class CreditLimitExceededException implements Exception {
  final double currentDues;
  final double billAmount;
  final double creditLimit;
  final String? customerName;

  CreditLimitExceededException({
    required this.currentDues,
    required this.billAmount,
    required this.creditLimit,
    this.customerName,
  });

  double get projectedDues => currentDues + billAmount;
  double get overLimit => projectedDues - creditLimit;

  @override
  String toString() {
    final name = customerName ?? 'Customer';
    return 'CreditLimitExceededException: Cannot create credit sale for $name. '
        'Current dues: ₹${currentDues.toStringAsFixed(2)}, '
        'Bill amount: ₹${billAmount.toStringAsFixed(2)}, '
        'Would exceed limit by: ₹${overLimit.toStringAsFixed(2)}. '
        'Credit limit: ₹${creditLimit.toStringAsFixed(2)}.';
  }

  /// User-friendly message for UI display
  String get userMessage {
    final name = customerName ?? 'This customer';
    return '$name has reached their credit limit (₹${creditLimit.toStringAsFixed(0)}). '
        'Current dues: ₹${currentDues.toStringAsFixed(0)}. '
        'Cannot add ₹${billAmount.toStringAsFixed(0)} more credit. '
        'Please collect payment or request owner approval.';
  }
}
