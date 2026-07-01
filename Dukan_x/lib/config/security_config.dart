import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Security Configuration Service
///
/// SECURITY: All secrets are loaded from secure storage, NOT hardcoded.
/// Configure secrets during app setup or via secure configuration management.
class SecurityConfig {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Storage keys
  static const String _paymentHmacSecretKey = 'security_payment_hmac_secret';
  static const String _apiEncryptionKeyKey = 'security_api_encryption_key';

  /// Get Payment HMAC Secret
  ///
  /// Throws [SecurityConfigException] if not configured
  static Future<String> getPaymentHmacSecret() async {
    final secret = await _secureStorage.read(key: _paymentHmacSecretKey);
    if (secret == null || secret.isEmpty) {
      throw SecurityConfigException(
        'Payment HMAC secret not configured. '
        'Call SecurityConfig.configureSecrets() during app setup.',
      );
    }
    return secret;
  }

  /// Get API Encryption Key
  ///
  /// Throws [SecurityConfigException] if not configured
  static Future<String> getApiEncryptionKey() async {
    final key = await _secureStorage.read(key: _apiEncryptionKeyKey);
    if (key == null || key.isEmpty) {
      throw SecurityConfigException(
        'API encryption key not configured. '
        'Call SecurityConfig.configureSecrets() during app setup.',
      );
    }
    return key;
  }

  /// Configure all security secrets
  ///
  /// Call this during app initialization with secrets from secure source
  /// (e.g., fetched from backend after authentication, or from secure vault)
  static Future<void> configureSecrets({
    required String paymentHmacSecret,
    String? apiEncryptionKey,
  }) async {
    await _secureStorage.write(
      key: _paymentHmacSecretKey,
      value: paymentHmacSecret,
    );

    if (apiEncryptionKey != null) {
      await _secureStorage.write(
        key: _apiEncryptionKeyKey,
        value: apiEncryptionKey,
      );
    }
  }

  /// Check if secrets are configured
  static Future<bool> areSecretsConfigured() async {
    final hmacSecret = await _secureStorage.read(key: _paymentHmacSecretKey);
    return hmacSecret != null && hmacSecret.isNotEmpty;
  }

  /// Clear all secrets (for logout or security reset)
  static Future<void> clearSecrets() async {
    await _secureStorage.delete(key: _paymentHmacSecretKey);
    await _secureStorage.delete(key: _apiEncryptionKeyKey);
  }

  /// 2FA Settings (non-sensitive, can remain as constants)
  static const int tokenLength = 6;
  static const int maxRetries = 3;
  static const Duration tokenExpiry = Duration(minutes: 5);
}

/// Exception thrown when security configuration is missing or invalid
class SecurityConfigException implements Exception {
  final String message;

  SecurityConfigException(this.message);

  @override
  String toString() => 'SecurityConfigException: $message';
}
