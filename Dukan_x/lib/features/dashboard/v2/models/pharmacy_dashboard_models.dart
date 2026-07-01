// ============================================================================
// PHARMACY DASHBOARD DATA MODELS
// ============================================================================
// Maps 1:1 to pharmacy dashboard API responses
// All amounts are in cents (paise) — divided by 100 for display
// ============================================================================

import 'package:equatable/equatable.dart';

// ── KPI Cards Data Models ─────────────────────────────────────────────────────

class PharmacyKpiData {
  final TotalRevenueKpi totalRevenue;
  final NewPatientsKpi newPatients;
  final PrescriptionsFilledKpi prescriptionsFilled;
  final LowStockItemsKpi lowStockItems;

  const PharmacyKpiData({
    required this.totalRevenue,
    required this.newPatients,
    required this.prescriptionsFilled,
    required this.lowStockItems,
  });

  factory PharmacyKpiData.fromJson(Map<String, dynamic> json) {
    return PharmacyKpiData(
      totalRevenue: TotalRevenueKpi.fromJson(json['totalRevenue'] ?? {}),
      newPatients: NewPatientsKpi.fromJson(json['newPatients'] ?? {}),
      prescriptionsFilled: PrescriptionsFilledKpi.fromJson(json['prescriptionsFilled'] ?? {}),
      lowStockItems: LowStockItemsKpi.fromJson(json['lowStockItems'] ?? {}),
    );
  }

  static const empty = PharmacyKpiData(
    totalRevenue: TotalRevenueKpi.empty,
    newPatients: NewPatientsKpi.empty,
    prescriptionsFilled: PrescriptionsFilledKpi.empty,
    lowStockItems: LowStockItemsKpi.empty,
  );
}

class TotalRevenueKpi extends Equatable {
  final int totalCents;
  final double changePercent;
  final String trend; // "up" | "down" | "neutral"
  final bool isEmpty;
  final String? message;

  const TotalRevenueKpi({
    required this.totalCents,
    required this.changePercent,
    required this.trend,
    required this.isEmpty,
    this.message,
  });

  factory TotalRevenueKpi.fromJson(Map<String, dynamic> json) {
    return TotalRevenueKpi(
      totalCents: (json['total'] as num?)?.toInt() ?? 0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0.0,
      trend: json['trend'] as String? ?? 'neutral',
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = TotalRevenueKpi(
    totalCents: 0,
    changePercent: 0.0,
    trend: 'neutral',
    isEmpty: true,
  );

  @override
  List<Object?> get props => [totalCents, changePercent, trend, isEmpty, message];
}

class NewPatientsKpi extends Equatable {
  final int count;
  final double changePercent;
  final bool isEmpty;
  final String? message;

  const NewPatientsKpi({
    required this.count,
    required this.changePercent,
    required this.isEmpty,
    this.message,
  });

  factory NewPatientsKpi.fromJson(Map<String, dynamic> json) {
    return NewPatientsKpi(
      count: (json['count'] as num?)?.toInt() ?? 0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0.0,
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = NewPatientsKpi(
    count: 0,
    changePercent: 0.0,
    isEmpty: true,
  );

  @override
  List<Object?> get props => [count, changePercent, isEmpty, message];
}

class PrescriptionsFilledKpi extends Equatable {
  final int count;
  final double changePercent;
  final bool isEmpty;
  final String? message;

  const PrescriptionsFilledKpi({
    required this.count,
    required this.changePercent,
    required this.isEmpty,
    this.message,
  });

  factory PrescriptionsFilledKpi.fromJson(Map<String, dynamic> json) {
    return PrescriptionsFilledKpi(
      count: (json['count'] as num?)?.toInt() ?? 0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0.0,
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = PrescriptionsFilledKpi(
    count: 0,
    changePercent: 0.0,
    isEmpty: true,
  );

  @override
  List<Object?> get props => [count, changePercent, isEmpty, message];
}

class LowStockItemsKpi extends Equatable {
  final int count;
  final String severity; // "ok" | "warning" | "alert"
  final bool isEmpty;
  final String? message;

  const LowStockItemsKpi({
    required this.count,
    required this.severity,
    required this.isEmpty,
    this.message,
  });

  factory LowStockItemsKpi.fromJson(Map<String, dynamic> json) {
    return LowStockItemsKpi(
      count: (json['count'] as num?)?.toInt() ?? 0,
      severity: json['severity'] as String? ?? 'ok',
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = LowStockItemsKpi(
    count: 0,
    severity: 'ok',
    isEmpty: true,
  );

  @override
  List<Object?> get props => [count, severity, isEmpty, message];
}

// ── Sales Performance Chart Data ─────────────────────────────────────────────

class SalesPerformanceData {
  final List<String> dates;
  final List<double> dailyRevenue;
  final List<double> rollingAverage;
  final bool isEmpty;
  final String? message;

  const SalesPerformanceData({
    required this.dates,
    required this.dailyRevenue,
    required this.rollingAverage,
    required this.isEmpty,
    this.message,
  });

  factory SalesPerformanceData.fromJson(Map<String, dynamic> json) {
    return SalesPerformanceData(
      dates: (json['dates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dailyRevenue: (json['daily'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      rollingAverage: (json['average'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = SalesPerformanceData(
    dates: [],
    dailyRevenue: [],
    rollingAverage: [],
    isEmpty: true,
  );
}

// ── Prescriptions by Category Data ───────────────────────────────────────────

class PrescriptionsByCategoryData {
  final List<String> categories;
  final List<int> counts;
  final bool isEmpty;
  final String? message;

  const PrescriptionsByCategoryData({
    required this.categories,
    required this.counts,
    required this.isEmpty,
    this.message,
  });

  factory PrescriptionsByCategoryData.fromJson(Map<String, dynamic> json) {
    return PrescriptionsByCategoryData(
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      counts: (json['counts'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = PrescriptionsByCategoryData(
    categories: [],
    counts: [],
    isEmpty: true,
  );
}

// ── Top Selling Products Data ────────────────────────────────────────────────

class TopSellingProduct {
  final String name;
  final int qtySold;
  final int revenueCents;

  const TopSellingProduct({
    required this.name,
    required this.qtySold,
    required this.revenueCents,
  });

  factory TopSellingProduct.fromJson(Map<String, dynamic> json) {
    return TopSellingProduct(
      name: json['name'] as String? ?? '',
      qtySold: (json['qty'] as num?)?.toInt() ?? 0,
      revenueCents: (json['revenue'] as num?)?.toInt() ?? 0,
    );
  }
}

class TopSellingProductsData {
  final List<TopSellingProduct> products;
  final bool isEmpty;
  final String? message;

  const TopSellingProductsData({
    required this.products,
    required this.isEmpty,
    this.message,
  });

  factory TopSellingProductsData.fromJson(Map<String, dynamic> json) {
    return TopSellingProductsData(
      products: (json['products'] as List<dynamic>?)
              ?.map((e) => TopSellingProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = TopSellingProductsData(
    products: [],
    isEmpty: true,
  );
}

// ── Inventory Status Data ───────────────────────────────────────────────────

class InventoryStatusData {
  final double inStockPercent;
  final double lowStockPercent;
  final double outOfStockPercent;
  final bool isEmpty;
  final String? message;

  const InventoryStatusData({
    required this.inStockPercent,
    required this.lowStockPercent,
    required this.outOfStockPercent,
    required this.isEmpty,
    this.message,
  });

  factory InventoryStatusData.fromJson(Map<String, dynamic> json) {
    return InventoryStatusData(
      inStockPercent: (json['inStock'] as num?)?.toDouble() ?? 0.0,
      lowStockPercent: (json['lowStock'] as num?)?.toDouble() ?? 0.0,
      outOfStockPercent: (json['outOfStock'] as num?)?.toDouble() ?? 0.0,
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = InventoryStatusData(
    inStockPercent: 0.0,
    lowStockPercent: 0.0,
    outOfStockPercent: 0.0,
    isEmpty: true,
  );
}

// ── Low Stock Alerts Data ───────────────────────────────────────────────────

class LowStockItem {
  final String id;
  final String name;
  final int qty;
  final int reorderPoint;
  final String status; // "critical" | "warning"

  const LowStockItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.reorderPoint,
    required this.status,
  });

  factory LowStockItem.fromJson(Map<String, dynamic> json) {
    return LowStockItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      reorderPoint: (json['reorderPoint'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'warning',
    );
  }
}

class LowStockAlertsData {
  final List<LowStockItem> items;
  final bool isEmpty;
  final String? message;

  const LowStockAlertsData({
    required this.items,
    required this.isEmpty,
    this.message,
  });

  factory LowStockAlertsData.fromJson(Map<String, dynamic> json) {
    return LowStockAlertsData(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => LowStockItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = LowStockAlertsData(
    items: [],
    isEmpty: true,
  );
}

// ── Recent Activity Data ───────────────────────────────────────────────────

class ActivityItem {
  final String type; // "sale" | "prescription" | "stock_update" | "new_patient"
  final String description;
  final String timestamp;
  final String actor;

  const ActivityItem({
    required this.type,
    required this.description,
    required this.timestamp,
    required this.actor,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      type: json['type'] as String? ?? 'unknown',
      description: json['description'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      actor: json['actor'] as String? ?? 'System',
    );
  }
}

class RecentActivityData {
  final List<ActivityItem> activities;
  final bool isEmpty;
  final String? message;

  const RecentActivityData({
    required this.activities,
    required this.isEmpty,
    this.message,
  });

  factory RecentActivityData.fromJson(Map<String, dynamic> json) {
    return RecentActivityData(
      activities: (json['activities'] as List<dynamic>?)
              ?.map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = RecentActivityData(
    activities: [],
    isEmpty: true,
  );
}

// ── Patient Feedback Data ───────────────────────────────────────────────────

class PatientFeedbackData {
  final double averageRating;
  final List<double> trend; // Last 30 days trend
  final bool isEmpty;
  final String? message;

  const PatientFeedbackData({
    required this.averageRating,
    required this.trend,
    required this.isEmpty,
    this.message,
  });

  factory PatientFeedbackData.fromJson(Map<String, dynamic> json) {
    return PatientFeedbackData(
      averageRating: (json['average'] as num?)?.toDouble() ?? 0.0,
      trend: (json['trend'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      isEmpty: json['isEmpty'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static const empty = PatientFeedbackData(
    averageRating: 0.0,
    trend: [],
    isEmpty: true,
  );
}

// ── Date Range Filter Model ─────────────────────────────────────────────────

enum DateRangeFilter {
  last7Days('Last 7 Days', 7),
  last30Days('Last 30 Days', 30),
  last90Days('Last 90 Days', 90),
  custom('Custom', 0);

  const DateRangeFilter(this.displayName, this.days);
  
  final String displayName;
  final int days;
}

class PharmacyDashboardFilters {
  final DateRangeFilter dateRange;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const PharmacyDashboardFilters({
    required this.dateRange,
    this.customStartDate,
    this.customEndDate,
  });

  PharmacyDashboardFilters copyWith({
    DateRangeFilter? dateRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) {
    return PharmacyDashboardFilters(
      dateRange: dateRange ?? this.dateRange,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
    );
  }

  Map<String, String> toApiParams() {
    switch (dateRange) {
      case DateRangeFilter.last7Days:
        return {'range': 'last7days'};
      case DateRangeFilter.last30Days:
        return {'range': 'last30days'};
      case DateRangeFilter.last90Days:
        return {'range': 'last90days'};
      case DateRangeFilter.custom:
        if (customStartDate != null && customEndDate != null) {
          return {
            'startDate': customStartDate!.toIso8601String().split('T')[0],
            'endDate': customEndDate!.toIso8601String().split('T')[0],
          };
        }
        return {'range': 'last30days'}; // fallback
    }
  }

  static const defaultFilters = PharmacyDashboardFilters(
    dateRange: DateRangeFilter.last30Days,
  );
}
