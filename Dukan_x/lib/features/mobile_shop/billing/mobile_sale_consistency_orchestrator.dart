/// MobileSaleConsistencyOrchestrator — Authoritative Sale/Cancel/Return Routing
///
/// Routes all mobileShop sale, cancellation, and return operations through the
/// outbox/sync infrastructure. Ensures:
///
/// 1. Only local draft/pending state is saved before backend confirmation
///    (Drift is local cache only — never authoritative)
/// 2. One Operation_Id and Mutation_Fingerprint are generated per logical
///    mutation and reused on every retry (idempotency)
/// 3. Reconciliation status is tracked and exposed to the UI
/// 4. No unconfirmed outcome appears as committed/current/server-confirmed
///
/// Requirements: 3.3–3.11, 7.2–7.6, 12.7–12.10; GR-3
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/api_result.dart';
import '../api/mobile_shop_api.dart';
import '../auth/tenant_context.dart';
import '../config/error_codes_config.dart';
import '../config/offline_eligibility_config.dart';
import '../database/mobile_shop_database.dart';
import '../models/confirmation_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import '../sync/mobile_sync_coordinator.dart';

// ─── Sale Command ────────────────────────────────────────────────────────────

/// Command for a mobile device sale routed through the consistency orchestrator.
///
/// The [operationId] and [mutationFingerprint] are generated once per logical
/// sale and reused on every retry (Req 7.5). Callers MUST NOT regenerate these
/// on retry.
@immutable
class MobileSaleCommand {
  /// Idempotent operation identifier — generated once per logical mutation.
  final String operationId;

  /// Deterministic digest of the operation type + normalized immutable fields.
  final String mutationFingerprint;

  /// Draft invoice data (serialized JSON payload for the sale).
  final Map<String, dynamic> invoicePayload;

  /// Device lines with IMEI associations.
  final List<DeviceLineItem> deviceLines;

  /// Expected IMEI versions for conditional writes.
  final Map<String, int> expectedImeiVersions;

  /// Data model version for schema compatibility.
  final int dataModelVersion;

  const MobileSaleCommand({
    required this.operationId,
    required this.mutationFingerprint,
    required this.invoicePayload,
    required this.deviceLines,
    required this.expectedImeiVersions,
    required this.dataModelVersion,
  });
}

/// A single device line item in the sale.
@immutable
class DeviceLineItem {
  /// Normalized IMEI (15-digit, Luhn-valid).
  final String normalizedImei;

  /// Product/model identifier.
  final String productId;

  /// Sale price in integer minor units.
  final int salePriceMinor;

  /// Warranty months (if applicable).
  final int? warrantyMonths;

  const DeviceLineItem({
    required this.normalizedImei,
    required this.productId,
    required this.salePriceMinor,
    this.warrantyMonths,
  });

  Map<String, dynamic> toJson() => {
    'normalizedImei': normalizedImei,
    'productId': productId,
    'salePriceMinor': salePriceMinor,
    if (warrantyMonths != null) 'warrantyMonths': warrantyMonths,
  };
}

/// Command for a mobile invoice cancellation.
@immutable
class MobileCancellationCommand {
  /// Idempotent operation identifier.
  final String operationId;

  /// Deterministic digest.
  final String mutationFingerprint;

  /// ID of the invoice being cancelled.
  final String invoiceId;

  /// Expected invoice version for conditional cancel.
  final int expectedInvoiceVersion;

  /// IMEIs associated with the invoice (for lifecycle reversal).
  final List<String> associatedImeis;

  /// Expected IMEI versions for conditional writes.
  final Map<String, int> expectedImeiVersions;

  /// Reason for cancellation.
  final String reason;

  /// Data model version.
  final int dataModelVersion;

  const MobileCancellationCommand({
    required this.operationId,
    required this.mutationFingerprint,
    required this.invoiceId,
    required this.expectedInvoiceVersion,
    required this.associatedImeis,
    required this.expectedImeiVersions,
    required this.reason,
    required this.dataModelVersion,
  });
}

/// Command for a mobile device return.
@immutable
class MobileReturnCommand {
  /// Idempotent operation identifier.
  final String operationId;

  /// Deterministic digest.
  final String mutationFingerprint;

  /// ID of the originating sale invoice.
  final String originatingInvoiceId;

  /// The normalized IMEI being returned.
  final String normalizedImei;

  /// Expected current IMEI version.
  final int expectedImeiVersion;

  /// Return condition/disposition.
  final String condition;

  /// Reason for return.
  final String reason;

  /// Target lifecycle state (usually RETURNED).
  final String targetLifecycleState;

  /// Data model version.
  final int dataModelVersion;

  const MobileReturnCommand({
    required this.operationId,
    required this.mutationFingerprint,
    required this.originatingInvoiceId,
    required this.normalizedImei,
    required this.expectedImeiVersion,
    required this.condition,
    required this.reason,
    required this.targetLifecycleState,
    required this.dataModelVersion,
  });
}

// ─── Orchestrator Outcome ────────────────────────────────────────────────────

/// Outcome states from the orchestrator — never labels as committed without
/// authoritative confirmation (Req 12.9, GR-3).
enum SaleOutcomeState {
  /// Locally queued in outbox; awaiting sync push. NOT committed.
  localPending,

  /// Backend accepted and fully committed in DynamoDB.
  committed,

  /// Backend accepted; reconciliation in progress.
  acceptedPending,

  /// Backend rejected due to conflict (version, uniqueness, etc).
  conflict,

  /// Backend permanently rejected the operation.
  rejected,

  /// Network unavailable; queued for later delivery.
  offlineQueued,
}

/// Result of routing an operation through the consistency orchestrator.
@immutable
class ConsistencyOutcome {
  /// The state of this operation.
  final SaleOutcomeState state;

  /// The operation ID for tracking.
  final String operationId;

  /// Authoritative confirmation (only present for committed/acceptedPending).
  final AuthoritativeConfirmation? confirmation;

  /// Error details if conflict or rejected.
  final String? errorCode;
  final String? errorMessage;

  /// Whether this can be retried with the same operation ID.
  final bool retryable;

  const ConsistencyOutcome({
    required this.state,
    required this.operationId,
    this.confirmation,
    this.errorCode,
    this.errorMessage,
    this.retryable = false,
  });

  /// Whether the UI should display this as pending/unconfirmed.
  bool get isPending =>
      state == SaleOutcomeState.localPending ||
      state == SaleOutcomeState.acceptedPending ||
      state == SaleOutcomeState.offlineQueued;

  /// Whether the backend has confirmed the outcome.
  bool get isServerConfirmed =>
      state == SaleOutcomeState.committed && confirmation != null;

  /// Whether a reconciliation is in progress.
  bool get isReconciling => state == SaleOutcomeState.acceptedPending;

  @override
  String toString() =>
      'ConsistencyOutcome(state=${state.name}, opId=$operationId, '
      'confirmed=${confirmation != null})';
}

// ─── Orchestrator Interface ──────────────────────────────────────────────────

/// Abstract interface for the sale consistency orchestrator.
///
/// All mobileShop sale, cancellation, and return operations MUST use this
/// interface. It guarantees:
/// - Draft/pending local state only (Drift is cache, not authority)
/// - Operation ID / fingerprint reuse on retry
/// - Reconciliation tracking
/// - No false-positive committed labels
abstract interface class MobileSaleConsistencyOrchestrator {
  /// Finalize a mobile device sale through the consistency path.
  ///
  /// If online: queues locally as pending, then pushes to backend.
  /// If offline: queues locally and returns [SaleOutcomeState.offlineQueued].
  /// On backend confirmation: returns committed/acceptedPending.
  Future<ConsistencyOutcome> finalizeSale(
    TenantContext context,
    MobileSaleCommand command,
  );

  /// Cancel a mobile invoice through the consistency path.
  Future<ConsistencyOutcome> cancelSale(
    TenantContext context,
    MobileCancellationCommand command,
  );

  /// Process a device return through the consistency path.
  Future<ConsistencyOutcome> returnDevice(
    TenantContext context,
    MobileReturnCommand command,
  );

  /// Check the current reconciliation status of an operation.
  Future<ConsistencyOutcome> checkStatus(
    TenantContext context,
    String operationId,
  );
}

// ─── Implementation ──────────────────────────────────────────────────────────

/// Production implementation routing through MobileShopApi and local outbox.
///
/// Flow:
/// 1. Queue mutation in local outbox (Drift) with status = 'pending'
/// 2. Attempt immediate push if online
/// 3. On success → mark confirmed locally, return committed/acceptedPending
/// 4. On network error → leave as queued, return offlineQueued
/// 5. On conflict/rejection → create conflict record, return typed error
///
/// The Sync_Engine (MobileSyncCoordinator) handles background retry with
/// the same Operation_Id and Mutation_Fingerprint.
class MobileSaleConsistencyOrchestratorImpl
    implements MobileSaleConsistencyOrchestrator {
  final MobileShopLocalRepository _repository;
  final MobileShopApi _api;
  // ignore: unused_field
  final MobileSyncCoordinatorInterface _syncCoordinator;

  static const _uuid = Uuid();

  MobileSaleConsistencyOrchestratorImpl({
    required MobileShopLocalRepository repository,
    required MobileShopApi api,
    required MobileSyncCoordinatorInterface syncCoordinator,
  }) : _repository = repository,
       _api = api,
       _syncCoordinator = syncCoordinator;

  // ─── Public API ──────────────────────────────────────────────────────────

  @override
  Future<ConsistencyOutcome> finalizeSale(
    TenantContext context,
    MobileSaleCommand command,
  ) async {
    return _routeOperation(
      context: context,
      operationId: command.operationId,
      mutationFingerprint: command.mutationFingerprint,
      entityType: 'DEVICE_SALE',
      payload: _encodeSalePayload(command),
      baseVersions: command.expectedImeiVersions,
      dataModelVersion: command.dataModelVersion,
    );
  }

  @override
  Future<ConsistencyOutcome> cancelSale(
    TenantContext context,
    MobileCancellationCommand command,
  ) async {
    return _routeOperation(
      context: context,
      operationId: command.operationId,
      mutationFingerprint: command.mutationFingerprint,
      entityType: 'INVOICE_CANCEL',
      payload: _encodeCancellationPayload(command),
      baseVersions: command.expectedImeiVersions,
      dataModelVersion: command.dataModelVersion,
    );
  }

  @override
  Future<ConsistencyOutcome> returnDevice(
    TenantContext context,
    MobileReturnCommand command,
  ) async {
    return _routeOperation(
      context: context,
      operationId: command.operationId,
      mutationFingerprint: command.mutationFingerprint,
      entityType: 'DEVICE_RETURN',
      payload: _encodeReturnPayload(command),
      baseVersions: {command.normalizedImei: command.expectedImeiVersion},
      dataModelVersion: command.dataModelVersion,
    );
  }

  @override
  Future<ConsistencyOutcome> checkStatus(
    TenantContext context,
    String operationId,
  ) async {
    // Check local outbox status first
    final mutations = await _repository.getNextMutations(context, 1000);
    final match = mutations.where((m) => m.operationId == operationId);
    if (match.isNotEmpty) {
      final mutation = match.first;
      switch (mutation.status) {
        case 'queued':
        case 'sending':
          return ConsistencyOutcome(
            state: SaleOutcomeState.localPending,
            operationId: operationId,
            retryable: true,
          );
        case 'sent':
          return ConsistencyOutcome(
            state: SaleOutcomeState.committed,
            operationId: operationId,
          );
        case 'failed':
          return ConsistencyOutcome(
            state: SaleOutcomeState.conflict,
            operationId: operationId,
            retryable: false,
          );
        default:
          return ConsistencyOutcome(
            state: SaleOutcomeState.localPending,
            operationId: operationId,
            retryable: true,
          );
      }
    }

    // Not found in outbox — might already be confirmed or unknown
    return ConsistencyOutcome(
      state: SaleOutcomeState.localPending,
      operationId: operationId,
      retryable: true,
    );
  }

  // ─── Core Routing Logic ──────────────────────────────────────────────────

  /// Routes an operation through the consistency path:
  /// 1. Queue in local outbox (draft/pending)
  /// 2. Attempt immediate push
  /// 3. Return appropriate outcome
  Future<ConsistencyOutcome> _routeOperation({
    required TenantContext context,
    required String operationId,
    required String mutationFingerprint,
    required String entityType,
    required String payload,
    required Map<String, int> baseVersions,
    required int dataModelVersion,
  }) async {
    final now = DateTime.now();

    // Step 1: Queue in local outbox with 'queued' status (Req 7.2)
    // This is local draft/pending only — NOT authoritative.
    final outboxEntry = _buildOutboxEntity(
      context: context,
      operationId: operationId,
      mutationFingerprint: mutationFingerprint,
      entityType: entityType,
      payload: payload,
      baseVersions: baseVersions,
      dataModelVersion: dataModelVersion,
      now: now,
    );
    await _repository.queueMutation(context, outboxEntry);

    // Step 2: Check offline eligibility and connectivity
    if (!kOfflineEligibilityConfig.isOfflineEligible(entityType)) {
      // Online-only operations must attempt immediately
      return _attemptImmediatePush(context, operationId, outboxEntry);
    }

    // Step 3: Attempt immediate push (best-effort when online)
    try {
      return await _attemptImmediatePush(context, operationId, outboxEntry);
    } on Object {
      // Network failure — operation stays queued for Sync_Engine (Req 7.2, 7.14)
      return ConsistencyOutcome(
        state: SaleOutcomeState.offlineQueued,
        operationId: operationId,
        retryable: true,
      );
    }
  }

  /// Attempt immediate push to the backend via the API.
  Future<ConsistencyOutcome> _attemptImmediatePush(
    TenantContext context,
    String operationId,
    MobileOutboxMutationEntity outboxEntry,
  ) async {
    // Build sale DTO from the outbox entry payload
    final saleDto = <String, dynamic>{
      'operationId': outboxEntry.operationId,
      'mutationFingerprint': outboxEntry.mutationFingerprint,
      'tenantId': context.tenantId,
      'dataModelVersion': outboxEntry.dataModelVersion,
      'entityType': outboxEntry.entityType,
      'payload': outboxEntry.payload,
      'expectedVersions': outboxEntry.baseVersions != null
          ? jsonDecode(outboxEntry.baseVersions!)
          : <String, dynamic>{},
    };

    // Use finalizeSale for all mutation types — the backend routes internally
    // based on entityType in the payload
    final result = await _api.finalizeSale(saleDto);

    switch (result) {
      case ApiSuccess<SaleOutcomeDto>(:final data):
        return _handleApiSuccess(context, operationId, data);
      case ApiError<SaleOutcomeDto>(:final outcome):
        return _handleApiError(context, operationId, outcome);
      case ApiNetworkError<SaleOutcomeDto>():
        // Leave as queued — Sync_Engine retries with same IDs (Req 7.5)
        return ConsistencyOutcome(
          state: SaleOutcomeState.offlineQueued,
          operationId: operationId,
          retryable: true,
        );
    }
  }

  /// Handle a successful API response.
  ConsistencyOutcome _handleApiSuccess(
    TenantContext context,
    String operationId,
    MutationOutcome<Map<String, dynamic>> outcome,
  ) {
    switch (outcome.state) {
      case MutationOutcomeState.committed:
        // Server confirmed — mark locally as server-confirmed
        _markLocallyConfirmed(context, operationId);
        return ConsistencyOutcome(
          state: SaleOutcomeState.committed,
          operationId: operationId,
          confirmation: outcome.confirmation,
        );
      case MutationOutcomeState.acceptedPending:
        // Accepted pending reconciliation — track reconciliation status
        _trackReconciliation(context, operationId, outcome.confirmation);
        return ConsistencyOutcome(
          state: SaleOutcomeState.acceptedPending,
          operationId: operationId,
          confirmation: outcome.confirmation,
          retryable: false,
        );
      case MutationOutcomeState.conflict:
        _markLocalConflict(context, operationId, outcome.error);
        return ConsistencyOutcome(
          state: SaleOutcomeState.conflict,
          operationId: operationId,
          errorCode: outcome.error?.code,
          errorMessage: outcome.error?.message,
          retryable: outcome.error?.retryable ?? false,
        );
      case MutationOutcomeState.rejected:
        _markLocalConflict(context, operationId, outcome.error);
        return ConsistencyOutcome(
          state: SaleOutcomeState.rejected,
          operationId: operationId,
          errorCode: outcome.error?.code,
          errorMessage: outcome.error?.message,
          retryable: false,
        );
    }
  }

  /// Handle a domain error from the API.
  ConsistencyOutcome _handleApiError(
    TenantContext context,
    String operationId,
    DeterministicOutcome outcome,
  ) {
    // Mark mutation as failed in outbox
    _repository.markMutationFailed(
      context,
      operationId,
      '${outcome.code}: ${outcome.recoveryAction}',
    );

    return ConsistencyOutcome(
      state: SaleOutcomeState.rejected,
      operationId: operationId,
      errorCode: outcome.code,
      errorMessage: outcome.recoveryAction,
      retryable: outcome.retryable,
    );
  }

  // ─── Local State Management ──────────────────────────────────────────────

  /// Mark operation as server-confirmed locally.
  void _markLocallyConfirmed(TenantContext context, String operationId) {
    // Fire-and-forget: update outbox status to 'sent'
    _repository.markMutationSent(context, operationId);
  }

  /// Track reconciliation status for accepted-pending outcomes.
  void _trackReconciliation(
    TenantContext context,
    String operationId,
    AuthoritativeConfirmation? confirmation,
  ) {
    // Mark as sent (accepted by backend)
    _repository.markMutationSent(context, operationId);
    // Reconciliation tracking is handled by the pull service when
    // it receives change events with reconciliation updates.
  }

  /// Mark a local conflict for rejected/conflicted operations.
  void _markLocalConflict(
    TenantContext context,
    String operationId,
    MutationError? error,
  ) {
    _repository.markMutationFailed(
      context,
      operationId,
      error?.message ?? 'Unknown conflict',
    );
  }

  // ─── Payload Encoding ────────────────────────────────────────────────────

  String _encodeSalePayload(MobileSaleCommand command) {
    return jsonEncode({
      'type': 'DEVICE_SALE',
      'operationId': command.operationId,
      'mutationFingerprint': command.mutationFingerprint,
      'invoice': command.invoicePayload,
      'deviceLines': command.deviceLines.map((d) => d.toJson()).toList(),
      'expectedImeiVersions': command.expectedImeiVersions,
      'dataModelVersion': command.dataModelVersion,
    });
  }

  String _encodeCancellationPayload(MobileCancellationCommand command) {
    return jsonEncode({
      'type': 'INVOICE_CANCEL',
      'operationId': command.operationId,
      'mutationFingerprint': command.mutationFingerprint,
      'invoiceId': command.invoiceId,
      'expectedInvoiceVersion': command.expectedInvoiceVersion,
      'associatedImeis': command.associatedImeis,
      'expectedImeiVersions': command.expectedImeiVersions,
      'reason': command.reason,
      'dataModelVersion': command.dataModelVersion,
    });
  }

  String _encodeReturnPayload(MobileReturnCommand command) {
    return jsonEncode({
      'type': 'DEVICE_RETURN',
      'operationId': command.operationId,
      'mutationFingerprint': command.mutationFingerprint,
      'originatingInvoiceId': command.originatingInvoiceId,
      'normalizedImei': command.normalizedImei,
      'expectedImeiVersion': command.expectedImeiVersion,
      'condition': command.condition,
      'reason': command.reason,
      'targetLifecycleState': command.targetLifecycleState,
      'dataModelVersion': command.dataModelVersion,
    });
  }

  // ─── Outbox Entity Builder ───────────────────────────────────────────────

  /// Build a typed outbox entity for the local repository.
  MobileOutboxMutationEntity _buildOutboxEntity({
    required TenantContext context,
    required String operationId,
    required String mutationFingerprint,
    required String entityType,
    required String payload,
    required Map<String, int> baseVersions,
    required int dataModelVersion,
    required DateTime now,
  }) {
    return MobileOutboxMutationEntity(
      id: _uuid.v4(),
      tenantId: context.tenantId,
      operationId: operationId,
      mutationFingerprint: mutationFingerprint,
      entityType: entityType,
      payload: payload,
      baseVersions: jsonEncode(baseVersions),
      dependencies: null,
      retryCount: 0,
      maxRetries: 10,
      status: OutboxStatus.queued,
      dataModelVersion: dataModelVersion,
      createdAt: now,
      lastAttemptAt: null,
      updatedAt: now,
    );
  }
}

// ─── Fingerprint Utility ─────────────────────────────────────────────────────

/// Generates a deterministic mutation fingerprint from the operation type
/// and normalized immutable fields.
///
/// The fingerprint is computed once per logical mutation and reused on every
/// retry (Req 7.5). The same request fields MUST produce the same fingerprint.
String computeMutationFingerprint(String operationType, String payload) {
  // Use a simple stable hash for the fingerprint.
  // In production, this could be SHA-256 of the canonical JSON.
  final input = '$operationType:$payload';
  final bytes = utf8.encode(input);
  var hash = 0;
  for (final byte in bytes) {
    hash = ((hash << 5) - hash + byte) & 0x7FFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Generates a new unique operation ID.
///
/// Called exactly ONCE per logical mutation. NEVER regenerated on retry.
String generateOperationId() => const Uuid().v4();
