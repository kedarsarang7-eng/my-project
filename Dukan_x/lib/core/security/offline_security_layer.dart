// ============================================================================
// OFFLINE_SECURITY_LAYER — cross-cutting offline security entry point
// ============================================================================
// Feature: offline-license-activation (Task 18.1)
//
// This is the single service-layer seam for the offline Security_Layer's
// cross-cutting controls that the Startup_Sequence and the rest of the offline
// stack consult:
//
//   * Runtime key derivation — exposed through [OfflineKeyDerivation] (the one
//     audited PBKDF2 primitive; keys are never in source — Req 17.1/17.2/17.3).
//   * Local_License_File integrity verification BEFORE use (Req 17.11/17.16):
//     on offline startup the file must decrypt, authenticate (AES-256-GCM tag),
//     and parse, otherwise its use is blocked and the failure reported.
//   * Log scrubbing — exposed through [LogScrubber] and wired into the Dart
//     logging chokepoints (Req 17.10).
//   * Local_Store tamper/swap detection (Req 17.12, task 18.2): on offline
//     startup the store is probed for authentication under the machine-derived
//     SQLCipher key; a store that does not authenticate (swapped from another
//     machine/tenant, or with modified bytes) drives the installation into a
//     read-only forensic mode via [StoreForensicGate] — reads stay permitted,
//     all writes are blocked, and the condition is reported.
//
// It composes the Fingerprint_Collector (to derive the binding hash), the
// runtime app-secret loader (`LocalStoreEncryption.loadAppSecret`, never
// hardcoded), and [LocalLicenseFile.verifyIntegrity]. It performs NO Flutter UI
// work and is injected through the existing service_locator (task 20.1 wires it
// into the Backend_Supervisor's `licenseDecryptValidate` startup step).
//
// Author: DukanX Engineering
// ============================================================================

import '../database/local_store_crypto.dart';
import '../licensing/local_license_file.dart';
import '../security/device/device_fingerprint.dart';
import '../services/logger_service.dart';
import 'store/store_forensic_gate.dart';
import 'store/store_tamper_detector.dart';

/// Cross-cutting offline Security_Layer controls (key derivation access,
/// license-file integrity verification, and log scrubbing).
class OfflineSecurityLayer {
  static const String _logTag = 'SecurityLayer';

  final FingerprintCollector _fingerprintCollector;
  final LocalLicenseFile _licenseFile;
  final LocalStoreEncryption _encryption;
  final StoreForensicGate _forensicGate;

  OfflineSecurityLayer({
    FingerprintCollector? fingerprintCollector,
    LocalLicenseFile? licenseFile,
    LocalStoreEncryption? encryption,
    StoreForensicGate? forensicGate,
  }) : _fingerprintCollector =
           fingerprintCollector ?? DeviceFingerprintCollector(),
       _licenseFile = licenseFile ?? LocalLicenseFile(),
       _encryption = encryption ?? LocalStoreEncryption.instance,
       _forensicGate = forensicGate ?? StoreForensicGate.instance;

  /// Verifies the integrity of the Local_License_File before use, as required
  /// on offline startup (Requirement 17.11).
  ///
  /// Loads the runtime application secret (never hardcoded) and the current
  /// Fingerprint_Hash, then delegates to [LocalLicenseFile.verifyIntegrity].
  /// When the application secret is unavailable the file cannot be authenticated,
  /// so this conservatively reports a failed verification rather than allowing
  /// use of an unverifiable file. NEVER logs secret/key material (Req 17.10).
  Future<LicenseFileIntegrityResult> verifyLicenseFileIntegrity() async {
    final appSecret = await _encryption.loadAppSecret();
    if (appSecret == null || appSecret.isEmpty) {
      LoggerService.w(
        _logTag,
        'Application secret unavailable; cannot verify Local_License_File '
        'integrity — use is blocked.',
      );
      return const LicenseFileIntegrityResult(LicenseFileIntegrity.failed);
    }

    final fingerprint = await _fingerprintCollector.collect();
    final fingerprintHash = _fingerprintCollector.fingerprintHash(fingerprint);

    final result = await _licenseFile.verifyIntegrity(
      fingerprintHash: fingerprintHash,
      appSecret: appSecret,
    );

    switch (result.status) {
      case LicenseFileIntegrity.verified:
        LoggerService.i(_logTag, 'Local_License_File integrity verified.');
      case LicenseFileIntegrity.failed:
        // Req 17.16: prevent use and report the integrity-verification failure.
        LoggerService.e(
          _logTag,
          'Local_License_File integrity verification FAILED; use is blocked.',
        );
      case LicenseFileIntegrity.absent:
        LoggerService.i(
          _logTag,
          'No Local_License_File present; machine is not activated.',
        );
    }
    return result;
  }

  // --------------------------------------------------------------------------
  // Local_Store tamper / swap detection → read-only forensic mode (Req 17.12)
  // --------------------------------------------------------------------------

  /// Detects whether the Local_Store has been swapped or tampered with and, if
  /// so, drives the installation into read-only forensic mode (Requirement
  /// 17.12).
  ///
  /// The store is encrypted with SQLCipher under a key the Security_Layer
  /// derives from the machine binding (Fingerprint_Hash + tenant id + app
  /// secret). A store copied from a DIFFERENT machine/tenant, or whose bytes
  /// were modified, fails authentication under that key. This routine runs an
  /// injected [StoreTamperDetector] (which performs the SQLCipher
  /// authentication probe) and, on a tampered result, arms [StoreForensicGate]
  /// so every write chokepoint blocks while reads remain permitted, and reports
  /// the condition. Reads are NEVER blocked — the gate gates writes only.
  ///
  /// This is intended to run during the offline Startup_Sequence (wired by task
  /// 20.1), AFTER the SQLCipher key has been configured on
  /// [LocalStoreEncryption]. When no key is configured (legacy unencrypted
  /// install, or before activation) the detector reports `notApplicable` and
  /// the gate is left untouched, so Cloud_Subscription_Mode and existing
  /// installs are unaffected.
  ///
  /// NEVER logs secret/key material (Req 17.10): only the classification and a
  /// fixed reason string are emitted/stored.
  Future<StoreTamperResult> detectStoreTamper(
    StoreTamperDetector detector,
  ) async {
    final result = await detector.detect();

    switch (result.status) {
      case StoreTamperStatus.tampered:
        // Req 17.12: permit reads, block ALL writes, report the condition.
        LoggerService.e(
          _logTag,
          'Local_Store detected as swapped/tampered; entering read-only '
          'forensic mode (reads permitted, all writes blocked).',
        );
        _forensicGate.markTampered(StoreForensicGate.writeBlockedReason);
      case StoreTamperStatus.intact:
        LoggerService.i(
          _logTag,
          'Local_Store authenticated under the machine-derived key; binding '
          'intact.',
        );
      case StoreTamperStatus.notApplicable:
        LoggerService.i(
          _logTag,
          'Local_Store tamper check not applicable (no encrypted store to '
          'authenticate).',
        );
    }

    return result;
  }
}
