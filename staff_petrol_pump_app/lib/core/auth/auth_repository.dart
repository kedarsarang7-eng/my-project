import 'dart:convert';

import 'package:amazon_cognito_identity_dart_2/cognito.dart';

import '../config/aws_config.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'token_storage.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();
  final CognitoUserPool _userPool = AwsConfig.userPool;

  Future<Map<String, dynamic>> signIn(
    String email,
    String password,
  ) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.v1AuthLogin, data: {
        'email': email,
        'password': password,
      });
      final payload = response.data is Map<String, dynamic>
          ? (response.data['data'] as Map<String, dynamic>? ?? response.data as Map<String, dynamic>)
          : <String, dynamic>{};

      final token = payload['token'] as String?;
      final accessToken = token ?? payload['accessToken'] as String?;
      final idToken = payload['idToken'] as String? ?? accessToken;
      final refreshToken = payload['refreshToken'] as String?;
      if (accessToken == null || refreshToken == null) {
        throw Exception('Token missing');
      }

      await TokenStorage.saveTokens(
        accessToken: accessToken,
        idToken: idToken ?? accessToken,
        refreshToken: refreshToken,
      );

      // ENHANCED: Return full login response for license data
      return payload;
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      await _apiClient.post(ApiEndpoints.v1AuthLogout);
    } catch (_) {}
    await TokenStorage.clearTokens();
  }

  Future<void> signUp(String name, String email, String password, String role, String? tenantId) async {
    final normalizedRole = role.trim().toLowerCase();
    final safeRole = <String>{'staff', 'manager', 'admin', 'ca'}.contains(normalizedRole)
        ? normalizedRole
        : 'staff';
    final userAttributes = [
      AttributeArg(name: 'name', value: name),
      AttributeArg(name: 'email', value: email),
      AttributeArg(name: 'custom:role', value: safeRole),
      if (tenantId != null) AttributeArg(name: 'custom:tenant_id', value: tenantId),
    ];
    await _userPool.signUp(email, password, userAttributes: userAttributes);
  }

  Future<void> confirmSignUp(String email, String code) async {
    final cognitoUser = CognitoUser(email, _userPool);
    await cognitoUser.confirmRegistration(code);
  }

  Future<CognitoUserSession?> refreshSession() async {
    final existingRefreshToken = await TokenStorage.getRefreshToken();
    if (existingRefreshToken == null) return null;

    try {
      final response = await _apiClient.post(ApiEndpoints.v1AuthRefresh, data: {
        'refreshToken': existingRefreshToken,
      });
      final payload = response.data is Map<String, dynamic>
          ? (response.data['data'] as Map<String, dynamic>? ?? response.data as Map<String, dynamic>)
          : <String, dynamic>{};

      final token = (payload['token'] as String?) ?? (payload['accessToken'] as String?);
      final refreshToken = payload['refreshToken'] as String? ?? existingRefreshToken;
      final idToken = payload['idToken'] as String? ?? token;
      if (token == null) {
        return null;
      }

      await TokenStorage.saveTokens(
        accessToken: token,
        idToken: idToken ?? token,
        refreshToken: refreshToken,
      );

      return CognitoUserSession(
        CognitoIdToken(idToken ?? token),
        CognitoAccessToken(token),
        refreshToken: CognitoRefreshToken(refreshToken),
      );
    } catch (_) {
      await TokenStorage.clearTokens();
      return null;
    }
  }

  Future<bool> isAuthenticated() async {
    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null) return false;

    try {
      final parts = accessToken.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        ) as Map<String, dynamic>;
        final exp = payload['exp'];
        if (exp is int) {
          final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          if (expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
            return true;
          }
        }
      }
      return (await refreshSession()) != null;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getCurrentUserId() async {
    return (await _claimFromAccessToken('userId')) ?? (await _claimFromAccessToken('sub'));
  }

  Future<String?> getCurrentTenantId() async {
    return (await _claimFromAccessToken('businessId')) ?? (await _claimFromAccessToken('custom:tenant_id'));
  }

  Future<String?> _claimFromAccessToken(String key) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      return payload[key]?.toString();
    } catch (_) {
      return null;
    }
  }
}
