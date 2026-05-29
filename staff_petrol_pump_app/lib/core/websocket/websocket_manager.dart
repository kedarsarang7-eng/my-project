import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../auth/token_storage.dart';
import '../config/app_config.dart';

/// WebSocket connection states
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket message types from backend
class WebSocketMessage {
  final String type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  WebSocketMessage({
    required this.type,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] ?? 'unknown',
      payload: json['payload'] ?? json,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Check if this is a payment success message
  bool get isPaymentSuccess => type == 'PAYMENT_SUCCESS';

  /// Check if this is a payment failed message
  bool get isPaymentFailed => type == 'PAYMENT_FAILED';

  /// Get transaction ID from payload
  String? get transactionId => payload['transactionId']?.toString();

  /// Get order ID from payload
  String? get orderId => payload['orderId']?.toString();

  /// Get amount from payload (in paise)
  int? get amountPaise {
    final amount = payload['amount'];
    if (amount is int) return amount;
    if (amount is double) return amount.toInt();
    return null;
  }
}

/// WebSocket manager for real-time payment notifications
/// Handles connection, authentication, reconnection, and message parsing
class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;
  WebSocketManager._internal();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  final StreamController<WebSocketMessage> _messageController =
      StreamController<WebSocketMessage>.broadcast();
  final StreamController<WebSocketState> _stateController =
      StreamController<WebSocketState>.broadcast();

  WebSocketState _currentState = WebSocketState.disconnected;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  /// Stream of incoming messages
  Stream<WebSocketMessage> get messages => _messageController.stream;

  /// Stream of connection state changes
  Stream<WebSocketState> get state => _stateController.stream;

  /// Current connection state
  WebSocketState get currentState => _currentState;

  /// Whether connected
  bool get isConnected => _currentState == WebSocketState.connected;

  void _setState(WebSocketState state) {
    if (_currentState != state) {
      _currentState = state;
      _stateController.add(state);
      debugPrint('WebSocket state: $state');
    }
  }

  /// Connect to WebSocket with JWT authentication
  Future<void> connect() async {
    if (_currentState == WebSocketState.connecting ||
        _currentState == WebSocketState.connected) {
      return;
    }

    _setState(WebSocketState.connecting);

    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null) {
        _setState(WebSocketState.error);
        throw Exception('No access token available for WebSocket');
      }

      // Build WebSocket URL with token as query param
      // Backend expects: wss://xxx.execute-api.ap-south-1.amazonaws.com/prod?token=JWT
      final wsBaseUrl = AppConfig.wsBaseUrl;
      final wsUrl = Uri.parse('$wsBaseUrl?token=$token');

      debugPrint('Connecting to WebSocket: ${wsUrl.toString().split('?')[0]}...');

      _channel = WebSocketChannel.connect(wsUrl);

      // Listen to incoming messages
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _setState(WebSocketState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();

      debugPrint('WebSocket connected successfully');
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _setState(WebSocketState.error);
      _scheduleReconnect();
    }
  }

  /// Handle incoming message
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final wsMessage = WebSocketMessage.fromJson(data);
      _messageController.add(wsMessage);

      debugPrint('WebSocket message received: ${wsMessage.type}');
    } catch (e) {
      debugPrint('WebSocket message parse error: $e');
    }
  }

  /// Handle connection error
  void _onError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _setState(WebSocketState.error);
    _scheduleReconnect();
  }

  /// Handle connection close
  void _onDone() {
    debugPrint('WebSocket connection closed');
    _setState(WebSocketState.disconnected);
    _stopHeartbeat();
    _scheduleReconnect();
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    final delay = Duration(
      seconds: _reconnectDelay.inSeconds * _reconnectAttempts,
    );

    debugPrint('Scheduling reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _setState(WebSocketState.reconnecting);

    _reconnectTimer = Timer(delay, () {
      debugPrint('Attempting to reconnect...');
      connect();
    });
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (isConnected) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          debugPrint('Heartbeat failed: $e');
        }
      }
    });
  }

  /// Stop heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  /// Disconnect WebSocket
  void disconnect() {
    debugPrint('Disconnecting WebSocket...');
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _reconnectAttempts = 0;

    try {
      _channel?.sink.close(status.normalClosure);
    } catch (_) {
      // Ignore close errors
    }

    _channel = null;
    _setState(WebSocketState.disconnected);
  }

  /// Send message to server
  void send(Map<String, dynamic> message) {
    if (!isConnected) {
      throw Exception('WebSocket not connected');
    }
    _channel?.sink.add(jsonEncode(message));
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }
}

/// Riverpod provider for WebSocket manager
// Note: Provider will be defined in providers.dart after importing
