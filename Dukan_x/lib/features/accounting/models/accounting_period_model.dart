/// Accounting Period Model for Financial Year management
///
/// Supports period locking to prevent modifications to closed periods
library;

class AccountingPeriodModel {
  final String id;
  final String userId;
  final String name; // "FY 2025-26", "Q1 2025", "April 2025"
  final DateTime startDate;
  final DateTime endDate;
  final bool isLocked;
  final DateTime? lockedAt;
  final String? lockedByUserId;
  final bool isSynced;
  final DateTime createdAt;

  AccountingPeriodModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isLocked = false,
    this.lockedAt,
    this.lockedByUserId,
    this.isSynced = false,
    required this.createdAt,
  });

  /// Check if a date falls within this period
  bool containsDate(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(endDate.add(const Duration(days: 1)));
  }

  /// Get current financial year period (April to March for India)
  static AccountingPeriodModel currentFinancialYear(String userId) {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    return AccountingPeriodModel(
      id: 'fy_${startYear}_${startYear + 1}',
      userId: userId,
      name: 'FY $startYear-${(startYear + 1) % 100}',
      startDate: DateTime(startYear, 4, 1),
      endDate: DateTime(startYear + 1, 3, 31),
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'isLocked': isLocked,
    'lockedAt': lockedAt?.toIso8601String(),
    'lockedByUserId': lockedByUserId,
    'isSynced': isSynced,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AccountingPeriodModel.fromMap(Map<String, dynamic> map) =>
      AccountingPeriodModel(
        id: map['id'] ?? '',
        userId: map['userId'] ?? '',
        name: map['name'] ?? '',
        startDate: DateTime.parse(
          map['startDate'] ?? DateTime.now().toIso8601String(),
        ),
        endDate: DateTime.parse(
          map['endDate'] ?? DateTime.now().toIso8601String(),
        ),
        isLocked: map['isLocked'] ?? false,
        lockedAt: map['lockedAt'] != null
            ? DateTime.tryParse(map['lockedAt'])
            : null,
        lockedByUserId: map['lockedByUserId'],
        isSynced: map['isSynced'] ?? false,
        createdAt: DateTime.parse(
          map['createdAt'] ?? DateTime.now().toIso8601String(),
        ),
      );

  AccountingPeriodModel copyWith({
    String? id,
    String? userId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isLocked,
    DateTime? lockedAt,
    String? lockedByUserId,
    bool? isSynced,
    DateTime? createdAt,
  }) {
    return AccountingPeriodModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isLocked: isLocked ?? this.isLocked,
      lockedAt: lockedAt ?? this.lockedAt,
      lockedByUserId: lockedByUserId ?? this.lockedByUserId,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
