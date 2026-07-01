import 'package:dukanx/core/compat/firestore_compat.dart';

/// AccountingPeriod - Represents a financial period that can be locked.
///
/// Period locking prevents modifications to transactions dated within
/// a locked period, ensuring data integrity after month/year close.
///
/// Common use cases:
/// - Monthly close for GST filing (GSTR-3B)
/// - Quarterly close
/// - Annual close (financial year end)
class AccountingPeriod {
  final String id;
  final String businessId;
  final String name; // e.g., "April 2025", "Q1 FY2025-26"
  final DateTime startDate;
  final DateTime endDate;
  final PeriodType type;
  final bool isLocked;
  final DateTime? lockedAt;
  final String? lockedBy;
  final String? lockReason;

  // Summary at time of lock (for quick reference)
  final double? closingSalesTotal;
  final double? closingPurchaseTotal;
  final double? closingCashBalance;

  final DateTime createdAt;

  const AccountingPeriod({
    required this.id,
    required this.businessId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.isLocked = false,
    this.lockedAt,
    this.lockedBy,
    this.lockReason,
    this.closingSalesTotal,
    this.closingPurchaseTotal,
    this.closingCashBalance,
    required this.createdAt,
  });

  /// Check if a transaction date falls within this period.
  bool containsDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
  }

  /// Check if modifications are allowed for a given date.
  /// Returns false if the period is locked.
  bool canModify(DateTime transactionDate) {
    if (!isLocked) return true;
    return !containsDate(transactionDate);
  }

  factory AccountingPeriod.fromMap(String id, Map<String, dynamic> map) {
    return AccountingPeriod(
      id: id,
      businessId: map['businessId'] ?? '',
      name: map['name'] ?? '',
      startDate: _parseDate(map['startDate']) ?? DateTime.now(),
      endDate: _parseDate(map['endDate']) ?? DateTime.now(),
      type: PeriodType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PeriodType.monthly,
      ),
      isLocked: map['isLocked'] ?? false,
      lockedAt: _parseDate(map['lockedAt']),
      lockedBy: map['lockedBy'],
      lockReason: map['lockReason'],
      closingSalesTotal: map['closingSalesTotal']?.toDouble(),
      closingPurchaseTotal: map['closingPurchaseTotal']?.toDouble(),
      closingCashBalance: map['closingCashBalance']?.toDouble(),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  factory AccountingPeriod.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AccountingPeriod.fromMap(doc.id, data);
  }

  /// Create a monthly period for a given month.
  factory AccountingPeriod.forMonth(String businessId, int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0); // Last day of month
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return AccountingPeriod(
      id: '${businessId}_${year}_${month.toString().padLeft(2, '0')}',
      businessId: businessId,
      name: '${monthNames[month - 1]} $year',
      startDate: start,
      endDate: end,
      type: PeriodType.monthly,
      createdAt: DateTime.now(),
    );
  }

  /// Create a financial year period.
  factory AccountingPeriod.forFinancialYear(
    String businessId,
    int startYear,
    int startMonth,
  ) {
    final start = DateTime(startYear, startMonth, 1);
    final end = DateTime(startYear + 1, startMonth, 0);

    return AccountingPeriod(
      id: '${businessId}_FY_${startYear}_${startYear + 1}',
      businessId: businessId,
      name: 'FY $startYear-${(startYear + 1) % 100}',
      startDate: start,
      endDate: end,
      type: PeriodType.annual,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'type': type.name,
      'isLocked': isLocked,
      'lockedAt': lockedAt?.toIso8601String(),
      'lockedBy': lockedBy,
      'lockReason': lockReason,
      'closingSalesTotal': closingSalesTotal,
      'closingPurchaseTotal': closingPurchaseTotal,
      'closingCashBalance': closingCashBalance,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'type': type.name,
      'isLocked': isLocked,
      'lockedAt': lockedAt != null ? Timestamp.fromDate(lockedAt!) : null,
      'lockedBy': lockedBy,
      'lockReason': lockReason,
      'closingSalesTotal': closingSalesTotal,
      'closingPurchaseTotal': closingPurchaseTotal,
      'closingCashBalance': closingCashBalance,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AccountingPeriod copyWith({
    String? id,
    String? businessId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    PeriodType? type,
    bool? isLocked,
    DateTime? lockedAt,
    String? lockedBy,
    String? lockReason,
    double? closingSalesTotal,
    double? closingPurchaseTotal,
    double? closingCashBalance,
    DateTime? createdAt,
  }) {
    return AccountingPeriod(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      type: type ?? this.type,
      isLocked: isLocked ?? this.isLocked,
      lockedAt: lockedAt ?? this.lockedAt,
      lockedBy: lockedBy ?? this.lockedBy,
      lockReason: lockReason ?? this.lockReason,
      closingSalesTotal: closingSalesTotal ?? this.closingSalesTotal,
      closingPurchaseTotal: closingPurchaseTotal ?? this.closingPurchaseTotal,
      closingCashBalance: closingCashBalance ?? this.closingCashBalance,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Lock this period with closing balances.
  AccountingPeriod lock({
    required String lockedBy,
    required double salesTotal,
    required double purchaseTotal,
    required double cashBalance,
    String? reason,
  }) {
    return copyWith(
      isLocked: true,
      lockedAt: DateTime.now(),
      lockedBy: lockedBy,
      lockReason: reason ?? 'Period closed',
      closingSalesTotal: salesTotal,
      closingPurchaseTotal: purchaseTotal,
      closingCashBalance: cashBalance,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  String toString() => 'AccountingPeriod(name: $name, locked: $isLocked)';
}

/// Types of accounting periods.
enum PeriodType { monthly, quarterly, annual, custom }

extension PeriodTypeExtension on PeriodType {
  String get displayName {
    switch (this) {
      case PeriodType.monthly:
        return 'Monthly';
      case PeriodType.quarterly:
        return 'Quarterly';
      case PeriodType.annual:
        return 'Annual';
      case PeriodType.custom:
        return 'Custom';
    }
  }
}
