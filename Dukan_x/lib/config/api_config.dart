import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Environment types for API configuration
enum Environment { local, dev, staging, production }

/// API Configuration with environment-based URL selection
///
/// Usage:
/// - Debug builds: Uses DEV environment by default
/// - Release builds: Uses PRODUCTION environment by default
/// - Override: flutter run --dart-define=DUKANX_ENV=local
/// - Local mode: Uses LocalStack (DynamoDB, S3) + Keycloak (Auth)
class ApiConfig {
  // ============================================================================
  // ENVIRONMENT URLs
  // ============================================================================

  /// Local environment URLs (LocalStack + Keycloak)
  static const String _localUrl = 'http://127.0.0.1:8000';
  static const String _localKeycloakUrl = 'http://localhost:8080/realms/dukanx';
  static const String _localS3Url = 'http://localhost:4566';
  static const String _localWsUrl = 'ws://localhost:3001';

  /// Development URLs (local development)
  static const String _devAndroidEmulatorUrl = 'http://10.0.2.2:8000';
  static const String _devLocalhostUrl = 'http://127.0.0.1:8000';

  /// Staging URLs (pre-production testing)
  static const String _stagingUrl = 'https://api-staging.dukanx.com';

  /// Production URLs (live environment)
  static const String _productionUrl = 'https://api.dukanx.com';

  // ============================================================================
  // ENVIRONMENT DETECTION
  // ============================================================================

  /// Current environment - read from dart-define or inferred from build mode
  static Environment get currentEnvironment {
    // Check for explicit environment override via --dart-define
    const envString = String.fromEnvironment('DUKANX_ENV', defaultValue: '');

    if (envString.isNotEmpty) {
      switch (envString.toLowerCase()) {
        case 'local':
          return Environment.local;
        case 'dev':
        case 'development':
          return Environment.dev;
        case 'staging':
        case 'stage':
          return Environment.staging;
        case 'prod':
        case 'production':
          return Environment.production;
      }
    }

    // Default: Debug mode uses DEV, Release mode uses PRODUCTION
    return kDebugMode ? Environment.dev : Environment.production;
  }

  /// Check if running in local mode (LocalStack + Keycloak)
  static bool get isLocal => currentEnvironment == Environment.local;

  /// Check if running in production
  static bool get isProduction => currentEnvironment == Environment.production;

  /// Check if running in development
  static bool get isDevelopment => currentEnvironment == Environment.dev;

  // ============================================================================
  // RUNTIME BASE URL OVERRIDE (Server Settings)
  // ============================================================================
  //
  // A user-configured server URL persisted in SharedPreferences. When set it
  // takes precedence over the environment defaults, so changing the server in
  // Settings applies immediately without an app restart. Cached in memory so
  // the synchronous [baseUrl] getter stays synchronous.

  static const String _kServerUrlPrefKey = 'server_settings_base_url';
  static String? _runtimeBaseUrlOverride;

  /// Loads any persisted server-URL override into memory. Call once at startup.
  static Future<void> loadRuntimeOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kServerUrlPrefKey);
      _runtimeBaseUrlOverride =
          (saved != null && saved.trim().isNotEmpty) ? saved.trim() : null;
    } catch (_) {
      _runtimeBaseUrlOverride = null;
    }
  }

  /// The currently active override, if any.
  static String? get runtimeBaseUrlOverride => _runtimeBaseUrlOverride;

  /// Persists [url] as the active server URL (applies without restart). Passing
  /// null or empty clears the override and reverts to environment defaults.
  static Future<void> setRuntimeBaseUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      _runtimeBaseUrlOverride = null;
      await prefs.remove(_kServerUrlPrefKey);
    } else {
      _runtimeBaseUrlOverride = trimmed;
      await prefs.setString(_kServerUrlPrefKey, trimmed);
    }
  }

  // ============================================================================
  // BASE URL RESOLUTION
  // ============================================================================

  /// Get the appropriate base URL for current environment and platform
  static String get baseUrl {
    final override = _runtimeBaseUrlOverride;
    if (override != null && override.isNotEmpty) return override;

    switch (currentEnvironment) {
      case Environment.production:
        return _productionUrl;

      case Environment.staging:
        return _stagingUrl;

      case Environment.local:
        return _localUrl;

      case Environment.dev:
        return _getDevUrl();
    }
  }

  /// Keycloak URL (local mode only — Cognito is used in cloud environments)
  static String get keycloakUrl => _localKeycloakUrl;

  /// S3 base URL (LocalStack in local, AWS in cloud)
  static String get s3BaseUrl {
    if (isLocal) return _localS3Url;
    return 'https://s3.ap-south-1.amazonaws.com';
  }

  /// WebSocket URL
  static String get websocketUrl {
    if (isLocal) return _localWsUrl;
    return const String.fromEnvironment('WS_ENDPOINT_URL', defaultValue: '');
  }

  /// Get development URL based on platform
  static String _getDevUrl() {
    if (kIsWeb) {
      return _devLocalhostUrl;
    }

    if (Platform.isAndroid) {
      // 10.0.2.2 is the special alias to host loopback on Android Emulator
      // For real devices, override with DUKANX_API_URL dart-define
      const customUrl = String.fromEnvironment(
        'DUKANX_API_URL',
        defaultValue: '',
      );
      if (customUrl.isNotEmpty) return customUrl;
      return _devAndroidEmulatorUrl;
    }

    // iOS Simulator, Windows, Linux, Mac use localhost
    return _devLocalhostUrl;
  }

  /// Environment name for logging/debugging
  static String get environmentName => currentEnvironment.name.toUpperCase();

  // ============================================================================
  // ADDITIONAL CONFIGURATIONS
  // ============================================================================

  static String get adminToken => const String.fromEnvironment('ADMIN_TOKEN', defaultValue: '');
  static String get appSyncEndpoint => const String.fromEnvironment('APPSYNC_ENDPOINT', defaultValue: 'https://api.dukanx.com/graphql');
  static String get appSyncApiKey => const String.fromEnvironment('APPSYNC_API_KEY', defaultValue: '');
  static String get awsRegion => const String.fromEnvironment('AWS_REGION', defaultValue: 'ap-south-1');

  static Duration get requestTimeout => const Duration(seconds: 30);
  static Duration get connectTimeout => const Duration(seconds: 10);
  static int get maxRetries => 3;
  static Duration get retryBaseDelay => const Duration(milliseconds: 500);

  static String get sttBaseUrl => '$baseUrl/stt';
  static String get slsLicensingBaseUrl => '$baseUrl/licensing';
  static List<String> get pinnedCertFingerprints => const [];

  static String get appVersion => const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  static String get licenseActivationUrl => '$baseUrl/license/activate';
  static String get heartbeatUrl => '$baseUrl/license/heartbeat';
  static String get licenseValidationUrl => '$baseUrl/license/validate';
  static String get subscriptionStatusUrl => '$baseUrl/subscription/status';
  static String get subscriptionRenewUrl => '$baseUrl/subscription/renew';
  static String get subscriptionCancelUrl => '$baseUrl/subscription/cancel';
  static String get subscriptionUpdateUrl => '$baseUrl/subscription/update';

  static void validateConfiguration() {
    // Stub validation logic
  }
}

