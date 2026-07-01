/// Represents a captured commission value for a single lot in a broker sale.
///
/// Two variants:
/// - **Flat**: a fixed integer paise amount captured directly from the entry sheet.
/// - **Percentage**: a rate (≥2 decimal precision) plus the resulting paise amount.
///
/// The captured value is persisted directly — no flat→%→flat round-trip.
/// (Requirements 5.1, 5.2, 5.3)
sealed class CommissionInput {
  const CommissionInput();

  /// Validates the commission input and returns an error message if invalid,
  /// or null if valid.
  ///
  /// Rejects: missing, negative, or (for percentage) outside 0.00–100.00.
  /// (Requirement 5.6)
  String? validate();

  /// The resulting commission amount in integer paise.
  int get amountPaise;

  /// Whether this is a flat commission.
  bool get isFlat => this is FlatCommission;

  /// Whether this is a percentage commission.
  bool get isPercentage => this is PercentageCommission;

  /// The commission type string for persistence.
  String get typeString;
}

/// A flat commission: the exact paise amount captured at entry.
/// Stored with zero variance (Requirement 5.2).
class FlatCommission extends CommissionInput {
  /// The commission amount in integer paise.
  final int paise;

  const FlatCommission(this.paise);

  @override
  String? validate() {
    if (paise < 0) {
      return 'Commission amount must not be negative (got $paise paise)';
    }
    return null;
  }

  @override
  int get amountPaise => paise;

  @override
  String get typeString => 'flat';
}

/// A percentage commission: the rate plus the resulting paise amount.
/// Both the rate (≥2 decimal places) and the result paise are stored
/// (Requirement 5.3).
class PercentageCommission extends CommissionInput {
  /// The percentage rate (e.g. 5.25 for 5.25%).
  final double rate;

  /// The resulting commission amount in integer paise.
  final int resultPaise;

  const PercentageCommission({required this.rate, required this.resultPaise});

  @override
  String? validate() {
    if (rate < 0.0) {
      return 'Commission rate must not be negative (got $rate%)';
    }
    if (rate > 100.0) {
      return 'Commission rate must not exceed 100.00% (got $rate%)';
    }
    if (resultPaise < 0) {
      return 'Resulting commission amount must not be negative (got $resultPaise paise)';
    }
    return null;
  }

  @override
  int get amountPaise => resultPaise;

  @override
  String get typeString => 'percentage';
}
