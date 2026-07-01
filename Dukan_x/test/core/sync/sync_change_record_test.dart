// Reproduction + regression test for D5 idempotency-key support
// (clauses 2.10 + 2.19 of `bugfix.md`).
//
// On F (no idempotencyKey field) round-tripping a `SyncChangeRecord` drops
// the dedupe identity, so server-side retries duplicate writes. On F' the
// key is preserved through `toJson`/`fromJson` and downstream handlers
// inherit it for free because they all build their envelopes via this
// single class.

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/sync/models/sync_payloads.dart';

void main() {
  group('SyncChangeRecord — idempotency key', () {
    test('toJson omits idempotencyKey when null (legacy compatibility)', () {
      const record = SyncChangeRecord(
        table: 'customers',
        action: 'insert',
        id: 'c-001',
        data: {'name': 'Alice'},
        localTimestamp: '2024-06-15T10:00:00Z',
      );
      expect(record.toJson().containsKey('idempotencyKey'), isFalse);
    });

    test('toJson includes idempotencyKey when supplied', () {
      const record = SyncChangeRecord(
        table: 'bills',
        action: 'update',
        id: 'b-007',
        data: {'total': 12345},
        localTimestamp: '2024-06-15T10:00:00Z',
        idempotencyKey: 'op-uuid-aaaa-bbbb-cccc',
      );
      final json = record.toJson();
      expect(json['idempotencyKey'], equals('op-uuid-aaaa-bbbb-cccc'));
    });

    test('round-trip preserves idempotencyKey', () {
      const original = SyncChangeRecord(
        table: 'products',
        action: 'delete',
        id: 'p-42',
        data: {'sku': 'X42'},
        localTimestamp: '2024-06-15T10:00:00Z',
        idempotencyKey: 'dedupe-9b7f-3e21',
      );
      final restored = SyncChangeRecord.fromJson(original.toJson());
      expect(restored.idempotencyKey, equals(original.idempotencyKey));
      expect(restored.table, equals(original.table));
      expect(restored.action, equals(original.action));
      expect(restored.id, equals(original.id));
      expect(restored.localTimestamp, equals(original.localTimestamp));
    });

    test('legacy payload without idempotencyKey decodes with null', () {
      final legacyJson = <String, dynamic>{
        'table': 'customers',
        'action': 'insert',
        'id': 'c-002',
        'data': {'name': 'Bob'},
        'localTimestamp': '2024-06-15T10:00:00Z',
      };
      final record = SyncChangeRecord.fromJson(legacyJson);
      expect(record.idempotencyKey, isNull);
    });

    test(
      'two retries with the same key serialise identically (dedupe-ready)',
      () {
        const a = SyncChangeRecord(
          table: 'bills',
          action: 'insert',
          id: 'b-100',
          data: {'total': 500},
          localTimestamp: '2024-06-15T10:00:00Z',
          idempotencyKey: 'retry-key-1',
        );
        const b = SyncChangeRecord(
          table: 'bills',
          action: 'insert',
          id: 'b-100',
          data: {'total': 500},
          localTimestamp: '2024-06-15T10:00:00Z',
          idempotencyKey: 'retry-key-1',
        );
        expect(a.toJson(), equals(b.toJson()));
      },
    );
  });
}
