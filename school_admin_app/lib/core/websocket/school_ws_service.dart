import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

/// Real-time WebSocket service for admin app.
/// Receives new admission alerts, fee payment confirmations, system broadcasts.
class SchoolWsService {
  static const int _maxReconnectDelay = 30;

  final _storage = const FlutterSecureStorage();
  WebSocket? _socket;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectDelay = 1;
  bool _intentionalClose = false;

  final _controller = StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get events => _controller.stream;

  Future<void> connect() async {
    _intentionalClose = false;
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;
    final wsUrl = '${AppConfig.wsBaseUrl}?token=${Uri.encodeComponent(token)}';
    try {
      _socket = await WebSocket.connect(wsUrl);
      _reconnectDelay = 1;
      _startHeartbeat();
      _socket!.listen(_onMessage, onError: (_) => _scheduleReconnect(), onDone: _onDone, cancelOnError: false);
    } catch (_) { _scheduleReconnect(); }
  }

  void _onMessage(dynamic raw) {
    try {
      _controller.add(WsEvent.fromJson(jsonDecode(raw as String) as Map<String, dynamic>));
    } catch (_) {}
  }

  void _onDone() {
    _heartbeatTimer?.cancel();
    if (!_intentionalClose) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _reconnectDelay = (_reconnectDelay * 2).clamp(1, _maxReconnectDelay);
      connect();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      try { _socket?.add(jsonEncode({'action': 'ping'})); } catch (_) {}
    });
  }

  void send(Map<String, dynamic> payload) {
    try { _socket?.add(jsonEncode(payload)); } catch (_) {}
  }

  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.close();
    _socket = null;
  }

  void dispose() { disconnect(); _controller.close(); }
  bool get isConnected => _socket?.readyState == WebSocket.open;
}

class WsEvent {
  final String type;
  final String? title;
  final String? body;
  final String? category;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  WsEvent({required this.type, this.title, this.body, this.category, required this.data}) : receivedAt = DateTime.now();
  factory WsEvent.fromJson(Map<String, dynamic> json) => WsEvent(
        type: json['type'] ?? json['action'] ?? 'unknown',
        title: json['title'],
        body: json['body'] ?? json['message'],
        category: json['category'],
        data: Map<String, dynamic>.from(json),
      );
}

final schoolWsServiceProvider = Provider<SchoolWsService>((ref) {
  final service = SchoolWsService();
  ref.onDispose(service.dispose);
  return service;
});

/// Filtered stream — only real notifications (not heartbeats)
final wsNotificationsProvider = StateNotifierProvider<_NotifNotifier, List<WsEvent>>((ref) {
  return _NotifNotifier(ref.watch(schoolWsServiceProvider));
});

class _NotifNotifier extends StateNotifier<List<WsEvent>> {
  StreamSubscription? _sub;
  _NotifNotifier(SchoolWsService ws) : super([]) {
    _sub = ws.events
        .where((e) => e.type != 'pong' && e.type != 'ping')
        .listen((e) => state = [e, ...state.take(49)]);
  }
  void clear() => state = [];
  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
}
