// ============================================================================
// RESTAURANT TENANT SCOPE — active-tenant resolution for Restaurant vertical
// ============================================================================
// Thin, testable wrapper over `SessionManager` that resolves the active
// tenantId using a TWO-TIER strategy:
//   1. `SessionManager.currentBusinessId` (primary)
//   2. `SessionManager.userId` (fallback only when businessId is null)
//
// Raises a consistent authorization error (`TenantScopeError`) when neither
// tier resolves.
//
// This is the SINGLE authorization-error chokepoint that all restaurant
// read/write paths use so the cross-cutting tenant rules hold uniformly:
//   - R2.1 : vendorId resolved from real session, never 'SYSTEM'
//   - R2.2 : fail-closed on unresolvable tenant (throw in debug, error screen
//            in release)
//   - R2.3 : same resolution for GoRouter routes (collapsed into sidebar
//            handler)
//
// The literal `vendorId: 'SYSTEM'` is NEVER used or returned.
//
// Restaurant-scoped utility: only restaurant code paths use this; other
// verticals are untouched.
// ============================================================================

import '../../../core/di/service_locator.dart';
import '../../../core/error/tenant_scope_error.dart';
import '../../../core/session/session_manager.dart';

// Re-export the canonical error so a single import gives callers both the
// accessor and the error.
export '../../../core/error/tenant_scope_error.dart';

/// Resolves the active tenantId from the authenticated session using a
/// two-tier strategy for the Restaurant vertical.
///
/// Resolution order:
///   1. `SessionManager.currentBusinessId` (trimmed, blank-safe)
///   2. `SessionManager.userId` (trimmed, blank-safe) — only if tier 1 is null
///   3. Throw [TenantScopeError] — no valid id resolved
///
/// Construct with the default constructor to use the app's `SessionManager`
/// from the service locator, or inject one for tests:
///
/// ```dart
/// final scope = RestaurantTenantScope();               // production
/// final scope = RestaurantTenantScope(session: fake);  // tests
/// ```
class RestaurantTenantScope {
  final SessionManager _session;

  /// Creates a Restaurant tenant-scope accessor.
  ///
  /// [session] defaults to the DI-registered `SessionManager`. It is injectable
  /// purely to keep the accessor unit-testable without the service locator.
  RestaurantTenantScope({SessionManager? session})
    : _session = session ?? sl<SessionManager>();

  /// Returns the active tenantId using two-tier resolution, or `null` when
  /// neither tier can be resolved.
  ///
  /// Resolution order:
  ///   1. `currentBusinessId?.trim()` — blank/whitespace-only treated as null
  ///   2. `userId?.trim()` — blank/whitespace-only treated as null
  ///
  /// A blank/whitespace-only id is treated as unresolved so callers never
  /// scope a query to an empty tenant. Use this when the caller wants to
  /// branch on availability (e.g. a UI showing a "tenant unavailable" state)
  /// rather than throw.
  String? tryResolve() {
    // Tier 1: currentBusinessId
    final businessId = _session.currentBusinessId?.trim();
    if (businessId != null && businessId.isNotEmpty) return businessId;

    // Tier 2: userId (fallback only when businessId is null/blank)
    final userId = _session.userId?.trim();
    if (userId != null && userId.isNotEmpty) return userId;

    return null;
  }

  /// Returns the active tenantId or throws [TenantScopeError] when neither
  /// tier resolves (Requirement 2.2).
  ///
  /// This is the method all restaurant navigation/read/write paths call before
  /// constructing a screen or scoping a query, so a missing tenant consistently
  /// rejects the operation with an authorization error and leaves data
  /// unchanged.
  ///
  /// The literal `vendorId: 'SYSTEM'` is never returned — the resolved value
  /// comes exclusively from the two-tier session resolution.
  String require() {
    final id = tryResolve();
    if (id == null) {
      throw const TenantScopeError.missing(
        'Tenant context unavailable: no active tenantId could be resolved '
        'from the authenticated session (neither currentBusinessId nor userId '
        'present). Restaurant data access aborted.',
      );
    }
    return id;
  }

  /// True when an active tenantId can be resolved via either tier.
  bool get hasTenant => tryResolve() != null;
}
