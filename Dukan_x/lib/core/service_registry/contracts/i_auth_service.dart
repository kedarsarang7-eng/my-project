// ============================================================================
// IAuthService — Authentication Contract
// ============================================================================
// Both online (Cognito) and offline (local password vault) providers must
// implement this interface identically. Business code receives an `AuthToken`
// regardless of which provider produced it.
// ============================================================================

import 'dart:async';

/// Opaque-to-caller credentials returned by an auth provider.
///
/// In online mode this wraps a Cognito JWT (id+access+refresh). In offline
/// mode this wraps a locally-issued HMAC-signed token tied to the device
/// fingerprint. Callers MUST NOT inspect the token contents — use
/// [IAuthService.verify] instead.
class AuthToken {
  final String accessToken;
  final String? idToken;
  final String? refreshToken;
  final DateTime expiresAt;

  /// Free-form provider-specific metadata (groups, custom attrs, etc.).
  final Map<String, dynamic> metadata;

  const AuthToken({
    required this.accessToken,
    required this.expiresAt,
    this.idToken,
    this.refreshToken,
    this.metadata = const {},
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Verified user identity claims, mode-independent shape.
class UserClaims {
  final String userId;
  final String email;
  final String? phone;
  final List<String> groups;
  final String? businessId;
  final Map<String, dynamic> custom;

  const UserClaims({
    required this.userId,
    required this.email,
    this.phone,
    this.groups = const [],
    this.businessId,
    this.custom = const {},
  });
}

/// Authentication contract — implemented by `CognitoAuthProvider` (online)
/// and `LocalVaultAuthProvider` (offline).
abstract class IAuthService {
  /// Sign in with email/password. Throws [AuthException] on failure.
  Future<AuthToken> login(String email, String password);

  /// Validate a token and decode its claims.
  Future<UserClaims> verify(String accessToken);

  /// Exchange a refresh token for a new access token.
  Future<AuthToken> refresh(String refreshToken);

  /// Revoke a session.
  Future<void> logout(String accessToken);

  /// Hot-swap entry point used by `ServiceRegistry.reinitialize()`.
  /// Default no-op; overridden where the provider holds resources.
  Future<void> dispose() async {}
}

class AuthException implements Exception {
  final String code;
  final String message;
  const AuthException(this.code, this.message);
  @override
  String toString() => 'AuthException($code): $message';
}
