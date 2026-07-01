// ============================================================================
// LOCAL_LICENSE_FILE — AES-256-GCM encrypted activation result on disk
// ============================================================================
// Feature: offline-license-activation (Task 4.3)
//
// The Local_License_File is the on-disk activation result. It stores the
// License_Token (plus the bound Machine_Fingerprint and the trusted
// `lastValidatedAt` reference) encrypted with AES-256-GCM using a key derived
// via PBKDF2 from the Fingerprint_Hash and the application secret
// (Requirements 5.6, 17.3). The encrypted envelope is written to an
// OS-specific secure location (Requirements 5.7, 20.4).
//
// File format (design "Data Models → Local_License_File"):
//   {
//     "v": 1,
//     "alg": "AES-256-GCM",
//     "iv":  "<base64 12-byte nonce>",
//     "tag": "<base64 16-byte GCM auth tag>",
//     "ciphertext": "<base64 of UTF-8 JSON { licenseToken, machineFingerprint,
//                     lastValidatedAt }>"
//   }
//
// SECURITY (AGENTS.md "Never expose API keys or secrets"):
//   * The application secret is NEVER hardcoded. It is loaded at runtime by the
//     existing `LocalStoreEncryption.loadAppSecret()` seam (secure storage →
//     git-ignored `.env` fallback), exactly as `local_store_crypto.dart` does
//     for the SQLCipher key.
//   * The PBKDF2 key derivation reuses the same PBKDF2-HMAC-SHA256 primitive,
//     iteration count, and key length already used for the Local_Store, so
//     there is a single, audited derivation pattern across the offline stack.
//   * Decryption is authenticated: any altered ciphertext, IV, tag, or a key
//     derived from a different Fingerprint_Hash / secret fails the GCM tag
//     check, so the file is usable iff its integrity verifies (Requirement
//     17.11). This is leveraged by the License_Validator (task 5.x).
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';

import '../security/crypto/key_derivation.dart';
import '../services/logger_service.dart';
import 'license_token.dart';

/// Outcome of a Local_License_File integrity check (Requirements 17.11, 17.16).
enum LicenseFileIntegrity {
  /// The file exists, decrypts/authenticates, and parses — safe to use.
  verified,

  /// The file exists but failed authenticated decryption or could not be
  /// parsed (tampered, wrong key inputs, or corrupt). Use MUST be blocked.
  failed,

  /// No Local_License_File is present (the machine is not activated yet).
  absent,
}

/// Small value returned by [LocalLicenseFile.verifyIntegrity] so callers can
/// gate use of the license file without catching exceptions.
class LicenseFileIntegrityResult {
  final LicenseFileIntegrity status;

  const LicenseFileIntegrityResult(this.status);

  /// True only when the file exists and its integrity verified (Req 17.11).
  bool get isUsable => status == LicenseFileIntegrity.verified;

  /// True when a file is present but failed verification (Req 17.16).
  bool get isTampered => status == LicenseFileIntegrity.failed;

  @override
  String toString() => 'LicenseFileIntegrityResult($status)';
}

/// The plaintext payload stored (encrypted) inside the Local_License_File.
class LocalLicensePayload {
  /// The RS256 License_Token issued by the License_Server.
  final LicenseToken token;

  /// The Machine_Fingerprint the license was activated against, as a map of the
  /// five components (cpuId, macAddress, hddSerial, osType, hostname).
  final Map<String, dynamic> machineFingerprint;

  /// The trusted time reference recorded at activation / last successful
  /// validation. Seeds the License_Validator grace-period calculation.
  final DateTime lastValidatedAt;

  const LocalLicensePayload({
    required this.token,
    required this.machineFingerprint,
    required this.lastValidatedAt,
  });

  Map<String, dynamic> toJson() => {
    'licenseToken': token.raw,
    'machineFingerprint': machineFingerprint,
    'lastValidatedAt': lastValidatedAt.toUtc().toIso8601String(),
  };

  factory LocalLicensePayload.fromJson(Map<String, dynamic> json) {
    return LocalLicensePayload(
      token: LicenseToken.fromJwt(json['licenseToken'] as String),
      machineFingerprint:
          (json['machineFingerprint'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      lastValidatedAt:
          DateTime.tryParse(
            json['lastValidatedAt'] as String? ?? '',
          )?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

/// Encrypts, writes, reads, and decrypts the Local_License_File.
///
/// All cryptographic operations are pure functions of (plaintext, Fingerprint_Hash,
/// appSecret); the only side effects are file I/O against the OS-specific secure
/// location resolved by [resolveLicenseFilePath].
class LocalLicenseFile {
  static const String _logTag = 'LocalLicenseFile';

  /// Envelope format version.
  static const int formatVersion = 1;

  /// Algorithm label written into the envelope.
  static const String algorithm = 'AES-256-GCM';

  /// AES-256 key length in bytes.
  static const int keyLengthBytes = 32;

  /// GCM nonce/IV length in bytes (96-bit, the GCM-recommended size).
  static const int ivLengthBytes = 12;

  /// GCM authentication tag length in bytes (128-bit).
  static const int tagLengthBytes = 16;

  /// PBKDF2 iteration count. Matches the Local_Store derivation cost; runs once
  /// per activation / file open, not per query.
  static const int pbkdf2Iterations = OfflineKeyDerivation.defaultIterations;

  /// Directory name under the OS data root.
  static const String _appDirName = 'DukanX';

  /// Sub-directory holding the license file.
  static const String _licenseDirName = 'license';

  /// The license file name.
  static const String _licenseFileName = 'license.dat';

  /// Optional explicit base directory. When null, [resolveLicenseDirectory]
  /// derives the OS-specific secure location. Injectable for tests.
  final String? _overrideBaseDir;

  /// Secure-random source for the GCM nonce.
  final Random _random;

  LocalLicenseFile({String? overrideBaseDir, Random? random})
    : _overrideBaseDir = overrideBaseDir,
      _random = random ?? Random.secure();

  // --------------------------------------------------------------------------
  // File locations (Requirements 5.7, 20.4)
  // --------------------------------------------------------------------------

  /// Resolves the OS-specific secure directory that holds the Local_License_File:
  ///   * Windows: `%APPDATA%/DukanX/license/`
  ///   * macOS:   `~/Library/Application Support/DukanX/license/`
  ///   * Linux:   `$XDG_DATA_HOME/DukanX/license/`
  ///              (fallback `~/.local/share/DukanX/license/`)
  ///
  /// The directory is created if it does not exist.
  Future<Directory> resolveLicenseDirectory() async {
    final base = _overrideBaseDir ?? await _osDataRoot();
    final dir = Directory(p.join(base, _appDirName, _licenseDirName));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Full path to the Local_License_File.
  Future<String> resolveLicenseFilePath() async {
    final dir = await resolveLicenseDirectory();
    return p.join(dir.path, _licenseFileName);
  }

  Future<String> _osDataRoot() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) return appData;
      // Fallback to the platform application-support directory.
      return (await getApplicationSupportDirectory()).path;
    }

    if (Platform.isMacOS) {
      // ~/Library/Application Support
      return (await getApplicationSupportDirectory()).path;
    }

    if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_DATA_HOME'];
      if (xdg != null && xdg.isNotEmpty) return xdg;
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return p.join(home, '.local', 'share');
      }
      return (await getApplicationSupportDirectory()).path;
    }

    // Other platforms: use the application-support directory.
    return (await getApplicationSupportDirectory()).path;
  }

  // --------------------------------------------------------------------------
  // Existence / removal
  // --------------------------------------------------------------------------

  /// Whether a Local_License_File currently exists on disk.
  Future<bool> exists() async {
    final path = await resolveLicenseFilePath();
    return File(path).existsSync();
  }

  /// Deletes the Local_License_File if present (used on migration / reset).
  Future<void> delete() async {
    final path = await resolveLicenseFilePath();
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  // --------------------------------------------------------------------------
  // Write (encrypt) — Requirement 5.6
  // --------------------------------------------------------------------------

  /// Encrypts [payload] with AES-256-GCM under a PBKDF2 key derived from
  /// [fingerprintHash] + [appSecret] and writes it to the OS-specific secure
  /// location. Returns the file path written.
  ///
  /// The write is staged to a temporary file and atomically renamed into place
  /// so a crash mid-write never leaves a half-written license file.
  Future<String> write({
    required LocalLicensePayload payload,
    required String fingerprintHash,
    required String appSecret,
  }) async {
    final envelope = encryptToEnvelope(
      plaintext: utf8.encode(jsonEncode(payload.toJson())),
      fingerprintHash: fingerprintHash,
      appSecret: appSecret,
    );

    final path = await resolveLicenseFilePath();
    final tmp = File('$path.tmp');
    await tmp.writeAsString(jsonEncode(envelope), flush: true);
    await tmp.rename(path);
    LoggerService.i(_logTag, 'Local_License_File written to secure location.');
    return path;
  }

  // --------------------------------------------------------------------------
  // Read (decrypt) — leveraged by the License_Validator (Requirement 17.11)
  // --------------------------------------------------------------------------

  /// Reads and decrypts the Local_License_File. Returns `null` when no file
  /// exists. Throws [InvalidCipherTextException] / [FormatException] when the
  /// file is tampered with or the key inputs are wrong (authenticated failure).
  Future<LocalLicensePayload?> read({
    required String fingerprintHash,
    required String appSecret,
  }) async {
    final path = await resolveLicenseFilePath();
    final file = File(path);
    if (!file.existsSync()) return null;

    final envelope =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final plaintext = decryptFromEnvelope(
      envelope: envelope,
      fingerprintHash: fingerprintHash,
      appSecret: appSecret,
    );
    final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    return LocalLicensePayload.fromJson(json);
  }

  // --------------------------------------------------------------------------
  // Integrity verification (Requirements 17.11, 17.16)
  // --------------------------------------------------------------------------

  /// Verifies the integrity of the Local_License_File BEFORE it is used, as the
  /// Security_Layer requires on offline startup (Requirement 17.11).
  ///
  /// Integrity holds iff the on-disk envelope decrypts and authenticates under
  /// a key derived from [fingerprintHash] + [appSecret] (the AES-256-GCM tag
  /// check) AND the recovered plaintext parses into a well-formed
  /// [LocalLicensePayload]. Any tampering of the IV, tag, ciphertext, or
  /// envelope structure, or a wrong key input, fails the check.
  ///
  /// This NEVER throws and NEVER logs secret material — it returns a small
  /// result the caller acts on. When a file does not exist the result is
  /// [LicenseFileIntegrity.absent] (there is nothing to verify yet); when it
  /// exists but does not verify, the caller MUST prevent use of the file and
  /// report the failure (Requirement 17.16).
  Future<LicenseFileIntegrityResult> verifyIntegrity({
    required String fingerprintHash,
    required String appSecret,
  }) async {
    final path = await resolveLicenseFilePath();
    final file = File(path);
    if (!file.existsSync()) {
      return const LicenseFileIntegrityResult(LicenseFileIntegrity.absent);
    }

    try {
      final payload = await read(
        fingerprintHash: fingerprintHash,
        appSecret: appSecret,
      );
      if (payload == null) {
        return const LicenseFileIntegrityResult(LicenseFileIntegrity.absent);
      }
      return const LicenseFileIntegrityResult(LicenseFileIntegrity.verified);
    } catch (e) {
      // Authenticated-decryption failure, malformed envelope, or unparsable
      // payload. Do NOT include the exception detail in the log to avoid
      // leaking key-related material (Requirement 17.10).
      LoggerService.w(
        _logTag,
        'Local_License_File failed integrity verification; use is blocked.',
      );
      return const LicenseFileIntegrityResult(LicenseFileIntegrity.failed);
    }
  }

  // --------------------------------------------------------------------------
  // Pure crypto core
  // --------------------------------------------------------------------------

  /// Encrypts [plaintext] and returns the JSON-serializable envelope map.
  Map<String, dynamic> encryptToEnvelope({
    required List<int> plaintext,
    required String fingerprintHash,
    required String appSecret,
  }) {
    final key = _deriveKey(
      fingerprintHash: fingerprintHash,
      appSecret: appSecret,
    );
    final iv = _randomBytes(ivLengthBytes);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), tagLengthBytes * 8, iv, Uint8List(0)),
      );

    // pointycastle appends the GCM tag to the end of the encryption output.
    final out = cipher.process(Uint8List.fromList(plaintext));
    final ctLen = out.length - tagLengthBytes;
    final ciphertext = Uint8List.sublistView(out, 0, ctLen);
    final tag = Uint8List.sublistView(out, ctLen);

    return {
      'v': formatVersion,
      'alg': algorithm,
      'iv': base64Encode(iv),
      'tag': base64Encode(tag),
      'ciphertext': base64Encode(ciphertext),
    };
  }

  /// Decrypts an [envelope] produced by [encryptToEnvelope]. Throws on a failed
  /// GCM authentication check (wrong key inputs or tampered data).
  Uint8List decryptFromEnvelope({
    required Map<String, dynamic> envelope,
    required String fingerprintHash,
    required String appSecret,
  }) {
    final iv = base64Decode(envelope['iv'] as String);
    final tag = base64Decode(envelope['tag'] as String);
    final ciphertext = base64Decode(envelope['ciphertext'] as String);

    final key = _deriveKey(
      fingerprintHash: fingerprintHash,
      appSecret: appSecret,
    );

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), tagLengthBytes * 8, iv, Uint8List(0)),
      );

    // Recombine ciphertext+tag so GCM can validate the authentication tag.
    final combined = Uint8List(ciphertext.length + tag.length)
      ..setRange(0, ciphertext.length, ciphertext)
      ..setRange(ciphertext.length, ciphertext.length + tag.length, tag);

    return cipher.process(combined);
  }

  /// PBKDF2-HMAC-SHA256 key derivation from the Fingerprint_Hash + app secret.
  ///
  /// Delegates to the centralised [OfflineKeyDerivation] so this AES-256-GCM key
  /// and the Local_Store SQLCipher key share one audited PBKDF2 primitive (the
  /// Security_Layer's single derivation seam — task 18.1). The Fingerprint_Hash
  /// and the application secret form the PBKDF2 password; the fixed context
  /// label forms the salt. Identical inputs always yield the same key (so the
  /// same machine can decrypt its file), while any altered input yields a
  /// different key that fails the GCM tag check.
  Uint8List _deriveKey({
    required String fingerprintHash,
    required String appSecret,
  }) {
    return OfflineKeyDerivation.deriveLicenseFileKey(
      fingerprintHash: fingerprintHash,
      appSecret: appSecret,
      iterations: pbkdf2Iterations,
      keyLengthBytes: keyLengthBytes,
    );
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}
