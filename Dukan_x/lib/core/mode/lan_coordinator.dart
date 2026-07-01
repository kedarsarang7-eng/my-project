// ============================================================================
// LAN_COORDINATOR — primary/secondary multi-device coordination over the LAN
// ============================================================================
// Feature: offline-license-activation (Task 16.1)
//
// The LAN_Coordinator lets several terminals on the same local network bill
// against ONE machine's authoritative Local_Store without any internet
// dependency, honouring Requirements 15.1–15.6:
//
//   * PRIMARY DESIGNATION (15.1): exactly one Primary_Device holds the
//     authoritative Local_Store. The role is the persisted LAN role already
//     owned by `LocalConfig` (LanRole.primary / .secondary / .none) — this
//     coordinator reads it, it does not invent a new role store.
//   * AUTHENTICATED CONNECT WITHIN 10s (15.2): a Secondary_Device connects to
//     the Primary_Device's packaged backend over the LAN using the primary's
//     IP/host and an AUTHENTICATED session (the existing offline auth/JWT
//     bearer token, reused via the session-token provider). The attempt
//     completes or is abandoned within a 10-second window.
//   * OFFLINE ONLY (15.3): every probe targets the primary's LAN address on the
//     local backend port — never the AWS host — so coordination works with no
//     internet access.
//   * FAILURE REPORTING (15.4): when the primary is unreachable the secondary
//     reports a connection failure to the service layer REGARDLESS of the
//     previously reported status (a previously-"connected" device still flips
//     to a failure when a fresh probe cannot reach the primary).
//   * ALLOWANCE CAP (15.5): the count of concurrently connected
//     Secondary_Devices PLUS the Primary_Device never exceeds the license
//     device allowance (the unchanged `LicenseKeyPayload.maxDevices` — 1 by
//     default, up to 3). Connections beyond the cap are rejected with a clear
//     reason.
//   * SECONDARY WRITE BLOCK (15.6): while a Secondary_Device cannot reach the
//     Primary_Device it is prevented from creating or modifying records in the
//     primary's Local_Store (reads may continue per the design).
//
// REUSE, DON'T REBUILD:
//   * LAN role + primary host → `LocalConfig` (`LanRole`, `getLanPrimaryHost`).
//   * Local backend port → `kLoopbackPort` from `backend_supervisor.dart`.
//   * Device allowance → the unchanged `LicenseKeyPayload.maxDevices` carried by
//     the `LicenseToken`, read from the existing AES-256-GCM Local_License_File
//     (same FingerprintCollector + LocalLicenseFile + LocalStoreEncryption seam
//     the Activation_Service / Migration_Wizard use).
//   * Authenticated session → the existing offline auth/JWT bearer token via the
//     registered `SessionManager` (the same provider the Activation_Transport
//     reuses) — no new auth scheme is invented.
//
// SERVICE LAYER ONLY: no Flutter widget imports; injected through the existing
// `service_locator` (`sl`) and wired by task 20.1. The pure admission/cap logic
// (`LanDeviceRegistry`, `LanDeviceRegistry.wouldExceedAllowance`) is the surface
// the Property 32 test (task 16.2) drives with generated inputs.
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../database/local_store_crypto.dart';
import '../licensing/local_license_file.dart';
import '../security/device/device_fingerprint.dart';
import '../services/logger_service.dart';
import 'backend_supervisor.dart' show kLoopbackPort;
import 'local_config.dart';

// ============================================================================
// Value types
// ============================================================================

/// Outcome of a Secondary_Device's attempt to connect to the Primary_Device
/// (Requirements 15.2, 15.4).
enum LanConnectionStatus {
  /// The primary was reachable over the LAN and an authenticated session was
  /// presented within the connect window (Requirement 15.2).
  connected,

  /// The primary could not be reached within the 10-second window
  /// (Requirement 15.4). Secondary writes are blocked while this holds
  /// (Requirement 15.6).
  unreachable,

  /// No authenticated session was available, so an authenticated LAN connection
  /// could not be established (Requirement 15.2).
  unauthenticated,

  /// No primary host is configured for this Secondary_Device, so there is no
  /// target to connect to.
  noPrimaryConfigured,

  /// Connect was requested on a device that is not a Secondary_Device.
  notSecondary,
}

/// The result of a Secondary_Device connection attempt.
class LanConnectionResult {
  /// The classified connection status.
  final LanConnectionStatus status;

  /// The primary host that was targeted, when known.
  final String? primaryHost;

  /// A short, human-readable reason for display/logging (never a secret).
  final String reason;

  const LanConnectionResult({
    required this.status,
    required this.reason,
    this.primaryHost,
  });

  /// True only when an authenticated LAN session to the primary is established.
  bool get isConnected => status == LanConnectionStatus.connected;

  @override
  String toString() =>
      'LanConnectionResult(status: $status, host: ${primaryHost ?? '-'}, '
      'reason: $reason)';
}

/// The result of admitting (or rejecting) a Secondary_Device on the
/// Primary_Device against the license device allowance (Requirement 15.5).
class LanAdmission {
  /// Machine-readable code: [codeAdmitted] or [codeAllowanceExceeded].
  final String code;

  /// Human-readable reason (e.g. why a connection was rejected).
  final String reason;

  /// Total connected devices AFTER this decision — the Primary_Device plus the
  /// concurrently connected Secondary_Devices.
  final int connectedDeviceCount;

  /// The license device allowance the decision was evaluated against.
  final int maxDevices;

  const LanAdmission({
    required this.code,
    required this.reason,
    required this.connectedDeviceCount,
    required this.maxDevices,
  });

  /// Whether the device was admitted into the deployment.
  bool get admitted => code == codeAdmitted;

  /// Code: the device was admitted within the allowance.
  static const String codeAdmitted = 'ADMITTED';

  /// Code: admitting the device would exceed the license device allowance.
  static const String codeAllowanceExceeded = 'DEVICE_ALLOWANCE_EXCEEDED';

  @override
  String toString() =>
      'LanAdmission($code, $connectedDeviceCount/$maxDevices devices)';
}

// ============================================================================
// Primary-side device registry (pure cap logic — Property 32 surface)
// ============================================================================

/// Tracks the Secondary_Devices currently connected to a Primary_Device and
/// enforces the license device-allowance cap (Requirement 15.5).
///
/// The registry is pure in-memory state with NO I/O, so the allowance-cap
/// property (Property 32, task 16.2) can drive it directly with generated
/// connect/disconnect sequences. The Primary_Device itself always counts as one
/// device, so the deployment size is `1 + connectedSecondaries`.
class LanDeviceRegistry {
  /// The license device allowance (the unchanged `LicenseKeyPayload.maxDevices`).
  /// Never below 1, because a deployment always contains at least the primary.
  final int maxDevices;

  final Set<String> _secondaries = <String>{};

  LanDeviceRegistry({required int maxDevices})
    : maxDevices = maxDevices < 1 ? 1 : maxDevices;

  /// The number of currently connected Secondary_Devices.
  int get connectedSecondaryCount => _secondaries.length;

  /// The total connected devices: the Primary_Device (1) plus the connected
  /// Secondary_Devices.
  int get connectedDeviceCount => 1 + _secondaries.length;

  /// The connected Secondary_Device identifiers (unmodifiable snapshot).
  Set<String> get connectedSecondaries => Set.unmodifiable(_secondaries);

  /// Whether admitting ONE MORE NEW Secondary_Device on top of
  /// [currentSecondaryCount] already-connected secondaries would push the
  /// deployment ([currentSecondaryCount] + 1 new + 1 primary) beyond
  /// [maxDevices]. Pure and total over its integer inputs.
  static bool wouldExceedAllowance({
    required int currentSecondaryCount,
    required int maxDevices,
  }) {
    final cap = maxDevices < 1 ? 1 : maxDevices;
    // After admission: (currentSecondaryCount + 1) secondaries + 1 primary.
    final totalAfter = currentSecondaryCount + 1 + 1;
    return totalAfter > cap;
  }

  /// Admits [deviceId] if the allowance permits, otherwise rejects it
  /// (Requirement 15.5). Re-admitting an already-connected device is idempotent
  /// (it does not consume an extra slot) so a reconnecting secondary is never
  /// spuriously rejected.
  LanAdmission admit(String deviceId) {
    final id = deviceId.trim();
    if (id.isEmpty) {
      return LanAdmission(
        code: LanAdmission.codeAllowanceExceeded,
        reason: 'A device identifier is required to join the deployment.',
        connectedDeviceCount: connectedDeviceCount,
        maxDevices: maxDevices,
      );
    }

    // Idempotent: an already-connected device keeps its slot (Requirement 15.5
    // counts CONCURRENTLY connected devices, not cumulative connects).
    if (_secondaries.contains(id)) {
      return LanAdmission(
        code: LanAdmission.codeAdmitted,
        reason: 'Device already connected.',
        connectedDeviceCount: connectedDeviceCount,
        maxDevices: maxDevices,
      );
    }

    if (wouldExceedAllowance(
      currentSecondaryCount: _secondaries.length,
      maxDevices: maxDevices,
    )) {
      return LanAdmission(
        code: LanAdmission.codeAllowanceExceeded,
        reason:
            'The license device allowance of $maxDevices device(s) is fully '
            'used; this connection was rejected.',
        connectedDeviceCount: connectedDeviceCount,
        maxDevices: maxDevices,
      );
    }

    _secondaries.add(id);
    return LanAdmission(
      code: LanAdmission.codeAdmitted,
      reason: 'Device connected.',
      connectedDeviceCount: connectedDeviceCount,
      maxDevices: maxDevices,
    );
  }

  /// Releases [deviceId] from the deployment (a secondary disconnected),
  /// freeing its slot for another device.
  void release(String deviceId) => _secondaries.remove(deviceId.trim());

  /// Releases every connected Secondary_Device (e.g. on shutdown).
  void releaseAll() => _secondaries.clear();
}

// ============================================================================
// Secondary-side transport seam (authenticated LAN reachability probe)
// ============================================================================

/// Probes the Primary_Device's packaged backend over the LAN. Injectable so the
/// connect logic can be tested without a real network (task 16.2).
abstract class LanPrimaryTransport {
  /// Returns `true` iff the primary's backend at [primaryBaseUri] responds
  /// successfully to an authenticated probe carrying [authToken] within
  /// [timeout]. Must NEVER throw for ordinary network/timeout conditions —
  /// those resolve to `false` (an unreachable primary, Requirement 15.4).
  Future<bool> probe(
    Uri primaryBaseUri, {
    required String authToken,
    required Duration timeout,
  });
}

/// Default HTTP [LanPrimaryTransport] that probes `GET <primary>/health` over
/// the LAN with the authenticated-session bearer token attached. Any non-200
/// status, malformed body, timeout, or transport error is treated as
/// unreachable. Uses a plain (non-pinned) HTTP client because the target is a
/// LAN peer on the local backend port, not the TLS-pinned AWS host
/// (Requirement 15.3 — offline/local only).
class HttpLanPrimaryTransport implements LanPrimaryTransport {
  static const String _logTag = 'LanCoordinator';
  static const String _healthPath = '/health';

  final http.Client _client;

  HttpLanPrimaryTransport({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<bool> probe(
    Uri primaryBaseUri, {
    required String authToken,
    required Duration timeout,
  }) async {
    final uri = primaryBaseUri.replace(path: _healthPath);
    try {
      final resp = await _client
          .get(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              // Present the authenticated session (Requirement 15.2). The
              // primary's auth middleware verifies the reused offline JWT.
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(timeout);
      return resp.statusCode == 200;
    } on TimeoutException {
      LoggerService.v(_logTag, 'Primary probe timed out (LAN unreachable).');
      return false;
    } on SocketException {
      LoggerService.v(_logTag, 'Primary probe connection failed.');
      return false;
    } on http.ClientException {
      LoggerService.v(_logTag, 'Primary probe client error.');
      return false;
    } on HttpException {
      LoggerService.v(_logTag, 'Primary probe HTTP error.');
      return false;
    }
  }
}

// ============================================================================
// Coordinator contract + default implementation
// ============================================================================

/// Coordinates primary/secondary LAN operation and enforces the license device
/// allowance (Requirements 15.1–15.6). Service layer only.
abstract class LanCoordinator {
  /// The 10-second window within which a Secondary_Device connection attempt
  /// must complete or be abandoned (Requirement 15.2).
  static const Duration connectTimeout = Duration(seconds: 10);

  /// The persisted LAN role of this machine (Requirement 15.1).
  Future<LanRole> currentRole();

  /// PRIMARY: admits or rejects a Secondary_Device [deviceId] against the
  /// license device allowance (Requirement 15.5). The allowance is read from
  /// the activated License_Token's `maxDevices`.
  Future<LanAdmission> admitSecondary(String deviceId);

  /// PRIMARY: releases a previously-admitted Secondary_Device, freeing its slot.
  void releaseSecondary(String deviceId);

  /// PRIMARY: the current total connected devices (primary + secondaries).
  int get connectedDeviceCount;

  /// SECONDARY: attempts an authenticated connection to the Primary_Device over
  /// the LAN within [LanCoordinator.connectTimeout] (Requirements 15.2, 15.3).
  /// Always reports the fresh result, even if a previous attempt succeeded
  /// (Requirement 15.4).
  Future<LanConnectionResult> connectToPrimary();

  /// SECONDARY: whether this device may create or modify records in the
  /// primary's Local_Store right now (Requirement 15.6). False whenever the
  /// primary is not currently reachable. A Primary_Device (or a standalone,
  /// non-LAN machine) may always write.
  bool get canWriteToPrimaryStore;

  /// Emits the latest [LanConnectionResult] each time a Secondary_Device probes
  /// the primary, so the service layer can react to connect/disconnect
  /// transitions (Requirement 15.4).
  Stream<LanConnectionResult> get connectionStatus;
}

/// Resolves the license device allowance (the unchanged
/// `LicenseKeyPayload.maxDevices`). Returns 1 — the single-device default
/// (Requirement 5.8) — when the machine is not activated or the allowance
/// cannot be read, so the deployment never over-admits on missing data.
typedef DeviceAllowanceResolver = Future<int> Function();

/// Provides the authenticated-session bearer token for the LAN connection
/// (Requirement 15.2). The default returns `null`; the `service_locator`
/// wiring (task 20.1) supplies a provider that reads the existing offline
/// auth/JWT session (e.g. the registered `SessionManager` access token) — the
/// same session reused everywhere else, so no new auth scheme is invented.
typedef LanAuthTokenProvider = Future<String?> Function();

/// Default [LanCoordinator]. Reads the LAN role + primary host from
/// [LocalConfig], the device allowance from the activated License_Token, and
/// the authenticated-session token from the registered [SessionManager].
class DefaultLanCoordinator implements LanCoordinator {
  static const String _logTag = 'LanCoordinator';

  final LocalConfig _localConfig;
  final LanPrimaryTransport _transport;
  final DeviceAllowanceResolver _allowanceResolver;
  final LanAuthTokenProvider _authTokenProvider;
  final Duration _connectTimeout;
  final int _primaryPort;

  final StreamController<LanConnectionResult> _statusController =
      StreamController<LanConnectionResult>.broadcast();

  /// Lazily built once the allowance is known (primary role only).
  LanDeviceRegistry? _registry;

  /// The most recent connection result observed by this (secondary) device.
  /// Seeds the write gate (Requirement 15.6); null until the first attempt.
  LanConnectionResult? _lastConnection;

  DefaultLanCoordinator({
    LocalConfig? localConfig,
    LanPrimaryTransport? transport,
    DeviceAllowanceResolver? allowanceResolver,
    LanAuthTokenProvider? authTokenProvider,
    Duration connectTimeout = LanCoordinator.connectTimeout,
    int primaryPort = kLoopbackPort,
  }) : _localConfig = localConfig ?? LocalConfig(),
       _transport = transport ?? HttpLanPrimaryTransport(),
       _allowanceResolver = allowanceResolver ?? _defaultAllowanceResolver,
       _authTokenProvider = authTokenProvider ?? _defaultAuthToken,
       _connectTimeout = connectTimeout,
       _primaryPort = primaryPort;
  @override
  Future<LanRole> currentRole() => _localConfig.getLanRole();

  @override
  Stream<LanConnectionResult> get connectionStatus => _statusController.stream;

  // --------------------------------------------------------------------------
  // Primary side — allowance cap (Requirement 15.5)
  // --------------------------------------------------------------------------

  @override
  Future<LanAdmission> admitSecondary(String deviceId) async {
    final registry = await _ensureRegistry();
    final admission = registry.admit(deviceId);
    if (admission.admitted) {
      LoggerService.i(
        _logTag,
        'Secondary admitted (${admission.connectedDeviceCount}/'
        '${admission.maxDevices} devices).',
      );
    } else {
      LoggerService.w(
        _logTag,
        'Secondary rejected: allowance ${admission.maxDevices} fully used.',
      );
    }
    return admission;
  }

  @override
  void releaseSecondary(String deviceId) => _registry?.release(deviceId);

  @override
  int get connectedDeviceCount => _registry?.connectedDeviceCount ?? 1;

  /// Builds the registry on first use with the resolved license allowance, or
  /// refreshes its allowance if the license changed. Connected devices are
  /// preserved across a refresh that does not lower the cap below them.
  Future<LanDeviceRegistry> _ensureRegistry() async {
    final allowance = await _allowanceResolver();
    final existing = _registry;
    if (existing == null || existing.maxDevices != allowance) {
      final refreshed = LanDeviceRegistry(maxDevices: allowance);
      // Carry over still-fitting connections so an allowance refresh does not
      // silently drop devices that remain within the (possibly new) cap.
      if (existing != null) {
        for (final id in existing.connectedSecondaries) {
          refreshed.admit(id);
        }
      }
      _registry = refreshed;
    }
    return _registry!;
  }

  // --------------------------------------------------------------------------
  // Secondary side — authenticated connect within 10s (Req 15.2/15.3/15.4)
  // --------------------------------------------------------------------------

  @override
  Future<LanConnectionResult> connectToPrimary() async {
    final role = await _localConfig.getLanRole();
    if (role != LanRole.secondary) {
      // Only a Secondary_Device connects outward to a primary.
      return _publish(
        const LanConnectionResult(
          status: LanConnectionStatus.notSecondary,
          reason: 'This device is not configured as a Secondary_Device.',
        ),
      );
    }

    final host = (await _localConfig.getLanPrimaryHost())?.trim();
    if (host == null || host.isEmpty) {
      return _publish(
        const LanConnectionResult(
          status: LanConnectionStatus.noPrimaryConfigured,
          reason: 'No Primary_Device address is configured.',
        ),
      );
    }

    // Reuse the existing offline auth/JWT session — no new auth scheme
    // (Requirement 15.2). Without a session we cannot form an authenticated
    // connection, so we must not connect.
    final token = await _resolveAuthToken();
    if (token == null || token.isEmpty) {
      return _publish(
        LanConnectionResult(
          status: LanConnectionStatus.unauthenticated,
          primaryHost: host,
          reason: 'No authenticated session is available for the LAN session.',
        ),
      );
    }

    final baseUri = _primaryBaseUri(host);
    bool reachable;
    try {
      // The transport applies the window internally; the outer timeout is a
      // belt-and-braces guard so connect always completes/abandons within 10s
      // (Requirement 15.2).
      reachable = await _transport
          .probe(baseUri, authToken: token, timeout: _connectTimeout)
          .timeout(_connectTimeout);
    } on TimeoutException {
      reachable = false;
    } catch (_) {
      // A well-behaved transport never throws; treat anything unexpected as
      // unreachable rather than surfacing a raw error to the service layer.
      reachable = false;
    }

    // Requirement 15.4: report the fresh result regardless of any prior status.
    return _publish(
      reachable
          ? LanConnectionResult(
              status: LanConnectionStatus.connected,
              primaryHost: host,
              reason: 'Connected to the Primary_Device over the LAN.',
            )
          : LanConnectionResult(
              status: LanConnectionStatus.unreachable,
              primaryHost: host,
              reason:
                  'The Primary_Device could not be reached within '
                  '${_connectTimeout.inSeconds}s.',
            ),
    );
  }

  @override
  bool get canWriteToPrimaryStore {
    final last = _lastConnection;
    switch (last?.status) {
      // A Secondary_Device may write only while it is currently connected to
      // the primary (Requirement 15.6).
      case LanConnectionStatus.connected:
        return true;
      // Not a secondary deployment (or this device is the primary / standalone)
      // — the local machine owns its authoritative store and may always write.
      case LanConnectionStatus.notSecondary:
        return true;
      // Unreachable / unauthenticated / no-primary / not-yet-probed: block
      // writes to the primary's store (Requirement 15.6).
      default:
        return false;
    }
  }

  /// Records [result] as the latest status, emits it to listeners, and returns
  /// it so the connect path can both publish and return in one step.
  LanConnectionResult _publish(LanConnectionResult result) {
    _lastConnection = result;
    if (!_statusController.isClosed) {
      _statusController.add(result);
    }
    return result;
  }

  Uri _primaryBaseUri(String host) =>
      Uri(scheme: 'http', host: host, port: _primaryPort);

  Future<String?> _resolveAuthToken() async {
    try {
      return await _authTokenProvider();
    } catch (_) {
      return null;
    }
  }

  /// Releases stream resources. Call when the coordinator is disposed.
  Future<void> dispose() async {
    _registry?.releaseAll();
    await _statusController.close();
  }

  // --------------------------------------------------------------------------
  // Default seams (reuse existing components)
  // --------------------------------------------------------------------------

  /// Default allowance resolver: reads the activated License_Token's
  /// `maxDevices` from the encrypted Local_License_File using the same
  /// fingerprint + app-secret seam the Activation_Service / Migration_Wizard
  /// use. Returns the single-device default (1) when not activated or the file
  /// cannot be read.
  static Future<int> _defaultAllowanceResolver() async {
    try {
      final encryption = LocalStoreEncryption.instance;
      final appSecret = await encryption.loadAppSecret();
      if (appSecret == null || appSecret.isEmpty) return 1;

      final collector = DeviceFingerprintCollector();
      final fingerprint = await collector.collect();
      final fingerprintHash = collector.fingerprintHash(fingerprint);

      final payload = await LocalLicenseFile().read(
        fingerprintHash: fingerprintHash,
        appSecret: appSecret,
      );
      return payload?.token.maxDevices ?? 1;
    } catch (e) {
      LoggerService.w(
        _logTag,
        'Could not read device allowance; defaulting to 1 device.',
      );
      return 1;
    }
  }

  /// Default authenticated-session token provider. Returns `null` so that an
  /// unwired coordinator fails CLOSED (reports `unauthenticated` rather than
  /// connecting without a session). The real provider — the existing offline
  /// auth/JWT session (e.g. the registered `SessionManager` access token) — is
  /// injected by the `service_locator` wiring (task 20.1), exactly as the
  /// Backend_Supervisor receives its license/session seams. This keeps the
  /// coordinator decoupled from `sl` and reuses the established session.
  static Future<String?> _defaultAuthToken() async => null;
}
