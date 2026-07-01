// KYC Field-Level Encryption/Redaction Boundary
// Protects PMLA KYC PII (customerIdNumber, customerPhotoUrl) at rest.
// Uses AES-256-CBC with tenant-scoped key derivation via HMAC-SHA256.
// Requirement 11.1: field-level encryption at rest
// Requirement 11.2: tenant-scoped records
// Requirement 11.3: redacted display (last-4)
// Requirement 11.4: withhold on decryption failure

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Result of a KYC field decryption attempt.
/// On success, [value] holds the plaintext; on failure, [value] is null
/// and [hasError] is true — the caller must withhold the value and show
/// an error indication (Requirement 11.4).
class KycDecryptResult {
  final String? value;
  final bool hasError;
  final String? errorMessage;

  const KycDecryptResult.success(this.value)
    : hasError = false,
      errorMessage = null;

  const KycDecryptResult.failure([this.errorMessage])
    : value = null,
      hasError = true;
}

/// Boundary for encrypting/decrypting/redacting PMLA KYC PII fields.
///
/// Tenant isolation: a per-tenant key is derived from the master key using
/// HMAC-SHA256(masterKey, tenantId). This ensures that even if two tenants
/// store the same id number, the ciphertext differs, and one tenant's key
/// cannot decrypt another tenant's data.
///
/// Encryption format: base64([IV 16 bytes] || [AES-256-CBC ciphertext])
class KycFieldCrypto {
  static const _masterKeyStorage = 'kyc_aes_master_key_v1';
  static final FlutterSecureStorage _secure = const FlutterSecureStorage();

  /// Cache for derived keys to avoid repeated HMAC on hot paths.
  static final Map<String, Uint8List> _derivedKeyCache = {};

  // ──────────────────────────────────────────────────────────────────────────
  // KEY MANAGEMENT
  // ──────────────────────────────────────────────────────────────────────────

  /// Retrieve or generate the 32-byte master key from secure storage.
  static Future<Uint8List> _getMasterKey() async {
    final existing = await _secure.read(key: _masterKeyStorage);
    if (existing != null) {
      return base64Url.decode(existing);
    }

    // First-time: generate a cryptographically secure 32-byte key
    final random = Random.secure();
    final keyBytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _secure.write(
      key: _masterKeyStorage,
      value: base64Url.encode(keyBytes),
    );
    return keyBytes;
  }

  /// Derive a 32-byte tenant-scoped key using HMAC-SHA256(masterKey, tenantId).
  /// This ensures tenant isolation at the crypto layer (Requirement 11.2).
  static Future<Uint8List> _deriveKey(String tenantId) async {
    if (_derivedKeyCache.containsKey(tenantId)) {
      return _derivedKeyCache[tenantId]!;
    }

    final masterKey = await _getMasterKey();
    final hmac = Hmac(sha256, masterKey);
    final digest = hmac.convert(utf8.encode(tenantId));
    final derived = Uint8List.fromList(digest.bytes);
    _derivedKeyCache[tenantId] = derived;
    return derived;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ENCRYPT
  // ──────────────────────────────────────────────────────────────────────────

  /// Encrypt a PII plaintext field for the given tenant.
  /// Returns a base64 string of [IV (16 bytes) || ciphertext].
  /// Returns null if [plaintext] is null or empty (nothing to encrypt).
  static Future<String?> encrypt(String? plaintext, String tenantId) async {
    if (plaintext == null || plaintext.isEmpty) return null;

    final keyBytes = await _deriveKey(tenantId);
    final key = encrypt_pkg.Key(keyBytes);

    // Generate a random 16-byte IV per encryption call
    final random = Random.secure();
    final ivBytes = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final iv = encrypt_pkg.IV(ivBytes);

    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    // Combine IV + ciphertext
    final combined = Uint8List(16 + encrypted.bytes.length);
    combined.setAll(0, ivBytes);
    combined.setAll(16, encrypted.bytes);

    return base64.encode(combined);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DECRYPT
  // ──────────────────────────────────────────────────────────────────────────

  /// Decrypt a PII ciphertext field for the given tenant.
  /// Returns [KycDecryptResult.success] with the plaintext, or
  /// [KycDecryptResult.failure] if decryption fails for any reason
  /// (Requirement 11.4: withhold value, surface error indication).
  static Future<KycDecryptResult> decrypt(
    String? ciphertext,
    String tenantId,
  ) async {
    if (ciphertext == null || ciphertext.isEmpty) {
      return const KycDecryptResult.success(null);
    }

    try {
      final combined = base64.decode(ciphertext);

      if (combined.length <= 16) {
        return const KycDecryptResult.failure(
          'KYC field data is corrupted (too short)',
        );
      }

      final keyBytes = await _deriveKey(tenantId);
      final key = encrypt_pkg.Key(keyBytes);

      // Extract IV (first 16 bytes) and ciphertext (remainder)
      final iv = encrypt_pkg.IV(Uint8List.fromList(combined.sublist(0, 16)));
      final cipherBytes = Uint8List.fromList(combined.sublist(16));

      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc),
      );
      final plaintext = encrypter.decrypt(
        encrypt_pkg.Encrypted(cipherBytes),
        iv: iv,
      );

      return KycDecryptResult.success(plaintext);
    } catch (e) {
      // Requirement 11.4: never expose corrupted/partial data
      return KycDecryptResult.failure(
        'KYC field decryption failed: unable to read protected data',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // REDACT
  // ──────────────────────────────────────────────────────────────────────────

  /// Redact a customer ID number for display: show only the last 4 characters.
  /// Returns `****XXXX` format where XXXX are the last 4 visible chars.
  /// If the id is 4 chars or fewer, all are masked.
  /// (Requirement 11.3: redacted form, last-4 only)
  static String redact(String? idNumber) {
    if (idNumber == null || idNumber.isEmpty) return '****';
    if (idNumber.length <= 4) return '****';
    final last4 = idNumber.substring(idNumber.length - 4);
    return '****$last4';
  }

  /// Clear the derived-key cache (call on logout/session change).
  static void clearCache() {
    _derivedKeyCache.clear();
  }
}
