import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class PosWsEvent {
  final String event;
  final Map<String, dynamic> data;

  const PosWsEvent({required this.event, required this.data});

  factory PosWsEvent.fromJson(Map<String, dynamic> json) {
    return PosWsEvent(
      event: (json['event'] ?? '').toString(),
      data: (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }
}

class PosWebSocketService {
  PosWebSocketService._();
  static final PosWebSocketService instance = PosWebSocketService._();

  static const String _endpoint = String.fromEnvironment(
    'DUKANX_WS_URL',
    defaultValue: 'wss://chfkfh81zf.execute-api.ap-south-1.amazonaws.com/dev',
  );

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _ping;
  final _events = StreamController<PosWsEvent>.broadcast();

  Stream<PosWsEvent> get events => _events.stream;

  bool get isConnected => _channel != null;

  Future<bool> connect({
    required String authToken,
    required String businessId,
    String? staffId,
    String? deviceId,
  }) async {
    if (authToken.isEmpty || businessId.isEmpty) return false;
    if (isConnected) return true;

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'authToken': authToken,
        'clientType': 'restaurant_staff_app',
        'businessId': businessId,
        if (staffId != null && staffId.isNotEmpty) 'staffId': staffId,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      },
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        _onMessage,
        onDone: _softReset,
        onError: (_) => _softReset(),
      );
      _startPing();
      return true;
    } catch (_) {
      _softReset();
      return false;
    }
  }

  void subscribe(List<String> events) {
    final ch = _channel;
    if (ch == null || events.isEmpty) return;
    ch.sink.add(jsonEncode({'action': 'subscribe', 'events': events}));
  }

  Future<void> disconnect() async {
    _ping?.cancel();
    _ping = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _events.close();
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) return;
      if (parsed['action'] == 'pong') return;
      final event = PosWsEvent.fromJson(parsed);
      if (event.event.isNotEmpty) _events.add(event);
    } catch (_) {}
  }

  void _startPing() {
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 30), (_) {
      final ch = _channel;
      if (ch != null) ch.sink.add(jsonEncode({'action': 'ping'}));
    });
  }

  void _softReset() {
    _ping?.cancel();
    _ping = null;
    _sub?.cancel();
    _sub = null;
    _channel = null;
  }
}
