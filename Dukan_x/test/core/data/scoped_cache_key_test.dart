// Reproduction tests for D4 cache-key scoping (clauses 1.7, 2.7, 2.8).
//
// The single D4 inventory row covers the cross-cutting "scope cache keys
// with tenant / business-type / account" requirement from
// `tasks.md` § 3.2.4. These tests fail on F (no `ScopedCacheKey` type
// existed; bare-string keys leaked across tenants/accounts) and pass on
// F' (this file exercises the new typed key under
// `lib/core/data/scoped_cache_key.dart`).

import 'package:dukanx/core/data/scoped_cache_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScopedCacheKey', () {
    const a = ScopedCacheKey(
      tenantId: 't1',
      businessType: 'jewellery',
      accountId: 'acc1',
      resource: 'bills.list',
    );
    const aDup = ScopedCacheKey(
      tenantId: 't1',
      businessType: 'jewellery',
      accountId: 'acc1',
      resource: 'bills.list',
    );

    test('equal keys hash and compare equal', () {
      expect(a, aDup);
      expect(a.hashCode, aDup.hashCode);
    });

    test('different tenant produces a different key', () {
      const b = ScopedCacheKey(
        tenantId: 't2',
        businessType: 'jewellery',
        accountId: 'acc1',
        resource: 'bills.list',
      );
      expect(a, isNot(b));
    });

    test('different business type produces a different key', () {
      const b = ScopedCacheKey(
        tenantId: 't1',
        businessType: 'pharmacy',
        accountId: 'acc1',
        resource: 'bills.list',
      );
      expect(a, isNot(b));
    });

    test('different account produces a different key', () {
      const b = ScopedCacheKey(
        tenantId: 't1',
        businessType: 'jewellery',
        accountId: 'acc2',
        resource: 'bills.list',
      );
      expect(a, isNot(b));
    });

    test('canonical form is `tenant:bt:account:resource`', () {
      expect(a.canonical, 't1:jewellery:acc1:bills.list');
    });

    test('global key uses `*` placeholders in canonical form', () {
      const g = ScopedCacheKey.global(resource: 'route_table');
      expect(g.canonical, '*:*:*:route_table');
    });

    test('sub() appends a segment without losing scope', () {
      final p = a.sub('page=3');
      expect(p.tenantId, 't1');
      expect(p.businessType, 'jewellery');
      expect(p.accountId, 'acc1');
      expect(p.resource, 'bills.list:page=3');
      expect(p, isNot(a));
    });

    test('sub() with empty suffix returns the same key', () {
      expect(a.sub(''), a);
      expect(a.sub('   '), a);
    });

    test('keys are usable as Map keys (no cross-tenant leakage)', () {
      final cache = <ScopedCacheKey, String>{};
      cache[a] = 'tenant1-data';

      const otherTenant = ScopedCacheKey(
        tenantId: 't2',
        businessType: 'jewellery',
        accountId: 'acc1',
        resource: 'bills.list',
      );

      expect(cache[a], 'tenant1-data');
      expect(
        cache[otherTenant],
        isNull,
        reason: 'tenant scope must isolate entries',
      );
    });
  });
}
