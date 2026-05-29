import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../auth/token_storage.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add authorization header
          final accessToken = await TokenStorage.getAccessToken();
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }

          // Do not send client-forged tenant headers.
          // Backend must derive tenant from verified JWT claims.

          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Try to refresh token
            final refreshToken = await TokenStorage.getRefreshToken();
            if (refreshToken != null) {
              try {
                // Call refresh endpoint
                final response = await _dio.post('/auth/refresh', data: {
                  'refreshToken': refreshToken,
                });
                final payload = response.data is Map<String, dynamic>
                    ? (response.data['data'] as Map<String, dynamic>? ?? response.data as Map<String, dynamic>)
                    : <String, dynamic>{};
                final accessToken = (payload['token'] as String?) ?? (payload['accessToken'] as String?);
                final idToken = payload['idToken'] as String? ?? accessToken;
                if (accessToken == null) {
                  throw Exception('Missing access token on refresh');
                }
                await TokenStorage.saveTokens(
                  accessToken: accessToken,
                  idToken: idToken ?? accessToken,
                  refreshToken: refreshToken, // Keep the same refresh token
                );

                // Retry the original request
                final options = error.requestOptions;
                options.headers['Authorization'] = 'Bearer $accessToken';

                final retryResponse = await _dio.request(
                  options.path,
                  options: Options(
                    method: options.method,
                    headers: options.headers,
                  ),
                  data: options.data,
                  queryParameters: options.queryParameters,
                );

                return handler.resolve(retryResponse);
              } catch (refreshError) {
                // Refresh failed, clear tokens and redirect to login
                await TokenStorage.clearTokens();
                // Navigation to login would be handled by auth state listener
              }
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}