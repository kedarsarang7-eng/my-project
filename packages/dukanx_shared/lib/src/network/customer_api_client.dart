import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../auth/jwt_utils.dart';
import '../auth/secure_token_store.dart';
import '../models/api_response.dart';

typedef TokenRefreshCallback = Future<String?> Function(String refreshToken);

/// Secure HTTP client for the customer app.
/// - Attaches Bearer token automatically.
/// - Silently refreshes token if near expiry (5-min buffer).
/// - Retries once after a 401 (in case of concurrent refresh race).
/// - Never stores tokens in SharedPreferences.
class CustomerApiClient {
  final String baseUrl;
  final SecureTokenStore _tokenStore;
  final TokenRefreshCallback? onRefreshToken;
  final http.Client _http;

  bool _isRefreshing = false;

  static const _timeout = Duration(seconds: 30);
  static const _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  CustomerApiClient({
    required this.baseUrl,
    required SecureTokenStore tokenStore,
    this.onRefreshToken,
    http.Client? httpClient,
  })  : _tokenStore = tokenStore,
        _http = httpClient ?? http.Client();

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    return _execute('GET', path, queryParams: queryParams);
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _execute('POST', path, body: body);
  }

  Future<ApiResponse<Map<String, dynamic>>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _execute('PATCH', path, body: body);
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(String path) async {
    return _execute('DELETE', path);
  }

  // ── Core ────────────────────────────────────────────────────────────────────

  Future<ApiResponse<Map<String, dynamic>>> _execute(
    String method,
    String path, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    try {
      final token = await _getValidToken();
      if (token == null) {
        return ApiResponse.failure(401, 'No valid session', code: 'NO_SESSION');
      }

      final uri = Uri.parse('$baseUrl$path').replace(
        queryParameters: queryParams,
      );

      final headers = {
        ..._defaultHeaders,
        'Authorization': 'Bearer $token',
      };

      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = json.encode(body);

      final streamedResponse = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      final correlationId = response.headers['x-request-id'];

      if (response.statusCode == 401 && !isRetry) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          return _execute(method, path,
              queryParams: queryParams, body: body, isRetry: true);
        }
        return ApiResponse.failure(401, 'Session expired', code: 'SESSION_EXPIRED');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = response.body.isNotEmpty
            ? json.decode(response.body) as Map<String, dynamic>
            : <String, dynamic>{};
        return ApiResponse.success(response.statusCode, decoded,
            correlationId: correlationId);
      }

      Map<String, dynamic> errorBody = {};
      try {
        errorBody = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      return ApiResponse.failure(
        response.statusCode,
        errorBody['message'] as String? ?? response.reasonPhrase ?? 'Error',
        code: errorBody['error'] as String? ?? errorBody['code'] as String?,
        correlationId: correlationId,
      );
    } on SocketException {
      return ApiResponse.offline();
    } on HttpException catch (e) {
      return ApiResponse.networkError(e.message);
    } on FormatException {
      return ApiResponse.networkError('Invalid server response');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return ApiResponse.timeout();
      }
      return ApiResponse.networkError(e.toString());
    }
  }

  Future<String?> _getValidToken() async {
    final tokenData = await _tokenStore.read();
    if (tokenData == null) return null;

    if (JwtUtils.isNearExpiry(tokenData.accessToken)) {
      final refreshed = await _tryRefreshToken();
      if (!refreshed) return null;
      final updated = await _tokenStore.read();
      return updated?.accessToken;
    }

    return tokenData.accessToken;
  }

  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) {
      await Future.delayed(const Duration(milliseconds: 500));
      return (await _tokenStore.read()) != null;
    }

    _isRefreshing = true;
    try {
      final tokenData = await _tokenStore.read();
      if (tokenData == null || onRefreshToken == null) return false;

      final newAccessToken =
          await onRefreshToken!(tokenData.refreshToken);
      if (newAccessToken == null) {
        await _tokenStore.clear();
        return false;
      }

      final expiry = JwtUtils.expiryFromToken(newAccessToken) ??
          DateTime.now().add(const Duration(hours: 1));

      await _tokenStore.write(
        tokenData.copyWithNewTokens(
          accessToken: newAccessToken,
          idToken: newAccessToken,
          expiresAt: expiry,
        ),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  void dispose() => _http.close();
}
