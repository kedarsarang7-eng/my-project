// ============================================================================
// OFFLINE MODE INDICATOR WIDGET
// ============================================================================
// Shows connection status and pending sync count to users
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../sync/sync_manager.dart';

// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.

/// Offline mode indicator that shows connectivity status and pending items
class OfflineModeIndicator extends StatefulWidget {
  final Widget child;
  final bool showBanner;
  final bool showFloatingBadge;

  const OfflineModeIndicator({
    super.key,
    required this.child,
    this.showBanner = true,
    this.showFloatingBadge = false,
  });

  @override
  State<OfflineModeIndicator> createState() => _OfflineModeIndicatorState();
}

class _OfflineModeIndicatorState extends State<OfflineModeIndicator>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  int _pendingCount = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<SyncHealthMetrics>? _syncSubscription;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initConnectivity();
    _subscribeSyncStatus();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectivity(result);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectivity,
    );
  }

  void _updateConnectivity(List<ConnectivityResult> result) {
    setState(() {
      _isOnline = !result.contains(ConnectivityResult.none);
    });
  }

  void _subscribeSyncStatus() {
    try {
      _syncSubscription = SyncManager.instance.syncStatusStream.listen((
        metrics,
      ) {
        setState(() {
          _pendingCount = metrics.pendingCount + metrics.inProgressCount;
        });
      });
    } catch (_) {
      // SyncManager not initialized yet
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            if (!_isOnline && widget.showBanner) _buildOfflineBanner(),
            if (_isOnline && _pendingCount > 0 && widget.showBanner)
              _buildSyncingBanner(),
            Expanded(child: widget.child),
          ],
        ),
        if (widget.showFloatingBadge && (_pendingCount > 0 || !_isOnline))
          Positioned(right: 16, bottom: 80, child: _buildFloatingBadge()),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.orange.shade600],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Opacity(
                opacity: 0.5 + (_pulseController.value * 0.5),
                child: const Icon(
                  Icons.cloud_off,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Offline Mode - Changes saved locally',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_pendingCount pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade500],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  Colors.white.withOpacity(0.9),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Syncing $_pendingCount item${_pendingCount > 1 ? 's' : ''}...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBadge() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isOnline ? Colors.blue : Colors.orange,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isOnline ? Icons.sync : Icons.cloud_off,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              _isOnline ? 'Syncing $_pendingCount' : 'Offline',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact sync status badge for AppBar
class SyncStatusBadge extends StatefulWidget {
  const SyncStatusBadge({super.key});

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge> {
  bool _isOnline = true;
  int _pendingCount = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<SyncHealthMetrics>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _initStatus();
  }

  Future<void> _initStatus() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = !result.contains(ConnectivityResult.none);
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      setState(() {
        _isOnline = !result.contains(ConnectivityResult.none);
      });
    });

    try {
      _syncSubscription = SyncManager.instance.syncStatusStream.listen((
        metrics,
      ) {
        setState(() {
          _pendingCount = metrics.pendingCount + metrics.inProgressCount;
        });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline && _pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isOnline
            ? Colors.blue.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOnline
              ? Colors.blue.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.sync : Icons.cloud_off,
            size: 14,
            color: _isOnline ? Colors.blue : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            _isOnline ? '$_pendingCount' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _isOnline ? Colors.blue : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
