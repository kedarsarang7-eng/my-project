// Unit tests: RequestContext — RID generation and parsing
// Source: lib/core/request_context/request_context.dart
//
// RID format: {tenantId}-{timestamp_ms}-{uuid_v4_short}

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/request_context/request_context.dart';

void main() {
  // === RID Format ===
  group('RequestContext.generate — RID format', () {
    test('format: {tenantId}-{timestamp_ms}-{uuid_v4_short}', () {
      final ctx = RequestContext.generate(
        tenantId: 'tenant_abc', userId: 'user_1');
      final parts = ctx.requestId.split('-');
      // tenant_abc has an underscore, so split by '-' gives:
      // ['tenant_abc', '<timestamp>', '<uuid6>']
      // But tenant_abc itself has no dash, so parts length should be 3
      expect(parts.length, greaterThanOrEqualTo(3));
      expect(ctx.requestId.startsWith('tenant_abc-'), true);
    });

    test('tenantId is embedded in RID', () {
      final ctx = RequestContext.generate(tenantId: 'shop_123');
      expect(ctx.requestId.startsWith('shop_123-'), true);
      expect(ctx.tenantId, 'shop_123');
    });

    test('timestamp component is valid milliseconds', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final ctx = RequestContext.generate(tenantId: 'test');
      final after = DateTime.now().millisecondsSinceEpoch;

      // Extract timestamp — after tenantId and before uuid
      final rid = ctx.requestId;
      final afterTenant = rid.substring('test-'.length);
      final tsStr = afterTenant.split('-').first;
      final ts = int.parse(tsStr);

      expect(ts, greaterThanOrEqualTo(before));
      expect(ts, lessThanOrEqualTo(after));
    });

    test('uuid component is 6 characters', () {
      final ctx = RequestContext.generate(tenantId: 'test');
      final lastPart = ctx.requestId.split('-').last;
      expect(lastPart.length, 6);
    });
  });

  // === Uniqueness ===
  group('RequestContext.generate — uniqueness', () {
    test('two RIDs for same tenant are unique', () {
      final a = RequestContext.generate(tenantId: 'tenant_a');
      final b = RequestContext.generate(tenantId: 'tenant_a');
      expect(a.requestId, isNot(equals(b.requestId)));
    });

    test('100 RIDs are all unique', () {
      final rids = List.generate(
        100, (_) => RequestContext.generate(tenantId: 'test').requestId);
      expect(rids.toSet().length, 100);
    });

    test('RID for Tenant A never starts with Tenant B prefix', () {
      final a = RequestContext.generate(tenantId: 'alpha');
      final b = RequestContext.generate(tenantId: 'beta');
      expect(a.requestId.startsWith('alpha-'), true);
      expect(b.requestId.startsWith('beta-'), true);
      expect(a.requestId.startsWith('beta-'), false);
    });
  });

  // === shortReference ===
  group('RequestContext — shortReference', () {
    test('shortReference is last segment of RID', () {
      final ctx = RequestContext.generate(tenantId: 'test');
      final lastPart = ctx.requestId.split('-').last;
      expect(ctx.shortReference, lastPart);
    });
  });

  // === createChildContext ===
  group('RequestContext.createChildContext', () {
    test('child has same tenantId', () {
      final parent = RequestContext.generate(
        tenantId: 'shop_1', userId: 'user_1');
      final child = parent.createChildContext();
      expect(child.tenantId, 'shop_1');
      expect(child.userId, 'user_1');
    });

    test('child has different requestId', () {
      final parent = RequestContext.generate(tenantId: 'shop_1');
      final child = parent.createChildContext();
      expect(child.requestId, isNot(equals(parent.requestId)));
    });

    test('child sessionRid defaults to parent requestId', () {
      final parent = RequestContext.generate(tenantId: 'shop_1');
      final child = parent.createChildContext();
      expect(child.sessionRid, parent.requestId);
    });

    test('child inherits parent sessionRid if set', () {
      final parent = RequestContext.generate(
        tenantId: 'shop_1', sessionRid: 'original-session');
      final child = parent.createChildContext();
      expect(child.sessionRid, 'original-session');
    });
  });

  // === RequestContext.inherit ===
  group('RequestContext.inherit', () {
    test('uses provided requestId directly', () {
      final ctx = RequestContext.inherit(
        requestId: 'custom-rid-123',
        tenantId: 'tenant_1',
        userId: 'user_1',
      );
      expect(ctx.requestId, 'custom-rid-123');
      expect(ctx.tenantId, 'tenant_1');
    });
  });

  // === toHeaders ===
  group('RequestContext.toHeaders', () {
    test('contains required headers', () {
      final ctx = RequestContext.generate(
        tenantId: 'shop_1', userId: 'user_1');
      final headers = ctx.toHeaders();
      expect(headers['X-Request-ID'], ctx.requestId);
      expect(headers['X-Tenant-ID'], 'shop_1');
    });
  });

  // === toLogMap ===
  group('RequestContext.toLogMap', () {
    test('contains all fields', () {
      final ctx = RequestContext.generate(
        tenantId: 'shop_1', userId: 'user_1', sessionRid: 'sess-1');
      final log = ctx.toLogMap();
      expect(log['requestId'], ctx.requestId);
      expect(log['tenantId'], 'shop_1');
      expect(log['userId'], 'user_1');
      expect(log['sessionRid'], 'sess-1');
      expect(log['startTime'], isA<String>());
      expect(log['duration'], isA<int>());
    });
  });

  // === duration ===
  group('RequestContext.duration', () {
    test('duration is non-negative', () {
      final ctx = RequestContext.generate(tenantId: 'test');
      expect(ctx.duration.inMilliseconds, greaterThanOrEqualTo(0));
    });
  });

  // === userErrorReference extension ===
  group('RequestContextExtension', () {
    test('userErrorReference contains shortReference', () {
      final ctx = RequestContext.generate(tenantId: 'test');
      expect(ctx.userErrorReference.contains(ctx.shortReference), true);
      expect(ctx.userErrorReference.startsWith('Reference: '), true);
    });
  });

  // === Monotonic timestamp ===
  group('RequestContext — timestamp monotonicity', () {
    test('sequential RIDs have non-decreasing timestamps', () {
      final rids = List.generate(
        50, (_) => RequestContext.generate(tenantId: 'test').requestId);
      int? prevTs;
      for (final rid in rids) {
        final afterTenant = rid.substring('test-'.length);
        final ts = int.parse(afterTenant.split('-').first);
        if (prevTs != null) {
          expect(ts, greaterThanOrEqualTo(prevTs));
        }
        prevTs = ts;
      }
    });
  });
}
