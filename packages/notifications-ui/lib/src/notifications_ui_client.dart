// ============================================================================
// notifications_ui — UI-side HTTP client.
// ----------------------------------------------------------------------------
// Thin wrapper around the Notification_Service HTTP surface that the four
// widgets in this package need. Kept SEPARATE from `notifications_sdk` on
// purpose:
//
//   * `notifications_sdk` owns the four canonical client methods pinned by
//     `phase3-architecture.md` 13.2 (subscribe / emit / onNotification /
//     replay). That surface is contract-level and SHOULD NOT grow.
//   * UI screens additionally need: list paginated history, get the unread
//     count, mark an item read, and read/write preferences. Those are
//     read/write API operations that don't belong on the SDK envelope and
//     are covered here.
//
// Auth: every call attaches `Authorization: Bearer <jwt>` using the same
// `JwtTokenProvider` typedef the SDK already exposes (REQ 19.1).
//
// Endpoints (locked by `phase3-architecture.md` 14.3):
//
//   GET  /notifications?status=&category=&cursor=&limit=  -> list page
//   GET  /notifications/unread-count                       -> integer count
//   POST /notifications/{id}/read                          -> idempotent ack
//   GET  /notifications/preferences                        -> UserPreference
//   POST /notifications/preferences                        -> setUserPreferences
//
// All methods throw `NotificationsUiException` on non-2xx so widgets can
// render a single failure state.
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:notifications_sdk/notifications_sdk.dart';

/// Thrown when an HTTP call to the backend returns a non-2xx and the UI
/// can't recover (e.g. expired token, server-side validation rejection).
class NotificationsUiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? body;

  const NotificationsUiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.body,
  });

  @override
  String toString() =>
      'NotificationsUiException($statusCode${code != null ? ', $code' : ''}): $message';
}

/// One page of notifications returned by the list endpoint.
///
/// Cursor-based pagination per REQ 6.9 / REQ 11.2. The opaque `nextCursor`
/// is null when there are no more pages — widgets can stop loading then.
class NotificationPage {
  final List<NotificationDelivery> items;
  final String? nextCursor;

  const NotificationPage({required this.items, this.nextCursor});
}

/// Single mute entry. `targetId` is required (REQ 7.5); `eventName` is
/// optional and limits the mute to a specific event (where the registry
/// permits it).
class MuteTarget {
  final String targetId;
  final String? eventName;

  const MuteTarget({required this.targetId, this.eventName});

  Map<String, dynamic> toJson() => <String, dynamic>{
    'target_id': targetId,
    if (eventName != null) 'event_name': eventName,
  };

  factory MuteTarget.fromJson(Map<String, dynamic> json) => MuteTarget(
    targetId: json['target_id'] as String,
    eventName: json['event_name'] as String?,
  );
}

/// User preferences as returned by `GET /notifications/preferences` and
/// accepted by `POST /notifications/preferences`. Mirrors the
/// `UserPreference` record in `requirements.md` REQ 6.2 / REQ 7.
class UserPreferences {
  /// Optional role. The backend fills this in from the JWT when missing,
  /// but we round-trip it so the page can show the role label.
  final String? role;

  /// `category -> [channels]`. Empty list = opt-out from that category.
  final Map<String, List<String>> perCategoryChannels;

  /// `event_name -> [channels]`. Wins over `perCategoryChannels` for the
  /// matching event (REQ 7.2).
  final Map<String, List<String>> perEventChannels;

  /// `HH:MM` start of the local Quiet_Hours range, or null when unset.
  final String? quietHoursStart;

  /// `HH:MM` end of the local Quiet_Hours range, or null when unset.
  final String? quietHoursEnd;

  /// IANA tz name (e.g. `Asia/Kolkata`). Required when both quiet bounds
  /// are set; null otherwise.
  final String? quietHoursTimezone;

  /// List of muted `target_id` (and optional `event_name`) tuples.
  final List<MuteTarget> muteTargets;

  const UserPreferences({
    this.role,
    this.perCategoryChannels = const <String, List<String>>{},
    this.perEventChannels = const <String, List<String>>{},
    this.quietHoursStart,
    this.quietHoursEnd,
    this.quietHoursTimezone,
    this.muteTargets = const <MuteTarget>[],
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'per_category_channels': perCategoryChannels,
      'per_event_channels': perEventChannels,
      'mute_targets': muteTargets.map((m) => m.toJson()).toList(),
    };
    if (role != null) map['role'] = role;
    if (quietHoursStart != null) map['quiet_hours_start'] = quietHoursStart;
    if (quietHoursEnd != null) map['quiet_hours_end'] = quietHoursEnd;
    if (quietHoursTimezone != null) {
      map['quiet_hours_timezone'] = quietHoursTimezone;
    }
    return map;
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>> readChannelMap(dynamic raw) {
      if (raw is! Map) return <String, List<String>>{};
      final out = <String, List<String>>{};
      raw.forEach((key, value) {
        if (key is! String) return;
        if (value is! List) return;
        out[key] = value.whereType<String>().toList();
      });
      return out;
    }

    final muteRaw = json['mute_targets'];
    return UserPreferences(
      role: json['role'] as String?,
      perCategoryChannels: readChannelMap(json['per_category_channels']),
      perEventChannels: readChannelMap(json['per_event_channels']),
      quietHoursStart: json['quiet_hours_start'] as String?,
      quietHoursEnd: json['quiet_hours_end'] as String?,
      quietHoursTimezone: json['quiet_hours_timezone'] as String?,
      muteTargets: muteRaw is List
          ? muteRaw
                .whereType<Map>()
                .map((m) => MuteTarget.fromJson(Map<String, dynamic>.from(m)))
                .toList()
          : const <MuteTarget>[],
    );
  }

  UserPreferences copyWith({
    String? role,
    Map<String, List<String>>? perCategoryChannels,
    Map<String, List<String>>? perEventChannels,
    String? quietHoursStart,
    String? quietHoursEnd,
    String? quietHoursTimezone,
    List<MuteTarget>? muteTargets,
  }) {
    return UserPreferences(
      role: role ?? this.role,
      perCategoryChannels: perCategoryChannels ?? this.perCategoryChannels,
      perEventChannels: perEventChannels ?? this.perEventChannels,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      quietHoursTimezone: quietHoursTimezone ?? this.quietHoursTimezone,
      muteTargets: muteTargets ?? this.muteTargets,
    );
  }
}

/// Thin client for the read/write notification endpoints the UI needs.
///
/// One instance per signed-in session is the intended use, identical to
/// the lifetime of the [NotificationsSdk] it complements.
class NotificationsUiClient {
  final Uri _apiBaseUrl;
  final JwtTokenProvider _tokenProvider;
  final http.Client _http;

  NotificationsUiClient({
    required Uri apiBaseUrl,
    required JwtTokenProvider tokenProvider,
    http.Client? httpClient,
  }) : _apiBaseUrl = apiBaseUrl,
       _tokenProvider = tokenProvider,
       _http = httpClient ?? http.Client();

  /// Released by callers when the session ends.
  void close() => _http.close();

  // --------------------------------------------------------------------------
  // Public API consumed by the bell / drawer / preferences widgets.
  // --------------------------------------------------------------------------

  /// `GET /notifications/unread-count` -> `{ unread_count: <int> }`.
  /// Backs the bell badge (REQ 11.1).
  Future<int> unreadCount() async {
    final res = await _get('notifications/unread-count');
    final body = _decodeJson(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFor(res, body);
    }
    if (body is Map && body['unread_count'] is num) {
      return (body['unread_count'] as num).toInt();
    }
    if (body is num) return body.toInt();
    return 0;
  }

  /// `GET /notifications?cursor=&category=&limit=` -> paginated history in
  /// `created_at` DESC order (REQ 11.2).
  Future<NotificationPage> listNotifications({
    String? cursor,
    String? category,
    int limit = 25,
    String? status,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
      if (category != null) 'category': category,
      if (status != null) 'status': status,
    };
    final uri = _apiBaseUrl
        .resolve('notifications')
        .replace(queryParameters: params.isEmpty ? null : params);
    final headers = await _authHeaders();
    final res = await _http.get(uri, headers: headers);
    final body = _decodeJson(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFor(res, body);
    }
    final List<dynamic> rawItems = body is Map && body['notifications'] is List
        ? List<dynamic>.from(body['notifications'] as List)
        : (body is List ? List<dynamic>.from(body) : const <dynamic>[]);
    final items = rawItems
        .whereType<Map>()
        .map((m) => NotificationDelivery.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    final next = body is Map ? body['next_cursor'] as String? : null;
    return NotificationPage(items: items, nextCursor: next);
  }

  /// `POST /notifications/{id}/read` -- idempotent (REQ 4.6, 11.5).
  Future<void> markAsRead(String notificationId) async {
    final uri = _apiBaseUrl.resolve('notifications/$notificationId/read');
    final headers = await _authHeaders();
    headers['Content-Type'] = 'application/json';
    final res = await _http.post(uri, headers: headers, body: '{}');
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = _decodeJson(res);
    throw _exceptionFor(res, body);
  }

  /// `GET /notifications/preferences` (REQ 4.7).
  Future<UserPreferences> getUserPreferences() async {
    final res = await _get('notifications/preferences');
    final body = _decodeJson(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFor(res, body);
    }
    if (body is Map) {
      final preferences = body['preferences'];
      if (preferences is Map) {
        return UserPreferences.fromJson(Map<String, dynamic>.from(preferences));
      }
      return UserPreferences.fromJson(Map<String, dynamic>.from(body));
    }
    return const UserPreferences();
  }

  /// `POST /notifications/preferences` -- idempotent (REQ 4.9, 7.7, 11.4).
  Future<UserPreferences> setUserPreferences(UserPreferences prefs) async {
    final uri = _apiBaseUrl.resolve('notifications/preferences');
    final headers = await _authHeaders();
    headers['Content-Type'] = 'application/json';
    final res = await _http.post(
      uri,
      headers: headers,
      body: jsonEncode(prefs.toJson()),
    );
    final body = _decodeJson(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _exceptionFor(res, body);
    }
    if (body is Map) {
      final preferences = body['preferences'];
      if (preferences is Map) {
        return UserPreferences.fromJson(Map<String, dynamic>.from(preferences));
      }
      return UserPreferences.fromJson(Map<String, dynamic>.from(body));
    }
    return prefs;
  }

  // --------------------------------------------------------------------------
  // Internals.
  // --------------------------------------------------------------------------

  Future<http.Response> _get(String path) async {
    final uri = _apiBaseUrl.resolve(path);
    final headers = await _authHeaders();
    return _http.get(uri, headers: headers);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenProvider();
    return <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeJson(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return res.body;
    }
  }

  NotificationsUiException _exceptionFor(http.Response res, dynamic body) {
    final code = body is Map ? body['code'] as String? : null;
    final message = body is Map
        ? (body['message'] as String? ?? 'Request failed')
        : (body is String && body.isNotEmpty ? body : 'Request failed');
    return NotificationsUiException(
      statusCode: res.statusCode,
      code: code,
      message: message,
      body: body is Map ? Map<String, dynamic>.from(body) : null,
    );
  }
}
