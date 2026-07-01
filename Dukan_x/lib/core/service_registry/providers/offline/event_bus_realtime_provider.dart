// Offline Realtime Provider — in-process broadcast StreamController.
// On a single machine there is no LAN fanout needed; all subscribers are
// in the same Dart isolate. Events are dispatched synchronously via a
// broadcast stream, so the API is identical to the online WebSocket version.

import 'dart:async';
import '../../contracts/i_realtime_service.dart';

class EventBusRealtimeProvider implements IRealtimeService {
  // Each event name gets its own broadcast controller.
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  // Active subscriptions keyed by handle id → cancel function.
  final Map<String, StreamSubscription> _subscriptions = {};

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> emit(String event, Map<String, dynamic> payload) async {
    _controllerFor(event).add(payload);
  }

  @override
  void Function() subscribe(String event, RealtimeHandler handler) {
    // ignore: close_sinks
    final ctrl = _controllerFor(event);
    final key = '${event}_${DateTime.now().microsecondsSinceEpoch}';
    final sub = ctrl.stream.listen((payload) => handler(event, payload));
    _subscriptions[key] = sub;
    return () {
      sub.cancel();
      _subscriptions.remove(key);
    };
  }

  @override
  Future<void> broadcast(
    String room,
    String event,
    Map<String, dynamic> payload,
  ) async {
    // Single-process: broadcast == emit (no rooms needed offline).
    await emit(event, payload);
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();
    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
    _controllers.clear();
    _connected = false;
  }

  StreamController<Map<String, dynamic>> _controllerFor(String event) {
    return _controllers.putIfAbsent(
      event,
      () => StreamController<Map<String, dynamic>>.broadcast(),
    );
  }
}
