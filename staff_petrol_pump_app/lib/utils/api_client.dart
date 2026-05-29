import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../core/config/app_config.dart';
import '../core/auth/token_storage.dart';

class SecureApiClient {
  final Dio dio;

  SecureApiClient._(this.dio);

  factory SecureApiClient.create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            final parts = token.split('.');
            if (parts.length == 3) {
              final payload = jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              ) as Map<String, dynamic>;
              final exp = payload['exp'];
              if (exp is int) {
                final expAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
                if (expAt.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
                  await dio.post('/api/v1/auth/refresh');
                }
              }
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await TokenStorage.clearTokens();
          } else if (error.response?.statusCode == 403) {
            Fluttertoast.showToast(msg: 'Access Denied');
          }
          handler.next(error);
        },
      ),
    );

    return SecureApiClient._(dio);
  }
}
