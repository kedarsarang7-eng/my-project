// ============================================
// P1-003: Token Manager — Cognito Token Refresh
// ============================================
// Manages ID + refresh tokens, auto-refresh before expiry.
// Stores securely in platform keychain via flutter_secure_storage.
// Provides interceptor for HTTP calls to auto-refresh as needed.

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Token pair from Cognito
class TokenPair {
  final String idToken;
  final String accessToken;
  final String tokenType;
  final int expiresInSeconds;
  final DateTime issuedAt;

  TokenPair({
    required this.idToken,
    required this.accessToken,
    required this.tokenType,
    required this.expiresInSeconds,
    required this.issuedAt,
  });

  /// Serialize for storage
  Map<String, dynamic> toJson() => {
    'idToken': idToken,
    'accessToken': accessToken,
    'tokenType': tokenType,
    'expiresInSeconds': expiresInSeconds,
    'issuedAt': issuedAt.toIso8601String(),
  };

  /// Deserialize from storage
  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      idToken: json['idToken'] as String,
      accessToken: json['accessToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 3600,
      issuedAt: DateTime.parse(json['issuedAt'] as String),
    );
  }

  /// Check if ID token will expire within N seconds
  bool isExpiringSoon({int secondsThreshold = 300}) {
    final expiresAt = issuedAt.add(Duration(seconds: expiresInSeconds));
    final nowPlus = DateTime.now().add(Duration(seconds: secondsThreshold));
    return nowPlus.isAfter(expiresAt);
  }

  /// Check if token is completely expired
  bool isExpired() {
    final expiresAt = issuedAt.add(Duration(seconds: expiresInSeconds));
    return DateTime.now().isAfter(expiresAt);
  }

  /// Decode JWT to extract expiry time
  DateTime get expiresAt {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return DateTime.now();

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(parts[1].padRight((parts[1].length + 3) ~/ 4 * 4, '=')))
      ) as Map<String, dynamic>;

      final exp = payload['exp'] as int?;
      if (exp == null) return DateTime.now();

      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// Token refresh from POST /api/auth/refresh response
class TokenRefreshResponse {
  final String idToken;
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String refreshedAt;

  TokenRefreshResponse({
    required this.idToken,
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.refreshedAt,
  });

  factory TokenRefreshResponse.fromJson(Map<String, dynamic> json) {
    return TokenRefreshResponse(
      idToken: json['id_token'] as String,
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int? ?? 3600,
      refreshedAt: json['refreshed_at'] as String,
    );
  }
}

/// Manages Cognito tokens with secure storage + auto-refresh
class TokenManager {
  static const _tokensKey = 'cognito_tokens_v2';
  static const _refreshTokenKey = 'cognito_refresh_token_v2';

  final FlutterSecureStorage _storage;
  final String _apiBaseUrl;
  
  TokenPair? _cachedTokens;
  String? _cachedRefreshToken;

  TokenManager({
    required String apiBaseUrl,
    FlutterSecureStorage? storage,
  })  : _apiBaseUrl = apiBaseUrl,
        _storage = storage ?? const FlutterSecureStorage();

  /// Load tokens from secure storage
  Future<TokenPair?> getTokens() async {
    try {
      if (_cachedTokens != null) return _cachedTokens;

      final json = await _storage.read(key: _tokensKey);
      if (json == null) return null;

      _cachedTokens = TokenPair.fromJson(jsonDecode(json) as Map<String, dynamic>);
      developer.log('Tokens loaded from secure storage', name: 'TokenManager');
      return _cachedTokens;
    } catch (e) {
      developer.log('Failed to load tokens: $e', name: 'TokenManager', level: 900);
      return null;
    }
  }

  /// Load refresh token
  Future<String?> getRefreshToken() async {
    try {
      if (_cachedRefreshToken != null) return _cachedRefreshToken;

      _cachedRefreshToken = await _storage.read(key: _refreshTokenKey);
      return _cachedRefreshToken;
    } catch (e) {
      developer.log('Failed to load refresh token: $e', name: 'TokenManager', level: 900);
      return null;
    }
  }

  /// Save tokens to secure storage
  Future<void> saveTokens(TokenPair tokens, {String? refreshToken}) async {
    try {
      _cachedTokens = tokens;
      await _storage.write(key: _tokensKey, value: jsonEncode(tokens.toJson()));

      if (refreshToken != null) {
        _cachedRefreshToken = refreshToken;
        await _storage.write(key: _refreshTokenKey, value: refreshToken);
      }

      developer.log('Tokens saved securely', name: 'TokenManager');
    } catch (e) {
      developer.log('Failed to save tokens: $e', name: 'TokenManager', level: 900);
      rethrow;
    }
  }

  /// Refresh ID token using refresh token
  Future<TokenPair?> refreshTokens() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        developer.log('No refresh token available', name: 'TokenManager');
        return null;
      }

      // AUDIT FIX #22: Use correct backend path and request body key
      final url = Uri.parse('$_apiBaseUrl/auth/refresh');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        developer.log('Token refresh failed: ${response.statusCode}', name: 'TokenManager', level: 900);
        return null;
      }

      final data = TokenRefreshResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      final newTokens = TokenPair(
        idToken: data.idToken,
        accessToken: data.accessToken,
        tokenType: data.tokenType,
        expiresInSeconds: data.expiresIn,
        issuedAt: DateTime.now(),
      );

      await saveTokens(newTokens, refreshToken: refreshToken);
      developer.log('Tokens refreshed successfully', name: 'TokenManager');
      return newTokens;
    } catch (e) {
      developer.log('Token refresh error: $e', name: 'TokenManager', level: 900);
      return null;
    }
  }

  /// Ensure tokens are fresh, refresh if needed
  Future<TokenPair?> ensureFreshTokens({int secondsThreshold = 300}) async {
    try {
      var tokens = await getTokens();
      if (tokens == null) return null;

      if (tokens.isExpiringSoon(secondsThreshold: secondsThreshold)) {
        developer.log('ID token expiring soon, refreshing', name: 'TokenManager');
        tokens = await refreshTokens();
      }

      return tokens;
    } catch (e) {
      developer.log('Failed to ensure fresh tokens: $e', name: 'TokenManager', level: 900);
      return null;
    }
  }

  /// Clear all tokens (logout)
  Future<void> clearTokens() async {
    try {
      _cachedTokens = null;
      _cachedRefreshToken = null;
      await _storage.delete(key: _tokensKey);
      await _storage.delete(key: _refreshTokenKey);
      developer.log('Tokens cleared', name: 'TokenManager');
    } catch (e) {
      developer.log('Failed to clear tokens: $e', name: 'TokenManager', level: 900);
    }
  }

  /// Get ID token for API calls (with auto-refresh)
  Future<String?> getIdToken({bool autoRefresh = true}) async {
    try {
      var tokens = await getTokens();
      if (tokens == null) return null;

      if (autoRefresh && tokens.isExpiringSoon(secondsThreshold: 60)) {
        tokens = await refreshTokens();
      }

      return tokens?.idToken;
    } catch (e) {
      developer.log('Failed to get ID token: $e', name: 'TokenManager', level: 900);
      return null;
    }
  }
}
