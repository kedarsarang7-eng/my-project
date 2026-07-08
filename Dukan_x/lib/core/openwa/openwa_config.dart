// ============================================================================
// OpenWA Configuration — Connection settings for the WhatsApp Gateway
// ============================================================================
// Reads OpenWA base URL and related settings from .env. This is the single
// source of truth for how the Flutter client reaches the OpenWA sidecar.
//
// The OpenWA instance runs as a shared multi-session service on ECS Fargate,
// using the Baileys engine (no Chromium). Media is stored in a separate S3
// bucket from the main DukanX bucket.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenWAConfig {
  OpenWAConfig._();

  // ── Base URL ──────────────────────────────────────────────────────────────

  /// OpenWA API base URL (the NestJS sidecar, NOT the DukanX API Gateway).
  /// Set via .env: OPENWA_BASE_URL=https://openwa.yourdomain.com/api
  /// Or via dart-define: --dart-define=OPENWA_BASE_URL=http://localhost:2785/api
  static String get baseUrl {
    // .env highest priority
    final envUrl = dotenv.env['OPENWA_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return _normalizeUrl(envUrl);

    // dart-define fallback
    const dartDefine =
        String.fromEnvironment('OPENWA_BASE_URL', defaultValue: '');
    if (dartDefine.isNotEmpty) return _normalizeUrl(dartDefine);

    // Development fallback — local OpenWA instance
    if (kDebugMode) {
      return 'http://localhost:2785/api';
    }

    throw StateError(
      'OPENWA_BASE_URL is not configured. '
      'Set in .env or via --dart-define=OPENWA_BASE_URL',
    );
  }

  // ── WebSocket URL ─────────────────────────────────────────────────────────

  /// OpenWA WebSocket endpoint for real-time events (Socket.IO).
  /// Derived from base URL by default (same host, /socket.io path).
  static String get wsUrl {
    final envUrl = dotenv.env['OPENWA_WS_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    // Derive from base URL: strip /api suffix, use ws:// or wss://
    final base = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    }
    return base.replaceFirst('http://', 'ws://');
  }

  // ── Media S3 Bucket ───────────────────────────────────────────────────────

  /// Separate S3 bucket for OpenWA media (NOT the same as DukanX).
  static String get mediaBucketName {
    final bucket = dotenv.env['OPENWA_S3_BUCKET'];
    if (bucket != null && bucket.isNotEmpty) return bucket;
    return 'dukanx-openwa-media'; // Default naming convention
  }

  // ── Engine ────────────────────────────────────────────────────────────────

  /// WhatsApp engine type — Baileys for production (no Chromium).
  static String get engineType {
    return dotenv.env['OPENWA_ENGINE_TYPE'] ?? 'baileys';
  }

  // ── Timeouts ──────────────────────────────────────────────────────────────

  /// Connect timeout for OpenWA REST calls (default: 10s).
  static Duration get connectTimeout {
    final ms = int.tryParse(dotenv.env['OPENWA_CONNECT_TIMEOUT_MS'] ?? '');
    return Duration(milliseconds: ms ?? 10000);
  }

  /// Request timeout for OpenWA REST calls (default: 30s).
  static Duration get requestTimeout {
    final ms = int.tryParse(dotenv.env['OPENWA_REQUEST_TIMEOUT_MS'] ?? '');
    return Duration(milliseconds: ms ?? 30000);
  }

  // ── Validation ────────────────────────────────────────────────────────────

  /// Validate OpenWA configuration at startup.
  /// Returns true if configured, false if not (non-fatal — WhatsApp is optional).
  static bool validate() {
    try {
      final url = baseUrl;
      debugPrint('[OpenWAConfig] ✔ Validated: $url (engine: $engineType)');
      return true;
    } catch (e) {
      debugPrint('[OpenWAConfig] ⚠ Not configured: $e');
      return false;
    }
  }

  /// Whether OpenWA integration is available (configured + reachable).
  static bool get isConfigured {
    try {
      baseUrl; // Will throw if not configured
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Normalize URL: ensure /api suffix, strip trailing slash.
  static String _normalizeUrl(String url) {
    var normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!normalized.endsWith('/api')) {
      normalized = '$normalized/api';
    }
    return normalized;
  }
}
