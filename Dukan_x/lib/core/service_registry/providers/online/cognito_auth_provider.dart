// Online Auth Provider — delegates to the existing auth infrastructure.
// Uses ApiClient POST /auth/login, /auth/refresh, /auth/logout and the
// existing TokenManager for secure token storage.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../services/token_manager.dart';
import '../../contracts/i_auth_service.dart';

class CognitoAuthProvider implements IAuthService {
  ApiClient get _api => sl<ApiClient>();
  TokenManager get _tokens => sl<TokenManager>();

  @override
  Future<AuthToken> login(String email, String password) async {
    final res = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    if (!res.isSuccess || res.data == null) {
      throw AuthException(
        res.code ?? 'LOGIN_FAILED',
        res.error ?? 'Login failed',
      );
    }
    final data = res.data as Map<String, dynamic>;
    return _parseToken(data);
  }

  @override
  Future<UserClaims> verify(String accessToken) async {
    final res = await _api.get('/auth/me');
    if (!res.isSuccess || res.data == null) {
      throw AuthException('VERIFY_FAILED', res.error ?? 'Token verification failed');
    }
    final data = res.data as Map<String, dynamic>;
    return UserClaims(
      userId: data['userId'] ?? data['sub'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      groups: List<String>.from(data['groups'] ?? []),
      businessId: data['businessId'],
      custom: Map<String, dynamic>.from(data['custom'] ?? {}),
    );
  }

  @override
  Future<AuthToken> refresh(String refreshToken) async {
    final res = await _api.post('/auth/refresh', body: {
      'refreshToken': refreshToken,
    });
    if (!res.isSuccess || res.data == null) {
      throw AuthException('REFRESH_FAILED', res.error ?? 'Token refresh failed');
    }
    return _parseToken(res.data as Map<String, dynamic>);
  }

  @override
  Future<void> logout(String accessToken) async {
    try {
      await _api.post('/auth/logout', body: {'token': accessToken});
    } catch (e) {
      debugPrint('[CognitoAuthProvider] Logout API error (ignored): $e');
    }
    await _tokens.clearTokens();
  }

  @override
  Future<void> dispose() async {}

  AuthToken _parseToken(Map<String, dynamic> data) {
    final expiresIn = (data['expiresIn'] as int?) ?? 3600;
    return AuthToken(
      accessToken: data['accessToken'] ?? data['access_token'] ?? '',
      idToken: data['idToken'] ?? data['id_token'],
      refreshToken: data['refreshToken'] ?? data['refresh_token'],
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }
}
