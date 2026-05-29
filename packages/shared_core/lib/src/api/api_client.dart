import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exceptions/api_exceptions.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// API Client configuration
class ApiConfig {
  final String baseUrl;
  final String apiVersion;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final bool enableLogging;

  const ApiConfig({
    required this.baseUrl,
    this.apiVersion = 'v1',
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.enableLogging = true,
  });

  /// Production config
  static const production = ApiConfig(
    baseUrl: 'https://api.dukanx.app',
    enableLogging: false,
  );

  /// Staging config
  static const staging = ApiConfig(
    baseUrl: 'https://api-staging.dukanx.app',
    enableLogging: true,
  );

  /// Development config
  static const development = ApiConfig(
    baseUrl: 'http://localhost:3000',
    enableLogging: true,
  );
}

/// Provider for API client
final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError(
    'Override this provider with your app-specific API client',
  );
});

/// Centralized API client using Dio
/// 
/// WHY: Dio provides powerful interceptors for auth, retry, and logging.
/// This client is the single point of contact for all backend communication.
class ApiClient {
  late final Dio _dio;
  final ApiConfig config;

  ApiClient({
    required this.config,
    required AuthInterceptor authInterceptor,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: '${config.baseUrl}/api/${config.apiVersion}',
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors in order
    _dio.interceptors.addAll([
      // 1. Auth interceptor - adds tokens
      authInterceptor,
      
      // 2. Retry interceptor - handles 429 and network errors
      RetryInterceptor(
        dio: _dio,
        retries: 3,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 4),
        ],
      ),
      
      // 3. Logging interceptor (dev only)
      if (config.enableLogging && kDebugMode)
        LoggingInterceptor()
      else
        _SimpleLogInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Convert DioException to domain-specific exceptions
  ApiException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          message: 'Connection timeout. Please check your internet.',
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;

        if (statusCode == 401) {
          return UnauthorizedException(
            message: data?['error']?['message'] ?? 'Session expired. Please login again.',
          );
        }

        if (statusCode == 403) {
          return ForbiddenException(
            message: data?['error']?['message'] ?? 'Access denied.',
          );
        }

        if (statusCode == 429) {
          final retryAfter = error.response?.headers.value('retry-after');
          return RateLimitException(
            message: data?['error']?['message'] ?? 'Too many requests.',
            retryAfter: retryAfter != null ? int.tryParse(retryAfter) : null,
          );
        }

        if (statusCode != null && statusCode >= 500) {
          return ServerException(
            message: data?['error']?['message'] ?? 'Server error. Please try again later.',
            statusCode: statusCode,
          );
        }

        return ApiException(
          message: data?['error']?['message'] ?? 'Request failed.',
          statusCode: statusCode,
        );

      case DioExceptionType.cancel:
        return ApiException(message: 'Request cancelled.');

      default:
        return NetworkException(
          message: 'Network error. Please check your connection.',
        );
    }
  }
}

/// Simple log interceptor for production (minimal logging)
class _SimpleLogInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Log only critical errors
    if (err.response?.statusCode != null && err.response!.statusCode! >= 500) {
      debugPrint('[API ERROR] ${err.requestOptions.path}: ${err.message}');
    }
    handler.next(err);
  }
}
