import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/mobile_shop/widgets/performance/debounced_search_controller.dart';

void main() {
  group('DebouncedSearchController', () {
    late List<String> executedQueries;
    late List<String> deliveredResults;
    late Completer<String> searchCompleter;

    setUp(() {
      executedQueries = [];
      deliveredResults = [];
    });

    DebouncedSearchController<String> createController({
      Duration? debounceDuration,
      int? minQueryLength,
      Future<String> Function(String)? executor,
    }) {
      return DebouncedSearchController<String>(
        executor:
            executor ??
            (query) async {
              executedQueries.add(query);
              return 'result:$query';
            },
        onResult: (result) => deliveredResults.add(result),
        debounceDuration: debounceDuration ?? const Duration(milliseconds: 50),
        minQueryLength: minQueryLength ?? 3,
      );
    }

    test('does not execute query below minimum length', () {
      fakeAsync((async) {
        final cleared = <bool>[];
        final controller = DebouncedSearchController<String>(
          executor: (q) async {
            executedQueries.add(q);
            return 'result:$q';
          },
          onResult: (r) => deliveredResults.add(r),
          onCleared: () => cleared.add(true),
          debounceDuration: const Duration(milliseconds: 50),
          minQueryLength: 3,
        );

        controller.onQueryChanged('ab');
        async.elapse(const Duration(milliseconds: 100));

        expect(executedQueries, isEmpty);
        expect(cleared, hasLength(1));

        controller.dispose();
      });
    });

    test('debounces query execution by configured duration', () {
      fakeAsync((async) {
        final controller = createController();

        controller.onQueryChanged('abc');
        expect(executedQueries, isEmpty);

        async.elapse(const Duration(milliseconds: 25));
        expect(executedQueries, isEmpty);

        async.elapse(const Duration(milliseconds: 30));
        expect(executedQueries, ['abc']);

        controller.dispose();
      });
    });

    test('cancels previous timer on rapid input', () {
      fakeAsync((async) {
        final controller = createController();

        controller.onQueryChanged('abc');
        async.elapse(const Duration(milliseconds: 20));
        controller.onQueryChanged('abcd');
        async.elapse(const Duration(milliseconds: 20));
        controller.onQueryChanged('abcde');

        async.elapse(const Duration(milliseconds: 60));

        // Only the last query should execute.
        expect(executedQueries, ['abcde']);

        controller.dispose();
      });
    });

    test('skips unchanged query (avoids rescan)', () {
      fakeAsync((async) {
        final controller = createController();

        controller.onQueryChanged('hello');
        async.elapse(const Duration(milliseconds: 60));
        expect(executedQueries, ['hello']);

        // Same query again — should be skipped.
        controller.onQueryChanged('hello');
        async.elapse(const Duration(milliseconds: 60));
        expect(executedQueries, hasLength(1));

        controller.dispose();
      });
    });

    test('latest-query-wins: discards stale results', () {
      fakeAsync((async) {
        final completers = <String, Completer<String>>{};

        final controller = DebouncedSearchController<String>(
          executor: (query) {
            executedQueries.add(query);
            final c = Completer<String>();
            completers[query] = c;
            return c.future;
          },
          onResult: (result) => deliveredResults.add(result),
          debounceDuration: const Duration(milliseconds: 10),
          minQueryLength: 3,
        );

        // First query
        controller.onQueryChanged('first');
        async.elapse(const Duration(milliseconds: 15));
        expect(executedQueries, ['first']);

        // Second query before first completes
        controller.onQueryChanged('second');
        async.elapse(const Duration(milliseconds: 15));
        expect(executedQueries, ['first', 'second']);

        // Complete second first (out of order)
        completers['second']!.complete('result:second');
        async.flushMicrotasks();
        expect(deliveredResults, ['result:second']);

        // Complete first (stale) — should be discarded
        completers['first']!.complete('result:first');
        async.flushMicrotasks();
        expect(deliveredResults, ['result:second']);

        controller.dispose();
      });
    });

    test('executeImmediate bypasses debounce', () {
      fakeAsync((async) {
        final controller = createController();

        controller.executeImmediate('immediate');
        async.flushMicrotasks();

        expect(executedQueries, ['immediate']);
        controller.dispose();
      });
    });

    test('cancel stops pending debounce', () {
      fakeAsync((async) {
        final controller = createController();

        controller.onQueryChanged('pending');
        controller.cancel();
        async.elapse(const Duration(milliseconds: 100));

        expect(executedQueries, isEmpty);
        controller.dispose();
      });
    });

    test('reset clears last query state', () {
      fakeAsync((async) {
        final controller = createController();

        controller.onQueryChanged('hello');
        async.elapse(const Duration(milliseconds: 60));
        expect(controller.lastExecutedQuery, 'hello');

        controller.reset();
        expect(controller.lastExecutedQuery, '');

        // Same query should execute again after reset.
        controller.onQueryChanged('hello');
        async.elapse(const Duration(milliseconds: 60));
        expect(executedQueries, ['hello', 'hello']);

        controller.dispose();
      });
    });

    test('onError only delivers for latest query', () {
      fakeAsync((async) {
        final errors = <Object>[];
        final completers = <String, Completer<String>>{};

        final controller = DebouncedSearchController<String>(
          executor: (query) {
            final c = Completer<String>();
            completers[query] = c;
            return c.future;
          },
          onResult: (r) => deliveredResults.add(r),
          onError: (e) => errors.add(e),
          debounceDuration: const Duration(milliseconds: 10),
          minQueryLength: 3,
        );

        controller.onQueryChanged('query1');
        async.elapse(const Duration(milliseconds: 15));

        controller.onQueryChanged('query2');
        async.elapse(const Duration(milliseconds: 15));

        // Stale query errors — should be discarded.
        completers['query1']!.completeError('stale error');
        async.flushMicrotasks();
        expect(errors, isEmpty);

        // Latest query errors — should be delivered.
        completers['query2']!.completeError('current error');
        async.flushMicrotasks();
        expect(errors, ['current error']);

        controller.dispose();
      });
    });

    test('uses default debounce from kBoundsConfig (300ms)', () {
      fakeAsync((async) {
        final controller = DebouncedSearchController<String>(
          executor: (q) async {
            executedQueries.add(q);
            return q;
          },
          onResult: (r) {},
        );

        controller.onQueryChanged('test query');

        // Should not execute before 300ms
        async.elapse(const Duration(milliseconds: 250));
        expect(executedQueries, isEmpty);

        // Should execute after 300ms
        async.elapse(const Duration(milliseconds: 60));
        expect(executedQueries, ['test query']);

        controller.dispose();
      });
    });
  });
}
