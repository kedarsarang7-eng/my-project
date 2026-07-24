/// Inventory Command Service — Screen-facing mutation API (Dart)
///
/// Provides a clean interface for screens to queue inventory operations
/// (reservations, demo transitions, intake submissions) without requiring
/// screens to construct Drift entities directly.
///
/// Routes through the local repository outbox and respects the sync
/// infrastructure (Operation_Id reuse, fingerprint, etc.).
///
/// Requirements: 4.1–4.9, 7.2–7.6, 12.7
library;

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../auth/tenant_context.dart';
import '../billing/mobile_sale_consistency_orchestrator.dart';
import '../database/mobile_shop_database.dart';
import '../repository/mobile_shop_local_repository.dart';

/// Application service for queueing inventory lifecycle commands
/// from screens without exposing infrastructure details.
class InventoryCommandService {
  final MobileShopLocalRepository _repository;
  static const _uuid = Uuid();

  InventoryCommandService({required MobileShopLocalRepository repository})
    : _repository = repository;

  /// Queue a demo lifecycle transition (mark as demo or return to stock).
  Future<void> queueDemoTransition({
    required TenantContext context,
    required String imei,
    required int expectedVersion,
    required String targetState,
    String? reason,
  }) async {
    final operationId = _uuid.v4();
    final fingerprint = computeMutationFingerprint(
      'DEMO_TRANSITION',
      '$imei:$expectedVersion:$targetState',
    );
    final payload = jsonEncode({
      'type': 'DEMO_TRANSITION',
      'operationId': operationId,
      'imei': imei,
      'expectedVersion': expectedVersion,
      'targetState': targetState,
      'reason': ?reason,
    });

    final entity = MobileOutboxMutationEntity(
      id: _uuid.v4(),
      tenantId: context.tenantId,
      operationId: operationId,
      mutationFingerprint: fingerprint,
      entityType: 'IMEI_UNIT',
      payload: payload,
      baseVersions: jsonEncode({imei: expectedVersion}),
      dependencies: null,
      retryCount: 0,
      maxRetries: 10,
      status: 'queued',
      dataModelVersion: 1,
      createdAt: DateTime.now(),
      lastAttemptAt: null,
      updatedAt: DateTime.now(),
    );

    await _repository.queueMutation(context, entity);
  }

  /// Queue a device reservation claim.
  Future<void> queueReservation({
    required TenantContext context,
    required String imei,
    required String customerName,
    String? depositAmount,
  }) async {
    final operationId = _uuid.v4();
    final fingerprint = computeMutationFingerprint(
      'DEVICE_RESERVATION',
      '$imei:$customerName',
    );
    final payload = jsonEncode({
      'type': 'DEVICE_RESERVATION',
      'operationId': operationId,
      'imei': imei,
      'customerName': customerName,
      if (depositAmount != null && depositAmount.isNotEmpty)
        'depositAmountMinor': int.tryParse(depositAmount) ?? 0,
    });

    final entity = MobileOutboxMutationEntity(
      id: _uuid.v4(),
      tenantId: context.tenantId,
      operationId: operationId,
      mutationFingerprint: fingerprint,
      entityType: 'RESERVATION',
      payload: payload,
      baseVersions: null,
      dependencies: null,
      retryCount: 0,
      maxRetries: 10,
      status: 'queued',
      dataModelVersion: 1,
      createdAt: DateTime.now(),
      lastAttemptAt: null,
      updatedAt: DateTime.now(),
    );

    await _repository.queueMutation(context, entity);
  }

  /// Queue a second-hand intake submission.
  Future<void> queueIntakeSubmission({
    required TenantContext context,
    required Map<String, dynamic> intakeData,
  }) async {
    final operationId = _uuid.v4();
    final fingerprint = computeMutationFingerprint(
      'SECOND_HAND_INTAKE',
      intakeData['imei'] as String? ?? operationId,
    );
    final payload = jsonEncode({
      'type': 'SECOND_HAND_INTAKE',
      'operationId': operationId,
      ...intakeData,
    });

    final entity = MobileOutboxMutationEntity(
      id: _uuid.v4(),
      tenantId: context.tenantId,
      operationId: operationId,
      mutationFingerprint: fingerprint,
      entityType: 'SECOND_HAND_INTAKE',
      payload: payload,
      baseVersions: null,
      dependencies: null,
      retryCount: 0,
      maxRetries: 10,
      status: 'queued',
      dataModelVersion: 1,
      createdAt: DateTime.now(),
      lastAttemptAt: null,
      updatedAt: DateTime.now(),
    );

    await _repository.queueMutation(context, entity);
  }
}
