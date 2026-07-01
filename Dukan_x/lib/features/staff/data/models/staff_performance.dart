/// Petrol pump staff performance metrics for a given period.
///
/// Used by [StaffDetailScreen] to display fuel sales breakdown.
class StaffPerformance {
  final double petrolLiters;
  final double petrolRevenue;
  final double dieselLiters;
  final double dieselRevenue;
  final double cngKg;
  final double cngRevenue;
  final int totalTransactions;
  final double totalRevenue;
  final double performanceScore;
  final double averageTransactionValue;

  const StaffPerformance({
    this.petrolLiters = 0.0,
    this.petrolRevenue = 0.0,
    this.dieselLiters = 0.0,
    this.dieselRevenue = 0.0,
    this.cngKg = 0.0,
    this.cngRevenue = 0.0,
    this.totalTransactions = 0,
    this.totalRevenue = 0.0,
    this.performanceScore = 0.0,
    this.averageTransactionValue = 0.0,
  });

  factory StaffPerformance.fromMap(Map<String, dynamic> map) {
    return StaffPerformance(
      petrolLiters: (map['petrolLiters'] as num?)?.toDouble() ?? 0.0,
      petrolRevenue: (map['petrolRevenue'] as num?)?.toDouble() ?? 0.0,
      dieselLiters: (map['dieselLiters'] as num?)?.toDouble() ?? 0.0,
      dieselRevenue: (map['dieselRevenue'] as num?)?.toDouble() ?? 0.0,
      cngKg: (map['cngKg'] as num?)?.toDouble() ?? 0.0,
      cngRevenue: (map['cngRevenue'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: (map['totalTransactions'] as num?)?.toInt() ?? 0,
      totalRevenue: (map['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      performanceScore: (map['performanceScore'] as num?)?.toDouble() ?? 0.0,
      averageTransactionValue: (map['averageTransactionValue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static const StaffPerformance empty = StaffPerformance();
}
