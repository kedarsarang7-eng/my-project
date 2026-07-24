// ============================================================================
// MOBILE SHOP — LOCAL REPOSITORY INTERFACE
// ============================================================================
// Defines all tenant-bound local data operations for the MobileShop feature.
// Every method requires TenantContext as its first parameter to enforce
// tenant isolation at the repository boundary.
//
// Drift is a local cache/draft/queue — never authoritative.
//
// Requirements: 7.1, 7.4, 7.8, 7.12, 7.14–7.15, 8.9
// ============================================================================

import '../auth/tenant_context.dart';
import '../database/mobile_shop_database.dart';

// ─── Confirmation Status Constants ───────────────────────────────────────────

/// Local confirmation status values for domain projections.
abstract class ConfirmationStatus {
  static const String pending = 'pending';
  static const String serverConfirmed = 'serverConfirmed';
  static const String conflict = 'conflict';
}

/// Outbox mutation status values.
abstract class OutboxStatus {
  static const String queued = 'queued';
  static const String sending = 'sending';
  static const String sent = 'sent';
  static const String failed = 'failed';
}

/// Conflict resolution status values.
abstract class ConflictResolutionStatus {
  static const String unresolved = 'unresolved';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String merged = 'merged';
}

// ─── Result Wrappers ─────────────────────────────────────────────────────────

/// Wraps a domain entity with its local sync state for presentation.
class LocalRecord<T> {
  final T entity;
  final String confirmationStatus;
  final int serverVersion;
  final DateTime? syncedAt;

  const LocalRecord({
    required this.entity,
    required this.confirmationStatus,
    required this.serverVersion,
    this.syncedAt,
  });

  /// Whether the record is confirmed by the server.
  bool get isServerConfirmed =>
      confirmationStatus == ConfirmationStatus.serverConfirmed;

  /// Whether the record has a pending local change not yet synced.
  bool get isPending => confirmationStatus == ConfirmationStatus.pending;

  /// Whether the record is in a conflicted state.
  bool get isConflict => confirmationStatus == ConfirmationStatus.conflict;

  /// Whether the local cache may be stale (no sync timestamp or old).
  bool get isStale => syncedAt == null;
}

/// Checkpoint state for a sync bucket.
class CheckpointState {
  final String bucket;
  final String? lastPosition;
  final DateTime? lastPulledAt;
  final int serverVersion;

  const CheckpointState({
    required this.bucket,
    this.lastPosition,
    this.lastPulledAt,
    required this.serverVersion,
  });
}

// ─── Abstract Interface ──────────────────────────────────────────────────────

/// Abstract local repository for all tenant-bound MobileShop data operations.
///
/// Every method requires [TenantContext] to guarantee tenant isolation.
/// The implementation includes tenant predicates on every query and uses
/// tenant ID in all unique keys.
abstract class MobileShopLocalRepository {
  // ── IMEI Units ───────────────────────────────────────────────────────────

  /// Retrieves a single IMEI unit by normalized IMEI within the tenant scope.
  Future<LocalRecord<MobileImeiUnitEntity>?> getImeiUnit(
    TenantContext ctx,
    String imei,
  );

  /// Lists IMEI units filtered by optional confirmation status and limit.
  Future<List<LocalRecord<MobileImeiUnitEntity>>> listImeiUnits(
    TenantContext ctx, {
    String? confirmationStatus,
    int? limit,
  });

  /// Inserts or updates an IMEI unit within the tenant scope.
  Future<void> upsertImeiUnit(TenantContext ctx, MobileImeiUnitEntity entity);

  // ── Invoice Associations ─────────────────────────────────────────────────

  /// Retrieves all device-line associations for an invoice.
  Future<List<LocalRecord<MobileInvoiceAssociationEntity>>>
  getInvoiceAssociations(TenantContext ctx, String invoiceId);

  /// Inserts or updates an invoice-device association.
  Future<void> upsertAssociation(
    TenantContext ctx,
    MobileInvoiceAssociationEntity entity,
  );

  // ── Service Jobs ─────────────────────────────────────────────────────────

  /// Lists service jobs filtered by optional status and limit.
  Future<List<LocalRecord<MobileServiceJobEntity>>> listServiceJobs(
    TenantContext ctx, {
    String? status,
    int? limit,
  });

  /// Inserts or updates a service job.
  Future<void> upsertServiceJob(
    TenantContext ctx,
    MobileServiceJobEntity entity,
  );

  // ── Exchanges ────────────────────────────────────────────────────────────

  /// Lists exchanges filtered by optional status and limit.
  Future<List<LocalRecord<MobileExchangeEntity>>> listExchanges(
    TenantContext ctx, {
    String? status,
    int? limit,
  });

  /// Inserts or updates an exchange record.
  Future<void> upsertExchange(TenantContext ctx, MobileExchangeEntity entity);

  // ── Warranties ───────────────────────────────────────────────────────────

  /// Lists warranties filtered by optional status and limit.
  Future<List<LocalRecord<MobileWarrantyEntity>>> listWarranties(
    TenantContext ctx, {
    String? status,
    int? limit,
  });

  /// Inserts or updates a warranty record.
  Future<void> upsertWarranty(TenantContext ctx, MobileWarrantyEntity entity);

  // ── Outbox (Mutation Queue) ──────────────────────────────────────────────

  /// Queues a new mutation for later push by the Sync_Engine.
  Future<void> queueMutation(
    TenantContext ctx,
    MobileOutboxMutationEntity mutation,
  );

  /// Retrieves the next batch of mutations ready for push (status: queued).
  Future<List<MobileOutboxMutationEntity>> getNextMutations(
    TenantContext ctx,
    int limit,
  );

  /// Marks a mutation as successfully sent.
  Future<void> markMutationSent(TenantContext ctx, String operationId);

  /// Marks a mutation as failed with an error message.
  Future<void> markMutationFailed(
    TenantContext ctx,
    String operationId,
    String error,
  );

  // ── Conflicts ────────────────────────────────────────────────────────────

  /// Inserts a new conflict record.
  Future<void> insertConflict(TenantContext ctx, MobileConflictEntity conflict);

  /// Lists conflict records filtered by optional resolution status.
  Future<List<MobileConflictEntity>> listConflicts(
    TenantContext ctx, {
    String? resolutionStatus,
  });

  /// Resolves a conflict with the given resolution status and evidence.
  Future<void> resolveConflict(
    TenantContext ctx,
    String id,
    String resolution, {
    String? resolutionEvidence,
  });

  // ── Event Inbox ──────────────────────────────────────────────────────────

  /// Inserts an event if its (tenantId, eventId) pair does not already exist.
  /// Returns true if inserted, false if duplicate.
  Future<bool> insertEventIfNotExists(
    TenantContext ctx,
    MobileEventInboxEntity event,
  );

  /// Retrieves unprocessed events (processedAt == null) up to a limit.
  Future<List<MobileEventInboxEntity>> getUnprocessedEvents(
    TenantContext ctx,
    int limit,
  );

  // ── Checkpoints ──────────────────────────────────────────────────────────

  /// Gets the current checkpoint state for a sync bucket.
  Future<CheckpointState?> getCheckpoint(TenantContext ctx, String bucket);

  /// Advances the checkpoint position and server version for a bucket.
  Future<void> advanceCheckpoint(
    TenantContext ctx,
    String bucket,
    String? position,
    int serverVersion,
  );

  // ── Atomic Page Apply ────────────────────────────────────────────────────

  /// Atomically applies server-pulled items and advances the checkpoint
  /// in a single Drift transaction.
  ///
  /// [bucket] identifies the sync partition being updated.
  /// [items] are the change events to apply locally.
  /// [newCheckpoint] is the new continuation position after this page.
  /// [serverVersion] is the server version associated with this page.
  Future<void> applyPulledPage(
    TenantContext ctx, {
    required String bucket,
    required List<PulledItem> items,
    required String? newCheckpoint,
    required int serverVersion,
  });
}

/// Represents one item from a pulled page to be applied locally.
class PulledItem {
  /// The entity type (e.g., 'IMEI_UNIT', 'SERVICE_JOB').
  final String entityType;

  /// The entity ID.
  final String entityId;

  /// The new entity version from the server.
  final int entityVersion;

  /// The action (CREATED, UPDATED, DELETED).
  final String action;

  /// The serialized entity snapshot (JSON).
  final String? snapshot;

  /// Whether this item represents a deletion.
  final bool deleted;

  const PulledItem({
    required this.entityType,
    required this.entityId,
    required this.entityVersion,
    required this.action,
    this.snapshot,
    this.deleted = false,
  });
}
