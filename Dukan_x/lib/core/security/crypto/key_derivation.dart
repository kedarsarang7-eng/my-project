// ============================================================================
// OFFLINE_KEY_DERIVATION — the single, audited runtime key-derivation seam
// ============================================================================
// Feature: offline-license-activation (Task 18.1 — Security_Layer)
//
// This is the ONE place the offline stack derives encryption keys. Both
// subsystems that need a key route through it:
//
//   * Local_License_File  → AES-256-GCM key  (Requirements 5.6, 17.3)
//   * Local_Store         → SQLCipher AES-256 key  (Requirements 8.3, 17.1)
//
// Centralising the primitive here (rather than copying PBKDF2 into each file)
// means there is a single, auditable derivation pattern across the offline
// stack, exactly as the design's Security_Layer mandates ("runtime-derived
// keys, never in source").
//
// SECURITY (Requirement 17.2 — "derive all encryption keys ... at runtime and
// SHALL NOT store encryption keys in source code"):
//   * This module derives keys PURELY from inputs passed in by the caller; it
//     contains NO key material and NO secret of its own.
//   * The application secret is always loaded at runtime by the caller (via
//     `LocalStoreEncryption.loadAppSecret()` → secure storage / git-ignored
//     `.env`), never hardcoded.
//   * Identical inputs always yield identical bytes, so the same machine +
//     tenant can re-open its data, while any altered input (different
//     Fingerprint_Hash, tenant, or secret) yields a different key that fails
//     the authenticated-decryption check.
//
// PRIMITIVE: PBKDF2-HMAC-SHA256, 100 000 iterations, 256-bit output. The
// Fingerprint_Hash + application secret form the PBKDF2 password; a fixed,
// per-subsystem context label (plus the tenant id for the store) forms the
// salt, so a key derived for one subsystem can never collide with another.
//
// PURE DART: no Flutter imports, so it composes cleanly with unit/property
// tests and the packaged stack.
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

/// Centralised PBKDF2-HMAC-SHA256 key derivation for the offline Security_Layer.
class OfflineKeyDerivation {
  OfflineKeyDerivation._();

  /// PBKDF2 iteration count. High enough to be costly to brute force, while
  /// running only once per activation / database open (not per query).
  static const int defaultIterations = 100000;

  /// 256-bit derived key (AES-256 / SQLCipher default cipher key size).
  static const int defaultKeyLengthBytes = 32;

  /// HMAC-SHA256 block size in bytes.
  static const int _hmacBlockSizeBytes = 64;

  /// Fixed context label for the Local_License_File AES-256-GCM key. Mixed into
  /// the salt so this key can never collide with another subsystem's key.
  static const String licenseFileSaltContext =
      'DukanX:LocalLicenseFile:AES-GCM:v1';

  /// Fixed context label for the Local_Store SQLCipher key. The owning tenant
  /// id is appended to this (see [deriveSqlcipherKeyHex]) so each tenant's
  /// store derives a distinct key.
  static const String sqlcipherSaltContext = 'DukanX:LocalStore:SQLCipher:v1';

  // --------------------------------------------------------------------------
  // Generic primitive
  // --------------------------------------------------------------------------

  /// Derives raw key bytes from [password] and [saltContext] using
  /// PBKDF2-HMAC-SHA256. The single low-level entry point all derivations use.
  static Uint8List deriveKeyBytes({
    required String password,
    required String saltContext,
    int iterations = defaultIterations,
    int keyLengthBytes = defaultKeyLengthBytes,
  }) {
    final pwd = Uint8List.fromList(utf8.encode(password));
    final salt = Uint8List.fromList(utf8.encode(saltContext));

    final derivator = PBKDF2KeyDerivator(
      HMac(SHA256Digest(), _hmacBlockSizeBytes),
    )..init(Pbkdf2Parameters(salt, iterations, keyLengthBytes));
    return derivator.process(pwd);
  }

  /// As [deriveKeyBytes], but returns the key as a lowercase hex string (the
  /// form SQLCipher's raw-key `PRAGMA key = "x'<hex>'"` syntax expects).
  static String deriveKeyHex({
    required String password,
    required String saltContext,
    int iterations = defaultIterations,
    int keyLengthBytes = defaultKeyLengthBytes,
  }) {
    return _toHex(
      deriveKeyBytes(
        password: password,
        saltContext: saltContext,
        iterations: iterations,
        keyLengthBytes: keyLengthBytes,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Named subsystem derivations (the composition lives here, in one place)
  // --------------------------------------------------------------------------

  /// Derives the AES-256-GCM key for the Local_License_File from the
  /// Fingerprint_Hash + application secret (Requirements 5.6, 17.3).
  static Uint8List deriveLicenseFileKey({
    required String fingerprintHash,
    required String appSecret,
    int iterations = defaultIterations,
    int keyLengthBytes = defaultKeyLengthBytes,
  }) {
    _requireNotEmpty(fingerprintHash, 'fingerprintHash');
    _requireNotEmpty(appSecret, 'appSecret');
    return deriveKeyBytes(
      password: '$fingerprintHash:$appSecret',
      saltContext: licenseFileSaltContext,
      iterations: iterations,
      keyLengthBytes: keyLengthBytes,
    );
  }

  /// Derives the SQLCipher key (as lowercase hex) for the Local_Store from the
  /// Fingerprint_Hash, tenant id, and application secret (Requirement 8.3).
  static String deriveSqlcipherKeyHex({
    required String fingerprintHash,
    required String tenantId,
    required String appSecret,
    int iterations = defaultIterations,
    int keyLengthBytes = defaultKeyLengthBytes,
  }) {
    _requireNotEmpty(fingerprintHash, 'fingerprintHash');
    _requireNotEmpty(tenantId, 'tenantId');
    _requireNotEmpty(appSecret, 'appSecret');
    return deriveKeyHex(
      password: '$fingerprintHash:$appSecret',
      saltContext: '$sqlcipherSaltContext:$tenantId',
      iterations: iterations,
      keyLengthBytes: keyLengthBytes,
    );
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  static void _requireNotEmpty(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
  }

  static String _toHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
