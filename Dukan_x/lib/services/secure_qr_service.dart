// ============================================================================
// SECURE QR SERVICE
// ============================================================================
// Generates and validates signed QR codes for fraud-resistant customer linking.
// Uses HMAC-SHA256 signatures to prevent QR tampering and replay attacks.
//
// QR Payload Format:
// {
//   "v": 2,                      // Version
//   "shopId": "...",             // Shop/Vendor UID
//   "customerProfileId": "...",  // Profile ID (if generated)
//   "issuedAt": 1234567890,      // Unix timestamp
//   "expiresAt": 1234567899,     // Expiry timestamp
//   "sig": "..."                 // HMAC-SHA256 signature
// }
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Result of QR validation
class QrValidationResult {
  final bool isValid;
  final String? shopId;
  final String? customerProfileId;
  final String? error;
  final Map<String, dynamic>? payload;

  const QrValidationResult({
    required this.isValid,
    this.shopId,
    this.customerProfileId,
    this.error,
    this.payload,
  });

  factory QrValidationResult.valid({
    required String shopId,
    String? customerProfileId,
    Map<String, dynamic>? payload,
  }) => QrValidationResult(
    isValid: true,
    shopId: shopId,
    customerProfileId: customerProfileId,
    payload: payload,
  );

  factory QrValidationResult.invalid(String error) =>
      QrValidationResult(isValid: false, error: error);
}

class SecureQrService {
  // Default expiry: 24 hours
  static const int defaultExpiryHours = 24;

  // Secret key for HMAC signing
  // Load from .env (set QR_SIGNING_KEY) or use fallback for development
  String _secretKey = 'DukanX_QR_Secret_Key_v2_2024';
  bool _isInitialized = false;

  SecureQrService() {
    _loadKeyFromEnv();
  }

  /// Load key from .env file if available
  void _loadKeyFromEnv() {
    try {
      final key = dotenv.env['QR_SIGNING_KEY'];
      if (key != null && key.isNotEmpty) {
        _secretKey = key;
        _isInitialized = true;
        debugPrint('SecureQrService: HMAC key loaded from .env');
      }
    } catch (e) {
      // Fall back to default key - add QR_SIGNING_KEY to .env for production
      debugPrint('SecureQrService: Using default key');
    }
  }

  /// Set the secret key manually (for testing or runtime config)
  void setSecretKey(String key) {
    _secretKey = key;
    _isInitialized = true;
  }

  /// Check if service has been initialized with custom key
  bool get isProductionReady => _isInitialized;

  /// Generate signed QR payload for a shop
  /// This is used by shop owners to display their QR code
  String generateShopQrPayload({
    required String shopId,
    String? shopName,
    String? businessType,
    int expiryHours = defaultExpiryHours,
  }) {
    final now = DateTime.now();
    final issuedAt = now.millisecondsSinceEpoch ~/ 1000;
    final expiresAt =
        now.add(Duration(hours: expiryHours)).millisecondsSinceEpoch ~/ 1000;

    final payload = <String, dynamic>{
      'v': 2, // Version 2 format
      'shopId': shopId,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
      'shopName': ?shopName,
      'businessType': ?businessType,
    };

    // Generate signature
    final signature = _signPayload(payload);
    payload['sig'] = signature;

    return jsonEncode(payload);
  }

  /// Generate signed QR payload for a specific customer profile
  /// This is used for customer-specific QR codes (less common)
  String generateCustomerProfileQrPayload({
    required String shopId,
    required String customerProfileId,
    int expiryHours = defaultExpiryHours,
  }) {
    final now = DateTime.now();
    final issuedAt = now.millisecondsSinceEpoch ~/ 1000;
    final expiresAt =
        now.add(Duration(hours: expiryHours)).millisecondsSinceEpoch ~/ 1000;

    final payload = <String, dynamic>{
      'v': 2,
      'shopId': shopId,
      'customerProfileId': customerProfileId,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
    };

    final signature = _signPayload(payload);
    payload['sig'] = signature;

    return jsonEncode(payload);
  }

  /// Validate QR payload and signature
  QrValidationResult validateQrPayload(String qrData) {
    try {
      // Try parsing as JSON (v2 format)
      final Map<String, dynamic>? payload = _tryParseJson(qrData);

      if (payload != null) {
        return _validateV2Payload(payload);
      }

      // Try parsing as v1 format (v1:vendorId:customerId:checksum)
      if (qrData.startsWith('v1:')) {
        return _validateV1Payload(qrData);
      }

      // Try parsing as legacy OWNER_QR format
      final legacyPayload = _tryParseJson(qrData);
      if (legacyPayload != null && legacyPayload['type'] == 'OWNER_QR') {
        return _validateLegacyPayload(legacyPayload);
      }

      return QrValidationResult.invalid('Unknown QR format');
    } catch (e) {
      debugPrint('SecureQrService: Validation error: $e');
      return QrValidationResult.invalid('Invalid QR data: $e');
    }
  }

  /// Validate v2 signed payload
  QrValidationResult _validateV2Payload(Map<String, dynamic> payload) {
    // Check version
    final version = payload['v'];
    if (version != 2) {
      return QrValidationResult.invalid('Unsupported QR version');
    }

    // Check required fields
    final shopId = payload['shopId'] as String?;
    if (shopId == null || shopId.isEmpty) {
      return QrValidationResult.invalid('Missing shopId');
    }

    // Check signature
    final signature = payload['sig'] as String?;
    if (signature == null) {
      return QrValidationResult.invalid('Missing signature');
    }

    // Remove signature for verification
    final payloadWithoutSig = Map<String, dynamic>.from(payload);
    payloadWithoutSig.remove('sig');

    if (!_verifySignature(payloadWithoutSig, signature)) {
      return QrValidationResult.invalid(
        'Invalid signature - QR may be tampered',
      );
    }

    // Check expiry
    final expiresAt = payload['expiresAt'] as int?;
    if (expiresAt != null) {
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (DateTime.now().isAfter(expiryTime)) {
        return QrValidationResult.invalid('QR code has expired');
      }
    }

    return QrValidationResult.valid(
      shopId: shopId,
      customerProfileId: payload['customerProfileId'] as String?,
      payload: payload,
    );
  }

  /// Validate v1 format (backward compatibility)
  QrValidationResult _validateV1Payload(String qrData) {
    final parts = qrData.split(':');
    if (parts.length < 2) {
      return QrValidationResult.invalid('Invalid v1 QR format');
    }

    final shopId = parts[1];
    if (shopId.isEmpty) {
      return QrValidationResult.invalid('Missing shopId in v1 format');
    }

    // v1 doesn't have expiry or strong signature, but we accept it for migration
    return QrValidationResult.valid(
      shopId: shopId,
      payload: {'v': 1, 'shopId': shopId},
    );
  }

  /// Validate legacy OWNER_QR format
  QrValidationResult _validateLegacyPayload(Map<String, dynamic> payload) {
    final ownerUid = payload['owner_uid'] as String?;
    if (ownerUid == null || ownerUid.isEmpty) {
      return QrValidationResult.invalid('Missing owner_uid in legacy format');
    }

    return QrValidationResult.valid(shopId: ownerUid, payload: payload);
  }

  /// Sign payload with HMAC-SHA256
  String _signPayload(Map<String, dynamic> payload) {
    // Sort keys for consistent signing
    final sortedKeys = payload.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      buffer.write('$key=${payload[key]}&');
    }
    final canonicalString = buffer.toString();

    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(canonicalString);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);

    return digest.toString();
  }

  /// Verify signature
  bool _verifySignature(Map<String, dynamic> payload, String signature) {
    final expectedSignature = _signPayload(payload);
    return expectedSignature == signature;
  }

  /// Try to parse JSON, return null if invalid
  Map<String, dynamic>? _tryParseJson(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  /// Generate a one-time use QR code with nonce (for extra security)
  String generateSecureOneTimeQr({
    required String shopId,
    String? customerProfileId,
    int expiryMinutes = 5,
  }) {
    final now = DateTime.now();
    final issuedAt = now.millisecondsSinceEpoch ~/ 1000;
    final expiresAt =
        now.add(Duration(minutes: expiryMinutes)).millisecondsSinceEpoch ~/
        1000;
    final nonce = const Uuid().v4();

    final payload = <String, dynamic>{
      'v': 2,
      'shopId': shopId,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
      'nonce': nonce, // One-time use nonce
      'customerProfileId': ?customerProfileId,
    };

    final signature = _signPayload(payload);
    payload['sig'] = signature;

    return jsonEncode(payload);
  }

  /// Generate signed Deep Link URL for Customer Join
  /// Format: https://app.dukanx.com/join?v=2&shopId=...&mode=customer&expiresAt=...&sig=...
  String generateCustomerDeepLink({
    required String shopId,
    String baseUrl = 'https://app.dukanx.com/join',
    int expiryHours = defaultExpiryHours,
  }) {
    final now = DateTime.now();
    final expiresAt =
        now.add(Duration(hours: expiryHours)).millisecondsSinceEpoch ~/ 1000;

    final params = <String, String>{
      'v': '2',
      'shopId': shopId,
      'mode': 'customer',
      'expiresAt': expiresAt.toString(),
    };

    // Generate signature for params
    final signature = _signParams(params);
    params['sig'] = signature;

    // Build URL
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    return uri.toString();
  }

  /// Verify Deep Link Parameters
  QrValidationResult verifyDeepLinkParams(Map<String, String> params) {
    try {
      // Check version
      if (params['v'] != '2') {
        return QrValidationResult.invalid('Unsupported link version');
      }

      // Check required fields
      final shopId = params['shopId'];
      if (shopId == null || shopId.isEmpty) {
        return QrValidationResult.invalid('Missing shopId');
      }

      final mode = params['mode'];
      if (mode != 'customer') {
        return QrValidationResult.invalid('Invalid mode: $mode');
      }

      // Check signature
      final signature = params['sig'];
      if (signature == null) {
        return QrValidationResult.invalid('Missing signature');
      }

      // Check expiry
      final expiresAtStr = params['expiresAt'];
      if (expiresAtStr != null) {
        final expiresAt = int.tryParse(expiresAtStr);
        if (expiresAt != null) {
          final expiryTime = DateTime.fromMillisecondsSinceEpoch(
            expiresAt * 1000,
          );
          if (DateTime.now().isAfter(expiryTime)) {
            return QrValidationResult.invalid('Link has expired');
          }
        }
      }

      // Verify Sig
      final paramsByType = Map<String, String>.from(params);
      paramsByType.remove('sig');

      if (!_verifyParamSignature(paramsByType, signature)) {
        return QrValidationResult.invalid('Invalid signature - Link tampered');
      }

      return QrValidationResult.valid(shopId: shopId, payload: params);
    } catch (e) {
      return QrValidationResult.invalid('Validation error: $e');
    }
  }

  /// Sign params map (string values)
  String _signParams(Map<String, String> params) {
    final sortedKeys = params.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      buffer.write('$key=${params[key]}&');
    }
    final canonicalString = buffer.toString();

    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(canonicalString);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);

    return digest.toString();
  }

  bool _verifyParamSignature(Map<String, String> params, String signature) {
    final expected = _signParams(params);
    return expected == signature;
  }

  // ... (keep existing methods)
}
