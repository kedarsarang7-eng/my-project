import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class PwaWsEvent {
  final String event;
  final Map<String, dynamic> data;

  const PwaWsEvent({required this.event, required this.data});

  factory PwaWsEvent.fromJson(Map<String, dynamic> json) {
    return PwaWsEvent(
      event: (json['event'] ?? '').toString(),
      data: (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }
}

class PwaWebSocketService {
  PwaWebSocketService._();
  static final PwaWebSocketService instance = PwaWebSocketService._();

  // P0-10: No default. Pass --dart-define=DUKANX_WS_URL=wss://... per stage.
  // Empty value disables WebSocket entirely (graceful degradation).
  static const String _defaultEndpoint = String.fromEnvironment('DUKANX_WS_URL');

  WebSocketChannel? _channel;
  StreamSubscription? _streamSub;
  Timer? _pingTimer;
  final _controller = StreamController<PwaWsEvent>.broadcast();

  Stream<PwaWsEvent> get stream => _controller.stream;

  bool get isConnected => _channel != null;

  Future<bool> connect({
    required String authToken,
    required String vendorId,
    String? customerId,
    String? deviceId,
  }) async {
    if (authToken.isEmpty || vendorId.isEmpty) return false;
    if (_defaultEndpoint.isEmpty) return false; // P0-10: WS not configured
    if (isConnected) return true;

    final uri = Uri.parse(_defaultEndpoint).replace(
      queryParameters: {
        'authToken': authToken,
        'clientType': 'customer_app',
        'businessId': vendorId,
        if (customerId != null && customerId.isNotEmpty) 'staffId': customerId,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      },
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _streamSub = _channel!.stream.listen(
        _onMessage,
        onError: (_) => _softReset(),
        onDone: _softReset,
      );
      _startPing();
      return true;
    } catch (_) {
      _softReset();
      return false;
    }
  }

  void subscribe(List<String> events) {
    if (_channel == null || events.isEmpty) return;
    _channel!.sink.add(jsonEncode({'action': 'subscribe', 'events': events}));
  }

  void unsubscribe(List<String> events) {
    if (_channel == null || events.isEmpty) return;
    _channel!.sink.add(jsonEncode({'action': 'unsubscribe', 'events': events}));
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _streamSub?.cancel();
    _streamSub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) return;
      if (parsed['action'] == 'pong') return;
      final event = PwaWsEvent.fromJson(parsed);
      if (event.event.isNotEmpty) {
        _controller.add(event);
      }
    } catch (_) {}
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final channel = _channel;
      if (channel != null) {
        channel.sink.add(jsonEncode({'action': 'ping'}));
      }
    });
  }

  void _softReset() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _streamSub?.cancel();
    _streamSub = null;
    _channel = null;
  }
}
