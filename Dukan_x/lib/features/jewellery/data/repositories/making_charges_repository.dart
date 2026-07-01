// Making Charges Repository - Configuration Management
// Feature 2: Making Charges Calculator
//
// Offline-first parity: VERIFIED (Phase 5, Task 10.2)
// Hive boxes: making_charges_configs, making_charges_sync_queue
// Pattern: initialize() → Hive boxes, _addToSyncQueue(), _syncConfig(), syncAll()
// Matches jewellery_repository_offline.dart offline-first architecture.

import 'dart:async';
import 'package:hive/hive.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/sync/version_reconciliation.dart';
import '../../../../core/utils/rid_generator.dart';
import '../models/making_charges_model.dart';

/// Repository for managing making charges configurations
class MakingChargesRepository {
  final ApiClient _client;
  final SessionManager _session;

  late Box<MakingChargesConfig> _configsBox;
  late Box<Map> _syncQueueBox;

  bool _initialized = false;

  MakingChargesRepository(this._client, this._session);

  Future<void> initialize() async {
    if (_initialized) return;

    _configsBox = await Hive.openBox<MakingChargesConfig>(
      'making_charges_configs',
    );
    _syncQueueBox = await Hive.openBox<Map>('making_charges_sync_queue');

    // Load presets if empty
    if (_configsBox.isEmpty) {
      await _loadPresets();
    }

    _initialized = true;
  }

  /// Load preset configurations
  Future<void> _loadPresets() async {
    final tenantId = _session.ownerId ?? 'default';
    final now = DateTime.now();

    final presets = [
      MakingChargesPresets.simpleChain(),
      MakingChargesPresets.ringWithStone(),
      MakingChargesPresets.bridalJewellery(),
      MakingChargesPresets.lightWeight(),
    ];

    for (final preset in presets) {
      final config = preset.copyWith(
        tenantId: tenantId,
        synced: true,
        createdAt: now,
        updatedAt: now,
      );
      await _configsBox.put(config.id, config);
    }
  }

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  /// Create new making charges configuration
  Future<MakingChargesConfig> createConfig(
    CreateMakingChargesConfigRequest request,
  ) async {
    await initialize();

    final now = DateTime.now();
    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);

    final config = MakingChargesConfig(
      id: id,
      tenantId: tenantId,
      name: request.name,
      description: request.description,
      type: request.type,
      ratePaisaPerGram: request.ratePerGram != null
          ? (request.ratePerGram! * 100).round()
          : null,
      percentageOfMetalValue: request.percentageOfMetalValue,
      fixedAmountPaisa: request.fixedAmount != null
          ? (request.fixedAmount! * 100).round()
          : null,
      tieredRates: request.tieredRates,
      complexityRates: request.complexityRates,
      baseAmountPaisa: request.baseAmount != null
          ? (request.baseAmount! * 100).round()
          : null,
      additionalPercentage: request.additionalPercentage,
      minimumChargePaisa: request.minimumCharge != null
          ? (request.minimumCharge! * 100).round()
          : null,
      maximumChargePaisa: request.maximumCharge != null
          ? (request.maximumCharge! * 100).round()
          : null,
      applyOnWastage: request.applyOnWastage,
      includeStoneWeight: request.includeStoneWeight,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      synced: false,
    );

    await _configsBox.put(id, config);
    await _addToSyncQueue('create', id);

    _syncConfig(config);

    return config;
  }

  /// Get all configurations
  Future<List<MakingChargesConfig>> getConfigs({
    bool includeInactive = false,
    MakingChargeType? type,
  }) async {
    await initialize();

    final tenantId = _session.ownerId;

    var configs = _configsBox.values.where((c) {
      if (c.tenantId != tenantId) return false;
      if (!includeInactive && !c.isActive) return false;
      if (type != null && c.type != type) return false;
      return true;
    }).toList();

    // Sort by name
    configs.sort((a, b) => a.name.compareTo(b.name));

    return configs;
  }

  /// Get active configurations only
  Future<List<MakingChargesConfig>> getActiveConfigs() async {
    return getConfigs(includeInactive: false);
  }

  /// Get config by ID
  Future<MakingChargesConfig?> getConfigById(String id) async {
    await initialize();
    return _configsBox.get(id);
  }

  /// Update configuration
  Future<MakingChargesConfig> updateConfig(
    String id,
    UpdateMakingChargesConfigRequest request,
  ) async {
    await initialize();

    final existing = _configsBox.get(id);
    if (existing == null) {
      throw Exception('Configuration not found: $id');
    }

    final now = DateTime.now();

    final updated = existing.copyWith(
      name: request.name ?? existing.name,
      description: request.description ?? existing.description,
      type: request.type ?? existing.type,
      ratePaisaPerGram: request.ratePerGram != null
          ? (request.ratePerGram! * 100).round()
          : existing.ratePaisaPerGram,
      percentageOfMetalValue:
          request.percentageOfMetalValue ?? existing.percentageOfMetalValue,
      fixedAmountPaisa: request.fixedAmount != null
          ? (request.fixedAmount! * 100).round()
          : existing.fixedAmountPaisa,
      tieredRates: request.tieredRates ?? existing.tieredRates,
      complexityRates: request.complexityRates ?? existing.complexityRates,
      baseAmountPaisa: request.baseAmount != null
          ? (request.baseAmount! * 100).round()
          : existing.baseAmountPaisa,
      additionalPercentage:
          request.additionalPercentage ?? existing.additionalPercentage,
      minimumChargePaisa: request.minimumCharge != null
          ? (request.minimumCharge! * 100).round()
          : existing.minimumChargePaisa,
      maximumChargePaisa: request.maximumCharge != null
          ? (request.maximumCharge! * 100).round()
          : existing.maximumChargePaisa,
      applyOnWastage: request.applyOnWastage ?? existing.applyOnWastage,
      includeStoneWeight:
          request.includeStoneWeight ?? existing.includeStoneWeight,
      isActive: request.isActive ?? existing.isActive,
      updatedAt: now,
      synced: false,
    );

    await _configsBox.put(id, updated);
    await _addToSyncQueue('update', id);

    _syncConfig(updated);

    return updated;
  }

  /// Delete (soft delete) configuration
  Future<void> deleteConfig(String id) async {
    await initialize();

    final existing = _configsBox.get(id);
    if (existing == null) return;

    // Soft delete
    final updated = existing.copyWith(
      isActive: false,
      updatedAt: DateTime.now(),
      synced: false,
    );

    await _configsBox.put(id, updated);
    await _addToSyncQueue('update', id);

    _syncConfig(updated);
  }

  /// Permanently delete configuration.
  ///
  /// Optimistic local write + enqueue contract (Requirement 14.3):
  /// 1. Mark as inactive locally in Hive immediately (retaining for sync).
  /// 2. Enqueue a 'delete' sync-queue entry.
  /// 3. Fire-and-forget sync attempt (non-blocking).
  /// The record is soft-deleted locally (isActive = false) so the sync-queue
  /// retry logic can still reference it. Physical removal from Hive occurs
  /// only after successful server-side deletion.
  Future<void> permanentlyDeleteConfig(String id) async {
    await initialize();

    final existing = _configsBox.get(id);
    if (existing == null) return;

    final deleted = existing.copyWith(
      isActive: false,
      updatedAt: DateTime.now(),
      synced: false,
    );

    await _configsBox.put(id, deleted);
    await _addToSyncQueue('delete', id);

    // Fire-and-forget sync attempt
    _syncConfig(deleted);
  }

  // ============================================================================
  // PRESETS
  // ============================================================================

  /// Get preset configurations
  List<MakingChargesConfig> getPresets() {
    return [
      MakingChargesPresets.simpleChain(),
      MakingChargesPresets.ringWithStone(),
      MakingChargesPresets.bridalJewellery(),
      MakingChargesPresets.lightWeight(),
    ];
  }

  /// Clone a preset as new config
  Future<MakingChargesConfig> clonePreset(
    String presetId, {
    String? newName,
  }) async {
    final presets = getPresets();
    final preset = presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => throw Exception('Preset not found: $presetId'),
    );

    final createRequest = CreateMakingChargesConfigRequest(
      name: newName ?? '${preset.name} (Copy)',
      description: preset.description,
      type: preset.type,
      ratePerGram: preset.displayRatePerGram,
      percentageOfMetalValue: preset.percentageOfMetalValue,
      fixedAmount: preset.displayFixedAmount,
      tieredRates: preset.tieredRates,
      complexityRates: preset.complexityRates,
      baseAmount: preset.displayBaseAmount,
      additionalPercentage: preset.additionalPercentage,
      minimumCharge: preset.displayMinimumCharge,
      maximumCharge: preset.displayMaximumCharge,
      applyOnWastage: preset.applyOnWastage,
      includeStoneWeight: preset.includeStoneWeight,
    );

    return createConfig(createRequest);
  }

  // ============================================================================
  // SYNC
  // ============================================================================

  /// Enqueue a sync-queue entry for a local write (Requirement 14.3).
  ///
  /// **Optimistic local write + enqueue contract:**
  /// Every create/update/delete in this repository follows the same pattern:
  ///   1. Persist the change to the local Hive box immediately (optimistic).
  ///   2. Call [_addToSyncQueue] to enqueue a corresponding sync-queue entry.
  ///   3. Fire-and-forget call to [_syncConfig] (non-blocking).
  Future<void> _addToSyncQueue(String operation, String entityId) async {
    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);
    await _syncQueueBox.put(id, {
      'id': id,
      'entityType': 'making_charges_config',
      'operation': operation,
      'entityId': entityId,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });
  }

  Future<void> _syncConfig(MakingChargesConfig config) async {
    try {
      // Determine operation from the sync queue entry context.
      // For permanently-deleted configs (isActive = false via permanentlyDeleteConfig),
      // we check if a 'delete' entry was just queued.
      final data = {
        'id': config.id,
        'tenantId': config.tenantId,
        'name': config.name,
        'description': config.description,
        'type': config.type.name,
        'ratePaisaPerGram': config.ratePaisaPerGram,
        'percentageOfMetalValue': config.percentageOfMetalValue,
        'fixedAmountPaisa': config.fixedAmountPaisa,
        'tieredRates': config.tieredRates?.map((t) => t.toJson()).toList(),
        'complexityRates': config.complexityRates
            ?.map((c) => c.toJson())
            .toList(),
        'baseAmountPaisa': config.baseAmountPaisa,
        'additionalPercentage': config.additionalPercentage,
        'minimumChargePaisa': config.minimumChargePaisa,
        'maximumChargePaisa': config.maximumChargePaisa,
        'applyOnWastage': config.applyOnWastage,
        'includeStoneWeight': config.includeStoneWeight,
        'isActive': config.isActive,
        'createdAt': config.createdAt.toIso8601String(),
        'updatedAt': config.updatedAt.toIso8601String(),
      };

      // Look up the pending operation from the sync queue for this entity.
      final pendingOp = _getPendingOperation(config.id);

      if (pendingOp == 'delete') {
        await _client.delete('/jewellery/making-charges-configs/${config.id}');
        // On successful server delete, remove from local Hive
        await _configsBox.delete(config.id);
        return;
      }

      Map<String, dynamic>? responseData;

      if (pendingOp == 'create') {
        final response = await _client.post(
          '/jewellery/making-charges-configs',
          body: data,
        );
        responseData = response.data as Map<String, dynamic>?;
      } else {
        final response = await _client.put(
          '/jewellery/making-charges-configs/${config.id}',
          body: data,
        );
        responseData = response.data as Map<String, dynamic>?;
      }

      // Version-based reconciliation (Requirement 14.4)
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );
      final reconciliation = VersionReconciliation.reconcile(
        localVersion:
            0, // MakingChargesConfig has no version field — use 0 baseline
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        // Server has newer data — update local config
        final serverData = reconciliation.serverData!;
        final reconciled = config.copyWith(
          isActive: serverData['isActive'] as bool? ?? config.isActive,
          ratePaisaPerGram:
              serverData['ratePaisaPerGram'] as int? ?? config.ratePaisaPerGram,
          synced: true,
          lastSyncedAt: DateTime.now(),
        );
        await _configsBox.put(config.id, reconciled);
      } else {
        final synced = config.copyWith(
          synced: true,
          lastSyncedAt: DateTime.now(),
        );
        await _configsBox.put(config.id, synced);
      }
    } catch (e) {
      print('[MakingChargesRepository] Sync failed: $e');
    }
  }

  /// Look up the most recent pending operation for an entity from the sync queue.
  String? _getPendingOperation(String entityId) {
    final entries = _syncQueueBox.values.where(
      (entry) => entry['entityId'] == entityId,
    );
    if (entries.isEmpty) return null;
    // Return the most recent entry's operation
    final sorted = entries.toList()
      ..sort(
        (a, b) =>
            (b['timestamp'] as String).compareTo(a['timestamp'] as String),
      );
    return sorted.first['operation'] as String?;
  }

  /// Sync all pending configs
  Future<void> syncAll() async {
    await initialize();

    final pending = _configsBox.values.where((c) => !c.synced).toList();

    for (final config in pending) {
      await _syncConfig(config);
    }
  }

  // ============================================================================
  // CALCULATION HISTORY (Optional - for tracking)
  // ============================================================================

  /// Store calculation history for analytics
  Future<void> logCalculation({
    required String configId,
    required MakingChargeResult result,
    required String productName,
  }) async {
    // This can be used for analytics - tracking which configs are used most
    // Implementation depends on requirements
  }
}
