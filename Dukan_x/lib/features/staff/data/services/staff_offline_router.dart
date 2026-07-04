// ============================================================================
// STAFF OFFLINE ROUTER
// ============================================================================
// Routes offline-capable writes through OfflineQueue and reads through Drift
// local cache, based on the per-entity conflict policies defined in
// [StaffConflictPolicyRegistry].
//
// Implements Req 12.1 (explicit Conflict_Policy per entity) and
// Req 12.2 (offline-capable operations proceed against Local_Database).
//
// Author: DukanX Engineering
// ============================================================================

import 'package:flutter/foundation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/offline_queue.dart';
import 'conflict_policy_registry.dart';

/// Connectivity status callback used by the router to determine whether the
/// device is currently online.
typedef ConnectivityChecker = bool Function();

/// Result of an offline-routed write operation.
class OfflineWriteResult {
  /// Whether the write was queued offline or sent directly.
  final bool queuedOffline;

  /// The mutation ID if queued offline; null if sent online.
  final String? mutationId;

  /// Error message if the operation failed.
  final String? error;

  /// Whether the operation succeeded (queued or sent).
  bool get isSuccess => error == null;

  const OfflineWriteResult._({
    required this.queuedOffline,
    this.mutationId,
    this.error,
  });

  factory OfflineWriteResult.queued(String mutationId) =>
      OfflineWriteResult._(queuedOffline: true, mutationId: mutationId);

  factory OfflineWriteResult.sentOnline() =>
      const OfflineWriteResult._(queuedOffline: false);

  factory OfflineWriteResult.failure(String error) =>
      OfflineWriteResult._(queuedOffline: false, error: error);
}

/// Routes staff module writes and reads through the appropriate offline/online
/// path based on the entity's registered [StaffEntityConflictPolicy].
///
/// - **Offline-capable writes** (create/update) are routed through [OfflineQueue]
///   when the device is offline.
/// - **Reads** for entities with offline view capability fall back to the Drift
///   local database when offline.
/// - **Online-only entities** (e.g., PayrollRun) reject writes when offline.
///
/// Usage:
/// ```dart
/// final router = StaffOfflineRouter(
///   offlineQueue: queue,
///   database: db,
///   isOnline: () => connectivityNotifier.isOnline,
///   tenantId: sessionManager.tenantId,
/// );
///
/// // Offline-capable write (e.g., create attendance event)
/// final result = await router.routeWrite(
///   entityType: StaffConflictPolicyRegistry.attendanceEvent,
///   operationType: MutationOperationType.create,
///   payload: event.toJson(),
///   recordId: event.eventId,
/// );
/// ```
class StaffOfflineRouter {
  final OfflineQueue _offlineQueue;
  final AppDatabase _database;
  final ConnectivityChecker _isOnline;
  final String _tenantId;

  StaffOfflineRouter({
    required OfflineQueue offlineQueue,
    required AppDatabase database,
    required ConnectivityChecker isOnline,
    required String tenantId,
  }) : _offlineQueue = offlineQueue,
       _database = database,
       _isOnline = isOnline,
       _tenantId = tenantId;

  // ─── Write Routing ─────────────────────────────────────────────────────────

  /// Route a write operation through the appropriate path.
  ///
  /// If the device is offline and the entity supports the given operation
  /// offline, the write is enqueued to [OfflineQueue]. Otherwise, the caller
  /// is expected to handle the online API call (this method returns
  /// [OfflineWriteResult.sentOnline] to signal that the caller should proceed
  /// with the REST call).
  ///
  /// Returns [OfflineWriteResult.failure] if the entity does not support the
  /// operation offline and the device is offline.
  Future<OfflineWriteResult> routeWrite({
    required String entityType,
    required MutationOperationType operationType,
    required Map<String, dynamic> payload,
    required String recordId,
  }) async {
    final policy = StaffConflictPolicyRegistry.forEntity(entityType);

    if (policy == null) {
      return OfflineWriteResult.failure(
        'Unknown entity type: $entityType. '
        'No conflict policy registered.',
      );
    }

    // If online, always prefer the direct API path.
    if (_isOnline()) {
      return OfflineWriteResult.sentOnline();
    }

    // Device is offline — check if the operation is allowed offline.
    final offlineCapability = _mapOperationToCapability(operationType);
    if (offlineCapability == null ||
        !policy.offlineCapabilities.contains(offlineCapability)) {
      // Entity does not support this operation offline.
      if (policy.isOnlineOnly) {
        return OfflineWriteResult.failure(
          'Entity "$entityType" is online-only. '
          'Please connect to the internet to perform this operation.',
        );
      }
      return OfflineWriteResult.failure(
        'Entity "$entityType" does not support '
        '"${operationType.value}" operations offline.',
      );
    }

    // Enqueue the mutation for later sync.
    final mutation = OfflineMutation(
      tenantId: _tenantId,
      operationType: operationType,
      entityType: entityType,
      payload: payload,
      affectedRecordId: recordId,
    );

    final result = await _offlineQueue.enqueue(mutation);
    if (result.success) {
      debugPrint(
        'StaffOfflineRouter: Queued offline $entityType '
        '${operationType.value} (id: ${result.mutationId})',
      );
      return OfflineWriteResult.queued(result.mutationId!);
    } else {
      return OfflineWriteResult.failure(result.error ?? 'Queue enqueue failed');
    }
  }

  // ─── Read Routing ──────────────────────────────────────────────────────────

  /// Determines whether a read for the given entity should fall back to the
  /// local Drift cache.
  ///
  /// Returns `true` if the device is offline and the entity supports offline
  /// reads (view capability). The caller uses this to decide whether to query
  /// Drift or the remote API.
  bool shouldReadFromCache(String entityType) {
    if (_isOnline()) return false;

    final policy = StaffConflictPolicyRegistry.forEntity(entityType);
    if (policy == null) return false;

    return policy.supportsOfflineRead;
  }

  /// Returns `true` if the entity is view-only from cache (never written
  /// offline). Used by payslip views to confirm read-only offline behavior.
  bool isReadOnlyCache(String entityType) {
    final policy = StaffConflictPolicyRegistry.forEntity(entityType);
    if (policy == null) return false;
    return policy.resolutionStrategy ==
        ConflictResolutionStrategy.readOnlyCache;
  }

  /// Returns `true` if the entity is strictly online-only (e.g., PayrollRun).
  bool isOnlineOnly(String entityType) {
    final policy = StaffConflictPolicyRegistry.forEntity(entityType);
    if (policy == null) return true; // Unknown entities default to online-only
    return policy.isOnlineOnly;
  }

  // ─── Conflict Policy Queries ───────────────────────────────────────────────

  /// Get the conflict resolution strategy for an entity.
  ConflictResolutionStrategy? getResolutionStrategy(String entityType) {
    return StaffConflictPolicyRegistry.forEntity(
      entityType,
    )?.resolutionStrategy;
  }

  /// Check if conflicts for this entity should be surfaced to the user.
  bool shouldSurfaceConflicts(String entityType) {
    return StaffConflictPolicyRegistry.forEntity(
          entityType,
        )?.surfaceUnresolvable ??
        false;
  }

  /// Get the merge key fields for deduplication during sync.
  List<String> getMergeKeyFields(String entityType) {
    return StaffConflictPolicyRegistry.forEntity(entityType)?.mergeKeyFields ??
        const [];
  }

  /// Get the additive merge fields (fields merged via union, not overwrite).
  List<String> getAdditiveFields(String entityType) {
    return StaffConflictPolicyRegistry.forEntity(entityType)?.additiveFields ??
        const [];
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  /// Map a mutation operation type to an offline capability.
  OfflineCapability? _mapOperationToCapability(
    MutationOperationType operationType,
  ) {
    switch (operationType) {
      case MutationOperationType.create:
        return OfflineCapability.create;
      case MutationOperationType.update:
        return OfflineCapability.update;
      case MutationOperationType.delete:
        // Deletes are not in the offline capability set for staff entities;
        // they require online confirmation to prevent accidental data loss.
        return null;
    }
  }
}
