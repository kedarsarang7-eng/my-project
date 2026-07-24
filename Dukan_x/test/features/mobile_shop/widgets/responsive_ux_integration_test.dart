/// Responsive UX Integration Tests — Cross-Component Behavior (Task 16.4)
///
/// Validates: Requirements 11.7–11.12, 13.1
/// - OperationStateCard renders correct icons/labels for all 10 states
/// - OperationStateCard respects semantic liveRegion for state changes
/// - DebouncedSearchController cancels stale queries (latest-query-wins)
/// - StableKeyListView preserves widget identity across updates
/// - BoundedListController pagination with stable keys
/// - FilterStateController does not notify on unchanged filter (rebuild bounds)
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/theme/mobile_shop_theme.dart';
import 'package:dukanx/features/mobile_shop/widgets/operation_state/operation_state.dart';
import 'package:dukanx/features/mobile_shop/widgets/operation_state/operation_state_card.dart';
import 'package:dukanx/features/mobile_shop/widgets/performance/bounded_list_controller.dart';
import 'package:dukanx/features/mobile_shop/widgets/performance/debounced_search_controller.dart';
import 'package:dukanx/features/mobile_shop/widgets/performance/filter_state_controller.dart';
import 'package:dukanx/features/mobile_shop/widgets/performance/stable_key_list_view.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // OperationStateCard — Correct Icons/Labels per State (Req 11.7)
  // ═══════════════════════════════════════════════════════════════════════════

  group('OperationStateCard renders all 10 states', () {
    testWidgets('loading state shows progress indicator and label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _stateCardApp(
          const OperationLoading(message: 'Fetching devices', progress: 0.5),
        ),
      );

      // Progress indicator instead of static icon for loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Fetching devices'), findsWidgets);
    });

    testWidgets('empty state shows inbox icon', (tester) async {
      await tester.pumpWidget(
        _stateCardApp(const OperationEmpty(message: 'No devices in stock')),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('disabled state shows block icon', (tester) async {
      await tester.pumpWidget(
        _stateCardApp(const OperationDisabled(reason: 'Permission required')),
      );

      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    });

    testWidgets('pending localQueued shows cloud upload icon', (tester) async {
      await tester.pumpWidget(
        _stateCardApp(const OperationPending(kind: PendingKind.localQueued)),
      );

      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });

    testWidgets('pending serverAccepted shows cloud done icon', (tester) async {
      await tester.pumpWidget(
        _stateCardApp(const OperationPending(kind: PendingKind.serverAccepted)),
      );

      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    });

    testWidgets('pending reconciling shows sync icon', (tester) async {
      await tester.pumpWidget(
        _stateCardApp(const OperationPending(kind: PendingKind.reconciling)),
      );

      expect(find.byIcon(Icons.sync_outlined), findsOneWidget);
    });

    testWidgets('stale state shows update icon', (tester) async {
      await tester.pumpWidget(
        _stateCardApp(const OperationStale(message: 'Data may be outdated')),
      );

      expect(find.byIcon(Icons.update_outlined), findsOneWidget);
    });

    testWidgets('conflicted state shows warning icon', (tester) async {
      await tester.pumpWidget(
        _stateCardApp(const OperationConflicted(message: 'Version mismatch')),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('unavailable state shows cloud-off icon', (tester) async {
      await tester.pumpWidget(
        _stateCardApp(
          const OperationUnavailable(message: 'Backend unreachable'),
        ),
      );

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('failed state shows error icon', (tester) async {
      await tester.pumpWidget(
        _stateCardApp(const OperationFailed(message: 'Transaction rejected')),
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('complete state shows check icon', (tester) async {
      await tester.pumpWidget(
        _stateCardApp(OperationComplete(confirmedAt: DateTime(2025, 1, 15))),
      );

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('signedOut state shows lock icon', (tester) async {
      await tester.pumpWidget(_stateCardApp(const OperationSignedOut()));

      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('card exposes semantics liveRegion for all states', (
      tester,
    ) async {
      await tester.pumpWidget(
        _stateCardApp(const OperationLoading(message: 'Processing sale')),
      );

      final semantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(OperationStateCard),
          matching: find.byType(Semantics),
        ),
      );
      final liveRegions = semantics.where(
        (s) => s.properties.liveRegion == true,
      );
      expect(liveRegions, isNotEmpty);
    });

    testWidgets('recovery actions render when onRecoveryAction provided', (
      tester,
    ) async {
      RecoveryAction? invoked;

      await tester.pumpWidget(
        _themeApp(
          child: OperationStateCard(
            state: const OperationFailed(
              message: 'Network error',
              retryable: true,
              operationId: 'op-123',
              correlationId: 'corr-456',
            ),
            onRecoveryAction: (action) => invoked = action,
          ),
        ),
      );

      // Find and tap the retry chip
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(invoked, isNotNull);
      expect(invoked!.type, RecoveryActionType.retry);
    });

    testWidgets('compact mode shows inline state without recovery actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themeApp(
          child: const OperationStateCard(
            state: OperationFailed(
              message: 'Error',
              retryable: true,
              operationId: 'op-1',
            ),
            compact: true,
          ),
        ),
      );

      // In compact mode, icon is 16px and no recovery buttons
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DebouncedSearchController — Stale Query Cancellation (Req 11.9)
  // ═══════════════════════════════════════════════════════════════════════════

  group('DebouncedSearchController cancellation', () {
    test('cancels stale queries and delivers only latest result', () {
      fakeAsync((async) {
        final results = <String>[];
        int executionCount = 0;

        final controller = DebouncedSearchController<String>(
          executor: (query) async {
            executionCount++;
            await Future.delayed(const Duration(milliseconds: 100));
            return 'result:$query';
          },
          onResult: (r) => results.add(r),
          debounceDuration: const Duration(milliseconds: 50),
          minQueryLength: 2,
        );

        // Type rapidly — only the last query should execute
        controller.onQueryChanged('samsung');
        async.elapse(const Duration(milliseconds: 20));
        controller.onQueryChanged('samsung ga');
        async.elapse(const Duration(milliseconds: 20));
        controller.onQueryChanged('samsung galaxy');

        // Wait for debounce + execution
        async.elapse(const Duration(milliseconds: 200));

        // Only one execution (the latest after debounce)
        expect(executionCount, 1);
        expect(results, ['result:samsung galaxy']);

        controller.dispose();
      });
    });

    test(
      'latest-query-wins: old results discarded after newer query fires',
      () {
        fakeAsync((async) {
          final results = <String>[];
          var delayMs = 200; // First query is slow

          final controller = DebouncedSearchController<String>(
            executor: (query) async {
              final thisDelay = delayMs;
              delayMs = 50; // Subsequent queries fast
              await Future.delayed(Duration(milliseconds: thisDelay));
              return 'result:$query';
            },
            onResult: (r) => results.add(r),
            debounceDuration: const Duration(milliseconds: 30),
            minQueryLength: 2,
          );

          // First query
          controller.onQueryChanged('iphone');
          async.elapse(const Duration(milliseconds: 30)); // debounce fires

          // Immediately new query before first resolves
          controller.onQueryChanged('pixel');
          async.elapse(const Duration(milliseconds: 30)); // second debounce

          // Wait for both to resolve
          async.elapse(const Duration(milliseconds: 300));

          // Only the latest result should be delivered
          expect(results.where((r) => r.contains('iphone')), isEmpty);
          expect(results.last, 'result:pixel');

          controller.dispose();
        });
      },
    );

    test('cancel() prevents pending debounce from executing', () {
      fakeAsync((async) {
        final results = <String>[];

        final controller = DebouncedSearchController<String>(
          executor: (query) async => 'result:$query',
          onResult: (r) => results.add(r),
          debounceDuration: const Duration(milliseconds: 50),
          minQueryLength: 2,
        );

        controller.onQueryChanged('test query');
        // Cancel before debounce fires
        async.elapse(const Duration(milliseconds: 20));
        controller.cancel();

        // Wait past debounce
        async.elapse(const Duration(milliseconds: 100));

        expect(results, isEmpty);

        controller.dispose();
      });
    });

    test('skips unchanged query to avoid rescans (Req 11.11)', () {
      fakeAsync((async) {
        int executionCount = 0;

        final controller = DebouncedSearchController<String>(
          executor: (query) async {
            executionCount++;
            return 'result:$query';
          },
          onResult: (_) {},
          debounceDuration: const Duration(milliseconds: 50),
          minQueryLength: 2,
        );

        // Execute once
        controller.onQueryChanged('nokia');
        async.elapse(const Duration(milliseconds: 100));
        expect(executionCount, 1);

        // Same query again — should skip
        controller.onQueryChanged('nokia');
        async.elapse(const Duration(milliseconds: 100));
        expect(executionCount, 1);

        controller.dispose();
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // StableKeyListView — Stable Keys (Req 11.10)
  // ═══════════════════════════════════════════════════════════════════════════

  group('StableKeyListView', () {
    testWidgets('uses stable keys from keyExtractor', (tester) async {
      final items = [
        _TestItem('id-1', 'Phone A'),
        _TestItem('id-2', 'Phone B'),
        _TestItem('id-3', 'Phone C'),
      ];

      await tester.pumpWidget(
        _themeApp(
          child: StableKeyListView<_TestItem>(
            items: items,
            keyExtractor: (item) => item.id,
            itemBuilder: (context, item) => ListTile(title: Text(item.name)),
          ),
        ),
      );

      expect(find.text('Phone A'), findsOneWidget);
      expect(find.text('Phone B'), findsOneWidget);
      expect(find.text('Phone C'), findsOneWidget);
    });

    testWidgets('shows empty widget when items is empty', (tester) async {
      await tester.pumpWidget(
        _themeApp(
          child: StableKeyListView<_TestItem>(
            items: const [],
            keyExtractor: (item) => item.id,
            itemBuilder: (context, item) => ListTile(title: Text(item.name)),
            emptyWidget: const Text('No items'),
          ),
        ),
      );

      expect(find.text('No items'), findsOneWidget);
    });

    testWidgets('preserves stable keys when list is reordered', (tester) async {
      final items = [_TestItem('id-1', 'First'), _TestItem('id-2', 'Second')];

      await tester.pumpWidget(
        _themeApp(
          child: StableKeyListView<_TestItem>(
            items: items,
            keyExtractor: (item) => item.id,
            itemBuilder: (context, item) =>
                Text(item.name, key: ValueKey(item.id)),
          ),
        ),
      );

      // Reorder
      final reordered = [items[1], items[0]];
      await tester.pumpWidget(
        _themeApp(
          child: StableKeyListView<_TestItem>(
            items: reordered,
            keyExtractor: (item) => item.id,
            itemBuilder: (context, item) =>
                Text(item.name, key: ValueKey(item.id)),
          ),
        ),
      );

      // Both still visible
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // BoundedListController — Pagination (Req 11.10)
  // ═══════════════════════════════════════════════════════════════════════════

  group('BoundedListController pagination', () {
    test('loadInitial fetches first page and stores items', () async {
      final controller = BoundedListController<String>(
        fetcher: (limit, token) async {
          expect(token, isNull);
          return BoundedPage(
            items: ['a', 'b', 'c'],
            continuationToken: 'page2',
          );
        },
        pageSize: 10,
      );

      await controller.loadInitial();

      expect(controller.items, ['a', 'b', 'c']);
      expect(controller.hasMore, isTrue);
      expect(controller.isLoading, isFalse);

      controller.dispose();
    });

    test('loadMore appends next page using continuation token', () async {
      var callCount = 0;

      final controller = BoundedListController<String>(
        fetcher: (limit, token) async {
          callCount++;
          if (callCount == 1) {
            return BoundedPage(items: ['a', 'b'], continuationToken: 'token-2');
          }
          expect(token, 'token-2');
          return const BoundedPage(items: ['c', 'd']);
        },
        pageSize: 5,
      );

      await controller.loadInitial();
      await controller.loadMore();

      expect(controller.items, ['a', 'b', 'c', 'd']);
      expect(controller.hasMore, isFalse);

      controller.dispose();
    });

    test('loadMore is no-op when already loading', () async {
      final completer = Completer<BoundedPage<String>>();
      var fetchCount = 0;

      final controller = BoundedListController<String>(
        fetcher: (limit, token) {
          fetchCount++;
          return completer.future;
        },
      );

      // Start loading — will await completer
      final future1 = controller.loadInitial();
      // Try loadMore while loading
      controller.loadMore();

      completer.complete(
        const BoundedPage(items: ['x'], continuationToken: 'next'),
      );
      await future1;

      // Only one fetch occurred (loadMore was a no-op)
      expect(fetchCount, 1);

      controller.dispose();
    });

    test('loadMore is no-op when hasMore is false', () async {
      var fetchCount = 0;

      final controller = BoundedListController<String>(
        fetcher: (limit, token) async {
          fetchCount++;
          return const BoundedPage(items: ['x']); // no continuation
        },
      );

      await controller.loadInitial();
      expect(controller.hasMore, isFalse);

      await controller.loadMore();
      expect(fetchCount, 1); // No additional fetch

      controller.dispose();
    });

    test('captures error without crashing', () async {
      final controller = BoundedListController<String>(
        fetcher: (limit, token) async {
          throw Exception('Network error');
        },
      );

      await controller.loadInitial();

      expect(controller.lastError, isNotNull);
      expect(controller.items, isEmpty);
      expect(controller.isLoading, isFalse);

      controller.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FilterStateController — Rebuild Bounds (Req 11.11)
  // ═══════════════════════════════════════════════════════════════════════════

  group('FilterStateController rebuild bounds', () {
    test('does not notify when filter is unchanged', () {
      int notifyCount = 0;

      final controller = FilterStateController(
        initialState: const MapFilterState({'status': 'active'}),
      );
      controller.addListener(() => notifyCount++);

      // Try to update with same state
      final changed = controller.updateState(
        const MapFilterState({'status': 'active'}),
      );

      expect(changed, isFalse);
      expect(notifyCount, 0);

      controller.dispose();
    });

    test('notifies when filter actually changes', () {
      int notifyCount = 0;

      final controller = FilterStateController(
        initialState: const MapFilterState({'status': 'active'}),
      );
      controller.addListener(() => notifyCount++);

      final changed = controller.updateState(
        const MapFilterState({'status': 'completed'}),
      );

      expect(changed, isTrue);
      expect(notifyCount, 1);

      controller.dispose();
    });

    test('onFilterChanged callback only fires on actual change', () {
      final changes = <MapFilterState>[];

      final controller = FilterStateController(
        initialState: const MapFilterState({'tab': 'all'}),
        onFilterChanged: (state) => changes.add(state),
      );

      // No-op change
      controller.updateState(const MapFilterState({'tab': 'all'}));
      expect(changes, isEmpty);

      // Real change
      controller.updateState(const MapFilterState({'tab': 'pending'}));
      expect(changes, hasLength(1));
      expect(changes.first.get<String>('tab'), 'pending');

      // Another same state — no change
      controller.updateState(const MapFilterState({'tab': 'pending'}));
      expect(changes, hasLength(1));

      controller.dispose();
    });

    test('reset to same state does not notify', () {
      int notifyCount = 0;
      const initial = MapFilterState({'sort': 'date'});

      final controller = FilterStateController(initialState: initial);
      controller.addListener(() => notifyCount++);

      final changed = controller.reset(initial);
      expect(changed, isFalse);
      expect(notifyCount, 0);

      controller.dispose();
    });

    test('reset to different state notifies', () {
      int notifyCount = 0;

      final controller = FilterStateController(
        initialState: const MapFilterState({'sort': 'date'}),
      );
      controller.addListener(() => notifyCount++);

      final changed = controller.reset(const MapFilterState.empty());
      expect(changed, isTrue);
      expect(notifyCount, 1);

      controller.dispose();
    });
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _TestItem {
  final String id;
  final String name;
  const _TestItem(this.id, this.name);
}

Widget _themeApp({required Widget child}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [MobileShopTheme.light()]),
    home: Scaffold(body: child),
  );
}

Widget _stateCardApp(OperationState state) {
  return _themeApp(child: OperationStateCard(state: state));
}
