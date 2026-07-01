import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/error/error_handler.dart';
import 'dashboard_alert.dart';

class DashboardAnalyticsRepository {
  final AppDatabase database;
  final ErrorHandler errorHandler;

  DashboardAnalyticsRepository({
    required this.database,
    required this.errorHandler,
  });

  /// Get revenue stats for a specific period
  /// Revenue is calculated based on PAID AMOUNT in bills
  /// Returns a map of Date -> Amount
  Future<RepositoryResult<Map<DateTime, double>>> getRevenueStats({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    String? businessType,
  }) async {
    return await errorHandler.runSafe<Map<DateTime, double>>(() async {
      final query = database.select(database.bills)
        ..where(
          (t) =>
              t.userId.equals(userId) &
              t.deletedAt.isNull() &
              t.billDate.isBiggerOrEqualValue(startDate) &
              t.billDate.isSmallerOrEqualValue(endDate),
        );

      if (businessType != null &&
          businessType != 'All' &&
          businessType.isNotEmpty) {
        query.where((t) => t.businessType.equals(businessType));
      }

      final bills = await query.get();

      // Aggregate by day
      final Map<DateTime, double> revenueMap = {};

      // Initialize all dates in range with 0 to ensure continuous graph
      // (This is crucial for the "Line + Bar" hybrid chart to look good)
      for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
        final d = startDate.add(Duration(days: i));
        final dateKey = DateTime(d.year, d.month, d.day);
        revenueMap[dateKey] = 0.0;
      }

      for (final bill in bills) {
        // We use paidAmount for actual revenue collected
        if (bill.paidAmount > 0) {
          final dateKey = DateTime(
            bill.billDate.year,
            bill.billDate.month,
            bill.billDate.day,
          );
          // Only add if within range (query should handle this, but safety check)
          if (revenueMap.containsKey(dateKey)) {
            revenueMap[dateKey] = (revenueMap[dateKey] ?? 0) + bill.paidAmount;
          }
        }
      }

      return revenueMap;
    }, 'getRevenueStats');
  }

  /// Get expense breakdown by category for a specific month
  Future<RepositoryResult<Map<String, double>>> getExpenseBreakdown({
    required String userId,
    required DateTime monthDate,
  }) async {
    return await errorHandler.runSafe<Map<String, double>>(() async {
      final startOfMonth = DateTime(monthDate.year, monthDate.month, 1);
      final endOfMonth = DateTime(
        monthDate.year,
        monthDate.month + 1,
        0,
        23,
        59,
        59,
      );

      final query = database.select(database.expenses)
        ..where(
          (t) =>
              t.userId.equals(userId) &
              t.deletedAt.isNull() &
              t.expenseDate.isBiggerOrEqualValue(startOfMonth) &
              t.expenseDate.isSmallerOrEqualValue(endOfMonth),
        );

      final expenses = await query.get();

      final Map<String, double> categoryMap = {};
      for (final expense in expenses) {
        // Normalize category name
        final category = expense.category.isNotEmpty
            ? expense.category
            : 'Others';
        categoryMap[category] = (categoryMap[category] ?? 0) + expense.amount;
      }

      return categoryMap;
    }, 'getExpenseBreakdown');
  }

  /// Get recent transactions (Bills)
  Stream<List<BillEntity>> watchRecentTransactions({
    required String userId,
    int limit = 10,
  }) {
    return (database.select(database.bills)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  /// Get upcoming payments (Unpaid bills sorted by estimated due date)
  /// Due date proxy: Bill Date + Credit Period (default 7 days)
  Future<List<BillEntity>> getUpcomingPayments({
    required String userId,
    int limit = 10,
  }) async {
    // Ideally we should join with Customers to get credit period,
    // but for now we fetch unpaid bills and doing in-memory sort is fine for small N
    final unpaidBills =
        await (database.select(database.bills)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.deletedAt.isNull() &
                  t.paidAmount.isSmallerThan(t.grandTotal) & // Not fully paid
                  t.status.isNotIn(['CANCELLED', 'DRAFT']),
            ))
            .get();

    // Filter out fully paid (just in case float math is weird)
    final dueBills = unpaidBills
        .where((b) => (b.grandTotal - b.paidAmount) > 0.1)
        .toList();

    // Sort by "Due Date" (Oldest bills first are most due)
    dueBills.sort((a, b) => a.billDate.compareTo(b.billDate));

    return dueBills.take(limit).toList();
  }

  /// Get consolidated Dashboard Alerts
  /// Combines Low Stock, Overdue Payments, and Tax alerts
  Future<List<DashboardAlert>> getDashboardAlerts({
    required String userId,
  }) async {
    final alerts = <DashboardAlert>[];

    // 1. Low Stock Alerts
    final lowStockProducts = await getLowStockAlerts(userId: userId, limit: 5);
    for (final p in lowStockProducts) {
      alerts.add(
        DashboardAlert(
          title: p.stockQuantity <= 0 ? 'Out of Stock' : 'Low Stock',
          message: '${p.name} has only ${p.stockQuantity.toInt()} left',
          type: AlertType.stock,
          severity: p.stockQuantity <= 0
              ? AlertSeverity.critical
              : AlertSeverity.medium,
          relatedId: p.id,
          data: p,
        ),
      );
    }

    // 2. Overdue Payments (Older than 30 days)
    // We already have getUpcomingPayments logic, let's reuse a query
    final overdueBills =
        await (database.select(database.bills)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.deletedAt.isNull() &
                  t.paidAmount.isSmallerThan(t.grandTotal) &
                  t.billDate.isSmallerThanValue(
                    DateTime.now().subtract(const Duration(days: 30)),
                  ) &
                  t.status.isNotIn(['CANCELLED', 'DRAFT']),
            ))
            .get();

    if (overdueBills.isNotEmpty) {
      final totalOverdue = overdueBills.fold(
        0.0,
        (sum, b) => sum + (b.grandTotal - b.paidAmount),
      );

      alerts.add(
        DashboardAlert(
          title: 'Overdue Payments',
          message:
              '${overdueBills.length} invoices are overdue (>30 days). Total: ₹${totalOverdue.toStringAsFixed(0)}',
          type: AlertType.payment,
          severity: AlertSeverity.high,
        ),
      );
    }

    // 3. Tax / GST Alert (Simple logic: If user has Sales > 0 but no GSTIN, maybe warn?)
    // For now, let's just check if there are many "PENDING" bills
    final pendingCount =
        await (database.select(database.bills)..where(
              (t) => t.userId.equals(userId) & t.status.equals('PENDING'),
            ))
            .get()
            .then((l) => l.length);

    if (pendingCount > 10) {
      alerts.add(
        DashboardAlert(
          title: 'Pending Invoices',
          message: 'You have $pendingCount pending invoices. Follow up soon.',
          type: AlertType.system,
          severity: AlertSeverity.low,
        ),
      );
    }

    return alerts;
  }

  /// Get Low Stock Alerts (Helper)
  Future<List<ProductEntity>> getLowStockAlerts({
    required String userId,
    int limit = 5,
  }) async {
    // This logic mimics app_database.dart getLowStockProducts but with a limit
    final products =
        await (database.select(database.products)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.deletedAt.isNull() &
                  t.isActive.equals(true),
            ))
            .get();

    final lowStock = products
        .where((p) => p.stockQuantity <= p.lowStockThreshold)
        .toList();
    // Sort by lowest stock ratio or just absolute quantity? Absolute for now.
    lowStock.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

    return lowStock.take(limit).toList();
  }
}
