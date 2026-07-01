// Unit tests: RequestContext — EXTENDED edge cases
// Covers: malformed RID parsing, tenant isolation, concurrent generation,
// and edge-case tenantId formats.

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/request_context/request_context.dart';

void main() {
  // =========================================================================
  // Malformed RID → safe parsing (no uncaught exception)
  // =========================================================================
  group('RID parsing — malformed input safety', () {
    test('shortReference on RID with no dashes → returns full string', () {
      // If someone creates an inherit context with a bad rid, shortReference
      // should not crash.
      final ctx = RequestContext.inherit(
        requestId: 'nodashes',
        tenantId: 'test',
      );
      // split('-').last on 'nodashes' → 'nodashes'
      expect(ctx.shortReference, 'nodashes');
    });

    test('shortReference on empty requestId → returns empty', () {
      final ctx = RequestContext.inherit(
        requestId: '',
        tenantId: 'test',
      );
      expect(ctx.shortReference, '');
    });

    test('inherit with arbitrary string does not throw', () {
      expect(
        () => RequestContext.inherit(
          requestId: '!!!invalid!!!',
          tenantId: 'test',
        ),
        returnsNormally,
      );
    });

    test('toHeaders with null userId does not crash', () {
      final ctx = RequestContext.generate(
        tenantId: 'test',
        // userId is null
      );
      expect(() => ctx.toHeaders(), returnsNormally);
    });

    test('toLogMap with null sessionRid and userId', () {
      final ctx = RequestContext.generate(tenantId: 'test');
      final log = ctx.toLogMap();
      expect(log['userId'], isNull);
      expect(log['sessionRid'], isNull);
    });
  });

  // =========================================================================
  // Tenant isolation — RID prefixes never cross
  // =========================================================================
  group('RID tenant isolation', () {
    test('100 RIDs across 5 tenants — no prefix collision', () {
      final tenants = ['alpha', 'beta', 'gamma', 'delta', 'epsilon'];
      final ridsByTenant = <String, List<String>>{};

      for (final tenant in tenants) {
        ridsByTenant[tenant] = List.generate(
          20,
          (_) => RequestContext.generate(tenantId: tenant).requestId,
        );
      }

      // Every RID for tenant X starts with "X-"
      for (final tenant in tenants) {
        for (final rid in ridsByTenant[tenant]!) {
          expect(rid.startsWith('$tenant-'), true,
              reason: 'RID $rid should start with $tenant-');
        }
      }

      // No RID for tenant X starts with tenant Y
      for (var i = 0; i < tenants.length; i++) {
        for (var j = 0; j < tenants.length; j++) {
          if (i == j) continue;
          for (final rid in ridsByTenant[tenants[i]]!) {
            expect(rid.startsWith('${tenants[j]}-'), false,
                reason: '${tenants[i]} RID should not start with ${tenants[j]}');
          }
        }
      }
    });
  });

  // =========================================================================
  // Edge-case tenantId formats
  // =========================================================================
  group('RID — special tenantId formats', () {
    test('tenantId with dashes — RID still parseable', () {
      // e.g. "shop-pune-01"
      final ctx = RequestContext.generate(tenantId: 'shop-pune-01');
      expect(ctx.requestId.startsWith('shop-pune-01-'), true);
      expect(ctx.tenantId, 'shop-pune-01');
      // shortReference still works (last segment)
      expect(ctx.shortReference.length, 6);
    });

    test('very long tenantId → RID is still generated', () {
      final longTenant = 'a' * 200;
      final ctx = RequestContext.generate(tenantId: longTenant);
      expect(ctx.requestId.startsWith('$longTenant-'), true);
    });

    test('tenantId with unicode characters', () {
      final ctx = RequestContext.generate(tenantId: 'दुकान_१');
      expect(ctx.tenantId, 'दुकान_१');
      expect(ctx.requestId.startsWith('दुकान_१-'), true);
    });

    test('empty tenantId → generates RID starting with -', () {
      final ctx = RequestContext.generate(tenantId: '');
      expect(ctx.requestId.startsWith('-'), true);
    });
  });

  // =========================================================================
  // Concurrent generation — rapid-fire uniqueness
  // =========================================================================
  group('RID — rapid-fire uniqueness', () {
    test('1000 RIDs generated in tight loop — all unique', () {
      final rids = <String>{};
      for (var i = 0; i < 1000; i++) {
        rids.add(RequestContext.generate(tenantId: 'stress').requestId);
      }
      expect(rids.length, 1000);
    });

    test('child contexts in tight loop — all unique', () {
      final parent = RequestContext.generate(tenantId: 'parent');
      final childRids = <String>{};
      for (var i = 0; i < 500; i++) {
        childRids.add(parent.createChildContext().requestId);
      }
      expect(childRids.length, 500);
    });
  });

  // =========================================================================
  // Parsing a RID back → extract tenantId
  // =========================================================================
  group('RID — parsing tenantId from RID', () {
    test('simple tenantId can be extracted by removing timestamp+uuid', () {
      final ctx = RequestContext.generate(tenantId: 'tenant_abc');
      final rid = ctx.requestId;
      // For simple tenantIds (no dashes), the format is:
      // tenant_abc-{timestamp}-{uuid6}
      // tenantId is everything before the first dash-followed-by-digits
      final match = RegExp(r'^(.+)-(\d+)-([a-f0-9]{6})$').firstMatch(rid);
      expect(match, isNotNull);
      expect(match!.group(1), 'tenant_abc');
      expect(match.group(3)!.length, 6);
    });

    test('tenantId with dashes — regex still extracts correctly', () {
      final ctx = RequestContext.generate(tenantId: 'shop-pune-01');
      final rid = ctx.requestId;
      // For tenantIds with dashes, we need to match the timestamp pattern
      final match = RegExp(r'^(.+)-(\d{13,})-([a-f0-9]{6})$').firstMatch(rid);
      expect(match, isNotNull);
      expect(match!.group(1), 'shop-pune-01');
    });
  });

  // =========================================================================
  // toString
  // =========================================================================
  group('RequestContext.toString', () {
    test('contains requestId and tenantId', () {
      final ctx = RequestContext.generate(tenantId: 'shop_1');
      final str = ctx.toString();
      expect(str.contains(ctx.requestId), true);
      expect(str.contains('shop_1'), true);
    });
  });
}
