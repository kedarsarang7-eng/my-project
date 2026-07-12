// ============================================================================
// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// **Property 19: Bug Condition** — Concurrent KOT Status Updates Resolve
// Deterministically
//
// The `RestaurantSyncService` handles offline sync by queueing unsynced orders
// for upload to Firestore. However, it has NO deterministic conflict resolution
// for concurrent KOT status updates. When two devices update the same order's
// status concurrently (each with a distinct `updatedAt` timestamp), there is no
// logic to ensure the update with the later `updatedAt` always wins.
//
// The current `updateOrderStatus` in `FoodOrderRepository` simply writes the
// new status to the local Drift DB, overwriting whatever was there previously.
// The `SyncManager.resolveConflict` is a no-op placeholder (just a debugPrint).
// The `_syncOrders` method iterates unsynced orders and enqueues them — no
// timestamp comparison or last-write-wins reconciliation happens at any layer.
//
// This means the final status of a concurrently-updated order depends entirely
// on which update physically arrives last at the DB write layer — a
// non-deterministic, order-dependent outcome.
//
// This test asserts the POSITIVE expectation: that for any pair of concurrent
// status updates with distinct `updatedAt` timestamps applied to the same order,
// the reconciled final status is ALWAYS the one with the later `updatedAt`,
// regardless of arrival order.
//
// On UNFIXED code this FAILS because no such reconciliation logic exists.
//
// **Validates: Requirements 2.26**
// ============================================================================
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'Property 19: Bug Condition — Concurrent KOT Status Updates Resolve Deterministically',
    () {
      late String syncServiceSource;
      late String orderRepoSource;
      late String syncManagerSource;

      setUpAll(() {
        // Read restaurant_sync_service.dart
        final syncFile = File(
          'lib/features/restaurant/domain/services/restaurant_sync_service.dart',
        );
        expect(
          syncFile.existsSync(),
          isTrue,
          reason: 'restaurant_sync_service.dart must exist',
        );
        syncServiceSource = syncFile.readAsStringSync();

        // Read food_order_repository.dart
        final repoFile = File(
          'lib/features/restaurant/data/repositories/food_order_repository.dart',
        );
        expect(
          repoFile.existsSync(),
          isTrue,
          reason: 'food_order_repository.dart must exist',
        );
        orderRepoSource = repoFile.readAsStringSync();

        // Read sync_manager.dart
        final syncMgrFile = File('lib/core/sync/sync_manager.dart');
        expect(
          syncMgrFile.existsSync(),
          isTrue,
          reason: 'sync_manager.dart must exist',
        );
        syncManagerSource = syncMgrFile.readAsStringSync();
      });

      // =====================================================================
      // Sub-Test 1: Assert RestaurantSyncService has a reconcile/conflict
      // resolution method that compares `updatedAt` timestamps.
      // On UNFIXED code — FAILS (no such method exists).
      // =====================================================================
      test(
        'RestaurantSyncService has a reconcileOrderStatus method with updatedAt comparison',
        () {
          // Check for any method that reconciles/resolves conflicts
          final hasReconcileMethod =
              syncServiceSource.contains('reconcile') ||
              syncServiceSource.contains('resolveConflict') ||
              syncServiceSource.contains('lastWriteWins') ||
              syncServiceSource.contains('mergeUpdates');

          expect(
            hasReconcileMethod,
            isTrue,
            reason:
                'COUNTEREXAMPLE (Property 19 / Req 2.26): '
                'RestaurantSyncService has NO reconciliation method.\n\n'
                'The service contains only: syncAll(), _syncMenuItems(), '
                '_syncOrders(), _syncTables(), _syncBills(), getSyncStatus().\n\n'
                'None of these methods compare `updatedAt` timestamps or '
                'implement any conflict resolution strategy. The _syncOrders() '
                'method simply iterates unsynced orders and enqueues them for '
                'upload — if two devices update the same order status at the '
                'same time, whichever enqueue arrives last at Firestore wins, '
                'regardless of which update had the later timestamp.\n\n'
                'Expected: A reconcileOrderStatus (or equivalent) method that '
                'compares `updatedAt` timestamps and ensures the update with '
                'the later timestamp always wins, regardless of arrival order.',
          );
        },
      );

      // =====================================================================
      // Sub-Test 2: Assert updateOrderStatus in FoodOrderRepository checks
      // the existing record's `updatedAt` before overwriting.
      // On UNFIXED code — FAILS (it blindly overwrites).
      // =====================================================================
      test(
        'updateOrderStatus compares updatedAt before writing (last-write-wins guard)',
        () {
          // Extract the updateOrderStatus method body
          final methodName = 'updateOrderStatus';
          final methodIdx = orderRepoSource.indexOf(methodName);
          expect(
            methodIdx,
            isNot(-1),
            reason:
                'updateOrderStatus must exist in food_order_repository.dart',
          );

          // Get the method body
          final blockStart = orderRepoSource.indexOf('{', methodIdx);
          int depth = 0;
          int blockEnd = -1;
          for (int i = blockStart; i < orderRepoSource.length; i++) {
            if (orderRepoSource[i] == '{') depth++;
            if (orderRepoSource[i] == '}') {
              depth--;
              if (depth == 0) {
                blockEnd = i + 1;
                break;
              }
            }
          }
          final methodBody = orderRepoSource.substring(blockStart, blockEnd);

          // Check if the method reads the current updatedAt before writing
          final checksExistingTimestamp =
              methodBody.contains('updatedAt') &&
              (methodBody.contains('isAfter') ||
                  methodBody.contains('isBefore') ||
                  methodBody.contains('compareTo') ||
                  methodBody.contains('millisecondsSinceEpoch'));

          expect(
            checksExistingTimestamp,
            isTrue,
            reason:
                'COUNTEREXAMPLE (Property 19 / Req 2.26): '
                'updateOrderStatus in FoodOrderRepository does NOT check the '
                'existing record\'s updatedAt timestamp before overwriting.\n\n'
                'The method simply creates a new FoodOrdersCompanion with '
                'updatedAt: Value(DateTime.now()) and writes it via '
                '_db.update(_db.foodOrders)..where((t) => t.id.equals(orderId))'
                '.write(companion).\n\n'
                'There is no SELECT of the existing record to compare '
                'timestamps, no isAfter/isBefore check, and no conditional '
                'write. If two concurrent updates arrive (e.g., Device A sets '
                'status=COOKING at T1, Device B sets status=READY at T2 where '
                'T2 > T1), the final status depends entirely on which write() '
                'call executes last — not on which has the later timestamp.\n\n'
                'Expected: updateOrderStatus should read the current record\'s '
                'updatedAt, compare it against the incoming update\'s '
                'timestamp, and only write if the incoming timestamp is later '
                '(last-write-wins by updatedAt).',
          );
        },
      );

      // =====================================================================
      // Sub-Test 3: Assert SyncManager.resolveConflict has real logic (not
      // just a debugPrint placeholder).
      // On UNFIXED code — FAILS (resolveConflict is a no-op).
      // =====================================================================
      test(
        'SyncManager.resolveConflict implements real conflict resolution (not a no-op)',
        () {
          // Extract resolveConflict method body
          final methodName = 'resolveConflict';
          final methodIdx = syncManagerSource.indexOf(methodName);
          expect(
            methodIdx,
            isNot(-1),
            reason: 'resolveConflict must exist in sync_manager.dart',
          );

          final blockStart = syncManagerSource.indexOf('{', methodIdx);
          int depth = 0;
          int blockEnd = -1;
          for (int i = blockStart; i < syncManagerSource.length; i++) {
            if (syncManagerSource[i] == '{') depth++;
            if (syncManagerSource[i] == '}') {
              depth--;
              if (depth == 0) {
                blockEnd = i + 1;
                break;
              }
            }
          }
          final methodBody = syncManagerSource.substring(blockStart, blockEnd);

          // Check that it does more than just debugPrint
          final hasRealLogic =
              methodBody.contains('updatedAt') ||
              methodBody.contains('isAfter') ||
              methodBody.contains('isBefore') ||
              methodBody.contains('timestamp') ||
              methodBody.contains('lastWriteWins') ||
              methodBody.contains('update') && methodBody.contains('write');

          // Also check it's not just a debugPrint placeholder
          final isMoreThanDebugPrint =
              methodBody.split('\n').where((line) {
                final trimmed = line.trim();
                return trimmed.isNotEmpty &&
                    !trimmed.startsWith('//') &&
                    !trimmed.startsWith('debugPrint') &&
                    trimmed != '{' &&
                    trimmed != '}';
              }).isNotEmpty &&
              hasRealLogic;

          expect(
            isMoreThanDebugPrint,
            isTrue,
            reason:
                'COUNTEREXAMPLE (Property 19 / Req 2.26): '
                'SyncManager.resolveConflict is a NO-OP placeholder.\n\n'
                'The entire method body is:\n'
                '  debugPrint(\'SyncManager Facade: resolveConflict called for '
                '\${conflict.operationId}\');\n'
                '  // Update local DB via Engine/Repo hooks if needed\n\n'
                'It does not compare timestamps, does not write to the local '
                'DB, and does not resolve any conflict. When a sync conflict '
                'is detected (two concurrent updates to the same order), the '
                'conflict is simply logged and ignored — the final state is '
                'whatever happened to arrive last at the DB write layer.\n\n'
                'Expected: resolveConflict should implement a last-write-wins '
                'strategy keyed on updatedAt, comparing the local and remote '
                'timestamps and applying whichever is later.',
          );
        },
      );

      // =====================================================================
      // Sub-Test 4 (PBT-style enumeration): For ANY pair of concurrent status
      // updates to the same order ID, assert deterministic resolution exists.
      //
      // We test this structurally: the sync service must have a method that
      // takes two competing updates and returns the one with the later
      // `updatedAt`. On UNFIXED code — FAILS (no such method exists).
      // =====================================================================
      test(
        'for any pair of concurrent status updates, a deterministic resolution function exists',
        () {
          // Check all three relevant files for any conflict resolution logic
          // that could handle "given two updates to the same orderId with
          // different timestamps, pick the later one"
          final allSources =
              syncServiceSource + orderRepoSource + syncManagerSource;

          // Look for patterns indicating timestamp-based conflict resolution
          final hasTimestampComparison =
              allSources.contains(
                RegExp(r'updatedAt.*isAfter|isAfter.*updatedAt'),
              ) ||
              allSources.contains(
                RegExp(r'updatedAt.*isBefore|isBefore.*updatedAt'),
              ) ||
              allSources.contains(
                RegExp(r'updatedAt.*compareTo|compareTo.*updatedAt'),
              ) ||
              allSources.contains(RegExp(r'millisecondsSinceEpoch.*[<>]'));

          // Look for a dedicated conflict resolution method/function
          final hasConflictResolutionFunction =
              syncServiceSource.contains('reconcile') ||
              syncServiceSource.contains('resolveOrderConflict') ||
              syncServiceSource.contains('lastWriteWins') ||
              syncServiceSource.contains('pickLatest') ||
              syncServiceSource.contains('mergeStatus');

          final hasDeterministicResolution =
              hasTimestampComparison || hasConflictResolutionFunction;

          expect(
            hasDeterministicResolution,
            isTrue,
            reason:
                'COUNTEREXAMPLE (Property 19 / Req 2.26): '
                'No deterministic conflict resolution exists for concurrent '
                'KOT status updates in any of the three relevant files:\n\n'
                '1. restaurant_sync_service.dart — only queues unsynced items '
                'for upload; no reconciliation logic.\n'
                '2. food_order_repository.dart — updateOrderStatus blindly '
                'overwrites; no timestamp comparison.\n'
                '3. sync_manager.dart — resolveConflict is a debugPrint '
                'placeholder.\n\n'
                'Given two concurrent updates:\n'
                '  Update A: orderId=X, status=COOKING, updatedAt=T1\n'
                '  Update B: orderId=X, status=READY, updatedAt=T2 (T2 > T1)\n\n'
                'If A arrives after B at the DB write layer, the final status '
                'is COOKING (the OLDER update), not READY (the NEWER one).\n'
                'If B arrives after A, the final status is READY.\n\n'
                'The outcome depends on arrival order, not on timestamp — '
                'this is the definition of non-deterministic conflict '
                'resolution.\n\n'
                'Expected: A reconciliation function that, given any two '
                'competing updates to the same orderId, always picks the one '
                'with the later updatedAt timestamp, regardless of arrival '
                'order.',
          );
        },
      );
    },
  );
}
