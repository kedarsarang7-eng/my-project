// ============================================================================
// ACTIVATION_SERVICE — one-time machine-bound license activation
// ============================================================================
// Feature: offline-license-activation (Task 4.3)
//
// Performs the one-time online activation described by Requirements 5.3–5.12:
//
//   1. Collect the Machine_Fingerprint and compute its Fingerprint_Hash
//      (reusing Fingerprint_Collector — tasks 4.1 / 4.2).
//   2. Verify an internet connection exists (Req 5.4). If not →
//      ActivationNeedsInternet, NO file created, machine stays unactivated.
//   3. POST key + fingerprint to the License_Server, waiting at most 30s
//      (Req 5.3) via ActivationTransport.
//   4. On success, write the License_Token to the AES-256-GCM Local_License_File
//      in the OS-specific secure location (Req 5.6, 5.7, 20.4).
//   5. On a definitive rejection → ActivationFailed with the reason (Req 5.11);
//      on network failure / timeout / 5xx → ActivationConnectionError (Req 5.12).
//
// ATOMICITY (Property 7, Req 5.4/5.11/5.12/17.13):
//   The Local_License_File is created ONLY on the success path, AFTER a valid,
//   token-carrying response has been received. Every failure path returns
//   before any write, so a failed activation NEVER leaves a partial file and
//   the machine stays unactivated. If the write itself fails, any partial
//   temp file is cleaned up and a connection-error outcome is returned.
//
// REUSE, DON'T REBUILD:
//   * Fingerprint collection/hashing → DeviceFingerprintCollector (4.1/4.2).
//   * Network transport → ActivationTransport (pinned HTTP client, ApiConfig,
//     SessionManager).
//   * App-secret loading → LocalStoreEncryption.loadAppSecret() (never hardcoded).
//   * Crypto → LocalLicenseFile (PBKDF2 + AES-256-GCM, mirrors local_store_crypto).
//
// SERVICE LAYER ONLY: no Flutter widget imports; injected via the service
// locator. Returns a sealed ActivationOutcome the UI-agnostic caller maps.
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../database/local_store_crypto.dart';
import '../../security/device/device_fingerprint.dart';
import '../../services/logger_service.dart';
import '../license_token.dart';
import '../local_license_file.dart';
import 'activation_transport.dart';

/// The result of an [ActivationService.activate] call (design "Activation_Service").
sealed class ActivationOutcome {
  const ActivationOutcome();
}

/// Activation succeeded: the Local_License_File was written. Carries the token.
class ActivationSucceeded extends ActivationOutcome {
  final LicenseToken token;
  const ActivationSucceeded(this.token);
}

/// The License_Server definitively rejected activation: invalid/expired/revoked
/// key, denylisted key, or device-allowance exhausted (Req 5.11). No file
/// created; machine stays unactivated.
class ActivationFailed extends ActivationOutcome {
  /// Machine-readable reason code from the server (e.g. `KEY_DENYLISTED`).
  final String code;

  /// Human-readable reason for display.
  final String reason;

  const ActivationFailed({required this.code, required this.reason});
}

/// No internet connection was available during activation (Req 5.4). No file
/// created; machine stays unactivated.
class ActivationNeedsInternet extends ActivationOutcome {
  const ActivationNeedsInternet();
}

/// The request failed or did not return within 30 seconds (Req 5.12), or the
/// server returned a non-definitive (5xx) error. No file created; machine stays
/// unactivated.
class ActivationConnectionError extends ActivationOutcome {
  /// One of [ActivationTransportUnavailable]'s reason constants.
  final String reason;
  const ActivationConnectionError({required this.reason});
}

/// Performs one-time online license activation and stores the Local_License_File
/// (Req 5.3–5.12).
abstract class ActivationService {
  Future<ActivationOutcome> activate(String licenseKey);
}

/// Default [ActivationService] wiring the fingerprint collector, transport, and
/// encrypted file store together with strict failure atomicity.
class DefaultActivationService implements ActivationService {
  static const String _logTag = 'ActivationService';

  final FingerprintCollector _fingerprintCollector;
  final ActivationTransport _transport;
  final LocalLicenseFile _licenseFile;
  final LocalStoreEncryption _encryption;
  final Connectivity _connectivity;

  DefaultActivationService({
    FingerprintCollector? fingerprintCollector,
    ActivationTransport? transport,
    LocalLicenseFile? licenseFile,
    LocalStoreEncryption? encryption,
    Connectivity? connectivity,
  }) : _fingerprintCollector =
           fingerprintCollector ?? DeviceFingerprintCollector(),
       _transport = transport ?? HttpActivationTransport(),
       _licenseFile = licenseFile ?? LocalLicenseFile(),
       _encryption = encryption ?? LocalStoreEncryption.instance,
       _connectivity = connectivity ?? Connectivity();

  @override
  Future<ActivationOutcome> activate(String licenseKey) async {
    final key = licenseKey.trim();
    if (key.isEmpty) {
      return const ActivationFailed(
        code: 'MISSING_LICENSE_KEY',
        reason: 'A license key is required to activate.',
      );
    }

    // 1. Collect fingerprint + compute Fingerprint_Hash (tasks 4.1 / 4.2).
    final fingerprint = await _fingerprintCollector.collect();
    final fingerprintHash = _fingerprintCollector.fingerprintHash(fingerprint);

    // 2. No internet → needs-internet, create no file (Req 5.4).
    if (!await _hasInternet()) {
      LoggerService.i(_logTag, 'Activation aborted: no internet connection.');
      return const ActivationNeedsInternet();
    }

    // 3. One-time online call (≤30s), classified by the transport (Req 5.3).
    final result = await _transport.activateOffline(
      licenseKey: key,
      fingerprint: fingerprint.toMap().map(
        (k, v) => MapEntry(k, v?.toString() ?? ''),
      ),
    );

    switch (result) {
      // 5.11 — definitive server rejection. NO file written.
      case ActivationTransportRejected(:final code, :final message):
        LoggerService.i(_logTag, 'Activation rejected by server ($code).');
        return ActivationFailed(code: code, reason: message);

      // 5.12 — no definitive answer (network/timeout/5xx). NO file written.
      case ActivationTransportUnavailable(:final reason):
        LoggerService.i(_logTag, 'Activation unavailable ($reason).');
        return ActivationConnectionError(reason: reason);

      // 5.6 — success: write the encrypted Local_License_File, THEN succeed.
      case ActivationTransportSuccess(:final data):
        return _onSuccess(
          data: data,
          fingerprint: fingerprint,
          fingerprintHash: fingerprintHash,
        );
    }
  }

  /// Success path: derive the key, write the AES-256-GCM Local_License_File, and
  /// return [ActivationSucceeded]. A write/secret failure here is the only place
  /// a partial file could appear, so it is cleaned up and reported as a
  /// connection error rather than leaving the machine half-activated (Property 7).
  Future<ActivationOutcome> _onSuccess({
    required Map<String, dynamic> data,
    required MachineFingerprint fingerprint,
    required String fingerprintHash,
  }) async {
    final LicenseToken token;
    try {
      token = LicenseToken.fromJwt(data['licenseToken'] as String);
    } on FormatException catch (e) {
      LoggerService.w(_logTag, 'Activation token was malformed: ${e.message}');
      return const ActivationConnectionError(
        reason: ActivationTransportUnavailable.reasonServerError,
      );
    }

    // The app secret is loaded at runtime (never hardcoded). Without it we
    // cannot encrypt the file, so we must NOT write anything (stay unactivated).
    final appSecret = await _encryption.loadAppSecret();
    if (appSecret == null || appSecret.isEmpty) {
      LoggerService.e(
        _logTag,
        'Activation cannot complete: application secret unavailable; '
        'no Local_License_File created.',
      );
      return const ActivationConnectionError(
        reason: ActivationTransportUnavailable.reasonServerError,
      );
    }

    final payload = LocalLicensePayload(
      token: token,
      machineFingerprint: fingerprint.toMap(),
      lastValidatedAt: DateTime.now().toUtc(),
    );

    try {
      await _licenseFile.write(
        payload: payload,
        fingerprintHash: fingerprintHash,
        appSecret: appSecret,
      );
    } catch (e) {
      // Best-effort cleanup so a failed write leaves no partial file.
      LoggerService.e(_logTag, 'Failed to write Local_License_File', e);
      try {
        await _licenseFile.delete();
      } catch (_) {
        // ignore — nothing more we can do; do not mask the original failure.
      }
      return const ActivationConnectionError(
        reason: ActivationTransportUnavailable.reasonServerError,
      );
    }

    LoggerService.i(
      _logTag,
      'Activation succeeded; Local_License_File stored.',
    );
    return ActivationSucceeded(token);
  }

  /// True when at least one transport reports connectivity (Req 5.4). Uses the
  /// same connectivity_plus pattern the rest of the app uses.
  Future<bool> _hasInternet() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      // If connectivity cannot be determined, let the bounded network call be
      // the source of truth rather than blocking activation outright.
      LoggerService.w(_logTag, 'Connectivity check failed: $e');
      return true;
    }
  }
}
