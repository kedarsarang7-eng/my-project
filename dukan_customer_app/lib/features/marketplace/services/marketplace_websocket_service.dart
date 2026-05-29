// ============================================================
// Dukan Customer App - Marketplace WebSocket Service
// Real-time updates for orders and inventory
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../config/app_config.dart';
import '../models/marketplace_models.dart';

class MarketplaceWebSocketService {
  WebSocketChannel? _channel;
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _orderUpdatesController = StreamController<OrderUpdatePayload>.broadcast();
  final _inventorySyncController = StreamController<Map<String, dynamic>>.broadcast();
  
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  
  String? _currentToken;
  String? _currentBusinessId;
  String? _currentCustomerId;

  // Streams
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<OrderUpdatePayload> get orderUpdatesStream => _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get inventorySyncStream => _inventorySyncController.stream;

  bool get isConnected => _isConnected;

  // Connect to WebSocket
  Future<void> connect({
    required String token,
    required String businessId,
    required String customerId,
  }) async {
    _currentToken = token;
    _currentBusinessId = businessId;
    _currentCustomerId = customerId;
    _shouldReconnect = true;

    await _connect();
  }

  Future<void> _connect() async {
    if (_channel != null) {
      await disconnect();
    }

    try {
      final wsUrl = AppConfig.wsUrlStatic;
      if (wsUrl.isEmpty) {
        print('WebSocket URL not configured');
        return;
      }

      // Build connection URL with auth params
      final uri = Uri.parse(wsUrl).replace(
        queryParameters: {
          'token': _currentToken,
          'businessId': _currentBusinessId,
        },
      );

      _channel = WebSocketChannel.connect(uri);

      // Listen for messages
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _isConnected = true;
      _connectionStatusController.add(true);

      // Subscribe to customer room
      _subscribeToRoom();

      // Start ping timer
      _startPingTimer();

      print('WebSocket connected');
    } catch (e) {
      print('WebSocket connection error: $e');
      _isConnected = false;
      _connectionStatusController.add(false);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final msg = WebSocketMessage.fromJson(data);

      switch (msg.type) {
        case 'ORDER_UPDATE':
          if (msg.payload != null) {
            final payload = OrderUpdatePayload.fromJson(msg.payload!);
            _orderUpdatesController.add(payload);
          }
          break;

        case 'INVENTORY_SYNC':
          if (msg.payload != null) {
            _inventorySyncController.add(msg.payload!);
          }
          break;

        case 'pong':
          // Ping response - connection is alive
          break;

        default:
          print('Unknown message type: ${msg.type}');
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  void _onError(dynamic error) {
    print('WebSocket error: $error');
    _isConnected = false;
    _connectionStatusController.add(false);
  }

  void _onDone() {
    print('WebSocket closed');
    _isConnected = false;
    _connectionStatusController.add(false);
    _pingTimer?.cancel();

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_shouldReconnect) {
        print('Attempting to reconnect...');
        _connect();
      }
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        _send({'action': 'ping'});
      }
    });
  }

  void _subscribeToRoom() {
    if (_currentBusinessId != null && _currentCustomerId != null) {
      final room = 'biz_${_currentBusinessId}_cust_$_currentCustomerId';
      _send({
        'action': 'subscribe',
        'room': room,
      });
    }
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  // Public API
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connectionStatusController.add(false);
  }

  void sendMessage(Map<String, dynamic> data) {
    _send(data);
  }

  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _orderUpdatesController.close();
    _inventorySyncController.close();
  }
}
