// ============================================================================
// DEFAULT LICENSE VALIDATOR — stateful silent background-validation loop
// ============================================================================
// Feature: offline-license-activation (Task 5.2)
//
// This is the concrete [LicenseValidator] that owns the silent background
// revalidation loop layered on top of the pure `classify()` contract from
// `license_validator.dart` (task 5.1). It satisfies Requirements 7.1–7.5 & 7.12:
//
//   7.1  Background validation every 24h (±5 min) measured from the LAST
//        COMPLETED attempt — a one-shot timer is rescheduled after each attempt
//        finishes, with a random ±5-minute jitter.
//   7.2  The interval is configurable to a whole-hour value in [1, 168],
//        defaulting to 24, persisted through Local_Config. An out-of-range value
//        is rejected and the previously applied interval is retained.
//   7.3  Each attempt completes or is abandoned within 2 seconds — the whole
//        attempt future is bounded by [kValidationAttemptBudget].
//   7.4  The attempt runs asynchronously (await-based I/O, no heavy synchronous
//        work), so the UI event loop is never blocked. classify() is O(1).
//   7.5  On success, the server-provided `Last_Validated_At` is recorded
//        (persisted back into the Local_License_File) and the new
//        Grace_Period_State is emitted.
//   7.12 On failure (server unreachable, network error, or 2-second timeout —
//        and, conservatively, a definitive server rejection), the most recent
//        `Last_Validated_At` is RETAINED, the Grace_Period_State is NOT advanced
//        as a result of the failure, and the user can keep working.
//
// REUSE, DON'T REBUILD:
//   * Day/drift/tamper classification → `LicenseValidator.classify` (task 5.1).
//   * Interval persistence + range note → `LocalConfig` (task 1.1).
//   * Encrypted activation result + `lastValidatedAt` → `LocalLicenseFile` (4.3).
//   * Fingerprint + drift counting → `FingerprintCollector` /
//     `MachineFingerprint.differingComponentCount` (tasks 4.1/4.2/6.1).
//   * App secret loading (never hardcoded) → `LocalStoreEncryption.loadAppSecret`.
//   * Bounded network call → `LicenseValidationTransport` (this task).
//
// TESTABILITY: the clock, the timer scheduler, the random jitter source, and
// every collaborator (transport, fingerprint collector, license file,
// encryption, config) are injectable. With a fixed clock and a manual scheduler
// a test can drive `runBackgroundValidation()` deterministically.
//
// SERVICE LAYER ONLY: no Flutter widget/material imports.
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';
import 'dart:math';

import '../core/database/local_store_crypto.dart';
import '../core/licensing/local_license_file.dart';
import '../core/licensing/validation/license_validation_transport.dart';
import '../core/mode/local_config.dart';
import '../core/security/device/device_fingerprint.dart';
import '../core/services/logger_service.dart';
import 'license_validator.dart';

/// Creates a one-shot timer that invokes [callback] after [duration]. Injectable
/// so tests can substitute a manual/fake scheduler instead of real wall-clock
/// timers.
typedef ValidatorTimerFactory =
    Timer Function(Duration duration, void Function() callback);

/// Concrete [LicenseValidator] implementing the stateful silent
/// background-validation loop (Task 5.2).
class DefaultLicenseValidator implements LicenseValidator {
  static const String _logTag = 'LicenseValidator';

  /// Lowest configurable validation interval (Requirement 7.2).
  static const int minIntervalHours = 1;

  /// Highest configurable validation interval (Requirement 7.2).
  static const int maxIntervalHours = 168;

  /// Tolerance applied as random jitter around the scheduled interval
  /// (Requirement 7.1: ±5 minutes).
  static const Duration intervalTolerance = Duration(minutes: 5);

  /// Per-attempt budget; an attempt that exceeds it is abandoned (Requirement 7.3).
  final Duration _attemptBudget;

  final LocalConfig _config;
  final LocalLicenseFile _licenseFile;
  final LicenseValidationTransport _transport;
  final FingerprintCollector _fingerprintCollector;
  final LocalStoreEncryption _encryption;

  /// Returns "now". Defaults to the UTC wall clock; injectable for tests.
  final DateTime Function() _now;

  /// Creates the next one-shot timer; injectable for tests.
  final ValidatorTimerFactory _timerFactory;

  /// Jitter source for the ±5-minute tolerance; injectable for tests.
  final Random _random;

  final StreamController<GracePeriodState> _stateController =
      StreamController<GracePeriodState>.broadcast();

  /// The interval currently applied to the loop. Seeded from [LocalConfig] on
  /// [start]; retained verbatim when an out-of-range value is rejected (7.2).
  int _intervalHours = LocalConfig.defaultValidationIntervalHours;

  /// The most recently recorded trusted reference time. Updated only on a
  /// successful validation; retained on any failure (Requirement 7.12).
  DateTime? _lastValidatedAt;

  /// The most recently emitted Grace_Period_State (the "current" state).
  GracePeriodState? _currentState;

  Timer? _timer;
  bool _running = false;
  bool _attemptInProgress = false;
  bool _disposed = false;

  DefaultLicenseValidator({
    LocalConfig? config,
    LocalLicenseFile? licenseFile,
    LicenseValidationTransport? transport,
    FingerprintCollector? fingerprintCollector,
    LocalStoreEncryption? encryption,
    DateTime Function()? now,
    ValidatorTimerFactory? timerFactory,
    Random? random,
    Duration attemptBudget = kValidationAttemptBudget,
  }) : _config = config ?? LocalConfig(),
       _licenseFile = licenseFile ?? LocalLicenseFile(),
       _transport = transport ?? HttpLicenseValidationTransport(),
       _fingerprintCollector =
           fingerprintCollector ?? DeviceFingerprintCollector(),
       _encryption = encryption ?? LocalStoreEncryption.instance,
       _now = now ?? (() => DateTime.now().toUtc()),
       _timerFactory = timerFactory ?? ((d, cb) => Timer(d, cb)),
       _random = random ?? Random(),
       _attemptBudget = attemptBudget;

  // --------------------------------------------------------------------------
  // Public state surface
  // --------------------------------------------------------------------------

  @override
  Stream<GracePeriodState> get state => _stateController.stream;

  /// The most recently emitted [GracePeriodState], or `null` before the first
  /// classification. Lets late subscribers (the broadcast stream does not
  /// replay) read the current value synchronously.
  GracePeriodState? get currentState => _currentState;

  /// The currently applied background-validation interval, in whole hours.
  int get intervalHours => _intervalHours;

  /// The most recently recorded trusted reference time, or `null` when no
  /// Local_License_File has been read yet.
  DateTime? get lastValidatedAt => _lastValidatedAt;

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  /// Starts the background-validation loop: loads the configured interval and
  /// the stored `Last_Validated_At`, emits the initial Grace_Period_State, and
  /// schedules the first attempt. Calling [start] when already running is a
  /// no-op.
  Future<void> start() async {
    if (_disposed) {
      throw StateError('DefaultLicenseValidator has been disposed.');
    }
    if (_running) return;
    _running = true;

    // Adopt the persisted interval, clamped defensively into range.
    final persisted = await _config.getValidationIntervalHours();
    _intervalHours = _isValidInterval(persisted)
        ? persisted
        : LocalConfig.defaultValidationIntervalHours;

    // Seed the trusted reference + initial state from the stored license file.
    await _refreshFromLicenseFile();

    _scheduleNext();
  }

  /// Stops the loop and cancels any pending timer. The state stream stays open
  /// so consumers keep their subscription; call [dispose] to release it.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Permanently releases resources. After disposal the validator cannot be
  /// restarted.
  Future<void> dispose() async {
    stop();
    _disposed = true;
    await _stateController.close();
  }

  // --------------------------------------------------------------------------
  // Interval configuration (Requirement 7.2)
  // --------------------------------------------------------------------------

  /// Applies a new background-validation interval.
  ///
  /// Accepts the value if and only if it is a whole number of hours in
  /// [minIntervalHours, maxIntervalHours]. On acceptance the value is persisted
  /// through [LocalConfig], adopted by the loop, and the next attempt is
  /// rescheduled. On rejection the previously applied interval is retained and
  /// nothing is persisted (Requirement 7.2). Returns `true` iff accepted.
  Future<bool> setValidationIntervalHours(int hours) async {
    if (!_isValidInterval(hours)) {
      LoggerService.w(
        _logTag,
        'Rejected out-of-range validation interval ($hours h); '
        'retaining $_intervalHours h.',
      );
      return false;
    }

    _intervalHours = hours;
    await _config.setValidationIntervalHours(hours);
    LoggerService.i(_logTag, 'Validation interval set to $hours h.');

    // Reschedule so the new interval takes effect from now.
    if (_running) {
      _scheduleNext();
    }
    return true;
  }

  bool _isValidInterval(int hours) =>
      hours >= minIntervalHours && hours <= maxIntervalHours;

  // --------------------------------------------------------------------------
  // Scheduling — one-shot timer rescheduled from the last completed attempt
  // --------------------------------------------------------------------------

  void _scheduleNext() {
    if (!_running || _disposed) return;
    _timer?.cancel();
    _timer = _timerFactory(_nextDelay(), _onTimer);
  }

  /// The next delay = interval ± a random jitter up to [intervalTolerance]
  /// (Requirement 7.1). Clamped to stay strictly positive.
  Duration _nextDelay() {
    final base = Duration(hours: _intervalHours);
    // Uniform jitter in [-tolerance, +tolerance] milliseconds.
    final span = intervalTolerance.inMilliseconds;
    final jitterMs = _random.nextInt(2 * span + 1) - span;
    final totalMs = base.inMilliseconds + jitterMs;
    return Duration(milliseconds: totalMs < 1 ? 1 : totalMs);
  }

  void _onTimer() {
    // Run the attempt, then reschedule from completion (Requirement 7.1:
    // measured from the last completed attempt) regardless of the outcome.
    runBackgroundValidation().whenComplete(() {
      if (_running && !_disposed) _scheduleNext();
    });
  }

  // --------------------------------------------------------------------------
  // The attempt (Requirements 7.3, 7.4, 7.5, 7.12)
  // --------------------------------------------------------------------------

  @override
  Future<void> runBackgroundValidation() async {
    if (_disposed) return;
    // Never overlap attempts; a slow attempt is already bounded below.
    if (_attemptInProgress) return;
    _attemptInProgress = true;
    try {
      // The whole attempt is bounded by the 2-second budget. On timeout the
      // attempt is abandoned and state is retained (Requirements 7.3, 7.12).
      await _attempt().timeout(
        _attemptBudget,
        onTimeout: () {
          LoggerService.w(
            _logTag,
            'Background validation abandoned (>${_attemptBudget.inSeconds}s); '
            'retaining last state.',
          );
        },
      );
    } catch (e) {
      // Any unexpected error retains state and lets the user keep working.
      LoggerService.w(_logTag, 'Background validation error; retaining state.');
    } finally {
      _attemptInProgress = false;
    }
  }

  /// One validation attempt. Reads the stored license, calls the bounded
  /// transport, and on success records the server `Last_Validated_At` and emits
  /// the new Grace_Period_State. Every non-success path returns without
  /// touching the recorded state.
  Future<void> _attempt() async {
    // The app secret is loaded at runtime (never hardcoded). Without it we
    // cannot open the license file, so retain state and bail.
    final appSecret = await _encryption.loadAppSecret();
    if (appSecret == null || appSecret.isEmpty) {
      LoggerService.w(
        _logTag,
        'Application secret unavailable; retaining last state.',
      );
      return;
    }

    final current = await _fingerprintCollector.collect();
    final fingerprintHash = _fingerprintCollector.fingerprintHash(current);

    final LocalLicensePayload? payload;
    try {
      payload = await _licenseFile.read(
        fingerprintHash: fingerprintHash,
        appSecret: appSecret,
      );
    } catch (e) {
      // Tampered / undecryptable file (e.g. a hashed component drifted). This
      // is not a validation outcome; retain state for this attempt.
      LoggerService.w(
        _logTag,
        'Local_License_File could not be read; retaining last state.',
      );
      return;
    }

    if (payload == null) {
      // No activation on this machine — nothing to revalidate.
      return;
    }

    final result = await _transport.validate(
      licenseToken: payload.token.raw,
      fingerprint: current.toMap().map(
        (k, v) => MapEntry(k, v?.toString() ?? ''),
      ),
    );

    switch (result) {
      // 7.5 — success: record the server `Last_Validated_At`, persist it, and
      // emit the freshly classified Grace_Period_State.
      case ValidationTransportSuccess(:final lastValidatedAt):
        await _onValidationSuccess(
          serverLastValidatedAt: lastValidatedAt,
          payload: payload,
          activatedFingerprint: payload.machineFingerprint,
          currentFingerprint: current,
          fingerprintHash: fingerprintHash,
          appSecret: appSecret,
        );

      // 7.12 — no successful refresh. Retain the recorded `Last_Validated_At`
      // and do NOT advance the Grace_Period_State as a result of the failure.
      case ValidationTransportUnavailable(:final reason):
        LoggerService.i(
          _logTag,
          'Validation unavailable ($reason); retaining last state.',
        );
      case ValidationTransportRejected(:final code):
        LoggerService.i(
          _logTag,
          'Validation rejected ($code); retaining last state.',
        );
    }
  }

  /// Records a successful validation: updates the in-memory reference, persists
  /// the new `Last_Validated_At` back into the Local_License_File (preserving
  /// the originally activated fingerprint), and emits the new state.
  Future<void> _onValidationSuccess({
    required DateTime serverLastValidatedAt,
    required LocalLicensePayload payload,
    required Map<String, dynamic> activatedFingerprint,
    required MachineFingerprint currentFingerprint,
    required String fingerprintHash,
    required String appSecret,
  }) async {
    final recorded = serverLastValidatedAt.toUtc();
    _lastValidatedAt = recorded;

    // Persist the refreshed reference. A persistence failure must not crash the
    // loop; the in-memory reference still reflects the successful validation.
    try {
      await _licenseFile.write(
        payload: LocalLicensePayload(
          token: payload.token,
          machineFingerprint: activatedFingerprint,
          lastValidatedAt: recorded,
        ),
        fingerprintHash: fingerprintHash,
        appSecret: appSecret,
      );
    } catch (e) {
      LoggerService.w(
        _logTag,
        'Validation succeeded but persisting Last_Validated_At failed.',
      );
    }

    final drift = _driftAgainstActivated(
      activatedFingerprint,
      currentFingerprint,
    );
    _emit(
      LicenseValidator.classify(
        now: _now(),
        lastValidatedAt: recorded,
        driftComponentCount: drift,
      ),
    );
  }

  /// Loads the stored `Last_Validated_At` (if any) and emits the initial
  /// Grace_Period_State so consumers have a value before the first attempt.
  /// Failures here are non-fatal: the loop still starts.
  Future<void> _refreshFromLicenseFile() async {
    try {
      final appSecret = await _encryption.loadAppSecret();
      if (appSecret == null || appSecret.isEmpty) return;

      final current = await _fingerprintCollector.collect();
      final fingerprintHash = _fingerprintCollector.fingerprintHash(current);

      final payload = await _licenseFile.read(
        fingerprintHash: fingerprintHash,
        appSecret: appSecret,
      );
      if (payload == null) return;

      _lastValidatedAt = payload.lastValidatedAt.toUtc();
      final drift = _driftAgainstActivated(payload.machineFingerprint, current);
      _emit(
        LicenseValidator.classify(
          now: _now(),
          lastValidatedAt: _lastValidatedAt!,
          driftComponentCount: drift,
        ),
      );
    } catch (e) {
      // Could not read a starting state; the loop proceeds and a later
      // successful attempt will seed it.
      LoggerService.w(
        _logTag,
        'Could not seed initial state from Local_License_File.',
      );
    }
  }

  /// Number of fingerprint components that differ between the originally
  /// activated fingerprint (stored map) and the [current] fingerprint.
  int _driftAgainstActivated(
    Map<String, dynamic> activated,
    MachineFingerprint current,
  ) {
    final activatedFp = MachineFingerprint.fromMap(activated);
    return activatedFp.differingComponentCount(current);
  }

  /// Emits [state] on the stream and records it as the current state. Always
  /// records, but only pushes onto the (open) controller.
  void _emit(GracePeriodState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
