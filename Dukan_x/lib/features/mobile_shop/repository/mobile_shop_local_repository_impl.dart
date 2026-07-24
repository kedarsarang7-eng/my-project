// ============================================================================
// MOBILE SHOP — LOCAL REPOSITORY IMPLEMENTATION
// ============================================================================
// Drift-backed implementation of [MobileShopLocalRepository].
// Every query includes tenant predicate. Page apply + checkpoint advancement
// happen in one Drift transaction for atomicity.
//
// Requirements: 7.1, 7.4, 7.8, 7.12, 7.14–7.15, 8.9
// ============================================================================

import 'package:drift/drift.dart';

import '../auth/tenant_context.dart';
import '../database/mobile_shop_database.dart';
import '../database/mobile_shop_tables.dart';
import 'mobile_shop_local_repository.dart';

/// Drift-backed implementation of [MobileShopLocalRepository].
///
/// Key invariants:
/// - Every query uses `..where((t) => t.tenantId.equals(ctx.tenantId))`
/// - Upserts verify tenant ownership through unique key constraints
/// - [applyPulledPage] wraps item application + checkpoint advance in one
///   Drift [transaction] for atomicity
/// - Records are separated by confirmationStatus (pending, serverConfirmed,
///   conflict)
class MobileShopLocalRepositoryImpl implements MobileShopLocalRepository {
  final MobileShopDatabase _db;

  MobileShopLocalRepositoryImpl(this._db);

  // ── IMEI Units ───────────────────────────────────────────────────────────

  @override
  Future<LocalRecord<MobileImeiUnitEntity>?> getImeiUnit(
    TenantContext ctx,
    String imei,
  ) async {
    final query = _db.select(_db.mobileImeiUnits)
      ..where((t) => t.tenantId.equals(ctx.tenantId) & t.imei.equals(imei));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _wrapImeiUnit(row);
  }

  @override
  Future<List<LocalRecord<MobileImeiUnitEntity>>> listImeiUnits(
    TenantContext ctx, {
    String? confirmationStatus,
    int? limit,
  }) async {
    final query = _db.select(_db.mobileImeiUnits)
      ..where((t) {
        var predicate = t.tenantId.equals(ctx.tenantId);
        if (confirmationStatus != null) {
          predicate =
              predicate & t.confirmationStatus.equals(confirmationStatus);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    final rows = await query.get();
    return rows.map(_wrapImeiUnit).toList();
  }

  @override
  Future<void> upsertImeiUnit(
    TenantContext ctx,
    MobileImeiUnitEntity entity,
  ) async {
    assert(
      entity.tenantId == ctx.tenantId,
      'Entity tenantId must match TenantContext',
    );
    await _db
        .into(_db.mobileImeiUnits)
        .insertOnConflictUpdate(
          MobileImeiUnitsCompanion.insert(
            id: entity.id,
            tenantId: entity.tenantId,
            entityId: entity.entityId,
            imei: entity.imei,
            version: Value(entity.version),
            serverVersion: Value(entity.serverVersion),
            lifecycleState: Value(entity.lifecycleState),
            condition: Value(entity.condition),
            brand: Value(entity.brand),
            model: Value(entity.model),
            salePricePaise: Value(entity.salePricePaise),
            acquisitionCostPaise: Value(entity.acquisitionCostPaise),
            warrantyStartDate: Value(entity.warrantyStartDate),
            warrantyEndDate: Value(entity.warrantyEndDate),
            confirmationStatus: Value(entity.confirmationStatus),
            syncedAt: Value(entity.syncedAt),
            dataModelVersion: Value(entity.dataModelVersion),
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
          ),
        );
  }

  // ── Invoice Associations ─────────────────────────────────────────────────

  @override
  Future<List<LocalRecord<MobileInvoiceAssociationEntity>>>
  getInvoiceAssociations(TenantContext ctx, String invoiceId) async {
    final query = _db.select(_db.mobileInvoiceAssociations)
      ..where(
        (t) => t.tenantId.equals(ctx.tenantId) & t.invoiceId.equals(invoiceId),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.lineNumber)]);

    final rows = await query.get();
    return rows.map(_wrapAssociation).toList();
  }

  @override
  Future<void> upsertAssociation(
    TenantContext ctx,
    MobileInvoiceAssociationEntity entity,
  ) async {
    assert(
      entity.tenantId == ctx.tenantId,
      'Entity tenantId must match TenantContext',
    );
    await _db
        .into(_db.mobileInvoiceAssociations)
        .insertOnConflictUpdate(
          MobileInvoiceAssociationsCompanion.insert(
            id: entity.id,
            tenantId: entity.tenantId,
            invoiceId: entity.invoiceId,
            entityId: entity.entityId,
            imei: entity.imei,
            lineNumber: Value(entity.lineNumber),
            linePricePaise: Value(entity.linePricePaise),
            serverVersion: Value(entity.serverVersion),
            confirmationStatus: Value(entity.confirmationStatus),
            dataModelVersion: Value(entity.dataModelVersion),
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
          ),
        );
  }

  // ── Service Jobs ─────────────────────────────────────────────────────────

  @override
  Future<List<LocalRecord<MobileServiceJobEntity>>> listServiceJobs(
    TenantContext ctx, {
    String? status,
    int? limit,
  }) async {
    final query = _db.select(_db.mobileServiceJobs)
      ..where((t) {
        var predicate = t.tenantId.equals(ctx.tenantId);
        if (status != null) {
          predicate = predicate & t.status.equals(status);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    final rows = await query.get();
    return rows.map(_wrapServiceJob).toList();
  }

  @override
  Future<void> upsertServiceJob(
    TenantContext ctx,
    MobileServiceJobEntity entity,
  ) async {
    assert(
      entity.tenantId == ctx.tenantId,
      'Entity tenantId must match TenantContext',
    );
    await _db
        .into(_db.mobileServiceJobs)
        .insertOnConflictUpdate(
          MobileServiceJobsCompanion.insert(
            id: entity.id,
            tenantId: entity.tenantId,
            entityId: entity.entityId,
            imei: Value(entity.imei),
            customerId: Value(entity.customerId),
            customerName: Value(entity.customerName),
            status: Value(entity.status),
            technicianId: Value(entity.technicianId),
            problemDescription: Value(entity.problemDescription),
            diagnosis: Value(entity.diagnosis),
            estimatedCostPaise: Value(entity.estimatedCostPaise),
            actualCostPaise: Value(entity.actualCostPaise),
            dueAt: Value(entity.dueAt),
            version: Value(entity.version),
            serverVersion: Value(entity.serverVersion),
            confirmationStatus: Value(entity.confirmationStatus),
            dataModelVersion: Value(entity.dataModelVersion),
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
          ),
        );
  }

  // ── Exchanges ────────────────────────────────────────────────────────────

  @override
  Future<List<LocalRecord<MobileExchangeEntity>>> listExchanges(
    TenantContext ctx, {
    String? status,
    int? limit,
  }) async {
    final query = _db.select(_db.mobileExchanges)
      ..where((t) {
        var predicate = t.tenantId.equals(ctx.tenantId);
        if (status != null) {
          predicate = predicate & t.status.equals(status);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    final rows = await query.get();
    return rows.map(_wrapExchange).toList();
  }

  @override
  Future<void> upsertExchange(
    TenantContext ctx,
    MobileExchangeEntity entity,
  ) async {
    assert(
      entity.tenantId == ctx.tenantId,
      'Entity tenantId must match TenantContext',
    );
    await _db
        .into(_db.mobileExchanges)
        .insertOnConflictUpdate(
          MobileExchangesCompanion.insert(
            id: entity.id,
            tenantId: entity.tenantId,
            entityId: entity.entityId,
            oldDeviceImei: Value(entity.oldDeviceImei),
            newDeviceImei: Value(entity.newDeviceImei),
            customerId: Value(entity.customerId),
            oldDeviceValuationPaise: Value(entity.oldDeviceValuationPaise),
            adjustmentPaise: Value(entity.adjustmentPaise),
            status: Value(entity.status),
            version: Value(entity.version),
            serverVersion: Value(entity.serverVersion),
            confirmationStatus: Value(entity.confirmationStatus),
            dataModelVersion: Value(entity.dataModelVersion),
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
          ),
        );
  }

  // ── Warranties ───────────────────────────────────────────────────────────

  @override
  Future<List<LocalRecord<MobileWarrantyEntity>>> listWarranties(
    TenantContext ctx, {
    String? status,
    int? limit,
  }) async {
    final query = _db.select(_db.mobileWarranties)
      ..where((t) {
        var predicate = t.tenantId.equals(ctx.tenantId);
        if (status != null) {
          predicate = predicate & t.status.equals(status);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    final rows = await query.get();
    return rows.map(_wrapWarranty).toList();
  }

  @override
  Future<void> upsertWarranty(
    TenantContext ctx,
    MobileWarrantyEntity entity,
  ) async {
    assert(
      entity.tenantId == ctx.tenantId,
      'Entity tenantId must match TenantContext',
    );
    await _db
        .into(_db.mobileWarranties)
        .insertOnConflictUpdate(
          MobileWarrantiesCompanion.insert(
            id: entity.id,
            tenantId: entity.tenantId,
            entityId: entity.entityId,
            imei: entity.imei,
            provider: Value(entity.provider),
            warrantyMonths: Value(entity.warrantyMonths),
            startDate: Value(entity.startDate),
            endDate: Value(entity.endDate),
            status: Value(entity.status),
            claimStatus: Value(entity.claimStatus),
            evidenceRef: Value(entity.evidenceRef),
            version: Value(entity.version),
            serverVersion: Value(entity.serverVersion),
            confirmationStatus: Value(entity.confirmationStatus),
            dataModelVersion: Value(entity.dataModelVersion),
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
          ),
        );
  }

  // ── Outbox (Mutation Queue) ──────────────────────────────────────────────

  @override
  Future<void> queueMutation(
    TenantContext ctx,
    MobileOutboxMutationEntity mutation,
  ) async {
    assert(
      mutation.tenantId == ctx.tenantId,
      'Mutation tenantId must match TenantContext',
    );
    await _db
        .into(_db.mobileOutboxMutations)
        .insert(
          MobileOutboxMutationsCompanion.insert(
            id: mutation.id,
            tenantId: mutation.tenantId,
            operationId: mutation.operationId,
            mutationFingerprint: mutation.mutationFingerprint,
            entityType: mutation.entityType,
            payload: mutation.payload,
            baseVersions: Value(mutation.baseVersions),
            dependencies: Value(mutation.dependencies),
            retryCount: Value(mutation.retryCount),
            maxRetries: Value(mutation.maxRetries),
            status: Value(OutboxStatus.queued),
            dataModelVersion: Value(mutation.dataModelVersion),
            createdAt: mutation.createdAt,
            lastAttemptAt: Value(mutation.lastAttemptAt),
            updatedAt: mutation.updatedAt,
          ),
        );
  }

  @override
  Future<List<MobileOutboxMutationEntity>> getNextMutations(
    TenantContext ctx,
    int limit,
  ) async {
    final query = _db.select(_db.mobileOutboxMutations)
      ..where(
        (t) =>
            t.tenantId.equals(ctx.tenantId) &
            t.status.equals(OutboxStatus.queued),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
      ..limit(limit);

    return query.get();
  }

  @override
  Future<void> markMutationSent(TenantContext ctx, String operationId) async {
    final update = _db.update(_db.mobileOutboxMutations)
      ..where(
        (t) =>
            t.tenantId.equals(ctx.tenantId) & t.operationId.equals(operationId),
      );
    await update.write(
      MobileOutboxMutationsCompanion(
        status: const Value(OutboxStatus.sent),
        lastAttemptAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> markMutationFailed(
    TenantContext ctx,
    String operationId,
    String error,
  ) async {
    // Read the current row to increment retry count.
    final current =
        await (_db.select(_db.mobileOutboxMutations)..where(
              (t) =>
                  t.tenantId.equals(ctx.tenantId) &
                  t.operationId.equals(operationId),
            ))
            .getSingleOrNull();

    if (current == null) return;

    final newRetryCount = current.retryCount + 1;
    final isFailed = newRetryCount >= current.maxRetries;

    final update = _db.update(_db.mobileOutboxMutations)
      ..where(
        (t) =>
            t.tenantId.equals(ctx.tenantId) & t.operationId.equals(operationId),
      );
    await update.write(
      MobileOutboxMutationsCompanion(
        retryCount: Value(newRetryCount),
        status: Value(isFailed ? OutboxStatus.failed : OutboxStatus.queued),
        lastAttemptAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── Conflicts ────────────────────────────────────────────────────────────

  @override
  Future<void> insertConflict(
    TenantContext ctx,
    MobileConflictEntity conflict,
  ) async {
    assert(
      conflict.tenantId == ctx.tenantId,
      'Conflict tenantId must match TenantContext',
    );
    await _db
        .into(_db.mobileConflicts)
        .insert(
          MobileConflictsCompanion.insert(
            id: conflict.id,
            tenantId: conflict.tenantId,
            operationId: conflict.operationId,
            entityType: conflict.entityType,
            entityId: conflict.entityId,
            localVersion: conflict.localVersion,
            serverVersion: conflict.serverVersion,
            reason: conflict.reason,
            resolutionStatus: Value(ConflictResolutionStatus.unresolved),
            resolutionEvidence: Value(conflict.resolutionEvidence),
            dataModelVersion: Value(conflict.dataModelVersion),
            createdAt: conflict.createdAt,
            resolvedAt: Value(conflict.resolvedAt),
            updatedAt: conflict.updatedAt,
          ),
        );
  }

  @override
  Future<List<MobileConflictEntity>> listConflicts(
    TenantContext ctx, {
    String? resolutionStatus,
  }) async {
    final query = _db.select(_db.mobileConflicts)
      ..where((t) {
        var predicate = t.tenantId.equals(ctx.tenantId);
        if (resolutionStatus != null) {
          predicate = predicate & t.resolutionStatus.equals(resolutionStatus);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.get();
  }

  @override
  Future<void> resolveConflict(
    TenantContext ctx,
    String id,
    String resolution, {
    String? resolutionEvidence,
  }) async {
    final update = _db.update(_db.mobileConflicts)
      ..where((t) => t.tenantId.equals(ctx.tenantId) & t.id.equals(id));
    await update.write(
      MobileConflictsCompanion(
        resolutionStatus: Value(resolution),
        resolutionEvidence: Value(resolutionEvidence),
        resolvedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── Event Inbox ──────────────────────────────────────────────────────────

  @override
  Future<bool> insertEventIfNotExists(
    TenantContext ctx,
    MobileEventInboxEntity event,
  ) async {
    assert(
      event.tenantId == ctx.tenantId,
      'Event tenantId must match TenantContext',
    );

    // Check for existing event with same (tenantId, eventId) — deduplication.
    final existing =
        await (_db.select(_db.mobileEventInbox)..where(
              (t) =>
                  t.tenantId.equals(ctx.tenantId) &
                  t.eventId.equals(event.eventId),
            ))
            .getSingleOrNull();

    if (existing != null) return false;

    await _db
        .into(_db.mobileEventInbox)
        .insert(
          MobileEventInboxCompanion.insert(
            id: event.id,
            tenantId: event.tenantId,
            eventId: event.eventId,
            entityType: event.entityType,
            entityId: event.entityId,
            version: event.version,
            action: event.action,
            dataModelVersion: Value(event.dataModelVersion),
            receivedAt: event.receivedAt,
            processedAt: Value(event.processedAt),
            updatedAt: event.updatedAt,
          ),
        );
    return true;
  }

  @override
  Future<List<MobileEventInboxEntity>> getUnprocessedEvents(
    TenantContext ctx,
    int limit,
  ) async {
    final query = _db.select(_db.mobileEventInbox)
      ..where((t) => t.tenantId.equals(ctx.tenantId) & t.processedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.receivedAt)])
      ..limit(limit);

    return query.get();
  }

  // ── Checkpoints ──────────────────────────────────────────────────────────

  @override
  Future<CheckpointState?> getCheckpoint(
    TenantContext ctx,
    String bucket,
  ) async {
    final query = _db.select(_db.mobileContinuationCheckpoints)
      ..where((t) => t.tenantId.equals(ctx.tenantId) & t.bucket.equals(bucket));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return CheckpointState(
      bucket: row.bucket,
      lastPosition: row.lastPosition,
      lastPulledAt: row.lastPulledAt,
      serverVersion: row.serverVersion,
    );
  }

  @override
  Future<void> advanceCheckpoint(
    TenantContext ctx,
    String bucket,
    String? position,
    int serverVersion,
  ) async {
    final now = DateTime.now();
    await _db
        .into(_db.mobileContinuationCheckpoints)
        .insertOnConflictUpdate(
          MobileContinuationCheckpointsCompanion.insert(
            id: '${ctx.tenantId}_$bucket',
            tenantId: ctx.tenantId,
            bucket: bucket,
            lastPosition: Value(position),
            lastPulledAt: Value(now),
            serverVersion: Value(serverVersion),
            dataModelVersion: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  // ── Atomic Page Apply ────────────────────────────────────────────────────

  @override
  Future<void> applyPulledPage(
    TenantContext ctx, {
    required String bucket,
    required List<PulledItem> items,
    required String? newCheckpoint,
    required int serverVersion,
  }) async {
    await _db.transaction(() async {
      // Apply each pulled item to the appropriate table.
      for (final item in items) {
        await _applyPulledItem(ctx, item);
      }

      // Advance the checkpoint within the same transaction.
      await advanceCheckpoint(ctx, bucket, newCheckpoint, serverVersion);
    });
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  /// Applies a single pulled item to the correct local table based on
  /// entity type. Deletions remove the row; creates/updates upsert it.
  Future<void> _applyPulledItem(TenantContext ctx, PulledItem item) async {
    final now = DateTime.now();

    if (item.deleted) {
      await _deletePulledItem(ctx, item);
      return;
    }

    // For non-delete items, we mark them as serverConfirmed since they
    // come from a confirmed pull response.
    switch (item.entityType) {
      case 'IMEI_UNIT':
        await _db
            .into(_db.mobileImeiUnits)
            .insertOnConflictUpdate(
              MobileImeiUnitsCompanion.insert(
                id: '${ctx.tenantId}_${item.entityId}',
                tenantId: ctx.tenantId,
                entityId: item.entityId,
                imei: item.entityId, // Will be overwritten by snapshot parsing
                serverVersion: Value(item.entityVersion),
                confirmationStatus: const Value(
                  ConfirmationStatus.serverConfirmed,
                ),
                syncedAt: Value(now),
                createdAt: now,
                updatedAt: now,
              ),
            );
      case 'INVOICE_ASSOCIATION':
        await _db
            .into(_db.mobileInvoiceAssociations)
            .insertOnConflictUpdate(
              MobileInvoiceAssociationsCompanion.insert(
                id: '${ctx.tenantId}_${item.entityId}',
                tenantId: ctx.tenantId,
                invoiceId: '', // Populated from snapshot
                entityId: item.entityId,
                imei: '', // Populated from snapshot
                serverVersion: Value(item.entityVersion),
                confirmationStatus: const Value(
                  ConfirmationStatus.serverConfirmed,
                ),
                createdAt: now,
                updatedAt: now,
              ),
            );
      case 'SERVICE_JOB':
        await _db
            .into(_db.mobileServiceJobs)
            .insertOnConflictUpdate(
              MobileServiceJobsCompanion.insert(
                id: '${ctx.tenantId}_${item.entityId}',
                tenantId: ctx.tenantId,
                entityId: item.entityId,
                serverVersion: Value(item.entityVersion),
                confirmationStatus: const Value(
                  ConfirmationStatus.serverConfirmed,
                ),
                createdAt: now,
                updatedAt: now,
              ),
            );
      case 'EXCHANGE':
        await _db
            .into(_db.mobileExchanges)
            .insertOnConflictUpdate(
              MobileExchangesCompanion.insert(
                id: '${ctx.tenantId}_${item.entityId}',
                tenantId: ctx.tenantId,
                entityId: item.entityId,
                serverVersion: Value(item.entityVersion),
                confirmationStatus: const Value(
                  ConfirmationStatus.serverConfirmed,
                ),
                createdAt: now,
                updatedAt: now,
              ),
            );
      case 'WARRANTY':
        await _db
            .into(_db.mobileWarranties)
            .insertOnConflictUpdate(
              MobileWarrantiesCompanion.insert(
                id: '${ctx.tenantId}_${item.entityId}',
                tenantId: ctx.tenantId,
                entityId: item.entityId,
                imei: '', // Populated from snapshot
                serverVersion: Value(item.entityVersion),
                confirmationStatus: const Value(
                  ConfirmationStatus.serverConfirmed,
                ),
                createdAt: now,
                updatedAt: now,
              ),
            );
    }
  }

  /// Removes a pulled item marked as deleted from the local store.
  Future<void> _deletePulledItem(TenantContext ctx, PulledItem item) async {
    switch (item.entityType) {
      case 'IMEI_UNIT':
        await (_db.delete(_db.mobileImeiUnits)..where(
              (t) =>
                  t.tenantId.equals(ctx.tenantId) &
                  t.entityId.equals(item.entityId),
            ))
            .go();
      case 'INVOICE_ASSOCIATION':
        await (_db.delete(_db.mobileInvoiceAssociations)..where(
              (t) =>
                  t.tenantId.equals(ctx.tenantId) &
                  t.entityId.equals(item.entityId),
            ))
            .go();
      case 'SERVICE_JOB':
        await (_db.delete(_db.mobileServiceJobs)..where(
              (t) =>
                  t.tenantId.equals(ctx.tenantId) &
                  t.entityId.equals(item.entityId),
            ))
            .go();
      case 'EXCHANGE':
        await (_db.delete(_db.mobileExchanges)..where(
              (t) =>
                  t.tenantId.equals(ctx.tenantId) &
                  t.entityId.equals(item.entityId),
            ))
            .go();
      case 'WARRANTY':
        await (_db.delete(_db.mobileWarranties)..where(
              (t) =>
                  t.tenantId.equals(ctx.tenantId) &
                  t.entityId.equals(item.entityId),
            ))
            .go();
    }
  }

  // ── Record Wrappers ──────────────────────────────────────────────────────

  LocalRecord<MobileImeiUnitEntity> _wrapImeiUnit(MobileImeiUnitEntity row) =>
      LocalRecord(
        entity: row,
        confirmationStatus: row.confirmationStatus,
        serverVersion: row.serverVersion,
        syncedAt: row.syncedAt,
      );

  LocalRecord<MobileInvoiceAssociationEntity> _wrapAssociation(
    MobileInvoiceAssociationEntity row,
  ) => LocalRecord(
    entity: row,
    confirmationStatus: row.confirmationStatus,
    serverVersion: row.serverVersion,
  );

  LocalRecord<MobileServiceJobEntity> _wrapServiceJob(
    MobileServiceJobEntity row,
  ) => LocalRecord(
    entity: row,
    confirmationStatus: row.confirmationStatus,
    serverVersion: row.serverVersion,
  );

  LocalRecord<MobileExchangeEntity> _wrapExchange(MobileExchangeEntity row) =>
      LocalRecord(
        entity: row,
        confirmationStatus: row.confirmationStatus,
        serverVersion: row.serverVersion,
      );

  LocalRecord<MobileWarrantyEntity> _wrapWarranty(MobileWarrantyEntity row) =>
      LocalRecord(
        entity: row,
        confirmationStatus: row.confirmationStatus,
        serverVersion: row.serverVersion,
      );
}
