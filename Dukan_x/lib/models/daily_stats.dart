class DailyStats {
  final double todaySales;
  final double todaySpend; // Purchases + Expenses
  final double totalPending;
  final int lowStockCount;
  final double paidThisMonth;
  final double overdueAmount;
  final double todayCollections;
  final int todayBillCount;
  final int monthlyBillCount;
  final int customerCount;

  const DailyStats({
    required this.todaySales,
    required this.todaySpend,
    required this.totalPending,
    required this.lowStockCount,
    required this.paidThisMonth,
    required this.overdueAmount,
    this.todayCollections = 0,
    this.todayBillCount = 0,
    this.monthlyBillCount = 0,
    this.customerCount = 0,
  });

  factory DailyStats.empty() {
    return const DailyStats(
      todaySales: 0,
      todaySpend: 0,
      totalPending: 0,
      lowStockCount: 0,
      paidThisMonth: 0,
      overdueAmount: 0,
      todayCollections: 0,
      todayBillCount: 0,
      monthlyBillCount: 0,
      customerCount: 0,
    );
  }

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      todaySales: (json['todaySales'] as num?)?.toDouble() ?? 0,
      todaySpend: (json['todaySpend'] as num?)?.toDouble() ?? 0,
      totalPending: (json['totalPending'] as num?)?.toDouble() ?? 0,
      lowStockCount: (json['lowStockCount'] as num?)?.toInt() ?? 0,
      paidThisMonth: (json['paidThisMonth'] as num?)?.toDouble() ?? 0,
      overdueAmount: (json['overdueAmount'] as num?)?.toDouble() ?? 0,
      todayCollections: (json['todayCollections'] as num?)?.toDouble() ?? 0,
      todayBillCount: (json['todayBillCount'] as num?)?.toInt() ?? 0,
      monthlyBillCount: (json['monthlyBillCount'] as num?)?.toInt() ?? 0,
      customerCount: (json['customerCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class VendorStats {
  final double totalInvoiceValue;
  final double paidAmount;
  final double unpaidAmount;
  final double todayPurchase;
  final int activeOrders;

  const VendorStats({
    required this.totalInvoiceValue,
    required this.paidAmount,
    required this.unpaidAmount,
    required this.todayPurchase,
    required this.activeOrders,
  });

  factory VendorStats.empty() {
    return const VendorStats(
      totalInvoiceValue: 0,
      paidAmount: 0,
      unpaidAmount: 0,
      todayPurchase: 0,
      activeOrders: 0,
    );
  }
}

/// 🆕 Real-Time Profit Dashboard Model
class ProfitDashboard {
  final double todaySales;
  final double todayCogs;
  final double todayPurchases;
  final double grossProfit;
  final double netProfit;
  final int billCount;
  final double profitMargin; // Percentage

  const ProfitDashboard({
    required this.todaySales,
    required this.todayCogs,
    required this.todayPurchases,
    required this.grossProfit,
    required this.netProfit,
    required this.billCount,
    required this.profitMargin,
  });

  factory ProfitDashboard.empty() {
    return const ProfitDashboard(
      todaySales: 0,
      todayCogs: 0,
      todayPurchases: 0,
      grossProfit: 0,
      netProfit: 0,
      billCount: 0,
      profitMargin: 0,
    );
  }

  bool get isProfitable => grossProfit > 0;
}

/// Accurate today-vs-yesterday comparison used to compute real KPI trends.
///
/// Every field is derived directly from bill rows for the relevant day, so the
/// percentage changes shown on the analytics dashboard are real and not
/// estimated. Fields are nullable per day so a caller can distinguish "no data
/// for that period" from a genuine zero.
class DailyComparison {
  /// Today's totals (sales = grandTotal, collections = paidAmount).
  final double todaySales;
  final double todayCollections;

  /// Yesterday's totals, used as the prior period for the sales/collections
  /// trend badges.
  final double yesterdaySales;
  final double yesterdayCollections;

  /// Outstanding dues as of end-of-today and end-of-yesterday. These are
  /// summed across all non-deleted bills (grandTotal - paidAmount) whose
  /// billDate is strictly before the end of the respective day, so the two
  /// snapshots are directly comparable.
  final double duesEndOfToday;
  final double duesEndOfYesterday;

  /// Distinct customer count on bills created today / yesterday.
  final int customersToday;
  final int customersYesterday;

  const DailyComparison({
    required this.todaySales,
    required this.todayCollections,
    required this.yesterdaySales,
    required this.yesterdayCollections,
    required this.duesEndOfToday,
    required this.duesEndOfYesterday,
    required this.customersToday,
    required this.customersYesterday,
  });

  factory DailyComparison.empty() => const DailyComparison(
    todaySales: 0,
    todayCollections: 0,
    yesterdaySales: 0,
    yesterdayCollections: 0,
    duesEndOfToday: 0,
    duesEndOfYesterday: 0,
    customersToday: 0,
    customersYesterday: 0,
  );
}
