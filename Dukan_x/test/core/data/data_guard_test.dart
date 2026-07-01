import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/data/data_guard.dart';

void main() {
  group('DataGuard Crash Prevention Tests', () {
    test('safeString handles nulls and types', () {
      expect(DataGuard.safeString(null), '');
      expect(DataGuard.safeString('test'), 'test');
      expect(DataGuard.safeString(123), '123');
      expect(DataGuard.safeString(true), 'true');
    });

    test('safeDouble handles parsing', () {
      expect(DataGuard.safeDouble(null), 0.0);
      expect(DataGuard.safeDouble(10), 10.0);
      expect(DataGuard.safeDouble(10.5), 10.5);
      expect(DataGuard.safeDouble('10.5'), 10.5);
      expect(DataGuard.safeDouble('invalid'), 0.0);
    });

    test('safeMap handles null and bad types', () {
      expect(DataGuard.safeMap(null), {});
      expect(DataGuard.safeMap('not a map'), {});
      expect(DataGuard.safeMap({}), {});

      final m = {'a': 1, 'b': 2};
      // Generic map should be castable if types match
      expect(DataGuard.safeMap<String, int>(m), {'a': 1, 'b': 2});
    });

    test('safeJsonMap handles bad JSON', () {
      expect(DataGuard.safeJsonMap(null), {});
      expect(DataGuard.safeJsonMap(''), {});
      expect(DataGuard.safeJsonMap('{broken json'), {});
      expect(
        DataGuard.safeJsonMap('["list", "not", "map"]'),
        {},
      ); // Valid JSON but not map

      final json = '{"key": "value"}';
      expect(DataGuard.safeJsonMap(json), {'key': 'value'});
    });
  });
}
