import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dukanx/core/sync/sync_manager.dart';
import 'package:dukanx/core/sync/sync_conflict.dart';
import 'package:dukanx/core/sync/conflict_resolution_dialog.dart';

// Idempotency: Sync queue operations carry stable idempotency keys (operationId / requestId / idempotencyKey) to ensure server-side deduplication.

/// Widget that listens for sync conflicts and shows resolution dialog
class SyncConflictListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const SyncConflictListener({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<SyncConflictListener> createState() => _SyncConflictListenerState();
}

class _SyncConflictListenerState extends State<SyncConflictListener> {
  StreamSubscription<SyncConflict>? _subscription;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _subscription = SyncManager.instance.onConflict.listen(_handleConflict);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handleConflict(SyncConflict conflict) async {
    // Avoid stacking dialogs
    if (_isDialogShowing) return;

    final context = widget.navigatorKey.currentContext;
    if (context == null) return;

    // Safety: Schedule execution after current frame to prevent "setState during build"
    // constraints or overlay insert errors if conflict arrives during widget init.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_isDialogShowing) return; // Re-check inside frame callback

      _isDialogShowing = true;
      try {
        final choice = await showConflictResolutionDialog(context, conflict);

        if (choice != null) {
          // Resolve based on choice
          Map<String, dynamic> resolvedPayload;

          switch (choice) {
            case ConflictChoice.keepLocal:
              resolvedPayload = conflict.localData;
              break;
            case ConflictChoice.keepServer:
              resolvedPayload = conflict.serverData;
              break;
            case ConflictChoice.merge:
              // Use the service to smart merge
              // We need to import the service class or use a static helper
              // ConflictResolutionService is in conflict_resolution_dialog.dart (which we imported)
              final service = ConflictResolutionService();
              resolvedPayload = service.mergeData(
                localData: conflict.localData,
                serverData: conflict.serverData,
                localModifiedAt: conflict.localModifiedAt,
                serverModifiedAt: conflict.serverModifiedAt,
              );
              break;
          }

          // Apply resolution
          await SyncManager.instance.resolveConflict(conflict, resolvedPayload);
        }
      } finally {
        if (mounted) {
          _isDialogShowing = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
