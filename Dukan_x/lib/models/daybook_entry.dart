import 'package:dukanx/core/compat/firestore_compat.dart';

/// DayBookEntry - Persisted daily summary for reconciliation.
///
/// The Day Book is the primary ledger showing all transactions for a day.
/// Each entry stores opening and closing cash balances for reconciliation.
///
/// ## Reconciliation Rule
/// Closing Cash = Opening Cash + Cash Sales + Cash Received - Cash Purchases - Cash Paid - Cash Expenses
class DayBookEntry {
  final String id;
  final String businessId;
  final DateTime date;

  /// Cash balance at the start of the day
  final double openingCashBalance;

  /// Cash balance at the end of the day
  final double closingCashBalance;

  /// Computed closing based on transactions (for verification)
  final double? computedClosingBalance;

  // Transaction Summaries
  final double totalSales;
  final double totalCashSales;
  final double totalCreditSales;

  final double totalPurchases;
  final double totalCashPurchases;
  final double totalCreditPurchases;

  final double totalExpenses;
  final double totalCashExpenses;

  final double totalPaymentsReceived;
  final double totalPaymentsMade;

  // Transaction Counts
  final int salesCount;
  final int purchasesCount;
  final int expensesCount;
  final int paymentsReceivedCount;
  final int paymentsMadeCount;

  // Reconciliation Status
  final bool isReconciled;
  final DateTime? reconciledAt;
  final String? reconciledBy;
  final String? reconciliationNotes;

  /// Difference between actual and computed closing (for variance tracking)
  final double? reconciliationDifference;

  final DateTime createdAt;
  final DateTime updatedAt;

  const DayBookEntry({
    required this.id,
    required this.businessId,
    required this.date,
    this.openingCashBalance = 0,
    this.closingCashBalance = 0,
    this.computedClosingBalance,
    this.totalSales = 0,
    this.totalCashSales = 0,
    this.totalCreditSales = 0,
    this.totalPurchases = 0,
    this.totalCashPurchases = 0,
    this.totalCreditPurchases = 0,
    this.totalExpenses = 0,
    this.totalCashExpenses = 0,
    this.totalPaymentsReceived = 0,
    this.totalPaymentsMade = 0,
    this.salesCount = 0,
    this.purchasesCount = 0,
    this.expensesCount = 0,
    this.paymentsReceivedCount = 0,
    this.paymentsMadeCount = 0,
    this.isReconciled = false,
    this.reconciledAt,
    this.reconciledBy,
    this.reconciliationNotes,
    this.reconciliationDifference,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Compute the expected closing balance based on transactions
  double get expectedClosingBalance {
    return openingCashBalance +
        totalCashSales +
        totalPaymentsReceived -
        totalCashPurchases -
        totalPaymentsMade -
        totalCashExpenses;
  }

  /// Variance between actual and expected closing
  double get cashVariance => closingCashBalance - expectedClosingBalance;

  /// Check if there's a significant variance (more than ₹1)
  bool get hasVariance => cashVariance.abs() > 1.0;

  factory DayBookEntry.fromMap(String id, Map<String, dynamic> map) {
    return DayBookEntry(
      id: id,
      businessId: map['businessId'] ?? '',
      date: _parseDate(map['date']) ?? DateTime.now(),
      openingCashBalance: (map['openingCashBalance'] ?? 0).toDouble(),
      closingCashBalance: (map['closingCashBalance'] ?? 0).toDouble(),
      computedClosingBalance: map['computedClosingBalance']?.toDouble(),
      totalSales: (map['totalSales'] ?? 0).toDouble(),
      totalCashSales: (map['totalCashSales'] ?? 0).toDouble(),
      totalCreditSales: (map['totalCreditSales'] ?? 0).toDouble(),
      totalPurchases: (map['totalPurchases'] ?? 0).toDouble(),
      totalCashPurchases: (map['totalCashPurchases'] ?? 0).toDouble(),
      totalCreditPurchases: (map['totalCreditPurchases'] ?? 0).toDouble(),
      totalExpenses: (map['totalExpenses'] ?? 0).toDouble(),
      totalCashExpenses: (map['totalCashExpenses'] ?? 0).toDouble(),
      totalPaymentsReceived: (map['totalPaymentsReceived'] ?? 0).toDouble(),
      totalPaymentsMade: (map['totalPaymentsMade'] ?? 0).toDouble(),
      salesCount: map['salesCount'] ?? 0,
      purchasesCount: map['purchasesCount'] ?? 0,
      expensesCount: map['expensesCount'] ?? 0,
      paymentsReceivedCount: map['paymentsReceivedCount'] ?? 0,
      paymentsMadeCount: map['paymentsMadeCount'] ?? 0,
      isReconciled: map['isReconciled'] ?? false,
      reconciledAt: _parseDate(map['reconciledAt']),
      reconciledBy: map['reconciledBy'],
      reconciliationNotes: map['reconciliationNotes'],
      reconciliationDifference: map['reconciliationDifference']?.toDouble(),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  factory DayBookEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DayBookEntry.fromMap(doc.id, data);
  }

  /// Create an empty entry for a new day
  factory DayBookEntry.forDate(
    String businessId,
    DateTime date,
    double openingBalance,
  ) {
    final now = DateTime.now();
    return DayBookEntry(
      id: '${businessId}_${_dateKey(date)}',
      businessId: businessId,
      date: date,
      openingCashBalance: openingBalance,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'date': date.toIso8601String(),
      'openingCashBalance': openingCashBalance,
      'closingCashBalance': closingCashBalance,
      'computedClosingBalance': computedClosingBalance,
      'totalSales': totalSales,
      'totalCashSales': totalCashSales,
      'totalCreditSales': totalCreditSales,
      'totalPurchases': totalPurchases,
      'totalCashPurchases': totalCashPurchases,
      'totalCreditPurchases': totalCreditPurchases,
      'totalExpenses': totalExpenses,
      'totalCashExpenses': totalCashExpenses,
      'totalPaymentsReceived': totalPaymentsReceived,
      'totalPaymentsMade': totalPaymentsMade,
      'salesCount': salesCount,
      'purchasesCount': purchasesCount,
      'expensesCount': expensesCount,
      'paymentsReceivedCount': paymentsReceivedCount,
      'paymentsMadeCount': paymentsMadeCount,
      'isReconciled': isReconciled,
      'reconciledAt': reconciledAt?.toIso8601String(),
      'reconciledBy': reconciledBy,
      'reconciliationNotes': reconciliationNotes,
      'reconciliationDifference': reconciliationDifference,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'date': Timestamp.fromDate(date),
      'openingCashBalance': openingCashBalance,
      'closingCashBalance': closingCashBalance,
      'computedClosingBalance': computedClosingBalance,
      'totalSales': totalSales,
      'totalCashSales': totalCashSales,
      'totalCreditSales': totalCreditSales,
      'totalPurchases': totalPurchases,
      'totalCashPurchases': totalCashPurchases,
      'totalCreditPurchases': totalCreditPurchases,
      'totalExpenses': totalExpenses,
      'totalCashExpenses': totalCashExpenses,
      'totalPaymentsReceived': totalPaymentsReceived,
      'totalPaymentsMade': totalPaymentsMade,
      'salesCount': salesCount,
      'purchasesCount': purchasesCount,
      'expensesCount': expensesCount,
      'paymentsReceivedCount': paymentsReceivedCount,
      'paymentsMadeCount': paymentsMadeCount,
      'isReconciled': isReconciled,
      'reconciledAt': reconciledAt != null
          ? Timestamp.fromDate(reconciledAt!)
          : null,
      'reconciledBy': reconciledBy,
      'reconciliationNotes': reconciliationNotes,
      'reconciliationDifference': reconciliationDifference,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DayBookEntry copyWith({
    String? id,
    String? businessId,
    DateTime? date,
    double? openingCashBalance,
    double? closingCashBalance,
    double? computedClosingBalance,
    double? totalSales,
    double? totalCashSales,
    double? totalCreditSales,
    double? totalPurchases,
    double? totalCashPurchases,
    double? totalCreditPurchases,
    double? totalExpenses,
    double? totalCashExpenses,
    double? totalPaymentsReceived,
    double? totalPaymentsMade,
    int? salesCount,
    int? purchasesCount,
    int? expensesCount,
    int? paymentsReceivedCount,
    int? paymentsMadeCount,
    bool? isReconciled,
    DateTime? reconciledAt,
    String? reconciledBy,
    String? reconciliationNotes,
    double? reconciliationDifference,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DayBookEntry(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      date: date ?? this.date,
      openingCashBalance: openingCashBalance ?? this.openingCashBalance,
      closingCashBalance: closingCashBalance ?? this.closingCashBalance,
      computedClosingBalance:
          computedClosingBalance ?? this.computedClosingBalance,
      totalSales: totalSales ?? this.totalSales,
      totalCashSales: totalCashSales ?? this.totalCashSales,
      totalCreditSales: totalCreditSales ?? this.totalCreditSales,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalCashPurchases: totalCashPurchases ?? this.totalCashPurchases,
      totalCreditPurchases: totalCreditPurchases ?? this.totalCreditPurchases,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      totalCashExpenses: totalCashExpenses ?? this.totalCashExpenses,
      totalPaymentsReceived:
          totalPaymentsReceived ?? this.totalPaymentsReceived,
      totalPaymentsMade: totalPaymentsMade ?? this.totalPaymentsMade,
      salesCount: salesCount ?? this.salesCount,
      purchasesCount: purchasesCount ?? this.purchasesCount,
      expensesCount: expensesCount ?? this.expensesCount,
      paymentsReceivedCount:
          paymentsReceivedCount ?? this.paymentsReceivedCount,
      paymentsMadeCount: paymentsMadeCount ?? this.paymentsMadeCount,
      isReconciled: isReconciled ?? this.isReconciled,
      reconciledAt: reconciledAt ?? this.reconciledAt,
      reconciledBy: reconciledBy ?? this.reconciledBy,
      reconciliationNotes: reconciliationNotes ?? this.reconciliationNotes,
      reconciliationDifference:
          reconciliationDifference ?? this.reconciliationDifference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  String toString() =>
      'DayBookEntry(date: ${date.toString().substring(0, 10)}, sales: $totalSales, reconciled: $isReconciled)';
}
