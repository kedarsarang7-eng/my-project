import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../auth/customer_session_manager.dart';
import '../di/providers.dart';
import '../../config/app_config.dart';

enum WsConnectionState { disconnected, connecting, connected, reconnecting }

typedef WsMessageHandler = void Function(Map<String, dynamic> payload);

class CustomerWsService {
  CustomerWsService._();

  WebSocketChannel? _channel;
  WsConnectionState _state = WsConnectionState.disconnected;
  Timer? _pingTimer;
  /// Callback to fetch the current access token at reconnect time.
  /// Prevents stale-token reconnect loops after session refresh.
  String? Function()? _tokenGetter;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 6;
  static const _pingInterval = Duration(seconds: 25);

  final _stateController =
      StreamController<WsConnectionState>.broadcast();
  final _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _handlers = <String, List<WsMessageHandler>>{};

  Stream<WsConnectionState> get stateStream => _stateController.stream;
  WsConnectionState get state => _state;

  Future<void> connect(String accessToken, {String? Function()? tokenGetter}) async {
    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting) {
      return;
    }

    // Store getter for future reconnects
    if (tokenGetter != null) _tokenGetter = tokenGetter;

    _setState(WsConnectionState.connecting);

    final wsUrl =
        '${AppConfig.wsUrlStatic}?token=${Uri.encodeQueryComponent(accessToken)}';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _startPing();
    } catch (e) {
      debugPrint('[WS] Connect failed: $e');
      _setState(WsConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _cancelTimers();
    _channel?.sink.close(ws_status.goingAway);
    _channel = null;
    _setState(WsConnectionState.disconnected);
  }

  void subscribe(String eventType, WsMessageHandler handler) {
    _handlers.putIfAbsent(eventType, () => []).add(handler);
  }

  void unsubscribe(String eventType, WsMessageHandler handler) {
    _handlers[eventType]?.remove(handler);
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      _eventController.add(data);

      // Backend sends { event: 'payment_success', ... } — support both 'event'
      // and 'type' fields so all existing and new subscribers work.
      final eventKey = (data['event'] ?? data['type']) as String?;
      if (eventKey != null) {
        for (final h in List<WsMessageHandler>.of(_handlers[eventKey] ?? [])) {
          h(data);
        }
      }

      // Wildcard handlers
      for (final h in List<WsMessageHandler>.of(_handlers['*'] ?? [])) {
        h(data);
      }
    } catch (e) {
      debugPrint('[WS] Message parse error: $e');
    }
  }

  void _onError(Object error) {
    debugPrint('[WS] Error: $error');
  }

  void _onDone() {
    if (_state == WsConnectionState.connected) {
      debugPrint('[WS] Connection closed unexpectedly — scheduling reconnect');
      _setState(WsConnectionState.reconnecting);
      _cancelTimers();
      _scheduleReconnect();
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_state == WsConnectionState.connected) {
        _channel?.sink.add(jsonEncode({'action': 'ping'}));
      }
    });
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[WS] Max reconnect attempts reached');
      _setState(WsConnectionState.disconnected);
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(
      seconds: (_reconnectAttempts * _reconnectAttempts).clamp(1, 60),
    );
    debugPrint(
        '[WS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      // P1 FIX: Always fetch fresh token at reconnect time
      final freshToken = _tokenGetter?.call();
      if (freshToken != null) {
        connect(freshToken);
      } else {
        debugPrint('[WS] No valid token for reconnect — staying disconnected');
        _setState(WsConnectionState.disconnected);
      }
    });
  }

  void _cancelTimers() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
  }

  void _setState(WsConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _eventController.close();
  }
}

// ── Singleton provider ───────────────────────────────────────────────────────

final customerWsServiceProvider = Provider<CustomerWsService>((ref) {
  final service = CustomerWsService._();

  // Auto-connect when session is authenticated; disconnect on sign-out
  ref.listen(customerSessionProvider, (_, next) async {
    next.whenData((session) async {
      if (session.isAuthenticated && session.accessToken != null) {
        // P1 FIX: Pass tokenGetter so reconnects always use the latest token
        service.connect(
          session.accessToken!,
          tokenGetter: () => ref.read(customerSessionProvider).valueOrNull?.accessToken,
        );
      } else {
        service.disconnect();
      }
    });
  });

  ref.onDispose(service.dispose);
  return service;
});

// ── Riverpod notifier wrapping WS connection state ───────────────────────────

final wsConnectionStateProvider =
    StreamProvider<WsConnectionState>((ref) {
  final svc = ref.watch(customerWsServiceProvider);
  return svc.stateStream;
});
