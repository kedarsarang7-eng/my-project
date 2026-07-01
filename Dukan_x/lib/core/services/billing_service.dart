import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/accounting/money_math.dart';

import '../../../models/bill.dart';
import '../../../models/payment_history.dart';

class BillingService {
  // All operations via ApiClient
  static ApiClient get _api => sl<ApiClient>();

  // Stream daily bills for a specific owner
  // Note: True streaming (WebSocket) requires SyncManager. Here we fall back to polling or future representation
  // if exact socket event isn't available, but we return a Stream that yields the GET response.
  static Stream<List<Bill>> streamDailyBills(
    @Deprecated('ownerId is extracted from JWT by the backend') String? ownerId,
    DateTime date,
  ) async* {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final res = await _api.get(
      '/api/v1/bills',
      queryParameters: {
        'startDate': startOfDay.toUtc().toIso8601String(),
        'endDate': endOfDay.toUtc().toIso8601String(),
      },
    );

    if (res.isSuccess && res.data != null) {
      final list =
          res.data!['items'] as List<dynamic>? ??
          res.data! as List<dynamic>? ??
          [];
      yield list.map((b) => Bill.fromMap(b['id'] ?? b['_id'], b)).toList();
    } else {
      yield [];
    }
  }

  // Calculate daily summary from list of bills
  static DailyBillSummary calculateDailySummary(
    List<Bill> bills,
    DateTime date,
  ) {
    int totalBills = bills.length;
    // Use MoneyMath so the accumulator stays in fixed-precision Decimal
    // until the final rounded toDouble() (clause 2.6).
    final double totalRevenue = MoneyMath.sum(bills.map((b) => b.grandTotal));
    final double totalPaid = MoneyMath.sum(bills.map((b) => b.paidAmount));
    final double totalDues = MoneyMath.sum(
      bills.map((b) => b.grandTotal - b.paidAmount),
    );
    final double cashSales = MoneyMath.sum(
      bills.where((b) => b.paymentType == 'Cash').map((b) => b.grandTotal),
    );
    final double onlineSales = MoneyMath.sum(
      bills.where((b) => b.paymentType == 'Online').map((b) => b.grandTotal),
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
    @Deprecated('ownerId is extracted from JWT by the backend') String? ownerId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final res = await _api.get(
        '/api/v1/bills',
        queryParameters: {
          'startDate': startOfDay.toUtc().toIso8601String(),
          'endDate': endOfDay.toUtc().toIso8601String(),
        },
      );

      List<Bill> bills = [];
      if (res.isSuccess && res.data != null) {
        final list =
            res.data!['items'] as List<dynamic>? ??
            res.data! as List<dynamic>? ??
            [];
        bills = list.map((b) => Bill.fromMap(b['id'] ?? b['_id'], b)).toList();
      }

      return calculateDailySummary(bills, startOfDay);
    } catch (e) {
      rethrow;
    }
  }

  // Get weekly summary
  static Future<Map<String, DailyBillSummary>> getWeeklyBillSummary(
    @Deprecated('ownerId is extracted from JWT by the backend') String? ownerId,
    DateTime startDate,
  ) async {
    return _getSummaryFromBackend(
      startDate,
      startDate.add(const Duration(days: 6)),
    );
  }

  // Get monthly summary
  static Future<Map<String, DailyBillSummary>> getMonthlySummary(
    @Deprecated('ownerId is extracted from JWT by the backend') String? ownerId,
    int year,
    int month,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);
    return _getSummaryFromBackend(startDate, endDate);
  }

  static Future<Map<String, DailyBillSummary>> _getSummaryFromBackend(
    DateTime from,
    DateTime to,
  ) async {
    final summaries = <String, DailyBillSummary>{};
    try {
      // Assuming context holds businessId or API handles it via token/default
      final res = await _api.get(
        '/api/v1/billing/summary',
        queryParameters: {
          // 'businessId': currentBusinessId, // if needed by API wrapper
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
          'groupBy': 'day',
        },
      );

      if (res.isSuccess && res.data != null && res.data!['summary'] != null) {
        final dailyList = res.data!['summary']['daily'] as List<dynamic>? ?? [];
        for (final item in dailyList) {
          final dateStr = item['period'] as String;
          // Example mapping, adjust based on actual DailyBillSummary fields
          summaries[dateStr] = DailyBillSummary(
            date: dateStr,
            totalBills: item['billCount'] ?? 0,
            totalRevenue: (item['revenue'] ?? 0).toDouble(),
            totalPaid: (item['collected'] ?? 0).toDouble(),
            totalDues: (item['pending'] ?? 0).toDouble(),
          );
        }
      }
    } catch (e) {
      // Fallback or handle error
      rethrow;
    }
    return summaries;
  }

  // Get payment history for customer
  static Future<List<PaymentHistory>> getPaymentHistory(
    String customerId,
  ) async {
    try {
      final res = await _api.get(
        '/api/v1/payments',
        queryParameters: {'customerId': customerId},
      );

      if (res.isSuccess && res.data != null) {
        final list =
            res.data!['items'] as List<dynamic>? ??
            res.data! as List<dynamic>? ??
            [];
        return list
            .map((b) => PaymentHistory.fromMap(b['id'] ?? b['_id'], b))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  // Get blacklisted customers
  static Future<List<BlacklistedCustomer>> getBlacklistedCustomers(
    @Deprecated('ownerId extracted from JWT') String? ownerId,
  ) async {
    try {
      final res = await _api.get(
        '/api/v1/customers',
        queryParameters: {'isBlacklisted': 'true'},
      );

      if (res.isSuccess && res.data != null) {
        final list =
            res.data!['items'] as List<dynamic>? ??
            res.data! as List<dynamic>? ??
            [];
        return list.map((data) {
          return BlacklistedCustomer(
            customerId: data['id'] ?? data['_id'],
            customerName: data['name'] ?? '',
            blacklistDate: data['blacklistDate'] != null
                ? DateTime.parse(data['blacklistDate'])
                : DateTime.now(),
            duesAmount: (data['totalDues'] ?? 0).toDouble(),
            reason: data['blacklistReason'] ?? 'Non-payment',
          );
        }).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  // Get blacklist by date range
  static Future<List<BlacklistedCustomer>> getBlacklistByDateRange(
    @Deprecated('ownerId extracted from JWT') String? ownerId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final res = await _api.get(
        '/api/v1/customers',
        queryParameters: {
          'isBlacklisted': 'true',
          'blacklistStartDate': start.toUtc().toIso8601String(),
          'blacklistEndDate': end.toUtc().toIso8601String(),
        },
      );

      if (res.isSuccess && res.data != null) {
        final list =
            res.data!['items'] as List<dynamic>? ??
            res.data! as List<dynamic>? ??
            [];
        return list.map((data) {
          return BlacklistedCustomer(
            customerId: data['id'] ?? data['_id'],
            customerName: data['name'] ?? '',
            blacklistDate: data['blacklistDate'] != null
                ? DateTime.parse(data['blacklistDate'])
                : DateTime.now(),
            duesAmount: (data['totalDues'] ?? 0).toDouble(),
            reason: data['blacklistReason'] ?? 'Non-payment',
          );
        }).toList();
      }
      return [];
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
      await _api.patch(
        '/api/v1/customers/$customerId',
        body: {
          'isBlacklisted': false,
          'blacklistDate': null,
          'blacklistReason': null,
        },
      );
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
      final payment = {
        'customerId': customerId,
        'paymentDate': DateTime.now().toUtc().toIso8601String(),
        'amount': amount,
        'paymentType': method,
        'status': 'Completed',
        'description': 'Manual payment recorded',
      };

      await _api.post('/api/v1/payments', body: payment);
    } catch (e) {
      rethrow;
    }
  }

  // Generate per user report
  static Future<Map<String, dynamic>> generatePerUserReport(
    @Deprecated('ownerId extracted from JWT') String? ownerId,
    String customerId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final req1 = _api.get(
        '/api/v1/bills',
        queryParameters: {
          'customerId': customerId,
          'startDate': start.toUtc().toIso8601String(),
          'endDate': end.toUtc().toIso8601String(),
        },
      );

      final req2 = _api.get(
        '/api/v1/payments',
        queryParameters: {
          'customerId': customerId,
          'startDate': start.toUtc().toIso8601String(),
          'endDate': end.toUtc().toIso8601String(),
        },
      );

      final responses = await Future.wait([req1, req2]);
      final billsRes = responses[0];
      final paymentsRes = responses[1];

      List<Bill> bills = [];
      if (billsRes.isSuccess && billsRes.data != null) {
        final list =
            billsRes.data!['items'] as List<dynamic>? ??
            billsRes.data! as List<dynamic>? ??
            [];
        bills = list.map((b) => Bill.fromMap(b['id'] ?? b['_id'], b)).toList();
      }

      List<PaymentHistory> payments = [];
      if (paymentsRes.isSuccess && paymentsRes.data != null) {
        final list =
            paymentsRes.data!['items'] as List<dynamic>? ??
            paymentsRes.data! as List<dynamic>? ??
            [];
        payments = list
            .map((p) => PaymentHistory.fromMap(p['id'] ?? p['_id'], p))
            .toList();
      }

      // Use MoneyMath so the accumulator stays in fixed-precision Decimal
      // until the final rounded toDouble() (clause 2.6).
      final double totalBilled = MoneyMath.sum(bills.map((b) => b.grandTotal));
      final double totalPaid = MoneyMath.sum(payments.map((p) => p.amount));

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
