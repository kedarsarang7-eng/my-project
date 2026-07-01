// ============================================================================
// UNS PROVIDERS
// ============================================================================
// Riverpod providers that build a `NotificationsSdk` and `NotificationsUiClient`
// for DukanX. Wires the shared packages at `packages/notifications-sdk/` and
// `packages/notifications-ui/` to the existing Cognito session manager and
// API base URL — so every UNS call (emit, replay, listNotifications,
// markAsRead, etc.) reuses the same JWT the rest of the app already uses.
//
// Validates: REQ 8.1, 8.8, 10.5, 19.1.
// Used by: customer notifications screen + repository (task 14.5),
//          customer payment screen (T-CUS-5 / T-PAY-8),
//          customer link accept screen (T-CUS-4),
//          and every other DukanX site that emits or consumes UNS events.
// ============================================================================

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notifications_sdk/notifications_sdk.dart';
import 'package:notifications_ui/notifications_ui.dart';

import '../../config/api_config.dart';
import '../di/service_locator.dart';
import '../session/session_manager.dart';

/// Resolves the UNS API base URI from `ApiConfig`. The SDK joins relative
/// paths (`notifications`, `notifications/replay`, etc.) onto this URI, so
/// it MUST end with a trailing slash for `Uri.resolve` to work correctly.
Uri _resolveApiBaseUri() {
  final raw = ApiConfig.baseUrl;
  final normalised = raw.endsWith('/') ? raw : '$raw/';
  return Uri.parse(normalised);
}

/// Returns the current Cognito access token, or null while the user is
/// signed out. The SDK / UI client call this on every request so they
/// always carry a fresh token.
Future<String?> _readAccessToken() async {
  try {
    final session = sl<SessionManager>();
    return await session.getAccessToken();
  } catch (_) {
    return null;
  }
}

/// Cached `SchemaValidator` so we only parse the bundled schema once per
/// process. The schema is shipped as a Flutter asset by
/// `packages/notifications-sdk/pubspec.yaml`.
SchemaValidator? _cachedValidator;

Future<SchemaValidator> _loadValidator() async {
  final cached = _cachedValidator;
  if (cached != null) return cached;
  final raw = await rootBundle.loadString(
    'packages/notifications_sdk/event-contract.schema.json',
  );
  final validator = SchemaValidator.fromString(raw);
  _cachedValidator = validator;
  return validator;
}

/// Async provider for the canonical Shared_SDK instance. One per session.
///
/// The provider deliberately does NOT call `connect()` itself — host
/// surfaces decide when to bring the WebSocket up (e.g. on the post-login
/// route) so headless emit-and-buffer remains the default.
final notificationsSdkProvider = FutureProvider<NotificationsSdk>((ref) async {
  final validator = await _loadValidator();
  final sdk = NotificationsSdk(
    apiBaseUrl: _resolveApiBaseUri(),
    tokenProvider: _readAccessToken,
    validator: validator,
  );
  ref.onDispose(sdk.close);
  return sdk;
});

/// Provider for the UI-side HTTP client (list, unread count, mark read,
/// preferences). Kept separate from the SDK because these are read/write
/// API operations that don't belong on the canonical four-method envelope.
final notificationsUiClientProvider = Provider<NotificationsUiClient>((ref) {
  final client = NotificationsUiClient(
    apiBaseUrl: _resolveApiBaseUri(),
    tokenProvider: _readAccessToken,
  );
  ref.onDispose(client.close);
  return client;
});
