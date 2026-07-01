import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../config/api_config.dart';

// ============================================================================
// AppConfig â€” Unified Configuration Facade
// ============================================================================
// Single source of truth for ALL environment-driven configuration.
// Wraps ApiConfig and adds missing surfaces (WebSocket, S3, Groq, Web URLs).
//
// Usage:
//   AppConfig.validate();  // Call once at startup
//   final url = AppConfig.apiBaseUrl;
//   final ws  = AppConfig.wsEndpointUrl;
//
// Environment selection:
//   flutter run --dart-define=DUKANX_ENV=staging
//   flutter run --dart-define=DUKANX_API_URL=http://localhost:3000
// ============================================================================

class AppConfig {
  AppConfig._(); // Non-instantiable

  // â”€â”€ Delegated from ApiConfig â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Current environment (dev | staging | production)
  static Environment get environment => ApiConfig.currentEnvironment;
  static String get environmentName => ApiConfig.environmentName;
  static bool get isProduction => ApiConfig.isProduction;
  static bool get isDevelopment => ApiConfig.isDevelopment;

  // â”€â”€ API Base URL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Main API Gateway base URL (REST)
  static String get apiBaseUrl => ApiConfig.baseUrl;

  // â”€â”€ WebSocket â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// WebSocket endpoint URL for real-time events.
  /// Set via .env: WS_ENDPOINT_URL=wss://xxx.execute-api.ap-south-1.amazonaws.com/prod
  /// Or via dart-define: --dart-define=WS_BASE_URL=wss://...
  static String get wsEndpointUrl {
    // .env has highest priority
    final envUrl = dotenv.env['WS_ENDPOINT_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    // dart-define fallback
    const dartDefine =
        String.fromEnvironment('WS_BASE_URL', defaultValue: '');
    if (dartDefine.isNotEmpty) return dartDefine;

    // Fail-fast â€” no silent fallback to a random endpoint
    throw StateError(
      'WS_ENDPOINT_URL is not configured. '
      'Set in .env or via --dart-define=WS_BASE_URL',
    );
  }

  // â”€â”€ AWS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// AWS Region
  static String get awsRegion {
    final region = dotenv.env['AWS_REGION'];
    if (region != null && region.isNotEmpty) return region;
    throw StateError('AWS_REGION is not configured in .env');
  }

  // â”€â”€ Cognito â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Cognito User Pool ID
  static String get cognitoUserPoolId {
    final id = dotenv.env['COGNITO_USER_POOL_ID'];
    if (id != null && id.isNotEmpty) return id;
    throw StateError('COGNITO_USER_POOL_ID is not configured in .env');
  }

  /// Cognito App Client ID
  static String get cognitoClientId {
    final id = dotenv.env['COGNITO_CLIENT_ID'];
    if (id != null && id.isNotEmpty) return id;
    throw StateError('COGNITO_CLIENT_ID is not configured in .env');
  }

  /// Cognito Domain (for hosted UI auth)
  static String get cognitoDomain =>
      dotenv.env['COGNITO_DOMAIN'] ?? '';

  /// Google OAuth Client ID (for social login via Cognito)
  static String get googleClientId =>
      dotenv.env['GOOGLE_CLIENT_ID'] ?? '';

  /// Cognito Redirect URI (deep link callback)
  static String get cognitoRedirectUri =>
      dotenv.env['COGNITO_REDIRECT_URI'] ?? 'dukanx://auth/callback';

  // â”€â”€ S3 Storage â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// S3 Bucket Name â€” NO fallback to prevent cross-bucket data leaks
  static String get s3BucketName {
    final bucket = dotenv.env['AWS_S3_BUCKET_NAME'];
    if (bucket != null && bucket.isNotEmpty) return bucket;
    throw StateError(
      'AWS_S3_BUCKET_NAME is not configured in .env. '
      'This is required to prevent tenant data leaks.',
    );
  }

  /// S3 bucket base URL for public assets
  static String get s3BaseUrl =>
      dotenv.env['S3_BASE_URL'] ??
      'https://$s3BucketName.s3.$awsRegion.amazonaws.com';

  // â”€â”€ AppSync (GraphQL) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// AppSync GraphQL endpoint
  static String get appSyncEndpoint =>
      dotenv.env['APPSYNC_ENDPOINT'] ?? '';

  /// AppSync API Key
  static String get appSyncApiKey =>
      dotenv.env['APPSYNC_API_KEY'] ?? '';

  // â”€â”€ Web / Deep Links â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Web base URL for customer-facing links (QR codes, invites, legal pages)
  static String get webBaseUrl =>
      dotenv.env['APP_WEB_BASE_URL'] ?? 'https://dukanx.com';

  /// Build a customer connect URL
  static String customerConnectUrl(String customerId, String token) =>
      '$webBaseUrl/connect?id=$customerId&token=$token';

  // â”€â”€ AI / ML Services â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Groq API base URL
  static String get groqApiBaseUrl =>
      dotenv.env['GROQ_API_BASE_URL'] ??
      'https://api.groq.com/openai/v1/chat/completions';

  /// Groq API Key (optional â€” only for local dev; prod should use backend)
  static String get groqApiKey =>
      dotenv.env['GROQ_API_KEY'] ?? '';

  /// STT (Speech-to-Text) backend URL
  static String get sttBaseUrl => ApiConfig.sttBaseUrl;

  // â”€â”€ WhatsApp â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// WhatsApp API base URL (Meta Graph API)
  static String get whatsappApiUrl =>
      dotenv.env['WHATSAPP_API_URL'] ??
      'https://graph.facebook.com/v17.0';

  // â”€â”€ Licensing â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Licensing base URL (same as main API since unification)
  static String get licensingBaseUrl => ApiConfig.slsLicensingBaseUrl;

  // â”€â”€ Certificate Pinning â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// SHA-256 cert pins for HTTPS pinning
  static List<String> get certPins => ApiConfig.pinnedCertFingerprints;

  // â”€â”€ Timeouts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static Duration get connectTimeout => ApiConfig.connectTimeout;
  static Duration get requestTimeout => ApiConfig.requestTimeout;
  static int get maxRetries => ApiConfig.maxRetries;

  // â”€â”€ App Meta â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// App version string
  static String get appVersion =>
      dotenv.env['APP_VERSION'] ?? ApiConfig.appVersion;

  /// Log level
  static String get logLevel =>
      dotenv.env['APP_LOG_LEVEL'] ?? (kDebugMode ? 'debug' : 'info');

  // ========================================================================
  // VALIDATION â€” Call once at app startup
  // ========================================================================

  /// Validate all required environment variables.
  /// Call in main() after dotenv.load().
  /// Throws [StateError] with descriptive message on missing required vars.
  static void validate() {
    final missing = <String>[];

    // Required for all environments
    if ((dotenv.env['COGNITO_USER_POOL_ID'] ?? '').isEmpty) {
      missing.add('COGNITO_USER_POOL_ID');
    }
    if ((dotenv.env['COGNITO_CLIENT_ID'] ?? '').isEmpty) {
      missing.add('COGNITO_CLIENT_ID');
    }
    if ((dotenv.env['AWS_REGION'] ?? '').isEmpty) {
      missing.add('AWS_REGION');
    }

    // API_BASE_URL required unless dart-define override
    const dartDefineUrl =
        String.fromEnvironment('DUKANX_API_URL', defaultValue: '');
    if (dartDefineUrl.isEmpty) {
      final envUrl = dotenv.env['API_BASE_URL'] ??
          dotenv.env['API_URL_DEV'] ??
          '';
      if (envUrl.isEmpty) {
        missing.add('API_BASE_URL (or API_URL_DEV or --dart-define=DUKANX_API_URL)');
      }
    }

    // Production-only checks
    if (isProduction) {
      if ((dotenv.env['AWS_S3_BUCKET_NAME'] ?? '').isEmpty) {
        missing.add('AWS_S3_BUCKET_NAME');
      }
      // Validate HTTPS
      try {
        final url = apiBaseUrl;
        if (!url.startsWith('https://')) {
          missing.add('API_BASE_URL must use HTTPS in production (got: $url)');
        }
      } catch (_) {
        // Already caught above
      }
    }

    if (missing.isNotEmpty) {
      throw StateError(
        'â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—\n'
        'â•‘  MISSING REQUIRED ENVIRONMENT VARIABLES                    â•‘\n'
        'â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£\n'
        '${missing.map((v) => 'â•‘  âœ— $v').join('\n')}\n'
        'â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£\n'
        'â•‘  Configure in .env file or via --dart-define flags.        â•‘\n'
        'â•‘  See .env.example for reference.                           â•‘\n'
        'â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•',
      );
    }

    // Run ApiConfig validation too
    ApiConfig.validateConfiguration();

    debugPrint(
      '[AppConfig] âœ“ Validated for $environmentName\n'
      '  API:     $apiBaseUrl\n'
      '  Region:  ${dotenv.env['AWS_REGION'] ?? 'not set'}\n'
      '  Cognito: ${dotenv.env['COGNITO_USER_POOL_ID'] ?? 'not set'}',
    );
  }
}
