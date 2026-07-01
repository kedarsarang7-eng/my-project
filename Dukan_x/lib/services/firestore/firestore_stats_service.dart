// ============================================================================
// FIRESTORE STATS SERVICE
// ============================================================================
// Domain-specific Firestore operations for Dashboard Stats & Analytics
//
// Author: DukanX Engineering
// Version: 3.0.0
// ============================================================================

import 'dart:async';
import 'package:dukanx/core/compat/firestore_compat.dart';
import '../../models/daily_stats.dart';
import '../../models/purchase_bill.dart';
import '../../models/expense.dart';
import '../../models/stock_item.dart';
import '../../utils/number_utils.dart';

/// Vendor-specific dashboard stats
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

  factory VendorStats.empty() => const VendorStats(
    totalInvoiceValue: 0,
    paidAmount: 0,
    unpaidAmount: 0,
    todayPurchase: 0,
    activeOrders: 0,
  );
}

/// Handles all Firestore operations related to Stats & Analytics
class FirestoreStatsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================================
  // DAILY STATS
  // ============================================================================

  /// Stream aggregated Daily Stats (Sales, Spend, Pending, Low Stock)
  Stream<DailyStats> streamDailyStats(String ownerId) {
    if (ownerId.isEmpty) return Stream.value(DailyStats.empty());

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    // Sales Stream (Bills today)
    final salesStream = _db
        .collection('businesses')
        .doc(ownerId)
        .collection('sales')
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .snapshots()
        .map((snap) {
          double total = 0;
          for (var doc in snap.docs) {
            total += parseDouble(doc.data()['grandTotal']);
          }
          return total;
        });

    // Purchases Stream (Vendor Invoices today)
    final purchasesStream = _db
        .collection('businesses')
        .doc(ownerId)
        .collection('purchases')
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .snapshots()
        .map((snap) {
          double total = 0;
          for (var doc in snap.docs) {
            total += parseDouble(doc.data()['grandTotal']);
          }
          return total;
        });

    // Expenses Stream (Expenses today)
    final expensesStream = _db
        .collection('expenses')
        .where('ownerId', isEqualTo: ownerId)
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .snapshots()
        .map((snap) {
          double total = 0;
          for (var doc in snap.docs) {
            total += parseDouble(doc.data()['amount']);
          }
          return total;
        });

    // Pending Stream (Total Customer Dues)
    final pendingStream = _db
        .collection('businesses')
        .doc(ownerId)
        .collection('customers')
        .snapshots()
        .map((snap) {
          double total = 0;
          for (var doc in snap.docs) {
            total += parseDouble(doc.data()['totalDues']);
          }
          return total;
        });

    // Low Stock Stream
    final stockStream = _db
        .collection('owners')
        .doc(ownerId)
        .collection('stock')
        .where('quantity', isLessThan: 10)
        .snapshots()
        .map((snap) => snap.size);

    // Combine all streams
    StreamController<DailyStats> controller = StreamController<DailyStats>();

    double sales = 0;
    double purchases = 0;
    double expenses = 0;
    double pending = 0;
    int lowStock = 0;

    void emit() {
      if (!controller.isClosed) {
        controller.add(
          DailyStats(
            todaySales: sales,
            todaySpend: purchases + expenses,
            totalPending: pending,
            lowStockCount: lowStock,
            paidThisMonth: 0, // Not synced yet
            overdueAmount: 0, // Not synced yet
          ),
        );
      }
    }

    final p1 = salesStream.listen((v) {
      sales = v;
      emit();
    });
    final p2 = purchasesStream.listen((v) {
      purchases = v;
      emit();
    });
    final p3 = expensesStream.listen((v) {
      expenses = v;
      emit();
    });
    final p4 = pendingStream.listen((v) {
      pending = v;
      emit();
    });
    final p5 = stockStream.listen((v) {
      lowStock = v;
      emit();
    });

    controller.onCancel = () {
      p1.cancel();
      p2.cancel();
      p3.cancel();
      p4.cancel();
      p5.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ============================================================================
  // VENDOR STATS
  // ============================================================================

  /// Stream Vendor Dashboard Stats
  Stream<VendorStats> streamVendorStats(String ownerId) {
    if (ownerId.isEmpty) return Stream.value(VendorStats.empty());

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    return _db
        .collection('purchase_bills')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) {
          double totalVal = 0;
          double paid = 0;
          double unpaid = 0;
          double todayPurch = 0;
          int active = 0;

          for (var doc in snap.docs) {
            final data = doc.data();
            final gTotal = parseDouble(data['grandTotal']);
            final pAmnt = parseDouble(data['paidAmount']);
            final dateStr = data['date'] as String;

            totalVal += gTotal;
            paid += pAmnt;

            double pendingAmount = (gTotal - pAmnt).clamp(0, double.infinity);
            unpaid += pendingAmount;

            if (pendingAmount > 0) active++;

            if (dateStr.compareTo(startOfDay) >= 0) {
              todayPurch += gTotal;
            }
          }

          return VendorStats(
            totalInvoiceValue: totalVal,
            paidAmount: paid,
            unpaidAmount: unpaid,
            todayPurchase: todayPurch,
            activeOrders: active,
          );
        });
  }

  /// Get total customer dues
  Future<double> totalDues({required String ownerId}) async {
    if (ownerId.isEmpty) return 0.0;

    final snap = await _db
        .collection('businesses')
        .doc(ownerId)
        .collection('customers')
        .get();

    double sum = 0.0;
    for (var d in snap.docs) {
      sum += parseDouble(d.data()['totalDues']);
    }
    return sum;
  }

  // ============================================================================
  // STOCK & INVENTORY
  // ============================================================================

  /// Stream stock items for owner
  Stream<List<StockItem>> streamStock(String ownerId) {
    if (ownerId.isEmpty) return const Stream.empty();

    return _db
        .collection('owners')
        .doc(ownerId)
        .collection('stock')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => StockItem.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Get low stock count
  Future<int> getLowStockCount(String ownerId, {int threshold = 10}) async {
    if (ownerId.isEmpty) return 0;

    final snap = await _db
        .collection('owners')
        .doc(ownerId)
        .collection('stock')
        .where('quantity', isLessThan: threshold)
        .get();

    return snap.size;
  }

  // ============================================================================
  // EXPENSES
  // ============================================================================

  /// Stream expenses for owner
  Stream<List<Expense>> streamExpenses(String ownerId) {
    if (ownerId.isEmpty) return const Stream.empty();

    return _db
        .collection('expenses')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Expense.fromMap(d.id, d.data())).toList(),
        );
  }

  // ============================================================================
  // PURCHASE BILLS
  // ============================================================================

  /// Stream purchase bills for owner
  Stream<List<PurchaseBill>> streamPurchaseBills(String ownerId) {
    if (ownerId.isEmpty) return const Stream.empty();

    return _db
        .collection('purchase_bills')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PurchaseBill.fromMap(d.id, d.data()))
              .toList(),
        );
  }
}
