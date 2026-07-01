// ============================================================================
// WEBSOCKET RID SERVICE - Real-time tracking with Session + Message RIDs
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/logger_service.dart';
import '../request_context/request_context.dart';

/// WebSocket service with RID tracking for real-time features
class WebSocketRidService {
  WebSocketChannel? _channel;
  RequestContext? _sessionContext;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();
  
  Timer? _heartbeatTimer;
  bool _isConnected = false;
  
  /// Stream of incoming messages with RID
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  
  /// Stream of connection status changes
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;
  
  /// Current session RID (if connected)
  String? get sessionRid => _sessionContext?.requestId;
  
  /// Check if connected
  bool get isConnected => _isConnected;

  /// Connect and establish Session RID
  Future<void> connect({
    required String url,
    required String tenantId,
    required String userId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      // Generate Session RID
      _sessionContext = RequestContext.generate(
        tenantId: tenantId,
        userId: userId,
      );
      
      LoggerService.d('WebSocketRID', '[WebSocket] Connecting with Session RID: ${_sessionContext?.shortReference}');
      
      // Wait for connection
      await _channel!.ready.timeout(timeout);
      
      // Send connection init with Session RID
      _channel!.sink.add(jsonEncode({
        'action': 'connect',
        'sessionRid': _sessionContext!.requestId,
        'tenantId': tenantId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      
      _isConnected = true;
      _connectionController.add(ConnectionStatus.connected);
      
      // Start heartbeat
      _startHeartbeat();
      
      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleClose,
      );
      
      LoggerService.d('WebSocketRID', '[WebSocket:${_sessionContext?.shortReference}] Connected successfully');
      
    } catch (e) {
      LoggerService.d('WebSocketRID', '[WebSocket] Connection failed: $e');
      _connectionController.add(ConnectionStatus.error);
      rethrow;
    }
  }
  
  /// Send message with Message RID (child of Session RID)
  void sendMessage({
    required String type,
    required Map<String, dynamic> data,
    Map<String, dynamic>? extraHeaders,
  }) {
    if (_sessionContext == null) {
      throw StateError('WebSocket not connected. Call connect() first.');
    }
    
    if (!_isConnected) {
      throw StateError('WebSocket connection lost.');
    }
    
    // Create child Message RID
    final messageContext = _sessionContext!.createChildContext();
    
    final payload = {
      'rid': messageContext.requestId,
      'sessionRid': _sessionContext!.requestId,
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      ...?extraHeaders,
    };
    
    _channel!.sink.add(jsonEncode(payload));
    
    LoggerService.d('WebSocketRID', '[WebSocket:${messageContext.shortReference}] Sent: $type');
  }
  
  /// Send acknowledgment for received message
  void sendAck(String originalRid, {String? status = 'received'}) {
    sendMessage(
      type: 'ack',
      data: {
        'originalRid': originalRid,
        'status': status,
      },
    );
  }
  
  /// Subscribe to a specific channel/topic
  void subscribe(String channel) {
    sendMessage(
      type: 'subscribe',
      data: {'channel': channel},
    );
  }
  
  /// Unsubscribe from a channel
  void unsubscribe(String channel) {
    sendMessage(
      type: 'unsubscribe',
      data: {'channel': channel},
    );
  }
  
  /// Handle incoming message
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final rid = data['rid'] as String?;
      final sessionRid = data['sessionRid'] as String?;
      final type = data['type'] as String?;
      
      LoggerService.d('WebSocketRID', '[WebSocket] Received: rid=$rid, session=$sessionRid, type=$type');
      
      // Validate session RID matches
      if (sessionRid != null && _sessionContext != null) {
        if (sessionRid != _sessionContext!.requestId) {
          LoggerService.d('WebSocketRID', '[WebSocket] WARNING: Session RID mismatch!');
        }
      }
      
      // Add received timestamp
      data['_receivedAt'] = DateTime.now().toIso8601String();
      
      // Send ack for important messages
      if (type != 'ack' && type != 'heartbeat') {
        sendAck(rid ?? 'unknown');
      }
      
      _messageController.add(data);
      
    } catch (e) {
      LoggerService.d('WebSocketRID', '[WebSocket] Message parsing error: $e');
    }
  }
  
  /// Handle connection error
  void _handleError(dynamic error) {
    LoggerService.d('WebSocketRID', '[WebSocket:${_sessionContext?.shortReference}] Error: $error');
    _isConnected = false;
    _connectionController.add(ConnectionStatus.error);
    _stopHeartbeat();
  }
  
  /// Handle connection close
  void _handleClose() {
    LoggerService.d('WebSocketRID', '[WebSocket:${_sessionContext?.shortReference}] Connection closed');
    _isConnected = false;
    _connectionController.add(ConnectionStatus.disconnected);
    _stopHeartbeat();
  }
  
  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        sendMessage(
          type: 'heartbeat',
          data: {'ping': true},
        );
      }
    });
  }
  
  /// Stop heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  /// Disconnect gracefully
  Future<void> disconnect() async {
    _stopHeartbeat();
    
    if (_isConnected && _sessionContext != null) {
      // Send disconnect message
      sendMessage(
        type: 'disconnect',
        data: {'reason': 'client_disconnect'},
      );
    }
    
    await _channel?.sink.close();
    _isConnected = false;
    _sessionContext = null;
    
    LoggerService.d('WebSocketRID', '[WebSocket] Disconnected');
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}

/// Connection status enum
enum ConnectionStatus {
  connected,
  disconnected,
  error,
}

/// Extension for easy WebSocket usage with RID
extension WebSocketRidExtension on WebSocketRidService {
  /// Listen for specific message type
  Stream<Map<String, dynamic>> onMessageType(String type) {
    return messageStream.where((msg) => msg['type'] == type);
  }
  
  /// Listen for messages from specific session
  Stream<Map<String, dynamic>> onSession(String sessionRid) {
    return messageStream.where((msg) => msg['sessionRid'] == sessionRid);
  }
}
