// ============================================================================
// HARDWARE WEBSOCKET / REALTIME HANDLER (bugfix.md 1.17 / 2.17)
// ============================================================================
// Subscribes the hardware vertical to realtime `hardware.*` events on the LIVE
// realtime transport (AWS API Gateway WebSocket when online, in-process event
// bus when offline) exposed by [ServiceRegistry]. It is registered during app
// bootstrap (see [HardwareModule.register], invoked from
// `AppBootstrap.initialize`), so hardware realtime events are genuinely wired
// into the running app rather than being dead code.
//
// Preservation: subscribing to the `hardware.*` namespace is additive and inert
// for every other vertical — non-hardware realtime delivery is unchanged.
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/service_registry/service_registry.dart';

class HardwareWsHandler {
  HardwareWsHandler();

  /// Realtime event names the hardware vertical listens for. All live under the
  /// `hardware.*` namespace so they never collide with another vertical.
  static const List<String> hardwareEvents = <String>[
    'hardware.project.updated',
    'hardware.indent.created',
    'hardware.deposit.changed',
    'hardware.credit.updated',
    'hardware.challan.dispatched',
  ];

  final List<void Function()> _cancels = <void Function()>[];
  bool _attached = false;

  bool get isAttached => _attached;

  /// Subscribe every hardware event to the live realtime service. Idempotent.
  ///
  /// No-op (logged) when the [ServiceRegistry] has not been initialised yet,
  /// so an early bootstrap call degrades gracefully instead of throwing.
  void attach() {
    if (_attached) return;
    if (!ServiceRegistry.instance.isReady) {
      if (kDebugMode) {
        debugPrint(
          'HardwareWsHandler: ServiceRegistry not ready — realtime '
          'subscription deferred.',
        );
      }
      return;
    }

    final realtime = Services.realtime;
    for (final event in hardwareEvents) {
      _cancels.add(realtime.subscribe(event, _onEvent));
    }
    _attached = true;
    if (kDebugMode) {
      debugPrint(
        'HardwareWsHandler attached: ${hardwareEvents.length} hardware.* '
        'events subscribed on the live realtime transport.',
      );
    }
  }

  FutureOr<void> _onEvent(String event, Map<String, dynamic> payload) {
    // Hook for hardware realtime reconciliation (e.g. invalidate the relevant
    // HardwareOpsRepository cache). Kept side-effect-free here so the wiring is
    // safe to attach globally.
    if (kDebugMode) {
      debugPrint('HardwareWsHandler received: $event');
    }
  }

  void dispose() {
    for (final cancel in _cancels) {
      cancel();
    }
    _cancels.clear();
    _attached = false;
  }
}
