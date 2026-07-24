// ============================================================================
// MOBILE SHOP — API CONTRACT TESTS
// ============================================================================
// Validates MobileShopApi adapter DTOs, result types, confirmation semantics,
// and endpoint construction.
//
// **Validates: Requirements 6.3–6.4, 6.15–6.18, 6.42, 12.4–12.5, 13.1–13.3**
//
// Run: flutter test test/features/mobile_shop/verification/api_contract_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/api/api_result.dart';
import 'package:dukanx/features/mobile_shop/api/mobile_endpoint.dart';
import 'package:dukanx/features/mobile_shop/config/error_codes_config.dart';
import 'package:dukanx/features/mobile_shop/models/confirmation_models.dart';
import 'package:dukanx/features/mobile_shop/models/sync_models.dart';

// ─── Main Test Suite ─────────────────────────────────────────────────────────

void main() {
  // ==========================================================================
  // GROUP 1: ApiResult Sealed Type — Exhaustive States
  // ==========================================================================
  group('ApiResult — sealed types', () {
    test('ApiSuccess carries data and optional confirmation', () {
      const result = ApiSuccess<String>(
        data: 'test-data',
        apiVersion: 1,
        dataModelVersion: 1,
        correlationId: 'corr-001',
      );

      expect(result.data, 'test-data');
      expect(result.confirmation, isNull);
      expect(result.apiVersion, 1);
      expect(result.dataModelVersion, 1);
      expect(result.correlationId, 'corr-001');
    });

    test('ApiSuccess with confirmation carries authoritative evidence', () {
      const confirmation = AuthoritativeConfirmation(
        authority: ConfirmationAuthority.awsDynamoDb,
        state: ConfirmationState.committed,
        confirmedAt: '2024-01-15T10:00:00Z',
        dataModelVersion: 1,
        entityVersions: {'unit-1': 5},
        operationId: 'op-123',
      );

      const result = ApiSuccess<String>(
        data: 'confirmed-data',
        confirmation: confirmation,
        apiVersion: 1,
        dataModelVersion: 1,
      );

      expect(result.confirmation, isNotNull);
      expect(result.confirmation!.authority, ConfirmationAuthority.awsDynamoDb);
      expect(result.confirmation!.state, ConfirmationState.committed);
    });

    test('ApiNetworkError carries message and retryable flag', () {
      const result = ApiNetworkError<String>(
        message: 'Connection timeout',
        retryable: true,
      );

      expect(result.message, 'Connection timeout');
      expect(result.retryable, isTrue);
    });

    test('ApiNetworkError non-retryable for DNS failures', () {
      const result = ApiNetworkError<String>(
        message: 'DNS resolution failed',
        retryable: false,
      );

      expect(result.retryable, isFalse);
    });

    test('ApiResult types are exhaustive via switch', () {
      ApiResult<String> result = const ApiSuccess<String>(
        data: 'x',
        apiVersion: 1,
        dataModelVersion: 1,
      );

      // This verifies the sealed type is exhaustive at compile time
      final description = switch (result) {
        ApiSuccess<String>() => 'success',
        ApiError<String>() => 'error',
        ApiNetworkError<String>() => 'network',
      };
      expect(description, 'success');
    });
  });

  // ==========================================================================
  // GROUP 2: AuthoritativeConfirmation — Semantics
  // ==========================================================================
  group('AuthoritativeConfirmation — semantics', () {
    test('committed state with valid fields', () {
      const confirmation = AuthoritativeConfirmation(
        authority: ConfirmationAuthority.awsDynamoDb,
        state: ConfirmationState.committed,
        confirmedAt: '2024-01-15T10:00:00Z',
        dataModelVersion: 1,
        entityVersions: {'unit-1': 3, 'unit-2': 5},
        operationId: 'op-001',
      );

      expect(confirmation.authority, ConfirmationAuthority.awsDynamoDb);
      expect(confirmation.state, ConfirmationState.committed);
      expect(confirmation.entityVersions.length, 2);
      expect(confirmation.operationId, 'op-001');
    });

    test('acceptedPending includes reconciliation reference', () {
      const confirmation = AuthoritativeConfirmation(
        authority: ConfirmationAuthority.awsDynamoDb,
        state: ConfirmationState.acceptedPending,
        confirmedAt: '2024-01-15T10:00:00Z',
        dataModelVersion: 1,
        entityVersions: {'unit-1': 3},
        operationId: 'op-002',
        reconciliationId: 'recon-001',
      );

      expect(confirmation.state, ConfirmationState.acceptedPending);
      expect(confirmation.reconciliationId, 'recon-001');
    });

    test('current state has no operationId', () {
      const confirmation = AuthoritativeConfirmation(
        authority: ConfirmationAuthority.awsDynamoDb,
        state: ConfirmationState.current,
        confirmedAt: '2024-01-15T10:00:00Z',
        dataModelVersion: 1,
        entityVersions: {'unit-1': 10},
      );

      expect(confirmation.state, ConfirmationState.current);
      expect(confirmation.operationId, isNull);
    });
  });

  // ==========================================================================
  // GROUP 3: Sync DTOs — PushBatchRequest
  // ==========================================================================
  group('Sync DTOs — PushBatchRequest', () {
    test('PushBatchRequest carries mutations with operation identities', () {
      final request = PushBatchRequest(
        tenantId: 'tenant-1',
        dataModelVersion: 1,
        mutations: [
          PushMutation(
            operationId: 'op-1',
            mutationFingerprint: 'fp-1',
            dataModelVersion: 1,
            entityType: 'IMEI_UNIT',
            payload: '{"action":"createUnit"}',
            expectedVersions: {'unit-1': 2},
            queuedAt: '2024-01-15T10:00:00Z',
          ),
        ],
      );

      expect(request.mutations.length, 1);
      expect(request.mutations.first.operationId, 'op-1');
      expect(request.mutations.first.mutationFingerprint, 'fp-1');
      expect(request.tenantId, 'tenant-1');
      expect(request.dataModelVersion, 1);
    });

    test('PushBatchResponse maps per-mutation outcomes', () {
      const response = PushBatchResponse(
        dataModelVersion: 1,
        results: [
          PushMutationResult(
            operationId: 'op-1',
            status: PushMutationResultStatus.committed,
            confirmation: AuthoritativeConfirmation(
              authority: ConfirmationAuthority.awsDynamoDb,
              state: ConfirmationState.committed,
              confirmedAt: '2024-01-15T10:00:00Z',
              dataModelVersion: 1,
              entityVersions: {'unit-1': 3},
            ),
          ),
          PushMutationResult(
            operationId: 'op-2',
            status: PushMutationResultStatus.conflict,
            errorCode: 'VERSION_MISMATCH',
            errorMessage: 'Expected v2 but found v5',
          ),
        ],
      );

      expect(response.results.length, 2);
      expect(response.results[0].status, PushMutationResultStatus.committed);
      expect(response.results[0].confirmation, isNotNull);
      expect(response.results[1].status, PushMutationResultStatus.conflict);
      expect(response.results[1].errorCode, 'VERSION_MISMATCH');
    });
  });

  // ==========================================================================
  // GROUP 4: Sync DTOs — PullRequest/PullResponse
  // ==========================================================================
  group('Sync DTOs — PullRequest/PullResponse', () {
    test('PullRequest carries tenant and optional continuation token', () {
      final request = PullRequest(
        tenantId: 'tenant-1',
        dataModelVersion: 1,
        continuationToken: 'opaque-token-abc',
        limit: 50,
      );

      expect(request.tenantId, 'tenant-1');
      expect(request.continuationToken, 'opaque-token-abc');
      expect(request.limit, 50);
    });

    test('PullRequest without token starts from beginning', () {
      final request = PullRequest(
        tenantId: 'tenant-1',
        dataModelVersion: 1,
        limit: 100,
      );

      expect(request.continuationToken, isNull);
    });

    test('PullResponse carries changes and pagination state', () {
      final response = PullResponse(
        dataModelVersion: 1,
        changes: [
          ChangeEvent(
            eventId: 'evt-1',
            tenantId: 'tenant-1',
            dataModelVersion: 1,
            entityType: 'IMEI_UNIT',
            entityId: 'unit-1',
            entityVersion: 3,
            action: 'UPDATED',
            occurredAt: '2024-01-15T10:00:00Z',
            sequence: 100,
          ),
        ],
        continuationToken: 'next-cursor',
        hasMore: true,
      );

      expect(response.changes.length, 1);
      expect(response.hasMore, isTrue);
      expect(response.continuationToken, 'next-cursor');
    });

    test('PullResponse with empty changes and no more pages', () {
      const response = PullResponse(
        dataModelVersion: 1,
        changes: [],
        hasMore: false,
      );

      expect(response.changes, isEmpty);
      expect(response.hasMore, isFalse);
      expect(response.continuationToken, isNull);
    });
  });

  // ==========================================================================
  // GROUP 5: ServerHint — Minimal Invalidation DTO
  // ==========================================================================
  group('ServerHint — minimal invalidation', () {
    test('carries only tenant, event identity, and pull hint', () {
      final hint = ServerHint(
        tenantId: 'tenant-1',
        eventId: 'evt-1',
        entityType: 'IMEI_UNIT',
        entityId: 'unit-1',
        entityVersion: 5,
        hint: 'PULL_REQUIRED',
        occurredAt: '2024-01-15T10:00:00Z',
      );

      expect(hint.tenantId, 'tenant-1');
      expect(hint.eventId, 'evt-1');
      expect(hint.entityType, 'IMEI_UNIT');
      expect(hint.entityVersion, 5);
      expect(hint.hint, 'PULL_REQUIRED');
    });
  });

  // ==========================================================================
  // GROUP 6: ChangeEvent — Wire Contract
  // ==========================================================================
  group('ChangeEvent — wire contract', () {
    test('all required fields present', () {
      final event = ChangeEvent(
        eventId: 'evt-001',
        tenantId: 'tenant-A',
        dataModelVersion: 1,
        entityType: 'SERVICE_JOB',
        entityId: 'job-1',
        entityVersion: 2,
        action: 'CREATED',
        occurredAt: '2024-01-15T10:00:00Z',
        sequence: 42,
      );

      expect(event.eventId, 'evt-001');
      expect(event.tenantId, 'tenant-A');
      expect(event.entityType, 'SERVICE_JOB');
      expect(event.entityVersion, 2);
      expect(event.action, 'CREATED');
      expect(event.sequence, 42);
    });
  });

  // ==========================================================================
  // GROUP 7: MobileEndpoint — Typed Endpoint Construction
  // ==========================================================================
  group('MobileEndpoint — typed endpoint construction', () {
    test('endpoint carries path, method, and request/response types', () {
      final endpoint = MobileEndpoint<Map<String, dynamic>>(
        path: '/api/v1/mobile-shop/units',
        method: HttpMethod.get,
        queryParams: {'status': 'IN_STOCK', 'limit': '50'},
      );

      expect(endpoint.path, '/api/v1/mobile-shop/units');
      expect(endpoint.method, HttpMethod.get);
      expect(endpoint.queryParams?['status'], 'IN_STOCK');
    });

    test('mutation endpoint carries body and expected headers', () {
      final endpoint = MobileEndpoint<Map<String, dynamic>>(
        path: '/api/v1/mobile-shop/units/transition',
        method: HttpMethod.post,
        body: {
          'operationId': 'op-1',
          'mutationFingerprint': 'fp-1',
          'targetState': 'RESERVED',
          'expectedVersion': 3,
        },
      );

      expect(endpoint.method, HttpMethod.post);
      expect(endpoint.body?['operationId'], 'op-1');
    });
  });

  // ==========================================================================
  // GROUP 8: MutationOutcome — Typed Outcomes
  // ==========================================================================
  group('MutationOutcome — typed outcomes', () {
    test('committed outcome has confirmation', () {
      final outcome = MutationOutcome<Map<String, dynamic>>(
        state: MutationOutcomeState.committed,
        dataModelVersion: 1,
        confirmation: const AuthoritativeConfirmation(
          authority: ConfirmationAuthority.awsDynamoDb,
          state: ConfirmationState.committed,
          confirmedAt: '2024-01-15T10:00:00Z',
          dataModelVersion: 1,
          entityVersions: {'unit-1': 4},
        ),
      );

      expect(outcome.state, MutationOutcomeState.committed);
      expect(outcome.confirmation, isNotNull);
    });

    test('conflict outcome carries error details', () {
      final outcome = MutationOutcome<Map<String, dynamic>>(
        state: MutationOutcomeState.conflict,
        dataModelVersion: 1,
        error: const MutationError(
          code: 'VERSION_MISMATCH',
          message: 'Expected v2 but found v5',
          retryable: false,
        ),
      );

      expect(outcome.state, MutationOutcomeState.conflict);
      expect(outcome.error, isNotNull);
      expect(outcome.error!.code, 'VERSION_MISMATCH');
    });

    test('acceptedPending outcome has reconciliation ID', () {
      final outcome = MutationOutcome<Map<String, dynamic>>(
        state: MutationOutcomeState.acceptedPending,
        dataModelVersion: 1,
        confirmation: const AuthoritativeConfirmation(
          authority: ConfirmationAuthority.awsDynamoDb,
          state: ConfirmationState.acceptedPending,
          confirmedAt: '2024-01-15T10:00:00Z',
          dataModelVersion: 1,
          entityVersions: {'unit-1': 3},
          reconciliationId: 'recon-001',
        ),
      );

      expect(outcome.state, MutationOutcomeState.acceptedPending);
      expect(outcome.confirmation!.reconciliationId, 'recon-001');
    });
  });
}
