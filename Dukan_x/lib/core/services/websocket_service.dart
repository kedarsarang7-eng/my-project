import 'dart:async';
import 'dart:convert';
import 'logger_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

// ============================================================================
// WebSocket Service — Real-Time Communication Client
// ============================================================================
// Manages persistent WebSocket connection to the backend for receiving
// real-time events (orders, KOTs, payments, inventory changes, etc.).
//
// Usage:
//   final ws = WebSocketService.instance;
//   ws.connect(authToken: token, businessId: 'BUS_103', clientType: 'staff_app');
//   ws.subscribe('order_created', (data) => handleNewOrder(data));
//   ws.subscribe('kot_created', (data) => refreshKitchenDisplay(data));
// ============================================================================

/// All supported real-time event names (must match backend WSEventName enum).
class WSEventName {
  static const String orderCreated = 'order_created';
  static const String orderUpdated = 'order_updated';
  static const String orderCompleted = 'order_completed';
  static const String kotCreated = 'kot_created';
  static const String checkoutRequested = 'checkout_requested';
  static const String paymentSuccess = 'payment_success';
  static const String paymentFailed = 'payment_failed';
  static const String billCreated = 'bill_created';
  static const String billUpdated = 'bill_updated';
  static const String inventoryUpdated = 'inventory_updated';
  static const String lowStockAlert = 'low_stock_alert';
  static const String expiryAlert = 'expiry_alert';
  static const String staffActivity = 'staff_activity';
  static const String staffSaleCreated = 'staff_sale_created';
  static const String staffLogin = 'staff_login';
  static const String staffLogout = 'staff_logout';
  static const String staffAssigned = 'staff_assigned';
  static const String petrolSaleUpdate = 'petrol_sale_update';
  static const String dieselSaleUpdate = 'diesel_sale_update';
  static const String appointmentCreated = 'appointment_created';
  static const String queueUpdated = 'queue_updated';
  static const String prescriptionCreated = 'prescription_created';
  static const String serviceJobCreated = 'service_job_created';
  static const String serviceStatusUpdated = 'service_status_updated';
  static const String priceUpdated = 'price_updated';
  static const String dashboardUpdated = 'dashboard_updated';
  static const String adminAction = 'admin_action';
  static const String notification = 'notification';
  static const String syncCompleted = 'sync_completed';
  static const String deviceSync = 'device_sync';

  // Smart Inventory Import
  static const String importProgress = 'import_progress';
  static const String importCompleted = 'import_completed';
  static const String importFailed = 'import_failed';
}

/// Client types for WebSocket connection metadata.
class WSClientType {
  static const String staffApp = 'staff_app';
  static const String customerApp = 'customer_app';
  static const String restaurantStaffApp = 'restaurant_staff_app';
  static const String adminPanel = 'admin_panel';
  static const String desktopApp = 'desktop_app';
}

/// Connection status for the WebSocket.
enum WSConnectionStatus { disconnected, connecting, connected, reconnecting }

/// A real-time event received from the server.
class WSEvent {
  final String event;
  final String businessId;
  final String timestamp;
  final Map<String, dynamic> data;

  WSEvent({
    required this.event,
    required this.businessId,
    required this.timestamp,
    required this.data,
  });

  factory WSEvent.fromJson(Map<String, dynamic> json) {
    return WSEvent(
      event: json['event'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
    );
  }
}

typedef WSEventCallback = void Function(WSEvent event);

/// Singleton WebSocket client for real-time communication.
///
/// Provides:
/// - Secure connection with JWT authentication
/// - Automatic reconnection with exponential backoff
/// - Event subscription model
/// - Connection status monitoring
class WebSocketService {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final WebSocketService _instance = WebSocketService._internal();
  static WebSocketService get instance => _instance;
  WebSocketService._internal();

  // ── Configuration ──────────────────────────────────────────────────────
  // The endpoint is output by CloudFormation as WebsocketApiEndpoint.
  static const String _defaultEndpoint = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: '', // MUST be set via .env (WS_ENDPOINT_URL) or --dart-define
  );

  String _wsEndpoint = _defaultEndpoint;

  // ── State ──────────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  WSConnectionStatus _status = WSConnectionStatus.disconnected;
  String? _authToken;
  String? _businessId;
  String? _clientType;
  String? _staffId;
  String? _deviceId;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  // ── Event Listeners ────────────────────────────────────────────────────
  final Map<String, List<WSEventCallback>> _listeners = {};
  final _statusController = StreamController<WSConnectionStatus>.broadcast();

  /// Stream of connection status changes.
  Stream<WSConnectionStatus> get statusStream => _statusController.stream;

  /// Current connection status.
  WSConnectionStatus get status => _status;

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _status == WSConnectionStatus.connected;

  // ============================================================================
  // CONNECTION MANAGEMENT
  // ============================================================================

  /// Set the WebSocket endpoint URL (call before connect).
  void setEndpoint(String endpoint) {
    _wsEndpoint = endpoint;
  }

  /// Establish a secure WebSocket connection.
  ///
  /// [authToken]  — Cognito JWT access token for authentication.
  /// [businessId] — The tenant/business ID for event routing.
  /// [clientType] — One of [WSClientType] constants.
  /// [staffId]    — Optional staff identifier.
  /// [deviceId]   — Optional device identifier.
  Future<void> connect({
    required String authToken,
    required String businessId,
    required String clientType,
    String? staffId,
    String? deviceId,
  }) async {
    if (_status == WSConnectionStatus.connected ||
        _status == WSConnectionStatus.connecting) {
      return; // Already connected or connecting
    }

    _authToken = authToken;
    _businessId = businessId;
    _clientType = clientType;
    _staffId = staffId;
    _deviceId = deviceId;
    _reconnectAttempts = 0;

    await _doConnect();
  }

  /// Internal connection method.
  Future<void> _doConnect() async {
    _setStatus(WSConnectionStatus.connecting);

    try {
      if (_authToken == null || _authToken!.isEmpty) {
        LoggerService.d('WebSocket', '[WebSocket] No auth token available — skipping connection');
        _setStatus(WSConnectionStatus.disconnected);
        return;
      }

      // Build WebSocket URL with query parameters
      // NOTE: API Gateway WebSocket requires auth token in query params
      // (upgrade handshake doesn't support custom headers). This is the
      // standard approach for APIGW WebSockets.
      final queryParams = <String, String>{
        'token': _authToken!,
        'clientType': _clientType ?? WSClientType.desktopApp,
        'businessId': _businessId ?? '',
      };
      if (_staffId != null && _staffId!.isNotEmpty) {
        queryParams['staffId'] = _staffId!;
      }
      if (_deviceId != null && _deviceId!.isNotEmpty) {
        queryParams['deviceId'] = _deviceId!;
      }

      final uri = Uri.parse(_wsEndpoint).replace(queryParameters: queryParams);

      _channel = WebSocketChannel.connect(uri);

      // Listen for messages
      _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone);

      _setStatus(WSConnectionStatus.connected);
      _reconnectAttempts = 0;
      _startPingTimer();

      // FIX (M-06): Don't log URL with auth token — sanitize output
      LoggerService.d('WebSocket', '[WebSocket] Connected to ${Uri.parse(_wsEndpoint).host}');
    } catch (e) {
      LoggerService.d('WebSocket', '[WebSocket] Connection failed: $e');
      _setStatus(WSConnectionStatus.disconnected);
      _scheduleReconnect();
    }
  }

  /// Gracefully disconnect the WebSocket.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _reconnectAttempts = 0;

    if (_channel != null) {
      await _channel!.sink.close(ws_status.goingAway);
      _channel = null;
    }

    _setStatus(WSConnectionStatus.disconnected);
    LoggerService.d('WebSocket', '[WebSocket] Disconnected');
  }

  // ============================================================================
  // EVENT SUBSCRIPTION
  // ============================================================================

  /// Subscribe to a specific event type.
  ///
  /// Example:
  /// ```dart
  /// ws.subscribe(WSEventName.orderCreated, (event) {
  ///   print('New order: ${event.data['orderId']}');
  /// });
  /// ```
  void subscribe(String eventName, WSEventCallback callback) {
    _listeners.putIfAbsent(eventName, () => []);
    _listeners[eventName]!.add(callback);
  }

  /// Unsubscribe a specific callback from an event.
  void unsubscribe(String eventName, WSEventCallback callback) {
    _listeners[eventName]?.remove(callback);
  }

  /// Unsubscribe all callbacks for a specific event.
  void unsubscribeAll(String eventName) {
    _listeners.remove(eventName);
  }

  /// Remove all event listeners.
  void clearAllListeners() {
    _listeners.clear();
  }

  // ============================================================================
  // MESSAGE HANDLING
  // ============================================================================

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;

      // Handle pong response
      if (data['action'] == 'pong') return;

      // Parse as event
      final event = WSEvent.fromJson(data);

      // Notify listeners for this event type
      final callbacks = _listeners[event.event];
      if (callbacks != null) {
        for (final callback in callbacks) {
          try {
            callback(event);
          } catch (e) {
            LoggerService.d('WebSocket', 
              '[WebSocket] Event handler error for ${event.event}: $e',
            );
          }
        }
      }

      // Also notify wildcard listeners (listen to all events)
      final wildcardCallbacks = _listeners['*'];
      if (wildcardCallbacks != null) {
        for (final callback in wildcardCallbacks) {
          try {
            callback(event);
          } catch (e) {
            LoggerService.d('WebSocket', '[WebSocket] Wildcard handler error: $e');
          }
        }
      }
    } catch (e) {
      LoggerService.d('WebSocket', '[WebSocket] Failed to parse message: $e');
    }
  }

  void _onError(dynamic error) {
    LoggerService.d('WebSocket', '[WebSocket] Error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    LoggerService.d('WebSocket', '[WebSocket] Connection closed');
    _channel = null;
    _pingTimer?.cancel();

    if (_status != WSConnectionStatus.disconnected) {
      // Unexpected closure — attempt reconnection
      _scheduleReconnect();
    }
  }

  // ============================================================================
  // AUTO-RECONNECTION
  // ============================================================================

  /// Schedule a reconnection with exponential backoff.
  ///
  /// Strategy:
  ///   - Initial delay: 2 seconds
  ///   - Max delay: 30 seconds
  ///   - Max retries: infinite
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _setStatus(WSConnectionStatus.reconnecting);

    // Exponential backoff: 2s, 4s, 8s, 16s, 30s (capped)
    final delay = Duration(
      seconds: (2 * (1 << _reconnectAttempts)).clamp(2, 30),
    );

    LoggerService.d('WebSocket', 
      '[WebSocket] Reconnecting in ${delay.inSeconds}s '
      '(attempt ${_reconnectAttempts + 1})',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      _doConnect();
    });
  }

  // ============================================================================
  // KEEPALIVE PING
  // ============================================================================

  /// Send periodic ping messages to keep the connection alive.
  void _startPingTimer() {
    _pingTimer?.cancel();
    // FIX (M-09): Reduced from 5 min to 3 min. API Gateway idle timeout
    // is 10 min; 3-min ping provides safe margin for network latency.
    _pingTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (_channel != null && _status == WSConnectionStatus.connected) {
        try {
          _channel!.sink.add(jsonEncode({'action': 'ping'}));
        } catch (e) {
          LoggerService.d('WebSocket', '[WebSocket] Ping failed: $e');
        }
      }
    });
  }

  // ============================================================================
  // STATUS MANAGEMENT
  // ============================================================================

  void _setStatus(WSConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Send a raw JSON payload over the WebSocket channel.
  void sendMessage(Map<String, dynamic> payload) {
    if (_channel != null && _status == WSConnectionStatus.connected) {
      try {
        _channel!.sink.add(jsonEncode(payload));
      } catch (e) {
        LoggerService.d('WebSocket', '[WebSocket] sendMessage failed: $e');
      }
    }
  }

  /// Dispose all resources. Call when the app is shutting down.
  void dispose() {
    disconnect();
    _statusController.close();
    _listeners.clear();
  }
}
