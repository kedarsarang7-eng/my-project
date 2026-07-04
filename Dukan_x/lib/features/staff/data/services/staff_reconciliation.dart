// ============================================================================
// STAFF RECONCILIATION HANDLER — Universal Staff Management
// ============================================================================
// Implements per-entity conflict reconciliation on reconnect (Req 12.3, 12.4).
// Called by the SyncManager when connectivity is restored to reconcile local
// changes with the server-authoritative state according to each entity's
// Conflict_Policy defined in [StaffConflictPolicyRegistry].
//
// Reconciliation strategies:
//   - appendOnly (AttendanceEvent): merge by (eventId, timestamp), skip dupes
//   - serverAuthoritative (LeaveRequest): optimistic local → server wins;
//     conflicting approvals surface to manager (Req 4.3, 4.4)
//   - lastWriterWinsWithAdditiveMerge (Task): scalars use LWW; comments/
//     checklists merged additively
//   - fieldLevelMerge (Employee/Dept/Designation): non-conflicting fields
//     auto-merge; conflicting fields → surface via conflict_resolution_dialog
//   - readOnlyCache (Payslip): no reconciliation needed; local is read-only
//   - onlineOnly (PayrollRun): never offline; no reconciliation
//
// Requirements: 4.3, 4.4, 12.3, 12.4
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/sync/sync_conflict.dart';
import '../../../../core/sync/sync_manager.dart';
import 'conflict_policy_registry.dart';

/// Result of reconciling a single entity record.
class ReconciliationOutcome {
  /// The entity type that was reconciled.
  final String entityType;

  /// The record identifier.
  final String recordId;

  /// Whether the reconciliation succeeded without user intervention.
  final bool resolved;

  /// The action taken: 'merged', 'server_accepted', 'local_kept',
  /// 'duplicate_skipped', 'conflict_surfaced', 'no_action'.
  final String action;

  /// Merged data payload (when resolved automatically).
  final Map<String, dynamic>? resolvedData;

  /// Conflict to surface to the user (when [resolved] is false).
  final SyncConflict? unresolvedConflict;

  /// Informational message for logging.
  final String message;

  const ReconciliationOutcome({
    required this.entityType,
    required this.recordId,
    required this.resolved,
    required this.action,
    this.resolvedData,
    this.unresolvedConflict,
    this.message = '',
  });
}

/// Batch reconciliation result for an entire sync cycle.
class StaffReconciliationResult {
  final int totalProcessed;
  final int autoResolved;
  final int conflictsSurfaced;
  final int duplicatesSkipped;
  final int errors;
  final List<ReconciliationOutcome> outcomes;
  final Duration duration;

  const StaffReconciliationResult({
    required this.totalProcessed,
    required this.autoResolved,
    required this.conflictsSurfaced,
    required this.duplicatesSkipped,
    required this.errors,
    required this.outcomes,
    required this.duration,
  });
}

/// Callback for surfacing unresolvable conflicts to an authorized user.
/// Implementations should display [conflict_resolution_dialog.dart].
typedef ConflictSurfaceCallback =
    Future<ConflictChoice?> Function(SyncConflict conflict);

/// Staff-specific reconciliation handler.
///
/// The SyncManager calls [reconcileOnReconnect] when connectivity is restored.
/// For each queued local change, the handler applies the entity's conflict
/// policy to reconcile against the server-authoritative state.
///
/// Usage:
/// ```dart
/// final handler = StaffReconciliationHandler(
///   onConflictSurface: (conflict) => showConflictResolutionDialog(ctx, conflict),
/// );
/// final result = await handler.reconcileOnReconnect(
///   localChanges: pendingMutations,
///   serverStates: fetchedServerRecords,
/// );
/// ```
class StaffReconciliationHandler {
  /// Callback to surface unresolvable conflicts to the user.
  final ConflictSurfaceCallback? onConflictSurface;

  StaffReconciliationHandler({this.onConflictSurface});

  /// Reconcile all pending local changes against server state on reconnect.
  ///
  /// [localChanges] — pending offline mutations grouped by entity type.
  /// [serverStates] — server-authoritative records fetched on reconnect,
  ///   keyed by record ID.
  Future<StaffReconciliationResult> reconcileOnReconnect({
    required List<LocalChangeRecord> localChanges,
    required Map<String, Map<String, dynamic>> serverStates,
  }) async {
    final stopwatch = Stopwatch()..start();
    final outcomes = <ReconciliationOutcome>[];
    int autoResolved = 0;
    int conflictsSurfaced = 0;
    int duplicatesSkipped = 0;
    int errors = 0;

    for (final change in localChanges) {
      try {
        final policy = StaffConflictPolicyRegistry.forEntity(change.entityType);

        if (policy == null) {
          // Unknown entity — skip with a warning
          debugPrint(
            'StaffReconciliation: No policy for entity "${change.entityType}", skipping.',
          );
          errors++;
          continue;
        }

        final serverData = serverStates[change.recordId];
        final outcome = await _reconcileRecord(
          change: change,
          serverData: serverData,
          policy: policy,
        );

        outcomes.add(outcome);

        if (outcome.resolved) {
          if (outcome.action == 'duplicate_skipped') {
            duplicatesSkipped++;
          } else {
            autoResolved++;
          }
        } else {
          conflictsSurfaced++;
        }
      } catch (e) {
        debugPrint(
          'StaffReconciliation: Error reconciling ${change.recordId}: $e',
        );
        errors++;
      }
    }

    stopwatch.stop();

    debugPrint(
      'StaffReconciliation: Completed. '
      'Processed=${localChanges.length}, '
      'AutoResolved=$autoResolved, '
      'ConflictsSurfaced=$conflictsSurfaced, '
      'DupesSkipped=$duplicatesSkipped, '
      'Errors=$errors, '
      'Duration=${stopwatch.elapsed.inMilliseconds}ms',
    );

    return StaffReconciliationResult(
      totalProcessed: localChanges.length,
      autoResolved: autoResolved,
      conflictsSurfaced: conflictsSurfaced,
      duplicatesSkipped: duplicatesSkipped,
      errors: errors,
      outcomes: outcomes,
      duration: stopwatch.elapsed,
    );
  }

  /// Reconcile a single record against its policy.
  Future<ReconciliationOutcome> _reconcileRecord({
    required LocalChangeRecord change,
    required Map<String, dynamic>? serverData,
    required StaffEntityConflictPolicy policy,
  }) async {
    switch (policy.resolutionStrategy) {
      case ConflictResolutionStrategy.appendOnly:
        return _reconcileAppendOnly(change, serverData, policy);

      case ConflictResolutionStrategy.serverAuthoritative:
        return _reconcileServerAuthoritative(change, serverData, policy);

      case ConflictResolutionStrategy.lastWriterWinsWithAdditiveMerge:
        return _reconcileLastWriterWinsAdditive(change, serverData, policy);

      case ConflictResolutionStrategy.fieldLevelMerge:
        return _reconcileFieldLevelMerge(change, serverData, policy);

      case ConflictResolutionStrategy.readOnlyCache:
        return ReconciliationOutcome(
          entityType: change.entityType,
          recordId: change.recordId,
          resolved: true,
          action: 'no_action',
          message: 'Read-only cache entity — no reconciliation needed.',
        );

      case ConflictResolutionStrategy.onlineOnly:
        return ReconciliationOutcome(
          entityType: change.entityType,
          recordId: change.recordId,
          resolved: true,
          action: 'no_action',
          message: 'Online-only entity — should not have offline changes.',
        );
    }
  }

  // ─── Append-Only (AttendanceEvent) ─────────────────────────────────────────

  /// Merge by (eventId, timestamp). Duplicates are silently skipped.
  /// No user conflict is ever surfaced for attendance events.
  ReconciliationOutcome _reconcileAppendOnly(
    LocalChangeRecord change,
    Map<String, dynamic>? serverData,
    StaffEntityConflictPolicy policy,
  ) {
    // If the server already has this record (matched by merge keys),
    // skip as duplicate.
    if (serverData != null) {
      final localKey = _extractMergeKey(
        change.localData,
        policy.mergeKeyFields,
      );
      final serverKey = _extractMergeKey(serverData, policy.mergeKeyFields);

      if (localKey == serverKey) {
        return ReconciliationOutcome(
          entityType: change.entityType,
          recordId: change.recordId,
          resolved: true,
          action: 'duplicate_skipped',
          message:
              'Attendance event already exists on server '
              '(merged by ${policy.mergeKeyFields.join(", ")}). Skipped.',
        );
      }
    }

    // No duplicate found — local event should be pushed to server as-is.
    return ReconciliationOutcome(
      entityType: change.entityType,
      recordId: change.recordId,
      resolved: true,
      action: 'local_kept',
      resolvedData: change.localData,
      message: 'New attendance event — will be pushed to server.',
    );
  }

  // ─── Server-Authoritative (LeaveRequest) ───────────────────────────────────

  /// Optimistic local update reconciled against server-authoritative state.
  /// If server has a different status (e.g., already approved by another
  /// manager while we were offline), the local optimistic state is corrected.
  /// If concurrent offline approvals produce conflicting outcomes, surface to
  /// a manager for resolution (Req 4.4).
  Future<ReconciliationOutcome> _reconcileServerAuthoritative(
    LocalChangeRecord change,
    Map<String, dynamic>? serverData,
    StaffEntityConflictPolicy policy,
  ) async {
    // No server record yet — local is authoritative (new record created offline).
    if (serverData == null) {
      return ReconciliationOutcome(
        entityType: change.entityType,
        recordId: change.recordId,
        resolved: true,
        action: 'local_kept',
        resolvedData: change.localData,
        message: 'No server state found — local change is new. Push to server.',
      );
    }

    final localStatus = change.localData['status'] as String?;
    final serverStatus = serverData['status'] as String?;
    final localVersion = (change.localData['version'] as num?)?.toInt() ?? 0;
    final serverVersion = (serverData['version'] as num?)?.toInt() ?? 0;

    // Server version is newer or equal — server wins.
    if (serverVersion >= localVersion) {
      // Check for conflicting approval states (Req 4.4).
      if (_isConflictingApproval(localStatus, serverStatus)) {
        // Surface to manager for resolution.
        return await _surfaceLeaveConflict(change, serverData, policy);
      }

      // Server is authoritative — accept server state.
      return ReconciliationOutcome(
        entityType: change.entityType,
        recordId: change.recordId,
        resolved: true,
        action: 'server_accepted',
        resolvedData: serverData,
        message:
            'Server-authoritative: reconciled local "$localStatus" to '
            'server "$serverStatus" (v$serverVersion >= v$localVersion).',
      );
    }

    // Local version is newer (shouldn't normally happen for server-authoritative
    // entities, but handle gracefully) — accept server anyway per policy.
    return ReconciliationOutcome(
      entityType: change.entityType,
      recordId: change.recordId,
      resolved: true,
      action: 'server_accepted',
      resolvedData: serverData,
      message:
          'Server-authoritative: accepting server state despite local '
          'version being newer (v$localVersion > v$serverVersion).',
    );
  }

  /// Detect if local and server have conflicting approval outcomes.
  /// E.g., local approved + server rejected, or vice versa.
  bool _isConflictingApproval(String? localStatus, String? serverStatus) {
    if (localStatus == null || serverStatus == null) return false;
    if (localStatus == serverStatus) return false;

    const approvalStatuses = {'approved', 'rejected'};
    // Both are terminal approval statuses but differ — that's a conflict.
    return approvalStatuses.contains(localStatus) &&
        approvalStatuses.contains(serverStatus);
  }

  /// Surface a conflicting leave approval to a manager via the dialog.
  Future<ReconciliationOutcome> _surfaceLeaveConflict(
    LocalChangeRecord change,
    Map<String, dynamic> serverData,
    StaffEntityConflictPolicy policy,
  ) async {
    final conflict = SyncConflict(
      documentId: change.recordId,
      collection: change.entityType,
      localData: change.localData,
      serverData: serverData,
      localModifiedAt: change.localModifiedAt,
      serverModifiedAt: _parseDateTime(serverData['updatedAt']),
      localVersion: (change.localData['version'] as num?)?.toInt() ?? 0,
      serverVersion: (serverData['version'] as num?)?.toInt() ?? 0,
    );

    // Attempt to surface to user.
    if (onConflictSurface != null) {
      final choice = await onConflictSurface!(conflict);

      if (choice != null) {
        switch (choice) {
          case ConflictChoice.keepLocal:
            return ReconciliationOutcome(
              entityType: change.entityType,
              recordId: change.recordId,
              resolved: true,
              action: 'local_kept',
              resolvedData: change.localData,
              message: 'Manager chose to keep local leave approval.',
            );
          case ConflictChoice.keepServer:
            return ReconciliationOutcome(
              entityType: change.entityType,
              recordId: change.recordId,
              resolved: true,
              action: 'server_accepted',
              resolvedData: serverData,
              message: 'Manager chose to accept server leave state.',
            );
          case ConflictChoice.merge:
            // For leave requests, merge means accept server (authoritative).
            return ReconciliationOutcome(
              entityType: change.entityType,
              recordId: change.recordId,
              resolved: true,
              action: 'server_accepted',
              resolvedData: serverData,
              message: 'Manager chose merge — server-authoritative applied.',
            );
        }
      }
    }

    // No callback or user dismissed — conflict remains unresolved.
    return ReconciliationOutcome(
      entityType: change.entityType,
      recordId: change.recordId,
      resolved: false,
      action: 'conflict_surfaced',
      unresolvedConflict: conflict,
      message:
          'Conflicting leave approval: local="${change.localData['status']}", '
          'server="${serverData['status']}". Surfaced to manager.',
    );
  }

  // ─── Last-Writer-Wins + Additive Merge (Task) ─────────────────────────────

  /// Scalar fields use last-writer-wins (compare updatedAt timestamps).
  /// List fields (comments, checklist) merge additively (union of items).
  ReconciliationOutcome _reconcileLastWriterWinsAdditive(
    LocalChangeRecord change,
    Map<String, dynamic>? serverData,
    StaffEntityConflictPolicy policy,
  ) {
    // No server record — local is new.
    if (serverData == null) {
      return ReconciliationOutcome(
        entityType: change.entityType,
        recordId: change.recordId,
        resolved: true,
        action: 'local_kept',
        resolvedData: change.localData,
        message: 'No server state — new task will be pushed.',
      );
    }

    final localUpdatedAt = _parseDateTime(change.localData['updatedAt']);
    final serverUpdatedAt = _parseDateTime(serverData['updatedAt']);

    // Start with the winner's scalars.
    final Map<String, dynamic> merged;
    if (localUpdatedAt.isAfter(serverUpdatedAt)) {
      merged = Map<String, dynamic>.from(change.localData);
    } else {
      merged = Map<String, dynamic>.from(serverData);
    }

    // Additively merge list fields (union, deduped).
    for (final field in policy.additiveFields) {
      final localList = _toList(change.localData[field]);
      final serverList = _toList(serverData[field]);
      merged[field] = _mergeListsAdditively(localList, serverList);
    }

    return ReconciliationOutcome(
      entityType: change.entityType,
      recordId: change.recordId,
      resolved: true,
      action: 'merged',
      resolvedData: merged,
      message:
          'Task merged: scalars from '
          '${localUpdatedAt.isAfter(serverUpdatedAt) ? "local" : "server"}, '
          'additive fields unioned.',
    );
  }

  // ─── Field-Level Merge (Employee/Dept/Designation) ─────────────────────────

  /// Merge field-by-field. Fields changed only on one side are accepted.
  /// Fields changed on both sides with different values → surface to user
  /// if [surfaceUnresolvable] is true.
  Future<ReconciliationOutcome> _reconcileFieldLevelMerge(
    LocalChangeRecord change,
    Map<String, dynamic>? serverData,
    StaffEntityConflictPolicy policy,
  ) async {
    // No server record — local is new (unlikely for Employee, but handle).
    if (serverData == null) {
      return ReconciliationOutcome(
        entityType: change.entityType,
        recordId: change.recordId,
        resolved: true,
        action: 'local_kept',
        resolvedData: change.localData,
        message: 'No server state — local change will be pushed.',
      );
    }

    // Use the base record (last-synced version before offline edits) to
    // determine which fields were changed on each side.
    final baseData = change.baseData ?? serverData;
    final conflictingFields = <String>[];
    final merged = Map<String, dynamic>.from(serverData);

    // Gather all field keys from both sides.
    final allKeys = <String>{...change.localData.keys, ...serverData.keys};

    for (final key in allKeys) {
      if (key.startsWith('_')) continue; // Skip metadata fields

      final localVal = change.localData[key];
      final serverVal = serverData[key];
      final baseVal = baseData[key];

      final localChanged = _isDifferent(localVal, baseVal);
      final serverChanged = _isDifferent(serverVal, baseVal);

      if (localChanged && !serverChanged) {
        // Only local changed — accept local value.
        merged[key] = localVal;
      } else if (!localChanged && serverChanged) {
        // Only server changed — keep server (already in merged).
      } else if (localChanged && serverChanged) {
        // Both changed — check if they agree.
        if (_isDifferent(localVal, serverVal)) {
          conflictingFields.add(key);
        }
        // If both changed to the same value, keep it (already in merged).
      }
      // Neither changed — keep base/server (already in merged).
    }

    // If no conflicting fields, merge resolved automatically.
    if (conflictingFields.isEmpty) {
      return ReconciliationOutcome(
        entityType: change.entityType,
        recordId: change.recordId,
        resolved: true,
        action: 'merged',
        resolvedData: merged,
        message: 'Field-level merge succeeded — no conflicts.',
      );
    }

    // Conflicting fields exist — surface to user if policy says so.
    if (policy.surfaceUnresolvable && onConflictSurface != null) {
      final conflict = SyncConflict(
        documentId: change.recordId,
        collection: change.entityType,
        localData: change.localData,
        serverData: serverData,
        localModifiedAt: change.localModifiedAt,
        serverModifiedAt: _parseDateTime(serverData['updatedAt']),
        localVersion: (change.localData['version'] as num?)?.toInt() ?? 0,
        serverVersion: (serverData['version'] as num?)?.toInt() ?? 0,
      );

      final choice = await onConflictSurface!(conflict);

      if (choice != null) {
        switch (choice) {
          case ConflictChoice.keepLocal:
            return ReconciliationOutcome(
              entityType: change.entityType,
              recordId: change.recordId,
              resolved: true,
              action: 'local_kept',
              resolvedData: change.localData,
              message:
                  'User chose local version for conflicting fields: '
                  '${conflictingFields.join(", ")}.',
            );
          case ConflictChoice.keepServer:
            return ReconciliationOutcome(
              entityType: change.entityType,
              recordId: change.recordId,
              resolved: true,
              action: 'server_accepted',
              resolvedData: serverData,
              message:
                  'User chose server version for conflicting fields: '
                  '${conflictingFields.join(", ")}.',
            );
          case ConflictChoice.merge:
            // Smart merge: use server for conflicting fields (conservative).
            return ReconciliationOutcome(
              entityType: change.entityType,
              recordId: change.recordId,
              resolved: true,
              action: 'merged',
              resolvedData: merged,
              message:
                  'User chose smart merge. Server values kept for conflicts: '
                  '${conflictingFields.join(", ")}.',
            );
        }
      }
    }

    // Unresolved: return the conflict for later handling.
    return ReconciliationOutcome(
      entityType: change.entityType,
      recordId: change.recordId,
      resolved: false,
      action: 'conflict_surfaced',
      unresolvedConflict: SyncConflict(
        documentId: change.recordId,
        collection: change.entityType,
        localData: change.localData,
        serverData: serverData,
        localModifiedAt: change.localModifiedAt,
        serverModifiedAt: _parseDateTime(serverData['updatedAt']),
        localVersion: (change.localData['version'] as num?)?.toInt() ?? 0,
        serverVersion: (serverData['version'] as num?)?.toInt() ?? 0,
      ),
      message:
          'Field-level merge: ${conflictingFields.length} unresolved field(s): '
          '${conflictingFields.join(", ")}.',
    );
  }

  // ─── Utility Helpers ───────────────────────────────────────────────────────

  /// Extract a composite merge key from a data map.
  String _extractMergeKey(Map<String, dynamic> data, List<String> keyFields) {
    return keyFields.map((f) => data[f]?.toString() ?? '').join('|');
  }

  /// Parse a DateTime from various formats (ISO string or null).
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Check if two values are different (deep equality for simple types).
  bool _isDifferent(dynamic a, dynamic b) {
    if (a == null && b == null) return false;
    if (a == null || b == null) return true;
    return a.toString() != b.toString();
  }

  /// Safely cast a value to a `List<dynamic>`.
  List<dynamic> _toList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    return [];
  }

  /// Merge two lists additively (union by string representation).
  List<dynamic> _mergeListsAdditively(
    List<dynamic> localList,
    List<dynamic> serverList,
  ) {
    final seen = <String>{};
    final result = <dynamic>[];

    // Add server items first (authoritative baseline).
    for (final item in serverList) {
      final key = item.toString();
      if (seen.add(key)) {
        result.add(item);
      }
    }

    // Add local items that aren't already present.
    for (final item in localList) {
      final key = item.toString();
      if (seen.add(key)) {
        result.add(item);
      }
    }

    return result;
  }
}

/// Represents a local change record pending reconciliation.
class LocalChangeRecord {
  /// The staff entity type (matches policy registry keys).
  final String entityType;

  /// The unique record identifier.
  final String recordId;

  /// The local data payload (current offline state).
  final Map<String, dynamic> localData;

  /// The base data before offline edits (last-synced snapshot).
  /// Used by field-level merge to detect which side changed a field.
  final Map<String, dynamic>? baseData;

  /// When the local change was last modified.
  final DateTime localModifiedAt;

  /// The offline mutation operation type.
  final String operationType;

  const LocalChangeRecord({
    required this.entityType,
    required this.recordId,
    required this.localData,
    this.baseData,
    required this.localModifiedAt,
    this.operationType = 'update',
  });
}
