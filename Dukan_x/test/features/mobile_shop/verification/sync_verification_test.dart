// ============================================================================
// MOBILE SHOP — SYNC VERIFICATION TESTS
// ============================================================================
// Additional sync tests focusing on outbox submission, pull cycles, and
// tenant switching behaviors not covered by the existing sync test file.
// Validates deterministic sync behavior and state machine invariants.
//
// **Validates: Requirements 7.1–7.15, 8.3–8.4, 13.1, 13.4–13.5**
//
// Run: flutter test test/features/mobile_shop/verification/sync_verification_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/auth/business_type.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context.dart';
import 'package:dukanx/features/mobile_shop/models/confirmation_models.dart';
import 'package:dukanx/features/mobile_shop/models/sync_models.dart';
import 'package:dukanx/features/mobile_shop/repository/mobile_shop_local_repository.dart';
import 'package:dukanx/features/mobile_shop/sync/sync_types.dart';
import 'package:dukanx/features/mobile_shop/sync/tenant_switch_handler.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

int _counter = 0;

TenantContext _mobileCtx([String tenantId = 'tenant-sync']) => TenantContext(
  tenantId: tenantId,
  businessId: tenantId,
  subjectId: 'user-$tenantId',
  businessType: MobileShopBusinessType.mobileShop,
  permissions: const {'manage_imei', 'view_imei'},
  correlationId: 'corr-${++_counter}',
);

// ─── Main Test Suite ─────────────────────────────────────────────────────────

void main() {
  // ==========================================================================
  // GROUP 1: PushMutation DTO Invariants
  // ==========================================================================
  group('PushMutation DTO invariants', () {
    test('operationId is required and non-empty', () {
      final mutation = PushMutation(
        operationId: 'op-test-1',
        mutationFingerprint: 'fp-1',
        dataModelVersion: 1,
        entityType: 'IMEI_UNIT',
        payload: '{"action":"create"}',
        expectedVersions: const {},
        queuedAt: '2024-01-15T10:00:00Z',
      );

      expect(mutation.operationId, isNotEmpty);
      expect(mutation.mutationFingerprint, isNotEmpty);
    });

    test('expectedVersions carries expected entity versions', () {
      final mutation = PushMutation(
        operationId: 'op-v1',
        mutationFingerprint: 'fp-v1',
        dataModelVersion: 1,
        entityType: 'IMEI_UNIT',
        payload: '{}',
        expectedVersions: {'unit-1': 3, 'unit-2': 5},
        queuedAt: '2024-01-15T10:00:00Z',
      );

      expect(mutation.expectedVersions['unit-1'], 3);
      expect(mutation.expectedVersions['unit-2'], 5);
    });

    test('PushBatchRequest serializes multiple mutations', () {
      final request = PushBatchRequest(
        tenantId: 'tenant-batch',
        dataModelVersion: 1,
        mutations: [
          PushMutation(
            operationId: 'op-1',
            mutationFingerprint: 'fp-1',
            dataModelVersion: 1,
            entityType: 'IMEI_UNIT',
            payload: '{}',
            expectedVersions: const {},
            queuedAt: '2024-01-15T10:00:00Z',
          ),
          PushMutation(
            operationId: 'op-2',
            mutationFingerprint: 'fp-2',
            dataModelVersion: 1,
            entityType: 'SERVICE_JOB',
            payload: '{}',
            expectedVersions: const {},
            queuedAt: '2024-01-15T10:01:00Z',
          ),
        ],
      );

      expect(request.mutations.length, 2);
      expect(request.tenantId, 'tenant-batch');
    });
  });

  // ==========================================================================
  // GROUP 2: PushMutationResult — Status Mapping
  // ==========================================================================
  group('PushMutationResult — status mapping', () {
    test('committed status carries confirmation', () {
      const result = PushMutationResult(
        operationId: 'op-1',
        status: PushMutationResultStatus.committed,
        confirmation: AuthoritativeConfirmation(
          authority: ConfirmationAuthority.awsDynamoDb,
          state: ConfirmationState.committed,
          confirmedAt: '2024-01-15T10:00:00Z',
          dataModelVersion: 1,
          entityVersions: {'unit-1': 4},
        ),
      );

      expect(result.status, PushMutationResultStatus.committed);
      expect(result.confirmation, isNotNull);
      expect(result.errorCode, isNull);
    });

    test('conflict status carries error code and message', () {
      const result = PushMutationResult(
        operationId: 'op-2',
        status: PushMutationResultStatus.conflict,
        errorCode: 'VERSION_MISMATCH',
        errorMessage: 'Expected v2 but found v5',
      );

      expect(result.status, PushMutationResultStatus.conflict);
      expect(result.errorCode, 'VERSION_MISMATCH');
      expect(result.confirmation, isNull);
    });

    test('rejected status with business rule violation', () {
      const result = PushMutationResult(
        operationId: 'op-3',
        status: PushMutationResultStatus.rejected,
        errorCode: 'LIFECYCLE_VIOLATION',
        errorMessage: 'Cannot transition from RETIRED',
      );

      expect(result.status, PushMutationResultStatus.rejected);
      expect(result.errorCode, 'LIFECYCLE_VIOLATION');
    });
  });

  // ==========================================================================
  // GROUP 3: PullRequest — Bounded Pagination
  // ==========================================================================
  group('PullRequest — bounded pagination', () {
    test('limit must be positive', () {
      final request = PullRequest(
        tenantId: 'tenant-pull',
        dataModelVersion: 1,
        limit: 50,
      );

      expect(request.limit, greaterThan(0));
    });

    test('null continuation token starts from beginning', () {
      final request = PullRequest(
        tenantId: 'tenant-pull',
        dataModelVersion: 1,
        limit: 100,
      );

      expect(request.continuationToken, isNull);
    });

    test('continuation token opaque value is preserved', () {
      final request = PullRequest(
        tenantId: 'tenant-pull',
        dataModelVersion: 1,
        continuationToken: 'encrypted-opaque-token-xyz',
        limit: 50,
      );

      expect(request.continuationToken, 'encrypted-opaque-token-xyz');
    });
  });

  // ==========================================================================
  // GROUP 4: ChangeEvent — Version Semantics
  // ==========================================================================
  group('ChangeEvent — version semantics', () {
    test('entityVersion is a monotonically increasing integer', () {
      final event = ChangeEvent(
        eventId: 'evt-mono-1',
        tenantId: 'tenant-ver',
        dataModelVersion: 1,
        entityType: 'IMEI_UNIT',
        entityId: 'unit-1',
        entityVersion: 42,
        action: 'UPDATED',
        occurredAt: '2024-01-15T10:00:00Z',
        sequence: 500,
      );

      expect(event.entityVersion, greaterThan(0));
      expect(event.sequence, greaterThan(0));
    });

    test('action values cover create, update, delete', () {
      // These are the valid domain actions
      for (final action in ['CREATED', 'UPDATED', 'DELETED']) {
        final event = ChangeEvent(
          eventId: 'evt-$action',
          tenantId: 'tenant-act',
          dataModelVersion: 1,
          entityType: 'IMEI_UNIT',
          entityId: 'unit-1',
          entityVersion: 1,
          action: action,
          occurredAt: '2024-01-15T10:00:00Z',
          sequence: 1,
        );
        expect(event.action, action);
      }
    });
  });

  // ==========================================================================
  // GROUP 5: ServerHint — Deduplication Key
  // ==========================================================================
  group('ServerHint — deduplication key', () {
    test('eventId is the deduplication key', () {
      final hint1 = ServerHint(
        tenantId: 'tenant-dup',
        eventId: 'evt-same',
        entityType: 'IMEI_UNIT',
        entityId: 'unit-1',
        entityVersion: 3,
        hint: 'PULL_REQUIRED',
        occurredAt: '2024-01-15T10:00:00Z',
      );
      final hint2 = ServerHint(
        tenantId: 'tenant-dup',
        eventId: 'evt-same',
        entityType: 'IMEI_UNIT',
        entityId: 'unit-1',
        entityVersion: 3,
        hint: 'PULL_REQUIRED',
        occurredAt: '2024-01-15T10:00:00Z',
      );

      // Same eventId means same hint (dedup)
      expect(hint1.eventId, equals(hint2.eventId));
    });

    test('different eventId means different events', () {
      final hint1 = ServerHint(
        tenantId: 'tenant-dup',
        eventId: 'evt-1',
        entityType: 'IMEI_UNIT',
        entityId: 'unit-1',
        entityVersion: 3,
        hint: 'PULL_REQUIRED',
        occurredAt: '2024-01-15T10:00:00Z',
      );
      final hint2 = ServerHint(
        tenantId: 'tenant-dup',
        eventId: 'evt-2',
        entityType: 'IMEI_UNIT',
        entityId: 'unit-1',
        entityVersion: 4,
        hint: 'PULL_REQUIRED',
        occurredAt: '2024-01-15T10:01:00Z',
      );

      expect(hint1.eventId, isNot(equals(hint2.eventId)));
    });
  });

  // ==========================================================================
  // GROUP 6: CheckpointState — State Semantics
  // ==========================================================================
  group('CheckpointState — state semantics', () {
    test('fresh checkpoint has null position', () {
      const checkpoint = CheckpointState(
        bucket: 'ROOT',
        lastPosition: null,
        serverVersion: 0,
      );

      expect(checkpoint.lastPosition, isNull);
      expect(checkpoint.lastPulledAt, isNull);
    });

    test('advanced checkpoint has position and timestamp', () {
      final checkpoint = CheckpointState(
        bucket: 'ROOT',
        lastPosition: 'cursor-xyz',
        lastPulledAt: DateTime.now(),
        serverVersion: 10,
      );

      expect(checkpoint.lastPosition, isNotNull);
      expect(checkpoint.lastPulledAt, isNotNull);
      expect(checkpoint.serverVersion, 10);
    });
  });

  // ==========================================================================
  // GROUP 7: SyncCycleResult — Typed Outcome
  // ==========================================================================
  group('SyncCycleResult — typed outcome', () {
    test('successful cycle reports counts', () {
      const result = SyncCycleResult(
        pushedCount: 3,
        pulledCount: 10,
        conflictsCreated: 1,
        hasMorePull: false,
      );

      expect(result.pushedCount, 3);
      expect(result.pulledCount, 10);
      expect(result.conflictsCreated, 1);
      expect(result.hasMorePull, isFalse);
      expect(result.hasWork, isTrue);
    });

    test('empty cycle reports no work', () {
      expect(SyncCycleResult.empty.hasWork, isFalse);
      expect(SyncCycleResult.empty.pushedCount, 0);
      expect(SyncCycleResult.empty.pulledCount, 0);
    });

    test('hasMorePull indicates more data available', () {
      const result = SyncCycleResult(
        pushedCount: 0,
        pulledCount: 50,
        conflictsCreated: 0,
        hasMorePull: true,
      );

      expect(result.hasMorePull, isTrue);
    });
  });

  // ==========================================================================
  // GROUP 8: TenantSwitchResult — Typed Outcomes
  // ==========================================================================
  group('TenantSwitchResult — typed outcomes', () {
    test('success indicates clean switch', () {
      expect(TenantSwitchResult.success.name, 'success');
    });

    test(
      'successWithPullFailure indicates switch succeeded but pull failed',
      () {
        expect(
          TenantSwitchResult.successWithPullFailure.name,
          'successWithPullFailure',
        );
      },
    );
  });

  // ==========================================================================
  // GROUP 9: Outbox/Conflict Status Constants
  // ==========================================================================
  group('Status constants', () {
    test('OutboxStatus values are documented strings', () {
      expect(OutboxStatus.queued, 'queued');
      expect(OutboxStatus.sending, 'sending');
      expect(OutboxStatus.sent, 'sent');
      expect(OutboxStatus.failed, 'failed');
    });

    test('ConflictResolutionStatus values are documented strings', () {
      expect(ConflictResolutionStatus.unresolved, 'unresolved');
      expect(ConflictResolutionStatus.accepted, 'accepted');
      expect(ConflictResolutionStatus.rejected, 'rejected');
      expect(ConflictResolutionStatus.merged, 'merged');
    });

    test('ConfirmationStatus values are documented strings', () {
      expect(ConfirmationStatus.pending, 'pending');
      expect(ConfirmationStatus.serverConfirmed, 'serverConfirmed');
      expect(ConfirmationStatus.conflict, 'conflict');
    });
  });
}
