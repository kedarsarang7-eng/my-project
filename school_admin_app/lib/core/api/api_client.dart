import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class ApiResponse {
  final int statusCode;
  final dynamic data;
  final String? error;
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  const ApiResponse({required this.statusCode, required this.data, this.error});
}

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl, connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30), headers: {'Content-Type': 'application/json'}));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          try {
            final refreshToken = await _storage.read(key: 'refresh_token');
            if (refreshToken != null) {
              final refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
              final res = await refreshDio.post('/auth/refresh', data: {'refreshToken': refreshToken});
              final newToken = res.data?['accessToken'];
              if (newToken != null) {
                await _storage.write(key: 'access_token', value: newToken);
                final opts = error.requestOptions..headers['Authorization'] = 'Bearer $newToken';
                return handler.resolve(await _dio.fetch(opts));
              }
            }
          } catch (_) {}
        }
        return handler.next(error);
      },
    ));
    _dio.interceptors.add(_RetryInterceptor(_dio));
  }

  Future<ApiResponse> get(String path, {Map<String, dynamic>? params}) async {
    try { final r = await _dio.get(path, queryParameters: params); return ApiResponse(statusCode: r.statusCode ?? 200, data: r.data); }
    on DioException catch (e) { return ApiResponse(statusCode: e.response?.statusCode ?? 500, data: null, error: e.response?.data?['message'] ?? e.message); }
  }

  Future<ApiResponse> post(String path, {dynamic body}) async {
    try { final r = await _dio.post(path, data: body); return ApiResponse(statusCode: r.statusCode ?? 200, data: r.data); }
    on DioException catch (e) { return ApiResponse(statusCode: e.response?.statusCode ?? 500, data: null, error: e.response?.data?['message'] ?? e.message); }
  }

  Future<ApiResponse> put(String path, {dynamic body}) async {
    try { final r = await _dio.put(path, data: body); return ApiResponse(statusCode: r.statusCode ?? 200, data: r.data); }
    on DioException catch (e) { return ApiResponse(statusCode: e.response?.statusCode ?? 500, data: null, error: e.response?.data?['message'] ?? e.message); }
  }

  Future<ApiResponse> delete(String path) async {
    try { final r = await _dio.delete(path); return ApiResponse(statusCode: r.statusCode ?? 200, data: r.data); }
    on DioException catch (e) { return _handleError(e); }
  }

  ApiResponse _handleError(DioException e) {
    String msg;
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      msg = 'Connection timed out. Please check your network.';
    } else if (e.type == DioExceptionType.connectionError) {
      msg = 'No internet connection.';
    } else if (e.response?.statusCode == 401) {
      msg = 'Session expired. Please login again.';
    } else if (e.response?.statusCode == 403) {
      msg = 'You do not have permission to access this.';
    } else if (e.response?.statusCode == 404) {
      msg = 'Resource not found.';
    } else if ((e.response?.statusCode ?? 0) >= 500) {
      msg = 'Server error. Please try again later.';
    } else {
      msg = e.response?.data?['message'] ?? e.message ?? 'An error occurred.';
    }
    return ApiResponse(statusCode: e.response?.statusCode ?? 500, data: null, error: msg);
  }
}

class _RetryInterceptor extends Interceptor {
  final Dio dio;
  _RetryInterceptor(this.dio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = (err.requestOptions.extra['retryCount'] as num? ?? 0).toInt();
    final shouldRetry = retryCount < 3 &&
        (err.type == DioExceptionType.connectionTimeout ||
         err.type == DioExceptionType.connectionError ||
         (err.response?.statusCode ?? 0) >= 500);
    if (shouldRetry) {
      await Future.delayed(Duration(milliseconds: 300 * (retryCount + 1) * (retryCount + 1)));
      final opts = err.requestOptions..extra['retryCount'] = retryCount + 1;
      try { return handler.resolve(await dio.fetch(opts)); } catch (_) {}
    }
    return handler.next(err);
  }
}
