class AmountConverter {
  const AmountConverter._();

  /// Backend expects paise; UI works in rupees.
  static int rupeesToPaise(double rupees) => (rupees * 100).round();

  static double paiseToRupees(int paise) => paise / 100.0;

  static String formatRupeesFromPaise(int paise) {
    final rupees = paiseToRupees(paise);
    return '₹${rupees.toStringAsFixed(2)}';
  }

  /// Formats an integer Paise value as a rupee string with exactly 2 decimal
  /// places, WITHOUT the ₹ symbol.
  ///
  /// This is the canonical presentation-edge helper for the School_System
  /// paise migration (Requirement 1.1, 10.2). All money display in the
  /// academic_coaching feature should route through this.
  ///
  /// Examples:
  ///   formatPaiseAsRupees(123)   → "1.23"
  ///   formatPaiseAsRupees(10050) → "100.50"
  ///   formatPaiseAsRupees(0)     → "0.00"
  ///   formatPaiseAsRupees(7)     → "0.07"
  static String formatPaiseAsRupees(int paise) {
    final rupees = paise / 100.0;
    return rupees.toStringAsFixed(2);
  }
}
