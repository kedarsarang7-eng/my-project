// Gold Rate Alert Model - Real-time Rate Monitoring
// Feature 1: Gold Rate Alert System

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'jewellery_product_model.dart';
import 'package:hive/hive.dart';

part 'gold_rate_alert_model.freezed.dart';
part 'gold_rate_alert_model.g.dart';

/// Alert direction - whether to notify when rate goes above or below threshold
enum AlertDirection {
  above,  // Notify when rate goes above threshold
  below,  // Notify when rate goes below threshold
  both,   // Notify on both directions
}

extension AlertDirectionExtension on AlertDirection {
  String get displayName {
    switch (this) {
      case AlertDirection.above:
        return 'Above';
      case AlertDirection.below:
        return 'Below';
      case AlertDirection.both:
        return 'Above or Below';
    }
  }

  String get description {
    switch (this) {
      case AlertDirection.above:
        return 'Notify me when rate goes ABOVE the threshold';
      case AlertDirection.below:
        return 'Notify me when rate goes BELOW the threshold';
      case AlertDirection.both:
        return 'Notify me when rate crosses the threshold in either direction';
    }
  }
}

/// Notification method - how user wants to be notified
enum NotificationMethod {
  push,    // In-app push notification
  email,   // Email notification
  sms,     // SMS notification
  whatsapp, // WhatsApp message
}

extension NotificationMethodExtension on NotificationMethod {
  String get displayName {
    switch (this) {
      case NotificationMethod.push:
        return 'Push Notification';
      case NotificationMethod.email:
        return 'Email';
      case NotificationMethod.sms:
        return 'SMS';
      case NotificationMethod.whatsapp:
        return 'WhatsApp';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationMethod.push:
        return Icons.notifications;
      case NotificationMethod.email:
        return Icons.email;
      case NotificationMethod.sms:
        return Icons.sms;
      case NotificationMethod.whatsapp:
        return Icons.chat;
    }
  }
}

/// Alert status
enum AlertStatus {
  active,     // Alert is active and monitoring
  triggered,  // Alert has been triggered
  paused,     // Alert temporarily paused
  expired,    // Alert has expired
}

extension AlertStatusExtension on AlertStatus {
  String get displayName {
    switch (this) {
      case AlertStatus.active:
        return 'Active';
      case AlertStatus.triggered:
        return 'Triggered';
      case AlertStatus.paused:
        return 'Paused';
      case AlertStatus.expired:
        return 'Expired';
    }
  }

  Color get color {
    switch (this) {
      case AlertStatus.active:
        return Colors.green;
      case AlertStatus.triggered:
        return Colors.orange;
      case AlertStatus.paused:
        return Colors.grey;
      case AlertStatus.expired:
        return Colors.red;
    }
  }
}

/// Gold Rate Alert - Monitor gold rates and notify when thresholds are crossed
@freezed
abstract class GoldRateAlert with _$GoldRateAlert {
  @HiveType(typeId: 56)
  const factory GoldRateAlert({
    // Core identifiers
    @HiveField(0) required String id,
    @HiveField(1) required String tenantId,
    @HiveField(2) required String userId, // User who created the alert
    
    // Alert configuration
    @HiveField(3) required MetalType metalType,
    @HiveField(4) required int thresholdRatePaisaPerGram, // Rate threshold
    @HiveField(5) @Default(AlertDirection.above) AlertDirection direction,
    @HiveField(6) @Default(NotificationMethod.push) NotificationMethod method,
    
    // Optional settings
    @HiveField(7) String? note, // User note about why they set this alert
    @HiveField(8) @Default(false) bool isRecurring, // Reset after trigger?
    @HiveField(9) int? recurrenceHours, // How many hours before re-alerting
    
    // Expiration
    @HiveField(10) DateTime? expiryDate, // When alert should expire
    
    // Alert status
    @HiveField(11) @Default(AlertStatus.active) AlertStatus status,
    
    // Trigger tracking (real data from actual rate checks)
    @HiveField(12) DateTime? lastTriggeredAt,
    @HiveField(13) int? triggeredRatePaisa, // The actual rate when triggered
    @HiveField(14) @Default(0) int triggerCount, // How many times this alert has triggered
    
    // Rate history for this alert (last checked rates)
    @HiveField(15) List<AlertRateCheck>? rateHistory,
    
    // Notification history
    @HiveField(16) List<AlertNotificationLog>? notificationHistory,
    
    // Metadata
    @HiveField(17) required DateTime createdAt,
    @HiveField(18) required DateTime updatedAt,
    
    // Sync tracking
    @HiveField(19) @Default(true) bool synced,
    @HiveField(20) DateTime? lastSyncedAt,
    @HiveField(21) String? pendingOperation,
  }) = _GoldRateAlert;

  const GoldRateAlert._();

  factory GoldRateAlert.fromJson(Map<String, dynamic> json) =>
      _$GoldRateAlertFromJson(json);

  /// Check if alert should trigger given current rate
  bool shouldTrigger(int currentRatePaisa) {
    if (status != AlertStatus.active) return false;
    if (expiryDate != null && DateTime.now().isAfter(expiryDate!)) return false;
    
    // Check if enough time has passed since last trigger (for recurring alerts)
    if (isRecurring && 
        lastTriggeredAt != null && 
        recurrenceHours != null) {
      final hoursSinceLastTrigger = DateTime.now()
          .difference(lastTriggeredAt!)
          .inHours;
      if (hoursSinceLastTrigger < recurrenceHours!) {
        return false; // Not enough time passed
      }
    } else if (!isRecurring && lastTriggeredAt != null) {
      return false; // Already triggered and not recurring
    }

    final threshold = thresholdRatePaisaPerGram;
    
    switch (direction) {
      case AlertDirection.above:
        return currentRatePaisa > threshold;
      case AlertDirection.below:
        return currentRatePaisa < threshold;
      case AlertDirection.both:
        return currentRatePaisa != threshold; // Any change from threshold
    }
  }

  /// Get display threshold in rupees
  double get displayThreshold => thresholdRatePaisaPerGram / 100;

  /// Get last triggered rate in rupees
  double? get displayTriggeredRate => triggeredRatePaisa != null 
      ? triggeredRatePaisa! / 100 
      : null;

  /// Check if alert has expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// Get time until next possible trigger (for recurring alerts)
  Duration? get timeUntilNextTrigger {
    if (!isRecurring || lastTriggeredAt == null || recurrenceHours == null) {
      return null;
    }
    final nextTriggerTime = lastTriggeredAt!.add(
      Duration(hours: recurrenceHours!)
    );
    final now = DateTime.now();
    if (nextTriggerTime.isAfter(now)) {
      return nextTriggerTime.difference(now);
    }
    return Duration.zero; // Ready to trigger again
  }
}

/// Rate check record - stores the rate when alert was checked
@freezed
abstract class AlertRateCheck with _$AlertRateCheck {
  @HiveType(typeId: 57)
  const factory AlertRateCheck({
    @HiveField(0) required DateTime checkedAt,
    @HiveField(1) required int ratePaisaPerGram,
    @HiveField(2) required bool wouldTrigger,
  }) = _AlertRateCheck;

  factory AlertRateCheck.fromJson(Map<String, dynamic> json) =>
      _$AlertRateCheckFromJson(json);
}

/// Notification log - tracks when notifications were sent
@freezed
abstract class AlertNotificationLog with _$AlertNotificationLog {
  @HiveType(typeId: 58)
  const factory AlertNotificationLog({
    @HiveField(0) required DateTime sentAt,
    @HiveField(1) required NotificationMethod method,
    @HiveField(2) required int ratePaisaAtNotification,
    @HiveField(3) required String message,
    @HiveField(4) @Default(true) bool delivered,
    @HiveField(5) String? errorMessage,
  }) = _AlertNotificationLog;

  factory AlertNotificationLog.fromJson(Map<String, dynamic> json) =>
      _$AlertNotificationLogFromJson(json);
}

/// Alert summary statistics
@freezed
abstract class AlertStatistics with _$AlertStatistics {
  const factory AlertStatistics({
    @Default(0) int totalAlerts,
    @Default(0) int activeAlerts,
    @Default(0) int triggeredAlerts,
    @Default(0) int expiredAlerts,
    @Default(0) int totalTriggers,
    GoldRateAlert? mostTriggeredAlert,
    GoldRateAlert? recentlyTriggeredAlert,
  }) = _AlertStatistics;

  factory AlertStatistics.fromJson(Map<String, dynamic> json) =>
      _$AlertStatisticsFromJson(json);
}

/// Request models
class CreateGoldRateAlertRequest {
  final MetalType metalType;
  final double thresholdRatePerGram;
  final AlertDirection direction;
  final NotificationMethod method;
  final String? note;
  final bool isRecurring;
  final int? recurrenceHours;
  final DateTime? expiryDate;

  CreateGoldRateAlertRequest({
    required this.metalType,
    required this.thresholdRatePerGram,
    this.direction = AlertDirection.above,
    this.method = NotificationMethod.push,
    this.note,
    this.isRecurring = false,
    this.recurrenceHours,
    this.expiryDate,
  });

  Map<String, dynamic> toJson() => {
    'metalType': metalType.name,
    'thresholdRatePaisaPerGram': (thresholdRatePerGram * 100).round(),
    'direction': direction.name,
    'method': method.name,
    'note': note,
    'isRecurring': isRecurring,
    'recurrenceHours': recurrenceHours,
    'expiryDate': expiryDate?.toIso8601String(),
  };
}

class UpdateGoldRateAlertRequest {
  final int? thresholdRatePaisaPerGram;
  final AlertDirection? direction;
  final NotificationMethod? method;
  final String? note;
  final bool? isRecurring;
  final int? recurrenceHours;
  final DateTime? expiryDate;
  final AlertStatus? status;

  UpdateGoldRateAlertRequest({
    this.thresholdRatePaisaPerGram,
    this.direction,
    this.method,
    this.note,
    this.isRecurring,
    this.recurrenceHours,
    this.expiryDate,
    this.status,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (thresholdRatePaisaPerGram != null) {
      data['thresholdRatePaisaPerGram'] = thresholdRatePaisaPerGram;
    }
    if (direction != null) data['direction'] = direction!.name;
    if (method != null) data['method'] = method!.name;
    if (note != null) data['note'] = note;
    if (isRecurring != null) data['isRecurring'] = isRecurring;
    if (recurrenceHours != null) data['recurrenceHours'] = recurrenceHours;
    if (expiryDate != null) data['expiryDate'] = expiryDate!.toIso8601String();
    if (status != null) data['status'] = status!.name;
    return data;
  }
}

/// Alert trigger result
class AlertTriggerResult {
  final bool triggered;
  final GoldRateAlert? alert;
  final int currentRatePaisa;
  final String? message;
  final bool notificationSent;

  AlertTriggerResult({
    required this.triggered,
    this.alert,
    required this.currentRatePaisa,
    this.message,
    required this.notificationSent,
  });
}
