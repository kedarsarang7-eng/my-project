import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../exceptions/api_exceptions.dart';

/// Auth token storage keys
class _StorageKeys {
  static const accessToken = 'access_token';
  static const refreshToken = 'refresh_token';
  static const idToken = 'id_token';
}

/// Secure storage for tokens
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

/// Auth Interceptor - Manages JWT tokens and automatic refresh
/// 
/// WHY: Centralizes token management with secure storage.
/// Handles automatic token refresh before expiry.
/// Secure storage protects tokens from other apps.
class AuthInterceptor extends Interceptor {
  final String _cognitoDomain;
  final String _clientId;
  // ignore: unused_field
  final String? _refreshEndpoint;

  String? _accessToken;
  String? _refreshToken;
  String? _idToken;

  AuthInterceptor({
    required String cognitoDomain,
    required String clientId,
    String? refreshEndpoint,
  })  : _cognitoDomain = cognitoDomain,
        _clientId = clientId,
        _refreshEndpoint = refreshEndpoint;

  /// Load tokens from secure storage
  Future<void> initialize() async {
    _accessToken = await _secureStorage.read(key: _StorageKeys.accessToken);
    _refreshToken = await _secureStorage.read(key: _StorageKeys.refreshToken);
    _idToken = await _secureStorage.read(key: _StorageKeys.idToken);
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _accessToken != null && !JwtDecoder.isExpired(_accessToken!);

  /// Get current access token
  String? get accessToken => _accessToken;

  /// Get user ID from token
  String? get userId {
    if (_accessToken == null) return null;
    try {
      final decoded = JwtDecoder.decode(_accessToken!);
      return decoded['sub'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get role from token
  String? get role {
    if (_accessToken == null) return null;
    try {
      final decoded = JwtDecoder.decode(_accessToken!);
      // Try cognito:groups first, then custom:role
      final groups = decoded['cognito:groups'] as List<dynamic>?;
      if (groups != null && groups.isNotEmpty) {
        return groups.first as String;
      }
      return decoded['custom:role'] as String?;
    } catch (e) {
      return null;
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip auth for public endpoints
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }

    // Check if token needs refresh
    if (_accessToken != null && JwtDecoder.isExpired(_accessToken!)) {
      try {
        await _refreshAccessToken();
      } catch (e) {
        // Token refresh failed - clear tokens and throw auth error
        await clearTokens();
        handler.reject(
          DioException(
            requestOptions: options,
            error: UnauthorizedException(message: 'Session expired. Please login again.'),
          ),
        );
        return;
      }
    }

    // Add authorization header
    if (_accessToken != null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 by attempting refresh
    if (err.response?.statusCode == 401 && _refreshToken != null) {
      try {
        await _refreshAccessToken();
        
        // Retry the failed request with new token
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer $_accessToken';
        
        final response = await Dio().fetch(options);
        handler.resolve(response);
        return;
      } catch (e) {
        // Refresh failed - clear tokens
        await clearTokens();
      }
    }

    handler.next(err);
  }

  /// Save tokens after login
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? idToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _idToken = idToken;

    await Future.wait([
      _secureStorage.write(key: _StorageKeys.accessToken, value: accessToken),
      _secureStorage.write(key: _StorageKeys.refreshToken, value: refreshToken),
      if (idToken != null)
        _secureStorage.write(key: _StorageKeys.idToken, value: idToken),
    ]);

    debugPrint('[Auth] Tokens saved successfully');
  }

  /// Clear tokens on logout
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _idToken = null;

    await _secureStorage.deleteAll();
    
    debugPrint('[Auth] Tokens cleared');
  }

  /// Refresh access token using refresh token
  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      throw UnauthorizedException(message: 'No refresh token available');
    }

    try {
      final response = await Dio().post(
        'https://$_cognitoDomain/oauth2/token',
        data: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'refresh_token': _refreshToken,
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );

      final newAccessToken = response.data['access_token'] as String;
      final newIdToken = response.data['id_token'] as String?;

      await saveTokens(
        accessToken: newAccessToken,
        refreshToken: _refreshToken!, // Keep same refresh token
        idToken: newIdToken ?? _idToken,
      );

      debugPrint('[Auth] Token refreshed successfully');
    } catch (e) {
      debugPrint('[Auth] Token refresh failed: $e');
      throw UnauthorizedException(message: 'Failed to refresh session');
    }
  }
}
