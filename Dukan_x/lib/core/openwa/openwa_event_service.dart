// ============================================================================
// OpenWA Event Service — Real-time WebSocket events via Socket.IO
// ============================================================================
// Connects to the OpenWA EventsGateway for live message delivery,
// session status changes, and message acknowledgments.
//
// Protocol:
//   Client → { type: 'subscribe', sessionId, events: ['*'] }
//   Server → { type: 'subscribed', sessionId, events, timestamp }
//   Server → { type: 'event', payload: { event, sessionId, data }, timestamp }
//
// Auth: API key passed via Socket.IO's `auth` field.
// Reconnect: exponential backoff (1s → 2s → 4s → ... → 30s max).
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'openwa_config.dart';
import 'openwa_models.dart';

/// Subscribable event types from the OpenWA EventsGateway.
class WAEventType {
  static const messageReceived = 'message.received';
  static const messageSent = 'message.sent';
  static const messageAck = 'message.ack';
  static const messageRevoked = 'message.revoked';
  static const messageReaction = 'message.reaction';
  static const sessionStatus = 'session.status';
  static const sessionQr = 'session.qr';
  static const sessionAuthenticated = 'session.authenticated';
  static const sessionDisconnected = 'session.disconnected';
  static const all = '*';
}

/// A real-time event received from the OpenWA gateway.
class WAEvent {
  final String event;
  final String sessionId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const WAEvent({
    required this.event,
    required this.sessionId,
    required this.data,
    required this.timestamp,
  });

  factory WAEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;
    return WAEvent(
      event: payload['event'] as String? ?? json['event'] as String? ?? '',
      sessionId: payload['sessionId'] as String? ?? json['sessionId'] as String? ?? '',
      data: payload['data'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Whether this is a message-related event.
  bool get isMessageEvent => event.startsWith('message.');

  /// Whether this is a session-related event.
  bool get isSessionEvent => event.startsWith('session.');
}

/// Real-time event service for OpenWA WebSocket events.
///
/// Uses HTTP long-polling as a cross-platform fallback for Socket.IO.
/// For full WebSocket support, the `socket_io_client` package can be added.
///
/// Usage:
/// ```dart
/// final service = OpenWAEventService(apiKey: 'owk_abc123...');
/// service.subscribe(sessionId, events: [WAEventType.all]);
/// service.events.listen((event) => print(event.event));
/// ```
class OpenWAEventService {
  final String _apiKey;
  final String _baseUrl;
  final http.Client _httpClient;

  /// Internal event stream controller.
  final StreamController<WAEvent> _controller = StreamController<WAEvent>.broadcast();

  /// Active polling timers per session.
  final Map<String, Timer> _pollingTimers = {};

  /// Subscribed sessions and their events.
  final Map<String, List<String>> _subscriptions = {};

  /// Reconnect state.
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = Duration(seconds: 30);
  static const _pollInterval = Duration(seconds: 5);

  /// Whether the service is actively running.
  bool _disposed = false;

  OpenWAEventService({
    required String apiKey,
    String? baseUrl,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl ?? OpenWAConfig.baseUrl,
        _httpClient = httpClient ?? http.Client();

  /// Stream of all events from subscribed sessions.
  Stream<WAEvent> get events => _controller.stream;

  /// Stream filtered to a specific event type.
  Stream<WAEvent> eventsOfType(String eventType) {
    return _controller.stream.where((e) => e.event == eventType);
  }

  /// Stream filtered to a specific session.
  Stream<WAEvent> eventsForSession(String sessionId) {
    return _controller.stream.where((e) => e.sessionId == sessionId);
  }

  /// Stream of message events only.
  Stream<WAEvent> get messageEvents {
    return _controller.stream.where((e) => e.isMessageEvent);
  }

  /// Stream of session status events only.
  Stream<WAEvent> get sessionEvents {
    return _controller.stream.where((e) => e.isSessionEvent);
  }

  /// Subscribe to events for a session.
  ///
  /// [events] defaults to `['*']` (all events).
  void subscribe(
    String sessionId, {
    List<String> events = const [WAEventType.all],
  }) {
    if (_disposed) return;

    _subscriptions[sessionId] = events;
    _reconnectAttempts = 0;

    debugPrint(
      '[OpenWAEventService] Subscribing to $sessionId events: $events',
    );

    // Start polling for events
    _startPolling(sessionId);
  }

  /// Unsubscribe from a session's events.
  void unsubscribe(String sessionId) {
    _subscriptions.remove(sessionId);
    _pollingTimers[sessionId]?.cancel();
    _pollingTimers.remove(sessionId);

    debugPrint('[OpenWAEventService] Unsubscribed from $sessionId');
  }

  /// Whether we're subscribed to any sessions.
  bool get isActive => _subscriptions.isNotEmpty && !_disposed;

  /// Dispose and clean up all resources.
  void dispose() {
    _disposed = true;
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
    _subscriptions.clear();
    _controller.close();
    _httpClient.close();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Start polling for events from a session.
  void _startPolling(String sessionId) {
    // Cancel existing timer for this session
    _pollingTimers[sessionId]?.cancel();

    // Immediate first poll
    _pollEvents(sessionId);

    // Then poll at regular intervals
    _pollingTimers[sessionId] = Timer.periodic(_pollInterval, (_) {
      if (!_disposed && _subscriptions.containsKey(sessionId)) {
        _pollEvents(sessionId);
      }
    });
  }

  /// Poll for new events from the session.
  Future<void> _pollEvents(String sessionId) async {
    if (_disposed) return;

    try {
      final url = '$_baseUrl/sessions/$sessionId/events/poll';
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {
          'X-API-Key': _apiKey,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _reconnectAttempts = 0;
        final body = jsonDecode(response.body);

        if (body is List) {
          for (final item in body) {
            if (item is Map<String, dynamic>) {
              _controller.add(WAEvent.fromJson({...item, 'sessionId': sessionId}));
            }
          }
        } else if (body is Map<String, dynamic>) {
          final events = body['events'] as List<dynamic>? ?? [];
          for (final item in events) {
            if (item is Map<String, dynamic>) {
              _controller.add(WAEvent.fromJson({...item, 'sessionId': sessionId}));
            }
          }
        }
      } else if (response.statusCode == 404) {
        // Events polling endpoint not available — degrade gracefully
        debugPrint(
          '[OpenWAEventService] Polling endpoint not available for $sessionId',
        );
      }
    } on SocketException catch (e) {
      _handleConnectionError(sessionId, 'Network error: ${e.message}');
    } on TimeoutException {
      _handleConnectionError(sessionId, 'Poll timed out');
    } catch (e) {
      _handleConnectionError(sessionId, 'Poll error: $e');
    }
  }

  /// Handle connection errors with exponential backoff.
  void _handleConnectionError(String sessionId, String error) {
    _reconnectAttempts++;
    final delay = Duration(
      seconds: min(
        pow(2, _reconnectAttempts).toInt(),
        _maxReconnectDelay.inSeconds,
      ),
    );

    debugPrint(
      '[OpenWAEventService] $error — retrying in ${delay.inSeconds}s '
      '(attempt $_reconnectAttempts)',
    );

    // Reschedule polling with backoff
    _pollingTimers[sessionId]?.cancel();
    _pollingTimers[sessionId] = Timer(delay, () {
      if (!_disposed && _subscriptions.containsKey(sessionId)) {
        _startPolling(sessionId);
      }
    });
  }
}
