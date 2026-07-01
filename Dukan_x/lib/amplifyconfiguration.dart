import 'config/api_config.dart';

/// AWS Amplify configuration — built dynamically from environment variables.
///
/// Previously hardcoded; now reads from [ApiConfig] which sources from .env.
/// This ensures the AppSync endpoint and API key are configurable per
/// environment (dev / staging / production).
String get amplifyconfig {
  final endpoint = ApiConfig.appSyncEndpoint;
  final apiKey = ApiConfig.appSyncApiKey;
  final region = ApiConfig.awsRegion;

  return '''{
    "UserAgent": "aws-amplify-cli/2.0",
    "Version": "1.0",
    "api": {
        "plugins": {
            "awsAPIPlugin": {
                "dukanx": {
                    "endpointType": "GraphQL",
                    "endpoint": "$endpoint",
                    "region": "$region",
                    "authorizationType": "API_KEY",
                    "apiKey": "$apiKey"
                }
            }
        }
    }
}''';
}
