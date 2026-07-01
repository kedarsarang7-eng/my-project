/// Shift Reconciliation model for petrol pump shift close verification
///
/// FRAUD PREVENTION: This model captures the reconciliation data that must
/// match for a shift to be successfully closed. Any variance beyond tolerance
/// indicates potential fraud or error.
class ShiftReconciliation {
  /// Total litres calculated from nozzle readings (closing - opening)
  final double nozzleLitres;

  /// Total litres from bills created during this shift
  final double billedLitres;

  /// Total litres deducted from tanks during this shift
  final double tankDeducted;

  /// Variance: nozzleLitres - billedLitres (should be zero or within tolerance)
  final double varianceLitres;

  /// Payment breakup for the shift
  final double cashAmount;
  final double upiAmount;
  final double cardAmount;
  final double creditAmount;

  /// Total sales amount
  double get totalSalesAmount =>
      cashAmount + upiAmount + cardAmount + creditAmount;

  /// Default tolerance in litres (0.5L for measurement errors)
  static const double toleranceLitres = 0.5;

  /// Check if variance is within acceptable tolerance
  bool get isWithinTolerance => varianceLitres.abs() <= toleranceLitres;

  /// List of warnings if any discrepancies found
  final List<String> warnings;

  /// Nozzle-wise breakdown
  final List<NozzleReconciliation> nozzleBreakdown;

  const ShiftReconciliation({
    required this.nozzleLitres,
    required this.billedLitres,
    required this.tankDeducted,
    required this.varianceLitres,
    required this.cashAmount,
    required this.upiAmount,
    required this.cardAmount,
    required this.creditAmount,
    this.warnings = const [],
    this.nozzleBreakdown = const [],
  });

  /// Create an empty reconciliation for error cases
  factory ShiftReconciliation.empty() => const ShiftReconciliation(
    nozzleLitres: 0,
    billedLitres: 0,
    tankDeducted: 0,
    varianceLitres: 0,
    cashAmount: 0,
    upiAmount: 0,
    cardAmount: 0,
    creditAmount: 0,
  );

  Map<String, dynamic> toMap() => {
    'nozzleLitres': nozzleLitres,
    'billedLitres': billedLitres,
    'tankDeducted': tankDeducted,
    'varianceLitres': varianceLitres,
    'cashAmount': cashAmount,
    'upiAmount': upiAmount,
    'cardAmount': cardAmount,
    'creditAmount': creditAmount,
    'totalSalesAmount': totalSalesAmount,
    'isWithinTolerance': isWithinTolerance,
    'warnings': warnings,
    'nozzleBreakdown': nozzleBreakdown.map((n) => n.toMap()).toList(),
  };
}

/// Per-nozzle reconciliation breakdown
class NozzleReconciliation {
  final String nozzleId;
  final String? fuelTypeName;
  final double openingReading;
  final double closingReading;
  final double litresSold;
  final double billedLitres;
  final double variance;

  const NozzleReconciliation({
    required this.nozzleId,
    this.fuelTypeName,
    required this.openingReading,
    required this.closingReading,
    required this.litresSold,
    required this.billedLitres,
    required this.variance,
  });

  Map<String, dynamic> toMap() => {
    'nozzleId': nozzleId,
    'fuelTypeName': fuelTypeName,
    'openingReading': openingReading,
    'closingReading': closingReading,
    'litresSold': litresSold,
    'billedLitres': billedLitres,
    'variance': variance,
  };
}
