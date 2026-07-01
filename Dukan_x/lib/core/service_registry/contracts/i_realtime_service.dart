// ============================================================================
// IRealtimeService — Pub/Sub Contract
// ============================================================================
// Online  -> AWS API Gateway WebSocket (existing `WebSocketService`).
// Offline -> in-process broadcast Stream (single-machine, no LAN needed).
// ============================================================================

import 'dart:async';

typedef RealtimeHandler = FutureOr<void> Function(
  String event,
  Map<String, dynamic> payload,
);

abstract class IRealtimeService {
  /// Fire-and-forget event emission to the current user's channel.
  Future<void> emit(String event, Map<String, dynamic> payload);

  /// Subscribe a handler. Returns a cancel function.
  void Function() subscribe(String event, RealtimeHandler handler);

  /// Broadcast to all subscribers of [room]. Online: API GW WS broadcast.
  /// Offline: same as [emit] (single-process).
  Future<void> broadcast(
    String room,
    String event,
    Map<String, dynamic> payload,
  );

  /// True once the underlying transport is ready to accept emissions.
  bool get isConnected;

  Future<void> connect();
  Future<void> dispose() async {}
}
