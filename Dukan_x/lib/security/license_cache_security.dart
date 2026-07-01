// ============================================================================
// License Cache Security Service
// ============================================================================
// Provides integrity verification for locally cached license data stored
// in the Drift SQLite database.
//
// CRIT-004 FIX: Replaced XOR-based checksum (trivially reversible) with
// HMAC-SHA256 using device-fingerprint-derived key. This makes offline
// license tampering computationally infeasible.
//
// Security model:
//   - Key fields are base64-encoded before storage (obfuscation layer)
//   - HMAC-SHA256 checksum is computed from critical fields combined with
//     device fingerprint to detect any tampering
//   - On read, HMAC is re-computed and compared in constant time
// ============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../core/services/logger_service.dart';

/// Provides integrity protection for cached license data.
///
/// Usage in LicenseService:
///   - Before storing: call [protectFields] to encode sensitive fields + generate checksum
///   - Before reading: call [verifyIntegrity] to check if HMAC still matches
class LicenseCacheSecurityService {
  /// HMAC key derived from device fingerprint
  final List<int> _hmacKey;

  LicenseCacheSecurityService(String deviceFingerprint)
    : _hmacKey = _deriveHmacKey(deviceFingerprint);

  /// Derive an HMAC key from the device fingerprint using SHA-256.
  /// This ties the cache integrity to the specific device.
  static List<int> _deriveHmacKey(String fingerprint) {
    final salt = 'DukanX-CacheIntegrity-v2-HMAC';
    final mixed = '$salt:$fingerprint';
    // Use SHA-256 of the salted fingerprint as the HMAC key (32 bytes)
    return sha256.convert(utf8.encode(mixed)).bytes;
  }

  /// Encode a sensitive string field for storage.
  /// Uses base64 encoding to prevent plain-text reads of the SQLite file.
  String encodeField(String value) {
    return base64Encode(utf8.encode(value));
  }

  /// Decode a previously encoded field.
  String decodeField(String encoded) {
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (e) {
      LoggerService.d('LicenseCache', 'LicenseCacheSecurity: decode error: $e');
      return encoded; // Fallback — might be unencoded (migration)
    }
  }

  /// Compute HMAC-SHA256 checksum over critical license fields.
  /// CRIT-004 FIX: Replaces trivially-reversible XOR hash with
  /// cryptographic HMAC — computationally infeasible to forge.
  String computeChecksum(Map<String, String> fields) {
    final payload = StringBuffer();

    // Deterministic field ordering
    final orderedKeys = [
      'licenseKey',
      'status',
      'expiryDate',
      'enabledModulesJson',
      'licenseType',
      'maxDevices',
      'offlineGraceDays',
    ];

    for (final key in orderedKeys) {
      payload.write(fields[key] ?? '');
      payload.write('|');
    }

    // HMAC-SHA256 with device-fingerprint-derived key
    final hmac = Hmac(sha256, _hmacKey);
    final digest = hmac.convert(utf8.encode(payload.toString()));

    return base64Encode(digest.bytes);
  }

  /// Verify that the stored checksum matches the current field values.
  /// Returns true if integrity is valid, false if tampered.
  bool verifyIntegrity(Map<String, String> fields, String storedChecksum) {
    final computed = computeChecksum(fields);
    // Constant-time comparison to prevent timing attacks
    if (computed.length != storedChecksum.length) return false;
    int result = 0;
    for (int i = 0; i < computed.length; i++) {
      result |= computed.codeUnitAt(i) ^ storedChecksum.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Protect fields before caching.
  /// Returns encoded fields + HMAC integrity checksum to store alongside the record.
  ({String encodedModules, String encodedStatus, String checksum})
  protectFields({
    required String licenseKey,
    required String status,
    required String expiryDate,
    required String enabledModulesJson,
    required String licenseType,
    required int maxDevices,
    required int offlineGraceDays,
  }) {
    final encodedModules = encodeField(enabledModulesJson);
    final encodedStatus = encodeField(status);

    final checksum = computeChecksum({
      'licenseKey': licenseKey,
      'status': status,
      'expiryDate': expiryDate,
      'enabledModulesJson': enabledModulesJson,
      'licenseType': licenseType,
      'maxDevices': maxDevices.toString(),
      'offlineGraceDays': offlineGraceDays.toString(),
    });

    return (
      encodedModules: encodedModules,
      encodedStatus: encodedStatus,
      checksum: checksum,
    );
  }
}
