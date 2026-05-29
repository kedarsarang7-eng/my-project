// ============================================================================
// UNS providers — school_student_app
// ----------------------------------------------------------------------------
// Wires `notifications_sdk` and `notifications_ui` against the same JWT and
// API base URL the rest of the app already uses.
//
// Validates: REQ 8.1, 8.8, 11.2, 11.4, 19.1.
// Created by task 14.6 of `unified-notification-system` spec.
// ============================================================================

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:notifications_sdk/notifications_sdk.dart';
import 'package:notifications_ui/notifications_ui.dart';

import '../config/app_config.dart';

/// Reads the access token from `flutter_secure_storage` — the same key the
/// rest of the app's `ApiClient` uses to attach `Authorization: Bearer …`.
Future<String?> _readJwt() async {
  const storage = FlutterSecureStorage();
  return storage.read(key: 'access_token');
}

/// Schema validator. The bundled Event_Contract JSON Schema is loaded from
/// the SDK package's asset bundle so the SDK can reject schema-invalid
/// `emit` payloads client-side per REQ 3.6 / 8.7.
final schemaValidatorProvider = FutureProvider<SchemaValidator>((ref) async {
  final raw = await rootBundle.loadString(
    'packages/notifications_sdk/event-contract.schema.json',
  );
  return SchemaValidator.fromString(raw);
});

/// Single canonical SDK instance per signed-in session. Returns a future
/// because the schema validator is loaded asynchronously from the asset
/// bundle on first access.
final notificationsSdkProvider = FutureProvider<NotificationsSdk>((ref) async {
  final apiBase = Uri.parse(AppConfig.apiBaseUrl.endsWith('/')
      ? AppConfig.apiBaseUrl
      : '${AppConfig.apiBaseUrl}/');
  final wsBase = Uri.parse(AppConfig.wsBaseUrl.endsWith('/')
      ? AppConfig.wsBaseUrl
      : '${AppConfig.wsBaseUrl}/');
  final validator = await ref.watch(schemaValidatorProvider.future);
  final sdk = NotificationsSdk(
    apiBaseUrl: apiBase,
    tokenProvider: _readJwt,
    validator: validator,
    webSocketUrl: wsBase.resolve('notifications/stream'),
  );
  ref.onDispose(() async {
    await sdk.close();
  });
  return sdk;
});

/// Thin HTTP client backing the bell / drawer / preferences page. Synchronous
/// because it doesn't need the schema validator.
final notificationsUiClientProvider = Provider<NotificationsUiClient>((ref) {
  final apiBase = Uri.parse(AppConfig.apiBaseUrl.endsWith('/')
      ? AppConfig.apiBaseUrl
      : '${AppConfig.apiBaseUrl}/');
  final client = NotificationsUiClient(
    apiBaseUrl: apiBase,
    tokenProvider: _readJwt,
  );
  ref.onDispose(client.close);
  return client;
});
