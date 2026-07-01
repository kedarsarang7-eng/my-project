import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

/// Centralized Dio instance for services that need direct Dio access.
///
/// Provides a pre-configured Dio instance with the correct base URL
/// and default headers. Used by services like [StaffApiService] that
/// need Dio's interceptor-based request pipeline.
class DioClient {
  DioClient._();

  static Dio? _instance;

  /// Singleton Dio instance with base configuration.
  static Dio get instance {
    if (_instance == null) {
      _instance = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));
      _instance!.interceptors.add(const _LocaleInterceptor());
    }
    return _instance!;
  }
}

/// Injects the active app locale as [X-App-Locale] on every outbound request.
/// The Lambda [handler-wrapper] reads this header to localize error messages
/// and notification content.
class _LocaleInterceptor extends Interceptor {
  const _LocaleInterceptor();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locale = prefs.getString('locale') ?? 'en';
      options.headers['X-App-Locale'] = locale;
    } catch (_) {
      options.headers['X-App-Locale'] = 'en';
    }
    handler.next(options);
  }
}
