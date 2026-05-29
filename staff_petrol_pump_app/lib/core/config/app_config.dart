import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static late String apiBaseUrl;
  static late String wsBaseUrl;  // WebSocket URL for real-time payments
  static late String cognitoClientId;
  static late String cognitoUserPoolId;
  static late String awsRegion;
  static late String environment;

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');

    const overrideUrl = String.fromEnvironment('DUKANX_API_URL', defaultValue: '');
    apiBaseUrl = overrideUrl.isNotEmpty
        ? overrideUrl
        : (dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000');
    
    // WebSocket URL - convert HTTPS to WSS or HTTP to WS
    const overrideWsUrl = String.fromEnvironment('WS_BASE_URL', defaultValue: '');
    wsBaseUrl = overrideWsUrl.isNotEmpty
        ? overrideWsUrl
        : (dotenv.env['WS_BASE_URL'] ?? _defaultWsUrl(apiBaseUrl));
    
    cognitoClientId = dotenv.env['COGNITO_CLIENT_ID'] ?? '';
    cognitoUserPoolId = dotenv.env['COGNITO_USER_POOL_ID'] ?? '';
    awsRegion = dotenv.env['AWS_REGION'] ?? 'us-east-1';
    environment = dotenv.env['ENVIRONMENT'] ?? 'development';

    // Validate required config
    if (cognitoClientId.isEmpty) {
      throw Exception('COGNITO_CLIENT_ID is required');
    }
    if (cognitoUserPoolId.isEmpty) {
      throw Exception('COGNITO_USER_POOL_ID is required');
    }
  }

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';

  /// Derive default WebSocket URL from API base URL
  /// Converts https:// to wss:// and http:// to ws://
  static String _defaultWsUrl(String apiUrl) {
    if (apiUrl.startsWith('https://')) {
      return apiUrl.replaceFirst('https://', 'wss://');
    } else if (apiUrl.startsWith('http://')) {
      return apiUrl.replaceFirst('http://', 'ws://');
    }
    return 'wss://$apiUrl';
  }
}