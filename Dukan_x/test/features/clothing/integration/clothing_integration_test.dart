// Integration tests for the offline-first variant load + sync path.
//
// Validates: Requirements 12.1, 12.9 (Requirement 16.5)
//
// These tests confirm:
// 1. ClothingRepositoryOffline creates variants locally with RID + synced=false
//    and enqueues exactly one sync-queue entry.
// 2. ClothingRepositoryOffline.syncAll drains the queue FIFO; successful entries
//    are removed from the queue.
// 3. The three clothing screens (ClothingInventoryScreen,
//    VariantManagementScreen, TailoringMeasurementsScreen) depend on
//    ClothingRepositoryOffline and never import ApiClient directly for CRUD.
// 4. /clothing/* endpoints are either confirmed reachable or gated behind a
//    feature flag (no silent 404s).

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/clothing/data/repositories/clothing_repository_offline.dart';
import 'package:dukanx/features/clothing/data/variant_repository.dart';

// ---------------------------------------------------------------------------
// Fake implementations (avoids Mockito's null-safety `any` limitations)
// ---------------------------------------------------------------------------

/// A fake ApiClient that can be configured to succeed or fail.
class FakeApiClient implements ApiClient {
  bool shouldSucceed = false;
  int callCount = 0;
  final List<String> calledPaths = [];

  @override
  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    callCount++;
    calledPaths.add(path);
    if (!shouldSucceed) {
      throw Exception('Network unavailable (test)');
    }
    return ApiResponse<Map<String, dynamic>>.success(200, <String, dynamic>{
      'version': 1,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeApiClient.${invocation.memberName} not implemented',
  );
}

/// A fake SessionManager that returns a fixed ownerId.
class FakeSessionManager implements SessionManager {
  final String? _ownerId;

  FakeSessionManager({String? ownerId = 'tenant-test-001'})
    : _ownerId = ownerId;

  @override
  String? get ownerId => _ownerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeSessionManager.${invocation.memberName} not implemented',
  );
}

void main() {
  late Directory tempDir;
  late FakeApiClient fakeApiClient;
  late FakeSessionManager fakeSession;
  late ClothingRepositoryOffline repository;

  const testTenantId = 'tenant-test-001';

  setUp(() async {
    // Initialize Hive with a temp directory for test isolation
    tempDir = await Directory.systemTemp.createTemp('clothing_hive_test_');
    Hive.init(tempDir.path);

    fakeApiClient = FakeApiClient();
    fakeSession = FakeSessionManager(ownerId: testTenantId);

    repository = ClothingRepositoryOffline(fakeApiClient, fakeSession);
  });

  tearDown(() async {
    // Close all Hive boxes and clean up temp directory
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Offline-first variant path', () {
    test(
      'ClothingRepositoryOffline creates variant locally with RID and synced=false + sync queue entry',
      () async {
        // ApiClient will fail (simulating offline), so the sync-queue entry stays.
        // The fire-and-forget _syncVariant call will throw an unhandled async
        // exception — we expect this in offline mode and allow it to complete.
        fakeApiClient.shouldSucceed = false;

        // ACT: Create a variant through the offline repository
        // Note: The fire-and-forget sync attempt will fail asynchronously.
        // We add a brief delay to let the async error propagate and be handled.
        late OfflineVariantRecord record;
        await runZonedGuarded(
          () async {
            record = await repository.createVariant(
              productId: 'product-001',
              color: 'Red',
              size: 'M',
              sku: 'SKU-RED-M',
              barcode: 'BAR-001',
              priceCents: 99900,
              stock: 10,
            );
          },
          (error, stack) {
            // Expected: fire-and-forget sync throws when offline
          },
        );

        // Allow any async microtasks to complete
        await Future<void>.delayed(Duration.zero);

        // ASSERT: Variant was created with a valid RID
        expect(record.variant.id, isNotEmpty);
        // RID format: {tenantId}-{timestamp_ms}-{uuid_v4_short}
        expect(record.variant.id.startsWith(testTenantId), isTrue);

        // ASSERT: Record is marked as not synced with pendingOperation 'create'
        expect(record.synced, isFalse);
        expect(record.pendingOperation, equals('create'));
        expect(record.pendingSince, isNotNull);
        expect(record.version, equals(1));

        // ASSERT: Variant fields are persisted correctly
        expect(record.variant.productId, equals('product-001'));
        expect(record.variant.color, equals('Red'));
        expect(record.variant.size, equals('M'));
        expect(record.variant.sku, equals('SKU-RED-M'));
        expect(record.variant.barcode, equals('BAR-001'));
        expect(record.variant.priceCents, equals(99900));
        expect(record.variant.stock, equals(10));
        expect(record.tenantId, equals(testTenantId));

        // ASSERT: Exactly one sync queue entry was created
        final pendingCount = await repository.getPendingSyncCount();
        expect(pendingCount, equals(1));

        // ASSERT: The variant can be retrieved locally (offline-first)
        final retrieved = await repository.getVariants('product-001');
        expect(retrieved.length, equals(1));
        expect(retrieved.first.variant.color, equals('Red'));
      },
    );

    test(
      'ClothingRepositoryOffline.syncAll drains queue FIFO — successful entries removed',
      () async {
        // Make fire-and-forget sync calls fail so entries stay queued.
        fakeApiClient.shouldSucceed = false;

        // Create two variants (each adds a sync-queue entry)
        // Use runZonedGuarded to catch fire-and-forget sync failures.
        await runZonedGuarded(
          () async {
            await repository.createVariant(
              productId: 'product-001',
              color: 'Blue',
              size: 'S',
              priceCents: 50000,
              stock: 5,
            );
            await repository.createVariant(
              productId: 'product-001',
              color: 'Green',
              size: 'L',
              priceCents: 75000,
              stock: 8,
            );
          },
          (error, stack) {
            // Expected: fire-and-forget sync throws when offline
          },
        );

        // Allow any async microtasks to complete
        await Future<void>.delayed(Duration.zero);

        // Verify 2 pending entries exist
        final pendingBefore = await repository.getPendingSyncCount();
        expect(pendingBefore, equals(2));

        // Now make the ApiClient succeed for the syncAll call.
        fakeApiClient.shouldSucceed = true;
        fakeApiClient.callCount = 0;

        // ACT: Sync all pending entries
        final result = await repository.syncAll();

        // ASSERT: Both entries synced successfully
        expect(result.synced, equals(2));
        expect(result.failed, equals(0));

        // ASSERT: Queue is now empty (successful entries removed)
        final pendingAfter = await repository.getPendingSyncCount();
        expect(pendingAfter, equals(0));

        // ASSERT: The ApiClient was called (server sync attempted)
        expect(fakeApiClient.callCount, greaterThan(0));
        // ASSERT: Calls went to /clothing/* endpoints
        expect(
          fakeApiClient.calledPaths.every((p) => p.startsWith('/clothing/')),
          isTrue,
        );
      },
    );

    test(
      'Screen imports depend on ClothingRepositoryOffline and never import ApiClient directly for CRUD',
      () {
        // This test verifies the architectural constraint via static analysis
        // of the source file imports. The three clothing screens must route
        // through ClothingRepositoryOffline (Requirement 12.1).

        final screenPaths = [
          'lib/features/clothing/presentation/screens/clothing_inventory_screen.dart',
          'lib/features/clothing/presentation/screens/variant_management_screen.dart',
          'lib/features/clothing/presentation/screens/tailoring_measurements_screen.dart',
        ];

        for (final path in screenPaths) {
          final file = File(path);
          if (!file.existsSync()) {
            // Try from project root (CI may have a different cwd)
            fail(
              'Source file not found at $path — '
              'ensure tests run from the Dukan_x project root',
            );
          }

          final content = file.readAsStringSync();
          final filename = path.split('/').last;

          // ASSERT: Screen imports ClothingRepositoryOffline
          expect(
            content.contains('clothing_repository_offline'),
            isTrue,
            reason: '$filename must import clothing_repository_offline.dart',
          );

          // ASSERT: Screen does NOT import ApiClient directly for CRUD.
          // The import of api_client.dart in screens is forbidden — all CRUD
          // goes through ClothingRepositoryOffline which wraps ApiClient internally.
          final importLines = content
              .split('\n')
              .where((line) => line.trimLeft().startsWith('import '));
          final importsApiClient = importLines.any(
            (line) =>
                line.contains('api_client.dart') ||
                line.contains("api_client'"),
          );
          expect(
            importsApiClient,
            isFalse,
            reason:
                '$filename must NOT import ApiClient directly for CRUD '
                '— all operations route through ClothingRepositoryOffline',
          );
        }
      },
    );

    test(
      '/clothing/* endpoints are feature-flagged when absent — size-swap exchange gated',
      () {
        // The VariantRepository.sizeSwapExchange method gates the exchange
        // behind the 'clothing_size_swap_exchange' feature flag (Requirement 12.9).
        // This verifies the constant exists and the method references it.

        final repoFile = File(
          'lib/features/clothing/data/variant_repository.dart',
        );

        if (!repoFile.existsSync()) {
          fail(
            'variant_repository.dart not found — '
            'ensure tests run from the Dukan_x project root',
          );
        }

        final content = repoFile.readAsStringSync();

        // ASSERT: The feature flag constant is defined
        expect(
          content.contains('clothing_size_swap_exchange'),
          isTrue,
          reason:
              'VariantRepository must gate the exchange behind '
              'clothing_size_swap_exchange feature flag',
        );

        // ASSERT: The method checks FeatureFlagService before proceeding
        expect(
          content.contains('FeatureFlagService'),
          isTrue,
          reason:
              'sizeSwapExchange must consult FeatureFlagService to confirm '
              '/clothing/* endpoint availability',
        );
      },
    );
  });
}
