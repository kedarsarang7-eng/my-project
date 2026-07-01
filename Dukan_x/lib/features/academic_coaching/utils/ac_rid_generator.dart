// ============================================================================
// AC RID GENERATOR — tenant-scoped identifiers for School ERP (Academic Coaching)
// ============================================================================
// Produces RID-pattern identifiers for all new School_System entities:
//   Format: {tenantId}-{timestamp_ms}-{uuid_v4_short}
//
// Delegates to the shared `RidGenerator` (lib/core/services/rid_generator.dart)
// which provides:
//   - Non-decreasing timestamp per tenant (handles clock skew)
//   - Intra-millisecond uniqueness via short-uuid collision tracking
//   - TenantScopeError when tenantId is blank
//
// School-specific wrapper resolves the tenantId from `SessionManager` so
// callers need only call `generate()` without passing a tenant explicitly.
// This enforces Requirement 1.4 (RID pattern) and Requirement 1.7 (abort on
// missing tenant) at the identity-generation boundary.
//
// Usage:
//   final ridGenerator = AcRidGenerator();
//   final id = ridGenerator.generate(); // e.g. "tenant123-1715000000000-f3a9b2"
//
// NOTE: Currently no client-side entity-id generation exists in School_System
// (all ids are server-generated). This utility is provided for future use when
// client-side id generation is needed (e.g., offline-first creates via the
// Drift cache and sync queue).
// ============================================================================

import '../../../core/di/service_locator.dart';
import '../../../core/error/tenant_scope_error.dart';
import '../../../core/services/rid_generator.dart';
import '../../../core/session/session_manager.dart';

// Re-export the canonical error so a single import gives callers both the
// generator and the error type.
export '../../../core/error/tenant_scope_error.dart';

/// Generates RID-pattern identifiers for new School_System entities, resolving
/// the active tenant automatically from [SessionManager].
///
/// A single shared instance per session is recommended so the underlying
/// [RidGenerator]'s monotonic clock and collision tracking are honored.
class AcRidGenerator {
  final SessionManager _session;
  final RidGenerator _generator;

  /// Creates a School_System RID generator.
  ///
  /// [session] defaults to the DI-registered `SessionManager`. It is injectable
  /// purely to keep the generator unit-testable without the service locator.
  /// [generator] handles the actual RID production (defaults to a new instance;
  /// inject for tests).
  AcRidGenerator({SessionManager? session, RidGenerator? generator})
    : _session = session ?? sl<SessionManager>(),
      _generator = generator ?? RidGenerator();

  /// Resolve the active tenantId from the authenticated session.
  ///
  /// Returns `null` when the tenant cannot be resolved (blank/whitespace-only).
  String? tryResolveTenant() {
    final id = _session.currentBusinessId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Resolve the active tenantId or throw [TenantScopeError] when it is
  /// missing (Requirement 1.7).
  ///
  /// This is the method all School_System write paths should call before
  /// generating an id, so a missing tenant consistently rejects the operation
  /// with an authorization error and leaves data unchanged.
  String requireTenant() {
    final id = tryResolveTenant();
    if (id == null) {
      throw const TenantScopeError.missing(
        'Tenant context unavailable: no active tenantId could be resolved '
        'from the authenticated session. School data access aborted.',
      );
    }
    return id;
  }

  /// Produce a new RID for a School_System entity.
  ///
  /// Resolves the active tenantId via [requireTenant] and delegates to
  /// [RidGenerator.generate]. Throws [TenantScopeError] if no tenant is
  /// available (Requirement 1.7 — no school data write without tenant context).
  String generate() {
    final tenantId = requireTenant();
    return _generator.generate(tenantId);
  }

  /// Produce a new RID for a School_System entity using an explicitly provided
  /// tenantId.
  ///
  /// Validates the provided tenantId is not empty before generating the
  /// identifier, preventing generation without tenant context.
  String generateFor(String tenantId) {
    final resolved = tenantId.trim();
    if (resolved.isEmpty) {
      throw const TenantScopeError.missing(
        'Cannot generate a School_System RID with an empty tenantId.',
      );
    }
    return _generator.generate(resolved);
  }

  /// True when an active tenantId can be resolved.
  bool get hasTenant => tryResolveTenant() != null;
}
