/// MobileShop Pull Service (Dart)
///
/// Pulls change events from the canonical backend using the stored checkpoint,
/// applies them atomically with checkpoint advancement, deduplicates events
/// by (tenantId, eventId) through the event inbox, and creates durable
/// conflicts for version collisions.
///
/// Requirements: 7.4, 7.7–7.9, 7.13–7.15
library;

import '../api/api_result.dart';
import '../api/mobile_shop_api.dart';
import '../auth/tenant_context.dart';
import '../config/model_version_config.dart';
import '../database/mobile_shop_database.dart';
import '../models/sync_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import 'sync_types.dart';

/// Service responsible for pulling server changes and applying them locally.
///
/// Key behaviors:
/// - Gets checkpoint for the current bucket
/// - Calls api.pull with continuation token from checkpoint
/// - Applies pulled page atomically with checkpoint advancement
/// - Deduplicates events by (tenantId, eventId) through event inbox
/// - Creates conflicts for version collisions (Req 7.7)
class PullService {
  final MobileShopLocalRepository _repository;
  final MobileShopApi _api;

  /// Default sync bucket for all entity types.
  static const String _defaultBucket = 'ROOT';

  /// Maximum events per pull page.
  static const int _defaultPageLimit = 100;

  PullService({
    required MobileShopLocalRepository repository,
    required MobileShopApi api,
  }) : _repository = repository,
       _api = api;

  /// Pull one page of changes from the server for the given bucket.
  ///
  /// Returns the number of applied events, conflicts created, and whether
  /// more pages remain.
  Future<PullPhaseResult> pullOnePage(
    TenantContext context, {
    String bucket = _defaultBucket,
    int pageLimit = _defaultPageLimit,
  }) async {
    // Get checkpoint for the current bucket (Req 7.4)
    final checkpoint = await _repository.getCheckpoint(context, bucket);
    final continuationToken = checkpoint?.lastPosition;

    // Build pull request with continuation from checkpoint
    final request = PullRequest(
      tenantId: context.tenantId,
      dataModelVersion: kModelVersionConfig.currentVersion,
      continuationToken: continuationToken,
      limit: pageLimit,
    );

    final result = await _api.pull(request);

    switch (result) {
      case ApiSuccess<PullResponse>(:final data):
        return _applyPullPage(context, bucket, data, checkpoint);
      case ApiError<PullResponse>():
        // Server returned an error — leave checkpoint unchanged (Req 7.14)
        return PullPhaseResult.empty;
      case ApiNetworkError<PullResponse>():
        // Network error — leave checkpoint unchanged for next cycle
        return PullPhaseResult.empty;
    }
  }

  /// Apply a pulled page atomically with checkpoint advancement.
  ///
  /// For each change event:
  /// 1. Deduplicate by (tenantId, eventId) through event inbox
  /// 2. Check for version collisions with local state
  /// 3. Apply non-conflicting changes
  /// 4. Create durable conflicts for collisions
  ///
  /// The checkpoint advances atomically with the page application via
  /// [MobileShopLocalRepository.applyPulledPage].
  Future<PullPhaseResult> _applyPullPage(
    TenantContext context,
    String bucket,
    PullResponse response,
    CheckpointState? currentCheckpoint,
  ) async {
    if (response.changes.isEmpty) {
      // No changes but might need to advance token
      if (response.continuationToken != null &&
          response.continuationToken != currentCheckpoint?.lastPosition) {
        await _repository.advanceCheckpoint(
          context,
          bucket,
          response.continuationToken,
          currentCheckpoint?.serverVersion ?? 0,
        );
      }
      return PullPhaseResult(
        appliedCount: 0,
        conflictsCreated: 0,
        hasMore: response.hasMore,
      );
    }

    int appliedCount = 0;
    int conflictsCreated = 0;
    final itemsToApply = <PulledItem>[];

    for (final change in response.changes) {
      // Deduplicate by (tenantId, eventId) through event inbox (Req 7.10)
      final isNew = await _insertEventIfNew(context, change);
      if (!isNew) {
        // Already processed — skip
        continue;
      }

      // Check for version collisions with local state
      final hasConflict = await _checkVersionConflict(context, change);
      if (hasConflict) {
        // Create a durable conflict record (Req 7.7–7.8)
        await _createVersionConflict(context, change);
        conflictsCreated++;
        continue;
      }

      // Build a PulledItem for atomic application
      itemsToApply.add(
        PulledItem(
          entityType: change.entityType,
          entityId: change.entityId,
          entityVersion: change.entityVersion,
          action: change.action,
          snapshot: change.snapshot,
          deleted: change.deleted ?? false,
        ),
      );
    }

    // Apply items atomically with checkpoint advancement (Req 7.4, 7.15)
    if (itemsToApply.isNotEmpty) {
      final maxVersion = response.changes
          .map((c) => c.entityVersion)
          .fold<int>(
            currentCheckpoint?.serverVersion ?? 0,
            (a, b) => a > b ? a : b,
          );

      await _repository.applyPulledPage(
        context,
        bucket: bucket,
        items: itemsToApply,
        newCheckpoint: response.continuationToken,
        serverVersion: maxVersion,
      );
      appliedCount = itemsToApply.length;
    } else if (response.continuationToken != null) {
      // No items applied but advance checkpoint for continuation
      await _repository.advanceCheckpoint(
        context,
        bucket,
        response.continuationToken,
        currentCheckpoint?.serverVersion ?? 0,
      );
    }

    return PullPhaseResult(
      appliedCount: appliedCount,
      conflictsCreated: conflictsCreated,
      hasMore: response.hasMore,
    );
  }

  /// Insert event into the inbox for deduplication.
  ///
  /// Returns true if the event is new (not a duplicate).
  Future<bool> _insertEventIfNew(
    TenantContext context,
    ChangeEvent change,
  ) async {
    final event = MobileEventInboxEntity(
      id: 'evt_${context.tenantId}_${change.eventId}',
      tenantId: context.tenantId,
      eventId: change.eventId,
      entityType: change.entityType,
      entityId: change.entityId,
      version: change.entityVersion,
      action: change.action,
      dataModelVersion: change.dataModelVersion,
      receivedAt: DateTime.now(),
      processedAt: null,
      updatedAt: DateTime.now(),
    );

    return _repository.insertEventIfNotExists(context, event);
  }

  /// Check if a change event conflicts with the local version.
  ///
  /// A conflict occurs when:
  /// - The local record has a pending mutation (not yet server-confirmed)
  ///   AND the server version differs from what the local record expects
  ///
  /// Note: Uses entityId as the IMEI lookup key for IMEI_UNIT entities,
  /// since the server change feed uses the normalized IMEI as entityId.
  Future<bool> _checkVersionConflict(
    TenantContext context,
    ChangeEvent change,
  ) async {
    // Check entity-type-specific local state for pending mutations
    switch (change.entityType) {
      case 'IMEI_UNIT':
        // The server change feed uses normalized IMEI as the entityId
        final local = await _repository.getImeiUnit(context, change.entityId);
        if (local == null) return false;
        // Conflict when local is pending and server version diverges
        return local.isPending &&
            local.serverVersion > 0 &&
            change.entityVersion != local.serverVersion + 1;
      default:
        // For other entity types, no conflict detection yet — apply directly
        return false;
    }
  }

  /// Create a durable conflict for a version collision during pull.
  ///
  /// Retains local version, server version, reason, and resolution state
  /// without discarding either version (Req 7.8).
  Future<void> _createVersionConflict(
    TenantContext context,
    ChangeEvent change,
  ) async {
    // Get the local version for this entity
    int localVersion = 0;
    if (change.entityType == 'IMEI_UNIT') {
      final local = await _repository.getImeiUnit(context, change.entityId);
      if (local != null) {
        localVersion = local.serverVersion;
      }
    }

    final now = DateTime.now();
    final conflict = MobileConflictEntity(
      id: 'pull_conflict_${change.eventId}_${now.millisecondsSinceEpoch}',
      tenantId: context.tenantId,
      operationId: change.eventId,
      entityType: change.entityType,
      entityId: change.entityId,
      localVersion: localVersion,
      serverVersion: change.entityVersion,
      reason: 'VERSION_COLLISION',
      resolutionStatus: ConflictResolutionStatus.unresolved,
      resolutionEvidence: null,
      dataModelVersion: change.dataModelVersion,
      createdAt: now,
      resolvedAt: null,
      updatedAt: now,
    );

    await _repository.insertConflict(context, conflict);
  }
}
