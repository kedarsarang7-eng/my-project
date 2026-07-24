import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/mobile_shop/widgets/performance/bounded_list_controller.dart';
import 'package:dukanx/features/mobile_shop/screens/reports/report_screen_base.dart';

void main() {
  group('BoundedListController', () {
    test('clamps page size to valid range', () {
      final controller = BoundedListController<String>(
        fetcher: (limit, token) async => const BoundedPage.empty(),
        pageSize: 500, // exceeds kReportMaxLimit (200)
      );
      expect(controller.pageSize, kReportMaxLimit);
      controller.dispose();
    });

    test('uses kReportDefaultLimit (50) when pageSize is null', () {
      final controller = BoundedListController<String>(
        fetcher: (limit, token) async => const BoundedPage.empty(),
      );
      expect(controller.pageSize, kReportDefaultLimit);
      controller.dispose();
    });

    test('clamps page size minimum to 1', () {
      final controller = BoundedListController<String>(
        fetcher: (limit, token) async => const BoundedPage.empty(),
        pageSize: 0,
      );
      expect(controller.pageSize, 1);
      controller.dispose();
    });

    test('loadInitial fetches first page', () async {
      final controller = BoundedListController<String>(
        fetcher: (limit, token) async {
          expect(limit, kReportDefaultLimit);
          expect(token, isNull);
          return BoundedPage(
            items: ['a', 'b', 'c'],
            continuationToken: 'token1',
          );
        },
      );

      await controller.loadInitial();

      expect(controller.items, ['a', 'b', 'c']);
      expect(controller.hasMore, isTrue);
      expect(controller.currentToken, 'token1');
      expect(controller.isLoading, isFalse);
      controller.dispose();
    });

    test('loadMore appends next page', () async {
      int callCount = 0;

      final controller = BoundedListController<String>(
        fetcher: (limit, token) async {
          callCount++;
          if (callCount == 1) {
            return BoundedPage(items: ['a', 'b'], continuationToken: 'page2');
          }
          expect(token, 'page2');
          return const BoundedPage(items: ['c', 'd']);
        },
      );

      await controller.loadInitial();
      expect(controller.items, ['a', 'b']);

      await controller.loadMore();
      expect(controller.items, ['a', 'b', 'c', 'd']);
      expect(controller.hasMore, isFalse);
      controller.dispose();
    });

    test('loadMore is no-op when no more pages', () async {
      int callCount = 0;
      final controller = BoundedListController<String>(
        fetcher: (limit, token) async {
          callCount++;
          return const BoundedPage(items: ['only']);
        },
      );

      await controller.loadInitial();
      expect(callCount, 1);

      await controller.loadMore();
      expect(callCount, 1); // Not called again
      controller.dispose();
    });

    test('loadMore is no-op while loading', () async {
      final completer = Completer<BoundedPage<String>>();
      int callCount = 0;

      final controller = BoundedListController<String>(
        fetcher: (limit, token) {
          callCount++;
          if (callCount == 1) {
            return Future.value(
              BoundedPage(items: ['a'], continuationToken: 'next'),
            );
          }
          return completer.future;
        },
      );

      await controller.loadInitial();

      // Start loading more
      final future = controller.loadMore();
      expect(controller.isLoading, isTrue);

      // Try loading more while already loading
      await controller.loadMore();
      expect(callCount, 2); // Not called again

      completer.complete(const BoundedPage(items: ['b']));
      await future;
      controller.dispose();
    });

    test('captures error on fetch failure', () async {
      final controller = BoundedListController<String>(
        fetcher: (limit, token) async {
          throw Exception('network error');
        },
      );

      await controller.loadInitial();

      expect(controller.lastError, isA<Exception>());
      expect(controller.items, isEmpty);
      expect(controller.isLoading, isFalse);
      controller.dispose();
    });

    test('refresh resets and reloads', () async {
      int callCount = 0;
      final controller = BoundedListController<String>(
        fetcher: (limit, token) async {
          callCount++;
          return BoundedPage(
            items: ['page$callCount'],
            continuationToken: 'tok',
          );
        },
      );

      await controller.loadInitial();
      expect(controller.items, ['page1']);

      await controller.refresh();
      expect(controller.items, ['page2']);
      expect(callCount, 2);
      controller.dispose();
    });

    test('notifies listeners on state changes', () async {
      int notifications = 0;
      final controller = BoundedListController<String>(
        fetcher: (limit, token) async => const BoundedPage(items: ['x']),
      );
      controller.addListener(() => notifications++);

      await controller.loadInitial();
      // At least 2: once for loading start, once for loading complete
      expect(notifications, greaterThanOrEqualTo(2));
      controller.dispose();
    });
  });

  group('BoundedPage', () {
    test('hasMore is true when continuationToken is present', () {
      const page = BoundedPage(items: ['a'], continuationToken: 'tok');
      expect(page.hasMore, isTrue);
    });

    test('hasMore is false when continuationToken is null', () {
      const page = BoundedPage<String>(items: ['a']);
      expect(page.hasMore, isFalse);
    });

    test('empty() creates an empty page with no continuation', () {
      const page = BoundedPage<String>.empty();
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });
}
