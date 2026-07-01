// ============================================================================
// TENANT SCOPE — active-tenant resolution chokepoint
// ============================================================================
// Thin, testable wrapper over `SessionManager` that resolves the active
// tenantId (`SessionManager.currentBusinessId`) and raises a consistent
// authorization error (`TenantScopeError`) when it is absent.
//
// This is the SINGLE authorization-error chokepoint that changed pharmacy
// read/write paths use so the cross-cutting tenant rules (Requirement 1) hold
// uniformly:
//   - R1.1 / R1.2 / R1.4 : callers resolve the active tenantId via `require()`
//                          to scope every read filter and every write.
//   - R1.3               : a missing active tenantId → `TenantScopeError`.
//   - R1.5               : `requireMatch()` rejects a requested tenantId that
//                          differs from the active tenantId without reading or
//                          mutating the targeted records.
//
// Pharmacy-scoped utility: only changed pharmacy code paths use this; the
// other 18 verticals are untouched (Requirement 5.3).
// ============================================================================

import '../../../core/di/service_locator.dart';
import '../../../core/error/tenant_scope_error.dart';
import '../../../core/session/session_manager.dart';

// Re-export the canonical error so a single import gives callers both the
// accessor and the error.
export '../../../core/error/tenant_scope_error.dart';

/// Resolves the active tenantId from the authenticated session and enforces
/// the tenant-scope rules at one chokepoint.
///
/// Construct with the default constructor to use the app's `SessionManager`
/// from the service locator, or inject one for tests:
///
/// ```dart
/// final scope = TenantScope();            // production
/// final scope = TenantScope(session: fake); // tests
/// ```
class TenantScope {
  final SessionManager _session;

  /// Creates a tenant-scope accessor.
  ///
  /// [session] defaults to the DI-registered `SessionManager`. It is injectable
  /// purely to keep the accessor unit-testable without the service locator.
  TenantScope({SessionManager? session})
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
  /// missing (Requirement 1.3).
  ///
  /// This is the method changed read/write paths call before scoping a query
  /// or persisting a record, so a missing tenant consistently rejects the
  /// operation with an authorization error and leaves data unchanged.
  String require() {
    final id = tryResolve();
    if (id == null) {
      throw const TenantScopeError.missing();
    }
    return id;
  }

  /// Validates that [requestedTenantId] equals the active tenantId and returns
  /// it; throws [TenantScopeError] otherwise (Requirements 1.3, 1.5).
  ///
  /// - Missing active tenantId → [TenantScopeErrorKind.missingTenant].
  /// - Requested tenantId (non-blank) different from active → mismatch.
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
