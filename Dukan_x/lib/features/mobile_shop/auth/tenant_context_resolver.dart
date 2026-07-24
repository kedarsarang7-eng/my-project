/// MobileShop TenantContextResolver — Single Source of Identity (Dart)
///
/// Abstract interface + default implementation that resolves one authoritative
/// [TenantContext] from SessionManager. ALL screens, repositories, sync
/// coordinators, guards, quick actions, deep links, and named routes MUST
/// use this resolver — never direct Firebase/AuthService calls.
///
/// Fixes AF-13, AF-37: sibling screens using different identity resolution.
///
/// Requirements: 2.1–2.4, 5.8–5.9, 8.3–8.7
library;

import 'package:uuid/uuid.dart';

import '../../../core/session/session_manager.dart';
import '../permissions/compatibility_matrix.dart';
import '../permissions/permission_checker.dart';
import 'business_type.dart';
import 'domain_error.dart';
import 'tenant_context.dart';

// Re-export for convenience
export 'business_type.dart';
export 'domain_error.dart';
export 'tenant_context.dart';

/// Functional result type: either a value or a domain error.
///
/// Uses the sealed-class pattern from `packages/shared_core`.
sealed class TenantResult<T> {
  const TenantResult();
}

/// Successful resolution.
final class TenantSuccess<T> extends TenantResult<T> {
  final T value;
  const TenantSuccess(this.value);
}

/// Failed resolution with a typed domain error.
final class TenantFailure<T> extends TenantResult<T> {
  final DomainError error;
  const TenantFailure(this.error);
}

/// Extension helpers for [TenantResult].
extension TenantResultX<T> on TenantResult<T> {
  bool get isSuccess => this is TenantSuccess<T>;
  bool get isFailure => this is TenantFailure<T>;

  T? get valueOrNull => switch (this) {
    TenantSuccess(:final value) => value,
    TenantFailure() => null,
  };

  DomainError? get errorOrNull => switch (this) {
    TenantSuccess() => null,
    TenantFailure(:final error) => error,
  };

  R when<R>({
    required R Function(T value) success,
    required R Function(DomainError error) failure,
  }) => switch (this) {
    TenantSuccess(:final value) => success(value),
    TenantFailure(:final error) => failure(error),
  };
}

// ─── Interface ───────────────────────────────────────────────────────────────

/// The single authoritative interface for resolving tenant context.
///
/// All screens, repositories, sync coordinators, guards, sidebar dispatch,
/// quick actions, deep links, and named routes MUST use this interface.
abstract interface class TenantContextResolver {
  /// Returns mobile shop context or a typed domain error.
  ///
  /// Fails if:
  /// - Session is missing/expired → [DomainErrorKind.sessionExpired]
  /// - Business type is not mobile_shop → [DomainErrorKind.wrongBusinessType]
  TenantResult<TenantContext> requireMobileShop();

  /// Returns tenant context for any business type, or error if not authenticated.
  ///
  /// Use for shared screens that work across business types.
  TenantResult<TenantContext> require();

  /// Returns the current cached context, or null if not authenticated.
  ///
  /// Useful for guards that need to check without throwing.
  TenantContext? get current;

  /// Invalidates the cached context (call on sign-out or tenant switch).
  void invalidate();
}

// ─── Implementation ──────────────────────────────────────────────────────────

/// Default implementation that reads from [SessionManager] and caches
/// the resolved [TenantContext] per session lifecycle.
///
/// Resolution pipeline:
/// 1. Check SessionManager for authenticated session
/// 2. Extract tenantId, businessId, subjectId from session
/// 3. Normalize businessType via [MobileShopBusinessType.fromWireValue]
/// 4. Resolve permissions through the compatibility matrix
/// 5. Generate a correlation ID (UUID v4)
/// 6. Cache per session lifecycle
class DefaultTenantContextResolver implements TenantContextResolver {
  final SessionManager _sessionManager;
  final Uuid _uuid;

  /// Cached context; invalidated on sign-out or tenant switch.
  TenantContext? _cached;

  /// The session ID (odId) associated with the cached context.
  /// If the session changes, the cache is invalidated automatically.
  String? _cachedForSessionId;

  DefaultTenantContextResolver({
    required SessionManager sessionManager,
    Uuid? uuid,
  }) : _sessionManager = sessionManager,
       _uuid = uuid ?? const Uuid();

  @override
  TenantContext? get current {
    _ensureCacheValid();
    return _cached;
  }

  @override
  TenantResult<TenantContext> require() {
    _ensureCacheValid();

    final session = _sessionManager.currentSession;

    // Not authenticated
    if (!session.isAuthenticated) {
      _cached = null;
      return const TenantFailure(DomainError.sessionExpired());
    }

    // Already cached for this session
    if (_cached != null) {
      return TenantSuccess(_cached!);
    }

    // Resolve fresh context
    final context = _resolve(session);
    if (context == null) {
      return const TenantFailure(DomainError.sessionLoadFailed());
    }

    _cached = context;
    _cachedForSessionId = session.odId;
    return TenantSuccess(context);
  }

  @override
  TenantResult<TenantContext> requireMobileShop() {
    final result = require();
    return result.when(
      success: (context) {
        if (!context.isMobileShop) {
          return const TenantFailure(DomainError.wrongBusinessType());
        }
        return TenantSuccess(context);
      },
      failure: (error) => TenantFailure(error),
    );
  }

  @override
  void invalidate() {
    _cached = null;
    _cachedForSessionId = null;
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  /// Auto-invalidate if the underlying session changed.
  void _ensureCacheValid() {
    final session = _sessionManager.currentSession;
    if (!session.isAuthenticated) {
      _cached = null;
      _cachedForSessionId = null;
      return;
    }
    if (_cachedForSessionId != null && _cachedForSessionId != session.odId) {
      // Session user changed → invalidate
      _cached = null;
      _cachedForSessionId = null;
    }
  }

  /// Resolves a [TenantContext] from the current [UserSession].
  TenantContext? _resolve(UserSession session) {
    if (!session.isAuthenticated || session.odId.isEmpty) {
      return null;
    }

    // Derive tenant/business identifiers
    final tenantId = session.ownerId ?? session.odId;
    final businessId =
        session.activeBusinessId ?? session.ownerId ?? session.odId;
    final subjectId = session.odId;

    // Normalize business type
    final rawBusinessType = session.businessType?.name ?? 'other';
    final businessType = MobileShopBusinessType.fromWireValue(rawBusinessType);

    // Resolve permissions through compatibility matrix
    final permissions = _resolvePermissions(session, businessType);

    // Generate correlation ID
    final correlationId = _uuid.v4();

    return TenantContext(
      tenantId: tenantId,
      businessId: businessId,
      subjectId: subjectId,
      businessType: businessType,
      permissions: permissions,
      correlationId: correlationId,
    );
  }

  /// Resolves the effective permission set using the compatibility matrix.
  ///
  /// For mobile shop tenants: migrates legacy role/capabilities to
  /// dedicated MobileShop permissions and expands implications.
  Set<String> _resolvePermissions(
    UserSession session,
    MobileShopBusinessType businessType,
  ) {
    if (!businessType.isMobileShop) {
      // Non-mobile-shop paths get an empty mobile permission set.
      // Their existing permission checks are unchanged.
      return const {};
    }

    // Determine the effective role name for the compatibility matrix
    final effectiveRole = session.effectiveRole;
    final roleName = effectiveRole.name;

    // Gather existing permissions from the session
    final existingPermissions = session.staffPermissions
        .map((p) => p.name)
        .toList();

    // Use the compatibility matrix to migrate/expand permissions
    final migrationResult = migratePermissions(
      currentPermissions: existingPermissions,
      role: roleName,
      capabilities: _extractCapabilities(session),
    );

    // Expand manage-implies-view
    return expandPermissions(migrationResult.permissions);
  }

  /// Extracts legacy capability strings from session metadata.
  List<String> _extractCapabilities(UserSession session) {
    final metadata = session.metadata;
    if (metadata == null) return const [];

    final capabilities = <String>[];

    // Check for known capability flags in metadata
    const capabilityKeys = [
      'useIMEI',
      'useWarranty',
      'useBuyback',
      'useExchange',
      'useJobSheets',
      'useRepairStatus',
    ];

    for (final key in capabilityKeys) {
      if (metadata[key] == true || metadata[key] == 'true') {
        capabilities.add(key);
      }
    }

    // Also check nested capabilities map
    final caps = metadata['capabilities'];
    if (caps is Map) {
      for (final entry in caps.entries) {
        if (entry.value == true || entry.value == 'true') {
          capabilities.add(entry.key.toString());
        }
      }
    }

    return capabilities;
  }
}
