// ============================================================================
// BACKUP_LOCATION_GATE — first-run writable backup-location selection gate
// ============================================================================
// Feature: offline-license-activation (Task 14.1)
//
// The first piece of the Backup_Service. On the first run in
// Offline_Lifetime_Mode the user must choose a backup location before the app
// can be used, and only a *writable* location may be accepted
// (Requirements 13.1, 13.6):
//
//   * BLOCK USE until a writable backup location has been selected
//     ([isSetupRequired] is true while none is configured).
//   * VALIDATE WRITABILITY of every candidate location ([isWritable]).
//   * ACCEPT a writable selection by persisting it via Local_Config
//     ([selectLocation] → [BackupLocationAccepted]).
//   * REJECT a non-writable selection with a clear not-writable indication,
//     persist nothing, and keep requiring a writable location
//     ([selectLocation] → [BackupLocationRejected]; [isSetupRequired] stays
//     true).
//
// Design constraints honoured here:
//   * SERVICE LAYER ONLY. Injected through the service locator and never
//     referenced from the widget tree; this file imports no Flutter UI code.
//     The "prompt" is the UI's concern — this gate owns the decision/gating
//     logic the prompt drives.
//   * REUSE, DON'T REBUILD. Persistence reuses the existing
//     `LocalConfig.getBackupLocation` / `setBackupLocation` accessors; the
//     OS-path/probe pattern mirrors the rest of the offline stack.
//
// Scheduled verified backups (Task 14.2) and the restore wizard (Task 14.3)
// build on top of this gate; they are intentionally out of scope here.
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../mode/local_config.dart';
import '../services/logger_service.dart';

/// The result of evaluating a candidate backup location (design "Backup_Service").
sealed class BackupLocationOutcome {
  const BackupLocationOutcome();
}

/// The selected location is writable and has been persisted as the backup
/// location; first-run setup is complete (Requirement 13.1).
class BackupLocationAccepted extends BackupLocationOutcome {
  /// The accepted, persisted backup-directory path.
  final String path;
  const BackupLocationAccepted(this.path);
}

/// The selected location is not writable. Nothing is persisted, and a writable
/// location continues to be required (Requirement 13.6).
class BackupLocationRejected extends BackupLocationOutcome {
  /// The rejected candidate path (may be empty when no path was provided).
  final String path;

  /// Human-readable not-writable indication for display by the caller.
  final String reason;
  const BackupLocationRejected({required this.path, required this.reason});
}

/// Probes whether [path] can be written to. Returns `true` only when a file can
/// actually be created and removed inside the location. Injectable so tests can
/// supply a deterministic decision without touching the filesystem.
typedef BackupLocationProbe = Future<bool> Function(String path);

/// Gates first-run use of DukanX in Offline_Lifetime_Mode behind the selection
/// of a writable backup location (Requirements 13.1, 13.6).
class BackupLocationGate {
  static const String _logTag = 'BackupLocationGate';

  /// Standard not-writable indication returned for a rejected selection.
  static const String notWritableReason =
      'The selected backup location is not writable. '
      'Please choose a location you have permission to write to.';

  final LocalConfig _config;
  final BackupLocationProbe _probe;

  /// Creates a [BackupLocationGate].
  ///
  /// [config] persists/reads the chosen location (defaults to a real
  /// [LocalConfig]); [writabilityProbe] decides whether a location is writable
  /// (defaults to a real filesystem probe). Both are injectable for testing.
  BackupLocationGate({
    LocalConfig? config,
    BackupLocationProbe? writabilityProbe,
  }) : _config = config ?? LocalConfig(),
       _probe = writabilityProbe ?? _defaultWritabilityProbe;

  /// Whether first-run setup is still required, i.e. no backup location has
  /// been configured yet. While this is `true`, the app must block use until a
  /// writable location is selected (Requirement 13.1).
  Future<bool> isSetupRequired() async {
    final location = await configuredLocation();
    return location == null || location.isEmpty;
  }

  /// The currently configured backup-directory path, or `null` when none has
  /// been accepted yet.
  Future<String?> configuredLocation() => _config.getBackupLocation();

  /// Returns `true` iff [path] is a non-empty location that can be written to.
  Future<bool> isWritable(String path) async {
    final candidate = path.trim();
    if (candidate.isEmpty) return false;
    try {
      return await _probe(candidate);
    } catch (e) {
      // A probe that throws is treated as not-writable (fail closed).
      LoggerService.w(_logTag, 'Writability probe failed for a location: $e');
      return false;
    }
  }

  /// Validates [path] and, only when it is writable, persists it as the backup
  /// location and returns [BackupLocationAccepted]. A non-writable (or empty)
  /// selection persists nothing and returns [BackupLocationRejected], so a
  /// writable location continues to be required (Requirements 13.1, 13.6).
  Future<BackupLocationOutcome> selectLocation(String path) async {
    final candidate = path.trim();

    if (!await isWritable(candidate)) {
      LoggerService.i(
        _logTag,
        'Rejected backup location selection: not writable.',
      );
      return BackupLocationRejected(path: candidate, reason: notWritableReason);
    }

    await _config.setBackupLocation(candidate);
    LoggerService.i(_logTag, 'Accepted writable backup location.');
    return BackupLocationAccepted(candidate);
  }

  // --------------------------------------------------------------------------
  // Default filesystem writability probe
  // --------------------------------------------------------------------------

  /// Real writability check: ensure the directory exists (creating it when
  /// possible), then create and delete a unique probe file inside it. Any
  /// failure means the location is not writable.
  static Future<bool> _defaultWritabilityProbe(String path) async {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        // A location we cannot even create is not writable.
        dir.createSync(recursive: true);
      }

      final probe = File(p.join(path, '.dukanx_write_test_${_probeSuffix()}'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _probeSuffix() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 32);
    return '${now}_$rand';
  }
}
