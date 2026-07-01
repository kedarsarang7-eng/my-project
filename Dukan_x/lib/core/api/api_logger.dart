// ============================================================================
// API Logger — CloudWatch-friendly structured logging
// ============================================================================
// Produces structured JSON log entries for API requests, errors, and auth
// events. Compatible with AWS CloudWatch Logs when forwarded via backend.
// ============================================================================

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import '../services/logger_service.dart';

/// Structured API logger for production monitoring.
///
/// Log entries follow a consistent JSON format:
/// ```json
/// {
///   "type": "api_request",
///   "method": "POST",
///   "url": "/api/v1/sync/push",
///   "status": 200,
///   "latency_ms": 145,
///   "timestamp": "2026-02-26T12:00:00.000Z"
/// }
/// ```
class ApiLogger {
  static const String _logName = 'DukanX.API';

  /// Log a successful API request with latency.
  void logRequest(String method, String url, int statusCode, int latencyMs, {String? correlationId}) {
    final sanitizedUrl = _sanitizeUrl(url);
    _log('api_request', {
      'method': method,
      'url': sanitizedUrl,
      'status': statusCode,
      'latency_ms': latencyMs,
      // LOW FIX: Include correlation ID for backend traceability
      'correlation_id': ?correlationId,
    });

    // Warn on slow requests (> 5s)
    if (latencyMs > 5000) {
      _log('slow_request', {
        'method': method,
        'url': sanitizedUrl,
        'latency_ms': latencyMs,
        'correlation_id': ?correlationId,
      });
    }
  }

  /// Log an API error response.
  void logError(
    String method,
    String path,
    int statusCode,
    String error, {
    Map<String, dynamic>? additionalData,
  }) {
    _log('api_error', {
      'method': method,
      'url': _sanitizeUrl(path),
      'status': statusCode,
      'error': _truncate(error, 500),
      ...?additionalData,
    });
  }

  /// Log warning events.
  void logWarning(String message, {Map<String, dynamic>? additionalData}) {
    _log('warning', {'message': _truncate(message, 500), ...?additionalData});
  }

  /// Log informational events.
  void logInfo(String message, {Map<String, dynamic>? additionalData}) {
    _log('info', {'message': _truncate(message, 500), ...?additionalData});
  }

  /// Log authentication failure (401/403).
  void logAuthFailure(String method, String path) {
    _log('auth_failure', {
      'method': method,
      'url': _sanitizeUrl(path),
      'event': 'token_expired_or_invalid',
    });
  }

  /// Log network error (no connectivity, DNS failure, etc.).
  void logNetworkError(String method, String path, String error) {
    _log('network_error', {
      'method': method,
      'url': _sanitizeUrl(path),
      'error': _truncate(error, 300),
    });
  }

  /// Log request timeout.
  void logTimeout(String method, String path) {
    _log('request_timeout', {'method': method, 'url': _sanitizeUrl(path)});
  }

  /// Log offline state detected before request.
  void logOffline(String method, String path) {
    _log('offline', {
      'method': method,
      'url': _sanitizeUrl(path),
      'event': 'no_internet_connection',
    });
  }

  /// Log token refresh attempt.
  void logTokenRefresh(bool success) {
    _log('token_refresh', {'success': success});
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Emit a structured log entry.
  void _log(String type, Map<String, dynamic> fields) {
    final entry = {
      'type': type,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      ...fields,
    };

    final jsonString = jsonEncode(entry);

    // Use dart:developer for structured logging (captured by IDE and observers)
    developer.log(
      jsonString,
      name: _logName,
      level: type.contains('error') || type.contains('failure') ? 900 : 800,
    );

    // Also print in debug mode for console visibility
    if (kDebugMode) {
      LoggerService.d('ApiLogger', '[$_logName] $jsonString');
    }
  }

  /// Remove sensitive query parameters from URLs before logging.
  String _sanitizeUrl(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return url;

      // Strip query params that might contain tokens
      final sensitiveKeys = {
        'token',
        'access_token',
        'api_key',
        'key',
        'secret',
      };
      if (uri.queryParameters.keys.any(sensitiveKeys.contains)) {
        final safeParams = Map<String, String>.from(uri.queryParameters);
        for (final key in sensitiveKeys) {
          if (safeParams.containsKey(key)) {
            safeParams[key] = '***';
          }
        }
        return uri.replace(queryParameters: safeParams).toString();
      }

      // For full URLs, keep only the path portion for readability
      if (url.startsWith('http')) {
        return '${uri.path}${uri.hasQuery ? '?...' : ''}';
      }
      return url;
    } catch (_) {
      return url;
    }
  }

  /// Truncate long strings for log safety.
  String _truncate(String value, int maxLen) {
    if (value.length <= maxLen) return value;
    return '${value.substring(0, maxLen)}...';
  }
}
