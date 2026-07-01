// ============================================================================
// SECURITY NOTIFICATION SERVICE — UNS bridge (post-migration)
// ============================================================================
// Bridges the local FraudDetectionService.fraudAlerts stream onto the
// Unified Notification System (UNS) via the Shared_SDK. Persists each alert
// to the local FraudAlertRepository (local cache of security alerts) and
// emits the canonical Phase 2 Notification_Event_Registry event:
//
//   * `system.security_fraud.alert_raised`     — generic fraud alerts
//   * `system.security_cash.mismatch_detected` — FraudAlertType.cashVariance
//   * `system.security_stock.anomaly_detected` — FraudAlertType.stockMismatch
//
// Migration target: Trigger_Point T-SEC-1 (this file is the registered
// `source_module` for `system.security_fraud.alert_raised` per Phase 2 §11.8)
// and T-SEC-2 via FraudDetectionService.checkCashVariance →
// FraudAlertType.cashVariance. T-SEC-3 (stock anomaly) emits directly from
// `stock_security_service.dart`.
//
// Behaviour preservation (REQ 10.9):
//   - Recipient set: backend resolves from Phase 2 consumer_roles (admin,
//     super_admin, accountant) — superset of the legacy in-process UI
//     stream which had a single bell consumer.
//   - Channel set: per Phase 2 channels_per_role; widened from in-app-only
//     to in_app/push/sms/email per the registry.
//   - Message content: payload carries the FraudAlert.toJson() shape; the
//     UI title is materialised by the Shared UI widgets, not by this
//     service (the legacy emoji titles were view-layer concerns).
//
// Validates: REQ 10.7, 10.8, 10.9, 10.9a, 19.4, 19.5.
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;

import '../security/services/fraud_detection_service.dart';
import '../repository/fraud_alert_repository.dart';

/// Bridges local fraud alerts onto the UNS via the Shared_SDK.
///
/// One instance per signed-in session is the intended use. Wired by
/// `SecurityLayer.initialize` in `security_layer.dart`.
class SecurityNotificationService {
  final FraudDetectionService _fraudService;
  final FraudAlertRepository _alertRepository;
  final uns.NotificationsSdk? _sdk;

  /// Path-style identifier recorded in the EventContract.source_module
  /// field (REQ 2.10, REQ 6.3). Matches the Phase 2 §11.8 entry.
  static const String _sourceModule =
      'Dukan_x/lib/core/services/security_notification_service.dart';

  StreamSubscription<FraudAlert>? _subscription;

  SecurityNotificationService({
    required FraudDetectionService fraudService,
    required FraudAlertRepository alertRepository,
    uns.NotificationsSdk? sdk,
  }) : _fraudService = fraudService,
       _alertRepository = alertRepository,
       _sdk = sdk;

  /// Start listening for fraud alerts. Idempotent.
  void startListening() {
    _subscription?.cancel();
    _subscription = _fraudService.fraudAlerts.listen(_handleAlert);
    debugPrint(
      'SecurityNotificationService: Started listening for fraud alerts',
    );
  }

  /// Stop listening for fraud alerts.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('SecurityNotificationService: Stopped listening');
  }

  Future<void> _handleAlert(FraudAlert alert) async {
    // 1) Local cache write — kept post-migration. The repository remains a
    //    local mirror of security alerts so existing screens that read
    //    directly from it (e.g. fraud-alert review screens) continue to
    //    work without depending on UNS replay.
    try {
      await _alertRepository.saveAlert(alert);
    } catch (e) {
      debugPrint('SecurityNotificationService: saveAlert failed: $e');
      // Continue — emission to UNS must not be blocked by a local cache
      // failure.
    }

    // 2) UNS emission — replaces the legacy in-process SecurityNotification
    //    stream that the bell widget subscribed to. The Shared_SDK
    //    validates against event-contract.schema.json before publish, so a
    //    schema-invalid envelope here will throw rather than silently drop.
    final sdk = _sdk;
    if (sdk == null) {
      // Defensive: SecurityLayer is expected to inject the SDK, but
      // pre-init code paths (e.g. unit tests for the legacy bridge) may
      // omit it. Skip the publish rather than crash.
      return;
    }

    try {
      final event = _buildEvent(sdk, alert);
      await sdk.emit(event);
      debugPrint(
        'SecurityNotificationService: Emitted ${event.eventName} for '
        '${alert.type.name} (${alert.severity.name})',
      );
    } catch (e) {
      // The SDK enqueues on transient transport failures; only schema /
      // auth-class errors propagate. Log and move on so a single bad alert
      // does not stop the stream.
      debugPrint('SecurityNotificationService: emit failed: $e');
    }
  }

  /// Build the canonical EventContract for a FraudAlert.
  ///
  /// The (event_name, priority, channels, dedup_scope_fields) tuple is
  /// pinned by the Phase 2 Notification_Event_Registry sections 11.8-11.10.
  /// Recipients are intentionally left empty so the Notification_Service
  /// resolves them from the registry consumer_roles at dispatch time
  /// (event-contract.schema.json: "An empty array is permitted ... the
  /// Notification_Service must resolve recipients from the
  /// Notification_Event_Registry consumer_roles for this event_name.").
  uns.EventContract _buildEvent(uns.NotificationsSdk sdk, FraudAlert alert) {
    final mapping = _mapAlertType(alert.type);

    final payload = <String, dynamic>{
      'fraud_alert_id': alert.id,
      'business_id': alert.businessId,
      'type': alert.type.name,
      'severity': alert.severity.name,
      'description': alert.description,
      if (alert.referenceId != null) 'reference_id': alert.referenceId,
      if (alert.metadata != null) 'metadata': alert.metadata,
      'created_at': alert.createdAt.toUtc().toIso8601String(),
    };

    return sdk.buildEvent(
      eventName: mapping.eventName,
      category: uns.EventCategory.system,
      subCategory: mapping.subCategory,
      priority: mapping.priority,
      actorId: alert.userId,
      targetId: alert.referenceId ?? alert.id,
      recipients: const <uns.Recipient>[],
      payload: payload,
      channels: mapping.channels,
      sourceModule: _sourceModule,
      sourceApp: uns.SourceApp.dukanxDesktop,
      dedupKey: '${mapping.eventName}:${mapping.dedupTargetId(alert)}',
      dedupScopeFields: mapping.dedupScopeFields,
    );
  }

  /// Map a [FraudAlertType] onto its UNS event name and Phase 2 metadata.
  ///
  /// `cashVariance` and `stockMismatch` are routed to their dedicated
  /// events; everything else maps to `system.security_fraud.alert_raised`
  /// per Phase 2 §11.8.
  _SecurityEventMapping _mapAlertType(FraudAlertType type) {
    switch (type) {
      case FraudAlertType.cashVariance:
        // Phase 2 §11.9 — system.security_cash.mismatch_detected
        return const _SecurityEventMapping(
          eventName: 'system.security_cash.mismatch_detected',
          subCategory: 'cash_mismatch',
          priority: uns.EventPriority.critical,
          channels: <uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
            uns.NotificationChannel.push,
            uns.NotificationChannel.sms,
            uns.NotificationChannel.email,
          ],
          dedupScopeFields: <String>['day_close_id'],
        );
      case FraudAlertType.stockMismatch:
        // Phase 2 §11.10 — system.security_stock.anomaly_detected
        return const _SecurityEventMapping(
          eventName: 'system.security_stock.anomaly_detected',
          subCategory: 'stock_anomaly',
          priority: uns.EventPriority.high,
          channels: <uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
            uns.NotificationChannel.push,
            uns.NotificationChannel.email,
          ],
          dedupScopeFields: <String>['anomaly_id'],
        );
      case FraudAlertType.highDiscount:
      case FraudAlertType.repeatedBillEdits:
      case FraudAlertType.lateNightBilling:
      case FraudAlertType.roleAbuseAttempt:
      case FraudAlertType.pinBruteForce:
      case FraudAlertType.paidBillDeletion:
      case FraudAlertType.suspiciousRefunds:
      case FraudAlertType.largeTransaction:
      case FraudAlertType.billEditWindowExpired:
        // Phase 2 §11.8 — system.security_fraud.alert_raised
        return const _SecurityEventMapping(
          eventName: 'system.security_fraud.alert_raised',
          subCategory: 'fraud_alert',
          priority: uns.EventPriority.critical,
          channels: <uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
            uns.NotificationChannel.push,
            uns.NotificationChannel.sms,
            uns.NotificationChannel.email,
          ],
          dedupScopeFields: <String>['fraud_alert_id'],
        );
    }
  }

  /// Dispose resources.
  void dispose() {
    stopListening();
  }
}

/// Internal: per-event-name Phase 2 metadata.
class _SecurityEventMapping {
  final String eventName;
  final String subCategory;
  final uns.EventPriority priority;
  final List<uns.NotificationChannel> channels;
  final List<String> dedupScopeFields;

  const _SecurityEventMapping({
    required this.eventName,
    required this.subCategory,
    required this.priority,
    required this.channels,
    required this.dedupScopeFields,
  });

  /// The discriminator that goes into the dedup_key suffix. Mirrors the
  /// Phase 2 dedup rule for each event:
  ///   * fraud_alert_raised  → fraud_alert_id (alert.id)
  ///   * cash_mismatch       → day_close_id   (alert.referenceId)
  ///   * stock_anomaly       → anomaly_id     (alert.referenceId ?? alert.id)
  String dedupTargetId(FraudAlert alert) =>
      alert.referenceId ?? alert.id;
}
