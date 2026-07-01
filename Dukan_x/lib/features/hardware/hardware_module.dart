// ============================================================================
// HARDWARE MODULE (bugfix.md 1.17 / 2.17)
// ============================================================================
// Single cohesive entry point that wires the hardware vertical into the LIVE
// app: its route table, its offline [HardwareSyncHandler] (registered with the
// live SyncManager), and its realtime [HardwareWsHandler] (subscribed to the
// live `hardware.*` event transport).
//
// `register()` is invoked from `AppBootstrap.initialize` AFTER the SyncManager
// is initialised, so the handlers attach to genuinely-live infrastructure
// rather than being dead code. Modelled on the module-integration pattern
// (formerly `features/jewellery/jewellery_integration.dart`, now deleted).
//
// Preservation: registration is additive and hardware-namespaced. The route
// table mirrors the in-shell navigation resolver (the screens hardware users
// reach today); attaching the sync/realtime handlers does not change how any
// other vertical routes or syncs.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/sync/sync_manager.dart';
import 'hardware_sync_handler.dart';
import 'hardware_ws_handler.dart';

import 'presentation/screens/hardware_operations_screen.dart';
import 'presentation/screens/hardware_command_center_screen.dart';
import 'presentation/screens/hardware_supplier_management_screen.dart';
import 'presentation/screens/hardware_phase12_workspace_screen.dart';
import 'presentation/screens/hardware_credit_control_screen.dart';
import 'presentation/screens/hardware_invoice_profile_screen.dart';
import '../delivery_challan/presentation/screens/delivery_challan_list_screen.dart';

/// Hardware vertical module: routes + live offline-sync + live realtime wiring.
class HardwareModule {
  HardwareModule._();

  static final HardwareModule instance = HardwareModule._();

  HardwareSyncHandler? _syncHandler;
  HardwareWsHandler? _wsHandler;
  bool _registered = false;

  bool get isRegistered => _registered;
  HardwareSyncHandler? get syncHandler => _syncHandler;
  HardwareWsHandler? get wsHandler => _wsHandler;

  // ───────────────────────────────────────────────────────────────────────
  // ROUTE TABLE
  // ───────────────────────────────────────────────────────────────────────

  /// The hardware screens reachable in the running shell, keyed by the snake
  /// case ids the in-shell navigation resolver uses (kept in sync with
  /// `SidebarNavigationHandler.getScreenForItem`).
  static Map<String, WidgetBuilder> routes() {
    return <String, WidgetBuilder>{
      'hardware_operations': (_) => const HardwareOperationsScreen(),
      'delivery_challans': (_) => const DeliveryChallanListScreen(),
      'hardware_command_center': (_) => const HardwareCommandCenterScreen(),
      'hardware_supplier_management': (_) =>
          const HardwareSupplierManagementScreen(),
      'hardware_phase12_workspace': (_) =>
          const HardwarePhase12WorkspaceScreen(),
      'hardware_credit_control': (_) => const HardwareCreditControlScreen(),
      'hardware_invoice_profile': (_) => const HardwareInvoiceProfileScreen(),
    };
  }

  /// The set of route ids this module owns.
  static List<String> get routeIds => routes().keys.toList(growable: false);

  // ───────────────────────────────────────────────────────────────────────
  // LIVE WIRING
  // ───────────────────────────────────────────────────────────────────────

  /// Wire the hardware module into the live app. Idempotent.
  ///
  /// Called from `AppBootstrap.initialize` with the live [SyncManager]. Attaches
  /// the offline-sync handler to that manager and the realtime handler to the
  /// live `hardware.*` transport.
  void register({required SyncManager syncManager}) {
    if (_registered) return;

    _syncHandler = HardwareSyncHandler(syncManager)..attach();
    _wsHandler = HardwareWsHandler()..attach();
    _registered = true;

    if (kDebugMode) {
      debugPrint(
        'HardwareModule registered: ${routeIds.length} routes, '
        'sync handler attached=${_syncHandler!.isAttached}, '
        'ws handler attached=${_wsHandler!.isAttached}.',
      );
    }
  }

  /// Tear down the live wiring (used on shutdown / tests).
  Future<void> unregister() async {
    await _syncHandler?.dispose();
    _wsHandler?.dispose();
    _syncHandler = null;
    _wsHandler = null;
    _registered = false;
  }
}
