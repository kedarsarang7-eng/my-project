import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';

import 'auth_models.dart';

class AuthServiceV2 {
  final ApiClient _apiClient;

  AuthServiceV2({ApiClient? apiClient}) : _apiClient = apiClient ?? sl<ApiClient>();

  Future<LoginResult> login(String email, String password) async {
    final res = await _apiClient.post(
      '/auth/login',
      requireAuth: false,
      body: {'email': email, 'password': password},
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception(_toFriendlyMessage(res.statusCode, res.error));
    }
    return LoginResult.fromJson(res.data!);
  }

  Future<LoginResult> me() async {
    final res = await _apiClient.get('/auth/me', requireAuth: true);
    if (!res.isSuccess || res.data == null) {
      throw Exception(_toFriendlyMessage(res.statusCode, res.error));
    }
    return LoginResult.fromJson(res.data!);
  }

  Future<void> logout() async {
    await _apiClient.post('/auth/logout', requireAuth: true, body: const {});
  }

  String _toFriendlyMessage(int statusCode, String? error) {
    final lower = (error ?? '').toLowerCase();
    if (statusCode == 401) {
      if (lower.contains('suspended') || lower.contains('disabled')) {
        return 'Your account has been suspended. Contact admin.';
      }
      return 'Invalid email or password';
    }
    if (statusCode == 0) {
      return 'Unable to connect. Please check your connection.';
    }
    if (lower.contains('not configured') || lower.contains('no role')) {
      return 'Account not configured. Contact your administrator.';
    }
    return error?.isNotEmpty == true ? error! : 'Authentication failed';
  }
}
