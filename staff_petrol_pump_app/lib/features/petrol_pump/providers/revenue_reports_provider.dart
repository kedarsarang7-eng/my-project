import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/revenue_repository.dart';
import 'license_provider.dart';

/// Revenue report state
class RevenueReportState {
  final RevenueReport? report;
  final List<HourlySalesData> hourlySales;
  final RevenueComparison? comparison;
  final bool isLoading;
  final bool isLoadingHourly;
  final bool isLoadingComparison;
  final String? error;
  final ReportPeriod selectedPeriod;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const RevenueReportState({
    this.report,
    this.hourlySales = const [],
    this.comparison,
    this.isLoading = false,
    this.isLoadingHourly = false,
    this.isLoadingComparison = false,
    this.error,
    this.selectedPeriod = ReportPeriod.today,
    this.customStartDate,
    this.customEndDate,
  });

  RevenueReportState copyWith({
    RevenueReport? report,
    List<HourlySalesData>? hourlySales,
    RevenueComparison? comparison,
    bool? isLoading,
    bool? isLoadingHourly,
    bool? isLoadingComparison,
    String? error,
    ReportPeriod? selectedPeriod,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) {
    return RevenueReportState(
      report: report ?? this.report,
      hourlySales: hourlySales ?? this.hourlySales,
      comparison: comparison ?? this.comparison,
      isLoading: isLoading ?? this.isLoading,
      isLoadingHourly: isLoadingHourly ?? this.isLoadingHourly,
      isLoadingComparison: isLoadingComparison ?? this.isLoadingComparison,
      error: error,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
    );
  }

  DateTimeRange get dateRange {
    if (selectedPeriod == ReportPeriod.custom && customStartDate != null && customEndDate != null) {
      return DateTimeRange(start: customStartDate!, end: customEndDate!);
    }
    return selectedPeriod.dateRange;
  }

  String get periodDisplayName {
    if (selectedPeriod == ReportPeriod.custom && customStartDate != null && customEndDate != null) {
      final start = DateFormat('dd MMM').format(customStartDate!);
      final end = DateFormat('dd MMM').format(customEndDate!);
      return '$start - $end';
    }
    return selectedPeriod.displayName;
  }
}

/// Revenue reports notifier
class RevenueReportsNotifier extends StateNotifier<RevenueReportState> {
  final Ref _ref;
  final RevenueRepository _repository = RevenueRepository();

  RevenueReportsNotifier(this._ref) : super(const RevenueReportState());

  /// Load complete revenue report
  Future<void> loadRevenueReport({
    ReportPeriod? period,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    if (state.isLoading) return;

    final license = _ref.read(licenseProvider).profile;
    if (license == null) {
      state = state.copyWith(error: 'No license profile available');
      return;
    }

    // Update period if provided
    if (period != null) {
      state = state.copyWith(selectedPeriod: period);
    }
    if (customStart != null) {
      state = state.copyWith(customStartDate: customStart);
    }
    if (customEnd != null) {
      state = state.copyWith(customEndDate: customEnd);
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dateRange = state.dateRange;

      final report = await _repository.getRevenueReport(
        startDate: dateRange.start,
        endDate: dateRange.end,
      );

      state = state.copyWith(
        report: report,
        isLoading: false,
      );

      // Load comparison data in background
      _loadComparison(dateRange.start, dateRange.end);
      
      // Load hourly sales for today
      if (state.selectedPeriod == ReportPeriod.today) {
        _loadHourlySales(dateRange.start);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load hourly sales data
  Future<void> _loadHourlySales(DateTime date) async {
    state = state.copyWith(isLoadingHourly: true);

    try {
      final hourlyData = await _repository.getHourlySales(date: date);
      state = state.copyWith(
        hourlySales: hourlyData,
        isLoadingHourly: false,
      );
    } catch (e) {
      debugPrint('Failed to load hourly sales: $e');
      state = state.copyWith(isLoadingHourly: false);
    }
  }

  /// Load revenue comparison (current vs previous period)
  Future<void> _loadComparison(DateTime currentStart, DateTime currentEnd) async {
    state = state.copyWith(isLoadingComparison: true);

    try {
      final comparison = await _repository.getRevenueComparison(
        currentStart: currentStart,
        currentEnd: currentEnd,
      );
      state = state.copyWith(
        comparison: comparison,
        isLoadingComparison: false,
      );
    } catch (e) {
      debugPrint('Failed to load comparison: $e');
      state = state.copyWith(isLoadingComparison: false);
    }
  }

  /// Set report period
  Future<void> setPeriod(ReportPeriod period) async {
    await loadRevenueReport(period: period);
  }

  /// Set custom date range
  Future<void> setCustomDateRange(DateTime start, DateTime end) async {
    await loadRevenueReport(
      period: ReportPeriod.custom,
      customStart: start,
      customEnd: end,
    );
  }

  /// Refresh report
  Future<void> refresh() async {
    await loadRevenueReport();
  }

  /// Export report
  Future<String?> exportReport(String format) async {
    try {
      final dateRange = state.dateRange;
      final downloadUrl = await _repository.exportRevenueReport(
        startDate: dateRange.start,
        endDate: dateRange.end,
        format: format,
      );
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to export report: $e');
      return null;
    }
  }
}

/// Provider for revenue reports
final revenueReportsProvider = StateNotifierProvider<RevenueReportsNotifier, RevenueReportState>((ref) {
  return RevenueReportsNotifier(ref);
});

/// Provider for fuel breakdown (convenience)
final fuelBreakdownProvider = Provider<FuelBreakdown?>((ref) {
  return ref.watch(revenueReportsProvider).report?.fuelBreakdown;
});

/// Provider for payment methods breakdown (convenience)
final paymentMethodsProvider = Provider<PaymentMethodBreakdown?>((ref) {
  return ref.watch(revenueReportsProvider).report?.paymentMethods;
});

/// Provider for staff revenue summary (convenience)
final staffRevenueSummaryProvider = Provider<List<StaffRevenueSummary>>((ref) {
  return ref.watch(revenueReportsProvider).report?.staffSummary ?? [];
});

/// Provider for revenue comparison (convenience)
final revenueComparisonProvider = Provider<RevenueComparison?>((ref) {
  return ref.watch(revenueReportsProvider).comparison;
});

/// Provider for hourly sales (convenience)
final hourlySalesProvider = Provider<List<HourlySalesData>>((ref) {
  return ref.watch(revenueReportsProvider).hourlySales;
});

/// Revenue summary card data
class RevenueSummaryCard {
  final String title;
  final double value;
  final double? changePercent;
  final bool isPositive;
  final String icon;

  RevenueSummaryCard({
    required this.title,
    required this.value,
    this.changePercent,
    this.isPositive = true,
    required this.icon,
  });
}

/// Provider for revenue summary cards
final revenueSummaryCardsProvider = Provider<List<RevenueSummaryCard>>((ref) {
  final report = ref.watch(revenueReportsProvider).report;
  final comparison = ref.watch(revenueReportsProvider).comparison;

  if (report == null) return [];

  return [
    RevenueSummaryCard(
      title: 'Total Revenue',
      value: report.totalRevenue,
      changePercent: comparison?.revenueChangePercent,
      isPositive: comparison?.isRevenueUp ?? true,
      icon: 'payments',
    ),
    RevenueSummaryCard(
      title: 'Transactions',
      value: report.totalTransactions.toDouble(),
      changePercent: comparison?.transactionsChangePercent,
      isPositive: comparison?.isTransactionsUp ?? true,
      icon: 'receipt_long',
    ),
    RevenueSummaryCard(
      title: 'Fuel Sold',
      value: report.totalFuelLiters,
      changePercent: comparison?.fuelLitersChangePercent,
      isPositive: comparison?.isFuelLitersUp ?? true,
      icon: 'local_gas_station',
    ),
    RevenueSummaryCard(
      title: 'Avg Transaction',
      value: report.averageTransactionValue,
      icon: 'trending_up',
    ),
  ];
});
