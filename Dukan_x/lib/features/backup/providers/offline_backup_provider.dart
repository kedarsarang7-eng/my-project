import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/offline_backup_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class OfflineBackupState {
  final List<BackupEntry> backups;
  final BackupStatus status;
  final double progress;
  final String? lastError;
  final BackupScheduleFrequency scheduleFreq;
  final DateTime? lastBackup;
  final DateTime? nextScheduledBackup;
  final String? savedExternalDir;

  const OfflineBackupState({
    this.backups = const [],
    this.status = BackupStatus.idle,
    this.progress = 0,
    this.lastError,
    this.scheduleFreq = BackupScheduleFrequency.daily,
    this.lastBackup,
    this.nextScheduledBackup,
    this.savedExternalDir,
  });

  OfflineBackupState copyWith({
    List<BackupEntry>? backups,
    BackupStatus? status,
    double? progress,
    String? lastError,
    BackupScheduleFrequency? scheduleFreq,
    DateTime? lastBackup,
    DateTime? nextScheduledBackup,
    String? savedExternalDir,
    bool clearError = false,
  }) => OfflineBackupState(
    backups: backups ?? this.backups,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    lastError: clearError ? null : (lastError ?? this.lastError),
    scheduleFreq: scheduleFreq ?? this.scheduleFreq,
    lastBackup: lastBackup ?? this.lastBackup,
    nextScheduledBackup: nextScheduledBackup ?? this.nextScheduledBackup,
    savedExternalDir: savedExternalDir ?? this.savedExternalDir,
  );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class OfflineBackupNotifier extends StateNotifier<OfflineBackupState> {
  OfflineBackupNotifier() : super(const OfflineBackupState()) {
    _load();
  }

  final _svc = OfflineBackupService();

  Future<void> _load() async {
    final backups = await _svc.listBackups();
    final freq = await _svc.getScheduleFrequency();
    final last = await _svc.getLastBackupTime();
    final next = await _svc.getNextScheduledBackupTime();
    final extDir = await _svc.getSavedExternalDir();
    state = state.copyWith(
      backups: backups,
      scheduleFreq: freq,
      lastBackup: last,
      nextScheduledBackup: next,
      savedExternalDir: extDir,
    );
  }

  Future<BackupResult> createBackup({String? exportToFolder}) async {
    state = state.copyWith(
      status: BackupStatus.running,
      progress: 0.0,
      clearError: true,
    );
    final result = await _svc.createBackup(
      trigger: BackupScheduleFrequency.manual,
      exportToFolder: exportToFolder,
      onProgress: (p) {
        if (mounted) state = state.copyWith(progress: p);
      },
    );
    if (result.success) {
      final backups = await _svc.listBackups();
      final next = await _svc.getNextScheduledBackupTime();
      final last = await _svc.getLastBackupTime();
      state = state.copyWith(
        status: BackupStatus.success,
        progress: 1.0,
        backups: backups,
        lastBackup: last,
        nextScheduledBackup: next,
      );
    } else {
      state = state.copyWith(
        status: BackupStatus.failed,
        lastError: result.error,
      );
    }
    return result;
  }

  Future<BackupResult> exportToExternalDrive({BackupEntry? entry}) async {
    state = state.copyWith(
      status: BackupStatus.running,
      progress: 0.0,
      clearError: true,
    );
    final result = await _svc.exportToExternalDrive(
      entry: entry,
      onProgress: (p) {
        if (mounted) state = state.copyWith(progress: p);
      },
    );
    if (result.success) {
      final backups = await _svc.listBackups();
      final extDir = await _svc.getSavedExternalDir();
      final last = await _svc.getLastBackupTime();
      final next = await _svc.getNextScheduledBackupTime();
      state = state.copyWith(
        status: BackupStatus.success,
        progress: 1.0,
        backups: backups,
        savedExternalDir: extDir,
        lastBackup: last,
        nextScheduledBackup: next,
      );
    } else {
      state = state.copyWith(
        status: result.error == 'No folder selected'
            ? BackupStatus.idle
            : BackupStatus.failed,
        lastError: result.error == 'No folder selected' ? null : result.error,
      );
    }
    return result;
  }

  Future<RestoreResult> restoreFromBackup(String path) async {
    state = state.copyWith(
      status: BackupStatus.running,
      progress: 0.0,
      clearError: true,
    );
    final result = await _svc.restoreFromBackup(
      path,
      onProgress: (p) {
        if (mounted) state = state.copyWith(progress: p);
      },
    );
    state = state.copyWith(
      status: result.success ? BackupStatus.success : BackupStatus.failed,
      progress: result.success ? 1.0 : 0,
      lastError: result.error,
    );
    return result;
  }

  Future<String?> pickBackupFile() => _svc.pickBackupFile();

  Future<void> deleteBackup(BackupEntry entry) async {
    await _svc.deleteBackup(entry);
    final backups = await _svc.listBackups();
    state = state.copyWith(backups: backups);
  }

  Future<bool> verifyBackup(BackupEntry entry) => _svc.verifyChecksum(entry);

  Future<void> setScheduleFreq(BackupScheduleFrequency freq) async {
    await _svc.setScheduleFrequency(freq);
    final next = await _svc.getNextScheduledBackupTime();
    state = state.copyWith(scheduleFreq: freq, nextScheduledBackup: next);
  }

  Future<void> clearExternalDir() async {
    await _svc.setSavedExternalDir(null);
    state = state.copyWith(savedExternalDir: null);
  }

  void resetStatus() {
    state = state.copyWith(
      status: BackupStatus.idle,
      progress: 0,
      clearError: true,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final offlineBackupProvider =
    StateNotifierProvider<OfflineBackupNotifier, OfflineBackupState>(
      (_) => OfflineBackupNotifier(),
    );
