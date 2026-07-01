// ============================================================================
// RID GENERATOR
// ============================================================================
// Produces tenant-scoped, time-ordered, unique resource identifiers in the RID
// pattern: {tenantId}-{timestamp_ms}-{uuid_v4_short}
//   Example: tenant_abc-1715000000000-f3a9b2
//
// Reuses the format established by RequestContext.generate
// (lib/core/request_context/request_context.dart) and the
// background_sync_rid_service pattern, but adds the guarantees mandated by
// Requirement 3 for newly created pharmacy entities:
//
//   R3.1  exactly three hyphen-separated segments in the order
//         {tenantId}-{timestamp_ms}-{uuid_v4_short}; segment 2 is integer ms
//         since the Unix epoch (UTC); segment 3 is a non-empty short uuid v4.
//   R3.3  two or more IDs for the same tenantId within the same millisecond are
//         pairwise distinct.
//   R3.4  IDs for the same tenantId sort by their timestamp_ms segment
//         consistently with their creation sequence (non-decreasing time).
//   R3.5  when the tenantId is unresolved, no ID is produced and a
//         TenantScopeError is thrown.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:uuid/uuid.dart';

import '../error/tenant_scope_error.dart';

/// Generates RID-pattern identifiers for new pharmacy entities.
///
/// A single shared instance should be used so the per-tenant monotonic clock
/// and intra-millisecond uniqueness tracking are honoured across all callers.
class RidGenerator {
  RidGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Length of the shortened uuid v4 segment (segment 3).
  static const int _shortUuidLength = 6;

  final Uuid _uuid;

  /// Highest timestamp_ms already emitted per tenant. Used to keep the
  /// timestamp segment non-decreasing so sort order matches creation order
  /// even if the system clock momentarily moves backwards (R3.4).
  final Map<String, int> _lastTimestampMs = {};

  /// Short-uuid segments already emitted for the current [_lastTimestampMs] of
  /// each tenant. Guarantees intra-millisecond uniqueness (R3.3).
  final Map<String, Set<String>> _usedShortsAtLastMs = {};

  /// Produce a RID for [tenantId].
  ///
  /// Throws [TenantScopeError] when [tenantId] is unresolved (empty or blank),
  /// without producing an identifier (R3.5).
  String generate(String tenantId) {
    final resolvedTenantId = tenantId.trim();
    if (resolvedTenantId.isEmpty) {
      throw TenantScopeError.unresolved(
        'Cannot generate an identifier without an active tenant.',
      );
    }

    final timestampMs = _nextTimestampMs(resolvedTenantId);
    final shortUuid = _uniqueShortUuid(resolvedTenantId);

    return '$resolvedTenantId-$timestampMs-$shortUuid';
  }

  /// Returns a non-decreasing millisecond timestamp for the tenant so that
  /// later calls never receive an earlier timestamp than earlier calls (R3.4).
  int _nextTimestampMs(String tenantId) {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final previousMs = _lastTimestampMs[tenantId];
    final timestampMs = (previousMs != null && nowMs < previousMs)
        ? previousMs
        : nowMs;

    if (previousMs == null || timestampMs != previousMs) {
      // Entered a new (or first) millisecond for this tenant: reset the set of
      // used short-uuid segments tracked for collision avoidance.
      _usedShortsAtLastMs[tenantId] = <String>{};
    }
    _lastTimestampMs[tenantId] = timestampMs;
    return timestampMs;
  }

  /// Generates a short uuid v4 segment that has not yet been used for the
  /// tenant within the current millisecond, guaranteeing distinct IDs (R3.3).
  String _uniqueShortUuid(String tenantId) {
    final used = _usedShortsAtLastMs[tenantId] ??= <String>{};
    String shortUuid;
    do {
      shortUuid = _uuid.v4().replaceAll('-', '').substring(0, _shortUuidLength);
    } while (used.contains(shortUuid));
    used.add(shortUuid);
    return shortUuid;
  }
}
