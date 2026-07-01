// Clothing Sync Indicator Widget
// Shows a visible "unsynced changes exist" indication when pending or
// permanently-failed sync entries exist in the clothing sync queue.
//
// On reconnect, triggers ClothingRepositoryOffline.syncAll() to drain the
// queue FIFO with the retry cap (max 5 retries per entry).
//
// Requirements validated: 12.3, 12.4

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../data/repositories/clothing_repository_offline.dart';

/// A compact widget that indicates unsynced clothing changes.
///
/// Shows:
/// - An orange chip/badge when pending sync entries exist ("N pending sync").
/// - A red chip/badge when permanently-failed entries exist ("Sync failed").
/// - Nothing when all data is synced.
///
/// Tapping the indicator triggers a manual sync attempt.
///
/// Also listens for connectivity changes: when the device regains connectivity,
/// it automatically calls [ClothingRepositoryOffline.syncAll] to drain the
/// queue FIFO (Requirement 12.3).
class ClothingSyncIndicator extends StatefulWidget {
  /// The offline repository to query sync status from.
  final ClothingRepositoryOffline repository;

  /// How frequently to poll the sync queue status (default: 10 seconds).
  final Duration pollInterval;

  const ClothingSyncIndicator({
    super.key,
    required this.repository,
    this.pollInterval = const Duration(seconds: 10),
  });

  @override
  State<ClothingSyncIndicator> createState() => _ClothingSyncIndicatorState();
}

class _ClothingSyncIndicatorState extends State<ClothingSyncIndicator> {
  int _pendingCount = 0;
  bool _hasFailed = false;
  bool _isSyncing = false;
  Timer? _pollTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _startPolling();
    _listenConnectivity();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => _refreshStatus());
  }

  void _listenConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline = !results.contains(ConnectivityResult.none);
    if (isOnline && (_pendingCount > 0 || _hasFailed)) {
      // Device regained connectivity — trigger FIFO drain (Req 12.3)
      _triggerSync();
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final pending = await widget.repository.getPendingSyncCount();
      final hasFailed = await widget.repository.hasFailedSyncEntries();

      if (mounted) {
        setState(() {
          _pendingCount = pending;
          _hasFailed = hasFailed;
        });
      }
    } catch (_) {
      // Silently ignore — the repository may not be initialized yet.
    }
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      await widget.repository.syncAll();
    } catch (_) {
      // syncAll handles per-entry errors internally
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        _refreshStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to show when everything is synced
    if (_pendingCount == 0 && !_hasFailed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    // Determine color and message based on state
    final Color chipColor;
    final IconData chipIcon;
    final String chipLabel;

    if (_hasFailed) {
      chipColor = theme.colorScheme.error;
      chipIcon = Icons.sync_problem;
      chipLabel = 'Sync failed — tap to retry';
    } else {
      chipColor = theme.colorScheme.tertiary;
      chipIcon = Icons.sync;
      chipLabel =
          '$_pendingCount change${_pendingCount == 1 ? '' : 's'} pending sync';
    }

    return Semantics(
      label: chipLabel,
      button: true,
      child: Tooltip(
        message: _hasFailed
            ? 'Some changes could not be synced after multiple attempts. Tap to retry.'
            : 'Unsynced changes exist. Tap to sync now.',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isSyncing ? null : _triggerSync,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: chipColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSyncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: chipColor,
                    ),
                  )
                else
                  Icon(chipIcon, size: 14, color: chipColor),
                const SizedBox(width: 6),
                Text(
                  _isSyncing ? 'Syncing...' : chipLabel,
                  style: TextStyle(
                    color: chipColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
