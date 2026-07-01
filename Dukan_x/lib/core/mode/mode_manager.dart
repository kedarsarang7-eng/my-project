// ============================================================================
// MODE MANAGER — The single online/offline backend-routing switch point
// ============================================================================
// Feature: offline-license-activation (Task 1.2)
//
// Mode_Manager determines, persists, and exposes the active Operating_Mode and
// selects the active backend target for the repository layer. It is the ONLY
// decision point that differs between Cloud_Subscription_Mode (AWS) and
// Offline_Lifetime_Mode (the packaged Local_Backend on the loopback address).
//
// Design constraints honoured here:
//   * SERVICE LAYER ONLY (Requirement 1.6). This class — like
//     `local_config.dart` — imports no Flutter UI/material code and is injected
//     through the existing `service_locator` (`sl`). The active mode and the
//     active backend target are NEVER exposed to the widget tree; the UI stays
//     mode-agnostic (Requirement 1.7).
//   * REUSE, DON'T REBUILD. Persistence is delegated to the existing
//     `LocalConfig` (task 1.1) and the AWS host is read from the existing
//     `ApiConfig.baseUrl`. Mode_Manager owns only the enum <-> string mapping
//     and the safe-default / unrecognized-value policy.
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../services/logger_service.dart';
import 'local_config.dart';

/// The two runtime modes the application can run in (Requirement 1.1).
///
/// Exactly two values exist by design — there is no third mode.
enum OperatingMode {
  /// Runs against the packaged Local_Backend on the Loopback_Address with no
  /// internet dependency after activation.
  offlineLifetime,

  /// The existing mode that runs against the AWS backend. Its behaviour is the
  /// fixed baseline and is unchanged by this feature.
  cloudSubscription,
}

/// Describes a routed backend call that neither connected nor returned a
/// response within the routing timeout (Requirement 1.8).
///
/// [backendTarget] names the failed target (for example `127.0.0.1:8765` for
/// the Local_Backend, or the AWS host such as `api.dukanx.com`) so the service
/// layer can report exactly which backend failed.
class RoutingFailure {
  /// Reason value: the call did not return a response within the timeout.
  static const String reasonTimeout = 'timeout';

  /// Reason value: the call could not establish a connection to the target.
  static const String reasonConnectionFailed = 'connection_failed';

  /// The backend target that failed, e.g. `127.0.0.1:8765` or the AWS host.
  final String backendTarget;

  /// Why routing failed: [reasonTimeout] or [reasonConnectionFailed].
  final String reason;

  const RoutingFailure({required this.backendTarget, required this.reason});

  @override
  String toString() =>
      'RoutingFailure(target: $backendTarget, reason: $reason)';
}

/// Result of a routed call performed through [ModeManager.route].
///
/// A dependency-free, service-layer result type. A dedicated type (rather than
/// the UI-coupled `Result<T>` in `error_handler.dart`) keeps the mode layer
/// free of Flutter/Firebase imports (Requirement 1.6) and carries the typed
/// [RoutingFailure] that the routing-failure behaviour requires.
sealed class RouteResult<T> {
  const RouteResult();

  /// Whether the routed call succeeded.
  bool get isSuccess => this is RouteSuccess<T>;

  /// The success value, or `null` when the call failed.
  T? get valueOrNull => switch (this) {
    RouteSuccess<T>(:final value) => value,
    RouteFailure<T>() => null,
  };

  /// The routing failure, or `null` when the call succeeded.
  RoutingFailure? get failureOrNull => switch (this) {
    RouteSuccess<T>() => null,
    RouteFailure<T>(:final failure) => failure,
  };

  /// Folds the result into a single value of type [R].
  R when<R>({
    required R Function(T value) success,
    required R Function(RoutingFailure failure) failure,
  }) {
    return switch (this) {
      RouteSuccess<T>(value: final v) => success(v),
      RouteFailure<T>(failure: final f) => failure(f),
    };
  }
}

/// A successful routed call carrying its [value].
class RouteSuccess<T> extends RouteResult<T> {
  final T value;
  const RouteSuccess(this.value);
}

/// A failed routed call carrying the [RoutingFailure] that names the target.
class RouteFailure<T> extends RouteResult<T> {
  final RoutingFailure failure;
  const RouteFailure(this.failure);
}

/// Determines, persists, and exposes the active Operating_Mode and selects the
/// active backend target for the repository layer (Requirements 1.2–1.5, 1.8,
/// 1.9). Service layer only — never referenced by the widget tree.
abstract class ModeManager {
  /// The currently active Operating_Mode as last resolved/selected, read
  /// synchronously (service layer only; never read by the widget tree).
  ///
  /// This mirrors the in-memory value that backs [activeBackendBaseUri] so
  /// service-layer components (such as the Online_Only_Feature gate) can make a
  /// fast, deterministic offline/online decision without awaiting storage.
  /// Until [resolveActiveMode] runs at startup it reports the safe baseline
  /// Cloud_Subscription_Mode, so nothing is treated as offline prematurely.
  OperatingMode get activeMode;

  /// Reads the active Operating_Mode from Local_Config. A missing or
  /// unrecognized persisted value defaults to Cloud_Subscription_Mode and is
  /// persisted as that default (Requirements 1.2, 1.9).
  Future<OperatingMode> resolveActiveMode();

  /// Persists the user-selected Operating_Mode to Local_Config and makes it the
  /// active mode (Requirement 1.3).
  Future<void> selectMode(OperatingMode mode);

  /// Returns the active backend base URI: the AWS host in
  /// Cloud_Subscription_Mode (Requirement 1.4) or `http://127.0.0.1:8765` in
  /// Offline_Lifetime_Mode (Requirement 1.5).
  Uri activeBackendBaseUri();

  /// Wraps a routed call against the active backend target. If the call neither
  /// connects nor responds within [ModeManager.routingTimeout], yields a
  /// [RouteFailure] whose [RoutingFailure.backendTarget] names the active
  /// target; the active Operating_Mode is left unchanged (Requirement 1.8).
  Future<RouteResult<T>> route<T>(Future<T> Function(Uri baseUri) call);

  /// The 10-second window after which a routed call is treated as failed
  /// (Requirement 1.8).
  static const Duration routingTimeout = Duration(seconds: 10);

  /// The Local_Backend loopback target (Requirement 1.5).
  static final Uri loopbackBaseUri = Uri.parse('http://127.0.0.1:8765');
}

/// Default [ModeManager] backed by [LocalConfig] for persistence and
/// [ApiConfig] for the AWS host.
class DefaultModeManager implements ModeManager {
  static const String _logTag = 'ModeManager';

  // Stable on-disk values, decoupled from the Dart enum identifiers so a future
  // enum rename never invalidates a persisted mode. Mode_Manager owns this
  // mapping per the Local_Config contract.
  static const String _storageCloud = 'cloud_subscription';
  static const String _storageOffline = 'offline_lifetime';

  final LocalConfig _localConfig;
  final Duration _routingTimeout;

  /// The cached active mode. Defaults to Cloud_Subscription_Mode (the safe
  /// baseline) until [resolveActiveMode] runs at startup, so the application
  /// never routes to the Local_Backend before the persisted mode is known.
  OperatingMode _activeMode = OperatingMode.cloudSubscription;

  DefaultModeManager({
    required LocalConfig localConfig,
    Duration routingTimeout = ModeManager.routingTimeout,
  }) : _localConfig = localConfig,
       _routingTimeout = routingTimeout;

  /// The currently active mode (service layer only; never read by the UI).
  @override
  OperatingMode get activeMode => _activeMode;

  @override
  Future<OperatingMode> resolveActiveMode() async {
    final raw = await _localConfig.getOperatingMode();
    final parsed = _parseMode(raw);

    if (parsed == null) {
      // Missing or unrecognized persisted value -> default to cloud AND persist
      // that default so the next startup reads a recognized value (Req 1.9).
      _activeMode = OperatingMode.cloudSubscription;
      LoggerService.i(
        _logTag,
        'No recognized operating mode persisted (raw: ${raw ?? 'null'}); '
        'defaulting to Cloud_Subscription_Mode and persisting it.',
      );
      await _localConfig.setOperatingMode(_storageCloud);
      return _activeMode;
    }

    _activeMode = parsed;
    return _activeMode;
  }

  @override
  Future<void> selectMode(OperatingMode mode) async {
    // Persist first; only update the in-memory cache once persistence succeeds
    // so a failed write leaves the active mode unchanged.
    await _localConfig.setOperatingMode(_storageValue(mode));
    _activeMode = mode;
  }

  @override
  Uri activeBackendBaseUri() => baseUriForMode(_activeMode);

  /// Maps an [OperatingMode] to its backend base URI. A total function over the
  /// two modes (Requirement 1.4, 1.5): AWS host iff Cloud_Subscription_Mode,
  /// loopback iff Offline_Lifetime_Mode.
  static Uri baseUriForMode(OperatingMode mode) {
    return switch (mode) {
      OperatingMode.cloudSubscription => Uri.parse(ApiConfig.baseUrl),
      OperatingMode.offlineLifetime => ModeManager.loopbackBaseUri,
    };
  }

  @override
  Future<RouteResult<T>> route<T>(Future<T> Function(Uri baseUri) call) async {
    final target = activeBackendBaseUri();
    final label = _targetLabel(target);

    try {
      final value = await call(target).timeout(_routingTimeout);
      return RouteSuccess<T>(value);
    } on TimeoutException {
      // No response within the routing window (Req 1.8). Mode is unchanged:
      // this method never mutates _activeMode.
      LoggerService.w(_logTag, 'Routing timeout for target "$label".');
      return RouteFailure<T>(
        RoutingFailure(
          backendTarget: label,
          reason: RoutingFailure.reasonTimeout,
        ),
      );
    } on SocketException {
      LoggerService.w(
        _logTag,
        'Routing connection failed for target "$label".',
      );
      return RouteFailure<T>(
        RoutingFailure(
          backendTarget: label,
          reason: RoutingFailure.reasonConnectionFailed,
        ),
      );
    } on http.ClientException {
      LoggerService.w(
        _logTag,
        'Routing connection failed for target "$label".',
      );
      return RouteFailure<T>(
        RoutingFailure(
          backendTarget: label,
          reason: RoutingFailure.reasonConnectionFailed,
        ),
      );
    } on HttpException {
      LoggerService.w(
        _logTag,
        'Routing connection failed for target "$label".',
      );
      return RouteFailure<T>(
        RoutingFailure(
          backendTarget: label,
          reason: RoutingFailure.reasonConnectionFailed,
        ),
      );
    }
    // Non-connectivity errors thrown by `call` are domain errors, not routing
    // failures, and propagate to the caller unchanged.
  }

  // --------------------------------------------------------------------------
  // Internal helpers
  // --------------------------------------------------------------------------

  /// Produces the human-readable target label used in [RoutingFailure].
  /// `127.0.0.1:8765` for the loopback target, `api.dukanx.com` for the AWS
  /// host (the authority drops the default port).
  static String _targetLabel(Uri target) {
    final authority = target.authority;
    return authority.isNotEmpty ? authority : target.toString();
  }

  static String _storageValue(OperatingMode mode) {
    return switch (mode) {
      OperatingMode.cloudSubscription => _storageCloud,
      OperatingMode.offlineLifetime => _storageOffline,
    };
  }

  /// Parses a persisted raw value into an [OperatingMode], or `null` when the
  /// value is missing or unrecognized (the safe-default trigger for Req 1.9).
  static OperatingMode? _parseMode(String? raw) {
    switch (raw) {
      case _storageCloud:
        return OperatingMode.cloudSubscription;
      case _storageOffline:
        return OperatingMode.offlineLifetime;
      default:
        return null;
    }
  }
}
