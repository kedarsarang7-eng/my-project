// ============================================================================
// DC TENANT SCOPE — active-tenant resolution for Decoration & Catering
// ============================================================================
// Thin, testable wrapper over `SessionManager` that resolves the active
// tenantId (`SessionManager.currentBusinessId`) and raises a consistent
// authorization error (`TenantScopeError`) when it is absent.
//
// This is the SINGLE authorization-error chokepoint that all DC read/write
// paths use so the cross-cutting tenant rules (Requirement 1) hold uniformly:
//   - R1.1 / R1.2 : callers resolve the active tenantId via `require()`
//                    to scope every query, write, and cache key.
//   - R1.13       : a missing active tenantId → `TenantScopeError`; no DC
//                    data is accessed.
//   - The literal `vendorId: 'SYSTEM'` is NEVER used.
//
// DC-scoped utility: only changed DC code paths use this; other verticals
// are untouched.
// ============================================================================

import '../../../core/di/service_locator.dart';
import '../../../core/error/tenant_scope_error.dart';
import '../../../core/session/session_manager.dart';

// Re-export the canonical error so a single import gives callers both the
// accessor and the error.
export '../../../core/error/tenant_scope_error.dart';

/// Resolves the active tenantId from the authenticated session and enforces
/// the tenant-scope rules at one chokepoint for the DC vertical.
///
/// Construct with the default constructor to use the app's `SessionManager`
/// from the service locator, or inject one for tests:
///
/// ```dart
/// final scope = DcTenantScope();               // production
/// final scope = DcTenantScope(session: fake);  // tests
/// ```
class DcTenantScope {
  final SessionManager _session;

  /// Creates a DC tenant-scope accessor.
  ///
  /// [session] defaults to the DI-registered `SessionManager`. It is injectable
  /// purely to keep the accessor unit-testable without the service locator.
  DcTenantScope({SessionManager? session})
    : _session = session ?? sl<SessionManager>();

  /// Returns the active tenantId, or `null` when none can be resolved.
  ///
  /// A blank/whitespace-only business id is treated as unresolved so callers
  /// never scope a query to an empty tenant. Use this when the caller wants to
  /// branch on availability (e.g. a UI showing a "tenant unavailable" state)
  /// rather than throw.
  String? tryResolve() {
    final id = _session.currentBusinessId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Returns the active tenantId or throws [TenantScopeError] when it is
  /// missing (Requirement 1.13).
  ///
  /// This is the method all DC read/write paths call before scoping a query
  /// or persisting a record, so a missing tenant consistently rejects the
  /// operation with an authorization error and leaves data unchanged.
  ///
  /// The literal `vendorId: 'SYSTEM'` is never returned — the resolved value
  /// comes exclusively from `SessionManager.currentBusinessId`.
  String require() {
    final id = tryResolve();
    if (id == null) {
      throw const TenantScopeError.missing(
        'Tenant context unavailable: no active tenantId could be resolved '
        'from the authenticated session. DC data access aborted.',
      );
    }
    return id;
  }

  /// Validates that [requestedTenantId] equals the active tenantId and returns
  /// it; throws [TenantScopeError] otherwise (Requirements 1.1, 1.2).
  ///
  /// Call this on any operation that accepts an explicit tenantId before
  /// reading or mutating the targeted records, so a cross-tenant request is
  /// rejected without touching data.
  String requireMatch(String? requestedTenantId) {
    final active = require();
    final requested = requestedTenantId?.trim();
    if (requested != null && requested.isNotEmpty && requested != active) {
      throw TenantScopeError.mismatch(requested);
    }
    return active;
  }

  /// True when an active tenantId can be resolved.
  bool get hasTenant => tryResolve() != null;
}
