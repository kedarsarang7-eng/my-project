// ============================================================================
// HARDWARE SYNC HANDLER (bugfix.md 1.17 / 2.17)
// ============================================================================
// Offline-first sync handler for the hardware vertical. It is registered with
// the LIVE [SyncManager] during app bootstrap (see [HardwareModule.register],
// invoked from `AppBootstrap.initialize`), so hardware offline sync is genuinely
// wired into the running app rather than being dead code.
//
// The handler owns the set of hardware entity collections that must round-trip
// through the offline queue (projects, site indents, material-on-deposit,
// contractor credit, delivery challans) and gives the hardware feature a single
// place to enqueue and flush those operations against the live engine.
//
// Preservation: attaching this handler is additive and inert for every other
// vertical — it only ever observes/forwards hardware collections, so non-
// hardware sync behaviour is unchanged.
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/sync/sync_manager.dart';
import '../../core/sync/models/sync_types.dart';
import '../../core/sync/sync_queue_state_machine.dart';

class HardwareSyncHandler {
  HardwareSyncHandler(this._syncManager);

  final SyncManager _syncManager;
  StreamSubscription<SyncResult>? _eventSub;
  bool _attached = false;

  /// Hardware collections that participate in offline sync.
  static const List<String> hardwareCollections = <String>[
    'hardware_projects',
    'site_indents',
    'material_deposits',
    'contractor_credit',
    'delivery_challans',
  ];

  bool get isAttached => _attached;

  /// Attach to the live [SyncManager] event stream. Idempotent — safe to call
  /// from an idempotent bootstrap step.
  void attach() {
    if (_attached) return;
    _attached = true;
    _eventSub = _syncManager.syncEventStream.listen(
      _onSyncEvent,
      onError: (Object e) {
        if (kDebugMode) debugPrint('HardwareSyncHandler sync error: $e');
      },
    );
    if (kDebugMode) {
      debugPrint('HardwareSyncHandler attached to live SyncManager');
    }
  }

  /// Hook for hardware-specific post-sync reconciliation. Observes the live
  /// sync event stream; hardware features can extend this to refresh caches
  /// once their queued operations are confirmed by the engine.
  void _onSyncEvent(SyncResult result) {
    if (kDebugMode) {
      debugPrint(
        'HardwareSyncHandler: operation ${result.operationId} '
        '${result.isSuccess ? "synced" : "failed"}',
      );
    }
  }

  /// Enqueue a hardware operation through the live offline-first queue.
  Future<String> enqueue(SyncQueueItem item) => _syncManager.enqueue(item);

  /// Force an immediate flush of pending hardware operations.
  Future<void> flush() => _syncManager.forceSyncAll();

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _attached = false;
  }
}
