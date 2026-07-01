// Online Realtime Provider — delegates to the existing WebSocketService.
// Wraps the typed subscription API into the generic IRealtimeService contract.

import 'dart:async';
import '../../../../core/di/service_locator.dart';
import '../../../services/websocket_service.dart' show WebSocketService, WSEventCallback, WSEvent;
import '../../contracts/i_realtime_service.dart';

class ApiGwRealtimeProvider implements IRealtimeService {
  WebSocketService get _ws => sl<WebSocketService>();

  // Tracks active subscriptions keyed by a unique handle for cancellation.
  final Map<String, WSEventCallback> _handlers = {};

  @override
  bool get isConnected => _ws.isConnected;

  @override
  Future<void> connect() async {
    // WebSocketService manages its own connection lifecycle;
    // we just ensure it's initialized through GetIt.
    if (!_ws.isConnected) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  Future<void> emit(String event, Map<String, dynamic> payload) async {
    _ws.sendMessage({'action': event, ...payload});
  }

  @override
  void Function() subscribe(String event, RealtimeHandler handler) {
    final key = '${event}_${DateTime.now().microsecondsSinceEpoch}';
    void wrapped(WSEvent wsEvent) => handler(event, wsEvent.data);
    _handlers[key] = wrapped;
    _ws.subscribe(event, wrapped);
    return () {
      _ws.unsubscribe(event, wrapped);
      _handlers.remove(key);
    };
  }

  @override
  Future<void> broadcast(
    String room,
    String event,
    Map<String, dynamic> payload,
  ) async {
    // API GW WS backend handles room-based fan-out server-side.
    _ws.sendMessage({'action': event, 'room': room, ...payload});
  }

  @override
  Future<void> dispose() async {
    _handlers.clear();
  }
}
