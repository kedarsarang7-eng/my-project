import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static late String apiBaseUrl;
  static late String wsBaseUrl;
  static late String cognitoClientId;
  static late String cognitoUserPoolId;
  static late String awsRegion;
  static late String environment;
  static const String appRole = 'teacher';
  static const String appName = 'EduConnect Teacher';

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
    wsBaseUrl = dotenv.env['WS_BASE_URL'] ?? apiBaseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    cognitoClientId = dotenv.env['COGNITO_CLIENT_ID'] ?? '';
    cognitoUserPoolId = dotenv.env['COGNITO_USER_POOL_ID'] ?? '';
    awsRegion = dotenv.env['AWS_REGION'] ?? 'ap-south-1';
    environment = dotenv.env['ENVIRONMENT'] ?? 'development';
    if (cognitoClientId.isEmpty || cognitoUserPoolId.isEmpty) {
      throw Exception('Missing Cognito config in .env');
    }
  }

  static bool get isProd => environment == 'production';
}
