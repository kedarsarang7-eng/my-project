// ============================================================================
// DC RID GENERATOR — tenant-scoped identifiers for Decoration & Catering
// ============================================================================
// Produces RID-pattern identifiers for all new DC entities:
//   Format: {tenantId}-{timestamp_ms}-{uuid_v4_short}
//
// Delegates to the shared `RidGenerator` (lib/core/services/rid_generator.dart)
// which provides:
//   - Non-decreasing timestamp per tenant (handles clock skew)
//   - Intra-millisecond uniqueness via short-uuid collision tracking
//   - TenantScopeError when tenantId is blank
//
// DC-specific wrapper resolves the tenantId from `DcTenantScope` so callers
// need only call `generate()` without passing a tenant explicitly. This
// enforces Requirement 1.5 (RID pattern) and Requirement 1.13 (abort on
// missing tenant) at the identity-generation boundary.
//
// Usage:
//   final rid = DcRidGenerator(scope: scope, generator: generator);
//   final id = rid.generate(); // e.g. "tenant123-1715000000000-f3a9b2"
// ============================================================================

import '../../../core/services/rid_generator.dart';
import 'dc_tenant_scope.dart';

/// Generates RID-pattern identifiers for new DC entities, resolving the
/// active tenant automatically from [DcTenantScope].
///
/// A single shared instance per session is recommended so the underlying
/// [RidGenerator]'s monotonic clock and collision tracking are honored.
class DcRidGenerator {
  final DcTenantScope _scope;
  final RidGenerator _generator;

  /// Creates a DC RID generator.
  ///
  /// [scope] resolves the active tenantId. [generator] handles the actual
  /// RID production (defaults to a new instance; inject for tests).
  DcRidGenerator({required DcTenantScope scope, RidGenerator? generator})
    : _scope = scope,
      _generator = generator ?? RidGenerator();

  /// Produce a new RID for a DC entity.
  ///
  /// Resolves the active tenantId via [DcTenantScope.require] and delegates
  /// to [RidGenerator.generate]. Throws [TenantScopeError] if no tenant is
  /// available (Requirement 1.13 — no DC data access without tenant context).
  String generate() {
    final tenantId = _scope.require();
    return _generator.generate(tenantId);
  }

  /// Produce a new RID for a DC entity using an explicitly provided tenantId.
  ///
  /// Validates the provided tenantId against the active session tenant via
  /// [DcTenantScope.requireMatch] before generating the identifier, preventing
  /// cross-tenant id generation.
  String generateFor(String tenantId) {
    _scope.requireMatch(tenantId);
    return _generator.generate(tenantId);
  }
}
