import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared robust ApiClient with:
/// - Token injection
/// - Automatic token refresh on 401
/// - Exponential backoff retry (3 attempts)
/// - Connectivity-aware error messages
class BaseApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String baseUrl;
  final Future<String?> Function()? onRefreshToken;

  BaseApiClient({required this.baseUrl, this.onRefreshToken}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Auto-refresh on 401
        if (error.response?.statusCode == 401 && onRefreshToken != null) {
          try {
            final newToken = await onRefreshToken!();
            if (newToken != null) {
              await _storage.write(key: 'access_token', value: newToken);
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            }
          } catch (_) {}
        }
        return handler.next(error);
      },
    ));

    // Retry interceptor — 3 attempts with exponential backoff
    _dio.interceptors.add(_RetryInterceptor(_dio));
  }

  Future<ApiResponse> get(String path, {Map<String, dynamic>? params}) async {
    try {
      final r = await _dio.get(path, queryParameters: params);
      return ApiResponse(statusCode: r.statusCode ?? 200, data: r.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> post(String path, {dynamic body}) async {
    try {
      final r = await _dio.post(path, data: body);
      return ApiResponse(statusCode: r.statusCode ?? 200, data: r.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> put(String path, {dynamic body}) async {
    try {
      final r = await _dio.put(path, data: body);
      return ApiResponse(statusCode: r.statusCode ?? 200, data: r.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> delete(String path) async {
    try {
      final r = await _dio.delete(path);
      return ApiResponse(statusCode: r.statusCode ?? 200, data: r.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  ApiResponse _handleError(DioException e) {
    String message;
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timed out. Please check your network.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection.';
    } else if (e.response?.statusCode == 401) {
      message = 'Session expired. Please login again.';
    } else if (e.response?.statusCode == 403) {
      message = 'You do not have permission to access this.';
    } else if (e.response?.statusCode == 404) {
      message = 'Resource not found.';
    } else if ((e.response?.statusCode ?? 0) >= 500) {
      message = 'Server error. Please try again later.';
    } else {
      message = e.response?.data?['message'] ?? e.message ?? 'An error occurred.';
    }
    return ApiResponse(statusCode: e.response?.statusCode ?? 500, data: null, error: message);
  }
}

class ApiResponse {
  final int statusCode;
  final dynamic data;
  final String? error;
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  const ApiResponse({required this.statusCode, required this.data, this.error});
}

class _RetryInterceptor extends Interceptor {
  final Dio dio;
  static const _maxRetries = 3;

  _RetryInterceptor(this.dio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = (err.requestOptions.extra['retryCount'] as num? ?? 0).toInt();
    final shouldRetry = retryCount < _maxRetries &&
        (err.type == DioExceptionType.connectionTimeout ||
         err.type == DioExceptionType.receiveTimeout ||
         err.type == DioExceptionType.connectionError ||
         (err.response?.statusCode ?? 0) >= 500);

    if (shouldRetry) {
      final delay = Duration(milliseconds: 300 * (retryCount + 1) * (retryCount + 1));
      await Future.delayed(delay);
      final opts = err.requestOptions;
      opts.extra['retryCount'] = retryCount + 1;
      try {
        final response = await dio.fetch(opts);
        return handler.resolve(response);
      } catch (_) {}
    }
    return handler.next(err);
  }
}
