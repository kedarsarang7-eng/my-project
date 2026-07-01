// Dashboard V2 Data Models — maps 1:1 to API responses
// All amounts are in cents (paise) — divided by 100 for display

class DashboardSummary {
  final int totalRevenueCents;
  final double revenueChangePercent;
  final String revenueBadge;
  final int overdueCount;
  final int overdueAmountCents;
  final String overdueBadge;
  final int pendingCount;
  final int pendingAmountCents;
  final String pendingBadge;
  final int avgCollectionDays;
  final double collectionChangePercent;
  final String businessType;
  final bool isEmpty;
  final String? message;

  const DashboardSummary({
    required this.totalRevenueCents,
    required this.revenueChangePercent,
    required this.revenueBadge,
    required this.overdueCount,
    required this.overdueAmountCents,
    required this.overdueBadge,
    required this.pendingCount,
    required this.pendingAmountCents,
    required this.pendingBadge,
    required this.avgCollectionDays,
    required this.collectionChangePercent,
    required this.businessType,
    required this.isEmpty,
    this.message,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final revenue = (json['totalRevenueCents'] as num?)?.toInt() ?? 0;
    final overdue = (json['overdueCount'] as num?)?.toInt() ?? 0;
    final pending = (json['pendingCount'] as num?)?.toInt() ?? 0;
    // Derive isEmpty from data when API omits the field
    final apiIsEmpty = json['isEmpty'] as bool?;
    final derivedEmpty = apiIsEmpty ?? (revenue == 0 && overdue == 0 && pending == 0);

    return DashboardSummary(
      totalRevenueCents: revenue,
      revenueChangePercent: (json['revenueChangePercent'] as num?)?.toDouble() ?? 0,
      revenueBadge: json['revenueBadge'] as String? ?? 'Normal',
      overdueCount: overdue,
      overdueAmountCents: (json['overdueAmountCents'] as num?)?.toInt() ?? 0,
      overdueBadge: json['overdueBadge'] as String? ?? 'Normal',
      pendingCount: pending,
      pendingAmountCents: (json['pendingAmountCents'] as num?)?.toInt() ?? 0,
      pendingBadge: json['pendingBadge'] as String? ?? 'Normal',
      avgCollectionDays: (json['avgCollectionDays'] as num?)?.toInt() ?? 0,
      collectionChangePercent: (json['collectionChangePercent'] as num?)?.toDouble() ?? 0,
      businessType: json['businessType'] as String? ?? '',
      isEmpty: derivedEmpty,
      message: json['message'] as String?,
    );
  }

  static const empty = DashboardSummary(
    totalRevenueCents: 0,
    revenueChangePercent: 0,
    revenueBadge: 'Normal',
    overdueCount: 0,
    overdueAmountCents: 0,
    overdueBadge: 'Normal',
    pendingCount: 0,
    pendingAmountCents: 0,
    pendingBadge: 'Normal',
    avgCollectionDays: 0,
    collectionChangePercent: 0,
    businessType: '',
    isEmpty: true,
  );
}

class RevenueChartPoint {
  final String month;
  final String label;
  final int billedCents;
  final int collectedCents;

  const RevenueChartPoint({
    required this.month,
    required this.label,
    required this.billedCents,
    required this.collectedCents,
  });

  factory RevenueChartPoint.fromJson(Map<String, dynamic> json) {
    return RevenueChartPoint(
      month: json['month'] as String? ?? '',
      label: json['label'] as String? ?? '',
      billedCents: (json['billedCents'] as num?)?.toInt() ?? 0,
      collectedCents: (json['collectedCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class RevenueChartData {
  final int months;
  final List<RevenueChartPoint> points;
  final bool isEmpty;
  final String? message;

  const RevenueChartData({
    required this.months,
    required this.points,
    required this.isEmpty,
    this.message,
  });

  factory RevenueChartData.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>?)
            ?.map((e) => RevenueChartPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final apiIsEmpty = json['isEmpty'] as bool?;

    return RevenueChartData(
      months: (json['months'] as num?)?.toInt() ?? 6,
      points: points,
      isEmpty: apiIsEmpty ?? points.isEmpty,
      message: json['message'] as String?,
    );
  }

  static const empty = RevenueChartData(months: 6, points: [], isEmpty: true);
}

class InvoiceDistribution {
  final int totalInvoices;
  final int paid;
  final int pending;
  final int overdue;
  final int paidPercent;
  final int pendingPercent;
  final int overduePercent;
  final bool isEmpty;
  final String? message;

  const InvoiceDistribution({
    required this.totalInvoices,
    required this.paid,
    required this.pending,
    required this.overdue,
    required this.paidPercent,
    required this.pendingPercent,
    required this.overduePercent,
    required this.isEmpty,
    this.message,
  });

  factory InvoiceDistribution.fromJson(Map<String, dynamic> json) {
    final total = (json['totalInvoices'] as num?)?.toInt() ?? 0;
    final apiIsEmpty = json['isEmpty'] as bool?;

    return InvoiceDistribution(
      totalInvoices: total,
      paid: (json['paid'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
      paidPercent: (json['paidPercent'] as num?)?.toInt() ?? 0,
      pendingPercent: (json['pendingPercent'] as num?)?.toInt() ?? 0,
      overduePercent: (json['overduePercent'] as num?)?.toInt() ?? 0,
      isEmpty: apiIsEmpty ?? (total == 0),
      message: json['message'] as String?,
    );
  }

  static const empty = InvoiceDistribution(
    totalInvoices: 0, paid: 0, pending: 0, overdue: 0,
    paidPercent: 0, pendingPercent: 0, overduePercent: 0, isEmpty: true,
  );
}

class RecentInvoice {
  final String invoiceNumber;
  final String customerName;
  final String date;
  final String dueDate;
  final int amountCents;
  final String status;
  final String invoiceId;

  const RecentInvoice({
    required this.invoiceNumber,
    required this.customerName,
    required this.date,
    required this.dueDate,
    required this.amountCents,
    required this.status,
    required this.invoiceId,
  });

  factory RecentInvoice.fromJson(Map<String, dynamic> json) {
    return RecentInvoice(
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Walk-in',
      date: json['date'] as String? ?? '',
      dueDate: json['dueDate'] as String? ?? '',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      invoiceId: json['invoiceId'] as String? ?? '',
    );
  }
}

class RecentInvoicesData {
  final List<RecentInvoice> invoices;
  final bool isEmpty;
  final String? message;

  const RecentInvoicesData({
    required this.invoices,
    required this.isEmpty,
    this.message,
  });

  factory RecentInvoicesData.fromJson(Map<String, dynamic> json) {
    final invoices = (json['invoices'] as List<dynamic>?)
            ?.map((e) => RecentInvoice.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final apiIsEmpty = json['isEmpty'] as bool?;

    return RecentInvoicesData(
      invoices: invoices,
      isEmpty: apiIsEmpty ?? invoices.isEmpty,
      message: json['message'] as String?,
    );
  }

  static const empty = RecentInvoicesData(invoices: [], isEmpty: true);
}

class CashFlowPoint {
  final String month;
  final String label;
  final int cashReserveCents;
  final int forecastCents;

  const CashFlowPoint({
    required this.month,
    required this.label,
    required this.cashReserveCents,
    required this.forecastCents,
  });

  factory CashFlowPoint.fromJson(Map<String, dynamic> json) {
    return CashFlowPoint(
      month: json['month'] as String? ?? '',
      label: json['label'] as String? ?? '',
      cashReserveCents: (json['cashReserveCents'] as num?)?.toInt() ?? 0,
      forecastCents: (json['forecastCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class CashFlowForecastData {
  final List<CashFlowPoint> points;
  final double forecastPercent;
  final bool isEmpty;
  final String? message;

  const CashFlowForecastData({
    required this.points,
    required this.forecastPercent,
    required this.isEmpty,
    this.message,
  });

  factory CashFlowForecastData.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>?)
            ?.map((e) => CashFlowPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final apiIsEmpty = json['isEmpty'] as bool?;

    return CashFlowForecastData(
      points: points,
      forecastPercent: (json['forecastPercent'] as num?)?.toDouble() ?? 0,
      isEmpty: apiIsEmpty ?? points.isEmpty,
      message: json['message'] as String?,
    );
  }

  static const empty = CashFlowForecastData(points: [], forecastPercent: 0, isEmpty: true);
}

class LicenseInfo {
  final bool valid;
  final String status;
  final String plan;
  final List<String> allowedBusinessTypes;
  final String activeBusinessType;
  final String? expiresAt;

  const LicenseInfo({
    required this.valid,
    required this.status,
    required this.plan,
    required this.allowedBusinessTypes,
    required this.activeBusinessType,
    this.expiresAt,
  });

  factory LicenseInfo.fromJson(Map<String, dynamic> json) {
    return LicenseInfo(
      valid: json['valid'] as bool? ?? false,
      status: json['status'] as String? ?? 'unknown',
      plan: json['plan'] as String? ?? 'basic',
      allowedBusinessTypes: (json['allowedBusinessTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      activeBusinessType: json['activeBusinessType'] as String? ?? 'other',
      expiresAt: json['expiresAt'] as String?,
    );
  }
}
