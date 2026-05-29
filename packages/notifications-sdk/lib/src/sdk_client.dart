// ============================================================================
// NotificationsSdk — public API for the Unified Notification System (UNS).
// ----------------------------------------------------------------------------
// Exposes the four canonical methods pinned by phase3-architecture.md §13.2:
//
//   subscribe(eventName, handler)
//   emit(event)
//   onNotification(handler)
//   replay(sinceIso)
//
// Plus operational helpers:
//
//   flushOutbox()     — replay buffered events in created_at ASC (REQ 8.8)
//   connect()         — open the WebSocket and start consuming
//   close()           — release sockets and timers
//
// Auth: every HTTP and WebSocket call attaches `Authorization: Bearer <jwt>`
// using the same JWT that the existing DukanX/Sub_App APIs accept (REQ 19.1).
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'event_contract.dart';
import 'outbox.dart';
import 'schema_validator.dart';

/// One notification delivered to the signed-in user via the in-app channel.
///
/// The shape mirrors the `Notification` record produced by the
/// Notification_Store (design.md §6.1). Unknown fields are preserved in
/// [raw] so the SDK doesn't silently lose forward-compatible data.
class NotificationDelivery {
  final String id;
  final String eventName;
  final String category;
  final String priority;
  final String createdAt;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> raw;

  const NotificationDelivery({
    required this.id,
    required this.eventName,
    required this.category,
    required this.priority,
    required this.createdAt,
    required this.payload,
    required this.raw,
  });

  factory NotificationDelivery.fromJson(Map<String, dynamic> json) {
    return NotificationDelivery(
      id: json['id'] as String,
      eventName: json['event_name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      priority: json['priority'] as String? ?? 'normal',
      createdAt: json['created_at'] as String? ?? '',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      raw: Map<String, dynamic>.from(json),
    );
  }
}

/// Thrown when an HTTP call to the backend returns a non-2xx and the SDK
/// can't recover (e.g. auth failure, schema rejection from the publisher).
class NotificationsSdkException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? body;

  const NotificationsSdkException({
    required this.statusCode,
    required this.message,
    this.code,
    this.body,
  });

  @override
  String toString() =>
      'NotificationsSdkException($statusCode${code != null ? ', $code' : ''}): $message';
}

/// Pluggable token provider so apps can wire the SDK to whichever session
/// manager they already have (Cognito helper, secure storage, etc.).
typedef JwtTokenProvider = FutureOr<String?> Function();

/// SDK entry point. One instance per signed-in session is the intended use.
class NotificationsSdk {
  final Uri _apiBaseUrl;
  final JwtTokenProvider _tokenProvider;
  final SchemaValidator _validator;
  final OutboxStorage _outbox;
  final http.Client _http;
  final Uri? _webSocketUrl;

  /// Subscriptions keyed by `event_name`. Each handler is invoked when a
  /// matching delivery arrives over the WebSocket.
  final Map<String, List<void Function(NotificationDelivery)>> _subscribers =
      <String, List<void Function(NotificationDelivery)>>{};

  /// Broadcast stream for `onNotification(handler)`. Created lazily.
  final StreamController<NotificationDelivery> _notificationController =
      StreamController<NotificationDelivery>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  bool _closed = false;

  /// Gate that becomes true after [connect] succeeds and false again on a
  /// disconnect. Used by [emit] to decide whether to attempt the publish or
  /// go straight to the outbox.
  bool _isConnected = false;

  final Uuid _uuid = const Uuid();

  NotificationsSdk({
    required Uri apiBaseUrl,
    required JwtTokenProvider tokenProvider,
    required SchemaValidator validator,
    OutboxStorage? outbox,
    http.Client? httpClient,
    Uri? webSocketUrl,
  })  : _apiBaseUrl = apiBaseUrl,
        _tokenProvider = tokenProvider,
        _validator = validator,
        _outbox = outbox ?? InMemoryOutboxStorage(),
        _http = httpClient ?? http.Client(),
        _webSocketUrl = webSocketUrl;

  // --------------------------------------------------------------------------
  // Public API — pinned by phase3-architecture.md §13.2.
  // --------------------------------------------------------------------------

  /// Register a handler for a named event. Multiple handlers per name are
  /// supported and invoked in registration order.
  ///
  /// Returns a disposer that removes the registered handler.
  void Function() subscribe(
    String eventName,
    void Function(NotificationDelivery) handler,
  ) {
    final list = _subscribers.putIfAbsent(
        eventName, () => <void Function(NotificationDelivery)>[]);
    list.add(handler);
    return () {
      final current = _subscribers[eventName];
      if (current == null) return;
      current.remove(handler);
      if (current.isEmpty) _subscribers.remove(eventName);
    };
  }

  /// Validate against the Event_Contract schema, then publish to the
  /// backend. On any transient transport failure (network down, 5xx) the
  /// event is buffered to the outbox and `flushOutbox()` will replay it on
  /// the next successful connect (REQ 8.8). Schema-invalid payloads throw
  /// [SchemaValidationException] and are NOT buffered — REQ 3.6 demands
  /// rejection rather than silent persistence.
  Future<void> emit(EventContract event) async {
    final json = event.toJson();
    _validator.validateOrThrow(json);

    if (!_isConnected) {
      await _outbox.append(OutboxEntry(
        id: event.id,
        createdAt: event.createdAt,
        eventJson: json,
      ));
      return;
    }

    try {
      await _publish(json);
    } on SchemaValidationException {
      rethrow;
    } on NotificationsSdkException catch (e) {
      // 4xx that is not a schema rejection still indicates a permanent
      // client error (e.g. auth failure). Don't enqueue — surface to caller.
      // Buffering a 401/403 would silently re-fail forever after the JWT
      // refreshes, leaking memory until the user clears the app data.
      if (e.statusCode >= 400 && e.statusCode < 500) {
        rethrow;
      }
      // 5xx / unknown — buffer for replay.
      await _outbox.append(OutboxEntry(
        id: event.id,
        createdAt: event.createdAt,
        eventJson: json,
      ));
    } catch (_) {
      // Network errors / disconnects — buffer.
      await _outbox.append(OutboxEntry(
        id: event.id,
        createdAt: event.createdAt,
        eventJson: json,
      ));
    }
  }

  /// Stream of every notification delivered over the in-app channel for the
  /// signed-in user. Each `subscribe(name, handler)` is filtered from this
  /// same stream.
  Stream<NotificationDelivery> onNotification() =>
      _notificationController.stream;

  /// Call `GET /notifications/replay?since=<sinceIso>` and return the
  /// resulting list. Bounded server-side by the Replay_Window (default 7
  /// days, REQ 8.4-8.5a). Out-of-window requests return `replay_window_exceeded`
  /// surfaced as [NotificationsSdkException].
  Future<List<NotificationDelivery>> replay(String sinceIso,
      {String? appName}) async {
    final params = <String, String>{'since': sinceIso};
    if (appName != null) params['app'] = appName;
    final uri = _apiBaseUrl
        .resolve('notifications/replay')
        .replace(queryParameters: params);
    final headers = await _authHeaders();
    final res = await _http.get(uri, headers: headers);
    final body = _decodeJson(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw NotificationsSdkException(
        statusCode: res.statusCode,
        code: body is Map ? body['code'] as String? : null,
        message: body is Map
            ? (body['message'] as String? ?? 'Replay failed')
            : 'Replay failed',
        body: body is Map ? Map<String, dynamic>.from(body) : null,
      );
    }
    final list = body is Map && body['notifications'] is List
        ? body['notifications'] as List
        : (body is List ? body : const <dynamic>[]);
    return list
        .whereType<Map>()
        .map((m) => NotificationDelivery.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  // --------------------------------------------------------------------------
  // Operational helpers.
  // --------------------------------------------------------------------------

  /// Open the in-app WebSocket and begin listening. Safe to call repeatedly:
  /// already-open connections are a no-op. Triggers [flushOutbox] once the
  /// socket reports OPEN so any events buffered offline ride out in
  /// `created_at` ASC order before live traffic resumes.
  Future<void> connect() async {
    if (_closed) {
      throw StateError('NotificationsSdk has been closed.');
    }
    if (_channel != null) return;

    final wsUri = _webSocketUrl ?? _deriveWebSocketUrl(_apiBaseUrl);
    final token = await _tokenProvider();
    final headers = <String, dynamic>{
      if (token != null) 'Authorization': 'Bearer $token',
    };
    _channel = WebSocketChannel.connect(wsUri, protocols: null);
    _isConnected = true;

    _channelSub = _channel!.stream.listen(
      _onSocketMessage,
      onError: (_) => _markDisconnected(),
      onDone: _markDisconnected,
      cancelOnError: false,
    );

    // The current `web_socket_channel` API doesn't accept custom headers on
    // every platform, so for transports that need explicit auth-after-connect
    // we send a hello frame containing the JWT. The server is free to ignore
    // it on transports where the upgrade carried the header.
    if (token != null) {
      _channel!.sink.add(jsonEncode(<String, dynamic>{
        'type': 'hello',
        'authorization': 'Bearer $token',
        'headers': headers,
      }));
    }

    // Drain anything queued while we were offline.
    unawaited(flushOutbox());
  }

  /// Replay every buffered event in `created_at` ASC order (REQ 8.8). On a
  /// per-event publish failure the entry stays in the outbox and the loop
  /// stops so the original ordering is preserved on the next attempt.
  ///
  /// Stopping on first failure (rather than continuing past it) is
  /// deliberate: an at_most_once_with_dedup event published out of order
  /// against an at_least_once event of the same dedup_key could change
  /// which one the consumer sees as the "first delivery", and REQ 9.7
  /// requires offline-buffered events to replay in their original order.
  Future<void> flushOutbox() async {
    if (!_isConnected) return;
    final pending = await _outbox.readAllAscending();
    final flushed = <String>[];
    for (final entry in pending) {
      try {
        await _publish(entry.eventJson);
        flushed.add(entry.id);
      } catch (_) {
        // Stop on first failure to preserve ASC ordering for the retry.
        break;
      }
    }
    if (flushed.isNotEmpty) {
      await _outbox.removeMany(flushed);
    }
  }

  /// Tear down sockets and HTTP client. The instance is unusable afterwards.
  Future<void> close() async {
    _closed = true;
    _isConnected = false;
    await _channelSub?.cancel();
    _channelSub = null;
    await _channel?.sink.close();
    _channel = null;
    await _notificationController.close();
    _http.close();
  }

  // --------------------------------------------------------------------------
  // Internals.
  // --------------------------------------------------------------------------

  /// Convenience that fills in a fresh UUID + ISO timestamp + dedup_key
  /// derivation slot. Not part of the canonical API surface, but useful for
  /// callers that want a one-shot publish.
  EventContract buildEvent({
    required String eventName,
    required EventCategory category,
    String? subCategory,
    required EventPriority priority,
    required String actorId,
    String? targetId,
    required List<Recipient> recipients,
    required Map<String, dynamic> payload,
    required List<NotificationChannel> channels,
    required String sourceModule,
    required SourceApp sourceApp,
    required String dedupKey,
    List<String>? dedupScopeFields,
    String? id,
    String? createdAt,
  }) {
    return EventContract(
      id: id ?? _uuid.v4(),
      eventName: eventName,
      category: category,
      subCategory: subCategory,
      priority: priority,
      actorId: actorId,
      targetId: targetId,
      recipients: recipients,
      payload: payload,
      channels: channels,
      sourceModule: sourceModule,
      sourceApp: sourceApp,
      createdAt: createdAt ?? DateTime.now().toUtc().toIso8601String(),
      dedupKey: dedupKey,
      dedupScopeFields: dedupScopeFields,
    );
  }

  Future<void> _publish(Map<String, dynamic> json) async {
    final uri = _apiBaseUrl.resolve('notifications');
    final headers = await _authHeaders();
    headers['Content-Type'] = 'application/json';
    final res = await _http.post(uri, headers: headers, body: jsonEncode(json));
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = _decodeJson(res);
    final code = body is Map ? body['code'] as String? : null;
    final message = body is Map
        ? (body['message'] as String? ?? 'Publish failed')
        : 'Publish failed';
    // Surface schema rejections from the backend as the same exception type
    // the client-side validator throws so callers handle both consistently.
    if (res.statusCode == 400 && code == 'event_contract_validation_failed') {
      final rawErrors = body is Map ? body['errors'] : null;
      final errors = rawErrors is List
          ? rawErrors
              .whereType<Map>()
              .map((m) => SchemaError(
                    path: (m['path'] as String?) ?? '/',
                    message: (m['message'] as String?) ?? 'invalid',
                  ))
              .toList()
          : const <SchemaError>[];
      throw SchemaValidationException(errors);
    }
    throw NotificationsSdkException(
      statusCode: res.statusCode,
      code: code,
      message: message,
      body: body is Map ? Map<String, dynamic>.from(body) : null,
    );
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenProvider();
    return <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  void _onSocketMessage(dynamic frame) {
    if (frame is! String) return;
    final dynamic decoded;
    try {
      decoded = jsonDecode(frame);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;

    // Server may envelope: { type: 'notification', notification: {...} }.
    Map<String, dynamic>? raw;
    if (decoded['type'] == 'notification' && decoded['notification'] is Map) {
      raw = Map<String, dynamic>.from(decoded['notification'] as Map);
    } else if (decoded.containsKey('id') && decoded.containsKey('event_name')) {
      raw = Map<String, dynamic>.from(decoded);
    }
    if (raw == null) return;

    final delivery = NotificationDelivery.fromJson(raw);
    _notificationController.add(delivery);

    final byName = _subscribers[delivery.eventName];
    if (byName != null) {
      for (final h in List<void Function(NotificationDelivery)>.from(byName)) {
        try {
          h(delivery);
        } catch (_) {
          // A subscriber throwing must not break delivery to other handlers.
        }
      }
    }
  }

  void _markDisconnected() {
    _isConnected = false;
    _channelSub = null;
    _channel = null;
  }

  /// Decode a possibly-empty body. Returns `null` on empty, `Map` or `List`
  /// on JSON, or the raw string when decoding fails.
  dynamic _decodeJson(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return res.body;
    }
  }

  /// Map `https://host/path/` → `wss://host/path/notifications/stream`.
  /// Apps that need a different path can pass `webSocketUrl` directly.
  Uri _deriveWebSocketUrl(Uri base) {
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    return base.replace(
        scheme: scheme, path: '${basePath}notifications/stream');
  }
}
