// ============================================================================
// WhatsApp Offline Service — Offline queue for config/template/rule/customer writes
// ============================================================================
// Enqueues config/template/rule/customer writes through the core OfflineQueue
// with a stable idempotencyKey (UUID v4) per operation. On reconnection,
// pending operations are replayed in FIFO order by the SyncManager.
//
// Reads fall back to the local Drift database when the device is offline.
//
// Requirements: 9.1 (FIFO replay), 9.3 (stable idempotencyKey)
// ============================================================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/sync/offline_queue.dart';
import '../data/models/automation_config_model.dart';
import '../data/models/automation_rule_model.dart';
import '../data/models/message_template_model.dart';
import '../data/models/whatsapp_customer_model.dart';
import '../data/repositories/whatsapp_automation_repository.dart';

/// Entity types used for WhatsApp offline mutations.
/// These match the sync_table_registry local table names.
class WhatsAppEntityTypes {
  WhatsAppEntityTypes._();

  static const String config = 'wa_automation_config';
  static const String templates = 'wa_message_templates';
  static const String rules = 'wa_automation_rules';
  static const String customers = 'wa_customers';
}

/// WhatsApp Offline Service — manages offline queuing via OfflineQueue
/// and provides Drift-based read fallback when offline.
class WhatsAppOfflineService {
  final WhatsAppAutomationRepository _repository;
  final OfflineQueue _offlineQueue;
  final Connectivity _connectivity;
  final AppDatabase _db;
  final String _tenantId;
  final _uuid = const Uuid();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  WhatsAppOfflineService({
    required WhatsAppAutomationRepository repository,
    required OfflineQueue offlineQueue,
    required Connectivity connectivity,
    required AppDatabase db,
    required String tenantId,
  }) : _repository = repository,
       _offlineQueue = offlineQueue,
       _connectivity = connectivity,
       _db = db,
       _tenantId = tenantId {
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  // ── Config Operations ─────────────────────────────────────────────────────

  /// Update automation config. Queues offline if disconnected.
  Future<AutomationConfig?> updateConfig(Map<String, dynamic> updates) async {
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        return await _repository.updateConfig(updates);
      } catch (e) {
        if (_isNetworkError(e)) {
          await _enqueue(
            entityType: WhatsAppEntityTypes.config,
            operationType: MutationOperationType.update,
            payload: updates,
          );
          return null;
        }
        rethrow;
      }
    } else {
      await _enqueue(
        entityType: WhatsAppEntityTypes.config,
        operationType: MutationOperationType.update,
        payload: updates,
      );
      return null;
    }
  }

  // ── Template Operations ───────────────────────────────────────────────────

  /// Create a new message template. Queues offline if disconnected.
  Future<MessageTemplate?> createTemplate(Map<String, dynamic> body) async {
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        return await _repository.createTemplate(body);
      } catch (e) {
        if (_isNetworkError(e)) {
          await _enqueue(
            entityType: WhatsAppEntityTypes.templates,
            operationType: MutationOperationType.create,
            payload: body,
          );
          return null;
        }
        rethrow;
      }
    } else {
      await _enqueue(
        entityType: WhatsAppEntityTypes.templates,
        operationType: MutationOperationType.create,
        payload: body,
      );
      return null;
    }
  }

  /// Update an existing template. Queues offline if disconnected.
  Future<MessageTemplate?> updateTemplate(
    String templateId,
    Map<String, dynamic> updates,
  ) async {
    final isOnline = await _checkConnectivity();
    final payload = {'_id': templateId, ...updates};

    if (isOnline) {
      try {
        return await _repository.updateTemplate(templateId, updates);
      } catch (e) {
        if (_isNetworkError(e)) {
          await _enqueue(
            entityType: WhatsAppEntityTypes.templates,
            operationType: MutationOperationType.update,
            payload: payload,
            affectedRecordId: templateId,
          );
          return null;
        }
        rethrow;
      }
    } else {
      await _enqueue(
        entityType: WhatsAppEntityTypes.templates,
        operationType: MutationOperationType.update,
        payload: payload,
        affectedRecordId: templateId,
      );
      return null;
    }
  }

  /// Delete a template. Queues offline if disconnected.
  Future<void> deleteTemplate(String templateId) async {
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        await _repository.deleteTemplate(templateId);
        return;
      } catch (e) {
        if (_isNetworkError(e)) {
          await _enqueue(
            entityType: WhatsAppEntityTypes.templates,
            operationType: MutationOperationType.delete,
            payload: {'id': templateId},
            affectedRecordId: templateId,
          );
          return;
        }
        rethrow;
      }
    } else {
      await _enqueue(
        entityType: WhatsAppEntityTypes.templates,
        operationType: MutationOperationType.delete,
        payload: {'id': templateId},
        affectedRecordId: templateId,
      );
    }
  }

  // ── Rule Operations ───────────────────────────────────────────────────────

  /// Create a new automation rule. Queues offline if disconnected.
  Future<AutomationRule?> createRule(Map<String, dynamic> body) async {
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        return await _repository.createRule(body);
      } catch (e) {
        if (_isNetworkError(e)) {
          await _enqueue(
            entityType: WhatsAppEntityTypes.rules,
            operationType: MutationOperationType.create,
            payload: body,
          );
          return null;
        }
        rethrow;
      }
    } else {
      await _enqueue(
        entityType: WhatsAppEntityTypes.rules,
        operationType: MutationOperationType.create,
        payload: body,
      );
      return null;
    }
  }

  /// Update an existing rule. Queues offline if disconnected.
  Future<AutomationRule?> updateRule(
    String ruleId,
    Map<String, dynamic> updates,
  ) async {
    final isOnline = await _checkConnectivity();
    final payload = {'_id': ruleId, ...updates};

    if (isOnline) {
      try {
        return await _repository.updateRule(ruleId, updates);
      } catch (e) {
        if (_isNetworkError(e)) {
          await _enqueue(
            entityType: WhatsAppEntityTypes.rules,
            operationType: MutationOperationType.update,
            payload: payload,
            affectedRecordId: ruleId,
          );
          return null;
        }
        rethrow;
      }
    } else {
      await _enqueue(
        entityType: WhatsAppEntityTypes.rules,
        operationType: MutationOperationType.update,
        payload: payload,
        affectedRecordId: ruleId,
      );
      return null;
    }
  }

  /// Delete a rule. Queues offline if disconnected.
  Future<void> deleteRule(String ruleId) async {
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        await _repository.deleteRule(ruleId);
        return;
      } catch (e) {
        if (_isNetworkError(e)) {
          await _enqueue(
            entityType: WhatsAppEntityTypes.rules,
            operationType: MutationOperationType.delete,
            payload: {'id': ruleId},
            affectedRecordId: ruleId,
          );
          return;
        }
        rethrow;
      }
    } else {
      await _enqueue(
        entityType: WhatsAppEntityTypes.rules,
        operationType: MutationOperationType.delete,
        payload: {'id': ruleId},
        affectedRecordId: ruleId,
      );
    }
  }

  /// Enable a rule. Queues offline if disconnected.
  Future<AutomationRule?> enableRule(String ruleId) async {
    return updateRule(ruleId, {'enabled': true});
  }

  /// Disable a rule. Queues offline if disconnected.
  Future<AutomationRule?> disableRule(String ruleId) async {
    return updateRule(ruleId, {'enabled': false});
  }

  // ── Customer Operations ───────────────────────────────────────────────────

  /// Create a new customer profile. Queues offline if disconnected.
  Future<WhatsAppCustomer?> createCustomer(Map<String, dynamic> body) async {
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        return await _repository.createCustomer(body);
      } catch (e) {
        if (_isNetworkError(e)) {
          await _enqueue(
            entityType: WhatsAppEntityTypes.customers,
            operationType: MutationOperationType.create,
            payload: body,
          );
          return null;
        }
        rethrow;
      }
    } else {
      await _enqueue(
        entityType: WhatsAppEntityTypes.customers,
        operationType: MutationOperationType.create,
        payload: body,
      );
      return null;
    }
  }

  /// Update a customer profile. Queues offline if disconnected.
  Future<WhatsAppCustomer?> updateCustomer(
    String customerId,
    Map<String, dynamic> updates,
  ) async {
    final isOnline = await _checkConnectivity();
    final payload = {'_id': customerId, ...updates};

    if (isOnline) {
      try {
        return await _repository.updateCustomer(customerId, updates);
      } catch (e) {
        if (_isNetworkError(e)) {
          await _enqueue(
            entityType: WhatsAppEntityTypes.customers,
            operationType: MutationOperationType.update,
            payload: payload,
            affectedRecordId: customerId,
          );
          return null;
        }
        rethrow;
      }
    } else {
      await _enqueue(
        entityType: WhatsAppEntityTypes.customers,
        operationType: MutationOperationType.update,
        payload: payload,
        affectedRecordId: customerId,
      );
      return null;
    }
  }

  /// Set consent state for a customer. Queues offline if disconnected.
  Future<WhatsAppCustomer?> setConsent(
    String customerId,
    ConsentState consentState,
  ) async {
    final isOnline = await _checkConnectivity();
    final payload = {'_id': customerId, 'consentState': consentState.value};

    if (isOnline) {
      try {
        return await _repository.setConsent(customerId, consentState);
      } catch (e) {
        if (_isNetworkError(e)) {
          await _enqueue(
            entityType: WhatsAppEntityTypes.customers,
            operationType: MutationOperationType.update,
            payload: payload,
            affectedRecordId: customerId,
          );
          return null;
        }
        rethrow;
      }
    } else {
      await _enqueue(
        entityType: WhatsAppEntityTypes.customers,
        operationType: MutationOperationType.update,
        payload: payload,
        affectedRecordId: customerId,
      );
      return null;
    }
  }

  // ── Read Operations (Drift Fallback) ──────────────────────────────────────

  /// Get automation config. Falls back to local Drift cache when offline.
  Future<AutomationConfig?> getConfig() async {
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final config = await _repository.getConfig();
        // Cache for offline access (stored by the sync engine on successful pull)
        return config;
      } catch (e) {
        if (_isNetworkError(e)) {
          return _getConfigFromDrift();
        }
        rethrow;
      }
    }
    return _getConfigFromDrift();
  }

  /// Get templates. Falls back to local Drift cache when offline.
  Future<List<MessageTemplate>> getTemplates() async {
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        return await _repository.getTemplates();
      } catch (e) {
        if (_isNetworkError(e)) {
          return _getTemplatesFromDrift();
        }
        rethrow;
      }
    }
    return _getTemplatesFromDrift();
  }

  /// Get rules. Falls back to local Drift cache when offline.
  Future<List<AutomationRule>> getRules() async {
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        return await _repository.getRules();
      } catch (e) {
        if (_isNetworkError(e)) {
          return _getRulesFromDrift();
        }
        rethrow;
      }
    }
    return _getRulesFromDrift();
  }

  /// Get customers. Falls back to local Drift cache when offline.
  Future<List<WhatsAppCustomer>> getCustomers() async {
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        return await _repository.getCustomers();
      } catch (e) {
        if (_isNetworkError(e)) {
          return _getCustomersFromDrift();
        }
        rethrow;
      }
    }
    return _getCustomersFromDrift();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Dispose connectivity subscription.
  void dispose() {
    _connectivitySub?.cancel();
  }

  // ── Private — Enqueue ─────────────────────────────────────────────────────

  /// Enqueue a write operation into the OfflineQueue with a stable UUID v4
  /// idempotencyKey. Operations are replayed in FIFO (chronological) order
  /// on reconnection by SyncManager.
  Future<void> _enqueue({
    required String entityType,
    required MutationOperationType operationType,
    required Map<String, dynamic> payload,
    String? affectedRecordId,
  }) async {
    final idempotencyKey = _uuid.v4();

    final mutation = OfflineMutation(
      tenantId: _tenantId,
      idempotencyKey: idempotencyKey,
      operationType: operationType,
      entityType: entityType,
      payload: payload,
      affectedRecordId: affectedRecordId,
    );

    final result = await _offlineQueue.enqueue(mutation);
    if (result.success) {
      LoggerService.d(
        'WhatsAppOffline',
        'Queued $entityType ${operationType.value} '
            '(idempotencyKey: $idempotencyKey)',
      );
    } else {
      LoggerService.d('WhatsAppOffline', 'Failed to enqueue: ${result.error}');
    }
  }

  // ── Private — Drift Fallback Reads ────────────────────────────────────────

  /// Read config from local Drift cache.
  Future<AutomationConfig?> _getConfigFromDrift() async {
    try {
      final rows = await _db
          .customSelect('SELECT * FROM wa_automation_config LIMIT 1')
          .get();
      if (rows.isEmpty) return null;
      return AutomationConfig.fromJson(rows.first.data);
    } catch (e) {
      LoggerService.d(
        'WhatsAppOffline',
        'Drift fallback for config failed: $e',
      );
      return null;
    }
  }

  /// Read templates from local Drift cache.
  Future<List<MessageTemplate>> _getTemplatesFromDrift() async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM wa_message_templates WHERE is_deleted = 0',
          )
          .get();
      return rows.map((r) => MessageTemplate.fromJson(r.data)).toList();
    } catch (e) {
      LoggerService.d(
        'WhatsAppOffline',
        'Drift fallback for templates failed: $e',
      );
      return [];
    }
  }

  /// Read rules from local Drift cache.
  Future<List<AutomationRule>> _getRulesFromDrift() async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM wa_automation_rules WHERE is_deleted = 0',
          )
          .get();
      return rows.map((r) => AutomationRule.fromJson(r.data)).toList();
    } catch (e) {
      LoggerService.d('WhatsAppOffline', 'Drift fallback for rules failed: $e');
      return [];
    }
  }

  /// Read customers from local Drift cache.
  Future<List<WhatsAppCustomer>> _getCustomersFromDrift() async {
    try {
      final rows = await _db
          .customSelect('SELECT * FROM wa_customers WHERE is_deleted = 0')
          .get();
      return rows.map((r) => WhatsAppCustomer.fromJson(r.data)).toList();
    } catch (e) {
      LoggerService.d(
        'WhatsAppOffline',
        'Drift fallback for customers failed: $e',
      );
      return [];
    }
  }

  // ── Private — Connectivity ────────────────────────────────────────────────

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    // SyncManager handles replay automatically on reconnection.
    // The OfflineQueue's pending mutations will be replayed in FIFO order.
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnline) {
      LoggerService.d(
        'WhatsAppOffline',
        'Connection restored — SyncManager will replay pending mutations.',
      );
    }
  }

  Future<bool> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  bool _isNetworkError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('socket') ||
        msg.contains('timeout') ||
        msg.contains('network') ||
        msg.contains('offline');
  }
}
