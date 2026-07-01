// ============================================================================
// LOCAL CONFIG — Secure persistence for the offline/cloud operating mode
// ============================================================================
// Feature: offline-license-activation (Task 1.1)
//
// Local_Config is the service-layer store that persists the selected
// Operating_Mode plus the offline runtime settings (background-validation
// interval, scheduled backup time, backup location, and LAN role).
//
// Design constraints honoured here:
//   * SERVICE LAYER ONLY. This class is injected through the existing
//     `service_locator` (`sl`) and is NEVER referenced from the widget tree.
//     It imports no Flutter UI/material code on purpose.
//   * SECURE STORAGE. Values are persisted via `flutter_secure_storage`
//     (already used by `api_client.dart`), keeping the operating mode and
//     runtime settings out of plain SharedPreferences.
//   * THIN PERSISTENCE. This class only reads/writes values. Higher-level
//     policy (default-to-cloud + unrecognized-mode handling in Mode_Manager,
//     and validation-interval range validation in License_Validator) lives in
//     their respective components per the design.
//
// Author: DukanX Engineering
// ============================================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/logger_service.dart';

/// LAN deployment role persisted in [LocalConfig].
///
/// Mirrors the Primary_Device / Secondary_Device concepts from the LAN
/// coordination requirements; [none] means the machine participates in no LAN
/// deployment (single-machine install, the default).
enum LanRole { none, primary, secondary }

/// Secure, service-layer persistence for the operating mode and the offline
/// runtime settings.
///
/// The operating mode is stored as a raw string so that this class stays
/// decoupled from the `OperatingMode` enum owned by `Mode_Manager` (task 1.2);
/// Mode_Manager is responsible for parsing the raw value and applying the safe
/// default / unrecognized-value handling (Requirement 1.9).
class LocalConfig {
  /// Storage keys are namespaced under `local_config.` so they never collide
  /// with the existing secure-storage entries (e.g. `session_tenant_id`).
  static const String _kOperatingMode = 'local_config.operating_mode';
  static const String _kValidationIntervalHours =
      'local_config.validation_interval_hours';
  static const String _kBackupTime = 'local_config.backup_time';
  static const String _kBackupLocation = 'local_config.backup_location';
  static const String _kLanRole = 'local_config.lan_role';
  static const String _kLanPrimaryHost = 'local_config.lan_primary_host';
  static const String _kDeferredUpdateVersions =
      'local_config.deferred_update_versions';

  /// All keys owned by this config, used by [clear].
  static const List<String> _allKeys = <String>[
    _kOperatingMode,
    _kValidationIntervalHours,
    _kBackupTime,
    _kBackupLocation,
    _kLanRole,
    _kLanPrimaryHost,
    _kDeferredUpdateVersions,
  ];

  /// Default background-validation interval in hours (Requirement 7.2).
  static const int defaultValidationIntervalHours = 24;

  static const String _logTag = 'LocalConfig';

  final FlutterSecureStorage _storage;

  /// Creates a [LocalConfig].
  ///
  /// A [FlutterSecureStorage] instance can be injected for testing; in
  /// production the default instance is used, matching `api_client.dart`.
  LocalConfig({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  // --------------------------------------------------------------------------
  // Operating mode (raw string; Mode_Manager owns enum mapping + defaults)
  // --------------------------------------------------------------------------

  /// Returns the persisted operating-mode string, or `null` if none has been
  /// stored yet (Requirement 1.2). Mode_Manager interprets a `null` or
  /// unrecognized value as Cloud_Subscription_Mode.
  Future<String?> getOperatingMode() => _read(_kOperatingMode);

  /// Persists the selected operating-mode string (Requirement 1.3).
  Future<void> setOperatingMode(String mode) => _write(_kOperatingMode, mode);

  // --------------------------------------------------------------------------
  // Background-validation interval (whole hours)
  // --------------------------------------------------------------------------

  /// Returns the persisted background-validation interval in hours, falling
  /// back to [defaultValidationIntervalHours] when unset or unparseable.
  ///
  /// Range validation (1..168) is enforced by the License_Validator before it
  /// asks this store to persist a value, so this getter only guards against a
  /// missing/corrupt entry.
  Future<int> getValidationIntervalHours() async {
    final raw = await _read(_kValidationIntervalHours);
    if (raw == null) return defaultValidationIntervalHours;
    return int.tryParse(raw) ?? defaultValidationIntervalHours;
  }

  /// Persists the background-validation interval in hours.
  Future<void> setValidationIntervalHours(int hours) =>
      _write(_kValidationIntervalHours, hours.toString());

  // --------------------------------------------------------------------------
  // Scheduled backup time (stored as "HH:mm")
  // --------------------------------------------------------------------------

  /// Returns the configured daily backup time as `HH:mm`, or `null` if unset.
  Future<String?> getBackupTime() => _read(_kBackupTime);

  /// Persists the configured daily backup time (expected format `HH:mm`).
  Future<void> setBackupTime(String hourMinute) =>
      _write(_kBackupTime, hourMinute);

  // --------------------------------------------------------------------------
  // Backup location (filesystem path)
  // --------------------------------------------------------------------------

  /// Returns the configured backup directory path, or `null` if unset.
  Future<String?> getBackupLocation() => _read(_kBackupLocation);

  /// Persists the configured backup directory path.
  Future<void> setBackupLocation(String path) => _write(_kBackupLocation, path);

  // --------------------------------------------------------------------------
  // LAN role
  // --------------------------------------------------------------------------

  /// Returns the persisted [LanRole], defaulting to [LanRole.none] when unset
  /// or unrecognized.
  Future<LanRole> getLanRole() async {
    final raw = await _read(_kLanRole);
    if (raw == null) return LanRole.none;
    return LanRole.values.firstWhere(
      (r) => r.name == raw,
      orElse: () => LanRole.none,
    );
  }

  /// Persists the LAN deployment role.
  Future<void> setLanRole(LanRole role) => _write(_kLanRole, role.name);

  /// Returns the configured Primary_Device LAN host (IP or hostname) a
  /// Secondary_Device connects to, or `null` when unset. Only meaningful when
  /// [getLanRole] is [LanRole.secondary].
  Future<String?> getLanPrimaryHost() => _read(_kLanPrimaryHost);

  /// Persists the Primary_Device LAN host a Secondary_Device connects to.
  Future<void> setLanPrimaryHost(String host) => _write(_kLanPrimaryHost, host);

  // --------------------------------------------------------------------------
  // Deferred application updates (Update_Service, Requirement 18.3)
  // --------------------------------------------------------------------------

  /// Returns the set of update version strings the user has chosen to defer.
  ///
  /// Persisting these means a deferred (non-mandatory) update is not
  /// re-prompted on every restart (Requirement 18.3 — "updates do not
  /// interrupt my work"). The Update_Service owns the policy that a mandatory
  /// security patch is never placed in this set (Requirement 18.4); this store
  /// only reads/writes the raw values.
  ///
  /// Versions are stored as a newline-separated list; empty/blank entries are
  /// ignored so a corrupt or empty value yields an empty set.
  Future<Set<String>> getDeferredUpdateVersions() async {
    final raw = await _read(_kDeferredUpdateVersions);
    if (raw == null || raw.isEmpty) return <String>{};
    return raw
        .split('\n')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet();
  }

  /// Persists the set of deferred update version strings, replacing any
  /// previously stored set.
  Future<void> setDeferredUpdateVersions(Set<String> versions) {
    final cleaned = versions.map((v) => v.trim()).where((v) => v.isNotEmpty);
    return _write(_kDeferredUpdateVersions, cleaned.join('\n'));
  }

  // --------------------------------------------------------------------------
  // Maintenance
  // --------------------------------------------------------------------------

  /// Removes every value owned by this config. Useful for full device reset
  /// and for isolating test cases; does not touch unrelated secure-storage
  /// entries.
  Future<void> clear() async {
    for (final key in _allKeys) {
      try {
        await _storage.delete(key: key);
      } on Exception catch (e) {
        LoggerService.w(_logTag, 'Failed to delete "$key": $e');
      }
    }
  }

  // --------------------------------------------------------------------------
  // Internal secure-storage helpers
  // --------------------------------------------------------------------------

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Exception catch (e) {
      LoggerService.w(_logTag, 'Failed to read "$key": $e');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Exception catch (e) {
      LoggerService.e(_logTag, 'Failed to write "$key"', e);
      rethrow;
    }
  }
}
