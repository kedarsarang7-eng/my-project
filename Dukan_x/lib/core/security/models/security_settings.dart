// ============================================================================
// SECURITY SETTINGS MODEL
// ============================================================================
// Owner-configurable security settings for fraud prevention.
// These settings control PIN requirements, discount limits, and more.
// ============================================================================

import 'package:dukanx/core/compat/firestore_compat.dart';

/// Security Settings - Owner-configurable fraud prevention settings.
///
/// Created during first-time onboarding and enforced throughout the app.
/// All critical actions reference these settings for authorization.
class SecuritySettings {
  /// Unique identifier (same as businessId for 1:1 mapping)
  final String businessId;

  /// SHA-256 hashed owner PIN (never stored plain text)
  final String ownerPinHash;

  /// Maximum discount percentage allowed without PIN authorization
  /// Default: 10%
  final int maxDiscountPercent;

  /// Bill edit window in minutes after creation
  /// 0 = No edits allowed after save
  /// Default: 0 (strictest)
  final int billEditWindowMinutes;

  /// Cash tolerance limit for daily closing variance
  /// Mismatch beyond this triggers owner notification
  /// Default: ₹100
  final double cashToleranceLimit;

  /// Amount limit above which transactions require approval
  /// Default: ₹10,000
  final double approvalLimitAmount;

  /// Require PIN for refund processing
  final bool requirePinForRefunds;

  /// Require PIN for manual stock adjustments
  final bool requirePinForStockAdjustment;

  /// Require PIN for deleting bills
  final bool requirePinForBillDelete;

  /// Require PIN for period unlock
  final bool requirePinForPeriodUnlock;

  /// Late night billing restriction (hour after which alerts are raised)
  /// null = no restriction, 22 = alerts after 10 PM
  final int? lateNightHour;

  /// Maximum number of bill edits per user per day before alert
  final int maxBillEditsPerDay;

  /// Session expiry in hours
  final int sessionExpiryHours;

  /// Allow single device per user
  final bool enforceOneDevicePerUser;

  /// Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const SecuritySettings({
    required this.businessId,
    required this.ownerPinHash,
    this.maxDiscountPercent = 10,
    this.billEditWindowMinutes = 0,
    this.cashToleranceLimit = 100.0,
    this.approvalLimitAmount = 10000.0,
    this.requirePinForRefunds = true,
    this.requirePinForStockAdjustment = true,
    this.requirePinForBillDelete = true,
    this.requirePinForPeriodUnlock = true,
    this.lateNightHour = 22,
    this.maxBillEditsPerDay = 3,
    this.sessionExpiryHours = 24,
    this.enforceOneDevicePerUser = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create with sensible defaults for new business
  factory SecuritySettings.withDefaults({
    required String businessId,
    required String ownerPinHash,
  }) {
    final now = DateTime.now();
    return SecuritySettings(
      businessId: businessId,
      ownerPinHash: ownerPinHash,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Parse from database entity
  factory SecuritySettings.fromMap(Map<String, dynamic> map) {
    return SecuritySettings(
      businessId: map['businessId'] as String,
      ownerPinHash: map['ownerPinHash'] as String,
      maxDiscountPercent: map['maxDiscountPercent'] as int? ?? 10,
      billEditWindowMinutes: map['billEditWindowMinutes'] as int? ?? 0,
      cashToleranceLimit:
          (map['cashToleranceLimit'] as num?)?.toDouble() ?? 100.0,
      approvalLimitAmount:
          (map['approvalLimitAmount'] as num?)?.toDouble() ?? 10000.0,
      requirePinForRefunds: map['requirePinForRefunds'] as bool? ?? true,
      requirePinForStockAdjustment:
          map['requirePinForStockAdjustment'] as bool? ?? true,
      requirePinForBillDelete: map['requirePinForBillDelete'] as bool? ?? true,
      requirePinForPeriodUnlock:
          map['requirePinForPeriodUnlock'] as bool? ?? true,
      lateNightHour: map['lateNightHour'] as int?,
      maxBillEditsPerDay: map['maxBillEditsPerDay'] as int? ?? 3,
      sessionExpiryHours: map['sessionExpiryHours'] as int? ?? 24,
      enforceOneDevicePerUser: map['enforceOneDevicePerUser'] as bool? ?? false,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Parse from Firestore document
  factory SecuritySettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SecuritySettings.fromMap({...data, 'businessId': doc.id});
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'ownerPinHash': ownerPinHash,
      'maxDiscountPercent': maxDiscountPercent,
      'billEditWindowMinutes': billEditWindowMinutes,
      'cashToleranceLimit': cashToleranceLimit,
      'approvalLimitAmount': approvalLimitAmount,
      'requirePinForRefunds': requirePinForRefunds,
      'requirePinForStockAdjustment': requirePinForStockAdjustment,
      'requirePinForBillDelete': requirePinForBillDelete,
      'requirePinForPeriodUnlock': requirePinForPeriodUnlock,
      'lateNightHour': lateNightHour,
      'maxBillEditsPerDay': maxBillEditsPerDay,
      'sessionExpiryHours': sessionExpiryHours,
      'enforceOneDevicePerUser': enforceOneDevicePerUser,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'ownerPinHash': ownerPinHash,
      'maxDiscountPercent': maxDiscountPercent,
      'billEditWindowMinutes': billEditWindowMinutes,
      'cashToleranceLimit': cashToleranceLimit,
      'approvalLimitAmount': approvalLimitAmount,
      'requirePinForRefunds': requirePinForRefunds,
      'requirePinForStockAdjustment': requirePinForStockAdjustment,
      'requirePinForBillDelete': requirePinForBillDelete,
      'requirePinForPeriodUnlock': requirePinForPeriodUnlock,
      'lateNightHour': lateNightHour,
      'maxBillEditsPerDay': maxBillEditsPerDay,
      'sessionExpiryHours': sessionExpiryHours,
      'enforceOneDevicePerUser': enforceOneDevicePerUser,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Copy with modifications
  SecuritySettings copyWith({
    String? ownerPinHash,
    int? maxDiscountPercent,
    int? billEditWindowMinutes,
    double? cashToleranceLimit,
    double? approvalLimitAmount,
    bool? requirePinForRefunds,
    bool? requirePinForStockAdjustment,
    bool? requirePinForBillDelete,
    bool? requirePinForPeriodUnlock,
    int? lateNightHour,
    int? maxBillEditsPerDay,
    int? sessionExpiryHours,
    bool? enforceOneDevicePerUser,
  }) {
    return SecuritySettings(
      businessId: businessId,
      ownerPinHash: ownerPinHash ?? this.ownerPinHash,
      maxDiscountPercent: maxDiscountPercent ?? this.maxDiscountPercent,
      billEditWindowMinutes:
          billEditWindowMinutes ?? this.billEditWindowMinutes,
      cashToleranceLimit: cashToleranceLimit ?? this.cashToleranceLimit,
      approvalLimitAmount: approvalLimitAmount ?? this.approvalLimitAmount,
      requirePinForRefunds: requirePinForRefunds ?? this.requirePinForRefunds,
      requirePinForStockAdjustment:
          requirePinForStockAdjustment ?? this.requirePinForStockAdjustment,
      requirePinForBillDelete:
          requirePinForBillDelete ?? this.requirePinForBillDelete,
      requirePinForPeriodUnlock:
          requirePinForPeriodUnlock ?? this.requirePinForPeriodUnlock,
      lateNightHour: lateNightHour ?? this.lateNightHour,
      maxBillEditsPerDay: maxBillEditsPerDay ?? this.maxBillEditsPerDay,
      sessionExpiryHours: sessionExpiryHours ?? this.sessionExpiryHours,
      enforceOneDevicePerUser:
          enforceOneDevicePerUser ?? this.enforceOneDevicePerUser,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if a discount requires PIN authorization
  bool requiresPinForDiscount(double discountPercent) {
    return discountPercent > maxDiscountPercent;
  }

  /// Check if current time is late night
  bool isLateNight() {
    if (lateNightHour == null) return false;
    final hour = DateTime.now().hour;
    return hour >= lateNightHour! ||
        hour < 6; // After lateNightHour or before 6 AM
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
      'SecuritySettings(business: $businessId, maxDiscount: $maxDiscountPercent%)';
}
