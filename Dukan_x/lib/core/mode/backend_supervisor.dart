// ============================================================================
// BACKEND SUPERVISOR — Local_Backend process lifecycle owner
// ============================================================================
// Feature: offline-license-activation (Task 2.2)
//
// The Backend_Supervisor owns the full lifecycle of the packaged Local_Backend
// Node process (created at `Dukan_x/local-backend`, entry `dist/server.js`,
// bound to the Loopback_Address 127.0.0.1:8765). It implements:
//
//   * runStartupSequence — the ordered offline boot (Req 3.3):
//       local license check → decrypt/validate Local_License_File →
//       spawn Local_Backend → health check → connect repository → restore session.
//   * healthCheck — polls GET /health within an 8s startup window (Req 3.5/3.6).
//   * shutdown — graceful termination, force-killing after 5s (Req 3.7).
//   * automatic restart of an unexpectedly-terminated backend, up to 3
//     consecutive attempts, recording each as a RestartEvent (Req 3.8).
//   * unrecoverable-failure reporting that marks the repository layer
//     disconnected after the 3 attempts are exhausted (Req 3.9).
//
// Design constraints honoured here (see design.md "Backend_Supervisor (Dart)"):
//   * SERVICE LAYER ONLY. Injected through the existing `service_locator` (`sl`)
//     and never referenced from the widget tree. No Flutter UI imports.
//   * REUSE, DON'T REBUILD. License decrypt/validate and session-restore are
//     delegated to collaborators (arriving in later tasks) via injected
//     callbacks — this class defines clean seams and does not reimplement them.
//   * MOCKABLE PROCESS CONTROL. Spawning/killing is abstracted behind
//     [BackendProcessController]/[BackendProcessHandle] (concrete dart:io impls
//     live at the bottom of this file) so task 2.3 can mock the lifecycle.
//   * LOOPBACK ONLY. The packaged backend binds 127.0.0.1:8765 itself; this
//     supervisor never widens that exposure.
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/logger_service.dart';

// ============================================================================
// Public value types and seams
// ============================================================================

/// The Loopback_Address the packaged Local_Backend binds to (Req 3.4 / 17.6).
const String kLoopbackHost = '127.0.0.1';

/// The Loopback port the packaged Local_Backend listens on.
const int kLoopbackPort = 8765;

/// Base URI of the loopback Local_Backend.
const String kLoopbackBaseUri = 'http://$kLoopbackHost:$kLoopbackPort';

/// Records a single restart attempt of the Local_Backend process (Req 3.8).
///
/// [attempt] is the 1-based consecutive attempt number, [at] the wall-clock
/// time the restart was initiated, and [reason] a short machine-readable cause.
class RestartEvent {
  final int attempt;
  final DateTime at;
  final String reason;

  const RestartEvent({
    required this.attempt,
    required this.at,
    required this.reason,
  });

  @override
  String toString() =>
      'RestartEvent(attempt: $attempt, at: ${at.toIso8601String()}, '
      'reason: $reason)';
}

/// A startup error reported to the service layer when the Startup_Sequence
/// cannot complete (Req 3.6). [phase] names the failed boot step.
class BackendStartupError {
  final String phase;
  final String reason;
  final DateTime at;

  const BackendStartupError({
    required this.phase,
    required this.reason,
    required this.at,
  });

  @override
  String toString() => 'BackendStartupError(phase: $phase, reason: $reason)';
}

/// Abstracts a single spawned Local_Backend process so the lifecycle can be
/// mocked in tests (task 2.3). Wraps a dart:io [Process] in production.
abstract class BackendProcessHandle {
  /// Completes with the process exit code once it terminates.
  Future<int> get exitCode;

  /// Requests graceful termination (SIGTERM). Returns whether the signal was
  /// delivered. The packaged backend's SIGTERM handler performs a clean close.
  bool terminate();

  /// Forcibly terminates the process (SIGKILL). Returns whether the signal was
  /// delivered.
  bool kill();
}

/// Spawns Local_Backend processes. Injectable/mockable (task 2.3).
abstract class BackendProcessController {
  /// Starts a fresh Local_Backend process and returns a handle to it.
  Future<BackendProcessHandle> spawn();
}

/// Probes the Local_Backend `/health` endpoint. Injectable/mockable (task 2.3).
abstract class BackendHealthProbe {
  /// Returns `true` when GET /health returns a success response.
  Future<bool> check();
}

/// Seam through which the supervisor connects/disconnects the repository layer
/// to the Local_Backend (Req 3.5 / 3.9). The concrete wiring is supplied by the
/// service_locator integration in task 20.1.
abstract class RepositoryConnection {
  /// Connects the repository layer to the running Local_Backend (Req 3.5).
  void connect();

  /// Marks the repository layer disconnected from the Local_Backend (Req 3.9).
  void disconnect();
}

/// Convenience [RepositoryConnection] backed by two callbacks, so callers can
/// wire connect/disconnect without defining a class.
class CallbackRepositoryConnection implements RepositoryConnection {
  final void Function() onConnect;
  final void Function() onDisconnect;

  const CallbackRepositoryConnection({
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  void connect() => onConnect();

  @override
  void disconnect() => onDisconnect();
}

/// Verifies the local license check — the first Startup_Sequence step (Req 3.3).
/// Returns `true` when a local license is present and the boot may continue.
typedef LocalLicenseCheck = Future<bool> Function();

/// Decrypts and validates the Local_License_File (Req 3.3). Returns `true` when
/// the license is valid and not Locked. Implemented by License_Validator /
/// Security_Layer in a later task; injected here as a seam.
typedef LicenseDecryptValidate = Future<bool> Function();

/// Restores the prior session once the UI is connected (Req 3.3). Implemented
/// by a later task; injected here as a seam.
typedef SessionRestore = Future<void> Function();

// ============================================================================
// Abstract supervisor (matches design.md)
// ============================================================================

/// Owns the Local_Backend process lifecycle (Req 3.3–3.9).
abstract class BackendSupervisor {
  /// Executes the offline Startup_Sequence in order (Req 3.3):
  /// license → decrypt/validate → spawn → health → connect → restore.
  Future<void> runStartupSequence();

  /// Polls GET /health until it succeeds or the [window] elapses (Req 3.5/3.6).
  Future<bool> healthCheck({Duration window});

  /// Requests graceful shutdown and force-terminates after [graceful] (Req 3.7).
  Future<void> shutdown({Duration graceful});

  /// Emits one event per restart attempt, up to 3 consecutive (Req 3.8).
  Stream<RestartEvent> get restarts;

  /// Emits once when the backend cannot be recovered after 3 restarts (Req 3.9).
  Stream<void> get unrecoverableFailure;

  /// Emits a [BackendStartupError] whenever the Startup_Sequence stops (Req 3.6).
  Stream<BackendStartupError> get startupErrors;
}

// ============================================================================
// Concrete supervisor
// ============================================================================

/// Default [BackendSupervisor] implementation.
///
/// All collaborators are injected so the lifecycle is fully testable without a
/// real Node process (task 2.3): process control, the health probe, the
/// repository connection seam, and the license/session callbacks.
class DefaultBackendSupervisor implements BackendSupervisor {
  static const String _logTag = 'BackendSupervisor';

  /// Health-check startup window (Req 3.5/3.6).
  static const Duration kStartupWindow = Duration(seconds: 8);

  /// Graceful-shutdown window before force-termination (Req 3.7).
  static const Duration kGracefulShutdown = Duration(seconds: 5);

  /// Maximum consecutive restart attempts after an unexpected exit (Req 3.8).
  static const int kMaxRestartAttempts = 3;

  /// Interval between successive `/health` polls during the startup window.
  static const Duration _healthPollInterval = Duration(milliseconds: 250);

  final BackendProcessController _processController;
  final BackendHealthProbe _healthProbe;
  final RepositoryConnection _repository;
  final LocalLicenseCheck _localLicenseCheck;
  final LicenseDecryptValidate _licenseDecryptValidate;
  final SessionRestore _sessionRestore;

  final StreamController<RestartEvent> _restartsController =
      StreamController<RestartEvent>.broadcast();
  final StreamController<void> _unrecoverableController =
      StreamController<void>.broadcast();
  final StreamController<BackendStartupError> _startupErrorsController =
      StreamController<BackendStartupError>.broadcast();

  /// The currently supervised process handle (null when stopped).
  BackendProcessHandle? _process;

  /// Subscription that watches the running process for an unexpected exit.
  StreamSubscription<int>? _exitWatch;

  /// True once [shutdown] has been requested, so a deliberate exit is not
  /// mistaken for a crash that should trigger a restart (Req 3.8).
  bool _shuttingDown = false;

  /// True while a restart sequence is in flight, to serialize restarts.
  bool _restarting = false;

  /// True once the supervisor has given up after 3 failed restarts (Req 3.9).
  bool _unrecoverable = false;

  DefaultBackendSupervisor({
    required BackendProcessController processController,
    required BackendHealthProbe healthProbe,
    required RepositoryConnection repository,
    required LocalLicenseCheck localLicenseCheck,
    required LicenseDecryptValidate licenseDecryptValidate,
    required SessionRestore sessionRestore,
  }) : _processController = processController,
       _healthProbe = healthProbe,
       _repository = repository,
       _localLicenseCheck = localLicenseCheck,
       _licenseDecryptValidate = licenseDecryptValidate,
       _sessionRestore = sessionRestore;

  @override
  Stream<RestartEvent> get restarts => _restartsController.stream;

  @override
  Stream<void> get unrecoverableFailure => _unrecoverableController.stream;

  @override
  Stream<BackendStartupError> get startupErrors =>
      _startupErrorsController.stream;

  // --------------------------------------------------------------------------
  // Startup sequence (Req 3.3, 3.5, 3.6)
  // --------------------------------------------------------------------------

  @override
  Future<void> runStartupSequence() async {
    _shuttingDown = false;
    _unrecoverable = false;

    // Step 1 — verify the local license check (Req 3.3).
    LoggerService.i(_logTag, 'Startup: verifying local license check');
    if (!await _guard('local_license_check', _localLicenseCheck)) {
      return;
    }

    // Step 2 — decrypt + validate the Local_License_File (Req 3.3).
    LoggerService.i(_logTag, 'Startup: decrypting and validating license file');
    if (!await _guard('license_decrypt_validate', _licenseDecryptValidate)) {
      return;
    }

    // Step 3 — spawn the Local_Backend process (Req 3.3).
    LoggerService.i(_logTag, 'Startup: spawning Local_Backend process');
    try {
      _process = await _processController.spawn();
    } on Object catch (e) {
      _reportStartupError('spawn', 'failed to spawn Local_Backend: $e');
      return;
    }
    _watchForUnexpectedExit(_process!);

    // Step 4 — health check within the 8s window (Req 3.5/3.6).
    LoggerService.i(_logTag, 'Startup: health-checking Local_Backend');
    final healthy = await healthCheck(window: kStartupWindow);
    if (!healthy) {
      // Req 3.6: terminate any partially started process and stop the sequence.
      LoggerService.w(
        _logTag,
        'Startup: /health did not succeed within ${kStartupWindow.inSeconds}s',
      );
      await _terminatePartialProcess();
      _reportStartupError(
        'health_check',
        'Local_Backend did not become healthy within '
            '${kStartupWindow.inSeconds}s',
      );
      return;
    }

    // Step 5 — connect the repository layer to the Local_Backend (Req 3.5).
    LoggerService.i(_logTag, 'Startup: connecting repository layer');
    _repository.connect();

    // Step 6 — restore the prior session (Req 3.3).
    LoggerService.i(_logTag, 'Startup: restoring prior session');
    try {
      await _sessionRestore();
    } on Object catch (e) {
      // Session restore is best-effort; the backend is up and connected, so we
      // surface the failure but do not tear down a healthy backend.
      LoggerService.w(_logTag, 'Startup: session restore failed: $e');
      _reportStartupError('session_restore', 'session restore failed: $e');
      return;
    }

    LoggerService.i(_logTag, 'Startup sequence complete; Local_Backend ready');
  }

  /// Runs a boolean startup step, converting a `false` result or a thrown
  /// error into a [BackendStartupError] and stopping the sequence (Req 3.6).
  Future<bool> _guard(String phase, Future<bool> Function() step) async {
    try {
      final ok = await step();
      if (!ok) {
        _reportStartupError(phase, '$phase reported failure');
        return false;
      }
      return true;
    } on Object catch (e) {
      _reportStartupError(phase, '$phase threw: $e');
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // Health check (Req 3.5 / 3.6)
  // --------------------------------------------------------------------------

  @override
  Future<bool> healthCheck({Duration window = kStartupWindow}) async {
    final deadline = DateTime.now().add(window);
    while (DateTime.now().isBefore(deadline)) {
      bool ok = false;
      try {
        ok = await _healthProbe.check();
      } on Object catch (e) {
        // A connection refused while the server boots is expected — keep polling
        // until the window elapses.
        LoggerService.v(_logTag, 'Health poll error (will retry): $e');
        ok = false;
      }
      if (ok) return true;

      // Stop early if the remaining time is shorter than the poll interval.
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      final wait = remaining < _healthPollInterval
          ? remaining
          : _healthPollInterval;
      await Future<void>.delayed(wait);
    }
    return false;
  }

  // --------------------------------------------------------------------------
  // Shutdown (Req 3.7)
  // --------------------------------------------------------------------------

  @override
  Future<void> shutdown({Duration graceful = kGracefulShutdown}) async {
    _shuttingDown = true;

    // Stop watching for "unexpected" exits — this exit is deliberate.
    await _exitWatch?.cancel();
    _exitWatch = null;

    final process = _process;
    if (process == null) {
      LoggerService.i(_logTag, 'Shutdown: no Local_Backend process to stop');
      return;
    }

    LoggerService.i(_logTag, 'Shutdown: requesting graceful termination');
    process.terminate();

    try {
      // Wait up to the graceful window for the process to exit on its own.
      await process.exitCode.timeout(graceful);
      LoggerService.i(_logTag, 'Shutdown: Local_Backend exited gracefully');
    } on TimeoutException {
      // Req 3.7: force-terminate if not exited within the graceful window.
      LoggerService.w(
        _logTag,
        'Shutdown: graceful window (${graceful.inSeconds}s) elapsed; '
        'force-terminating',
      );
      process.kill();
      try {
        await process.exitCode;
      } on Object catch (e) {
        LoggerService.w(_logTag, 'Shutdown: error awaiting forced exit: $e');
      }
    } on Object catch (e) {
      LoggerService.w(_logTag, 'Shutdown: error awaiting graceful exit: $e');
    } finally {
      _process = null;
    }
  }

  // --------------------------------------------------------------------------
  // Unexpected-exit monitoring + restart (Req 3.8 / 3.9)
  // --------------------------------------------------------------------------

  /// Watches [process] for termination; an exit that was not requested via
  /// [shutdown] triggers the restart sequence (Req 3.8).
  void _watchForUnexpectedExit(BackendProcessHandle process) {
    _exitWatch?.cancel();
    _exitWatch = process.exitCode.asStream().listen((code) {
      if (_shuttingDown || _unrecoverable) return;
      LoggerService.w(
        _logTag,
        'Local_Backend exited unexpectedly (code: $code)',
      );
      // Fire-and-forget; restart errors are surfaced via streams.
      unawaited(_restartLoop('process_exit (code $code)'));
    });
  }

  /// Attempts up to [kMaxRestartAttempts] consecutive restarts, recording each
  /// as a [RestartEvent] (Req 3.8). On exhaustion, reports an unrecoverable
  /// failure and marks the repository disconnected (Req 3.9).
  Future<void> _restartLoop(String reason) async {
    if (_restarting) return;
    _restarting = true;
    try {
      for (var attempt = 1; attempt <= kMaxRestartAttempts; attempt++) {
        if (_shuttingDown) return;

        _restartsController.add(
          RestartEvent(attempt: attempt, at: DateTime.now(), reason: reason),
        );
        LoggerService.w(
          _logTag,
          'Restart attempt $attempt/$kMaxRestartAttempts ($reason)',
        );

        final ok = await _trySpawnAndHealthCheck();
        if (ok) {
          LoggerService.i(_logTag, 'Restart attempt $attempt succeeded');
          _restarting = false;
          return;
        }
        LoggerService.w(_logTag, 'Restart attempt $attempt failed');
      }

      // Req 3.9: all restart attempts exhausted → unrecoverable.
      _unrecoverable = true;
      LoggerService.e(
        _logTag,
        'Local_Backend unrecoverable after $kMaxRestartAttempts attempts',
      );
      _repository.disconnect();
      _unrecoverableController.add(null);
    } finally {
      _restarting = false;
    }
  }

  /// Spawns a fresh process and verifies it becomes healthy within the startup
  /// window. Returns `true` only when both succeed.
  Future<bool> _trySpawnAndHealthCheck() async {
    try {
      final process = await _processController.spawn();
      _process = process;
      _watchForUnexpectedExit(process);
    } on Object catch (e) {
      LoggerService.w(_logTag, 'Restart spawn failed: $e');
      return false;
    }

    final healthy = await healthCheck(window: kStartupWindow);
    if (!healthy) {
      await _terminatePartialProcess();
      return false;
    }
    return true;
  }

  /// Terminates a partially started / unhealthy process and clears state
  /// (Req 3.6). Best-effort: requests graceful stop then force-kills.
  Future<void> _terminatePartialProcess() async {
    final process = _process;
    if (process == null) return;
    await _exitWatch?.cancel();
    _exitWatch = null;
    try {
      process.terminate();
      await process.exitCode.timeout(kGracefulShutdown);
    } on TimeoutException {
      process.kill();
      try {
        await process.exitCode;
      } on Object catch (_) {}
    } on Object catch (e) {
      LoggerService.w(_logTag, 'Error terminating partial process: $e');
    } finally {
      _process = null;
    }
  }

  void _reportStartupError(String phase, String reason) {
    LoggerService.e(_logTag, 'Startup error [$phase]: $reason');
    _startupErrorsController.add(
      BackendStartupError(phase: phase, reason: reason, at: DateTime.now()),
    );
  }

  /// Releases stream resources. Call when the supervisor is disposed.
  Future<void> dispose() async {
    await _exitWatch?.cancel();
    await _restartsController.close();
    await _unrecoverableController.close();
    await _startupErrorsController.close();
  }
}

// ============================================================================
// Production dart:io implementations of the process/health seams
// ============================================================================

/// dart:io-backed [BackendProcessHandle] wrapping a spawned [Process].
class _IoBackendProcessHandle implements BackendProcessHandle {
  final Process _process;

  _IoBackendProcessHandle(this._process);

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool terminate() => _process.kill(ProcessSignal.sigterm);

  @override
  bool kill() => _process.kill(ProcessSignal.sigkill);
}

/// Spawns the packaged Local_Backend Node process from its `dist/server.js`
/// entry point (Req 3.1). The packaged backend binds the Loopback_Address
/// itself, so this controller only launches `node` and never widens exposure.
class NodeBackendProcessController implements BackendProcessController {
  static const String _logTag = 'BackendSupervisor';

  /// Path to the Node executable (defaults to `node` on PATH).
  final String nodeExecutable;

  /// Absolute path to the packaged backend entry script (`dist/server.js`).
  final String serverScriptPath;

  /// Working directory for the spawned process (the local-backend package dir).
  final String? workingDirectory;

  /// Extra environment passed to the process (e.g. runtime-derived keys from
  /// the Security_Layer, per the scaffold's notes). Never logged.
  final Map<String, String>? environment;

  NodeBackendProcessController({
    required this.serverScriptPath,
    this.nodeExecutable = 'node',
    this.workingDirectory,
    this.environment,
  });

  /// Resolves the packaged Local_Backend entry script bundled beside the
  /// application executable (`<exeDir>/local-backend/dist/server.js`) and its
  /// working directory.
  ///
  /// Used by the `service_locator` wiring (task 20.1) so the caller does not
  /// need to import `dart:io` to locate the bundled backend; the platform
  /// lookup stays inside this dart:io-owning file. The packaged desktop build
  /// ships `local-backend/` next to the executable.
  factory NodeBackendProcessController.bundled({
    String nodeExecutable = 'node',
    Map<String, String>? environment,
  }) {
    final sep = Platform.pathSeparator;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final backendDir = '$exeDir${sep}local-backend';
    return NodeBackendProcessController(
      serverScriptPath: '$backendDir${sep}dist${sep}server.js',
      nodeExecutable: nodeExecutable,
      workingDirectory: backendDir,
      environment: environment,
    );
  }

  @override
  Future<BackendProcessHandle> spawn() async {
    LoggerService.i(_logTag, 'Spawning Local_Backend: $serverScriptPath');
    final process = await Process.start(
      nodeExecutable,
      <String>[serverScriptPath],
      workingDirectory: workingDirectory,
      environment: environment,
      // Inherit stdio so the backend's structured logs surface in the host
      // console during development; production logging is scrubbed upstream.
      mode: ProcessStartMode.normal,
    );
    return _IoBackendProcessHandle(process);
  }
}

/// HTTP-backed [BackendHealthProbe] that polls GET /health on the loopback
/// backend and treats the AWS-style `{ success: true }` envelope as healthy
/// (Req 3.5). Any non-200 status, malformed body, or transport error is unhealthy.
class HttpBackendHealthProbe implements BackendHealthProbe {
  static const String _logTag = 'BackendSupervisor';

  /// Base URI of the loopback backend (defaults to [kLoopbackBaseUri]).
  final String baseUri;

  /// Per-request timeout; kept short so the 8s window can poll several times.
  final Duration requestTimeout;

  /// Injectable HTTP client (mockable in tests). Defaults to a shared client.
  final http.Client _client;

  HttpBackendHealthProbe({
    this.baseUri = kLoopbackBaseUri,
    this.requestTimeout = const Duration(seconds: 2),
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<bool> check() async {
    try {
      final resp = await _client
          .get(Uri.parse('$baseUri/health'))
          .timeout(requestTimeout);
      if (resp.statusCode != 200) return false;
      final body = jsonDecode(resp.body);
      if (body is Map<String, dynamic>) {
        // The scaffold returns the AWS envelope: success flag + healthy status.
        if (body['success'] == true) return true;
        final data = body['data'];
        if (data is Map && data['status'] == 'healthy') return true;
      }
      return false;
    } on Object catch (e) {
      LoggerService.v(_logTag, 'Health probe request failed: $e');
      return false;
    }
  }
}
