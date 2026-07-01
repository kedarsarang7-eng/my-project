// ============================================================================
// FRAUD DETECTION SERVICE
// ============================================================================
// Automated fraud detection engine with configurable rules.
// Monitors transactions and user behavior to detect anomalies.
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'owner_pin_service.dart';
import '../../repository/audit_repository.dart';
// ignore: unused_import (reserved for FraudAlertRepository integration)
import '../../database/app_database.dart';

/// Fraud Alert Model
class FraudAlert {
  final String id;
  final String businessId;
  final FraudAlertType type;
  final FraudSeverity severity;
  final String userId;
  final String description;
  final String? referenceId;
  final Map<String, dynamic>? metadata;
  final bool isAcknowledged;
  final String? acknowledgedBy;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;

  const FraudAlert({
    required this.id,
    required this.businessId,
    required this.type,
    required this.severity,
    required this.userId,
    required this.description,
    this.referenceId,
    this.metadata,
    this.isAcknowledged = false,
    this.acknowledgedBy,
    required this.createdAt,
    this.acknowledgedAt,
  });

  FraudAlert copyWith({
    bool? isAcknowledged,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
  }) {
    return FraudAlert(
      id: id,
      businessId: businessId,
      type: type,
      severity: severity,
      userId: userId,
      description: description,
      referenceId: referenceId,
      metadata: metadata,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      createdAt: createdAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'type': type.name,
    'severity': severity.name,
    'userId': userId,
    'description': description,
    'referenceId': referenceId,
    'metadata': metadata,
    'isAcknowledged': isAcknowledged,
    'acknowledgedBy': acknowledgedBy,
    'createdAt': createdAt.toIso8601String(),
    'acknowledgedAt': acknowledgedAt?.toIso8601String(),
  };
}

/// Types of fraud alerts
enum FraudAlertType {
  /// Multiple bill edits in short time
  repeatedBillEdits,

  /// Discount exceeds threshold
  highDiscount,

  /// Billing during unusual hours
  lateNightBilling,

  /// Stock levels don't match transactions
  stockMismatch,

  /// Cash variance during closing
  cashVariance,

  /// User attempting actions beyond their role
  roleAbuseAttempt,

  /// Multiple failed PIN attempts
  pinBruteForce,

  /// Bill deleted after payment
  paidBillDeletion,

  /// Unusual refund pattern
  suspiciousRefunds,

  /// Large transaction requiring review
  largeTransaction,

  /// Bill edited after time window expired
  billEditWindowExpired,
}

/// Severity of fraud alerts
enum FraudSeverity {
  /// Low risk - informational
  low,

  /// Medium risk - review recommended
  medium,

  /// High risk - immediate action needed
  high,

  /// Critical - potential fraud
  critical,
}

/// Fraud Detection Service - Automated fraud monitoring.
///
/// Features:
/// - Real-time transaction monitoring
/// - Configurable detection rules
/// - Alert generation and notification
/// - Risk scoring per user
class FraudDetectionService {
  // ignore: unused_field - Reserved for FraudAlertRepository integration
  final AppDatabase _database;
  final OwnerPinService _pinService;
  final AuditRepository _auditRepository;

  /// Stream controller for fraud alerts
  final StreamController<FraudAlert> _alertController =
      StreamController<FraudAlert>.broadcast();

  /// In-memory cache of pending alerts by business
  final Map<String, List<FraudAlert>> _pendingAlerts = {};

  FraudDetectionService({
    required AppDatabase database,
    required OwnerPinService pinService,
    required AuditRepository auditRepository,
  }) : _database = database,
       _pinService = pinService,
       _auditRepository = auditRepository;

  /// Stream of new fraud alerts
  Stream<FraudAlert> get fraudAlerts => _alertController.stream;

  /// Check for repeated bill edits by a user
  Future<void> checkRepeatedBillEdits({
    required String businessId,
    required String userId,
  }) async {
    try {
      final settings = await _pinService.getSecuritySettings(businessId);
      final threshold = settings?.maxBillEditsPerDay ?? 3;

      // Query audit logs for bill edits in last 24 hours
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final logs = await _auditRepository.getLogsByDateRange(
        userId: userId,
        from: yesterday,
        to: DateTime.now(),
      );

      if (logs.data == null) return;

      final billEdits = logs.data!
          .where(
            (log) => log.targetTableName == 'bills' && log.action == 'UPDATE',
          )
          .length;

      if (billEdits > threshold) {
        await _createAlert(
          businessId: businessId,
          type: FraudAlertType.repeatedBillEdits,
          severity: FraudSeverity.high,
          userId: userId,
          description:
              'User has edited $billEdits bills in last 24 hours (threshold: $threshold)',
          metadata: {'editCount': billEdits, 'threshold': threshold},
        );
      }
    } catch (e) {
      debugPrint('FraudDetectionService: Error checking repeated edits: $e');
    }
  }

  /// Check for high discount
  Future<void> checkHighDiscount({
    required String businessId,
    required String userId,
    required String billId,
    required double discountPercent,
    required double discountAmount,
  }) async {
    try {
      final settings = await _pinService.getSecuritySettings(businessId);
      final threshold = settings?.maxDiscountPercent ?? 10;

      if (discountPercent > threshold) {
        await _createAlert(
          businessId: businessId,
          type: FraudAlertType.highDiscount,
          severity: discountPercent > 25
              ? FraudSeverity.critical
              : FraudSeverity.high,
          userId: userId,
          referenceId: billId,
          description:
              'High discount of ${discountPercent.toStringAsFixed(1)}% applied (threshold: $threshold%)',
          metadata: {
            'discountPercent': discountPercent,
            'discountAmount': discountAmount,
            'threshold': threshold,
          },
        );
      }
    } catch (e) {
      debugPrint('FraudDetectionService: Error checking high discount: $e');
    }
  }

  /// Check for late night billing
  Future<void> checkLateNightBilling({
    required String businessId,
    required String userId,
    required String billId,
  }) async {
    try {
      final settings = await _pinService.getSecuritySettings(businessId);
      if (settings == null || settings.lateNightHour == null) return;

      if (settings.isLateNight()) {
        await _createAlert(
          businessId: businessId,
          type: FraudAlertType.lateNightBilling,
          severity: FraudSeverity.medium,
          userId: userId,
          referenceId: billId,
          description:
              'Bill created during restricted hours (after ${settings.lateNightHour}:00)',
          metadata: {'hour': DateTime.now().hour},
        );
      }
    } catch (e) {
      debugPrint(
        'FraudDetectionService: Error checking late night billing: $e',
      );
    }
  }

  /// Check if bill edit exceeds allowed time window
  ///
  /// Bills should only be editable within X minutes of creation.
  /// This prevents fraudulent backdating or late modifications.
  ///
  /// Returns true if edit is ALLOWED, false if BLOCKED.
  Future<bool> checkBillEditWindow({
    required String businessId,
    required String userId,
    required String billId,
    required DateTime billCreatedAt,
    int windowMinutes = 30, // Default 30 minutes
  }) async {
    try {
      final settings = await _pinService.getSecuritySettings(businessId);
      // Use setting if available, otherwise use default
      final allowedWindowMinutes =
          settings?.billEditWindowMinutes ?? windowMinutes;

      // If window is 0 or negative, edits are always allowed
      if (allowedWindowMinutes <= 0) return true;

      final now = DateTime.now();
      final ageMinutes = now.difference(billCreatedAt).inMinutes;

      if (ageMinutes > allowedWindowMinutes) {
        await _createAlert(
          businessId: businessId,
          type: FraudAlertType.billEditWindowExpired,
          severity: FraudSeverity.high,
          userId: userId,
          referenceId: billId,
          description:
              'Attempted to edit bill that is $ageMinutes minutes old (window: $allowedWindowMinutes min)',
          metadata: {
            'billId': billId,
            'billAgeMinutes': ageMinutes,
            'allowedWindowMinutes': allowedWindowMinutes,
            'billCreatedAt': billCreatedAt.toIso8601String(),
          },
        );
        return false; // Edit blocked
      }
      return true; // Edit allowed
    } catch (e) {
      debugPrint('FraudDetectionService: Error checking bill edit window: $e');
      // On error, allow edit but log warning
      return true;
    }
  }

  /// Check for cash variance
  Future<void> checkCashVariance({
    required String businessId,
    required String userId,
    required double expectedCash,
    required double actualCash,
  }) async {
    try {
      final settings = await _pinService.getSecuritySettings(businessId);
      final tolerance = settings?.cashToleranceLimit ?? 100.0;

      final variance = (expectedCash - actualCash).abs();

      if (variance > tolerance) {
        final severity = variance > tolerance * 5
            ? FraudSeverity.critical
            : variance > tolerance * 2
            ? FraudSeverity.high
            : FraudSeverity.medium;

        await _createAlert(
          businessId: businessId,
          type: FraudAlertType.cashVariance,
          severity: severity,
          userId: userId,
          description:
              'Cash variance of ₹${variance.toStringAsFixed(2)} detected (tolerance: ₹$tolerance)',
          metadata: {
            'expectedCash': expectedCash,
            'actualCash': actualCash,
            'variance': variance,
            'tolerance': tolerance,
          },
        );
      }
    } catch (e) {
      debugPrint('FraudDetectionService: Error checking cash variance: $e');
    }
  }

  /// Check for role abuse attempt
  Future<void> checkRoleAbuseAttempt({
    required String businessId,
    required String userId,
    required String attemptedAction,
    required String userRole,
  }) async {
    try {
      await _createAlert(
        businessId: businessId,
        type: FraudAlertType.roleAbuseAttempt,
        severity: FraudSeverity.high,
        userId: userId,
        description:
            'User with role "$userRole" attempted unauthorized action: $attemptedAction',
        metadata: {'attemptedAction': attemptedAction, 'userRole': userRole},
      );
    } catch (e) {
      debugPrint('FraudDetectionService: Error checking role abuse: $e');
    }
  }

  /// Check for large transaction
  Future<void> checkLargeTransaction({
    required String businessId,
    required String userId,
    required String billId,
    required double amount,
  }) async {
    try {
      final settings = await _pinService.getSecuritySettings(businessId);
      final threshold = settings?.approvalLimitAmount ?? 10000.0;

      if (amount > threshold) {
        await _createAlert(
          businessId: businessId,
          type: FraudAlertType.largeTransaction,
          severity: FraudSeverity.medium,
          userId: userId,
          referenceId: billId,
          description:
              'Large transaction of ₹${amount.toStringAsFixed(2)} (threshold: ₹$threshold)',
          metadata: {'amount': amount, 'threshold': threshold},
        );
      }
    } catch (e) {
      debugPrint('FraudDetectionService: Error checking large transaction: $e');
    }
  }

  /// Get pending (unacknowledged) alerts for a business
  Future<List<FraudAlert>> getPendingAlerts(String businessId) async {
    return _pendingAlerts[businessId] ?? [];
  }

  /// Acknowledge an alert
  Future<void> acknowledgeAlert({
    required String alertId,
    required String acknowledgedBy,
  }) async {
    for (final alerts in _pendingAlerts.values) {
      final index = alerts.indexWhere((a) => a.id == alertId);
      if (index >= 0) {
        alerts[index] = alerts[index].copyWith(
          isAcknowledged: true,
          acknowledgedBy: acknowledgedBy,
          acknowledgedAt: DateTime.now(),
        );
        break;
      }
    }
  }

  /// Get user risk score
  Future<UserRiskScore> getUserRiskScore({
    required String businessId,
    required String userId,
  }) async {
    final alerts = _pendingAlerts[businessId] ?? [];
    final userAlerts = alerts.where((a) => a.userId == userId).toList();

    if (userAlerts.isEmpty) {
      return UserRiskScore.normal;
    }

    final criticalCount = userAlerts
        .where((a) => a.severity == FraudSeverity.critical)
        .length;
    final highCount = userAlerts
        .where((a) => a.severity == FraudSeverity.high)
        .length;

    if (criticalCount > 0) return UserRiskScore.highRisk;
    if (highCount >= 3) return UserRiskScore.highRisk;
    if (highCount >= 1) return UserRiskScore.watch;
    return UserRiskScore.normal;
  }

  /// Create a fraud alert
  Future<void> _createAlert({
    required String businessId,
    required FraudAlertType type,
    required FraudSeverity severity,
    required String userId,
    required String description,
    String? referenceId,
    Map<String, dynamic>? metadata,
  }) async {
    final alert = FraudAlert(
      id: '${DateTime.now().millisecondsSinceEpoch}_${type.name}',
      businessId: businessId,
      type: type,
      severity: severity,
      userId: userId,
      description: description,
      referenceId: referenceId,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    // Add to pending alerts
    _pendingAlerts.putIfAbsent(businessId, () => []);
    _pendingAlerts[businessId]!.add(alert);

    // Emit to stream
    _alertController.add(alert);

    // Log to audit
    await _auditRepository.logAction(
      userId: userId,
      targetTableName: 'fraud_alerts',
      recordId: alert.id,
      action: 'CREATE',
      newValueJson: '${alert.toJson()}',
    );

    debugPrint(
      'FraudDetectionService: Created ${severity.name} alert: ${type.name}',
    );
  }

  /// Dispose resources
  void dispose() {
    _alertController.close();
  }
}

/// User risk score levels
enum UserRiskScore {
  /// Green - Normal behavior
  normal,

  /// Yellow - Under observation
  watch,

  /// Red - High risk, stricter controls
  highRisk,
}

extension UserRiskScoreX on UserRiskScore {
  String get displayName {
    switch (this) {
      case UserRiskScore.normal:
        return 'Normal';
      case UserRiskScore.watch:
        return 'Watch';
      case UserRiskScore.highRisk:
        return 'High Risk';
    }
  }

  String get color {
    switch (this) {
      case UserRiskScore.normal:
        return 'green';
      case UserRiskScore.watch:
        return 'yellow';
      case UserRiskScore.highRisk:
        return 'red';
    }
  }
}
