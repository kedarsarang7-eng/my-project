// ScopedCacheKey — typed cache key that scopes every entry with
// tenant + business-type + account.
//
// Per `bugfix.md` clause 1.7 / 2.7, repositories and providers must not
// leak data across tenants, business types or accounts. The previous
// pattern of using bare strings (`'bills'`, `'products_${userId}'`) is
// brittle: any caller can forget a scope dimension and silently produce
// a cross-account read. `ScopedCacheKey` makes the scope dimensions
// part of the type so the compiler refuses to construct an unscoped
// key.
//
// Usage:
//
//     final key = ScopedCacheKey(
//       tenantId: session.tenantId,
//       businessType: session.businessType.name,
//       accountId: session.ownerId,
//       resource: 'bills.list',
//     );
//
//     cache.read(key);
//     cache.write(key, bills);
//
// Equality + hashCode are stable across the four dimensions so the same
// key always maps to the same slot in any underlying `Map`. `toString()`
// renders the canonical `tenant:bt:account:resource` form so logs and
// debug surfaces are easy to grep.
//
// `ScopedCacheKey.empty(resource: ...)` exists for the narrow set of
// resources that are intentionally global (build constants, route
// metadata) — they must opt into being unscoped.

import 'package:flutter/foundation.dart';

/// Stable identifier for a cache entry, scoped to (tenant, businessType,
/// account, resource). Use `ScopedCacheKey.empty` only for genuinely
/// global resources.
@immutable
class ScopedCacheKey {
  const ScopedCacheKey({
    required this.tenantId,
    required this.businessType,
    required this.accountId,
    required this.resource,
  });

  /// Construct a deliberately-global key (no tenant/business/account
  /// scope). Reserved for build constants, route metadata, and other
  /// resources that are identical for every user.
  const ScopedCacheKey.global({required this.resource})
    : tenantId = '',
      businessType = '',
      accountId = '';

  /// Tenant id (DynamoDB partition). Empty string means global scope.
  final String tenantId;

  /// Business type (e.g. `jewellery`, `pharmacy`). Empty string means
  /// the resource is shared across business types.
  final String businessType;

  /// Account / owner id. Empty string means the resource is shared
  /// across accounts within the tenant.
  final String accountId;

  /// Resource identifier within the scope (e.g. `bills.list`,
  /// `products.byHsn`).
  final String resource;

  /// Render a sub-key by appending an extra segment. Useful for paginated
  /// or parameterized reads — e.g. `key.sub('page=3')`.
  ScopedCacheKey sub(String suffix) {
    final s = suffix.trim();
    if (s.isEmpty) return this;
    return ScopedCacheKey(
      tenantId: tenantId,
      businessType: businessType,
      accountId: accountId,
      resource: '$resource:$s',
    );
  }

  /// Canonical string form: `tenant:bt:account:resource`.
  String get canonical =>
      '${_or(tenantId, '*')}:${_or(businessType, '*')}:'
      '${_or(accountId, '*')}:$resource';

  static String _or(String s, String fallback) => s.isEmpty ? fallback : s;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScopedCacheKey &&
        other.tenantId == tenantId &&
        other.businessType == businessType &&
        other.accountId == accountId &&
        other.resource == resource;
  }

  @override
  int get hashCode => Object.hash(tenantId, businessType, accountId, resource);

  @override
  String toString() => 'ScopedCacheKey($canonical)';
}
