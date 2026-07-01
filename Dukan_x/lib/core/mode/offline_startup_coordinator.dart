// ============================================================================
// OFFLINE STARTUP COORDINATOR — drives the offline Startup_Sequence end to end
// ============================================================================
// Feature: offline-license-activation (Task 20.1)
//
// This coordinator is the single entry point the app bootstrap calls to run the
// Offline_Lifetime_Mode Startup_Sequence (Req 3.3) using the services wired
// through the existing `service_locator` (`sl`). It composes — it does NOT
// rebuild — the already-implemented offline components:
//
//   * Mode_Manager (task 1.2) decides whether the app is in Offline_Lifetime_Mode.
//   * Backend_Supervisor (task 2.2) owns the ordered boot:
//       local license check → decrypt/validate Local_License_File → spawn
//       Local_Backend → health check → connect repository → restore session.
//   * Offline_Security_Layer (task 18.1/18.2) performs the license-file
//       integrity verification and the Local_Store tamper/swap detection that
//       the "decrypt/validate" + "store tamper detection" steps require.
//
// CRITICAL — CLOUD MODE & UI UNCHANGED (Req 1.7, 2.1, 2.3, 11.1, 11.5, 11.7):
//   * In Cloud_Subscription_Mode (the default) [bootIfOffline] returns early
//     WITHOUT constructing or starting any offline component — the
//     Backend_Supervisor is resolved lazily and only when offline, so the cloud
//     startup path and `ApiClient` behavior are byte-for-byte unchanged.
//   * This file imports no Flutter widget code and is never referenced by the
//     widget tree; the offline switch stays entirely at the service layer.
//
// Author: DukanX Engineering
// ============================================================================

import '../licensing/local_license_file.dart';
import '../security/offline_security_layer.dart';
import '../security/store/local_store_auth_probe.dart';
import '../security/store/store_tamper_detector.dart';
import '../services/logger_service.dart';
import 'backend_supervisor.dart';
import 'mode_manager.dart';

/// Coordinates the offline Startup_Sequence using the wired offline services.
///
/// Service layer only — injected through the existing `service_locator` and
/// invoked from the app bootstrap. The Backend_Supervisor is provided through a
/// lazy [_supervisorProvider] so it is constructed only when the app is in
/// Offline_Lifetime_Mode, keeping Cloud_Subscription_Mode startup untouched.
class OfflineStartupCoordinator {
  static const String _logTag = 'OfflineStartup';

  final ModeManager _modeManager;
  final BackendSupervisor Function() _supervisorProvider;

  OfflineStartupCoordinator({
    required ModeManager modeManager,
    required BackendSupervisor Function() supervisorProvider,
  }) : _modeManager = modeManager,
       _supervisorProvider = supervisorProvider;

  /// Resolves the active Operating_Mode and, ONLY when it is
  /// Offline_Lifetime_Mode, runs the Backend_Supervisor Startup_Sequence
  /// (Req 3.3). Returns `true` when the offline sequence was driven, `false`
  /// when the app is in Cloud_Subscription_Mode and nothing offline was touched.
  ///
  /// Resolving the active mode also persists the safe default the first time the
  /// app runs (Req 1.9). In Cloud_Subscription_Mode the Backend_Supervisor is
  /// never resolved, so no offline process is spawned and cloud startup is
  /// unchanged (Req 2.1, 2.3).
  Future<bool> bootIfOffline() async {
    final mode = await _modeManager.resolveActiveMode();
    if (mode != OperatingMode.offlineLifetime) {
      LoggerService.i(
        _logTag,
        'Cloud_Subscription_Mode active; offline startup skipped '
        '(cloud behavior unchanged).',
      );
      return false;
    }

    LoggerService.i(
      _logTag,
      'Offline_Lifetime_Mode active; running Backend_Supervisor startup '
      'sequence.',
    );
    // Constructed lazily here so it never exists in Cloud_Subscription_Mode.
    await _supervisorProvider().runStartupSequence();
    return true;
  }

  // --------------------------------------------------------------------------
  // Startup-sequence seam builders (consumed by the service_locator wiring)
  // --------------------------------------------------------------------------

  /// Builds the first Startup_Sequence step (Req 3.3): a local license check
  /// that confirms a Local_License_File is present before the boot continues.
  static LocalLicenseCheck buildLocalLicenseCheck([LocalLicenseFile? file]) {
    final licenseFile = file ?? LocalLicenseFile();
    return () => licenseFile.exists();
  }

  /// Builds the "decrypt/validate Local_License_File + store tamper detection"
  /// Startup_Sequence step (Req 3.3) on top of the [securityLayer].
  ///
  /// The step:
  ///   1. Verifies Local_License_File integrity (Req 17.11/17.16). If the file
  ///      is absent or fails authenticated decryption, the boot stops (returns
  ///      `false`) so an unverifiable license is never used.
  ///   2. Runs Local_Store tamper/swap detection (Req 17.12). A swapped or
  ///      tampered store arms read-only forensic mode (reads stay permitted,
  ///      writes are blocked) but does NOT abort startup — the user can still
  ///      read their data for forensic inspection — so this returns `true`.
  static LicenseDecryptValidate buildLicenseDecryptValidate(
    OfflineSecurityLayer securityLayer, {
    StoreTamperDetector? tamperDetector,
  }) {
    final detector =
        tamperDetector ??
        StoreTamperDetector(probeRunner: defaultLocalStoreAuthProbe());
    return () async {
      final integrity = await securityLayer.verifyLicenseFileIntegrity();
      if (!integrity.isUsable) {
        LoggerService.e(
          _logTag,
          'Local_License_File is not usable (absent or failed integrity '
          'verification); offline startup blocked.',
        );
        return false;
      }
      // Arms read-only forensic mode on a swapped/tampered store; reads remain
      // permitted, so the boot continues regardless of the outcome.
      await securityLayer.detectStoreTamper(detector);
      return true;
    };
  }
}
