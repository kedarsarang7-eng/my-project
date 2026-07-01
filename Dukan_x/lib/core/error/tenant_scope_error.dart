// ============================================================================
// TENANT SCOPE ERROR
// ============================================================================
// Single, canonical authorization error raised when the active tenantId cannot
// be resolved, or when an operation requests a tenantId that is not the active
// tenant. Centralizing this type keeps the multi-tenant isolation constraint
// (Requirements 1.3, 1.5) and the RID generation constraint (Requirement 3.5)
// consistent across every changed pharmacy code path.
//
// This is the ONLY definition of `TenantScopeError`. Both consumers import it:
//   - `RidGenerator` (lib/core/services/rid_generator.dart) for R3.5 via
//     `TenantScopeError.unresolved(...)`.
//   - `TenantScope`  (lib/features/pharmacy/utils/tenant_scope.dart) for
//     R1.3 / R1.5 via `TenantScopeError.missing()` and
//     `TenantScopeError.mismatch(...)`. That file re-exports this one so a
//     single import gives callers both the accessor and the error.
//
// Do NOT create a second `TenantScopeError` elsewhere. Import this one.
//
// Callers translate this error into a user-facing "tenant context unavailable /
// not permitted" message. When this error is raised, no data is read or written.
//
// Author: DukanX Engineering
// Version: 2.0.0
// ============================================================================

/// Distinguishes the two tenant-scope failure modes so callers (and tests) can
/// react precisely while still treating both as a single authorization error.
enum TenantScopeErrorKind {
  /// No active tenantId could be resolved from the authenticated session
  /// (Requirement 1.3, Requirement 3.5). Covers both the "unresolved" and
  /// "missing" cases.
  missingTenant,

  /// A requested tenantId did not match the active tenantId
  /// (Requirement 1.5). Covers both the "mismatch" and "violation" cases.
  tenantMismatch,
}

/// Authorization error for tenant-scope problems.
///
/// Raised when:
/// - the active tenantId is unresolved (missing/blank) —
///   [TenantScopeErrorKind.missingTenant]
/// - a foreign tenantId is requested —
///   [TenantScopeErrorKind.tenantMismatch]
///
/// Carrying a typed [kind] keeps the message consistent while letting callers
/// branch on the cause without string matching. A stable [code] is also
/// provided for programmatic handling/logging.
class TenantScopeError implements Exception {
  /// Which tenant-scope rule was violated.
  final TenantScopeErrorKind kind;

  /// Stable error code for programmatic handling.
  final String code;

  /// Human-readable, user-translatable message.
  final String message;

  /// The tenantId the operation requested, when the failure is a mismatch.
  final String? requestedTenantId;

  /// The active tenantId, when known (populated for [TenantScopeError.violation]).
  final String? activeTenantId;

  /// General-purpose const constructor. Prefer the named constructors below.
  const TenantScopeError({
    required this.kind,
    required this.code,
    required this.message,
    this.requestedTenantId,
    this.activeTenantId,
  });

  /// The active tenantId could not be resolved from the session
  /// (Requirement 3.5). Used by `RidGenerator`.
  const TenantScopeError.unresolved([String? details])
    : kind = TenantScopeErrorKind.missingTenant,
      code = 'TENANT_SCOPE_MISSING',
      message =
          details ?? 'Active tenant scope is missing or could not be resolved.',
      requestedTenantId = null,
      activeTenantId = null;

  /// Convenience constructor for the "no resolvable active tenantId" case
  /// (Requirement 1.3 / 3.5). Used by `TenantScope.require()` in a const
  /// context. Equivalent in [kind] to [TenantScopeError.unresolved].
  const TenantScopeError.missing([
    this.message =
        'Tenant scope is missing: no active tenantId could be '
        'resolved from the authenticated session.',
  ]) : kind = TenantScopeErrorKind.missingTenant,
       code = 'TENANT_SCOPE_MISSING',
       requestedTenantId = null,
       activeTenantId = null;

  /// Convenience constructor for the "requested tenantId != active tenantId"
  /// case (Requirement 1.5). Used by `TenantScope.requireMatch()`.
  const TenantScopeError.mismatch(
    this.requestedTenantId, [
    this.message =
        'Tenant-scope violation: the requested tenant does not '
        'match the active tenant.',
  ]) : kind = TenantScopeErrorKind.tenantMismatch,
       code = 'TENANT_SCOPE_VIOLATION',
       activeTenantId = null;

  /// A tenantId other than the active tenantId was requested, with both the
  /// requested and active tenantIds known. Kept for completeness.
  /// Equivalent in [kind] to [TenantScopeError.mismatch].
  const TenantScopeError.violation({
    required this.requestedTenantId,
    required this.activeTenantId,
  }) : kind = TenantScopeErrorKind.tenantMismatch,
       code = 'TENANT_SCOPE_VIOLATION',
       message =
           'Requested tenant "$requestedTenantId" does not match the '
           'active tenant.';

  @override
  String toString() =>
      'TenantScopeError[$code] (${kind.name}): $message'
      '${requestedTenantId != null ? ' [requested=$requestedTenantId]' : ''}';
}
