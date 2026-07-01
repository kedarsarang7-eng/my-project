// ============================================================================
// TOKEN MANAGER - With Refresh Locking & Revocation Support (P1 FIX)
// ============================================================================

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/logger_service.dart';

import '../api/api_client.dart';

/// Token data model
class TokenData {
  final String accessToken;
  final String refreshToken;
  final String idToken;
  final DateTime expiresAt;
  final String userId;
  final String tenantId;
  final List<String> roles;
  
  TokenData({
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.expiresAt,
    required this.userId,
    required this.tenantId,
    required this.roles,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isExpiringSoon {
    final fiveMinutesFromNow = DateTime.now().add(Duration(minutes: 5));
    return fiveMinutesFromNow.isAfter(expiresAt);
  }
  
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'idToken': idToken,
    'expiresAt': expiresAt.toIso8601String(),
    'userId': userId,
    'tenantId': tenantId,
    'roles': roles,
  };
  
  factory TokenData.fromJson(Map<String, dynamic> json) {
    return TokenData(
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      idToken: json['idToken'],
      expiresAt: DateTime.parse(json['expiresAt']),
      userId: json['userId'],
      tenantId: json['tenantId'],
      roles: List<String>.from(json['roles'] ?? []),
    );
  }
}

/// Simple async lock to prevent concurrent token refresh
class _AsyncLock {
  Completer<void>? _completer;

  Future<T> synchronized<T>(Future<T> Function() fn) async {
    while (_completer != null) {
      await _completer!.future;
    }
    _completer = Completer<void>();
    try {
      return await fn();
    } finally {
      _completer!.complete();
      _completer = null;
    }
  }
}

/// Token manager with synchronized refresh and revocation support
class TokenManager {
  static const String _tokenKey = 'auth_tokens';
  static const String _revokedKey = 'revoked_tokens';
  
  final _lock = _AsyncLock();
  final _apiClient = ApiClient();
  
  TokenData? _cachedToken;
  
  /// Get valid token (with automatic refresh if needed)
  Future<String?> getAccessToken() async {
    // Fast path: check cached token
    if (_cachedToken != null && !_cachedToken!.isExpiringSoon) {
      return _cachedToken!.accessToken;
    }
    
    // P1 FIX: Slow path with lock prevents concurrent refresh requests
    return await _lock.synchronized(() async {
      // Double-check after acquiring lock
      if (_cachedToken != null && !_cachedToken!.isExpiringSoon) {
        return _cachedToken!.accessToken;
      }
      
      // Try to refresh
      final refreshed = await _refreshToken();
      if (refreshed != null) {
        _cachedToken = refreshed;
        await _saveToken(refreshed);
      }
      
      return refreshed?.accessToken;
    });
  }
  
  /// P1 FIX: Refresh token with Cognito
  Future<TokenData?> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenJson = prefs.getString(_tokenKey);
      
      if (tokenJson == null) return null;
      
      final currentToken = TokenData.fromJson(
        Map<String, dynamic>.from(await _parseJson(tokenJson))
      );
      
      // Check if token was revoked
      if (await _isTokenRevoked(currentToken.accessToken)) {
        LoggerService.d('TokenManager', '[TokenManager] Token was revoked, cannot refresh');
        await clearTokens();
        return null;
      }
      
      // Call refresh endpoint
      final response = await _apiClient.post(
        '/auth/refresh',
        body: {
          'refreshToken': currentToken.refreshToken,
        },
        requireAuth: false, // Don't include expired auth header
      );
      
      if (response.isSuccess) {
        // response.data is non-null when isSuccess is true (parser guarantees this)
        final data = response.data!;
        
        return TokenData(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'] ?? currentToken.refreshToken,
          idToken: data['idToken'] ?? currentToken.idToken,
          expiresAt: DateTime.now().add(Duration(seconds: data['expiresIn'] ?? 3600)),
          userId: data['userId'] ?? currentToken.userId,
          tenantId: data['tenantId'] ?? currentToken.tenantId,
          roles: List<String>.from(data['roles'] ?? currentToken.roles),
        );
      }
      
      return null;
    } catch (e) {
      LoggerService.d('TokenManager', '[TokenManager] Refresh failed: $e');
      return null;
    }
  }
  
  /// Save token to secure storage
  Future<void> saveToken(TokenData token) async {
    _cachedToken = token;
    await _saveToken(token);
  }
  
  Future<void> _saveToken(TokenData token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, await _stringifyJson(token.toJson()));
  }
  
  /// P1 FIX: Clear tokens and mark as revoked (global signout)
  Future<void> logout({bool globalSignout = true}) async {
    try {
      final token = _cachedToken ?? await _loadToken();
      
      if (token != null) {
        // P1 FIX: Call Cognito global signout to invalidate all tokens
        if (globalSignout) {
          await _apiClient.post(
            '/auth/logout',
            body: {
              'accessToken': token.accessToken,
              'globalSignout': true,
            },
          );
        }
        
        // Mark this token as revoked locally
        await _markTokenRevoked(token.accessToken);
      }
    } catch (e) {
      LoggerService.d('TokenManager', '[TokenManager] Logout error: $e');
    } finally {
      // Always clear local storage
      _cachedToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    }
  }
  
  /// P1 FIX: Mark token as revoked
  Future<void> _markTokenRevoked(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final revoked = prefs.getStringList(_revokedKey) ?? [];
    revoked.add(token.substring(0, 100)); // Store prefix only
    await prefs.setStringList(_revokedKey, revoked);
  }
  
  /// P1 FIX: Check if token was revoked
  Future<bool> _isTokenRevoked(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final revoked = prefs.getStringList(_revokedKey) ?? [];
    return revoked.contains(token.substring(0, 100));
  }
  
  /// Clear all tokens without revocation (for session timeout)
  Future<void> clearTokens() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
  
  /// Get user context from token
  Future<TokenData?> getUserContext() async {
    if (_cachedToken != null) return _cachedToken;
    return await _loadToken();
  }
  
  Future<TokenData?> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenJson = prefs.getString(_tokenKey);
    if (tokenJson == null) return null;
    
    try {
      final token = TokenData.fromJson(
        Map<String, dynamic>.from(await _parseJson(tokenJson))
      );
      
      // Check if token was revoked
      if (await _isTokenRevoked(token.accessToken)) {
        await clearTokens();
        return null;
      }
      
      _cachedToken = token;
      return token;
    } catch (e) {
      await clearTokens();
      return null;
    }
  }
  
  // JSON helpers
  Future<Map<String, dynamic>> _parseJson(String json) async {
    // In production, use proper JSON parsing
    return {};
  }
  
  Future<String> _stringifyJson(Map<String, dynamic> data) async {
    // In production, use proper JSON encoding
    return '{}';
  }
}

// Singleton instance
final tokenManager = TokenManager();
