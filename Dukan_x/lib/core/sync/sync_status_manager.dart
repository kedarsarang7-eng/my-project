import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_manager.dart';

// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.

enum SyncStatusState {
  synced, // All good, data safe (Green)
  syncing, // Uploading/Downloading (Yellow)
  pending, // Offline with pending changes (Red)
  failed, // Error/Conflict needs attention (Red)
}

/// Manages the source of truth for "Is my data safe?"
/// Persists critical sync stats to survive app restarts.
class SyncStatusManager {
  static SyncStatusManager? _instance;
  static SyncStatusManager get instance => _instance ??= SyncStatusManager._();

  SyncStatusManager._();

  // Storage keys
  static const String _keyPendingCount = 'sync_pending_count';
  static const String _keyLastBackup = 'sync_last_backup_time';
  static const String _keyLastError = 'sync_last_error';

  late SharedPreferences _prefs;
  final _statusController = StreamController<SyncStatusState>.broadcast();

  // Cache
  int _pendingCount = 0;
  DateTime? _lastBackupTime;
  String? _lastError;
  bool _isInit = false;

  Stream<SyncStatusState> get statusStream => _statusController.stream;

  // Public Getters
  int get pendingWritesCount => _pendingCount;
  DateTime? get lastSuccessfulBackupTime => _lastBackupTime;
  String? get lastError => _lastError;
  bool get isDataSafe => _pendingCount == 0 && _lastError == null;

  Future<void> initialize() async {
    if (_isInit) return;

    _prefs = await SharedPreferences.getInstance();

    // Load persisted state
    _pendingCount = _prefs.getInt(_keyPendingCount) ?? 0;
    final lastBackupMillis = _prefs.getInt(_keyLastBackup);
    _lastBackupTime = lastBackupMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(lastBackupMillis)
        : null;
    _lastError = _prefs.getString(_keyLastError);

    debugPrint(
      'SyncStatusManager: Init - Pending: $_pendingCount, LastBackup: $_lastBackupTime',
    );
    _isInit = true;
    _emitStatus();

    // Listen to SyncManager metrics if available
    SyncManager.instance.syncStatusStream.listen(_onSyncMetricsUpdate);
  }

  /// Called by SyncManager when metrics change
  void _onSyncMetricsUpdate(SyncHealthMetrics metrics) {
    bool stateChanged = false;

    // specific logic for safety
    if (_pendingCount != metrics.pendingCount) {
      _pendingCount = metrics.pendingCount;
      _prefs.setInt(_keyPendingCount, _pendingCount);
      stateChanged = true;
    }

    if (metrics.lastSyncAt != null && metrics.lastSyncAt != _lastBackupTime) {
      _lastBackupTime = metrics.lastSyncAt;
      _prefs.setInt(_keyLastBackup, _lastBackupTime!.millisecondsSinceEpoch);
      stateChanged = true;
    }

    if (metrics.lastError != _lastError) {
      _lastError = metrics.lastError;
      if (_lastError != null) {
        _prefs.setString(_keyLastError, _lastError!);
      } else {
        _prefs.remove(_keyLastError);
      }
      stateChanged = true;
    }

    if (stateChanged || metrics.inProgressCount > 0) {
      _emitStatus(metrics);
    }
  }

  void _emitStatus([SyncHealthMetrics? metrics]) {
    SyncStatusState state;

    if (metrics != null && metrics.inProgressCount > 0) {
      state = SyncStatusState.syncing;
    } else if (_lastError != null && _pendingCount > 0) {
      state = SyncStatusState.failed;
    } else if (_pendingCount > 0) {
      state = SyncStatusState.pending;
    } else {
      state = SyncStatusState.synced;
    }

    _statusController.add(state);
  }

  /// STRICT CHECK: Can the user safe-logout?
  bool canSafeLogout() {
    return _pendingCount == 0; // Only safe if NO pending writes
  }

  /// Clear data on logout (if forced)
  Future<void> clear() async {
    await _prefs.clear();
    _pendingCount = 0;
    _lastBackupTime = null;
    _lastError = null;
  }
}
