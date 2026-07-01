// ============================================================================
// DAILY SNAPSHOT SERVICE
// ============================================================================
// Aggregates daily business metrics for dashboard and analytics.
// Auto-generates end-of-day snapshots with sales, receipts, expenses.
//
// Usage:
// - Dashboard: Display today's real-time metrics
// - Reports: Historical daily summaries
// - Analytics: Trend analysis over time
// ============================================================================

import '../di/service_locator.dart';
import '../repository/bills_repository.dart';
import '../repository/expenses_repository.dart';
import 'event_dispatcher.dart';

/// Daily snapshot model for UI
class DailySnapshot {
  final String date; // YYYY-MM-DD format
  final double totalSales;
  final double totalReceipts;
  final double totalExpenses;
  final double netCashFlow;
  final int invoiceCount;
  final int customerCount;
  final double avgInvoiceValue;
  final DateTime generatedAt;

  DailySnapshot({
    required this.date,
    required this.totalSales,
    required this.totalReceipts,
    required this.totalExpenses,
    required this.netCashFlow,
    required this.invoiceCount,
    required this.customerCount,
    required this.avgInvoiceValue,
    required this.generatedAt,
  });

  /// Profit/loss for the day
  double get profit => totalSales - totalExpenses;

  /// Outstanding added today (sales - receipts)
  double get outstandingAdded => totalSales - totalReceipts;

  /// Check if day was profitable
  bool get isProfitable => profit > 0;

  /// Empty snapshot for when no data exists
  factory DailySnapshot.empty(String date) {
    return DailySnapshot(
      date: date,
      totalSales: 0,
      totalReceipts: 0,
      totalExpenses: 0,
      netCashFlow: 0,
      invoiceCount: 0,
      customerCount: 0,
      avgInvoiceValue: 0,
      generatedAt: DateTime.now(),
    );
  }

  @override
  String toString() =>
      'DailySnapshot($date: sales=₹$totalSales, receipts=₹$totalReceipts)';
}

/// Service for generating and retrieving daily business snapshots
class DailySnapshotService {
  final BillsRepository _billsRepo;
  final ExpensesRepository _expensesRepo;

  DailySnapshotService({
    BillsRepository? billsRepo,
    ExpensesRepository? expensesRepo,
  }) : _billsRepo = billsRepo ?? sl<BillsRepository>(),
       _expensesRepo = expensesRepo ?? sl<ExpensesRepository>();

  /// Generate snapshot for a specific date
  ///
  /// Aggregates all transactions from that day.
  Future<DailySnapshot> generateSnapshot(String userId, DateTime date) async {
    final dateStr = _formatDate(date);
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get all bills for the day
    final billsResult = await _billsRepo.getAll(userId: userId);
    final allBills = billsResult.data ?? [];

    // Filter bills for the specific day using `date` field
    final todayBills = allBills
        .where(
          (b) =>
              b.date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
              b.date.isBefore(endOfDay),
        )
        .toList();

    // Calculate sales metrics
    double totalSales = 0;
    double totalReceipts = 0;
    final customerIds = <String>{};

    for (final bill in todayBills) {
      totalSales += bill.grandTotal;
      totalReceipts += bill.paidAmount;
      if (bill.customerId.isNotEmpty) {
        customerIds.add(bill.customerId);
      }
    }

    // Get expenses for the day
    double totalExpenses = 0;
    try {
      final expensesResult = await _expensesRepo.getAll(userId: userId);
      if (expensesResult.data != null) {
        for (final expense in expensesResult.data!) {
          // Filter by date
          if (expense.date.isAfter(
                startOfDay.subtract(const Duration(seconds: 1)),
              ) &&
              expense.date.isBefore(endOfDay)) {
            totalExpenses += expense.amount;
          }
        }
      }
    } catch (e) {
      // Expenses might not exist for the day
    }

    // Calculate derived metrics
    final netCashFlow = totalReceipts - totalExpenses;
    final avgInvoiceValue = todayBills.isEmpty
        ? 0.0
        : totalSales / todayBills.length;

    // Create snapshot
    final snapshot = DailySnapshot(
      date: dateStr,
      totalSales: totalSales,
      totalReceipts: totalReceipts,
      totalExpenses: totalExpenses,
      netCashFlow: netCashFlow,
      invoiceCount: todayBills.length,
      customerCount: customerIds.length,
      avgInvoiceValue: avgInvoiceValue,
      generatedAt: DateTime.now(),
    );

    // Dispatch event
    EventDispatcher.instance.dispatch(BusinessEvent.dailySnapshotGenerated, {
      'date': dateStr,
      'totalSales': totalSales,
      'totalReceipts': totalReceipts,
    }, userId: userId);

    return snapshot;
  }

  /// Get today's snapshot (real-time calculation)
  Future<DailySnapshot> getTodaySnapshot(String userId) async {
    return generateSnapshot(userId, DateTime.now());
  }

  /// Get snapshot for a specific date
  Future<DailySnapshot> getSnapshot(String userId, DateTime date) async {
    return generateSnapshot(userId, date);
  }

  /// Get snapshots for date range (for charts/trends)
  Future<List<DailySnapshot>> getSnapshots(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshots = <DailySnapshot>[];
    var current = startDate;

    while (current.isBefore(endDate) || _isSameDay(current, endDate)) {
      final snapshot = await getSnapshot(userId, current);
      snapshots.add(snapshot);
      current = current.add(const Duration(days: 1));
    }

    return snapshots;
  }

  /// Get last N days of snapshots
  Future<List<DailySnapshot>> getLastNDays(String userId, int days) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));
    return getSnapshots(userId, startDate, endDate);
  }

  /// Compare today with yesterday
  Future<Map<String, dynamic>> getTodayVsYesterday(String userId) async {
    final today = await getTodaySnapshot(userId);
    final yesterday = await getSnapshot(
      userId,
      DateTime.now().subtract(const Duration(days: 1)),
    );

    return {
      'today': today,
      'yesterday': yesterday,
      'salesChange': today.totalSales - yesterday.totalSales,
      'salesChangePercent': yesterday.totalSales > 0
          ? ((today.totalSales - yesterday.totalSales) /
                yesterday.totalSales *
                100)
          : 0.0,
      'receiptsChange': today.totalReceipts - yesterday.totalReceipts,
      'invoiceCountChange': today.invoiceCount - yesterday.invoiceCount,
    };
  }

  // =========================================================================
  // Private Helpers
  // =========================================================================

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
