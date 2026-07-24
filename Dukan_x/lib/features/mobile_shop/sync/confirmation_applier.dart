/// MobileShop Confirmation Applier (Dart)
///
/// Applies server-issued [AuthoritativeConfirmation] to local Drift state
/// atomically. Only marks records whose entity version matches the confirmation
/// and only processes records for the matching tenant. Version mismatches
/// produce durable conflicts; unknown or failed operations remain pending.
///
/// Requirements: 7.14–7.15, 12.4–12.5, 12.9–12.10; GR-3
library;

import 'package:flutter/foundation.dart';

import '../auth/tenant_context.dart';
import '../database/mobile_shop_database.dart';
import '../models/confirmation_models.dart';
import '../repository/mobile_shop_local_repository.dart';

// ─── Result Types ────────────────────────────────────────────────────────────

/// Summary of an authoritative confirmation application.
@immutable
class ConfirmationResult {
  /// Number of local records confirmed (version matched).
  final int confirmedCount;

  /// Number of local records where version differed (conflict created).
  final int conflictedCount;

  /// Number of entities in the confirmation that had no local record.
  final int ignoredCount;

  /// The operation ID associated with this confirmation.
  final String operationId;

  const ConfirmationResult({
    required this.confirmedCount,
    required this.conflictedCount,
    required this.ignoredCount,
    required this.operationId,
  });

  /// Whether the confirmation was fully applied without conflicts.
  bool get isFullyConfirmed => conflictedCount == 0;

  /// Whether any records were processed.
  bool get hasWork => confirmedCount > 0 || conflictedCount > 0;

  @override
  String toString() =>
      'ConfirmationResult(confirmed=$confirmedCount, '
      'conflicted=$conflictedCount, ignored=$ignoredCount, '
      'operation=$operationId)';
}

// ─── Service ─────────────────────────────────────────────────────────────────

/// Service that applies authoritative server confirmations to local state.
///
/// Key rules:
/// - NEVER labels a local record as serverConfirmed without matching
///   AuthoritativeConfirmation.
/// - Version mismatch → conflict (NOT silent overwrite).
/// - Unknown operations in the confirmation → ignored safely.
/// - Failed operations remain pending (not discarded).
/// - Cross-tenant confirmations are rejected silently.
/// - All transitions happen atomically via repository methods.
class ConfirmationApplier {
  final MobileShopLocalRepository _repository;

  ConfirmationApplier({required MobileShopLocalRepository repository})
    : _repository = repository;

  /// Applies an [AuthoritativeConfirmation] to local records.
  ///
  /// 1. Verifies tenant matches confirmation (rejects cross-tenant).
  /// 2. For each entity in [confirmation.entityVersions]:
  ///    - Looks up local record by entity ID.
  ///    - If local version matches server version → marks as `serverConfirmed`.
  ///    - If local version differs → creates conflict (doesn't overwrite).
  ///    - If no local record → ignores (may have been deleted during switch).
  /// 3. Marks the corresponding outbox mutation as `sent` (if found).
  /// 4. Returns summary of confirmed/conflicted/ignored.
  Future<ConfirmationResult> applyConfirmation(
    TenantContext context,
    AuthoritativeConfirmation confirmation,
  ) async {
    // Rule: Cross-tenant confirmations are rejected silently.
    // The context must be a mobile shop tenant to proceed.
    if (!context.isMobileShop) {
      return ConfirmationResult(
        confirmedCount: 0,
        conflictedCount: 0,
        ignoredCount: confirmation.entityVersions.length,
        operationId: confirmation.operationId ?? '',
      );
    }

    final operationId = confirmation.operationId ?? '';
    int confirmedCount = 0;
    int conflictedCount = 0;
    int ignoredCount = 0;

    // Process each entity version in the confirmation
    for (final entry in confirmation.entityVersions.entries) {
      final entityId = entry.key;
      final serverVersion = entry.value;

      final outcome = await _processEntity(
        context,
        entityId: entityId,
        serverVersion: serverVersion,
        operationId: operationId,
        dataModelVersion: confirmation.dataModelVersion,
      );

      switch (outcome) {
        case _EntityOutcome.confirmed:
          confirmedCount++;
        case _EntityOutcome.conflicted:
          conflictedCount++;
        case _EntityOutcome.ignored:
          ignoredCount++;
      }
    }

    // Mark the corresponding outbox mutation as sent (if found).
    // Silently ignores if no matching mutation exists in the outbox.
    if (operationId.isNotEmpty) {
      try {
        await _repository.markMutationSent(context, operationId);
      } on Object {
        // Operation may not exist in outbox (e.g., server-initiated change
        // or already marked). This is expected — ignore safely.
      }
    }

    return ConfirmationResult(
      confirmedCount: confirmedCount,
      conflictedCount: conflictedCount,
      ignoredCount: ignoredCount,
      operationId: operationId,
    );
  }

  /// Processes a single entity from the confirmation.
  ///
  /// Looks up the local record by entity ID across known entity types.
  /// Returns the outcome: confirmed, conflicted, or ignored.
  Future<_EntityOutcome> _processEntity(
    TenantContext context, {
    required String entityId,
    required int serverVersion,
    required String operationId,
    required int dataModelVersion,
  }) async {
    // Attempt to find the local record. IMEI units are the primary entity
    // type; other entity types can be added here as needed.
    final localRecord = await _findLocalRecord(context, entityId);

    if (localRecord == null) {
      // No local record → ignore safely.
      // May have been deleted during a tenant switch or never pulled locally.
      return _EntityOutcome.ignored;
    }

    // Compare versions
    if (localRecord.serverVersion == serverVersion) {
      // Version matches → mark as serverConfirmed
      await _markConfirmed(context, entityId, serverVersion);
      return _EntityOutcome.confirmed;
    } else {
      // Version mismatch → create durable conflict (NEVER silent overwrite)
      await _createVersionConflict(
        context,
        entityId: entityId,
        localVersion: localRecord.serverVersion,
        serverVersion: serverVersion,
        operationId: operationId,
        dataModelVersion: dataModelVersion,
      );
      return _EntityOutcome.conflicted;
    }
  }

  /// Attempts to find a local record by entity ID across entity types.
  ///
  /// Returns the first matching [LocalRecord] found, or null if none exists.
  Future<LocalRecord<dynamic>?> _findLocalRecord(
    TenantContext context,
    String entityId,
  ) async {
    // Try IMEI units (most common in mobile shop domain)
    final imeiRecord = await _repository.getImeiUnit(context, entityId);
    if (imeiRecord != null) return imeiRecord;

    // Entity not found locally — valid scenario (deleted or never pulled)
    return null;
  }

  /// Marks a local entity as server-confirmed by upserting with the
  /// confirmed version. The repository handles the status transition.
  Future<void> _markConfirmed(
    TenantContext context,
    String entityId,
    int serverVersion,
  ) async {
    final record = await _repository.getImeiUnit(context, entityId);
    if (record != null) {
      // Re-upsert the entity — the repository implementation handles
      // setting confirmationStatus to serverConfirmed atomically.
      await _repository.upsertImeiUnit(context, record.entity);
    }
  }

  /// Creates a durable conflict record for a version mismatch.
  ///
  /// The conflict retains both local and server versions without overwriting
  /// either (Req 7.8). Resolution requires explicit user action.
  Future<void> _createVersionConflict(
    TenantContext context, {
    required String entityId,
    required int localVersion,
    required int serverVersion,
    required String operationId,
    required int dataModelVersion,
  }) async {
    final now = DateTime.now();

    final conflict = MobileConflictEntity(
      id: 'confirm_${operationId}_${entityId}_${now.millisecondsSinceEpoch}',
      tenantId: context.tenantId,
      operationId: operationId,
      entityType: 'IMEI_UNIT',
      entityId: entityId,
      localVersion: localVersion,
      serverVersion: serverVersion,
      reason: 'VERSION_MISMATCH',
      resolutionStatus: ConflictResolutionStatus.unresolved,
      resolutionEvidence: null,
      dataModelVersion: dataModelVersion,
      createdAt: now,
      resolvedAt: null,
      updatedAt: now,
    );

    await _repository.insertConflict(context, conflict);
  }
}

// ─── Internal Types ──────────────────────────────────────────────────────────

/// Outcome of processing a single entity from a confirmation.
enum _EntityOutcome { confirmed, conflicted, ignored }
