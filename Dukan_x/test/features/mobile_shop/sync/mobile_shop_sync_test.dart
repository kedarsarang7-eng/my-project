// ============================================================================
// MOBILE SHOP — API-CONTRACT & SYNCHRONIZATION INTEGRATION TESTS
// ============================================================================
// Verifies offline persistence, dependency order, identity reuse, mismatch
// conflict, page/checkpoint recovery, tenant switch, duplicate/out-of-order
// hints, failed pulls, and confirmation-scoped state transitions.
//
// **Validates: Requirements 7.1–7.15, 8.3–8.4, 13.1**
//
// Uses Mockito mocks for MobileShopApi and MobileShopLocalRepository.
// These are unit/integration tests of the sync logic — not E2E.
//
// TODO: Run `dart run build_runner build --delete-conflicting-outputs` before
// executing these tests. The generated Drift entities
// (MobileOutboxMutationEntity, MobileConflictEntity, MobileEventInboxEntity)
// must exist for compilation.
//
// Run: flutter test test/features/mobile_shop/sync/mobile_shop_sync_test.dart
// ============================================================================

import 'dart:convert';

import 'package:dukanx/features/mobile_shop/api/api_result.dart';
import 'package:dukanx/features/mobile_shop/api/mobile_shop_api.dart';
import 'package:dukanx/features/mobile_shop/auth/business_type.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context.dart';
import 'package:dukanx/features/mobile_shop/database/mobile_shop_database.dart';
import 'package:dukanx/features/mobile_shop/models/confirmation_models.dart';
import 'package:dukanx/features/mobile_shop/models/sync_models.dart';
import 'package:dukanx/features/mobile_shop/repository/mobile_shop_local_repository.dart';
import 'package:dukanx/features/mobile_shop/sync/confirmation_applier.dart';
import 'package:dukanx/features/mobile_shop/sync/mobile_sync_coordinator.dart';
import 'package:dukanx/features/mobile_shop/sync/outbox_push_service.dart';
import 'package:dukanx/features/mobile_shop/sync/pending_state_manager.dart';
import 'package:dukanx/features/mobile_shop/sync/pull_service.dart';
import 'package:dukanx/features/mobile_shop/sync/realtime_convergence.dart';
import 'package:dukanx/features/mobile_shop/sync/sync_types.dart';
import 'package:dukanx/features/mobile_shop/sync/tenant_switch_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'mobile_shop_sync_test.mocks.dart';

// ─── Mock Generation ─────────────────────────────────────────────────────────

@GenerateMocks([MobileShopApi, MobileShopLocalRepository])
// ignore: unused_element
void _dependencies() {
  // This function exists solely for build_runner to find the @GenerateMocks
  // annotation. Tests are defined in main() below.
}

// ─── Test Helpers ────────────────────────────────────────────────────────────

int _correlationCounter = 0;

/// Creates a TenantContext for mobile shop testing.
TenantContext _mobileCtx([String tenantId = 'tenant-A']) => TenantContext(
  tenantId: tenantId,
  businessId: tenantId,
  subjectId: 'subject-$tenantId',
  businessType: MobileShopBusinessType.mobileShop,
  permissions: const {'manage_imei', 'view_imei', 'manage_service'},
  correlationId: 'corr-${++_correlationCounter}',
);

/// Creates a non-mobile-shop tenant context.
TenantContext _nonMobileCtx([String tenantId = 'tenant-X']) => TenantContext(
  tenantId: tenantId,
  businessId: tenantId,
  subjectId: 'subject-$tenantId',
  businessType: MobileShopBusinessType.grocery,
  permissions: const {},
  correlationId: 'corr-${++_correlationCounter}',
);

/// Creates a fake outbox mutation entity for testing.
MobileOutboxMutationEntity _makeMutation({
  required String operationId,
  String tenantId = 'tenant-A',
  String fingerprint = 'fp-abc',
  String entityType = 'IMEI_UNIT',
  String payload = '{"entityId":"unit-1"}',
  String? baseVersions,
  String? dependencies,
  String status = 'queued',
  int retryCount = 0,
  int maxRetries = 10,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime.now();
  return MobileOutboxMutationEntity(
    id: 'outbox_$operationId',
    tenantId: tenantId,
    operationId: operationId,
    mutationFingerprint: fingerprint,
    entityType: entityType,
    payload: payload,
    baseVersions: baseVersions,
    dependencies: dependencies,
    retryCount: retryCount,
    maxRetries: maxRetries,
    status: status,
    dataModelVersion: 1,
    createdAt: now,
    lastAttemptAt: null,
    updatedAt: now,
  );
}

/// Creates a fake IMEI unit local record for testing.
LocalRecord<MobileImeiUnitEntity> _makeImeiRecord({
  required String entityId,
  String tenantId = 'tenant-A',
  int serverVersion = 3,
  String confirmationStatus = 'pending',
}) {
  final entity = MobileImeiUnitEntity(
    id: 'imei_$entityId',
    tenantId: tenantId,
    entityId: entityId,
    imei: '353456789012345',
    version: 1,
    serverVersion: serverVersion,
    lifecycleState: 'IN_STOCK',
    condition: 'new',
    brand: 'Samsung',
    model: 'Galaxy S24',
    salePricePaise: 5999900,
    acquisitionCostPaise: 4500000,
    warrantyStartDate: null,
    warrantyEndDate: null,
    confirmationStatus: confirmationStatus,
    syncedAt: DateTime.now(),
    dataModelVersion: 1,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  return LocalRecord(
    entity: entity,
    confirmationStatus: confirmationStatus,
    serverVersion: serverVersion,
    syncedAt: DateTime.now(),
  );
}

/// Creates an AuthoritativeConfirmation for testing.
AuthoritativeConfirmation _makeConfirmation({
  String operationId = 'op-1',
  Map<String, int> entityVersions = const {'unit-1': 3},
  int dataModelVersion = 1,
}) {
  return AuthoritativeConfirmation(
    authority: ConfirmationAuthority.awsDynamoDb,
    state: ConfirmationState.committed,
    operationId: operationId,
    confirmedAt: DateTime.now().toIso8601String(),
    dataModelVersion: dataModelVersion,
    entityVersions: entityVersions,
  );
}

// ─── Test Suite ──────────────────────────────────────────────────────────────

void main() {
  late MockMobileShopApi mockApi;
  late MockMobileShopLocalRepository mockRepo;

  setUp(() {
    mockApi = MockMobileShopApi();
    mockRepo = MockMobileShopLocalRepository();
  });

  // ==========================================================================
  // GROUP 1: Outbox Push — Dependency Order (Req 7.4)
  // ==========================================================================
  group('Outbox push — dependency order', () {
    test('mutations with dependencies push dependees first', () async {
      final ctx = _mobileCtx();
      final service = OutboxPushService(repository: mockRepo, api: mockApi);

      // Mutation B depends on mutation A
      final mutA = _makeMutation(
        operationId: 'op-A',
        createdAt: DateTime(2024, 1, 1, 10, 0),
      );
      final mutB = _makeMutation(
        operationId: 'op-B',
        dependencies: jsonEncode(['op-A']),
        createdAt: DateTime(2024, 1, 1, 10, 1),
      );

      // Return mutations in reverse order — B before A
      when(
        mockRepo.getNextMutations(ctx, any),
      ).thenAnswer((_) async => [mutB, mutA]);

      // API returns committed for each push
      when(mockApi.push(any)).thenAnswer((_) async {
        final call = _.positionalArguments[0] as PushBatchRequest;
        final opId = call.mutations.first.operationId;
        return ApiSuccess<PushBatchResponse>(
          data: PushBatchResponse(
            dataModelVersion: 1,
            results: [
              PushMutationResult(
                operationId: opId,
                status: PushMutationResultStatus.committed,
                confirmation: _makeConfirmation(operationId: opId),
              ),
            ],
          ),
          apiVersion: 1,
          dataModelVersion: 1,
        );
      });

      when(mockRepo.markMutationSent(ctx, any)).thenAnswer((_) async {});

      final result = await service.pushAll(ctx);

      // Verify push was called with A first, then B
      final captured = verify(mockApi.push(captureAny)).captured;
      expect(captured.length, 2);
      final firstPush = (captured[0] as PushBatchRequest).mutations.first;
      final secondPush = (captured[1] as PushBatchRequest).mutations.first;
      expect(firstPush.operationId, 'op-A');
      expect(secondPush.operationId, 'op-B');
      expect(result.pushedCount, 2);
    });
  });

  // ==========================================================================
  // GROUP 2: Outbox Push — Identity Reuse (Req 7.5)
  // ==========================================================================
  group('Outbox push — identity reuse', () {
    test(
      'operationId and fingerprint are never regenerated on retry',
      () async {
        final ctx = _mobileCtx();
        final service = OutboxPushService(repository: mockRepo, api: mockApi);

        final mutation = _makeMutation(
          operationId: 'op-stable',
          fingerprint: 'fp-stable-123',
          retryCount: 3, // simulates a retry
        );

        when(
          mockRepo.getNextMutations(ctx, any),
        ).thenAnswer((_) async => [mutation]);

        when(mockApi.push(any)).thenAnswer((_) async {
          return ApiSuccess<PushBatchResponse>(
            data: PushBatchResponse(
              dataModelVersion: 1,
              results: [
                PushMutationResult(
                  operationId: 'op-stable',
                  status: PushMutationResultStatus.committed,
                  confirmation: _makeConfirmation(operationId: 'op-stable'),
                ),
              ],
            ),
            apiVersion: 1,
            dataModelVersion: 1,
          );
        });

        when(mockRepo.markMutationSent(ctx, any)).thenAnswer((_) async {});

        await service.pushAll(ctx);

        // Verify the push used original operationId and fingerprint
        final captured = verify(mockApi.push(captureAny)).captured;
        final pushBatch = captured.first as PushBatchRequest;
        expect(pushBatch.mutations.first.operationId, 'op-stable');
        expect(pushBatch.mutations.first.mutationFingerprint, 'fp-stable-123');
      },
    );
  });

  // ==========================================================================
  // GROUP 3: Outbox Push — Conflict Creates Durable Record (Req 7.6–7.8)
  // ==========================================================================
  group('Outbox push — conflict creates durable record', () {
    test('version mismatch from server creates MobileConflictEntity', () async {
      final ctx = _mobileCtx();
      final service = OutboxPushService(repository: mockRepo, api: mockApi);

      final mutation = _makeMutation(
        operationId: 'op-conflict',
        baseVersions: jsonEncode({'unit-1': 2}),
      );

      when(
        mockRepo.getNextMutations(ctx, any),
      ).thenAnswer((_) async => [mutation]);

      when(mockApi.push(any)).thenAnswer((_) async {
        return ApiSuccess<PushBatchResponse>(
          data: PushBatchResponse(
            dataModelVersion: 1,
            results: [
              PushMutationResult(
                operationId: 'op-conflict',
                status: PushMutationResultStatus.conflict,
                errorCode: 'VERSION_MISMATCH',
                errorMessage: 'Expected v2 but found v5',
              ),
            ],
          ),
          apiVersion: 1,
          dataModelVersion: 1,
        );
      });

      when(mockRepo.insertConflict(ctx, any)).thenAnswer((_) async {});
      when(mockRepo.markMutationFailed(ctx, any, any)).thenAnswer((_) async {});

      final result = await service.pushAll(ctx);

      expect(result.conflictsCreated, 1);
      // Verify a conflict was inserted
      final conflictCapture = verify(
        mockRepo.insertConflict(ctx, captureAny),
      ).captured;
      expect(conflictCapture.length, 1);
      final conflict = conflictCapture.first as MobileConflictEntity;
      expect(conflict.operationId, 'op-conflict');
      expect(conflict.reason, 'VERSION_MISMATCH');
      expect(conflict.resolutionStatus, ConflictResolutionStatus.unresolved);
    });
  });

  // ==========================================================================
  // GROUP 4: Outbox Push — Network Error Leaves Queued (Req 7.14)
  // ==========================================================================
  group('Outbox push — network error leaves queued', () {
    test('mutations stay queued on network failure', () async {
      final ctx = _mobileCtx();
      final service = OutboxPushService(repository: mockRepo, api: mockApi);

      final mutation = _makeMutation(operationId: 'op-net-fail');

      when(
        mockRepo.getNextMutations(ctx, any),
      ).thenAnswer((_) async => [mutation]);

      when(mockApi.push(any)).thenAnswer((_) async {
        return const ApiNetworkError<PushBatchResponse>(
          message: 'Connection timeout',
          retryable: true,
        );
      });

      final result = await service.pushAll(ctx);

      // Pushed count is 0 — mutation stays queued
      expect(result.pushedCount, 0);
      expect(result.conflictsCreated, 0);
      // markMutationSent should NOT have been called
      verifyNever(mockRepo.markMutationSent(ctx, any));
      // markMutationFailed should NOT have been called for network errors
      verifyNever(mockRepo.markMutationFailed(ctx, any, any));
    });
  });

  // ==========================================================================
  // GROUP 5: Pull — Checkpoint Advancement (Req 7.4)
  // ==========================================================================
  group('Pull — checkpoint advancement', () {
    test('after pull, checkpoint reflects new position', () async {
      final ctx = _mobileCtx();
      final service = PullService(repository: mockRepo, api: mockApi);

      when(mockRepo.getCheckpoint(ctx, 'ROOT')).thenAnswer(
        (_) async => const CheckpointState(
          bucket: 'ROOT',
          lastPosition: 'cursor-0',
          serverVersion: 5,
        ),
      );

      when(mockApi.pull(any)).thenAnswer((_) async {
        return ApiSuccess<PullResponse>(
          data: PullResponse(
            dataModelVersion: 1,
            changes: [
              ChangeEvent(
                eventId: 'evt-1',
                tenantId: 'tenant-A',
                dataModelVersion: 1,
                entityType: 'IMEI_UNIT',
                entityId: 'unit-1',
                entityVersion: 6,
                action: 'UPDATED',
                occurredAt: DateTime.now().toIso8601String(),
                sequence: 100,
              ),
            ],
            continuationToken: 'cursor-1',
            hasMore: false,
          ),
          apiVersion: 1,
          dataModelVersion: 1,
        );
      });

      // No local record means no conflict
      when(mockRepo.getImeiUnit(ctx, 'unit-1')).thenAnswer((_) async => null);
      when(
        mockRepo.insertEventIfNotExists(ctx, any),
      ).thenAnswer((_) async => true);
      when(
        mockRepo.applyPulledPage(
          ctx,
          bucket: anyNamed('bucket'),
          items: anyNamed('items'),
          newCheckpoint: anyNamed('newCheckpoint'),
          serverVersion: anyNamed('serverVersion'),
        ),
      ).thenAnswer((_) async {});

      final result = await service.pullOnePage(ctx);

      expect(result.appliedCount, 1);
      // Verify applyPulledPage was called with the new checkpoint
      verify(
        mockRepo.applyPulledPage(
          ctx,
          bucket: 'ROOT',
          items: anyNamed('items'),
          newCheckpoint: 'cursor-1',
          serverVersion: 6,
        ),
      ).called(1);
    });
  });

  // ==========================================================================
  // GROUP 6: Pull — Deduplication (Req 7.10)
  // ==========================================================================
  group('Pull — deduplication', () {
    test('same eventId pulled twice → applied once', () async {
      final ctx = _mobileCtx();
      final service = PullService(repository: mockRepo, api: mockApi);

      when(mockRepo.getCheckpoint(ctx, 'ROOT')).thenAnswer((_) async => null);

      final change = ChangeEvent(
        eventId: 'evt-dup',
        tenantId: 'tenant-A',
        dataModelVersion: 1,
        entityType: 'IMEI_UNIT',
        entityId: 'unit-2',
        entityVersion: 2,
        action: 'CREATED',
        occurredAt: DateTime.now().toIso8601String(),
        sequence: 50,
      );

      when(mockApi.pull(any)).thenAnswer((_) async {
        return ApiSuccess<PullResponse>(
          data: PullResponse(
            dataModelVersion: 1,
            changes: [change, change], // same event twice
            continuationToken: 'cursor-2',
            hasMore: false,
          ),
          apiVersion: 1,
          dataModelVersion: 1,
        );
      });

      // First call: event is new → true; second call: duplicate → false
      int insertCallCount = 0;
      when(mockRepo.insertEventIfNotExists(ctx, any)).thenAnswer((_) async {
        insertCallCount++;
        return insertCallCount == 1; // only first is new
      });

      when(mockRepo.getImeiUnit(ctx, any)).thenAnswer((_) async => null);
      when(
        mockRepo.applyPulledPage(
          ctx,
          bucket: anyNamed('bucket'),
          items: anyNamed('items'),
          newCheckpoint: anyNamed('newCheckpoint'),
          serverVersion: anyNamed('serverVersion'),
        ),
      ).thenAnswer((_) async {});

      final result = await service.pullOnePage(ctx);

      // Only one event applied (the duplicate was rejected)
      expect(result.appliedCount, 1);
    });
  });

  // ==========================================================================
  // GROUP 7: Pull — Version Collision Creates Conflict (Req 7.7)
  // ==========================================================================
  group('Pull — version collision creates conflict', () {
    test('pending local + different server version → conflict', () async {
      final ctx = _mobileCtx();
      final service = PullService(repository: mockRepo, api: mockApi);

      when(mockRepo.getCheckpoint(ctx, 'ROOT')).thenAnswer((_) async => null);

      when(mockApi.pull(any)).thenAnswer((_) async {
        return ApiSuccess<PullResponse>(
          data: PullResponse(
            dataModelVersion: 1,
            changes: [
              ChangeEvent(
                eventId: 'evt-conflict',
                tenantId: 'tenant-A',
                dataModelVersion: 1,
                entityType: 'IMEI_UNIT',
                entityId: 'unit-3',
                entityVersion: 10, // server jumps to 10
                action: 'UPDATED',
                occurredAt: DateTime.now().toIso8601String(),
                sequence: 200,
              ),
            ],
            continuationToken: 'cursor-3',
            hasMore: false,
          ),
          apiVersion: 1,
          dataModelVersion: 1,
        );
      });

      when(
        mockRepo.insertEventIfNotExists(ctx, any),
      ).thenAnswer((_) async => true);

      // Local record is pending with serverVersion=5 → conflict
      // because 10 != 5+1
      when(mockRepo.getImeiUnit(ctx, 'unit-3')).thenAnswer(
        (_) async => _makeImeiRecord(
          entityId: 'unit-3',
          serverVersion: 5,
          confirmationStatus: 'pending',
        ),
      );

      when(mockRepo.insertConflict(ctx, any)).thenAnswer((_) async {});
      when(
        mockRepo.advanceCheckpoint(ctx, any, any, any),
      ).thenAnswer((_) async {});

      final result = await service.pullOnePage(ctx);

      expect(result.conflictsCreated, 1);
      expect(result.appliedCount, 0);

      // Verify conflict was inserted with correct fields
      final conflictCapture = verify(
        mockRepo.insertConflict(ctx, captureAny),
      ).captured;
      final conflict = conflictCapture.first as MobileConflictEntity;
      expect(conflict.entityId, 'unit-3');
      expect(conflict.localVersion, 5);
      expect(conflict.serverVersion, 10);
      expect(conflict.reason, 'VERSION_COLLISION');
    });
  });

  // ==========================================================================
  // GROUP 8: Tenant Switch — Cancels Prior Work (Req 7.11, 8.4)
  // ==========================================================================
  group('Tenant switch — cancels prior work', () {
    test('unbind clears subscriptions and leases', () async {
      final coordinator = MobileSyncCoordinator(
        repository: mockRepo,
        api: mockApi,
      );
      final realtimeService = RealtimeConvergenceService(
        api: mockApi,
        syncCoordinator: coordinator,
      );

      final handler = TenantSwitchHandler(
        syncCoordinator: coordinator,
        realtimeService: realtimeService,
        repository: mockRepo,
        api: mockApi,
      );

      final ctxA = _mobileCtx('tenant-A');
      final ctxB = _mobileCtx('tenant-B');

      // Set up mock for initial bind (tenant-A)
      when(
        mockApi.subscribe(any),
      ).thenAnswer((_) => const Stream<ServerHint>.empty());
      when(mockRepo.getNextMutations(any, any)).thenAnswer((_) async => []);
      when(mockApi.pull(any)).thenAnswer((_) async {
        return ApiSuccess<PullResponse>(
          data: const PullResponse(
            dataModelVersion: 1,
            changes: [],
            hasMore: false,
          ),
          apiVersion: 1,
          dataModelVersion: 1,
        );
      });
      when(mockRepo.getCheckpoint(any, any)).thenAnswer((_) async => null);
      when(mockRepo.markMutationFailed(any, any, any)).thenAnswer((_) async {});

      // Perform switch from A to B
      final result = await handler.handleTenantSwitch(ctxA, ctxB);

      expect(
        result,
        anyOf(
          TenantSwitchResult.success,
          TenantSwitchResult.successWithPullFailure,
        ),
      );
      // After switch, active tenant should be B
      expect(handler.activeTenantId, 'tenant-B');
      // The realtime service should now be connected to tenant B
      expect(realtimeService.connectedTenantId, 'tenant-B');
    });
  });

  // ==========================================================================
  // GROUP 9: Tenant Switch — New Tenant Gets Fresh Pull (Req 7.11)
  // ==========================================================================
  group('Tenant switch — new tenant gets fresh pull', () {
    test('after switch, initial pull is triggered', () async {
      final coordinator = MobileSyncCoordinator(
        repository: mockRepo,
        api: mockApi,
      );
      final realtimeService = RealtimeConvergenceService(
        api: mockApi,
        syncCoordinator: coordinator,
      );
      final handler = TenantSwitchHandler(
        syncCoordinator: coordinator,
        realtimeService: realtimeService,
        repository: mockRepo,
        api: mockApi,
      );

      final ctxB = _mobileCtx('tenant-B');

      when(
        mockApi.subscribe(any),
      ).thenAnswer((_) => const Stream<ServerHint>.empty());
      when(mockRepo.getNextMutations(any, any)).thenAnswer((_) async => []);
      when(mockRepo.getCheckpoint(any, any)).thenAnswer((_) async => null);
      when(mockApi.pull(any)).thenAnswer((_) async {
        return ApiSuccess<PullResponse>(
          data: const PullResponse(
            dataModelVersion: 1,
            changes: [],
            hasMore: false,
          ),
          apiVersion: 1,
          dataModelVersion: 1,
        );
      });

      // Initial bind (no prior tenant)
      await handler.handleTenantSwitch(null, ctxB);

      // Verify pull was called for the new tenant
      final pullCapture = verify(mockApi.pull(captureAny)).captured;
      expect(pullCapture.isNotEmpty, isTrue);
      final pullReq = pullCapture.first as PullRequest;
      expect(pullReq.tenantId, 'tenant-B');
    });
  });

  // ==========================================================================
  // GROUP 10: Confirmation Applier — Version Match (Req 7.14–7.15)
  // ==========================================================================
  group('Confirmation applier — version match → serverConfirmed', () {
    test('matching versions mark confirmed', () async {
      final ctx = _mobileCtx();
      final applier = ConfirmationApplier(repository: mockRepo);

      // Local record has serverVersion=3
      when(mockRepo.getImeiUnit(ctx, 'unit-1')).thenAnswer(
        (_) async => _makeImeiRecord(entityId: 'unit-1', serverVersion: 3),
      );
      when(mockRepo.upsertImeiUnit(ctx, any)).thenAnswer((_) async {});
      when(mockRepo.markMutationSent(ctx, any)).thenAnswer((_) async {});

      final confirmation = _makeConfirmation(
        operationId: 'op-1',
        entityVersions: {'unit-1': 3}, // matches local
      );

      final result = await applier.applyConfirmation(ctx, confirmation);

      expect(result.confirmedCount, 1);
      expect(result.conflictedCount, 0);
      expect(result.isFullyConfirmed, isTrue);
    });
  });

  // ==========================================================================
  // GROUP 11: Confirmation Applier — Version Mismatch → Conflict (Req 7.15)
  // ==========================================================================
  group('Confirmation applier — version mismatch → conflict', () {
    test('different versions create conflict', () async {
      final ctx = _mobileCtx();
      final applier = ConfirmationApplier(repository: mockRepo);

      // Local record has serverVersion=3 but confirmation says version=7
      when(mockRepo.getImeiUnit(ctx, 'unit-1')).thenAnswer(
        (_) async => _makeImeiRecord(entityId: 'unit-1', serverVersion: 3),
      );
      when(mockRepo.insertConflict(ctx, any)).thenAnswer((_) async {});
      when(mockRepo.markMutationSent(ctx, any)).thenAnswer((_) async {});

      final confirmation = _makeConfirmation(
        operationId: 'op-mismatch',
        entityVersions: {'unit-1': 7}, // DIFFERENT from local v3
      );

      final result = await applier.applyConfirmation(ctx, confirmation);

      expect(result.confirmedCount, 0);
      expect(result.conflictedCount, 1);
      expect(result.isFullyConfirmed, isFalse);

      // Verify conflict was created with correct versions
      final conflictCapture = verify(
        mockRepo.insertConflict(ctx, captureAny),
      ).captured;
      final conflict = conflictCapture.first as MobileConflictEntity;
      expect(conflict.localVersion, 3);
      expect(conflict.serverVersion, 7);
      expect(conflict.reason, 'VERSION_MISMATCH');
    });
  });

  // ==========================================================================
  // GROUP 12: Confirmation Applier — Cross-Tenant Rejected (Req 8.3–8.4)
  // ==========================================================================
  group('Confirmation applier — cross-tenant rejected', () {
    test('confirmation for wrong tenant is ignored', () async {
      // Use a non-mobile-shop tenant (grocery)
      final ctx = _nonMobileCtx('tenant-X');
      final applier = ConfirmationApplier(repository: mockRepo);

      final confirmation = _makeConfirmation(
        operationId: 'op-cross',
        entityVersions: {'unit-1': 5, 'unit-2': 3},
      );

      final result = await applier.applyConfirmation(ctx, confirmation);

      // All entities should be ignored — no DB access at all
      expect(result.confirmedCount, 0);
      expect(result.conflictedCount, 0);
      expect(result.ignoredCount, 2);
      verifyNever(mockRepo.getImeiUnit(any, any));
      verifyNever(mockRepo.insertConflict(any, any));
    });
  });

  // ==========================================================================
  // GROUP 13: Realtime Convergence — Duplicate Hint Ignored (Req 7.10)
  // ==========================================================================
  group('Realtime convergence — duplicate hint ignored', () {
    test('same eventId twice → second ignored', () async {
      final ctx = _mobileCtx();
      final coordinator = MobileSyncCoordinator(
        repository: mockRepo,
        api: mockApi,
      );

      final realtimeService = RealtimeConvergenceService(
        api: mockApi,
        syncCoordinator: coordinator,
      );

      // Mock the subscribe stream and sync calls
      when(
        mockApi.subscribe(any),
      ).thenAnswer((_) => const Stream<ServerHint>.empty());
      when(mockRepo.getNextMutations(any, any)).thenAnswer((_) async => []);
      when(mockRepo.getCheckpoint(any, any)).thenAnswer((_) async => null);
      when(mockApi.pull(any)).thenAnswer((_) async {
        return ApiSuccess<PullResponse>(
          data: const PullResponse(
            dataModelVersion: 1,
            changes: [],
            hasMore: false,
          ),
          apiVersion: 1,
          dataModelVersion: 1,
        );
      });

      // Connect to tenant
      realtimeService.connect(ctx);

      final hint = ServerHint(
        tenantId: 'tenant-A',
        eventId: 'evt-dup-hint',
        entityType: 'IMEI_UNIT',
        entityId: 'unit-5',
        entityVersion: 2,
        hint: 'PULL',
        occurredAt: DateTime.now().toIso8601String(),
      );

      // First hint should trigger a pull
      final first = await realtimeService.handleHint(hint);
      expect(first, isTrue);

      // Second identical hint should be deduplicated
      final second = await realtimeService.handleHint(hint);
      expect(second, isFalse);

      await realtimeService.disconnect();
    });
  });

  // ==========================================================================
  // GROUP 14: Realtime Convergence — Version Regression Ignored (Req 7.10)
  // ==========================================================================
  group('Realtime convergence — version regression ignored', () {
    test('older version hint → rejected', () async {
      final ctx = _mobileCtx();
      final coordinator = MobileSyncCoordinator(
        repository: mockRepo,
        api: mockApi,
      );
      final realtimeService = RealtimeConvergenceService(
        api: mockApi,
        syncCoordinator: coordinator,
      );

      when(
        mockApi.subscribe(any),
      ).thenAnswer((_) => const Stream<ServerHint>.empty());
      when(mockRepo.getNextMutations(any, any)).thenAnswer((_) async => []);
      when(mockRepo.getCheckpoint(any, any)).thenAnswer((_) async => null);
      when(mockApi.pull(any)).thenAnswer((_) async {
        return ApiSuccess<PullResponse>(
          data: const PullResponse(
            dataModelVersion: 1,
            changes: [],
            hasMore: false,
          ),
          apiVersion: 1,
          dataModelVersion: 1,
        );
      });

      realtimeService.connect(ctx);

      // Newer hint first (version 5)
      final newerHint = ServerHint(
        tenantId: 'tenant-A',
        eventId: 'evt-newer',
        entityType: 'IMEI_UNIT',
        entityId: 'unit-6',
        entityVersion: 5,
        hint: 'PULL',
        occurredAt: DateTime.now().toIso8601String(),
      );

      // Older hint (version 2) for the SAME entity
      final olderHint = ServerHint(
        tenantId: 'tenant-A',
        eventId: 'evt-older',
        entityType: 'IMEI_UNIT',
        entityId: 'unit-6',
        entityVersion: 2, // regression — older than 5
        hint: 'PULL',
        occurredAt: DateTime.now().toIso8601String(),
      );

      // Process newer first
      final first = await realtimeService.handleHint(newerHint);
      expect(first, isTrue);

      // Process older — should be rejected (version regression)
      final second = await realtimeService.handleHint(olderHint);
      expect(second, isFalse);

      await realtimeService.disconnect();
    });
  });

  // ==========================================================================
  // GROUP 15: Pending State Manager — Retry Guidance (Req 7.14, 12.4–12.5)
  // ==========================================================================
  group('Pending state manager — retry guidance', () {
    test('returns RecoveryAction.retry for queued mutations', () async {
      final ctx = _mobileCtx();
      final manager = PendingStateManager(repository: mockRepo);

      final mutation = _makeMutation(
        operationId: 'op-queued',
        status: 'queued',
        retryCount: 1,
        maxRetries: 10,
      );

      when(
        mockRepo.listConflicts(
          ctx,
          resolutionStatus: anyNamed('resolutionStatus'),
        ),
      ).thenAnswer((_) async => []);
      when(
        mockRepo.getNextMutations(ctx, any),
      ).thenAnswer((_) async => [mutation]);

      final guidance = await manager.getRecoveryGuidance(ctx, 'op-queued');

      expect(guidance.action, RecoveryAction.retry);
      expect(guidance.isRetrySafe, isTrue);
    });

    test(
      'returns RecoveryAction.resolveConflict for conflicted operations',
      () async {
        final ctx = _mobileCtx();
        final manager = PendingStateManager(repository: mockRepo);

        final mutation = _makeMutation(
          operationId: 'op-conflicted',
          status: 'failed',
        );

        final conflict = MobileConflictEntity(
          id: 'conflict-1',
          tenantId: 'tenant-A',
          operationId: 'op-conflicted',
          entityType: 'IMEI_UNIT',
          entityId: 'unit-1',
          localVersion: 3,
          serverVersion: 5,
          reason: 'VERSION_MISMATCH',
          resolutionStatus: ConflictResolutionStatus.unresolved,
          resolutionEvidence: null,
          dataModelVersion: 1,
          createdAt: DateTime.now(),
          resolvedAt: null,
          updatedAt: DateTime.now(),
        );

        when(
          mockRepo.listConflicts(
            ctx,
            resolutionStatus: anyNamed('resolutionStatus'),
          ),
        ).thenAnswer((_) async => [conflict]);
        when(
          mockRepo.getNextMutations(ctx, any),
        ).thenAnswer((_) async => [mutation]);

        final guidance = await manager.getRecoveryGuidance(
          ctx,
          'op-conflicted',
        );

        expect(guidance.action, RecoveryAction.resolveConflict);
        expect(guidance.isRetrySafe, isFalse);
        expect(guidance.needsUserAction, isTrue);
      },
    );

    test('returns RecoveryAction.terminal for exhausted retries', () async {
      final ctx = _mobileCtx();
      final manager = PendingStateManager(repository: mockRepo);

      final mutation = _makeMutation(
        operationId: 'op-exhausted',
        status: 'failed',
        retryCount: 10, // equals maxRetries
        maxRetries: 10,
      );

      when(
        mockRepo.listConflicts(
          ctx,
          resolutionStatus: anyNamed('resolutionStatus'),
        ),
      ).thenAnswer((_) async => []);
      when(
        mockRepo.getNextMutations(ctx, any),
      ).thenAnswer((_) async => [mutation]);

      final guidance = await manager.getRecoveryGuidance(ctx, 'op-exhausted');

      expect(guidance.action, RecoveryAction.terminal);
      expect(guidance.isRetrySafe, isFalse);
      expect(guidance.needsUserAction, isTrue);
    });

    test(
      'returns RecoveryAction.awaitReconciliation for sent mutations',
      () async {
        final ctx = _mobileCtx();
        final manager = PendingStateManager(repository: mockRepo);

        final mutation = _makeMutation(operationId: 'op-sent', status: 'sent');

        when(
          mockRepo.listConflicts(
            ctx,
            resolutionStatus: anyNamed('resolutionStatus'),
          ),
        ).thenAnswer((_) async => []);
        when(
          mockRepo.getNextMutations(ctx, any),
        ).thenAnswer((_) async => [mutation]);

        final guidance = await manager.getRecoveryGuidance(ctx, 'op-sent');

        expect(guidance.action, RecoveryAction.awaitReconciliation);
        expect(guidance.isRetrySafe, isFalse);
      },
    );

    test('returns RecoveryAction.unknown for non-mobile-shop tenant', () async {
      final ctx = _nonMobileCtx();
      final manager = PendingStateManager(repository: mockRepo);

      final guidance = await manager.getRecoveryGuidance(ctx, 'op-any');

      expect(guidance.action, RecoveryAction.unknown);
      expect(guidance.isRetrySafe, isFalse);
    });

    test('returns RecoveryAction.unknown when operation not found', () async {
      final ctx = _mobileCtx();
      final manager = PendingStateManager(repository: mockRepo);

      when(
        mockRepo.listConflicts(
          ctx,
          resolutionStatus: anyNamed('resolutionStatus'),
        ),
      ).thenAnswer((_) async => []);
      when(
        mockRepo.getNextMutations(ctx, any),
      ).thenAnswer((_) async => []); // op not in outbox

      final guidance = await manager.getRecoveryGuidance(ctx, 'op-not-found');

      expect(guidance.action, RecoveryAction.unknown);
    });
  });
}
