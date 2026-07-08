// ============================================================================
// OpenWA Riverpod Providers — State management for WhatsApp integration
// ============================================================================
// Riverpod 3.x providers (Notifier pattern — NOT legacy StateNotifier).
// Handles connection state, session management, chat state, and template CRUD.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dukanx/core/openwa/openwa_client.dart';
import 'package:dukanx/core/openwa/openwa_config.dart';
import 'package:dukanx/core/openwa/openwa_models.dart';
import 'package:dukanx/core/openwa/openwa_tenant_service.dart';

// ── Service Providers ───────────────────────────────────────────────────────

/// Singleton tenant service provider.
final openWATenantServiceProvider = Provider<OpenWATenantService>((ref) {
  return OpenWATenantService();
});

/// Whether OpenWA is configured (base URL set).
final openWAAvailableProvider = Provider<bool>((ref) {
  return OpenWAConfig.isConfigured;
});

// ── Connection State ────────────────────────────────────────────────────────

/// Connection status for the current business's WhatsApp session.
enum WAConnectionState {
  /// Not configured — OpenWA URL not set.
  unavailable,

  /// Not provisioned — no session created for this business yet.
  notProvisioned,

  /// Provisioned but disconnected.
  disconnected,

  /// QR code is ready — user needs to scan.
  qrReady,

  /// Session is connecting.
  connecting,

  /// Session is fully connected and ready.
  connected,

  /// Connection check in progress.
  loading,

  /// Error occurred.
  error;

  bool get isUsable => this == WAConnectionState.connected;
  bool get needsSetup =>
      this == WAConnectionState.notProvisioned ||
      this == WAConnectionState.unavailable;
}

/// Manages WhatsApp connection state for the current business.
/// Uses Riverpod 3.x Notifier pattern (not deprecated StateNotifier).
class WAConnectionNotifier extends Notifier<WAConnectionState> {
  String? _errorMessage;
  WAQRCode? _qrCode;

  @override
  WAConnectionState build() {
    _checkConnection();
    return WAConnectionState.loading;
  }

  OpenWATenantService get _tenantService =>
      ref.read(openWATenantServiceProvider);

  String? get errorMessage => _errorMessage;
  WAQRCode? get qrCode => _qrCode;

  /// Check current connection status.
  Future<void> _checkConnection() async {
    if (!OpenWAConfig.isConfigured) {
      state = WAConnectionState.unavailable;
      return;
    }

    state = WAConnectionState.loading;
    try {
      final config = await _tenantService.getBusinessConfig();
      if (!config.isProvisioned) {
        state = WAConnectionState.notProvisioned;
        return;
      }

      final client = await _tenantService.getClient();
      final session = await client.getSession(config.sessionId!);

      if (session.status.isConnected) {
        state = WAConnectionState.connected;
      } else if (session.status.needsQR) {
        state = WAConnectionState.qrReady;
      } else if (session.status == WASessionStatus.connecting ||
          session.status == WASessionStatus.initializing) {
        state = WAConnectionState.connecting;
      } else {
        state = WAConnectionState.disconnected;
      }
    } on OpenWAException catch (e) {
      if (e.code == 'NOT_PROVISIONED') {
        state = WAConnectionState.notProvisioned;
      } else {
        _errorMessage = e.message;
        state = WAConnectionState.error;
      }
    } catch (e) {
      _errorMessage = e.toString();
      state = WAConnectionState.error;
    }
  }

  /// Refresh connection status.
  Future<void> refresh() async => _checkConnection();

  /// Start the session and begin QR code flow.
  Future<void> startSession() async {
    state = WAConnectionState.connecting;
    try {
      final config = await _tenantService.getBusinessConfig();
      if (config.sessionId == null) {
        state = WAConnectionState.notProvisioned;
        return;
      }

      final client = await _tenantService.getClient();
      await client.startSession(config.sessionId!);

      // Poll for QR code
      await _pollForQR(client, config.sessionId!);
    } catch (e) {
      _errorMessage = e.toString();
      state = WAConnectionState.error;
    }
  }

  /// Fetch the QR code for scanning.
  Future<void> fetchQRCode() async {
    try {
      final config = await _tenantService.getBusinessConfig();
      if (config.sessionId == null) return;

      final client = await _tenantService.getClient();
      _qrCode = await client.getQRCode(config.sessionId!);
      state = WAConnectionState.qrReady;
    } catch (e) {
      _errorMessage = e.toString();
      state = WAConnectionState.error;
    }
  }

  /// Disconnect the session.
  Future<void> disconnect() async {
    try {
      await _tenantService.disconnect();
      state = WAConnectionState.notProvisioned;
    } catch (e) {
      _errorMessage = e.toString();
      state = WAConnectionState.error;
    }
  }

  Future<void> _pollForQR(OpenWAClient client, String sessionId) async {
    for (var i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final session = await client.getSession(sessionId);
        if (session.status.isConnected) {
          state = WAConnectionState.connected;
          return;
        }
        if (session.status.needsQR) {
          _qrCode = await client.getQRCode(sessionId);
          state = WAConnectionState.qrReady;
          return;
        }
      } catch (_) {}
    }
    _errorMessage = 'QR code generation timed out';
    state = WAConnectionState.error;
  }
}

final waConnectionProvider =
    NotifierProvider<WAConnectionNotifier, WAConnectionState>(
  WAConnectionNotifier.new,
);

// ── Session Info ────────────────────────────────────────────────────────────

/// Current session info for the active business.
final waSessionProvider = FutureProvider<WASession?>((ref) async {
  final tenantService = ref.watch(openWATenantServiceProvider);
  try {
    final config = await tenantService.getBusinessConfig();
    if (!config.isProvisioned) return null;

    final client = await tenantService.getClient();
    return await client.getSession(config.sessionId!);
  } catch (_) {
    return null;
  }
});

// ── Chat List ───────────────────────────────────────────────────────────────

/// Chat list for the current business's WhatsApp session.
final waChatListProvider = FutureProvider<List<WAChat>>((ref) async {
  final tenantService = ref.watch(openWATenantServiceProvider);
  try {
    final config = await tenantService.getBusinessConfig();
    if (!config.isProvisioned) return [];

    final client = await tenantService.getClient();
    return await client.getChats(config.sessionId!);
  } catch (_) {
    return [];
  }
});

// ── Templates ───────────────────────────────────────────────────────────────

/// Template list for the current business's WhatsApp session.
final waTemplateListProvider = FutureProvider<List<WATemplate>>((ref) async {
  final tenantService = ref.watch(openWATenantServiceProvider);
  try {
    final config = await tenantService.getBusinessConfig();
    if (!config.isProvisioned) return [];

    final client = await tenantService.getClient();
    return await client.listTemplates(config.sessionId!);
  } catch (_) {
    return [];
  }
});

// ── Session Stats ───────────────────────────────────────────────────────────

/// Session statistics (total, active, ready, disconnected).
final waStatsProvider = FutureProvider<WASessionStats?>((ref) async {
  final tenantService = ref.watch(openWATenantServiceProvider);
  try {
    final client = await tenantService.getClient();
    return await client.getStats();
  } catch (_) {
    return null;
  }
});
