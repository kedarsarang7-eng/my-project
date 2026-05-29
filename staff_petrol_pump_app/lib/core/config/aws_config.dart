import 'package:amazon_cognito_identity_dart_2/cognito.dart';

import 'app_config.dart';

class AwsConfig {
  static CognitoUserPool get userPool => CognitoUserPool(
        AppConfig.cognitoUserPoolId,
        AppConfig.cognitoClientId,
        clientSecret: null, // Public client
      );

  static String get region => AppConfig.awsRegion;
  static String get userPoolId => AppConfig.cognitoUserPoolId;
  static String get clientId => AppConfig.cognitoClientId;
}