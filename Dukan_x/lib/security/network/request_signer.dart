import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../../core/services/logger_service.dart';

/// API Request Signing Service
/// Signs every outgoing API request with HMAC-SHA256 to prove it originated
/// from the legitimate desktop application (not forged by an attacker).
///
/// SECURITY:
///   - Uses HMAC-SHA256 with a per-installation signing key
///   - Includes nonce (one-time use) to prevent replay attacks
///   - Includes timestamp for time-bound validity (5-minute window)
///   - Content hash ensures body integrity
///
/// Headers added to each request:
///   X-Request-Signature: HMAC-SHA256 of (method + path + timestamp + bodyHash)
///   X-Request-Timestamp: Unix timestamp in milliseconds
///   X-Nonce:             Random UUID nonce (one-time use)
class RequestSigningService {
  late String _signingKey;
  bool _isInitialized = false;

  /// Random generator for nonces
  final _random = Random.secure();

  /// Initialize with the app signing key.
  /// The signing key should be derived from secure storage or device fingerprint.
  Future<void> initialize(String signingKey) async {
    _signingKey = signingKey;
    _isInitialized = true;
    LoggerService.d('RequestSigner', '🔐 Request signing initialized');
  }

  /// Sign an API request and return the security headers.
  ///
  /// Usage:
  /// ```dart
  /// final headers = requestSigner.signRequest(
  ///   method: 'POST',
  ///   path: '/payment/initiate',
  ///   body: jsonEncode(requestBody),
  /// );
  /// // Merge headers into HTTP request
  /// ```
  Map<String, String> signRequest({
    required String method,
    required String path,
    String? body,
  }) {
    if (!_isInitialized) {
      LoggerService.d('RequestSigner', '⚠️ Request signer not initialized — skipping signing');
      return {};
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = _generateNonce();
    final bodyHash = _computeBodyHash(body);

    // Create the canonical string to sign
    // Format: METHOD\nPATH\nTIMESTAMP\nBODY_HASH
    final canonical = '$method\n$path\n$timestamp\n$bodyHash';

    // Compute HMAC-SHA256 signature
    final hmac = Hmac(sha256, utf8.encode(_signingKey));
    final signature = hmac.convert(utf8.encode(canonical)).toString();

    return {
      'X-Request-Signature': signature,
      'X-Request-Timestamp': timestamp,
      'X-Nonce': nonce,
    };
  }

  /// Compute SHA-256 hash of the request body.
  /// Empty body results in hash of empty string.
  String _computeBodyHash(String? body) {
    final content = body ?? '';
    return sha256.convert(utf8.encode(content)).toString();
  }

  /// Generate a cryptographically secure nonce.
  /// Format: 32 hex characters (128 bits of entropy).
  String _generateNonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool get isInitialized => _isInitialized;

  void dispose() {
    _isInitialized = false;
  }
}
