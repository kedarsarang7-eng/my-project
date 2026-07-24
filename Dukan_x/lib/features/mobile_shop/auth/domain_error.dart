/// MobileShop DomainError — Typed Error for Tenant/Policy Failures (Dart)
///
/// Provides structured, non-disclosing errors for auth/policy failures.
/// Guards and resolvers return these instead of raw exceptions.
///
/// Requirements: 5.9, 8.3–8.7
library;

/// Categories of domain-level errors produced by the tenant/policy layer.
enum DomainErrorKind {
  /// User is not authenticated (session missing/expired).
  sessionExpired,

  /// User is authenticated but session could not be loaded.
  sessionLoadFailed,

  /// Business type is not mobile_shop (wrong vertical).
  wrongBusinessType,

  /// Required capability/permission is missing.
  permissionDenied,

  /// Tenant context is unavailable (not yet resolved).
  contextUnavailable,
}

/// A structured domain error returned by [TenantContextResolver] and guards.
///
/// Carries enough information for the UI to render an actionable state
/// (signed-out, session-error, denied) without disclosing internal details.
class DomainError {
  /// The error category.
  final DomainErrorKind kind;

  /// A human-readable message (safe for UI display).
  final String message;

  /// Optional machine-readable code for programmatic handling.
  final String? code;

  const DomainError({required this.kind, required this.message, this.code});

  /// Session has expired or user is signed out.
  const DomainError.sessionExpired()
    : kind = DomainErrorKind.sessionExpired,
      message = 'Your session has expired. Please sign in again.',
      code = 'SESSION_EXPIRED';

  /// Session data could not be loaded.
  const DomainError.sessionLoadFailed()
    : kind = DomainErrorKind.sessionLoadFailed,
      message = 'Unable to load session. Please try again.',
      code = 'SESSION_LOAD_FAILED';

  /// Business type does not match mobile_shop.
  const DomainError.wrongBusinessType({String? actualType})
    : kind = DomainErrorKind.wrongBusinessType,
      message = 'This feature is only available for Mobile Shop businesses.',
      code = 'WRONG_BUSINESS_TYPE';

  /// Required permission is missing.
  const DomainError.permissionDenied({String? permission})
    : kind = DomainErrorKind.permissionDenied,
      message = 'You do not have permission to access this feature.',
      code = 'PERMISSION_DENIED';

  /// Tenant context has not been resolved.
  const DomainError.contextUnavailable()
    : kind = DomainErrorKind.contextUnavailable,
      message = 'Tenant context is not available.',
      code = 'CONTEXT_UNAVAILABLE';

  /// Whether this error represents a sign-out / session-gone condition.
  bool get isSessionGone =>
      kind == DomainErrorKind.sessionExpired ||
      kind == DomainErrorKind.sessionLoadFailed ||
      kind == DomainErrorKind.contextUnavailable;

  @override
  String toString() => 'DomainError($kind: $message)';
}
