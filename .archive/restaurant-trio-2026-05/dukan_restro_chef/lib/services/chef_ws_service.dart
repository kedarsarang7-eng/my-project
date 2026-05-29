import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChefWsService {
  static const String _wsOrigin = String.fromEnvironment(
    'DUKANX_WS_URL',
    defaultValue: 'wss://chfkfh81zf.execute-api.ap-south-1.amazonaws.com/dev',
  );

  WebSocketChannel? _channel;
  StreamSubscription? _streamSub;
  Timer? _pingTimer;
  final _eventController = StreamController<String>.broadcast();

  Stream<String> get events => _eventController.stream;

  Future<bool> connect() async {
    if (_channel != null) return true;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('staff_token') ?? '';
    final businessId =
        prefs.getString('pos_vendor_id') ?? prefs.getString('vendor_id') ?? '';
    if (token.isEmpty || businessId.isEmpty) return false;

    try {
      final uri = Uri.parse(_wsOrigin).replace(
        queryParameters: {
          'authToken': token,
          'clientType': 'restaurant_staff_app',
          'businessId': businessId,
        },
      );
      _channel = WebSocketChannel.connect(uri);
      _streamSub = _channel!.stream.listen(
        _onMessage,
        onError: (_) => disconnect(),
        onDone: disconnect,
      );
      _channel!.sink.add(
        jsonEncode({
          'action': 'subscribe',
          'events': ['kot_created', 'kot_status_updated'],
        }),
      );
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _channel?.sink.add(jsonEncode({'action': 'ping'}));
      });
      return true;
    } catch (_) {
      await disconnect();
      return false;
    }
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _streamSub?.cancel();
    _streamSub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final event = (parsed['event'] ?? '').toString();
      if (event.isNotEmpty) {
        _eventController.add(event);
      }
    } catch (_) {}
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
