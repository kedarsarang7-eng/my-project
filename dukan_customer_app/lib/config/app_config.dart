import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  final String apiBaseUrl;
  final String cognitoUserPoolId;
  final String cognitoClientId;
  final String wsUrl;
  final String environment;

  const AppConfig({
    required this.apiBaseUrl,
    required this.cognitoUserPoolId,
    required this.cognitoClientId,
    required this.wsUrl,
    required this.environment,
  });

  // Static instance populated at app bootstrap — safe to read without Ref.
  static AppConfig _instance = const AppConfig(
    apiBaseUrl: '',
    cognitoUserPoolId: '',
    cognitoClientId: '',
    wsUrl: '',
    environment: 'prod',
  );

  static AppConfig get instance => _instance;

  factory AppConfig.fromEnv() {
    final cfg = AppConfig(
      apiBaseUrl: dotenv.env['API_BASE_URL'] ?? '',
      cognitoUserPoolId: dotenv.env['COGNITO_USER_POOL_ID'] ?? '',
      cognitoClientId: dotenv.env['COGNITO_MOBILE_CLIENT_ID'] ?? '',
      wsUrl: dotenv.env['WS_URL'] ?? '',
      environment: dotenv.env['ENVIRONMENT'] ?? 'prod',
    );
    _instance = cfg;
    return cfg;
  }

  bool get isProduction => environment == 'prod';
  bool get isDevelopment => environment == 'dev';

  // Convenience static accessors for use outside widget tree
  static String get apiBaseUrlStatic => _instance.apiBaseUrl;
  static String get wsUrlStatic => _instance.wsUrl;
  static String get cognitoUserPoolIdStatic => _instance.cognitoUserPoolId;
  static String get cognitoClientIdStatic => _instance.cognitoClientId;
}

final appConfigProvider = Provider<AppConfig>((_) => AppConfig.fromEnv());
