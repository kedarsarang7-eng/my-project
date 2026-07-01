// ============================================================================
// BUSINESS ANALYTICS SERVICE
// ============================================================================
// Custom business event tracking for DukanX production monitoring.
//
// Events tracked:
// - bill_created: Successful bill creation
// - payment_failed: Payment processing errors
// - sync_conflict_detected: Sync conflict resolution events
// - data_integrity_autofix: Auto-repair actions taken
//
// IMPORTANT: This service is read-only and never mutates business data.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'monitoring_service.dart';

/// Business event types for analytics tracking
enum BusinessEventType {
  /// Bill successfully created
  billCreated('bill_created'),

  /// Bill successfully updated
  billUpdated('bill_updated'),

  /// Bill deleted/cancelled
  billCancelled('bill_cancelled'),

  /// Payment processing failed
  paymentFailed('payment_failed'),

  /// Payment successfully processed
  paymentReceived('payment_received'),

  /// Sync conflict detected and resolved
  syncConflictDetected('sync_conflict_detected'),

  /// Data integrity issue auto-fixed
  dataIntegrityAutofix('data_integrity_autofix'),

  /// Customer created
  customerCreated('customer_created'),

  /// Stock adjustment made
  stockAdjusted('stock_adjusted'),

  /// GST report generated
  gstReportGenerated('gst_report_generated'),

  /// Backup completed
  backupCompleted('backup_completed'),

  /// User session started
  sessionStarted('session_started'),

  /// Critical error occurred
  criticalError('critical_error');

  final String eventName;
  const BusinessEventType(this.eventName);
}

/// Business Analytics Service
///
/// Provides custom business event tracking integrated with Firebase Analytics
/// and Crashlytics. All operations are read-only and non-blocking.
class BusinessAnalyticsService {
  static BusinessAnalyticsService? _instance;
  static BusinessAnalyticsService get instance =>
      _instance ??= BusinessAnalyticsService._();

  BusinessAnalyticsService._();

  // Reference to monitoring service for logging
  final MonitoringService _monitoring = MonitoringService.instance;

  // Event buffer for batch processing (optional)
  final List<_BusinessEvent> _eventBuffer = [];
  static const int _maxBufferSize = 100;

  // ============================================================================
  // BILL EVENTS
  // ============================================================================

  /// Track bill creation event
  ///
  /// Called after successful bill creation. Does not affect the bill itself.
  void trackBillCreated({
    required String billId,
    required double amount,
    required String paymentStatus,
    String? customerId,
    String? businessId,
    int? itemCount,
  }) {
    _trackEvent(
      BusinessEventType.billCreated,
      parameters: {
        'bill_id': billId,
        'amount': amount,
        'payment_status': paymentStatus,
        'customer_id': ?customerId,
        'business_id': ?businessId,
        'item_count': ?itemCount,
        'currency': 'INR',
      },
    );
  }

  /// Track bill update event
  void trackBillUpdated({
    required String billId,
    required double originalAmount,
    required double newAmount,
    String? reason,
    String? updatedBy,
  }) {
    _trackEvent(
      BusinessEventType.billUpdated,
      parameters: {
        'bill_id': billId,
        'original_amount': originalAmount,
        'new_amount': newAmount,
        'amount_change': newAmount - originalAmount,
        'reason': ?reason,
        'updated_by': ?updatedBy,
      },
    );
  }

  /// Track bill cancellation event
  void trackBillCancelled({
    required String billId,
    required double amount,
    String? reason,
    String? cancelledBy,
  }) {
    _trackEvent(
      BusinessEventType.billCancelled,
      parameters: {
        'bill_id': billId,
        'amount': amount,
        'reason': ?reason,
        'cancelled_by': ?cancelledBy,
      },
    );
  }

  // ============================================================================
  // PAYMENT EVENTS
  // ============================================================================

  /// Track payment failure event
  ///
  /// Called when a payment processing error occurs.
  void trackPaymentFailed({
    required String? customerId,
    required double amount,
    required String error,
    String? paymentMethod,
    String? billId,
  }) {
    _trackEvent(
      BusinessEventType.paymentFailed,
      parameters: {
        'customer_id': ?customerId,
        'amount': amount,
        'error': error.length > 100 ? error.substring(0, 100) : error,
        'payment_method': ?paymentMethod,
        'bill_id': ?billId,
        'currency': 'INR',
      },
      isError: true,
    );
  }

  /// Track successful payment received
  void trackPaymentReceived({
    required String customerId,
    required double amount,
    required String paymentMethod,
    String? billId,
  }) {
    _trackEvent(
      BusinessEventType.paymentReceived,
      parameters: {
        'customer_id': customerId,
        'amount': amount,
        'payment_method': paymentMethod,
        'bill_id': ?billId,
        'currency': 'INR',
      },
    );
  }

  // ============================================================================
  // SYNC EVENTS
  // ============================================================================

  /// Track sync conflict detection and resolution
  void trackSyncConflictDetected({
    required String entityType,
    required String entityId,
    required String resolution,
    String? conflictDetails,
  }) {
    _trackEvent(
      BusinessEventType.syncConflictDetected,
      parameters: {
        'entity_type': entityType,
        'entity_id': entityId,
        'resolution': resolution,
        'conflict_details': ?conflictDetails,
      },
      isWarning: true,
    );
  }

  // ============================================================================
  // DATA INTEGRITY EVENTS
  // ============================================================================

  /// Track data integrity auto-fix event
  ///
  /// Called when DataIntegrityService performs automatic repair.
  void trackDataIntegrityAutofix({
    required String fixType,
    required List<String> entityIds,
    String? description,
    double? correctedAmount,
  }) {
    _trackEvent(
      BusinessEventType.dataIntegrityAutofix,
      parameters: {
        'fix_type': fixType,
        'entity_count': entityIds.length,
        'entity_ids': entityIds.take(10).join(','), // Limit for logging
        'description': ?description,
        'corrected_amount': ?correctedAmount,
      },
      isWarning: true,
    );
  }

  // ============================================================================
  // OTHER BUSINESS EVENTS
  // ============================================================================

  /// Track customer creation
  void trackCustomerCreated({required String customerId, String? businessId}) {
    _trackEvent(
      BusinessEventType.customerCreated,
      parameters: {'customer_id': customerId, 'business_id': ?businessId},
    );
  }

  /// Track stock adjustment
  void trackStockAdjusted({
    required String productId,
    required double previousQty,
    required double newQty,
    required String reason,
  }) {
    _trackEvent(
      BusinessEventType.stockAdjusted,
      parameters: {
        'product_id': productId,
        'previous_qty': previousQty,
        'new_qty': newQty,
        'adjustment': newQty - previousQty,
        'reason': reason,
      },
    );
  }

  /// Track GST report generation
  void trackGstReportGenerated({
    required String reportType,
    required String period,
    required double totalTax,
  }) {
    _trackEvent(
      BusinessEventType.gstReportGenerated,
      parameters: {
        'report_type': reportType,
        'period': period,
        'total_tax': totalTax,
      },
    );
  }

  /// Track backup completion
  void trackBackupCompleted({
    required String backupType,
    required int sizeBytes,
    required bool uploadedToCloud,
  }) {
    _trackEvent(
      BusinessEventType.backupCompleted,
      parameters: {
        'backup_type': backupType,
        'size_bytes': sizeBytes,
        'size_mb': (sizeBytes / 1024 / 1024).toStringAsFixed(2),
        'uploaded_to_cloud': uploadedToCloud,
      },
    );
  }

  /// Track session start
  void trackSessionStarted({
    required String userId,
    String? businessId,
    String? deviceType,
  }) {
    _trackEvent(
      BusinessEventType.sessionStarted,
      parameters: {
        'user_id': userId.length > 8 ? '${userId.substring(0, 8)}...' : userId,
        'business_id': ?businessId,
        'device_type': ?deviceType,
      },
    );
  }

  /// Track critical error (non-fatal but important)
  void trackCriticalError({
    required String errorType,
    required String message,
    String? context,
    String? stackTrace,
  }) {
    _trackEvent(
      BusinessEventType.criticalError,
      parameters: {
        'error_type': errorType,
        'message': message.length > 200 ? message.substring(0, 200) : message,
        'context': ?context,
      },
      isError: true,
    );
  }

  // ============================================================================
  // INTERNAL METHODS
  // ============================================================================

  /// Internal event tracking method
  void _trackEvent(
    BusinessEventType eventType, {
    required Map<String, dynamic> parameters,
    bool isError = false,
    bool isWarning = false,
  }) {
    final eventName = eventType.eventName;
    final timestamp = DateTime.now();

    // Create event record
    final event = _BusinessEvent(
      type: eventType,
      parameters: parameters,
      timestamp: timestamp,
    );

    // Add to buffer
    _eventBuffer.add(event);
    if (_eventBuffer.length > _maxBufferSize) {
      _eventBuffer.removeAt(0);
    }

    // Log to monitoring service
    if (isError) {
      _monitoring.warning('BusinessAnalytics', eventName, metadata: parameters);
    } else if (isWarning) {
      _monitoring.info('BusinessAnalytics', eventName, metadata: parameters);
    } else {
      _monitoring.debug('BusinessAnalytics', eventName, metadata: parameters);
    }

    // Send to Firebase Analytics (non-blocking)
    _monitoring.trackEvent(
      eventName,
      parameters: _sanitizeParameters(parameters),
    );

    // Send critical events to Crashlytics for dashboard visibility
    if ((isError || isWarning) && !kDebugMode) {
      _sendToCrashlytics(eventName, parameters);
    }
  }

  /// Sanitize parameters for Firebase Analytics
  /// Firebase has restrictions on parameter values
  Map<String, dynamic> _sanitizeParameters(Map<String, dynamic> params) {
    final sanitized = <String, dynamic>{};

    for (final entry in params.entries) {
      final key = entry.key.length > 40
          ? entry.key.substring(0, 40)
          : entry.key;

      var value = entry.value;

      // Firebase Analytics supports: String, int, double
      if (value is String) {
        value = value.length > 100 ? value.substring(0, 100) : value;
      } else if (value is! num && value is! bool) {
        final stringValue = value.toString();
        value = stringValue.length > 100
            ? stringValue.substring(0, 100)
            : stringValue;
      }

      sanitized[key] = value;
    }

    return sanitized;
  }

  /// Send event to local logging (Crashlytics removed)
  void _sendToCrashlytics(String eventName, Map<String, dynamic> params) {
    try {
      // Log important business events via dart:developer
      final importantParams = params.entries.take(3).toList();
      final paramStr = importantParams
          .map((e) => '${e.key}=${e.value}')
          .join(', ');
      developer.log(
        'BusinessEvent: $eventName [$paramStr]',
        name: 'BusinessAnalytics',
        level: 900,
      );
    } catch (e) {
      // Non-blocking - ignore errors
      debugPrint('[BusinessAnalytics] Logging error: $e');
    }
  }

  /// Get recent events (for debugging)
  List<Map<String, dynamic>> getRecentEvents({int limit = 20}) {
    return _eventBuffer.reversed
        .take(limit)
        .map(
          (e) => {
            'event': e.type.eventName,
            'timestamp': e.timestamp.toIso8601String(),
            'parameters': e.parameters,
          },
        )
        .toList();
  }

  /// Get event counts by type (for dashboard)
  Map<String, int> getEventCounts() {
    final counts = <String, int>{};
    for (final event in _eventBuffer) {
      final name = event.type.eventName;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  /// Clear event buffer
  void clearBuffer() {
    _eventBuffer.clear();
  }
}

/// Internal business event record
class _BusinessEvent {
  final BusinessEventType type;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;

  _BusinessEvent({
    required this.type,
    required this.parameters,
    required this.timestamp,
  });
}

/// Global shortcut
BusinessAnalyticsService get businessAnalytics =>
    BusinessAnalyticsService.instance;
