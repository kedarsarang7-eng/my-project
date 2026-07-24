import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/mobile_shop/widgets/performance/latest_query_guard.dart';

void main() {
  group('LatestQueryGuard', () {
    test('delivers result from single query', () async {
      final results = <String>[];
      final guard = LatestQueryGuard<String>(onResult: (r) => results.add(r));

      final value = await guard.guard(() async => 'hello');

      expect(value, 'hello');
      expect(results, ['hello']);
    });

    test('discards stale results from earlier queries', () async {
      final results = <String>[];
      final guard = LatestQueryGuard<String>(onResult: (r) => results.add(r));

      final completer1 = Completer<String>();
      final completer2 = Completer<String>();

      // Start first query
      final future1 = guard.guard(() => completer1.future);
      // Start second query (supersedes first)
      final future2 = guard.guard(() => completer2.future);

      // Complete second first
      completer2.complete('second');
      await future2;
      expect(results, ['second']);

      // Complete first (stale)
      completer1.complete('first');
      await future1;
      expect(results, ['second']); // Stale result not delivered
    });

    test('returns null for stale queries', () async {
      final guard = LatestQueryGuard<String>();

      final completer1 = Completer<String>();
      final completer2 = Completer<String>();

      final future1 = guard.guard(() => completer1.future);
      final future2 = guard.guard(() => completer2.future);

      completer2.complete('latest');
      completer1.complete('stale');

      expect(await future2, 'latest');
      expect(await future1, isNull);
    });

    test('only delivers error from latest query', () async {
      final errors = <Object>[];
      final guard = LatestQueryGuard<String>(onError: (e) => errors.add(e));

      final completer1 = Completer<String>();
      final completer2 = Completer<String>();

      final future1 = guard.guard(() => completer1.future);
      final future2 = guard.guard(() => completer2.future);

      // Error on stale query — discarded.
      completer1.completeError('stale error');
      await future1;
      expect(errors, isEmpty);

      // Error on latest query — delivered.
      completer2.completeError('latest error');
      await future2;
      expect(errors, ['latest error']);
    });

    test('invalidate discards all in-flight queries', () async {
      final results = <String>[];
      final guard = LatestQueryGuard<String>(onResult: (r) => results.add(r));

      final completer = Completer<String>();
      final future = guard.guard(() => completer.future);

      guard.invalidate();

      completer.complete('too late');
      await future;
      expect(results, isEmpty);
    });

    test('isCurrent checks sequence correctly', () {
      final guard = LatestQueryGuard<String>();

      final seq1 = guard.nextSequence();
      expect(guard.isCurrent(seq1), isTrue);

      final seq2 = guard.nextSequence();
      expect(guard.isCurrent(seq1), isFalse);
      expect(guard.isCurrent(seq2), isTrue);
    });

    test('reset sets sequence back to 0', () {
      final guard = LatestQueryGuard<String>();

      guard.nextSequence();
      guard.nextSequence();
      expect(guard.currentSequence, 2);

      guard.reset();
      expect(guard.currentSequence, 0);
    });

    test('handles multiple rapid queries keeping only the last', () async {
      final results = <int>[];
      final guard = LatestQueryGuard<int>(onResult: (r) => results.add(r));

      final completers = List.generate(5, (_) => Completer<int>());
      final futures = <Future<int?>>[];

      for (int i = 0; i < 5; i++) {
        futures.add(guard.guard(() => completers[i].future));
      }

      // Complete in reverse order
      for (int i = 4; i >= 0; i--) {
        completers[i].complete(i);
      }

      await Future.wait(futures);

      // Only the last query result (index 4) should be delivered.
      expect(results, [4]);
    });
  });
}
