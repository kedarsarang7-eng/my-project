export 'aging_report_model.dart';

/// Party Balance Summary Model
class PartyBalanceSummary {
  final double currentBalance;
  final String balanceType; // 'Dr' or 'Cr'
  final DateTime? lastTransactionDate;

  PartyBalanceSummary({
    required this.currentBalance,
    required this.balanceType,
    this.lastTransactionDate,
  });
}
