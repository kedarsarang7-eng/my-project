// ============================================================================
// OFFLINE SYNC STATUS WIDGET - PRODUCTION READY
// ============================================================================
// Displays real-time sync status to users
// Shows pending items, sync progress, and errors
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../sync/engine/sync_engine.dart';
import '../sync/models/sync_types.dart';

// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.

/// Sync Status Widget - Shows current sync state (New Engine)
class SyncStatusWidget extends StatefulWidget {
  final bool compact;
  final VoidCallback? onTap;

  const SyncStatusWidget({super.key, this.compact = false, this.onTap});

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription<SyncStats>? _syncSubscription;
  SyncStats? _stats;
  final bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _initializeListeners();
  }

  void _initializeListeners() {
    try {
      final engine = SyncEngine.instance;
      _syncSubscription = engine.statsStream.listen((stats) {
        if (mounted) {
          setState(() => _stats = stats);
        }
      });
      // Initial trigger? The engine emits on listen?
      // broadcast stream might not.
      // But Engine emits on start.
    } catch (_) {
      // Engine not initialized
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactView();
    }
    return _buildFullView();
  }

  Widget _buildCompactView() {
    final pendingCount = _stats?.pendingCount ?? 0;
    // Healthy if no failures/dead letters
    final isHealthy =
        (_stats?.failedCount ?? 0) == 0 && (_stats?.deadLetterCount ?? 0) == 0;

    if (pendingCount == 0 && isHealthy) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap ?? () => _showSyncDetails(context),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pendingCount > 0
                  ? Colors.orange.withOpacity(
                      0.1 + _pulseController.value * 0.1,
                    )
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pendingCount > 0 ? Icons.cloud_sync : Icons.cloud_off,
                  size: 16,
                  color: pendingCount > 0 ? Colors.orange : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  pendingCount > 0 ? '$pendingCount pending' : 'Sync error',
                  style: TextStyle(
                    fontSize: 12,
                    color: pendingCount > 0 ? Colors.orange : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _getStatusSubtitle(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_stats?.pendingCount != null && _stats!.pendingCount > 0)
                  TextButton(
                    onPressed: _triggerSync,
                    child: const Text('Sync Now'),
                  ),
              ],
            ),
            if (_stats != null &&
                (_stats!.failedCount > 0 || _stats!.deadLetterCount > 0))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildHealthWarning(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    final pendingCount = _stats?.pendingCount ?? 0;
    final isHealthy = (_stats?.failedCount ?? 0) == 0;

    if (!_isOnline) {
      return const Icon(Icons.cloud_off, color: Colors.grey, size: 32);
    }

    if (pendingCount == 0 && isHealthy) {
      return const Icon(Icons.cloud_done, color: Colors.green, size: 32);
    }

    if (pendingCount > 0) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Icon(
            Icons.cloud_sync,
            color: Colors.orange.withOpacity(
              0.5 + _pulseController.value * 0.5,
            ),
            size: 32,
          );
        },
      );
    }

    return const Icon(Icons.cloud_off, color: Colors.red, size: 32);
  }

  String _getStatusTitle() {
    if (!_isOnline) return 'Offline';
    if (_stats == null) return 'Checking sync...';

    final pendingCount = _stats!.pendingCount;
    final isHealthy =
        (_stats!.failedCount == 0 && _stats!.deadLetterCount == 0);

    if (pendingCount == 0 && isHealthy) return 'All synced';
    if (pendingCount > 0) return '$pendingCount items pending';
    return 'Sync issues';
  }

  String _getStatusSubtitle() {
    if (!_isOnline) return 'Changes saved locally';
    if (_stats == null) return 'Initializing...';

    if (_stats!.lastSyncTime != null) {
      final diff = DateTime.now().difference(_stats!.lastSyncTime!);
      if (diff.inMinutes < 1) return 'Last sync: Just now';
      if (diff.inMinutes < 60) return 'Last sync: ${diff.inMinutes} min ago';
      return 'Last sync: ${diff.inHours}h ago';
    }

    return 'Tap to sync now';
  }

  Widget _buildHealthWarning() {
    final issues = <String>[];
    if (_stats!.failedCount > 0) {
      issues.add('${_stats!.failedCount} failed');
    }
    if (_stats!.deadLetterCount > 0) {
      issues.add('${_stats!.deadLetterCount} need attention');
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red.shade400, size: 20),
          const SizedBox(width: 8),
          Text(
            issues.join(' • '),
            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showSyncDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SyncDetailsSheet(stats: _stats),
    );
  }

  Future<void> _triggerSync() async {
    try {
      await SyncEngine.instance.triggerSync();
    } catch (_) {}
  }
}

/// Sync Details Bottom Sheet
class SyncDetailsSheet extends StatelessWidget {
  final SyncStats? stats;

  const SyncDetailsSheet({super.key, this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sync Status',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            'Pending',
            '${stats?.pendingCount ?? 0}',
            Icons.schedule,
          ),
          _buildMetricRow(
            'In Progress',
            '${stats?.inProgressCount ?? 0}',
            Icons.sync,
          ),
          _buildMetricRow(
            'Failed',
            '${stats?.failedCount ?? 0}',
            Icons.error_outline,
          ),
          _buildMetricRow(
            'Dead Letter',
            '${stats?.deadLetterCount ?? 0}',
            Icons.dangerous,
          ),
          const SizedBox(height: 16),
          if (stats?.isCircuitOpen == true)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Circuit Breaker Open (Cooling down)",
                style: TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                SyncEngine.instance.triggerSync();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Offline Banner - Shows when device is offline
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            'Offline - Changes saved locally',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pending Changes Indicator
class PendingChangesIndicator extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const PendingChangesIndicator({super.key, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 14,
              color: Colors.blue.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              '$count pending',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
