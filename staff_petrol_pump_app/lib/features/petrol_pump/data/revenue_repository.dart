import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';

/// Revenue report data model
class RevenueReport {
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalRevenue;
  final int totalTransactions;
  final double totalFuelLiters;
  final double averageTransactionValue;
  final Map<String, double> revenueByDay;
  final FuelBreakdown fuelBreakdown;
  final PaymentMethodBreakdown paymentMethods;
  final List<StaffRevenueSummary> staffSummary;

  RevenueReport({
    required this.periodStart,
    required this.periodEnd,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.totalFuelLiters,
    required this.averageTransactionValue,
    required this.revenueByDay,
    required this.fuelBreakdown,
    required this.paymentMethods,
    required this.staffSummary,
  });

  factory RevenueReport.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    
    return RevenueReport(
      periodStart: data['periodStart'] != null
          ? DateTime.tryParse(data['periodStart']) ?? DateTime.now()
          : DateTime.now(),
      periodEnd: data['periodEnd'] != null
          ? DateTime.tryParse(data['periodEnd']) ?? DateTime.now()
          : DateTime.now(),
      totalRevenue: (data['totalRevenue'] ?? 0).toDouble(),
      totalTransactions: (data['totalTransactions'] ?? 0).toInt(),
      totalFuelLiters: (data['totalFuelLiters'] ?? 0).toDouble(),
      averageTransactionValue: (data['averageTransactionValue'] ?? 0).toDouble(),
      revenueByDay: _parseRevenueByDay(data['revenueByDay'] ?? {}),
      fuelBreakdown: FuelBreakdown.fromJson(data['fuelBreakdown'] ?? {}),
      paymentMethods: PaymentMethodBreakdown.fromJson(data['paymentMethods'] ?? {}),
      staffSummary: _parseStaffSummary(data['staffSummary'] ?? []),
    );
  }

  static Map<String, double> _parseRevenueByDay(Map<String, dynamic> json) {
    return json.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  static List<StaffRevenueSummary> _parseStaffSummary(List<dynamic> json) {
    return json.map((e) => StaffRevenueSummary.fromJson(e)).toList();
  }

  String get formattedRevenue => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(totalRevenue);

  String get formattedFuelLiters => '${NumberFormat('#,##0.0').format(totalFuelLiters)} L';

  String get formattedAverageTransaction => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(averageTransactionValue);
}

/// Fuel breakdown (Petrol vs Diesel)
class FuelBreakdown {
  final double petrolLiters;
  final double dieselLiters;
  final double petrolRevenue;
  final double dieselRevenue;
  final int petrolTransactions;
  final int dieselTransactions;

  FuelBreakdown({
    required this.petrolLiters,
    required this.dieselLiters,
    required this.petrolRevenue,
    required this.dieselRevenue,
    required this.petrolTransactions,
    required this.dieselTransactions,
  });

  factory FuelBreakdown.fromJson(Map<String, dynamic> json) {
    return FuelBreakdown(
      petrolLiters: (json['petrolLiters'] ?? 0).toDouble(),
      dieselLiters: (json['dieselLiters'] ?? 0).toDouble(),
      petrolRevenue: (json['petrolRevenue'] ?? 0).toDouble(),
      dieselRevenue: (json['dieselRevenue'] ?? 0).toDouble(),
      petrolTransactions: (json['petrolTransactions'] ?? 0).toInt(),
      dieselTransactions: (json['dieselTransactions'] ?? 0).toInt(),
    );
  }

  double get totalLiters => petrolLiters + dieselLiters;
  double get totalRevenue => petrolRevenue + dieselRevenue;
  
  double get petrolPercentage => totalLiters > 0 ? (petrolLiters / totalLiters) * 100 : 0;
  double get dieselPercentage => totalLiters > 0 ? (dieselLiters / totalLiters) * 100 : 0;
}

/// Payment method breakdown
class PaymentMethodBreakdown {
  final double upiAmount;
  final int upiTransactions;
  final double cashAmount;
  final int cashTransactions;
  final double cardAmount;
  final int cardTransactions;

  PaymentMethodBreakdown({
    required this.upiAmount,
    required this.upiTransactions,
    required this.cashAmount,
    required this.cashTransactions,
    required this.cardAmount,
    required this.cardTransactions,
  });

  factory PaymentMethodBreakdown.fromJson(Map<String, dynamic> json) {
    return PaymentMethodBreakdown(
      upiAmount: (json['upiAmount'] ?? 0).toDouble(),
      upiTransactions: (json['upiTransactions'] ?? 0).toInt(),
      cashAmount: (json['cashAmount'] ?? 0).toDouble(),
      cashTransactions: (json['cashTransactions'] ?? 0).toInt(),
      cardAmount: (json['cardAmount'] ?? 0).toDouble(),
      cardTransactions: (json['cardTransactions'] ?? 0).toInt(),
    );
  }

  double get totalAmount => upiAmount + cashAmount + cardAmount;
  int get totalTransactions => upiTransactions + cashTransactions + cardTransactions;

  double get upiPercentage => totalAmount > 0 ? (upiAmount / totalAmount) * 100 : 0;
  double get cashPercentage => totalAmount > 0 ? (cashAmount / totalAmount) * 100 : 0;
  double get cardPercentage => totalAmount > 0 ? (cardAmount / totalAmount) * 100 : 0;
}

/// Staff revenue summary
class StaffRevenueSummary {
  final String staffId;
  final String staffName;
  final double revenue;
  final int transactions;
  final double fuelLiters;

  StaffRevenueSummary({
    required this.staffId,
    required this.staffName,
    required this.revenue,
    required this.transactions,
    required this.fuelLiters,
  });

  factory StaffRevenueSummary.fromJson(Map<String, dynamic> json) {
    return StaffRevenueSummary(
      staffId: json['staffId'] ?? '',
      staffName: json['staffName'] ?? '',
      revenue: (json['revenue'] ?? 0).toDouble(),
      transactions: (json['transactions'] ?? 0).toInt(),
      fuelLiters: (json['fuelLiters'] ?? 0).toDouble(),
    );
  }

  double get averageTransaction => transactions > 0 ? revenue / transactions : 0;

  String get formattedRevenue => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(revenue);
}

/// Hourly sales data
class HourlySalesData {
  final int hour;
  final double revenue;
  final int transactions;
  final double fuelLiters;

  HourlySalesData({
    required this.hour,
    required this.revenue,
    required this.transactions,
    required this.fuelLiters,
  });

  factory HourlySalesData.fromJson(Map<String, dynamic> json) {
    return HourlySalesData(
      hour: (json['hour'] ?? 0).toInt(),
      revenue: (json['revenue'] ?? 0).toDouble(),
      transactions: (json['transactions'] ?? 0).toInt(),
      fuelLiters: (json['fuelLiters'] ?? 0).toDouble(),
    );
  }

  String get hourLabel {
    final time = DateTime(2024, 1, 1, hour);
    return DateFormat('h a').format(time);
  }
}

/// Revenue comparison (current vs previous period)
class RevenueComparison {
  final double currentRevenue;
  final double previousRevenue;
  final int currentTransactions;
  final int previousTransactions;
  final double currentFuelLiters;
  final double previousFuelLiters;

  RevenueComparison({
    required this.currentRevenue,
    required this.previousRevenue,
    required this.currentTransactions,
    required this.previousTransactions,
    required this.currentFuelLiters,
    required this.previousFuelLiters,
  });

  factory RevenueComparison.fromJson(Map<String, dynamic> json) {
    return RevenueComparison(
      currentRevenue: (json['currentRevenue'] ?? 0).toDouble(),
      previousRevenue: (json['previousRevenue'] ?? 0).toDouble(),
      currentTransactions: (json['currentTransactions'] ?? 0).toInt(),
      previousTransactions: (json['previousTransactions'] ?? 0).toInt(),
      currentFuelLiters: (json['currentFuelLiters'] ?? 0).toDouble(),
      previousFuelLiters: (json['previousFuelLiters'] ?? 0).toDouble(),
    );
  }

  double get revenueChangePercent => previousRevenue > 0
      ? ((currentRevenue - previousRevenue) / previousRevenue) * 100
      : 0;

  double get transactionsChangePercent => previousTransactions > 0
      ? ((currentTransactions - previousTransactions) / previousTransactions) * 100
      : 0;

  double get fuelLitersChangePercent => previousFuelLiters > 0
      ? ((currentFuelLiters - previousFuelLiters) / previousFuelLiters) * 100
      : 0;

  bool get isRevenueUp => revenueChangePercent >= 0;
  bool get isTransactionsUp => transactionsChangePercent >= 0;
  bool get isFuelLitersUp => fuelLitersChangePercent >= 0;
}

/// Report filter options
enum ReportPeriod {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  custom,
}

extension ReportPeriodExtension on ReportPeriod {
  String get displayName {
    switch (this) {
      case ReportPeriod.today:
        return 'Today';
      case ReportPeriod.yesterday:
        return 'Yesterday';
      case ReportPeriod.last7Days:
        return 'Last 7 Days';
      case ReportPeriod.last30Days:
        return 'Last 30 Days';
      case ReportPeriod.thisMonth:
        return 'This Month';
      case ReportPeriod.lastMonth:
        return 'Last Month';
      case ReportPeriod.custom:
        return 'Custom Range';
    }
  }

  DateTimeRange get dateRange {
    final now = DateTime.now();
    
    switch (this) {
      case ReportPeriod.today:
        return DateTimeRange(start: now, end: now);
      case ReportPeriod.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return DateTimeRange(start: yesterday, end: yesterday);
      case ReportPeriod.last7Days:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now,
        );
      case ReportPeriod.last30Days:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 29)),
          end: now,
        );
      case ReportPeriod.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case ReportPeriod.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
        return DateTimeRange(start: lastMonth, end: lastDayOfLastMonth);
      case ReportPeriod.custom:
        return DateTimeRange(start: now, end: now);
    }
  }
}

/// Date time range helper
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  DateTimeRange({required this.start, required this.end});
}

/// Revenue repository for API operations
class RevenueRepository {
  final ApiClient _apiClient = ApiClient();

  /// Get revenue report
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    String? staffId,
  }) async {
    final queryParams = <String, dynamic>{
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      if (staffId != null) 'staffId': staffId,
    };

    final response = await _apiClient.get(
      '/reports/revenue',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return RevenueReport.fromJson(response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load revenue report');
    }
  }

  /// Get hourly sales data
  Future<List<HourlySalesData>> getHourlySales({
    required DateTime date,
    String? staffId,
  }) async {
    final queryParams = <String, dynamic>{
      'date': date.toIso8601String().split('T')[0],
      if (staffId != null) 'staffId': staffId,
    };

    final response = await _apiClient.get(
      '/reports/hourly-sales',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] ?? response.data;
      final List<dynamic> hourlyData = data is List ? data : (data['items'] ?? []);
      return hourlyData.map((e) => HourlySalesData.fromJson(e)).toList();
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load hourly sales');
    }
  }

  /// Get revenue comparison (current vs previous period)
  Future<RevenueComparison> getRevenueComparison({
    required DateTime currentStart,
    required DateTime currentEnd,
  }) async {
    final queryParams = <String, dynamic>{
      'currentStart': currentStart.toIso8601String().split('T')[0],
      'currentEnd': currentEnd.toIso8601String().split('T')[0],
    };

    final response = await _apiClient.get(
      '/reports/comparison',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return RevenueComparison.fromJson(response.data['data'] ?? response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to load comparison');
    }
  }

  /// Export revenue report
  Future<String> exportRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    required String format, // 'pdf', 'excel', 'csv'
    String? staffId,
  }) async {
    final queryParams = <String, dynamic>{
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      'format': format,
      if (staffId != null) 'staffId': staffId,
    };

    final response = await _apiClient.get(
      '/reports/export',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      // Returns download URL
      return response.data['data']?['downloadUrl'] ?? '';
    } else {
      throw Exception(response.data['error'] ?? 'Failed to export report');
    }
  }
}
