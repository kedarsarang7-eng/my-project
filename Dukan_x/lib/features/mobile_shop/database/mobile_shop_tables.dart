// ============================================================================
// MOBILE SHOP — DRIFT TABLE DEFINITIONS
// ============================================================================
// Tenant-scoped, version-aware, confirmation-aware tables for:
//   • Domain projections (local cache of server data)
//   • Synchronization state (outbox, conflicts, event inbox, checkpoints)
//   • Reconciliation and provider tracking
//
// Design Principles:
//   • Every table includes tenantId as a required non-nullable column
//   • Money fields use IntColumn (integer minor units — paise for INR)
//   • Drift is a local cache/draft/queue — never authoritative
//   • Unique constraints always include tenantId
//   • Confirmation status: pending | serverConfirmed | conflict
//
// Requirements: 6.24, 7.1–7.2, 7.6–7.9, 7.13–7.15; GR-2
// ============================================================================

import 'package:drift/drift.dart';

// ============================================================================
// DOMAIN PROJECTIONS (local cache of server data)
// ============================================================================

/// Local cache of IMEI units synced from the canonical backend.
///
/// Each row is a projection of the authoritative DynamoDB IMEI unit. The
/// confirmation status distinguishes pending local drafts from server-confirmed
/// records and detected conflicts.
@DataClassName('MobileImeiUnitEntity')
class MobileImeiUnits extends Table {
  /// Local row identifier.
  TextColumn get id => text()();

  /// Owning tenant — part of all unique constraints.
  TextColumn get tenantId => text()();

  /// Server-assigned entity identifier.
  TextColumn get entityId => text()();

  /// Normalized 15-digit IMEI.
  TextColumn get imei => text()();

  /// Local optimistic version (incremented on local writes).
  IntColumn get version => integer().withDefault(const Constant(1))();

  /// Last known server version from the canonical backend.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  /// Device lifecycle state (IN_STOCK, RESERVED, SALE_PENDING, SOLD,
  /// RETURNED, DEMO, IN_SERVICE, EXCHANGED, DAMAGED, RETIRED).
  TextColumn get lifecycleState =>
      text().withDefault(const Constant('IN_STOCK'))();

  /// Device condition (new, excellent, good, fair, poor).
  TextColumn get condition => text().nullable()();

  /// Device brand.
  TextColumn get brand => text().nullable()();

  /// Device model.
  TextColumn get model => text().nullable()();

  /// Sale price in integer minor units (paise).
  IntColumn get salePricePaise => integer().nullable()();

  /// Acquisition cost in integer minor units (paise).
  IntColumn get acquisitionCostPaise => integer().nullable()();

  /// Warranty start date.
  DateTimeColumn get warrantyStartDate => dateTime().nullable()();

  /// Warranty end date.
  DateTimeColumn get warrantyEndDate => dateTime().nullable()();

  /// Confirmation status: pending | serverConfirmed | conflict.
  TextColumn get confirmationStatus =>
      text().withDefault(const Constant('pending'))();

  /// Last time this row was synced from the server.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Data model version for migration compatibility.
  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, imei},
    {tenantId, entityId},
  ];
}

/// Invoice-to-device line mappings (local projection).
@DataClassName('MobileInvoiceAssociationEntity')
class MobileInvoiceAssociations extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get invoiceId => text()();
  TextColumn get entityId => text()();

  /// The IMEI associated with this invoice line.
  TextColumn get imei => text()();

  /// Line number within the invoice.
  IntColumn get lineNumber => integer().withDefault(const Constant(1))();

  /// Sale price for this line in integer minor units (paise).
  IntColumn get linePricePaise => integer().nullable()();

  /// Server version of this association.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  TextColumn get confirmationStatus =>
      text().withDefault(const Constant('pending'))();

  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, invoiceId, imei},
  ];
}

/// Service job projections (local cache).
@DataClassName('MobileServiceJobEntity')
class MobileServiceJobs extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get entityId => text()();

  /// Associated IMEI (may be null for non-IMEI service work).
  TextColumn get imei => text().nullable()();

  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().nullable()();

  /// Service job status (RECEIVED, DIAGNOSED, WAITING_APPROVAL, APPROVED,
  /// WAITING_PARTS, IN_PROGRESS, COMPLETED, READY, DELIVERED, CANCELLED).
  TextColumn get status => text().withDefault(const Constant('RECEIVED'))();

  TextColumn get technicianId => text().nullable()();
  TextColumn get problemDescription => text().nullable()();
  TextColumn get diagnosis => text().nullable()();

  /// Estimated cost in paise.
  IntColumn get estimatedCostPaise => integer().nullable()();

  /// Actual cost in paise.
  IntColumn get actualCostPaise => integer().nullable()();

  DateTimeColumn get dueAt => dateTime().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();
  TextColumn get confirmationStatus =>
      text().withDefault(const Constant('pending'))();

  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, entityId},
  ];
}

/// Exchange projections (local cache).
@DataClassName('MobileExchangeEntity')
class MobileExchanges extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get entityId => text()();

  /// Old device IMEI being exchanged.
  TextColumn get oldDeviceImei => text().nullable()();

  /// New device IMEI being given.
  TextColumn get newDeviceImei => text().nullable()();

  TextColumn get customerId => text().nullable()();

  /// Old device valuation in paise.
  IntColumn get oldDeviceValuationPaise => integer().nullable()();

  /// Financial adjustment (difference) in paise.
  IntColumn get adjustmentPaise => integer().nullable()();

  /// Exchange status (PENDING, APPROVED, COMPLETED, CANCELLED).
  TextColumn get status => text().withDefault(const Constant('PENDING'))();

  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();
  TextColumn get confirmationStatus =>
      text().withDefault(const Constant('pending'))();

  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, entityId},
  ];
}

/// Warranty projections (local cache).
@DataClassName('MobileWarrantyEntity')
class MobileWarranties extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get entityId => text()();

  /// Associated IMEI.
  TextColumn get imei => text()();

  /// Warranty provider name.
  TextColumn get provider => text().nullable()();

  /// Warranty months.
  IntColumn get warrantyMonths => integer().nullable()();

  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Warranty status (ACTIVE, EXPIRED, CLAIMED, VOID).
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();

  /// Claim status if a claim has been filed.
  TextColumn get claimStatus => text().nullable()();

  /// Evidence reference (e.g., document path).
  TextColumn get evidenceRef => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();
  TextColumn get confirmationStatus =>
      text().withDefault(const Constant('pending'))();

  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, entityId},
  ];
}

/// Local view of reconciliation progress.
@DataClassName('MobileReconciliationStatusEntity')
class MobileReconciliationStatus extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();

  /// The operation that triggered reconciliation.
  TextColumn get operationId => text()();

  /// Reconciliation record ID from the server.
  TextColumn get reconciliationId => text().nullable()();

  /// Current reconciliation status (PENDING, IN_PROGRESS, COMPLETED, FAILED).
  TextColumn get status => text().withDefault(const Constant('PENDING'))();

  /// Total steps in the reconciliation plan.
  IntColumn get totalSteps => integer().withDefault(const Constant(0))();

  /// Steps completed so far.
  IntColumn get completedSteps => integer().withDefault(const Constant(0))();

  /// Latest error message if any step failed.
  TextColumn get latestError => text().nullable()();

  /// Terminal state evidence (e.g., JSON summary).
  TextColumn get terminalEvidence => text().nullable()();

  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, operationId},
  ];
}

/// Provider request tracking (local cache).
///
/// Stores Provider_Request_Id and outcome for external provider operations
/// (finance, recharge, OCR, compliance) so retries can reuse identity.
@DataClassName('MobileProviderStateEntity')
class MobileProviderState extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();

  /// The operation that initiated the provider request.
  TextColumn get operationId => text()();

  /// Stable provider request identity for retry safety.
  TextColumn get providerRequestId => text()();

  /// Provider type (FINANCE, RECHARGE, OCR, COMPLIANCE, EWAY).
  TextColumn get providerType => text()();

  /// Request payload (JSON).
  TextColumn get requestPayload => text().nullable()();

  /// Provider response status (PENDING, SUCCESS, FAILED, AMBIGUOUS).
  TextColumn get responseStatus =>
      text().withDefault(const Constant('PENDING'))();

  /// Provider response payload (JSON).
  TextColumn get responsePayload => text().nullable()();

  /// External provider reference (transaction ID, etc).
  TextColumn get externalRef => text().nullable()();

  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, operationId, providerType},
  ];
}

// ============================================================================
// SYNCHRONIZATION STATE
// ============================================================================

/// Durable local mutation queue (outbox).
///
/// Offline-approved commands are stored here before local acceptance is
/// reported. The Sync_Engine pushes these in dependency order on reconnect.
@DataClassName('MobileOutboxMutationEntity')
class MobileOutboxMutations extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();

  /// Idempotent operation identifier — reused on every retry.
  TextColumn get operationId => text()();

  /// Deterministic digest of immutable request fields.
  TextColumn get mutationFingerprint => text()();

  /// Entity type being mutated (IMEI_UNIT, INVOICE, SERVICE_JOB, etc).
  TextColumn get entityType => text()();

  /// Full mutation payload serialized as JSON.
  TextColumn get payload => text()();

  /// Expected entity versions for conditional writes (JSON map).
  TextColumn get baseVersions => text().nullable()();

  /// Operation IDs this mutation depends on (JSON array).
  TextColumn get dependencies => text().nullable()();

  /// Number of push attempts made.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Maximum retries before moving to dead-letter state.
  IntColumn get maxRetries => integer().withDefault(const Constant(10))();

  /// Outbox status: queued | sending | sent | failed.
  TextColumn get status => text().withDefault(const Constant('queued'))();

  /// Data model version for schema compatibility.
  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, operationId},
  ];
}

/// Conflict records for rejected or concurrent mutations.
///
/// Created when a push returns conflict, or when local and server versions
/// diverge. Retained until explicitly resolved by the user or policy.
@DataClassName('MobileConflictEntity')
class MobileConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();

  /// The operation that caused the conflict.
  TextColumn get operationId => text()();

  /// Entity type (IMEI_UNIT, INVOICE, SERVICE_JOB, etc).
  TextColumn get entityType => text()();

  /// Entity identifier.
  TextColumn get entityId => text()();

  /// Local version at time of conflict.
  IntColumn get localVersion => integer()();

  /// Server version that conflicted.
  IntColumn get serverVersion => integer()();

  /// Conflict reason (VERSION_MISMATCH, UNIQUENESS_VIOLATION, etc).
  TextColumn get reason => text()();

  /// Resolution status: unresolved | accepted | rejected | merged.
  TextColumn get resolutionStatus =>
      text().withDefault(const Constant('unresolved'))();

  /// Evidence of resolution (JSON — notes, actor, policy applied).
  TextColumn get resolutionEvidence => text().nullable()();

  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, operationId},
  ];
}

/// Deduplicated incoming events (from pull or WebSocket).
///
/// The Sync_Engine uses (tenantId, eventId) uniqueness to apply each event
/// at most once and prevent version regression.
@DataClassName('MobileEventInboxEntity')
class MobileEventInbox extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();

  /// Server-assigned event identifier — globally unique within tenant.
  TextColumn get eventId => text()();

  /// Entity type the event applies to.
  TextColumn get entityType => text()();

  /// Entity identifier.
  TextColumn get entityId => text()();

  /// Entity version after this event.
  IntColumn get version => integer()();

  /// Event action (CREATED, UPDATED, DELETED, LIFECYCLE_CHANGE, etc).
  TextColumn get action => text()();

  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get receivedAt => dateTime()();
  DateTimeColumn get processedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, eventId},
  ];
}

/// Sync cursor position per tenant/bucket.
///
/// Tracks the last successfully applied pull position so that the next pull
/// resumes from the correct point. Advancing the checkpoint and applying the
/// page happen in one Drift transaction.
@DataClassName('MobileContinuationCheckpointEntity')
class MobileContinuationCheckpoints extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();

  /// Logical bucket for partitioned sync (e.g., entity type or shard).
  TextColumn get bucket => text()();

  /// Opaque server-issued continuation position.
  TextColumn get lastPosition => text().nullable()();

  /// When the last successful pull completed.
  DateTimeColumn get lastPulledAt => dateTime().nullable()();

  /// Server version at last pull.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  IntColumn get dataModelVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {tenantId, bucket},
  ];
}
