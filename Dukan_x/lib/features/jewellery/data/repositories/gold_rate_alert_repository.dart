// Gold Rate Alert Repository - Real Data with Offline Support
// Feature 1: Gold Rate Alert System
//
// Offline-first parity: VERIFIED (Phase 5, Task 10.2)
// Hive boxes: gold_rate_alerts, alert_sync_queue
// Pattern: initialize() → Hive boxes, _addToSyncQueue(), _syncAlert(), syncAll()
// Matches jewellery_repository_offline.dart offline-first architecture.

import 'dart:async';
import 'package:hive/hive.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/services/notification_controller.dart';
import '../../../../core/sync/version_reconciliation.dart';
import '../../../../core/utils/rid_generator.dart';
import '../models/jewellery_product_model.dart';
import '../models/gold_rate_alert_model.dart';
import 'jewellery_repository_offline.dart';

/// Gold Rate Alert Repository - Manages alert CRUD and monitoring
class GoldRateAlertRepository {
  final ApiClient _client;
  final SessionManager _session;
  final NotificationService _notificationService;

  late Box<GoldRateAlert> _alertsBox;
  late Box<Map> _syncQueueBox;

  bool _initialized = false;
  Timer? _monitoringTimer;

  GoldRateAlertRepository(
    this._client,
    this._session,
    this._notificationService,
  );

  /// Initialize Hive boxes
  Future<void> initialize() async {
    if (_initialized) return;

    _alertsBox = await Hive.openBox<GoldRateAlert>('gold_rate_alerts');
    _syncQueueBox = await Hive.openBox<Map>('alert_sync_queue');

    _initialized = true;
  }

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  /// Create new gold rate alert
  Future<GoldRateAlert> createAlert(CreateGoldRateAlertRequest request) async {
    await initialize();

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';
    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);

    final alert = GoldRateAlert(
      id: id,
      tenantId: tenantId,
      userId: userId,
      metalType: request.metalType,
      thresholdRatePaisaPerGram: (request.thresholdRatePerGram * 100).round(),
      direction: request.direction,
      method: request.method,
      note: request.note,
      isRecurring: request.isRecurring,
      recurrenceHours: request.recurrenceHours,
      expiryDate: request.expiryDate,
      status: AlertStatus.active,
      triggerCount: 0,
      rateHistory: [],
      notificationHistory: [],
      createdAt: now,
      updatedAt: now,
      synced: false,
      pendingOperation: 'create',
    );

    await _alertsBox.put(id, alert);
    await _addToSyncQueue('create', id);

    // Try to sync immediately
    _syncAlert(alert);

    return alert;
  }

  /// Get all alerts for current user
  Future<List<GoldRateAlert>> getAlerts({
    AlertStatus? status,
    MetalType? metalType,
    bool includeExpired = false,
  }) async {
    await initialize();

    final userId = _session.userId;
    final tenantId = _session.ownerId;

    var alerts = _alertsBox.values.where((a) {
      // Filter by user and tenant
      if (a.userId != userId || a.tenantId != tenantId) return false;

      // Filter by status
      if (status != null && a.status != status) return false;

      // Filter by metal type
      if (metalType != null && a.metalType != metalType) return false;

      // Filter expired
      if (!includeExpired && a.isExpired) return false;

      return true;
    }).toList();

    // Sort by created date (newest first)
    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return alerts;
  }

  /// Get active alerts only
  Future<List<GoldRateAlert>> getActiveAlerts() async {
    return getAlerts(status: AlertStatus.active);
  }

  /// Get single alert by ID
  Future<GoldRateAlert?> getAlertById(String id) async {
    await initialize();
    return _alertsBox.get(id);
  }

  /// Update alert
  Future<GoldRateAlert> updateAlert(
    String id,
    UpdateGoldRateAlertRequest request,
  ) async {
    await initialize();

    final existing = _alertsBox.get(id);
    if (existing == null) {
      throw Exception('Alert not found: $id');
    }

    final now = DateTime.now();

    final updated = existing.copyWith(
      thresholdRatePaisaPerGram:
          request.thresholdRatePaisaPerGram ??
          existing.thresholdRatePaisaPerGram,
      direction: request.direction ?? existing.direction,
      method: request.method ?? existing.method,
      note: request.note ?? existing.note,
      isRecurring: request.isRecurring ?? existing.isRecurring,
      recurrenceHours: request.recurrenceHours ?? existing.recurrenceHours,
      expiryDate: request.expiryDate ?? existing.expiryDate,
      status: request.status ?? existing.status,
      updatedAt: now,
      synced: false,
      pendingOperation: 'update',
    );

    await _alertsBox.put(id, updated);
    await _addToSyncQueue('update', id);

    _syncAlert(updated);

    return updated;
  }

  /// Delete alert.
  ///
  /// Optimistic local write + enqueue contract (Requirement 14.3):
  /// 1. Mark deleted locally in Hive immediately (soft-delete with status).
  /// 2. Enqueue a 'delete' sync-queue entry.
  /// 3. Fire-and-forget sync attempt (non-blocking).
  /// The record is retained locally (marked as deleted) so the sync queue
  /// entry can reference it during retry; hard-removal happens only after
  /// successful server-side deletion.
  Future<void> deleteAlert(String id) async {
    await initialize();

    final existing = _alertsBox.get(id);
    if (existing == null) return;

    // Soft-delete: mark as deleted locally rather than hard-removing,
    // so retry logic can still reference the record.
    final deleted = existing.copyWith(
      status: AlertStatus.triggered, // Mark inactive
      updatedAt: DateTime.now(),
      synced: false,
      pendingOperation: 'delete',
    );

    await _alertsBox.put(id, deleted);
    await _addToSyncQueue('delete', id);

    // Fire-and-forget sync attempt
    _syncAlert(deleted);
  }

  /// Pause/Resume alert
  Future<GoldRateAlert> toggleAlertStatus(String id) async {
    final alert = await getAlertById(id);
    if (alert == null) throw Exception('Alert not found');

    final newStatus = alert.status == AlertStatus.active
        ? AlertStatus.paused
        : AlertStatus.active;

    return updateAlert(id, UpdateGoldRateAlertRequest(status: newStatus));
  }

  // ============================================================================
  // ALERT MONITORING - REAL DATA
  // ============================================================================

  /// Start monitoring gold rates and checking alerts
  /// This runs periodically to check if any alerts should trigger
  void startMonitoring({Duration interval = const Duration(minutes: 5)}) {
    _stopMonitoring(); // Stop any existing timer

    // Run immediately
    _checkAllAlerts();

    // Schedule periodic checks
    _monitoringTimer = Timer.periodic(interval, (_) {
      _checkAllAlerts();
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _stopMonitoring();
  }

  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  /// Check all active alerts against current gold rates
  Future<List<AlertTriggerResult>> _checkAllAlerts() async {
    await initialize();

    final results = <AlertTriggerResult>[];

    try {
      // Get current gold rates from repository
      final rates = await _getCurrentGoldRates();

      // Get all active alerts
      final alerts = await getActiveAlerts();

      for (final alert in alerts) {
        final currentRate = _getRateForMetalType(rates, alert.metalType);

        // Check if alert should trigger
        if (alert.shouldTrigger(currentRate)) {
          final result = await _triggerAlert(alert, currentRate);
          results.add(result);
        } else {
          // Record rate check even if not triggered
          await _recordRateCheck(alert, currentRate, false);
        }
      }
    } catch (e) {
      print('[GoldRateAlertRepository] Error checking alerts: $e');
    }

    return results;
  }

  /// Get current gold rates from local storage or API
  Future<Map<MetalType, int>> _getCurrentGoldRates() async {
    // Try to get from local storage first (offline support)
    final jewelleryRepo = JewelleryRepositoryOffline(_client, _session);
    await jewelleryRepo.initialize();

    final todayRate = await jewelleryRepo.getTodayGoldRate();

    if (todayRate != null) {
      return {
        MetalType.gold24k: todayRate.getGoldRatePerGram(MetalType.gold24k),
        MetalType.gold22k: todayRate.getGoldRatePerGram(MetalType.gold22k),
        MetalType.gold18k: todayRate.getGoldRatePerGram(MetalType.gold18k),
        MetalType.silver:
            todayRate.silverPerKgPaisa ~/ 1000, // per kg to per gram
        MetalType.platinum: todayRate.platinumPerGramPaisa,
      };
    }

    // If no local rate, try to fetch from API
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _client.get('/jewellery/gold-rate?date=$today');

      if (response.data != null && response.data!['data'] != null) {
        final data = response.data!['data'] as Map<String, dynamic>;
        return {
          MetalType.gold24k: (data['rates']['gold24KPer10gPaisa'] as int) ~/ 10,
          MetalType.gold22k: (data['rates']['gold22KPer10gPaisa'] as int) ~/ 10,
          MetalType.gold18k: (data['rates']['gold18KPer10gPaisa'] as int) ~/ 10,
          MetalType.silver: (data['rates']['silverPerKgPaisa'] as int) ~/ 1000,
          MetalType.platinum:
              data['rates']['platinumPerGramPaisa'] as int? ?? 0,
        };
      }
    } catch (e) {
      print('[GoldRateAlertRepository] Failed to fetch rates from API: $e');
    }

    return {}; // Empty if no rates available
  }

  int _getRateForMetalType(Map<MetalType, int> rates, MetalType type) {
    return rates[type] ?? 0;
  }

  /// Trigger an alert - send notification and update record
  Future<AlertTriggerResult> _triggerAlert(
    GoldRateAlert alert,
    int currentRatePaisa,
  ) async {
    final now = DateTime.now();

    // Generate notification message
    final message = _generateAlertMessage(alert, currentRatePaisa);

    // Send notification
    bool notificationSent = false;
    try {
      switch (alert.method) {
        case NotificationMethod.push:
          notificationSent = await _notificationService.showLocalNotification(
            title: 'Gold Rate Alert',
            body: message,
            payload: 'gold_rate_alert:${alert.id}',
          );
          break;
        case NotificationMethod.email:
          // Queue email for background send
          await _queueEmailNotification(alert, message);
          notificationSent = true;
          break;
        case NotificationMethod.sms:
          // Queue SMS for background send
          await _queueSMSNotification(alert, message);
          notificationSent = true;
          break;
        case NotificationMethod.whatsapp:
          // Queue WhatsApp for background send
          await _queueWhatsAppNotification(alert, message);
          notificationSent = true;
          break;
      }
    } catch (e) {
      print('[GoldRateAlertRepository] Failed to send notification: $e');
    }

    // Create notification log
    final notificationLog = AlertNotificationLog(
      sentAt: now,
      method: alert.method,
      ratePaisaAtNotification: currentRatePaisa,
      message: message,
      delivered: notificationSent,
      errorMessage: notificationSent ? null : 'Failed to deliver',
    );

    // Update alert with trigger info
    final updatedAlert = alert.copyWith(
      status: alert.isRecurring ? AlertStatus.active : AlertStatus.triggered,
      lastTriggeredAt: now,
      triggeredRatePaisa: currentRatePaisa,
      triggerCount: alert.triggerCount + 1,
      notificationHistory: [...?alert.notificationHistory, notificationLog],
      updatedAt: now,
      synced: false,
      pendingOperation: 'update',
    );

    await _alertsBox.put(alert.id, updatedAlert);
    await _addToSyncQueue('update', alert.id);

    // Sync to backend
    _syncAlert(updatedAlert);

    return AlertTriggerResult(
      triggered: true,
      alert: updatedAlert,
      currentRatePaisa: currentRatePaisa,
      message: message,
      notificationSent: notificationSent,
    );
  }

  /// Record a rate check even if alert didn't trigger
  Future<void> _recordRateCheck(
    GoldRateAlert alert,
    int ratePaisa,
    bool wouldTrigger,
  ) async {
    // Only keep last 100 rate checks per alert
    final rateHistory = [...?alert.rateHistory];
    if (rateHistory.length >= 100) {
      rateHistory.removeAt(0);
    }

    rateHistory.add(
      AlertRateCheck(
        checkedAt: DateTime.now(),
        ratePaisaPerGram: ratePaisa,
        wouldTrigger: wouldTrigger,
      ),
    );

    final updated = alert.copyWith(
      rateHistory: rateHistory,
      updatedAt: DateTime.now(),
    );

    await _alertsBox.put(alert.id, updated);
  }

  /// Generate human-readable alert message
  String _generateAlertMessage(GoldRateAlert alert, int currentRatePaisa) {
    final metalName = alert.metalType.displayName;
    final currentRate = (currentRatePaisa / 100).toStringAsFixed(2);
    final thresholdRate = (alert.thresholdRatePaisaPerGram / 100)
        .toStringAsFixed(2);

    switch (alert.direction) {
      case AlertDirection.above:
        return '$metalName rate is now ₹$currentRate/g, above your threshold of ₹$thresholdRate/g';
      case AlertDirection.below:
        return '$metalName rate is now ₹$currentRate/g, below your threshold of ₹$thresholdRate/g';
      case AlertDirection.both:
        return '$metalName rate has changed to ₹$currentRate/g (threshold: ₹$thresholdRate/g)';
    }
  }

  // ============================================================================
  // NOTIFICATION QUEUEING
  // ============================================================================

  Future<void> _queueEmailNotification(
    GoldRateAlert alert,
    String message,
  ) async {
    final tenantId = _session.ownerId ?? 'default';
    // Add to notification queue for background processing
    await _syncQueueBox.put('email_${RidGenerator.next(tenantId)}', {
      'type': 'email',
      'alertId': alert.id,
      'message': message,
      'queuedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _queueSMSNotification(
    GoldRateAlert alert,
    String message,
  ) async {
    final tenantId = _session.ownerId ?? 'default';
    await _syncQueueBox.put('sms_${RidGenerator.next(tenantId)}', {
      'type': 'sms',
      'alertId': alert.id,
      'message': message,
      'queuedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _queueWhatsAppNotification(
    GoldRateAlert alert,
    String message,
  ) async {
    final tenantId = _session.ownerId ?? 'default';
    await _syncQueueBox.put('whatsapp_${RidGenerator.next(tenantId)}', {
      'type': 'whatsapp',
      'alertId': alert.id,
      'message': message,
      'queuedAt': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  Future<AlertStatistics> getStatistics() async {
    await initialize();

    final alerts = await getAlerts(includeExpired: true);

    var totalTriggers = 0;
    GoldRateAlert? mostTriggered;
    GoldRateAlert? recentlyTriggered;

    for (final alert in alerts) {
      totalTriggers += alert.triggerCount;

      if (mostTriggered == null ||
          alert.triggerCount > mostTriggered.triggerCount) {
        mostTriggered = alert;
      }

      if (alert.lastTriggeredAt != null) {
        if (recentlyTriggered == null ||
            alert.lastTriggeredAt!.isAfter(
              recentlyTriggered.lastTriggeredAt!,
            )) {
          recentlyTriggered = alert;
        }
      }
    }

    return AlertStatistics(
      totalAlerts: alerts.length,
      activeAlerts: alerts.where((a) => a.status == AlertStatus.active).length,
      triggeredAlerts: alerts
          .where((a) => a.status == AlertStatus.triggered)
          .length,
      expiredAlerts: alerts.where((a) => a.isExpired).length,
      totalTriggers: totalTriggers,
      mostTriggeredAlert: mostTriggered,
      recentlyTriggeredAlert: recentlyTriggered,
    );
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Enqueue a sync-queue entry for a local write (Requirement 14.3).
  ///
  /// **Optimistic local write + enqueue contract:**
  /// Every create/update/delete in this repository follows the same pattern:
  ///   1. Persist the change to the local Hive box immediately (optimistic).
  ///   2. Call [_addToSyncQueue] to enqueue a corresponding sync-queue entry.
  ///   3. Fire-and-forget call to [_syncAlert] (non-blocking).
  Future<void> _addToSyncQueue(String operation, String entityId) async {
    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);
    await _syncQueueBox.put(id, {
      'id': id,
      'entityType': 'gold_rate_alert',
      'operation': operation,
      'entityId': entityId,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });
  }

  Future<void> _syncAlert(GoldRateAlert alert) async {
    try {
      final data = {
        'id': alert.id,
        'tenantId': alert.tenantId,
        'userId': alert.userId,
        'metalType': alert.metalType.name,
        'thresholdRatePaisaPerGram': alert.thresholdRatePaisaPerGram,
        'direction': alert.direction.name,
        'method': alert.method.name,
        'note': alert.note,
        'isRecurring': alert.isRecurring,
        'recurrenceHours': alert.recurrenceHours,
        'expiryDate': alert.expiryDate?.toIso8601String(),
        'status': alert.status.name,
        'triggerCount': alert.triggerCount,
        'createdAt': alert.createdAt.toIso8601String(),
        'updatedAt': alert.updatedAt.toIso8601String(),
      };

      Map<String, dynamic>? responseData;

      if (alert.pendingOperation == 'create') {
        final response = await _client.post(
          '/jewellery/gold-rate-alerts',
          body: data,
        );
        responseData = response.data as Map<String, dynamic>?;
      } else if (alert.pendingOperation == 'update') {
        final response = await _client.put(
          '/jewellery/gold-rate-alerts/${alert.id}',
          body: data,
        );
        responseData = response.data as Map<String, dynamic>?;
      } else if (alert.pendingOperation == 'delete') {
        await _client.delete('/jewellery/gold-rate-alerts/${alert.id}');
        // On successful server delete, remove from local Hive
        await _alertsBox.delete(alert.id);
        return;
      }

      // Version-based reconciliation (Requirement 14.4)
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );
      final reconciliation = VersionReconciliation.reconcile(
        localVersion: 0, // GoldRateAlert has no version field — use 0 baseline
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        // Server has newer data — update local alert
        final serverData = reconciliation.serverData!;
        final reconciled = alert.copyWith(
          status:
              _parseAlertStatus(serverData['status'] as String?) ??
              alert.status,
          triggerCount:
              serverData['triggerCount'] as int? ?? alert.triggerCount,
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _alertsBox.put(alert.id, reconciled);
      } else {
        // Mark as synced
        final synced = alert.copyWith(
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _alertsBox.put(alert.id, synced);
      }
    } catch (e) {
      // Will retry later
      print('[GoldRateAlertRepository] Sync failed: $e');
    }
  }

  /// Parse alert status string to enum, returns null if unrecognized.
  AlertStatus? _parseAlertStatus(String? status) {
    if (status == null) return null;
    try {
      return AlertStatus.values.firstWhere((s) => s.name == status);
    } catch (_) {
      return null;
    }
  }

  /// Sync all pending alerts
  Future<void> syncAll() async {
    await initialize();

    final pending = _alertsBox.values.where((a) => !a.synced).toList();

    for (final alert in pending) {
      await _syncAlert(alert);
    }
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  /// Clean up old rate history to save storage
  Future<void> cleanupOldRateHistory({int daysToKeep = 30}) async {
    await initialize();

    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    for (final alert in _alertsBox.values) {
      if (alert.rateHistory != null && alert.rateHistory!.isNotEmpty) {
        final cleaned = alert.rateHistory!
            .where((r) => r.checkedAt.isAfter(cutoffDate))
            .toList();

        if (cleaned.length < alert.rateHistory!.length) {
          final updated = alert.copyWith(rateHistory: cleaned);
          await _alertsBox.put(alert.id, updated);
        }
      }
    }
  }

  /// Dispose and cleanup
  void dispose() {
    stopMonitoring();
  }
}

class NotificationService {
  Future<bool> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final controller = sl<NotificationController>();
      await controller.showLocal(title: title, body: body);
      return true;
    } catch (e) {
      return false;
    }
  }
}
