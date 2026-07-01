// ============================================================================
// LOCAL_STORE CRYPTO — SQLCipher key derivation seam
// ============================================================================
// Offline License Activation — task 7.2 (Requirements 8.3, 17.1, 17.3).
//
// This file provides the *injectable seam* used to encrypt the offline
// Local_Store with SQLCipher. It does two things:
//
//   1. Derives the SQLCipher key deterministically from the three binding
//      inputs the spec mandates: the Fingerprint_Hash, the tenant identifier,
//      and the application secret (Requirement 8.3).
//   2. Holds the *active* key behind a small singleton so the database
//      `beforeOpen` hook can apply `PRAGMA key` only when a key has actually
//      been configured. This keeps existing UNENCRYPTED databases opening
//      exactly as before — encryption is opt-in and wired on by the
//      Activation_Service / Security_Layer (later tasks 4.x / 18.1), never by
//      simply importing this file.
//
// SECURITY (AGENTS.md "Never expose API keys or secrets"):
//   - The application secret is NEVER hardcoded in source. It is read at
//     runtime from FlutterSecureStorage first, then from the `.env`
//     (LOCAL_STORE_APP_SECRET) as a build/deploy-time fallback. If neither is
//     present, no key is derived and the store opens unencrypted (preserving
//     today's behavior) rather than failing closed and bricking the app.
//   - The derived key is a raw 256-bit key, hex-encoded, applied via the
//     SQLCipher raw-key syntax  PRAGMA key = "x'<64-hex>'"  so SQLCipher skips
//     its own (slower, salted) key-derivation and uses the bytes verbatim.
//   - Derivation uses PBKDF2-HMAC-SHA256, matching the design glossary
//     (Local_License_File / Local_Store "PBKDF2" derivation).
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../security/crypto/key_derivation.dart';

/// Derives the raw SQLCipher key for the offline Local_Store.
///
/// The key is a pure, deterministic function of (Fingerprint_Hash, tenant id,
/// application secret) — identical inputs always yield the same key, so the
/// same machine + tenant can always re-open its encrypted store, while a
/// different machine (different Fingerprint_Hash) or tenant derives a different
/// key and cannot decrypt it (Requirement 8.3).
class LocalStoreKeyDeriver {
  LocalStoreKeyDeriver._();

  /// PBKDF2 iteration count. High enough to be costly to brute force, while
  /// only running once per database open (not per query).
  static const int defaultIterations = OfflineKeyDerivation.defaultIterations;

  /// 256-bit key (SQLCipher default cipher key size).
  static const int keyLengthBytes = OfflineKeyDerivation.defaultKeyLengthBytes;

  /// Derive the raw SQLCipher key as a 64-character lowercase hex string.
  ///
  /// Binding inputs (all three are required by Requirement 8.3):
  ///  - [fingerprintHash] : SHA256(cpuId + macAddress + hddSerial)
  ///  - [tenantId]        : the owning tenant identifier
  ///  - [appSecret]       : the runtime-loaded application secret
  ///
  /// Delegates to the centralised [OfflineKeyDerivation] so the SQLCipher key
  /// and the Local_License_File key share one audited PBKDF2 primitive (the
  /// Security_Layer's single derivation seam — task 18.1). The Fingerprint_Hash
  /// and the application secret form the PBKDF2 password; the tenant id (plus a
  /// fixed context label) forms the salt, so every one of the three inputs
  /// influences the resulting key.
  static String deriveSqlcipherKey({
    required String fingerprintHash,
    required String tenantId,
    required String appSecret,
    int iterations = defaultIterations,
  }) {
    return OfflineKeyDerivation.deriveSqlcipherKeyHex(
      fingerprintHash: fingerprintHash,
      tenantId: tenantId,
      appSecret: appSecret,
      iterations: iterations,
    );
  }
}

/// Holds the active SQLCipher key for the Local_Store and loads the application
/// secret without ever hardcoding it.
///
/// This is the injectable seam the database open path consults. By default no
/// key is active, so [AppDatabase] opens the existing (unencrypted) database
/// unchanged. The Activation_Service / Security_Layer call [configure] once the
/// machine is activated and the Fingerprint_Hash + tenant id are known; from
/// then on the store is opened with `PRAGMA key`.
class LocalStoreEncryption {
  /// Production constructor — uses the default platform secure storage.
  /// Visible for the singleton and for tests that want a real backend.
  LocalStoreEncryption({FlutterSecureStorage? secureStorage})
    : _storage = secureStorage ?? const FlutterSecureStorage();

  /// Process-wide singleton consulted by the database open path.
  static final LocalStoreEncryption instance = LocalStoreEncryption();

  /// Secure-storage key under which the application secret is provisioned at
  /// runtime (preferred over the `.env` fallback).
  static const String secureStorageSecretKey = 'local_store_app_secret';

  /// `.env` variable name holding the application secret as a deploy-time
  /// fallback. The `.env` file is git-ignored (see Dukan_x/.gitignore), so this
  /// is not a committed/hardcoded secret.
  static const String envSecretKey = 'LOCAL_STORE_APP_SECRET';

  final FlutterSecureStorage _storage;

  String? _activeKeyHex;

  /// The currently active raw key (hex), or null when encryption is not
  /// configured. The database open path reads this.
  String? get activeKeyHex => _activeKeyHex;

  /// Whether a SQLCipher key is currently active.
  bool get isEnabled => _activeKeyHex != null && _activeKeyHex!.isNotEmpty;

  /// Inject a pre-derived raw key (hex). Primarily for tests and for callers
  /// that derive the key through the Security_Layer themselves.
  void setRawKeyHex(String? hexKey) => _activeKeyHex = hexKey;

  /// Derive and activate the SQLCipher key from the binding inputs.
  ///
  /// Returns true when a key was successfully derived and activated; false when
  /// the application secret is unavailable or an input is missing (in which
  /// case the store will continue to open unencrypted — existing behavior).
  ///
  /// Must be called before the first database query (the connection is lazy,
  /// so calling it during the offline Startup_Sequence is sufficient).
  Future<bool> configure({
    required String fingerprintHash,
    required String tenantId,
    String? appSecret,
  }) async {
    if (fingerprintHash.isEmpty || tenantId.isEmpty) {
      debugPrint(
        'LocalStoreEncryption: missing fingerprint/tenant — leaving store '
        'unencrypted',
      );
      return false;
    }

    final secret = appSecret ?? await loadAppSecret();
    if (secret == null || secret.isEmpty) {
      debugPrint(
        'LocalStoreEncryption: no application secret configured — leaving '
        'store unencrypted',
      );
      return false;
    }

    _activeKeyHex = LocalStoreKeyDeriver.deriveSqlcipherKey(
      fingerprintHash: fingerprintHash,
      tenantId: tenantId,
      appSecret: secret,
    );
    return true;
  }

  /// Load the application secret at runtime. Never hardcoded.
  ///
  /// Lookup order:
  ///   1. FlutterSecureStorage[[secureStorageSecretKey]] (runtime-provisioned)
  ///   2. dotenv[[envSecretKey]] (git-ignored `.env` deploy-time fallback)
  /// Returns null when neither is present.
  Future<String?> loadAppSecret() async {
    try {
      final fromSecure = await _storage.read(key: secureStorageSecretKey);
      if (fromSecure != null && fromSecure.isNotEmpty) return fromSecure;
    } catch (e) {
      debugPrint('LocalStoreEncryption: secure storage read failed: $e');
    }

    try {
      if (dotenv.isInitialized) {
        final fromEnv = dotenv.maybeGet(envSecretKey);
        if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
      }
    } catch (_) {
      // dotenv not initialised / unavailable — ignore and fall through.
    }
    return null;
  }

  /// Clear the active key (e.g. on logout / migration). The next open will be
  /// unencrypted unless reconfigured.
  void clear() => _activeKeyHex = null;
}
