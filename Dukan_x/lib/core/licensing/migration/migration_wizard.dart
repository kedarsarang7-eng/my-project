// ============================================================================
// MIGRATION_WIZARD — move an activated installation to a new machine
// ============================================================================
// Feature: offline-license-activation (Task 15.1)
//
// The Migration_Wizard moves an activated DukanX installation from a source
// machine to a target machine WITHOUT losing data or the license, honouring
// Requirements 14.1–14.7:
//
//   * EXPORT (14.1): export the Local_Store data plus a signed deactivation
//     token from the source machine. The source machine stays activated and
//     usable until it is deactivated.
//   * OVERLAP WINDOW (14.2, 14.3, 14.5): a 48-hour window begins at the
//     deactivation timestamp carried by the token. Within the window the
//     target machine may be activated with that token and BOTH machines stay
//     usable. When the window elapses the source machine is deactivated and
//     must be reactivated before further use.
//   * VERIFIED IMPORT (14.4, 14.7): before importing, the exported Local_Store
//     data is integrity-verified (SHA-256 checksum). The import only proceeds
//     when verification passes; on failure it aborts and the target machine's
//     existing Local_Store is preserved unchanged (Property 30).
//   * TOKEN VALIDATION (14.6): an invalid or expired (>48h) token is rejected
//     with a reason and leaves the target machine unactivated (Property 31).
//
// REUSE, DON'T REBUILD:
//   * License storage + AES-256-GCM crypto → LocalLicenseFile (task 4.3).
//   * Machine identity + Fingerprint_Hash → FingerprintCollector (tasks 4.1/4.2).
//   * Runtime application secret → LocalStoreEncryption.loadAppSecret()
//     (never hardcoded; same seam used for the SQLCipher / license-file keys).
//   * Local_Store file location → the same documents-dir path
//     `connection_native.dart` opens (`dukanx_enterprise.sqlite`).
//
// SERVICE LAYER ONLY: no Flutter widget imports; injected via the service
// locator (wired by task 20.1). The pure overlap-window / validity logic
// (`isWithinOverlapWindow`, `MigrationTokenSigner.verify`) is the surface the
// Property 31 test (task 15.2) drives with generated inputs.
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../database/local_store_crypto.dart';
import '../../security/device/device_fingerprint.dart';
import '../../services/logger_service.dart';
import '../license_token.dart';
import '../local_license_file.dart';

/// The signed token that authorizes exactly one target-machine activation
/// during the 48-hour overlap window (Requirements 14.1, 14.2, 14.6).
///
/// The token carries the License_Token to transfer, the source binding, and the
/// `deactivatedAt` timestamp that marks the start of the overlap window. The
/// [signature] is an HMAC-SHA256 over the canonical payload using a key derived
/// from the application secret, so the token cannot be forged or have its
/// timestamp altered offline.
class DeactivationToken {
  /// The fixed overlap window that begins at [deactivatedAt] (Requirement 14.2).
  static const Duration overlapWindow = Duration(hours: 48);

  /// Unique id for this migration handoff.
  final String migrationId;

  /// Owning tenant identifier (copied from the source License_Token).
  final String tenantId;

  /// The raw RS256 License_Token (compact JWT) being transferred to the target.
  final String licenseTokenJwt;

  /// Fingerprint_Hash of the source machine the license was activated against.
  final String sourceFingerprintHash;

  /// The instant the overlap window begins. Activation on the target is allowed
  /// only while `now - deactivatedAt <= 48h` (Requirement 14.2).
  final DateTime deactivatedAt;

  /// HMAC-SHA256 (base64) over the canonical payload — proves the token is
  /// authentic and unmodified.
  final String signature;

  const DeactivationToken({
    required this.migrationId,
    required this.tenantId,
    required this.licenseTokenJwt,
    required this.sourceFingerprintHash,
    required this.deactivatedAt,
    required this.signature,
  });

  /// The instant the overlap window elapses (`deactivatedAt + 48h`).
  DateTime get windowEndsAt => deactivatedAt.add(overlapWindow);

  /// The deterministic string the [signature] is computed over. Any change to a
  /// covered field (including [deactivatedAt]) changes this string and so
  /// invalidates the signature.
  String get canonicalPayload => [
    migrationId,
    tenantId,
    licenseTokenJwt,
    sourceFingerprintHash,
    deactivatedAt.toUtc().toIso8601String(),
  ].join('|');

  Map<String, dynamic> toJson() => {
    'migrationId': migrationId,
    'tenantId': tenantId,
    'licenseTokenJwt': licenseTokenJwt,
    'sourceFingerprintHash': sourceFingerprintHash,
    'deactivatedAt': deactivatedAt.toUtc().toIso8601String(),
    'signature': signature,
  };

  factory DeactivationToken.fromJson(Map<String, dynamic> json) {
    return DeactivationToken(
      migrationId: json['migrationId'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      licenseTokenJwt: json['licenseTokenJwt'] as String? ?? '',
      sourceFingerprintHash: json['sourceFingerprintHash'] as String? ?? '',
      deactivatedAt:
          DateTime.tryParse(json['deactivatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      signature: json['signature'] as String? ?? '',
    );
  }
}

/// Signs and verifies [DeactivationToken]s with an application-secret-derived
/// HMAC-SHA256 key. Pure (hashing only, no I/O) so the validity property can be
/// driven directly.
class MigrationTokenSigner {
  MigrationTokenSigner._();

  /// Fixed context label mixed into the HMAC key so a migration signature can
  /// never collide with another DukanX subsystem that derives from the secret.
  static const String _keyContext = 'DukanX:Migration:DeactivationToken:v1';

  /// Computes the base64 HMAC-SHA256 signature of [canonicalPayload].
  static String sign({
    required String canonicalPayload,
    required String appSecret,
  }) {
    if (appSecret.isEmpty) {
      throw ArgumentError.value(appSecret, 'appSecret', 'must not be empty');
    }
    final mac = Hmac(sha256, _deriveKey(appSecret));
    return base64Encode(mac.convert(utf8.encode(canonicalPayload)).bytes);
  }

  /// True iff [token]'s signature matches its payload under [appSecret].
  /// Uses a constant-time comparison to avoid timing leaks.
  static bool verify({
    required DeactivationToken token,
    required String appSecret,
  }) {
    if (appSecret.isEmpty || token.signature.isEmpty) return false;
    final expected = sign(
      canonicalPayload: token.canonicalPayload,
      appSecret: appSecret,
    );
    return _constantTimeEquals(expected, token.signature);
  }

  static List<int> _deriveKey(String appSecret) =>
      sha256.convert(utf8.encode('$_keyContext:$appSecret')).bytes;

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

/// The exported Local_Store data plus its integrity checksum (Requirement 14.4).
class MigrationDataPackage {
  /// Raw bytes of the source Local_Store file.
  final Uint8List storeBytes;

  /// SHA-256 (hex) of [storeBytes], verified before import (Requirements 14.4/14.7).
  final String checksum;

  const MigrationDataPackage({
    required this.storeBytes,
    required this.checksum,
  });

  /// Builds a package from [bytes], computing the integrity checksum.
  factory MigrationDataPackage.fromBytes(List<int> bytes) {
    final data = Uint8List.fromList(bytes);
    return MigrationDataPackage(
      storeBytes: data,
      checksum: sha256.convert(data).toString(),
    );
  }
}

/// The full export produced on the source machine: the verified data package
/// and the signed deactivation token (Requirement 14.1).
class MigrationExport {
  final DeactivationToken token;
  final MigrationDataPackage data;

  const MigrationExport({required this.token, required this.data});
}

/// Whether the source machine is still usable or now requires reactivation
/// (Requirements 14.3, 14.5).
enum MigrationSourceState {
  /// Within the 48-hour overlap window — the source stays usable.
  usable,

  /// The window has elapsed — the source is deactivated and must reactivate.
  requiresReactivation,
}

/// The outcome of a target-machine activation attempt.
sealed class TargetActivationOutcome {
  const TargetActivationOutcome();
}

/// Activation succeeded: verified data was imported and the target machine's
/// Local_License_File was written.
class TargetActivationSucceeded extends TargetActivationOutcome {
  final LicenseToken token;
  const TargetActivationSucceeded(this.token);
}

/// The deactivation token was invalid or its 48-hour window had elapsed
/// (Requirement 14.6). No data imported; target stays unactivated.
class TargetActivationRejected extends TargetActivationOutcome {
  final String code;
  final String reason;
  const TargetActivationRejected({required this.code, required this.reason});

  static const String codeInvalidToken = 'INVALID_DEACTIVATION_TOKEN';
  static const String codeExpiredWindow = 'OVERLAP_WINDOW_ELAPSED';
  static const String codeSecretUnavailable = 'APP_SECRET_UNAVAILABLE';
}

/// The exported data failed integrity verification (Requirement 14.7). The
/// import was aborted and the target's existing Local_Store left unchanged.
class TargetImportFailed extends TargetActivationOutcome {
  final String reason;
  const TargetImportFailed({required this.reason});
}

/// Moves an activated installation from one machine to another.
abstract class MigrationWizard {
  /// Exports the source Local_Store data + a signed deactivation token while
  /// keeping the source machine activated and usable (Requirement 14.1).
  Future<MigrationExport> exportForMigration();

  /// Pure check: the [token]'s overlap window is still open at [now]
  /// (`now - deactivatedAt <= 48h` and not before deactivation).
  bool isWithinOverlapWindow(DeactivationToken token, {DateTime? now});

  /// The source machine's state at [now] (Requirements 14.3, 14.5).
  MigrationSourceState sourceStateAt(DeactivationToken token, {DateTime? now});

  /// Verifies the exported data's integrity checksum (Requirements 14.4, 14.7).
  bool verifyDataIntegrity(MigrationDataPackage data);

  /// Activates the target machine from [export]: validates the token + window,
  /// verifies data integrity, imports the data, and writes the target license
  /// file. Never corrupts the target's existing store on failure (Property 30).
  Future<TargetActivationOutcome> activateOnTarget(
    MigrationExport export, {
    DateTime? now,
  });

  /// Auto-deactivates the source machine once the overlap window has elapsed,
  /// removing its Local_License_File so it requires reactivation
  /// (Requirement 14.5). Returns true when a deactivation was performed.
  Future<bool> finalizeSourceDeactivationIfElapsed(
    DeactivationToken token, {
    DateTime? now,
  });
}

/// Default [MigrationWizard] wiring the fingerprint collector, license file,
/// and application secret together with strict integrity and window checks.
class DefaultMigrationWizard implements MigrationWizard {
  static const String _logTag = 'MigrationWizard';

  /// File name of the offline Local_Store (mirrors `connection_native.dart`).
  static const String _storeFileName = 'dukanx_enterprise.sqlite';

  final FingerprintCollector _fingerprintCollector;
  final LocalLicenseFile _licenseFile;
  final LocalStoreEncryption _encryption;

  /// Resolves the absolute path to the Local_Store file. Injectable for tests;
  /// defaults to the documents-directory path the database connection uses.
  final Future<String> Function() _storePathResolver;

  final _uuidLikeRandom = DateTime.now();

  DefaultMigrationWizard({
    FingerprintCollector? fingerprintCollector,
    LocalLicenseFile? licenseFile,
    LocalStoreEncryption? encryption,
    Future<String> Function()? storePathResolver,
  }) : _fingerprintCollector =
           fingerprintCollector ?? DeviceFingerprintCollector(),
       _licenseFile = licenseFile ?? LocalLicenseFile(),
       _encryption = encryption ?? LocalStoreEncryption.instance,
       _storePathResolver = storePathResolver ?? _defaultStorePath;

  static Future<String> _defaultStorePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _storeFileName);
  }

  // --------------------------------------------------------------------------
  // Export (Requirement 14.1)
  // --------------------------------------------------------------------------

  @override
  Future<MigrationExport> exportForMigration() async {
    final appSecret = await _encryption.loadAppSecret();
    if (appSecret == null || appSecret.isEmpty) {
      throw StateError(
        'Cannot export migration: application secret is unavailable.',
      );
    }

    // Source identity + license payload (read under the source binding).
    final fingerprint = await _fingerprintCollector.collect();
    final fingerprintHash = _fingerprintCollector.fingerprintHash(fingerprint);

    final payload = await _licenseFile.read(
      fingerprintHash: fingerprintHash,
      appSecret: appSecret,
    );
    if (payload == null) {
      throw StateError(
        'Cannot export migration: this machine is not activated.',
      );
    }

    // Export the Local_Store bytes + integrity checksum.
    final data = await _exportStoreData();

    // Build + sign the deactivation token. `deactivatedAt = now` starts the
    // 48-hour overlap window; the source stays usable for its duration.
    final deactivatedAt = DateTime.now().toUtc();
    final base = DeactivationToken(
      migrationId: _newMigrationId(),
      tenantId: payload.token.tenantId ?? '',
      licenseTokenJwt: payload.token.raw,
      sourceFingerprintHash: fingerprintHash,
      deactivatedAt: deactivatedAt,
      signature: '',
    );
    final signature = MigrationTokenSigner.sign(
      canonicalPayload: base.canonicalPayload,
      appSecret: appSecret,
    );
    final token = DeactivationToken(
      migrationId: base.migrationId,
      tenantId: base.tenantId,
      licenseTokenJwt: base.licenseTokenJwt,
      sourceFingerprintHash: base.sourceFingerprintHash,
      deactivatedAt: base.deactivatedAt,
      signature: signature,
    );

    LoggerService.i(
      _logTag,
      'Migration exported; source stays usable within the 48h window.',
    );
    return MigrationExport(token: token, data: data);
  }

  Future<MigrationDataPackage> _exportStoreData() async {
    final path = await _storePathResolver();
    final file = File(path);
    final bytes = file.existsSync() ? await file.readAsBytes() : Uint8List(0);
    return MigrationDataPackage.fromBytes(bytes);
  }

  // --------------------------------------------------------------------------
  // Overlap window + source state (Requirements 14.2, 14.3, 14.5) — pure
  // --------------------------------------------------------------------------

  @override
  bool isWithinOverlapWindow(DeactivationToken token, {DateTime? now}) {
    final at = (now ?? DateTime.now()).toUtc();
    final start = token.deactivatedAt.toUtc();
    if (at.isBefore(start)) return false; // cannot precede deactivation
    return !at.isAfter(token.windowEndsAt.toUtc()); // inclusive 48h bound
  }

  @override
  MigrationSourceState sourceStateAt(DeactivationToken token, {DateTime? now}) {
    return isWithinOverlapWindow(token, now: now)
        ? MigrationSourceState.usable
        : MigrationSourceState.requiresReactivation;
  }

  // --------------------------------------------------------------------------
  // Integrity verification (Requirements 14.4, 14.7) — pure
  // --------------------------------------------------------------------------

  @override
  bool verifyDataIntegrity(MigrationDataPackage data) {
    final actual = sha256.convert(data.storeBytes).toString();
    return _equalsIgnoreCase(actual, data.checksum);
  }

  static bool _equalsIgnoreCase(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();

  // --------------------------------------------------------------------------
  // Target activation (Requirements 14.4, 14.6, 14.7)
  // --------------------------------------------------------------------------

  @override
  Future<TargetActivationOutcome> activateOnTarget(
    MigrationExport export, {
    DateTime? now,
  }) async {
    final at = (now ?? DateTime.now()).toUtc();

    final appSecret = await _encryption.loadAppSecret();
    if (appSecret == null || appSecret.isEmpty) {
      return const TargetActivationRejected(
        code: TargetActivationRejected.codeSecretUnavailable,
        reason: 'The application secret is unavailable on this machine.',
      );
    }

    // (1) Token authenticity (Requirement 14.6).
    if (!MigrationTokenSigner.verify(
      token: export.token,
      appSecret: appSecret,
    )) {
      LoggerService.i(_logTag, 'Target activation rejected: invalid token.');
      return const TargetActivationRejected(
        code: TargetActivationRejected.codeInvalidToken,
        reason: 'The deactivation token is invalid.',
      );
    }

    // (2) Overlap window still open (Requirement 14.2/14.6).
    if (!isWithinOverlapWindow(export.token, now: at)) {
      LoggerService.i(_logTag, 'Target activation rejected: window elapsed.');
      return const TargetActivationRejected(
        code: TargetActivationRejected.codeExpiredWindow,
        reason: 'The 48-hour migration window has elapsed.',
      );
    }

    // (3) Integrity-verify BEFORE touching the target store (Requirement 14.7).
    if (!verifyDataIntegrity(export.data)) {
      LoggerService.w(_logTag, 'Migration data failed integrity verification.');
      return const TargetImportFailed(
        reason: 'The migration data failed integrity verification.',
      );
    }

    // (4) Import the verified data without corrupting the existing store.
    try {
      await _importStoreData(export.data);
    } catch (e) {
      LoggerService.e(_logTag, 'Migration import failed; store preserved.', e);
      return const TargetImportFailed(
        reason: 'The migration data could not be imported.',
      );
    }

    // (5) Establish activation on the target: re-encrypt the transferred token
    //     under THIS machine's Fingerprint_Hash so it is usable offline here.
    try {
      final fingerprint = await _fingerprintCollector.collect();
      final fingerprintHash = _fingerprintCollector.fingerprintHash(
        fingerprint,
      );
      final token = LicenseToken.fromJwt(export.token.licenseTokenJwt);
      await _licenseFile.write(
        payload: LocalLicensePayload(
          token: token,
          machineFingerprint: fingerprint.toMap(),
          lastValidatedAt: at,
        ),
        fingerprintHash: fingerprintHash,
        appSecret: appSecret,
      );
      LoggerService.i(_logTag, 'Target machine activated from migration.');
      return TargetActivationSucceeded(token);
    } catch (e) {
      LoggerService.e(_logTag, 'Failed to write target license file.', e);
      try {
        await _licenseFile.delete();
      } catch (_) {
        // best-effort cleanup; do not mask the original failure.
      }
      return const TargetImportFailed(
        reason: 'Activation could not be completed on the target machine.',
      );
    }
  }

  /// Writes [data] into the target Local_Store atomically: the bytes are staged
  /// to a temp file and re-verified, the existing store is backed up, and only
  /// then is it replaced. On any failure the existing store is restored, so the
  /// live store is never left corrupted (Property 30).
  Future<void> _importStoreData(MigrationDataPackage data) async {
    final path = await _storePathResolver();
    final original = File(path);
    final tmp = File('$path.migration.tmp');
    final backup = File('$path.pre-migration.bak');

    // Stage + re-verify the staged bytes before replacing anything.
    await tmp.writeAsBytes(data.storeBytes, flush: true);
    final staged = sha256.convert(await tmp.readAsBytes()).toString();
    if (!_equalsIgnoreCase(staged, data.checksum)) {
      await _deleteQuietly(tmp);
      throw const FileSystemException('Staged migration data is corrupt.');
    }

    final hadOriginal = original.existsSync();
    if (hadOriginal) {
      await original.copy(backup.path);
    }

    try {
      await tmp.copy(path); // overwrite-safe on every platform
    } catch (e) {
      // Restore the original from backup so the live store is unchanged.
      if (hadOriginal && backup.existsSync()) {
        await backup.copy(path);
      }
      await _deleteQuietly(tmp);
      await _deleteQuietly(backup);
      rethrow;
    }

    await _deleteQuietly(tmp);
    await _deleteQuietly(backup);
  }

  // --------------------------------------------------------------------------
  // Source auto-deactivation (Requirement 14.5)
  // --------------------------------------------------------------------------

  @override
  Future<bool> finalizeSourceDeactivationIfElapsed(
    DeactivationToken token, {
    DateTime? now,
  }) async {
    if (isWithinOverlapWindow(token, now: now)) return false;
    await _licenseFile.delete();
    LoggerService.i(
      _logTag,
      'Overlap window elapsed; source deactivated and requires reactivation.',
    );
    return true;
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // ignore — cleanup is best-effort.
    }
  }

  /// A compact, collision-resistant id for one migration handoff. Avoids adding
  /// a dependency for a non-security id (the security comes from the HMAC).
  String _newMigrationId() {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    final salt = identityHashCode(_uuidLikeRandom) ^ micros;
    return 'mig_${micros.toRadixString(16)}_${salt.toRadixString(16)}';
  }
}
