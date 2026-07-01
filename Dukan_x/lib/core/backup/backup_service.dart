// ============================================================================
// BACKUP_SERVICE — offline local-data backup, integrity & restore (service layer)
// ============================================================================
// Feature: offline-license-activation
//
// Backup_Service is the design component (see design.md, "Backup_Service")
// responsible for scheduled local data backups, integrity checks, and restores
// in Offline_Lifetime_Mode. It is injected through the existing
// `service_locator` (`sl`) and is NEVER referenced from the widget tree — this
// file imports no Flutter UI code.
//
// IMPLEMENTED HERE:
//
//   * Task 14.1 — FIRST-RUN WRITABLE-LOCATION PROMPT (Requirements 13.1, 13.6):
//       - BLOCK USE until a writable backup location is selected
//         ([isFirstRunSetupRequired]).
//       - REJECT a non-writable/empty selection with a clear indication, persist
//         nothing, keep requiring a writable location ([selectBackupLocation]).
//       - ACCEPT a writable selection by persisting it through Local_Config.
//     This logic lives in the composed [BackupLocationGate] (reuse, don't
//     rebuild).
//
//   * Task 14.2 — SCHEDULED VERIFIED BACKUPS, RETENTION, FAILURE BANNER
//     (Requirements 13.2, 13.3, 13.4, 13.7):
//       - DAILY backup of the Local_Store at the Local_Config-configured time,
//         at most once per 24-hour period ([runScheduledBackupIfDue],
//         [isScheduledBackupDue]) — Req 13.2.
//       - VERIFY each backup by OPENING it AND matching its CHECKSUM against the
//         source; a backup counts as "verified" only when BOTH pass
//         ([performBackup]) — Req 13.2/13.3.
//       - RETAIN at least the 7 most recent verified backups, pruning older
//         verified backups beyond that ([BackupRetentionPolicy]) — Req 13.3/13.7.
//       - DISCARD a backup that fails verification and treat it as a failed
//         attempt while leaving previously verified backups untouched — Req 13.7.
//       - After 2 CONSECUTIVE failed attempts expose a persistent,
//         non-dismissible failure-banner state that stays active until a
//         verified backup succeeds ([isFailureBannerActive]) — Req 13.4.
//     The verification/retention/banner/scheduling DECISIONS are factored into
//     pure, deterministic helpers ([BackupSchedule], [BackupRetentionPolicy],
//     [BackupFailureBanner]) so they can be property-tested later (Task 14.4,
//     Property 28) without touching the filesystem or a clock.
//
//   * Task 14.3 — RESTORE WIZARD WITH AN INTEGRITY GATE (Requirements 13.5,
//     13.8):
//       - LET THE USER SELECT A BACKUP to restore — either one of the verified
//         backups surfaced by [listVerifiedBackups] ([listRestorableBackups]),
//         or an ARBITRARY backup file/path the user points at
//         ([prepareRestoreCandidate]) — Req 13.5.
//       - VERIFY THE SELECTED BACKUP'S INTEGRITY before restoring: it must OPEN
//         successfully AND its computed checksum must match the checksum
//         RECORDED for it (its `.verified` sidecar) — the SAME open + checksum
//         gate Task 14.2 uses ([verifyBackupForRestore]) — Req 13.5.
//       - RESTORE ONLY WHEN INTEGRITY VERIFIES: replace the live Local_Store
//         with the backup, atomically (stage → re-verify → back up the existing
//         store → replace → restore-on-failure), mirroring the Migration_Wizard
//         so the live store is NEVER left half-overwritten ([restoreFromBackup])
//         — Req 13.5.
//       - IF INTEGRITY DOES NOT VERIFY, ABORT the restore, preserve the EXISTING
//         live store COMPLETELY UNCHANGED, and report a clear reason
//         ([RestoreAborted]) — Req 13.8.
//
// REUSE, DON'T REBUILD:
//   * Writability decision + Local_Config persistence → [BackupLocationGate].
//   * Local_Store file location → the same documents-dir path
//     `connection_native.dart` opens (`dukanx_enterprise.sqlite`), mirrored by
//     the Migration_Wizard.
//   * Checksum/integrity approach → `crypto`'s SHA-256, as used by the
//     Migration_Wizard's integrity check.
//   * Configured backup time + location → the existing `LocalConfig`
//     `getBackupTime` / `getBackupLocation` accessors.
//
// EXTENSION POINT NOTE:
//   * Task 14.3 (the restore wizard with an integrity gate, Requirements 13.5,
//     13.8) is now implemented additively on THIS class in a clearly delimited
//     section below; it reuses the 14.2 collaborators (storePathResolver,
//     openProbe, listVerifiedBackups, the checksum/`.verified` sidecar scheme)
//     rather than rebuilding any backup logic.
//
// SERVICE LAYER ONLY; zero Flutter UI changes; Cloud_Subscription_Mode behavior
// is untouched.
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../mode/local_config.dart';
import '../services/logger_service.dart';
import 'backup_location_gate.dart';

// Re-export the gate's result types so callers of the Backup_Service do not
// need to import the gate directly to handle a selection outcome.
export 'backup_location_gate.dart'
    show
        BackupLocationOutcome,
        BackupLocationAccepted,
        BackupLocationRejected,
        BackupLocationProbe;

// ============================================================================
// PURE DECISION LOGIC (Task 14.2) — deterministic, no I/O, property-testable
// ============================================================================

/// Pure scheduling logic for the daily backup (Requirement 13.2).
///
/// Backups run "once per 24-hour period at a configured daily time". This is
/// modelled by the most-recent *scheduled instant*: today's configured time if
/// `now` has reached it, otherwise yesterday's. A backup is due when no attempt
/// has occurred since that instant. Pure (no clock/I-O) so it can be driven
/// directly by Property 28.
class BackupSchedule {
  BackupSchedule._();

  /// Default daily backup time (02:00) used when none is configured or the
  /// stored value is unparseable.
  static const int defaultBackupMinutes = 2 * 60;

  /// Parses an `HH:mm` time-of-day into minutes-since-midnight, or `null` when
  /// the value is missing or malformed.
  static int? parseTimeOfDayMinutes(String? hourMinute) {
    if (hourMinute == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hourMinute.trim());
    if (match == null) return null;
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
    return hours * 60 + minutes;
  }

  /// The most recent instant the daily backup was scheduled to run at, relative
  /// to [now] and the configured [scheduledMinutes] (minutes since midnight).
  static DateTime mostRecentScheduledInstant(
    DateTime now,
    int scheduledMinutes,
  ) {
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final todayScheduled = todayMidnight.add(
      Duration(minutes: scheduledMinutes),
    );
    if (!now.isBefore(todayScheduled)) return todayScheduled;
    return todayScheduled.subtract(const Duration(days: 1));
  }

  /// Whether a backup is due at [now]: true when no attempt has happened since
  /// the most recent scheduled instant (Requirement 13.2).
  static bool isBackupDue({
    required DateTime now,
    required DateTime? lastBackupAt,
    required int scheduledMinutes,
  }) {
    final dueSince = mostRecentScheduledInstant(now, scheduledMinutes);
    return lastBackupAt == null || lastBackupAt.isBefore(dueSince);
  }
}

/// Pure retention policy (Requirements 13.3, 13.7): keep at least the 7 most
/// recent verified backups, pruning any older verified backups beyond that.
class BackupRetentionPolicy {
  BackupRetentionPolicy._();

  /// The minimum number of verified backups that must be retained.
  static const int minVerifiedRetained = 7;

  /// Given the set of currently [verifiedBackups], returns those that should be
  /// pruned to keep the [keep] most recent (never fewer than
  /// [minVerifiedRetained]). The newest backups are always retained.
  static List<BackupRecord> selectForPruning(
    List<BackupRecord> verifiedBackups, {
    int keep = minVerifiedRetained,
  }) {
    final retain = keep < minVerifiedRetained ? minVerifiedRetained : keep;
    final sorted = [...verifiedBackups]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (sorted.length <= retain) return const <BackupRecord>[];
    return sorted.sublist(0, sorted.length - retain);
  }
}

/// Pure failure-banner logic (Requirement 13.4): a persistent, non-dismissible
/// banner is shown once there are at least 2 trailing consecutive failures with
/// no subsequent verified backup.
class BackupFailureBanner {
  BackupFailureBanner._();

  /// Consecutive failed attempts required before the banner is shown.
  static const int consecutiveFailureThreshold = 2;

  /// Whether the banner should be shown for the given count of trailing
  /// consecutive failures.
  static bool shouldShow(int consecutiveFailures) =>
      consecutiveFailures >= consecutiveFailureThreshold;

  /// Folds a chronological sequence of attempt outcomes (`true` = verified
  /// success, `false` = failure) into the trailing consecutive-failure count.
  /// A verified success resets the count to zero, which is what clears the
  /// banner (Requirement 13.4).
  static int trailingConsecutiveFailures(Iterable<bool> verifiedOutcomes) {
    var count = 0;
    for (final verified in verifiedOutcomes) {
      count = verified ? 0 : count + 1;
    }
    return count;
  }
}

/// A backup file on disk together with its integrity metadata.
class BackupRecord {
  /// Absolute path to the backup file.
  final String path;

  /// When the backup was created.
  final DateTime createdAt;

  /// SHA-256 (hex) checksum recorded for the backup.
  final String checksum;

  /// Whether the backup passed integrity verification (open + checksum).
  final bool verified;

  const BackupRecord({
    required this.path,
    required this.createdAt,
    required this.checksum,
    required this.verified,
  });
}

/// The outcome of a backup attempt (Requirements 13.2, 13.3, 13.4, 13.7).
sealed class BackupOutcome {
  const BackupOutcome();
}

/// No backup was due at the requested time (Requirement 13.2). Nothing changed.
class BackupNotDue extends BackupOutcome {
  const BackupNotDue();
}

/// The backup completed and passed integrity verification (open + checksum).
/// Older verified backups beyond the retention count were pruned.
class BackupSucceeded extends BackupOutcome {
  /// The verified backup that was created.
  final BackupRecord record;

  /// Paths of older verified backups pruned to honour retention.
  final List<String> prunedPaths;

  const BackupSucceeded({required this.record, required this.prunedPaths});
}

/// The backup attempt failed — either it could not be written, or it failed
/// integrity verification and was discarded (Requirement 13.7). Previously
/// verified backups are left untouched.
class BackupFailed extends BackupOutcome {
  /// Human-readable failure reason.
  final String reason;

  /// Number of consecutive failed attempts after this one.
  final int consecutiveFailures;

  /// Whether the persistent failure banner is now active (Requirement 13.4).
  final bool bannerActive;

  const BackupFailed({
    required this.reason,
    required this.consecutiveFailures,
    required this.bannerActive,
  });
}

/// Probes whether a written backup file "opens successfully" (Requirement 13.3).
/// Returns `true` only when the file exists and can be fully read. Injectable so
/// tests can supply a deterministic decision without touching the filesystem.
typedef BackupOpenProbe = Future<bool> Function(String path);

// ============================================================================
// RESTORE WIZARD TYPES (Task 14.3, Requirements 13.5, 13.8)
// ============================================================================

/// The result of integrity-verifying a backup selected for restore
/// (Requirements 13.5, 13.8). A backup is restorable only when it OPENS
/// successfully AND its computed checksum matches the checksum RECORDED for it
/// (the `.verified` sidecar) — the same open + checksum gate Task 14.2 uses to
/// mark a backup verified.
class RestoreIntegrity {
  /// Whether the selected backup passed the integrity gate.
  final bool verified;

  /// The recorded/confirmed checksum when [verified] is true, else `null`.
  final String? checksum;

  /// Why verification failed when [verified] is false, else `null`.
  final String? reason;

  const RestoreIntegrity._({
    required this.verified,
    this.checksum,
    this.reason,
  });

  /// A passing integrity result carrying the confirmed [checksum].
  const RestoreIntegrity.ok(String checksum)
    : this._(verified: true, checksum: checksum);

  /// A failing integrity result carrying a human-readable [reason].
  const RestoreIntegrity.failed(String reason)
    : this._(verified: false, reason: reason);
}

/// The outcome of a restore-wizard attempt (Requirements 13.5, 13.8).
sealed class RestoreOutcome {
  const RestoreOutcome();
}

/// The selected backup passed the integrity gate and the Local_Store was
/// replaced from it (Requirement 13.5).
class RestoreSucceeded extends RestoreOutcome {
  /// The backup file the Local_Store was restored from.
  final String backupPath;

  /// The verified checksum of the restored backup.
  final String checksum;

  const RestoreSucceeded({required this.backupPath, required this.checksum});
}

/// The restore was aborted; the existing Local_Store is preserved completely
/// unchanged and a clear reason is reported (Requirement 13.8).
class RestoreAborted extends RestoreOutcome {
  /// Stable machine-readable code for the abort cause.
  final String code;

  /// Human-readable reason the selected backup cannot be restored.
  final String reason;

  const RestoreAborted({required this.code, required this.reason});

  /// No backup was selected (empty/whitespace path).
  static const String codeNoBackupSelected = 'NO_BACKUP_SELECTED';

  /// The selected backup failed integrity verification (Requirement 13.8).
  static const String codeIntegrityFailed = 'BACKUP_INTEGRITY_FAILED';

  /// Integrity passed but replacing the live store failed; the existing store
  /// was restored from its pre-restore copy and left unchanged.
  static const String codeRestoreFailed = 'RESTORE_FAILED';
}

// ============================================================================
// BACKUP_SERVICE
// ============================================================================

/// Service-layer entry point for offline data protection (design "Backup_Service").
///
/// Owns the first-run writable-location prompt (Task 14.1, Requirements 13.1,
/// 13.6) via a composed [BackupLocationGate], scheduled verified backups with
/// retention plus the failure-banner state (Task 14.2, Requirements 13.2, 13.3,
/// 13.4, 13.7), and the restore wizard with its integrity gate (Task 14.3,
/// Requirements 13.5, 13.8).
class BackupService {
  static const String _logTag = 'BackupService';

  /// File name of the offline Local_Store (mirrors `connection_native.dart`
  /// and the Migration_Wizard).
  static const String _storeFileName = 'dukanx_enterprise.sqlite';

  /// Naming scheme for verified backup files and their verification sidecars.
  /// A backup is considered verified on disk iff its `.verified` sidecar (which
  /// holds the source checksum) exists alongside it — the sidecar is written
  /// only after verification passes.
  static const String _backupPrefix = 'dukanx_backup_';
  static const String _backupExt = '.sqlite';
  static const String _verifiedSuffix = '.verified';

  /// The first-run writable-location gate this service delegates to. Composed
  /// (not subclassed) so the gate's logic and tests are reused unchanged.
  final BackupLocationGate _locationGate;

  /// Local_Config accessor for the configured backup time + location. Shared
  /// with [_locationGate] so only one instance is ever created.
  final LocalConfig _config;

  /// Resolves the absolute path to the Local_Store file. Injectable for tests;
  /// defaults to the documents-directory path the database connection uses.
  final Future<String> Function() _storePathResolver;

  /// Clock seam so scheduling is deterministic under test.
  final DateTime Function() _clock;

  /// Open-check used during verification. Injectable for tests.
  final BackupOpenProbe _openProbe;

  /// Trailing count of consecutive failed backup attempts. Reset to zero only
  /// by a verified backup, which is what makes the banner non-dismissible
  /// (Requirement 13.4): there is no public method to clear it otherwise.
  int _consecutiveFailures = 0;

  /// The instant of the most recent backup attempt (success or failure), used
  /// to enforce "once per 24-hour period" scheduling (Requirement 13.2).
  DateTime? _lastBackupAttemptAt;

  /// Creates a [BackupService].
  ///
  /// In production all parameters are omitted and real collaborators are used.
  /// The seams exist so the service is testable without secure storage, a real
  /// clock, or the filesystem.
  factory BackupService({
    BackupLocationGate? locationGate,
    LocalConfig? config,
    BackupLocationProbe? writabilityProbe,
    Future<String> Function()? storePathResolver,
    DateTime Function()? clock,
    BackupOpenProbe? openProbe,
  }) {
    final resolvedConfig = config ?? LocalConfig();
    return BackupService._(
      config: resolvedConfig,
      locationGate:
          locationGate ??
          BackupLocationGate(
            config: resolvedConfig,
            writabilityProbe: writabilityProbe,
          ),
      storePathResolver: storePathResolver ?? _defaultStorePath,
      clock: clock ?? DateTime.now,
      openProbe: openProbe ?? _defaultOpenProbe,
    );
  }

  BackupService._({
    required LocalConfig config,
    required BackupLocationGate locationGate,
    required Future<String> Function() storePathResolver,
    required DateTime Function() clock,
    required BackupOpenProbe openProbe,
  }) : _config = config,
       _locationGate = locationGate,
       _storePathResolver = storePathResolver,
       _clock = clock,
       _openProbe = openProbe;

  static Future<String> _defaultStorePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _storeFileName);
  }

  // --------------------------------------------------------------------------
  // First-run writable-location prompt (Task 14.1, Requirements 13.1, 13.6)
  // --------------------------------------------------------------------------

  /// Whether first-run setup is still required because no backup location has
  /// been configured yet. While this is `true`, use of DukanX must remain
  /// blocked until a writable location is selected (Requirement 13.1).
  Future<bool> isFirstRunSetupRequired() => _locationGate.isSetupRequired();

  /// The currently configured backup-directory path, or `null` when none has
  /// been accepted yet.
  Future<String?> backupLocation() => _locationGate.configuredLocation();

  /// Returns `true` iff [path] is a non-empty location that can actually be
  /// written to (verified by a real create+delete write probe, not a flag).
  Future<bool> isLocationWritable(String path) =>
      _locationGate.isWritable(path);

  /// Validates [path] and, only when it is writable, persists it as the backup
  /// location ([BackupLocationAccepted]); a non-writable or empty selection
  /// persists nothing and returns [BackupLocationRejected], so a writable
  /// location continues to be required (Requirements 13.1, 13.6).
  Future<BackupLocationOutcome> selectBackupLocation(String path) =>
      _locationGate.selectLocation(path);

  // ==========================================================================
  // Scheduled verified backups, retention & failure banner
  // (Task 14.2, Requirements 13.2, 13.3, 13.4, 13.7)
  // ==========================================================================

  /// Whether the persistent, non-dismissible failure banner is currently active
  /// because at least 2 consecutive backup attempts have failed with no
  /// subsequent verified backup (Requirement 13.4). The UI reads this flag; it
  /// is cleared only by a verified backup, never by a dismiss action.
  bool get isFailureBannerActive =>
      BackupFailureBanner.shouldShow(_consecutiveFailures);

  /// The current count of trailing consecutive backup failures.
  int get consecutiveFailureCount => _consecutiveFailures;

  /// The instant of the most recent backup attempt, or `null` if none has run
  /// in this session.
  DateTime? get lastBackupAttemptAt => _lastBackupAttemptAt;

  /// Whether a scheduled backup is due now, based on the Local_Config backup
  /// time and the last attempt (Requirement 13.2).
  Future<bool> isScheduledBackupDue({DateTime? now}) async {
    final at = now ?? _clock();
    final minutes =
        BackupSchedule.parseTimeOfDayMinutes(await _config.getBackupTime()) ??
        BackupSchedule.defaultBackupMinutes;
    return BackupSchedule.isBackupDue(
      now: at,
      lastBackupAt: _lastBackupAttemptAt,
      scheduledMinutes: minutes,
    );
  }

  /// Runs the daily backup only when it is due (Requirement 13.2). Returns
  /// [BackupNotDue] when nothing was scheduled, otherwise the [performBackup]
  /// outcome.
  Future<BackupOutcome> runScheduledBackupIfDue({DateTime? now}) async {
    final at = now ?? _clock();
    if (!await isScheduledBackupDue(now: at)) {
      return const BackupNotDue();
    }
    return performBackup(now: at);
  }

  /// Performs a backup of the Local_Store now: copies it to the configured
  /// location, then verifies the copy by OPENING it AND matching its CHECKSUM
  /// against the source. The backup is "verified" only when BOTH checks pass
  /// (Requirements 13.2, 13.3).
  ///
  /// On success: the consecutive-failure count resets (clearing the banner),
  /// the verified sidecar is written, and older verified backups beyond the
  /// retention count are pruned (Requirements 13.3, 13.7).
  ///
  /// On failure (write error or failed verification): the failed/partial backup
  /// is discarded, previously verified backups are left untouched, and the
  /// attempt counts as a failure that may raise the banner (Requirements 13.4,
  /// 13.7).
  Future<BackupOutcome> performBackup({DateTime? now}) async {
    final at = now ?? _clock();
    // Every entry counts as an attempt for "once per 24h period" scheduling.
    _lastBackupAttemptAt = at;

    final location = await _config.getBackupLocation();
    if (location == null || location.isEmpty) {
      return _recordFailure('No writable backup location is configured.');
    }

    String? backupPath;
    try {
      final storePath = await _storePathResolver();
      final storeFile = File(storePath);
      if (!storeFile.existsSync()) {
        return _recordFailure('The Local_Store file does not exist.');
      }

      final sourceBytes = await storeFile.readAsBytes();
      final sourceChecksum = sha256.convert(sourceBytes).toString();

      final dir = Directory(location);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      backupPath = p.join(
        location,
        '$_backupPrefix${at.millisecondsSinceEpoch}$_backupExt',
      );
      final backupFile = File(backupPath);
      await backupFile.writeAsBytes(sourceBytes, flush: true);

      // Verify: the backup must OPEN successfully AND its CHECKSUM must match
      // the source. Only then is it "verified" (Requirement 13.3).
      final opened = await _safeOpen(backupPath);
      final backupBytes = backupFile.existsSync()
          ? await backupFile.readAsBytes()
          : Uint8List(0);
      final backupChecksum = sha256.convert(backupBytes).toString();
      final checksumMatches = _equalsIgnoreCase(backupChecksum, sourceChecksum);
      final verified = opened && checksumMatches;

      if (!verified) {
        // Discard the failed backup; leave prior verified backups intact
        // (Requirement 13.7).
        await _deleteQuietly(backupFile);
        await _deleteQuietly(File('$backupPath$_verifiedSuffix'));
        return _recordFailure(
          'Backup failed integrity verification '
          '(opened=$opened, checksumMatched=$checksumMatches).',
        );
      }

      // Mark verified by writing the checksum sidecar.
      await File(
        '$backupPath$_verifiedSuffix',
      ).writeAsString(sourceChecksum, flush: true);

      // A verified backup clears the failure state / banner (Requirement 13.4).
      _consecutiveFailures = 0;

      // Retain >= 7 most recent verified backups; prune older (Req 13.3/13.7).
      final prunedPaths = await _pruneOldVerifiedBackups();

      LoggerService.i(
        _logTag,
        'Backup verified and stored; pruned ${prunedPaths.length} old backup(s).',
      );
      return BackupSucceeded(
        record: BackupRecord(
          path: backupPath,
          createdAt: at,
          checksum: sourceChecksum,
          verified: true,
        ),
        prunedPaths: prunedPaths,
      );
    } catch (e) {
      // Best-effort discard of any partial file before recording the failure.
      if (backupPath != null) {
        await _deleteQuietly(File(backupPath));
        await _deleteQuietly(File('$backupPath$_verifiedSuffix'));
      }
      LoggerService.e(_logTag, 'Backup attempt failed.', e);
      return _recordFailure('Backup attempt failed: $e');
    }
  }

  /// Returns the verified backups currently present at the configured location,
  /// sorted oldest-first. A backup is verified iff its `.verified` checksum
  /// sidecar exists alongside it.
  Future<List<BackupRecord>> listVerifiedBackups() async {
    final location = await _config.getBackupLocation();
    if (location == null || location.isEmpty) return const <BackupRecord>[];

    final dir = Directory(location);
    if (!dir.existsSync()) return const <BackupRecord>[];

    final records = <BackupRecord>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(_backupPrefix) || !name.endsWith(_backupExt)) {
        continue;
      }
      final sidecar = File('${entity.path}$_verifiedSuffix');
      if (!sidecar.existsSync()) continue; // only verified backups count

      final createdAt = _parseTimestamp(name);
      if (createdAt == null) continue;

      String checksum = '';
      try {
        checksum = (await sidecar.readAsString()).trim();
      } catch (_) {
        // A sidecar we cannot read is treated as no checksum, but the backup
        // is still a verified file on disk.
      }
      records.add(
        BackupRecord(
          path: entity.path,
          createdAt: createdAt,
          checksum: checksum,
          verified: true,
        ),
      );
    }
    records.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return records;
  }

  // ==========================================================================
  // Restore wizard with an integrity gate
  // (Task 14.3, Requirements 13.5, 13.8)
  // ==========================================================================

  /// Step 1 of the restore wizard — let the user pick from the backups that can
  /// be offered for restore (Requirement 13.5). These are the verified backups
  /// at the configured location, surfaced newest-first so the most recent
  /// recovery point is the obvious choice. The user may also point the wizard at
  /// an arbitrary backup file with [prepareRestoreCandidate].
  Future<List<BackupRecord>> listRestorableBackups() async {
    final verified = await listVerifiedBackups();
    verified.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first
    return verified;
  }

  /// Step 1b of the restore wizard — accept an ARBITRARY backup file/path the
  /// user selected (Requirement 13.5), resolving it to a [BackupRecord] without
  /// yet restoring anything. The recorded checksum is read from the backup's
  /// `.verified` sidecar when present (the same convention Task 14.2 writes);
  /// when there is no sidecar the record carries an empty checksum and
  /// `verified = false`, and [verifyBackupForRestore] will then abort the
  /// restore at the integrity gate (Requirement 13.8). Returns `null` when
  /// [backupPath] is empty or the file does not exist.
  Future<BackupRecord?> prepareRestoreCandidate(String backupPath) async {
    final trimmed = backupPath.trim();
    if (trimmed.isEmpty) return null;

    final file = File(trimmed);
    if (!file.existsSync()) return null;

    final sidecar = File('$trimmed$_verifiedSuffix');
    final hasSidecar = sidecar.existsSync();
    String recordedChecksum = '';
    if (hasSidecar) {
      try {
        recordedChecksum = (await sidecar.readAsString()).trim();
      } catch (_) {
        // An unreadable sidecar is treated as no recorded checksum; the
        // integrity gate will abort rather than guess.
      }
    }

    final createdAt =
        _parseTimestamp(p.basename(trimmed)) ?? (file.statSync().modified);

    return BackupRecord(
      path: trimmed,
      createdAt: createdAt,
      checksum: recordedChecksum,
      verified: hasSidecar && recordedChecksum.isNotEmpty,
    );
  }

  /// Step 2 of the restore wizard — the INTEGRITY GATE (Requirements 13.5,
  /// 13.8). The selected backup is restorable only when BOTH:
  ///
  ///   1. it OPENS successfully (the same open-probe Task 14.2 uses), AND
  ///   2. its computed SHA-256 checksum MATCHES the checksum RECORDED for it
  ///      (its `.verified` sidecar).
  ///
  /// This is the same open + checksum verification that marks a backup verified
  /// at creation time, applied now to the restore source. Any missing file,
  /// missing/empty recorded checksum, failed open, or checksum mismatch yields a
  /// failing result with a clear reason — the caller MUST NOT touch the live
  /// store in that case.
  Future<RestoreIntegrity> verifyBackupForRestore(String backupPath) async {
    final trimmed = backupPath.trim();
    if (trimmed.isEmpty) {
      return const RestoreIntegrity.failed('No backup was selected.');
    }

    final file = File(trimmed);
    if (!file.existsSync()) {
      return const RestoreIntegrity.failed(
        'The selected backup file does not exist.',
      );
    }

    // The recorded checksum lives in the `.verified` sidecar written when the
    // backup was created and verified. Without it there is nothing to match the
    // backup against, so the restore cannot be trusted.
    final sidecar = File('$trimmed$_verifiedSuffix');
    if (!sidecar.existsSync()) {
      return const RestoreIntegrity.failed(
        'The selected backup has no recorded checksum and cannot be verified.',
      );
    }
    String recordedChecksum;
    try {
      recordedChecksum = (await sidecar.readAsString()).trim();
    } catch (_) {
      return const RestoreIntegrity.failed(
        'The recorded checksum for the selected backup could not be read.',
      );
    }
    if (recordedChecksum.isEmpty) {
      return const RestoreIntegrity.failed(
        'The recorded checksum for the selected backup is empty.',
      );
    }

    // (1) Must open successfully.
    final opened = await _safeOpen(trimmed);
    if (!opened) {
      return const RestoreIntegrity.failed(
        'The selected backup could not be opened.',
      );
    }

    // (2) Computed checksum must match the recorded checksum.
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return const RestoreIntegrity.failed(
        'The selected backup could not be read for verification.',
      );
    }
    final computed = sha256.convert(bytes).toString();
    if (!_equalsIgnoreCase(computed, recordedChecksum)) {
      return const RestoreIntegrity.failed(
        'The selected backup failed integrity verification '
        '(checksum mismatch).',
      );
    }

    return RestoreIntegrity.ok(recordedChecksum);
  }

  /// Step 3 of the restore wizard — restore the Local_Store from the selected
  /// [backupPath], gated on integrity (Requirements 13.5, 13.8).
  ///
  /// The selected backup is integrity-verified FIRST. Only when it verifies is
  /// the live Local_Store replaced from it; the replacement is ATOMIC (stage →
  /// re-verify the staged bytes → back up the existing store → replace →
  /// restore-on-failure), mirroring the Migration_Wizard's import so the live
  /// store is never left half-overwritten or corrupted ([RestoreSucceeded]).
  ///
  /// If integrity does NOT verify, the restore is ABORTED, the existing live
  /// store is preserved COMPLETELY UNCHANGED, and a clear reason is reported
  /// ([RestoreAborted], code [RestoreAborted.codeIntegrityFailed]) —
  /// Requirement 13.8.
  Future<RestoreOutcome> restoreFromBackup(String backupPath) async {
    final trimmed = backupPath.trim();
    if (trimmed.isEmpty) {
      return const RestoreAborted(
        code: RestoreAborted.codeNoBackupSelected,
        reason: 'No backup was selected to restore.',
      );
    }

    // INTEGRITY GATE — verify BEFORE touching the live store (Req 13.5/13.8).
    final integrity = await verifyBackupForRestore(trimmed);
    if (!integrity.verified) {
      LoggerService.w(
        _logTag,
        'Restore aborted; live store preserved unchanged: ${integrity.reason}',
      );
      return RestoreAborted(
        code: RestoreAborted.codeIntegrityFailed,
        reason:
            integrity.reason ??
            'The selected backup failed integrity verification.',
      );
    }

    // Integrity passed — replace the live store atomically (Req 13.5).
    try {
      await _replaceLiveStoreAtomically(trimmed, integrity.checksum!);
      LoggerService.i(_logTag, 'Local_Store restored from a verified backup.');
      return RestoreSucceeded(
        backupPath: trimmed,
        checksum: integrity.checksum!,
      );
    } catch (e) {
      // The atomic replace restores the original on any failure, so the live
      // store is unchanged here too (Req 13.8).
      LoggerService.e(
        _logTag,
        'Restore failed during replace; live store preserved.',
        e,
      );
      return const RestoreAborted(
        code: RestoreAborted.codeRestoreFailed,
        reason:
            'The backup verified but the Local_Store could not be replaced; '
            'the existing store was preserved unchanged.',
      );
    }
  }

  /// Replaces the live Local_Store with the verified backup at [backupPath]
  /// atomically (Requirement 13.5). Mirrors the Migration_Wizard import: the
  /// backup bytes are staged to a temp file and RE-VERIFIED against
  /// [expectedChecksum], the existing store is backed up, and only then is it
  /// overwritten. On ANY failure the existing store is restored from its backup
  /// copy, so the live store is never left half-overwritten (Requirement 13.8).
  Future<void> _replaceLiveStoreAtomically(
    String backupPath,
    String expectedChecksum,
  ) async {
    final storePath = await _storePathResolver();
    final live = File(storePath);
    final tmp = File('$storePath.restore.tmp');
    final preRestore = File('$storePath.pre-restore.bak');

    // Stage the backup bytes and RE-VERIFY them before replacing anything.
    final backupBytes = await File(backupPath).readAsBytes();
    await tmp.writeAsBytes(backupBytes, flush: true);
    final staged = sha256.convert(await tmp.readAsBytes()).toString();
    if (!_equalsIgnoreCase(staged, expectedChecksum)) {
      await _deleteQuietly(tmp);
      throw const FileSystemException(
        'Staged restore data is corrupt (checksum mismatch).',
      );
    }

    // Back up the existing store so it can be restored on failure.
    final hadLive = live.existsSync();
    if (hadLive) {
      await live.copy(preRestore.path);
    }

    try {
      await tmp.copy(storePath); // overwrite-safe on every platform
    } catch (_) {
      // Restore the original so the live store is left completely unchanged.
      if (hadLive && preRestore.existsSync()) {
        await preRestore.copy(storePath);
      }
      await _deleteQuietly(tmp);
      await _deleteQuietly(preRestore);
      rethrow;
    }

    await _deleteQuietly(tmp);
    await _deleteQuietly(preRestore);
  }

  // --------------------------------------------------------------------------
  // Internal helpers (Task 14.2)
  // --------------------------------------------------------------------------

  /// Records a failed attempt: increments the consecutive-failure count and
  /// reports whether the banner is now active (Requirement 13.4).
  BackupFailed _recordFailure(String reason) {
    _consecutiveFailures += 1;
    LoggerService.w(
      _logTag,
      'Backup failed (consecutive=$_consecutiveFailures): $reason',
    );
    return BackupFailed(
      reason: reason,
      consecutiveFailures: _consecutiveFailures,
      bannerActive: BackupFailureBanner.shouldShow(_consecutiveFailures),
    );
  }

  /// Prunes verified backups older than the [BackupRetentionPolicy] window,
  /// deleting both the backup file and its verification sidecar. Returns the
  /// pruned backup paths.
  Future<List<String>> _pruneOldVerifiedBackups() async {
    final verified = await listVerifiedBackups();
    final toPrune = BackupRetentionPolicy.selectForPruning(verified);
    final pruned = <String>[];
    for (final record in toPrune) {
      await _deleteQuietly(File(record.path));
      await _deleteQuietly(File('${record.path}$_verifiedSuffix'));
      pruned.add(record.path);
    }
    return pruned;
  }

  /// Runs the open-probe, treating any thrown error as "did not open".
  Future<bool> _safeOpen(String path) async {
    try {
      return await _openProbe(path);
    } catch (e) {
      LoggerService.w(_logTag, 'Backup open-probe failed: $e');
      return false;
    }
  }

  /// Parses the creation instant encoded in a backup file name
  /// (`dukanx_backup_<utcMillis>.sqlite`).
  DateTime? _parseTimestamp(String fileName) {
    if (fileName.length <= _backupPrefix.length + _backupExt.length) {
      return null;
    }
    final core = fileName.substring(
      _backupPrefix.length,
      fileName.length - _backupExt.length,
    );
    final millis = int.tryParse(core);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static bool _equalsIgnoreCase(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();

  Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // Cleanup is best-effort.
    }
  }

  /// Real open-check: the backup file must exist, be non-empty, and be fully
  /// readable (mirrors "opens successfully" for a byte-for-byte store copy).
  static Future<bool> _defaultOpenProbe(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      if (await file.length() <= 0) return false;
      await file.readAsBytes();
      return true;
    } catch (_) {
      return false;
    }
  }
}
