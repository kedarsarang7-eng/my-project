// ============================================================================
// APP MODE — Single Source of Truth for Online vs Offline
// ============================================================================
// This file defines the AppMode enum + a ValueNotifier-based mode state.
//
// RULE #1 (NON-NEGOTIABLE): NO file in lib/ outside of lib/core/service_registry/
// is allowed to import this file or branch on AppMode. Business logic stays
// 100% mode-agnostic. The only consumer is ServiceRegistry.
//
// The mode is determined by the MODE env key (read by AppConfig). Default is
// `online` for backward-compatibility with the current production deployment.
// ============================================================================

import 'package:flutter/foundation.dart';

/// Two deployment modes the app can run in.
enum AppMode {
  /// Cloud-connected: Cognito + Lambda/DynamoDB + S3 + API Gateway WebSocket + SES.
  online,

  /// Fully self-contained: Drift+SQLCipher locally, password auth in Drift,
  /// local filesystem storage, in-process realtime, queued email outbox.
  offline,
}

extension AppModeX on AppMode {
  /// Wire-format value used in config files & the MODE env key.
  String get wire => switch (this) {
        AppMode.online => 'online',
        AppMode.offline => 'offline',
      };

  bool get isOnline => this == AppMode.online;
  bool get isOffline => this == AppMode.offline;

  static AppMode fromWire(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'offline':
        return AppMode.offline;
      case 'online':
      case null:
      case '':
        return AppMode.online;
      default:
        throw ArgumentError.value(value, 'MODE',
            'Invalid mode (expected "online" or "offline")');
    }
  }
}

/// Reactive holder for the current mode. UI may listen for live mode changes
/// triggered by the migration engine after cutover.
class AppModeState {
  AppModeState._();
  static final AppModeState instance = AppModeState._();

  final ValueNotifier<AppMode> _mode = ValueNotifier<AppMode>(AppMode.online);

  ValueListenable<AppMode> get listenable => _mode;
  AppMode get current => _mode.value;

  /// Internal — only ServiceRegistry should call this after a successful
  /// migration cutover or initial bootstrap.
  void setInternal(AppMode mode) {
    if (_mode.value != mode) {
      _mode.value = mode;
    }
  }
}
