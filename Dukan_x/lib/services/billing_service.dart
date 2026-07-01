import 'package:dukanx/core/compat/firestore_compat.dart';

import '../models/bill.dart';
import '../models/payment_history.dart';
import '../core/accounting/money_math.dart';

class BillingService {
  static final _db = FirebaseFirestore.instance;

  // Stream daily bills for a specific owner
  static Stream<List<Bill>> streamDailyBills(String ownerId, DateTime date) {
    if (ownerId.isEmpty) return const Stream.empty();

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // Query from owners/{ownerId}/bills
    return _db
        .collection('owners')
        .doc(ownerId)
        .collection('bills')
        .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('date', isLessThanOrEqualTo: endOfDay.toIso8601String())
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Bill.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // Calculate daily summary from list of bills
  static DailyBillSummary calculateDailySummary(
    List<Bill> bills,
    DateTime date,
  ) {
    int totalBills = bills.length;
    final totalRevenue = MoneyMath.sum(bills.map((b) => b.subtotal));
    final totalPaid = MoneyMath.sum(bills.map((b) => b.paidAmount));
    final totalDues = MoneyMath.sum(bills.map((b) => b.subtotal - b.paidAmount));
    final cashSales = MoneyMath.sum(
      bills.where((b) => b.paymentType == 'Cash').map((b) => b.subtotal),
    );
    final onlineSales = MoneyMath.sum(
      bills.where((b) => b.paymentType == 'Online').map((b) => b.subtotal),
    );

    return DailyBillSummary(
      date: date.toString().split(' ')[0],
      totalBills: totalBills,
      totalRevenue: totalRevenue,
      totalPaid: totalPaid,
      totalDues: totalDues,
      cashSales: cashSales,
      onlineSales: onlineSales,
    );
  }

  // Get daily bill summary
  static Future<DailyBillSummary> getDailyBillSummary(
    String ownerId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final billsSnapshot = await _db
          .collection('owners')
          .doc(ownerId)
          .collection('bills')
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .get();

      final bills = billsSnapshot.docs
          .map((doc) => Bill.fromMap(doc.id, doc.data()))
          .toList();

      return calculateDailySummary(bills, startOfDay);
    } catch (e) {
      rethrow;
    }
  }

  // FIX (H-08): Get weekly summary — 1 query instead of 7 sequential
  static Future<Map<String, DailyBillSummary>> getWeeklyBillSummary(
    String ownerId,
    DateTime startDate,
  ) async {
    try {
      final endDate = startDate.add(const Duration(days: 7));
      final billsSnapshot = await _db
          .collection('owners')
          .doc(ownerId)
          .collection('bills')
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .get();

      final allBills = billsSnapshot.docs
          .map((doc) => Bill.fromMap(doc.id, doc.data()))
          .toList();

      // Group bills by day
      final summaries = <String, DailyBillSummary>{};
      for (int i = 0; i < 7; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = date.toString().split(' ')[0];
        final dayBills = allBills.where((b) =>
            b.date.year == date.year &&
            b.date.month == date.month &&
            b.date.day == date.day).toList();
        summaries[dateKey] = calculateDailySummary(dayBills, date);
      }
      return summaries;
    } catch (e) {
      rethrow;
    }
  }

  // FIX (H-08): Get monthly summary — 1 query instead of 31 sequential
  static Future<Map<String, DailyBillSummary>> getMonthlySummary(
    String ownerId,
    int year,
    int month,
  ) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);
      final daysInMonth = endOfMonth.day;

      // Single query for the entire month
      final billsSnapshot = await _db
          .collection('owners')
          .doc(ownerId)
          .collection('bills')
          .where('date', isGreaterThanOrEqualTo: startOfMonth.toIso8601String())
          .where('date', isLessThanOrEqualTo: endOfMonth.toIso8601String())
          .get();

      final allBills = billsSnapshot.docs
          .map((doc) => Bill.fromMap(doc.id, doc.data()))
          .toList();

      // Group by day client-side
      final summaries = <String, DailyBillSummary>{};
      for (int i = 1; i <= daysInMonth; i++) {
        final date = DateTime(year, month, i);
        final dateKey = date.toString().split(' ')[0];
        final dayBills = allBills.where((b) =>
            b.date.year == date.year &&
            b.date.month == date.month &&
            b.date.day == date.day).toList();
        summaries[dateKey] = calculateDailySummary(dayBills, date);
      }
      return summaries;
    } catch (e) {
      rethrow;
    }
  }

  // Get payment history for customer
  static Future<List<PaymentHistory>> getPaymentHistory(
    String customerId,
  ) async {
    try {
      final snapshot = await _db
          .collection('payments')
          .where('customerId', isEqualTo: customerId)
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PaymentHistory.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get blacklisted customers
  static Future<List<BlacklistedCustomer>> getBlacklistedCustomers(
    String ownerId,
  ) async {
    try {
      // Assuming blacklisted customers are stored in a subcollection or queried by status
      // For now, let's query customers with isBlacklisted=true
      // Note: This might need adjustment based on actual Firestore structure for blacklists
      // If blacklists are per-owner, we should query owners/{ownerId}/customers where isBlacklisted=true

      final snapshot = await _db
          .collection('owners')
          .doc(ownerId)
          .collection('customers')
          .where('isBlacklisted', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return BlacklistedCustomer(
          customerId: doc.id,
          customerName: data['name'] ?? '',
          blacklistDate: data['blacklistDate'] != null
              ? DateTime.parse(data['blacklistDate'])
              : DateTime.now(),
          duesAmount: (data['totalDues'] ?? 0).toDouble(),
          reason: data['blacklistReason'] ?? 'Non-payment',
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get blacklist by date range
  static Future<List<BlacklistedCustomer>> getBlacklistByDateRange(
    String ownerId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snapshot = await _db
          .collection('owners')
          .doc(ownerId)
          .collection('customers')
          .where('isBlacklisted', isEqualTo: true)
          .where(
            'blacklistDate',
            isGreaterThanOrEqualTo: start.toIso8601String(),
          )
          .where('blacklistDate', isLessThanOrEqualTo: end.toIso8601String())
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return BlacklistedCustomer(
          customerId: doc.id,
          customerName: data['name'] ?? '',
          blacklistDate: data['blacklistDate'] != null
              ? DateTime.parse(data['blacklistDate'])
              : DateTime.now(),
          duesAmount: (data['totalDues'] ?? 0).toDouble(),
          reason: data['blacklistReason'] ?? 'Non-payment',
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Remove from blacklist
  static Future<void> removeFromBlacklist(
    String ownerId,
    String customerId,
  ) async {
    try {
      await _db
          .collection('owners')
          .doc(ownerId)
          .collection('customers')
          .doc(customerId)
          .update({
            'isBlacklisted': false,
            'blacklistDate': null,
            'blacklistReason': null,
          });
    } catch (e) {
      rethrow;
    }
  }

  // Record payment
  static Future<void> recordPayment(
    String ownerId,
    String customerId,
    double amount,
    String method,
  ) async {
    try {
      final paymentRef = _db.collection('payments').doc();
      final payment = PaymentHistory(
        id: paymentRef.id,
        customerId: customerId,
        paymentDate: DateTime.now(),
        amount: amount,
        paymentType: method,
        status: 'Completed',
        description: 'Manual payment recorded',
      );

      await paymentRef.set(payment.toMap());

      // Update customer dues
      final customerRef = _db
          .collection('owners')
          .doc(ownerId)
          .collection('customers')
          .doc(customerId);

      await _db.runTransaction((tx) async {
        final doc = await tx.get(customerRef);
        if (doc.exists) {
          final currentDues = (doc.data()?['totalDues'] ?? 0).toDouble();
          final newDues = (currentDues - amount).clamp(0.0, double.infinity);
          tx.update(customerRef, {'totalDues': newDues});
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  // Generate per user report
  static Future<Map<String, dynamic>> generatePerUserReport(
    String ownerId,
    String customerId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      // Fetch bills
      final billsSnap = await _db
          .collection('owners')
          .doc(ownerId)
          .collection('customers')
          .doc(customerId)
          .collection('bills')
          .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('date', isLessThanOrEqualTo: end.toIso8601String())
          .get();

      final bills = billsSnap.docs
          .map((doc) => Bill.fromMap(doc.id, doc.data()))
          .toList();

      // Fetch payments
      final paymentsSnap = await _db
          .collection('payments')
          .where('customerId', isEqualTo: customerId)
          .where('paymentDate', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('paymentDate', isLessThanOrEqualTo: end.toIso8601String())
          .get();

      final payments = paymentsSnap.docs
          .map((doc) => PaymentHistory.fromMap(doc.id, doc.data()))
          .toList();

      final totalBilled = MoneyMath.sum(bills.map((b) => b.subtotal));
      final totalPaid = MoneyMath.sum(payments.map((p) => p.amount));

      return {
        'bills': bills,
        'payments': payments,
        'totalBilled': totalBilled,
        'totalPaid': totalPaid,
      };
    } catch (e) {
      rethrow;
    }
  }
}
