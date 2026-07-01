// ignore_for_file: cancel_subscriptions
// ============================================================================
// Secure API Client — Production-grade HTTP wrapper
// ============================================================================
// Features:
// - Automatic Cognito JWT token attachment
// - Automatic token refresh on 401
// - Retry with exponential backoff for 5xx / network errors
// - Configurable timeouts with keep-alive connections
// - Structured logging for CloudWatch
// - Offline detection
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../security/network/pinned_http_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/api_config.dart';
import '../di/service_locator.dart';
import '../mode/mode_manager.dart';
import '../request_context/request_context.dart';
import '../session/session_manager.dart';
import 'api_logger.dart';

/// Result wrapper for API responses.
class ApiResponse<T> {
  final int statusCode;
  final T? data;
  final String? error;
  final String? code;
  final bool isSuccess;
  // LOW FIX: Correlation ID for request tracing across frontend-backend
  final String? correlationId;

  const ApiResponse({
    required this.statusCode,
    this.data,
    this.error,
    this.code,
    required this.isSuccess,
    this.correlationId,
  });

  factory ApiResponse.success(
    int statusCode,
    T data, {
    String? correlationId,
  }) => ApiResponse(
    statusCode: statusCode,
    data: data,
    isSuccess: true,
    correlationId: correlationId,
  );

  factory ApiResponse.failure(
    int statusCode,
    String error, {
    String? code,
    String? correlationId,
  }) => ApiResponse(
    statusCode: statusCode,
    error: error,
    code: code,
    isSuccess: false,
    correlationId: correlationId,
  );

  factory ApiResponse.offline() => const ApiResponse(
    statusCode: -1, // HIGH FIX: Use -1 for offline instead of 0
    error: 'No internet connection',
    code: 'OFFLINE',
    isSuccess: false,
  );

  /// HIGH FIX: Network error (SocketException)
  factory ApiResponse.networkError(String message) => ApiResponse(
    statusCode: -2,
    error: message,
    code: 'NETWORK_ERROR',
    isSuccess: false,
  );

  /// HIGH FIX: Request timeout
  factory ApiResponse.timeout() => const ApiResponse(
    statusCode: -3,
    error: 'Request timed out',
    code: 'TIMEOUT',
    isSuccess: false,
  );

  /// HIGH FIX: Connection failed (ClientException)
  factory ApiResponse.connectionFailed(String message) => ApiResponse(
    statusCode: -4,
    error: message,
    code: 'CONNECTION_FAILED',
    isSuccess: false,
  );

  /// Convenience alias for [error] used across the codebase.
  String? get errorMessage => error;

  /// HIGH FIX: Check if this is a network-related error (negative status code)
  bool get isNetworkError => statusCode < 0;

  /// HIGH FIX: Get user-friendly error message
  String get userMessage {
    if (isSuccess) return 'Success';
    if (isNetworkError) {
      if (statusCode == -1) {
        return 'No internet connection. Please check your network.';
      }
      if (statusCode == -2) return 'Network error. Please try again.';
      if (statusCode == -3) return 'Request timed out. Please try again.';
      if (statusCode == -4) return 'Connection failed. Please try again.';
    }
    return error ?? 'Something went wrong';
  }
}

/// Exception for API errors with structured context.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final String? responseBody;
  final String? url;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.responseBody,
    this.url,
  });

  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isThrottled => statusCode == 429;
  bool get isServerError => statusCode >= 500;
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  @override
  String toString() =>
      'ApiException($statusCode): $message${url != null ? ' [$url]' : ''}';
}

/// Callback type for obtaining the current Cognito JWT access token.
typedef TokenProvider = Future<String?> Function();

/// Callback type for refreshing an expired Cognito session.
typedef TokenRefresher = Future<String?> Function();

/// Production-grade HTTP client for DukanX.
///
/// Usage:
/// ```dart
/// final client = ApiClient(
///   tokenProvider: () => sessionManager.getIdToken(),
///   tokenRefresher: () => sessionManager.refreshSession(),
/// );
///
/// final response = await client.get('/api/v1/products');
/// ```
/// Callback invoked when a 401 cannot be recovered by token refresh.
/// Use this to force-logout the user and redirect to login.
typedef SessionExpiredCallback = void Function();

class ApiClient {
  final String? _baseUrl;
  final TokenProvider? _tokenProvider;
  final TokenRefresher? _tokenRefresher;
  final SessionExpiredCallback? _onSessionExpired;
  final http.Client _httpClient;
  final ApiLogger _logger;
  final Duration _requestTimeout;
  final int _maxRetries;

  // OFFLINE-LICENSE-ACTIVATION (Task 1.3): the single online/offline switch
  // point. When set, the active backend base URL is resolved from
  // Mode_Manager (AWS host in Cloud_Subscription_Mode, the Local_Backend
  // loopback in Offline_Lifetime_Mode). This is injected for tests; in
  // production it is resolved lazily from the service locator (see [baseUrl]).
  final ModeManager? _modeManager;

  // AUDIT FIX #28: Cached connectivity to avoid checking on every request
  static List<ConnectivityResult>? _cachedConnectivity;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  ApiClient({
    String? baseUrl,
    TokenProvider? tokenProvider,
    TokenRefresher? tokenRefresher,
    SessionExpiredCallback? onSessionExpired,
    http.Client? httpClient,
    Duration? connectTimeout,
    Duration? requestTimeout,
    int? maxRetries,
    ModeManager? modeManager,
  }) : _baseUrl = baseUrl,
       _tokenProvider = tokenProvider,
       _tokenRefresher = tokenRefresher,
       _onSessionExpired = onSessionExpired,
       _httpClient = httpClient ?? createPinnedHttpClient(),
       _logger = ApiLogger(),
       _requestTimeout = requestTimeout ?? ApiConfig.requestTimeout,
       _maxRetries = maxRetries ?? ApiConfig.maxRetries,
       _modeManager = modeManager {
    // Start listening to connectivity changes once
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((result) {
      _cachedConnectivity = result;
    });
  }

  /// Resolved base URL — the single online/offline switch point.
  ///
  /// Resolution order (Requirements 1.4, 1.5, 1.6, 1.7):
  /// 1. An explicit per-instance [baseUrl] override always wins (used by
  ///    purpose-built clients and tests).
  /// 2. Otherwise the active backend target is resolved from [ModeManager]
  ///    (Cloud_Subscription_Mode -> AWS host == `ApiConfig.baseUrl`;
  ///    Offline_Lifetime_Mode -> `http://127.0.0.1:8765`). Mode_Manager reads
  ///    its *cached* active mode, so this stays synchronous exactly where the
  ///    client previously read `ApiConfig.baseUrl`.
  /// 3. If no Mode_Manager was injected and none is registered with the
  ///    service locator, it falls back to `ApiConfig.baseUrl` — byte-for-byte
  ///    the pre-feature Cloud_Subscription_Mode behavior (Requirement 2.1).
  ///
  /// The active mode/target is never returned to or read by the Flutter UI;
  /// resolution lives entirely at the service layer (Requirement 1.6).
  String get baseUrl {
    final override = _baseUrl;
    if (override != null) return override;

    final modeManager = _resolveModeManager();
    if (modeManager != null) {
      return modeManager.activeBackendBaseUri().toString();
    }

    // No Mode_Manager available: preserve the original cloud baseline exactly.
    return ApiConfig.baseUrl;
  }

  /// Returns the injected [ModeManager], or the one registered with the service
  /// locator when available. Returns `null` (cloud-baseline fallback) if
  /// resolution is unavailable, so the client never throws while resolving a
  /// base URL.
  ModeManager? _resolveModeManager() {
    if (_modeManager != null) return _modeManager;
    try {
      if (sl.isRegistered<ModeManager>()) {
        return sl<ModeManager>();
      }
    } catch (_) {
      // Service locator not ready (e.g. early bootstrap or unit tests) — fall
      // back to the cloud baseline below.
    }
    return null;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// HTTP GET with auto auth and retry.
  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    return _executeWithRetry(
      method: 'GET',
      path: path,
      queryParams: queryParams ?? queryParameters,
      extraHeaders: headers,
      requireAuth: requireAuth,
    );
  }

  /// HTTP POST with auto auth and retry.
  ///
  /// `idempotencyKey` (clause 2.10 of `bugfix.md`) is sent as the
  /// `Idempotency-Key` header. The backend uses it to dedupe replays from
  /// flaky networks, forced-kill mid-write, and multi-device retries.
  /// Callers that mutate state should always pass a stable key
  /// (`Uuid.v4()` is the documented default).
  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    return _executeWithRetry(
      method: 'POST',
      path: path,
      body: body,
      extraHeaders: _withIdempotencyKey(headers, idempotencyKey),
      requireAuth: requireAuth,
    );
  }

  /// HTTP PUT with auto auth and retry.
  ///
  /// See [post] for `idempotencyKey` semantics.
  Future<ApiResponse<Map<String, dynamic>>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    return _executeWithRetry(
      method: 'PUT',
      path: path,
      body: body,
      extraHeaders: _withIdempotencyKey(headers, idempotencyKey),
      requireAuth: requireAuth,
    );
  }

  /// HTTP PATCH with auto auth and retry.
  ///
  /// See [post] for `idempotencyKey` semantics.
  Future<ApiResponse<Map<String, dynamic>>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    return _executeWithRetry(
      method: 'PATCH',
      path: path,
      body: body,
      extraHeaders: _withIdempotencyKey(headers, idempotencyKey),
      requireAuth: requireAuth,
    );
  }

  /// HTTP DELETE with auto auth and retry.
  ///
  /// See [post] for `idempotencyKey` semantics.
  Future<ApiResponse<Map<String, dynamic>>> delete(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    return _executeWithRetry(
      method: 'DELETE',
      path: path,
      queryParams: queryParams,
      extraHeaders: _withIdempotencyKey(headers, idempotencyKey),
      requireAuth: requireAuth,
    );
  }

  /// Compose an `Idempotency-Key` header into the caller's header map.
  /// Returns the original map untouched when `key` is null so callers
  /// without dedupe semantics see no behavior change.
  Map<String, String>? _withIdempotencyKey(
    Map<String, String>? base,
    String? key,
  ) {
    if (key == null || key.isEmpty) return base;
    final merged = <String, String>{...?base, 'Idempotency-Key': key};
    return merged;
  }

  /// Release HTTP client resources.
  void dispose() {
    _httpClient.close();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Execute request with retry logic and token refresh.
  Future<ApiResponse<Map<String, dynamic>>> _executeWithRetry({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? extraHeaders,
    required bool requireAuth,
  }) async {
    // 0. Preemptive token refresh to avoid first-call 401 penalty.
    if (requireAuth) {
      try {
        final token = await _tokenProvider?.call();
        if (token == null || token.isEmpty) {
          _logger.logWarning('Auth token not available for $method $path');
          return ApiResponse.failure(
            401,
            'Session expired. Please login again.',
            code: 'AUTH_TOKEN_MISSING',
          );
        }

        if (_isJwtExpiringSoon(token)) {
          _logger.logInfo(
            'Token expiring soon, preemptively refreshing',
            additionalData: {'method': method, 'path': path},
          );
          final newToken = await _tokenRefresher?.call();
          if (newToken == null || newToken.isEmpty) {
            return ApiResponse.failure(
              401,
              'Session expired. Please login again.',
              code: 'AUTH_TOKEN_EXPIRED',
            );
          }
        }
      } catch (e) {
        _logger.logWarning(
          'Token refresh precheck failed: $e',
          additionalData: {'method': method, 'path': path},
        );
      }
    }

    // 1. Offline check (AUDIT FIX #28: use cached connectivity, no per-request poll)
    if (!kIsWeb) {
      final cached = _cachedConnectivity;
      if (cached != null && cached.contains(ConnectivityResult.none)) {
        _logger.logOffline(method, path);
        return ApiResponse.offline();
      }
    }

    // 2. Retry loop
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await _executeRequest(
          method: method,
          path: path,
          body: body,
          queryParams: queryParams,
          extraHeaders: extraHeaders,
          requireAuth: requireAuth,
        );

        // 3. Handle 401 — token refresh + single retry
        if (response.statusCode == 401 && requireAuth && attempt == 1) {
          _logger.logAuthFailure(method, path);
          final newToken = await _tokenRefresher?.call();
          if (newToken != null) {
            // Retry with refreshed token
            continue;
          }
          // Refresh failed — session is unrecoverable, force logout
          _logger.logWarning(
            'Token refresh failed on 401, firing session-expired callback',
          );
          _onSessionExpired?.call();
        }

        // 4. Parse response
        final parsed = _parseResponse(response, method, path);

        // 5. AUDIT FIX #7: Retry on 5xx (Lambda cold start, transient errors)
        if (response.statusCode >= 500 && attempt < _maxRetries) {
          _logger.logWarning(
            '5xx response (${response.statusCode}) on $method $path, '
            'retrying (attempt $attempt/$_maxRetries)...',
          );
          await _backoff(attempt);
          continue;
        }

        return parsed;
      } on SocketException catch (e) {
        if (attempt >= _maxRetries) {
          _logger.logNetworkError(method, path, e.toString());
          // HIGH FIX: Use specific network error response instead of status 0
          return ApiResponse.networkError('Network error: ${e.message}');
        }
        await _backoff(attempt);
      } on TimeoutException catch (_) {
        if (attempt >= _maxRetries) {
          _logger.logTimeout(method, path);
          // HIGH FIX: Use specific timeout response instead of status 0
          return ApiResponse.timeout();
        }
        await _backoff(attempt);
      } on http.ClientException catch (e) {
        if (attempt >= _maxRetries) {
          _logger.logNetworkError(method, path, e.toString());
          // HIGH FIX: Use specific connection failed response instead of status 0
          return ApiResponse.connectionFailed(
            'Connection failed: ${e.message}',
          );
        }
        await _backoff(attempt);
      } on ApiException catch (e) {
        return ApiResponse.failure(e.statusCode, e.message, code: e.code);
      } catch (e) {
        _logger.logError(method, path, 0, e.toString());
        // HIGH FIX: Still use 0 for truly unexpected errors, but add code
        return ApiResponse.failure(
          0,
          'Unexpected error: $e',
          code: 'UNEXPECTED_ERROR',
        );
      }
    }
  }

  /// Execute a single HTTP request.
  Future<http.Response> _executeRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? extraHeaders,
    required bool requireAuth,
  }) async {
    // Build headers
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Version': '3.0.0',
      'X-Environment': ApiConfig.environmentName,
    };

    // Attach JWT token and tenant context headers
    if (requireAuth) {
      final token = await _tokenProvider?.call();
      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          message: 'Session expired. Please login again.',
          code: 'AUTH_TOKEN_MISSING',
        );
      }
      headers['Authorization'] = 'Bearer $token';

      // Extract tenant and business context.
      // Prefer Cognito JWT-derived tenant ID to avoid stale-cache conflicts
      // with the backend's cross-tenant detection logic.
      String? tenantId;
      String? activeBusinessId;
      try {
        // First try extracting from session manager (Cognito ID token)
        final sessionMgr = sl<SessionManager>();
        final cognitoUser = await sessionMgr.currentCognitoUser;
        if (cognitoUser != null) {
          final session = await cognitoUser.getSession();
          if (session != null && session.isValid()) {
            final payload = session.getIdToken().payload;
            tenantId = payload['custom:tenant_id'] as String?;
          }
        }
      } on Exception catch (e) {
        _logger.logError(
          method,
          path,
          0,
          'Failed to extract tenant from Cognito: $e',
        );
      }

      // Fall back to secure storage if JWT extraction fails
      // SEC-02 FIX: Use flutter_secure_storage instead of SharedPreferences
      if (tenantId == null || tenantId.isEmpty) {
        try {
          const secureStorage = FlutterSecureStorage();
          tenantId = await secureStorage.read(key: 'session_tenant_id');
          if (tenantId == null || tenantId.isEmpty) {
            tenantId = await secureStorage.read(key: 'session_shop_id');
          }
        } on Exception catch (e) {
          _logger.logError(
            method,
            path,
            0,
            'Failed to load tenant from storage: $e',
          );
        }
      }

      try {
        const secureStorage = FlutterSecureStorage();
        activeBusinessId = await secureStorage.read(key: 'active_business_id');
      } catch (_) {}

      if (tenantId == null || tenantId.isEmpty) {
        _logger.logWarning('No tenant context available for $method $path');
        throw const ApiException(
          statusCode: 400,
          message: 'Tenant context not available. Please login again.',
          code: 'MISSING_TENANT_CONTEXT',
        );
      }

      headers['x-tenant-id'] = tenantId;
      // Use active business or fall back to tenant for single-business setups
      headers['x-active-business'] =
          (activeBusinessId != null && activeBusinessId.isNotEmpty)
          ? activeBusinessId
          : tenantId;
    }

    // =========================================================================
    // RID (Request ID) HEADER INJECTION
    // =========================================================================
    // Inject X-Request-ID for request tracing across the stack
    try {
      final requestContext = sl.isRegistered<RequestContext>()
          ? sl<RequestContext>()
          : null;
      if (requestContext != null) {
        headers['X-Request-ID'] = requestContext.requestId;
        headers['X-Request-Ref'] = requestContext.shortReference;
        _logger.logInfo(
          'RID attached',
          additionalData: {
            'rid': requestContext.shortReference,
            'path': path,
            'method': method,
          },
        );
      } else {
        // Generate emergency RID if no context exists
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final emergencyRid =
            'emergency-$timestamp-${100000 + DateTime.now().millisecond}';
        headers['X-Request-ID'] = emergencyRid;
        _logger.logWarning(
          'No RequestContext found, using emergency RID',
          additionalData: {'rid': emergencyRid, 'path': path},
        );
      }
    } catch (e) {
      // Don't fail the request if RID injection fails
      _logger.logWarning(
        'RID injection failed: $e',
        additionalData: {'path': path},
      );
    }
    // =========================================================================

    // Merge extra headers
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    // Execute request with timeout
    final candidates = _buildPathCandidates(path);
    late http.Response response;
    late Uri usedUri;
    final stopwatch = Stopwatch()..start();

    for (final candidate in candidates) {
      final fullUrl = candidate.startsWith('http')
          ? candidate
          : '$baseUrl$candidate';
      var uri = Uri.parse(fullUrl);
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(
          queryParameters: {...uri.queryParameters, ...queryParams},
        );
      }

      response = await _sendHttpRequest(
        method: method,
        uri: uri,
        headers: headers,
        body: body,
      );
      usedUri = uri;

      // Stop on first non-404 response.
      if (response.statusCode != 404) {
        break;
      }
    }

    // If all candidates return 404, use last tried response.
    if (response.statusCode == 404) {
      usedUri = Uri.parse(
        candidates.last.startsWith('http')
            ? candidates.last
            : '$baseUrl${candidates.last}',
      );
      if (queryParams != null && queryParams.isNotEmpty) {
        usedUri = usedUri.replace(
          queryParameters: {...usedUri.queryParameters, ...queryParams},
        );
      }
    }

    stopwatch.stop();

    // LOW FIX: Extract correlation ID for request logging
    final correlationId =
        response.headers['x-correlation-id'] ??
        response.headers['X-Correlation-Id'];

    _logger.logRequest(
      method,
      usedUri.toString(),
      response.statusCode,
      stopwatch.elapsedMilliseconds,
      // LOW FIX: Include correlation ID in logs for backend traceability
      correlationId: correlationId,
    );

    return response;
  }

  Future<http.Response> _sendHttpRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) async {
    switch (method.toUpperCase()) {
      case 'GET':
        return _httpClient.get(uri, headers: headers).timeout(_requestTimeout);
      case 'POST':
        return _httpClient
            .post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_requestTimeout);
      case 'PUT':
        return _httpClient
            .put(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_requestTimeout);
      case 'PATCH':
        return _httpClient
            .patch(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_requestTimeout);
      case 'DELETE':
        return _httpClient
            .delete(uri, headers: headers)
            .timeout(_requestTimeout);
      default:
        throw ApiException(
          statusCode: 0,
          message: 'Unsupported method: $method',
        );
    }
  }

  /// AUDIT FIX #9: Simplified path resolution — canonical path only.
  /// Strips /api/v1/ and /api/ prefixes to match backend routes directly.
  /// Keeps bills↔invoices alias since both are used across the codebase.
  List<String> _buildPathCandidates(String path) {
    if (path.startsWith('http')) return [path];

    // Normalize: strip /api/v1/ or /api/ prefix → backend uses bare paths
    String canonical = path;
    if (canonical.startsWith('/api/v1/')) {
      canonical = '/${canonical.substring('/api/v1/'.length)}';
    } else if (canonical.startsWith('/api/')) {
      canonical = '/${canonical.substring('/api/'.length)}';
    } else if (canonical.startsWith('/v1/')) {
      canonical = '/${canonical.substring('/v1/'.length)}';
    }

    final candidates = <String>[canonical];

    // bills ↔ invoices alias (backend uses /invoices, legacy code uses /bills)
    if (canonical.contains('/bills')) {
      candidates.add(canonical.replaceFirst('/bills', '/invoices'));
    } else if (canonical.contains('/invoices')) {
      candidates.add(canonical.replaceFirst('/invoices', '/bills'));
    }

    return candidates;
  }

  /// Parse HTTP response into typed ApiResponse.
  ApiResponse<Map<String, dynamic>> _parseResponse(
    http.Response response,
    String method,
    String path,
  ) {
    // LOW FIX: Extract correlation ID from response headers for all responses
    final correlationId =
        response.headers['x-correlation-id'] ??
        response.headers['X-Correlation-Id'];

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        if (response.body.isEmpty) {
          return ApiResponse.success(
            response.statusCode,
            {},
            correlationId: correlationId,
          );
        }
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return ApiResponse.success(
            response.statusCode,
            data,
            correlationId: correlationId,
          );
        }
        return ApiResponse.success(response.statusCode, {
          'data': data,
        }, correlationId: correlationId);
      } catch (e) {
        return ApiResponse.success(response.statusCode, {
          'raw': response.body,
        }, correlationId: correlationId);
      }
    }

    // Error responses
    String errorMessage;
    String? errorCode;
    try {
      final errorData = jsonDecode(response.body);
      errorMessage =
          errorData['error'] ?? errorData['message'] ?? response.body;
      errorCode = errorData is Map<String, dynamic>
          ? errorData['code'] as String?
          : null;
    } catch (_) {
      errorMessage = response.body.isNotEmpty
          ? response.body
          : 'HTTP ${response.statusCode}';
    }

    _logger.logError(
      method,
      path,
      response.statusCode,
      errorMessage,
      additionalData: {
        'code': errorCode,
        // LOW FIX: Include correlation ID in logs for backend traceability
        'correlationId': correlationId,
      },
    );
    return ApiResponse.failure(
      response.statusCode,
      errorMessage,
      code: errorCode,
      // LOW FIX: Store correlation ID in response for app-level error handling
      correlationId: correlationId,
    );
  }

  /// Exponential backoff delay.
  Future<void> _backoff(int attempt) async {
    final delay = ApiConfig.retryBaseDelay * (1 << (attempt - 1));
    await Future.delayed(delay);
  }

  bool _isJwtExpiringSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final normalized = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return false;

      final expiryTime = DateTime.fromMillisecondsSinceEpoch(
        (exp.toInt()) * 1000,
      );
      return DateTime.now()
          .add(const Duration(seconds: 60))
          .isAfter(expiryTime);
    } catch (_) {
      return false;
    }
  }
}
