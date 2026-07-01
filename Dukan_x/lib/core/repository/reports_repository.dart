// ============================================================================
// REPORTS REPOSITORY - OFFLINE-FIRST AGGREGATOR
// ============================================================================
// Aggregates data from multiple tables for dashboards and analytics
//
// Author: DukanX Engineering
// Version: 1.0.1
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';

import '../database/app_database.dart';
import '../error/error_handler.dart';
import '../../models/daily_stats.dart';

/// Computes an accurate today-vs-yesterday percentage change for a metric.
///
/// Returns null (i.e. "no comparable trend") when [previous] <= 0, since a
/// percentage change is meaningless without prior data. When [invert] is true
/// (e.g. for dues, where a decrease is good), the sign is flipped so the badge
/// colour reflects whether the change is favourable rather than raw up/down.
double? trendPercent({
  required double current,
  required double previous,
  bool invert = false,
}) {
  if (previous <= 0) return null;
  final raw = ((current - previous) / previous) * 100;
  return invert ? -raw : raw;
}

class ReportsRepository {
  final AppDatabase database;
  final ErrorHandler errorHandler;

  ReportsRepository({required this.database, required this.errorHandler});

  /// Watch Daily Dashboard Stats
  /// Aggregates:
  /// - Today's Sales from [bills]
  /// - Today's Spend from [purchaseOrders]
  /// - Total Pending from [customers]
  /// - Low Stock count from [products]
  Stream<DailyStats> watchDailyStats(String userId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // 1. Stream Sales (exclude deleted bills)
    final salesStream =
        (database.selectOnly(database.bills)
              ..addColumns([database.bills.grandTotal.sum()])
              ..where(
                database.bills.userId.equals(userId) &
                    database.bills.billDate.isBiggerOrEqualValue(todayStart) &
                    database.bills.billDate.isSmallerThanValue(todayEnd) &
                    database.bills.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map((row) => row?.read(database.bills.grandTotal.sum()) ?? 0.0);

    // 2. Stream Purchases (Spend) (exclude deleted purchases)
    final spendStream =
        (database.selectOnly(database.purchaseOrders)
              ..addColumns([database.purchaseOrders.totalAmount.sum()])
              ..where(
                database.purchaseOrders.userId.equals(userId) &
                    database.purchaseOrders.purchaseDate.isBiggerOrEqualValue(
                      todayStart,
                    ) &
                    database.purchaseOrders.purchaseDate.isSmallerThanValue(
                      todayEnd,
                    ) &
                    database.purchaseOrders.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map(
              (row) =>
                  row?.read(database.purchaseOrders.totalAmount.sum()) ?? 0.0,
            );

    // 3. Stream Total Pending Dues (from customers table, exclude deleted)
    final pendingStream =
        (database.selectOnly(database.customers)
              ..addColumns([database.customers.totalDues.sum()])
              ..where(
                database.customers.userId.equals(userId) &
                    database.customers.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map((row) => row?.read(database.customers.totalDues.sum()) ?? 0.0);

    // 4. Stream Low Stock Count
    final lowStockStream =
        (database.selectOnly(database.products)
              ..addColumns([database.products.id.count()])
              ..where(
                database.products.userId.equals(userId) &
                    database.products.stockQuantity.isSmallerOrEqual(
                      database.products.lowStockThreshold,
                    ),
              ))
            .watchSingleOrNull()
            .map((row) => row?.read(database.products.id.count()) ?? 0);

    // 5. Stream Paid This Month
    final startOfMonth = DateTime(now.year, now.month, 1);
    final paidInMonthStream =
        (database.selectOnly(database.bills)
              ..addColumns([database.bills.paidAmount.sum()])
              ..where(
                database.bills.userId.equals(userId) &
                    database.bills.billDate.isBiggerOrEqualValue(startOfMonth) &
                    database.bills.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map((row) => row?.read(database.bills.paidAmount.sum()) ?? 0.0);

    // 6. Overdue (Due Date < Now AND Status != 'PAID') (Simplified: Pending Dues from Customer Table is best proxy for now)
    // For strict overdue, we'd need due_date logic. Assuming totalPending covers it.
    // If we want detailed overdue bills:
    // final overdueStream = ...
    // Let's reuse totalPending as 'Outstanding' and use it for Overdue if strict calc is expensive or messy.
    // But UI requests "Overdue Amount". Let's try to query bills with due_date if it exists (it doesn't seem to be in migration).
    // Reviewing tables.dart again... 'dueDate' IS in Bills table definition (line 132).
    // So we CAN query it.
    final overdueStream =
        (database.selectOnly(database.bills)
              ..addColumns([
                (database.bills.grandTotal - database.bills.paidAmount).sum(),
              ])
              ..where(
                database.bills.userId.equals(userId) &
                    database.bills.dueDate.isSmallerThanValue(now) &
                    database.bills.status.isNotIn([
                      'PAID',
                      'CANCELLED',
                      'DRAFT',
                    ]) &
                    database.bills.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map(
              (row) =>
                  row?.read(
                    (database.bills.grandTotal - database.bills.paidAmount)
                        .sum(),
                  ) ??
                  0.0,
            );

    // Combine all streams using rxdart
    return Rx.combineLatest6(
      salesStream,
      spendStream,
      pendingStream,
      lowStockStream,
      paidInMonthStream,
      overdueStream,
      (sales, spend, pending, lowStock, paidMonth, overdue) => DailyStats(
        todaySales: sales,
        todaySpend: spend,
        totalPending: pending,
        lowStockCount: lowStock,
        paidThisMonth: paidMonth,
        overdueAmount: overdue,
      ),
    ).distinct();
  }

  /// 🆕 IMPROVEMENT: Real-Time Profit Dashboard
  ///
  /// Watches today's profit in real-time by streaming:
  /// - Today's Sales (revenue)
  /// - Today's COGS (cost of goods sold from bills)
  /// - Today's Purchases (direct costs)
  ///
  /// Formula: Gross Profit = Sales - COGS
  Stream<ProfitDashboard> watchTodaysProfit(String userId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // 1. Stream Today's Sales (Revenue)
    final salesStream =
        (database.selectOnly(database.bills)
              ..addColumns([database.bills.grandTotal.sum()])
              ..where(
                database.bills.userId.equals(userId) &
                    database.bills.billDate.isBiggerOrEqualValue(todayStart) &
                    database.bills.billDate.isSmallerThanValue(todayEnd) &
                    database.bills.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map((row) => row?.read(database.bills.grandTotal.sum()) ?? 0.0);

    // 2. Stream Today's Gross Profit (captured at sale time)
    final grossProfitStream =
        (database.selectOnly(database.bills)
              ..addColumns([database.bills.grossProfit.sum()])
              ..where(
                database.bills.userId.equals(userId) &
                    database.bills.billDate.isBiggerOrEqualValue(todayStart) &
                    database.bills.billDate.isSmallerThanValue(todayEnd) &
                    database.bills.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map((row) => row?.read(database.bills.grossProfit.sum()) ?? 0.0);

    // 3. Stream Today's Purchases (expenses)
    final purchasesStream =
        (database.selectOnly(database.purchaseOrders)
              ..addColumns([database.purchaseOrders.totalAmount.sum()])
              ..where(
                database.purchaseOrders.userId.equals(userId) &
                    database.purchaseOrders.purchaseDate.isBiggerOrEqualValue(
                      todayStart,
                    ) &
                    database.purchaseOrders.purchaseDate.isSmallerThanValue(
                      todayEnd,
                    ) &
                    database.purchaseOrders.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map(
              (row) =>
                  row?.read(database.purchaseOrders.totalAmount.sum()) ?? 0.0,
            );

    // 4. Stream Bill Count for today
    final billCountStream =
        (database.selectOnly(database.bills)
              ..addColumns([database.bills.id.count()])
              ..where(
                database.bills.userId.equals(userId) &
                    database.bills.billDate.isBiggerOrEqualValue(todayStart) &
                    database.bills.billDate.isSmallerThanValue(todayEnd) &
                    database.bills.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map((row) => row?.read(database.bills.id.count()) ?? 0);

    return Rx.combineLatest4(
      salesStream,
      grossProfitStream,
      purchasesStream,
      billCountStream,
      (double sales, double gp, double purchases, int billCount) =>
          ProfitDashboard(
            todaySales: sales,
            todayCogs: sales - gp, // Derive COGS
            todayPurchases: purchases,
            grossProfit: gp,
            netProfit: gp - purchases,
            billCount: billCount,
            profitMargin: sales > 0 ? (gp / sales) * 100 : 0,
          ),
    ).distinct();
  }

  /// Accurate today-vs-yesterday comparison of dashboard KPIs.
  ///
  /// Unlike [watchDailyStats] (which only exposes month-to-date collections and
  /// a `null` customer count), this computes every figure directly from bill
  /// rows for the relevant day, so percentage trends are real:
  /// - Sales / collections for today and yesterday.
  /// - Outstanding dues snapshot at end-of-today and end-of-yesterday
  ///   (sum of grandTotal - paidAmount across all non-deleted bills up to that
  ///   point in time, so the two snapshots are directly comparable).
  /// - Distinct customers billed today and yesterday.
  ///
  /// A [DailyComparison.empty()] is returned on error so the UI can degrade
  /// gracefully (all trend badges simply hide when previous <= 0).
  Future<DailyComparison> getDailyComparison(String userId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = todayStart;

    try {
      // --- Today: sales + collections ---
      final todayAgg = await _sumBills(
        userId: userId,
        from: todayStart,
        to: todayEnd,
      );
      // --- Yesterday: sales + collections ---
      final yestAgg = await _sumBills(
        userId: userId,
        from: yesterdayStart,
        to: yesterdayEnd,
      );

      // --- Distinct customers today / yesterday ---
      final customersToday = await _distinctCustomers(
        userId: userId,
        from: todayStart,
        to: todayEnd,
      );
      final customersYesterday = await _distinctCustomers(
        userId: userId,
        from: yesterdayStart,
        to: yesterdayEnd,
      );

      // --- Outstanding dues snapshot at end-of-today and end-of-yesterday ---
      // A bill contributes its outstanding amount to a snapshot if it was
      // created on or before the snapshot boundary, so the two figures are
      // measured against the same population of bills up to each point.
      final duesToday = await _outstandingDuesUpTo(userId, todayEnd);
      final duesYest = await _outstandingDuesUpTo(userId, yesterdayEnd);

      return DailyComparison(
        todaySales: todayAgg.sales,
        todayCollections: todayAgg.collections,
        yesterdaySales: yestAgg.sales,
        yesterdayCollections: yestAgg.collections,
        duesEndOfToday: duesToday,
        duesEndOfYesterday: duesYest,
        customersToday: customersToday,
        customersYesterday: customersYesterday,
      );
    } catch (_) {
      return DailyComparison.empty();
    }
  }

  /// Sums grandTotal (sales) and paidAmount (collections) for bills in [from, to).
  Future<_BillAggregates> _sumBills({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final query = database.selectOnly(database.bills)
      ..addColumns([
        database.bills.grandTotal.sum(),
        database.bills.paidAmount.sum(),
      ])
      ..where(
        database.bills.userId.equals(userId) &
            database.bills.billDate.isBiggerOrEqualValue(from) &
            database.bills.billDate.isSmallerThanValue(to) &
            database.bills.deletedAt.isNull(),
      );
    final row = await query.getSingleOrNull();
    return _BillAggregates(
      sales: row?.read(database.bills.grandTotal.sum()) ?? 0.0,
      collections: row?.read(database.bills.paidAmount.sum()) ?? 0.0,
    );
  }

  /// Counts distinct (non-null) customerId values billed in [from, to).
  Future<int> _distinctCustomers({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final customerId = database.bills.customerId;
    final distinctCount = customerId.count(distinct: true);
    final query = database.selectOnly(database.bills)
      ..addColumns([distinctCount])
      ..where(
        database.bills.userId.equals(userId) &
            database.bills.billDate.isBiggerOrEqualValue(from) &
            database.bills.billDate.isSmallerThanValue(to) &
            database.bills.deletedAt.isNull() &
            customerId.isNotNull() &
            customerId.equals('').not(),
      );
    final row = await query.getSingleOrNull();
    return row?.read(distinctCount) ?? 0;
  }

  /// Sums outstanding (grandTotal - paidAmount) over all non-deleted bills
  /// created strictly before [boundary]. Used to take a comparable dues
  /// snapshot at end-of-today vs end-of-yesterday.
  Future<double> _outstandingDuesUpTo(
    String userId,
    DateTime boundary,
  ) async {
    final outstanding = (database.bills.grandTotal - database.bills.paidAmount);
    final query = database.selectOnly(database.bills)
      ..addColumns([outstanding.sum()])
      ..where(
        database.bills.userId.equals(userId) &
            database.bills.billDate.isSmallerThanValue(boundary) &
            database.bills.deletedAt.isNull(),
      );
    final row = await query.getSingleOrNull();
    return row?.read(outstanding.sum()) ?? 0.0;
  }

  /// Get Sales Performance for last N days
  Future<RepositoryResult<List<Map<String, dynamic>>>> getSalesTrend({
    required String userId,
    int days = 7,
  }) async {
    return await errorHandler.runSafe<List<Map<String, dynamic>>>(() async {
      final startDate = DateTime.now().subtract(Duration(days: days));

      final query = database.select(database.bills)
        ..where(
          (t) =>
              t.userId.equals(userId) &
              t.billDate.isBiggerOrEqualValue(startDate) &
              t.deletedAt.isNull(),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.billDate)]);

      final bills = await query.get();
      final Map<String, double> dailyTotals = {};

      for (var bill in bills) {
        final dateKey =
            "${bill.billDate.year}-${bill.billDate.month}-${bill.billDate.day}";
        dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + bill.grandTotal;
      }

      return dailyTotals.entries
          .map((e) => {'date': e.key, 'value': e.value})
          .toList();
    }, 'getSalesTrend');
  }

  /// Get Detailed Sales Report
  Future<RepositoryResult<List<Map<String, dynamic>>>> getSalesReport({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    return await errorHandler.runSafe<List<Map<String, dynamic>>>(() async {
      final query = database.select(database.bills)
        ..where(
          (t) =>
              t.userId.equals(userId) &
              t.billDate.isBiggerOrEqualValue(start) &
              t.billDate.isSmallerThanValue(end.add(const Duration(days: 1))) &
              t.deletedAt.isNull(),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.billDate)]);

      final bills = await query.get();

      return bills
          .map(
            (b) => {
              'id': b.id,
              'bill_date': b.billDate,
              'bill_number': b.invoiceNumber,
              'customer_name': b.customerName,
              'total_amount': b.grandTotal,
              'status': b.status,
            },
          )
          .toList();
    }, 'getSalesReport');
  }

  /// Get Stock Valuation Report
  Future<RepositoryResult<List<Map<String, dynamic>>>> getStockValuationReport({
    required String userId,
  }) async {
    return await errorHandler.runSafe<List<Map<String, dynamic>>>(() async {
      final query = database.select(database.products)
        ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      final products = await query.get();

      return products
          .map(
            (p) => {
              'name': p.name,
              'stock_qty': p.stockQuantity,
              'price': p.sellingPrice,
              'total_value': p.stockQuantity * p.sellingPrice,
            },
          )
          .toList();
    }, 'getStockValuationReport');
  }

  /// Get Profit & Loss Summary
  Future<RepositoryResult<Map<String, double>>> getProfitLossSummary({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    return await errorHandler.runSafe<Map<String, double>>(() async {
      final endAdjusted = end.add(const Duration(days: 1));

      // 1. Total Sales
      final salesQuery = database.selectOnly(database.bills)
        ..addColumns([database.bills.grandTotal.sum()])
        ..where(
          database.bills.userId.equals(userId) &
              database.bills.billDate.isBiggerOrEqualValue(start) &
              database.bills.billDate.isSmallerThanValue(endAdjusted) &
              database.bills.deletedAt.isNull(),
        );

      final salesResult = await salesQuery.getSingleOrNull();
      final totalSales =
          salesResult?.read(database.bills.grandTotal.sum()) ?? 0.0;

      // 2. Total Purchases (Using PurchaseOrders table if available, or bills if expense logic exists)
      // Assuming PurchaseOrders exists as seen in watchDailyStats
      final purchaseQuery = database.selectOnly(database.purchaseOrders)
        ..addColumns([database.purchaseOrders.totalAmount.sum()])
        ..where(
          database.purchaseOrders.userId.equals(userId) &
              database.purchaseOrders.purchaseDate.isBiggerOrEqualValue(start) &
              database.purchaseOrders.purchaseDate.isSmallerThanValue(
                endAdjusted,
              ) &
              database.purchaseOrders.deletedAt.isNull(),
        );

      final purchaseResult = await purchaseQuery.getSingleOrNull();
      final totalPurchases =
          purchaseResult?.read(database.purchaseOrders.totalAmount.sum()) ??
          0.0;

      final netProfit = totalSales - totalPurchases;

      return {
        'total_sales': totalSales,
        'total_purchases': totalPurchases,
        'net_profit': netProfit,
      };
    }, 'getProfitLossSummary');
  }

  /// Watch Vendor Stats (for BuyFlow Dashboard)
  Stream<VendorStats> watchVendorStats(String userId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // 1. Total Invoice Value & Paid/Unpaid from purchaseOrders
    final purchaseStatsStream =
        (database.selectOnly(database.purchaseOrders)
              ..addColumns([
                database.purchaseOrders.totalAmount.sum(),
                database.purchaseOrders.paidAmount.sum(),
              ])
              ..where(
                database.purchaseOrders.userId.equals(userId) &
                    database.purchaseOrders.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map((row) {
              final total =
                  row?.read(database.purchaseOrders.totalAmount.sum()) ?? 0.0;
              final paid =
                  row?.read(database.purchaseOrders.paidAmount.sum()) ?? 0.0;
              return {
                'total': total,
                'paid': paid,
                'unpaid': (total - paid) < 0 ? 0.0 : (total - paid),
              };
            });

    // 2. Today's Purchase
    final todayPurchaseStream =
        (database.selectOnly(database.purchaseOrders)
              ..addColumns([database.purchaseOrders.totalAmount.sum()])
              ..where(
                database.purchaseOrders.userId.equals(userId) &
                    database.purchaseOrders.purchaseDate.isBiggerOrEqualValue(
                      todayStart,
                    ) &
                    database.purchaseOrders.purchaseDate.isSmallerThanValue(
                      todayEnd,
                    ) &
                    database.purchaseOrders.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map(
              (row) =>
                  row?.read(database.purchaseOrders.totalAmount.sum()) ?? 0.0,
            );

    // 3. Active Orders (Count all non-deleted purchase orders)
    final activeOrdersStream =
        (database.selectOnly(database.purchaseOrders)
              ..addColumns([database.purchaseOrders.id.count()])
              ..where(
                database.purchaseOrders.userId.equals(userId) &
                    database.purchaseOrders.deletedAt.isNull(),
              ))
            .watchSingleOrNull()
            .map((row) => row?.read(database.purchaseOrders.id.count()) ?? 0);

    return Rx.combineLatest3(
      purchaseStatsStream,
      todayPurchaseStream,
      activeOrdersStream,
      (pStats, today, active) => VendorStats(
        totalInvoiceValue: pStats['total']!,
        paidAmount: pStats['paid']!,
        unpaidAmount: pStats['unpaid']!,
        todayPurchase: today,
        activeOrders: active,
      ),
    ).distinct();
  }

  /// Get Product Sales Breakdown (Size/Color wise)
  Future<RepositoryResult<List<Map<String, dynamic>>>>
  getProductSalesBreakdown({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    return await errorHandler.runSafe<List<Map<String, dynamic>>>(() async {
      final query = database.select(database.bills)
        ..where(
          (t) =>
              t.userId.equals(userId) &
              t.billDate.isBiggerOrEqualValue(start) &
              t.billDate.isSmallerThanValue(end.add(const Duration(days: 1))) &
              t.deletedAt.isNull(),
        );

      final bills = await query.get();
      final Map<String, Map<String, dynamic>> grouped = {};

      for (var bill in bills) {
        // Parse items from JSON/Blob if needed, but Bill entity already has items list?
        // Wait, 'bills' from database.select(database.bills) gives BillData (drift class).
        // BillData likely stores items as JSON string or Blob if using type converter.
        // I need to check how items are stored in Drift.
        // 'tables.dart' defines items as 'text().map(const BillItemsConverter())()'.
        // So 'bill.items' should be List<BillItem>.

        List<dynamic> items = [];
        try {
          items = jsonDecode(bill.itemsJson);
        } catch (_) {}

        for (var item in items) {
          // item is Map<String, dynamic>
          final productId = item['productId'];
          final size = item['size'];
          final color = item['color'];
          final brand = item['brand'];
          final productName = item['productName'] ?? 'Unknown';
          final qty = (item['qty'] ?? 0).toDouble();
          final totalAmount = (item['totalAmount'] ?? 0).toDouble();

          final key = "${productId}_${size ?? ''}_${color ?? ''}";

          if (!grouped.containsKey(key)) {
            grouped[key] = {
              'name': productName,
              'size': size,
              'color': color,
              'brand': brand,
              'quantity': 0.0,
              'total': 0.0,
            };
          }

          grouped[key]!['quantity'] += qty;
          grouped[key]!['total'] += totalAmount;
        }
      }

      final result = grouped.values.toList();
      result.sort(
        (a, b) => (b['total'] as double).compareTo(a['total'] as double),
      );
      return result;
    }, 'getProductSalesBreakdown');
  }

  /// Get Category Sales Breakdown
  Future<RepositoryResult<List<Map<String, dynamic>>>>
  getCategorySalesBreakdown({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    return await errorHandler.runSafe<List<Map<String, dynamic>>>(() async {
      final query = database.select(database.billItems).join([
        innerJoin(
          database.bills,
          database.bills.id.equalsExp(database.billItems.billId),
        ),
        leftOuterJoin(
          database.products,
          database.products.id.equalsExp(database.billItems.productId),
        ),
      ]);

      query.where(
        database.bills.userId.equals(userId) &
            database.bills.billDate.isBiggerOrEqualValue(start) &
            database.bills.billDate.isSmallerThanValue(
              end.add(const Duration(days: 1)),
            ) &
            database.bills.deletedAt.isNull(),
      );

      final results = await query.get();
      final Map<String, double> categoryTotals = {};

      for (var row in results) {
        final amount = row.read(database.billItems.totalAmount) ?? 0.0;
        // Use product category if available, or fallback to 'Uncategorized'
        // If product is null (deleted?), try to infer or group as 'Others'
        String category = 'Uncategorized';
        final product = row.readTableOrNull(database.products);
        if (product != null &&
            product.category != null &&
            product.category!.isNotEmpty) {
          category = product.category!;
        }

        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      }

      final List<Map<String, dynamic>> finalResult = categoryTotals.entries
          .map((e) => {'category': e.key, 'total': e.value})
          .toList();

      // Sort by total desc
      finalResult.sort(
        (a, b) => (b['total'] as double).compareTo(a['total'] as double),
      );

      return finalResult;
    }, 'getCategorySalesBreakdown');
  }
}

/// Internal aggregate pair returned by [ReportsRepository._sumBills].
class _BillAggregates {
  final double sales;
  final double collections;
  const _BillAggregates({required this.sales, required this.collections});
}
