import '../core/repository/products_repository.dart';

class ReorderPrediction {
  final Product product;
  final double dailyVelocity;
  final int daysUntilEmpty;
  final DateTime? estimatedStockoutDate;

  ReorderPrediction({
    required this.product,
    required this.dailyVelocity,
    required this.daysUntilEmpty,
    this.estimatedStockoutDate,
  });

  bool get isCritical => daysUntilEmpty <= 7;
  bool get isWarning => daysUntilEmpty > 7 && daysUntilEmpty <= 14;

  // Simple copyWith if needed
  ReorderPrediction copyWith({
    Product? product,
    double? dailyVelocity,
    int? daysUntilEmpty,
    DateTime? estimatedStockoutDate,
  }) {
    return ReorderPrediction(
      product: product ?? this.product,
      dailyVelocity: dailyVelocity ?? this.dailyVelocity,
      daysUntilEmpty: daysUntilEmpty ?? this.daysUntilEmpty,
      estimatedStockoutDate:
          estimatedStockoutDate ?? this.estimatedStockoutDate,
    );
  }
}
