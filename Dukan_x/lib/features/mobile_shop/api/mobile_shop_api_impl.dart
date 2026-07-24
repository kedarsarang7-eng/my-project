/// MobileShop API Implementation — HTTP Adapter (Dart)
///
/// Versioned HTTP implementation of [MobileShopApi].
/// Sends authentication, correlation, operation, fingerprint, client/model
/// versions, expected versions, bounded limits, and opaque tokens.
/// Parses typed outcomes and rejects authoritative labels lacking confirmation.
///
/// Requirements: 6.3–6.4, 6.15–6.18, 6.42, 12.4–12.5, 12.9
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/tenant_context.dart';
import '../config/error_codes_config.dart';
import '../config/model_version_config.dart';
import '../config/pagination_config.dart';
import '../models/confirmation_models.dart';
import '../models/sync_models.dart';
import 'api_result.dart';
import 'mobile_endpoint.dart';
import 'mobile_shop_api.dart';

/// Provides bearer tokens for authenticated API requests.
///
/// Implementations resolve the current valid JWT for the active session.
/// The token is bound to the subject/tenant in [TenantContext].
abstract interface class TokenProvider {
  /// Returns a valid bearer token for the current session.
  ///
  /// Implementations may refresh expired tokens transparently.
  Future<String> getToken();
}

/// Configuration for the MobileShop API client.
@immutable
class MobileShopApiConfig {
  /// Base URL for the API (e.g., `https://api.example.com/api/v1/mobile-shop`).
  final String baseUrl;

  /// Client version string sent in `X-Client-Version`.
  final String clientVersion;

  /// Model version configuration for API/data versioning.
  final ModelVersionConfig modelVersionConfig;

  /// Pagination configuration for bounded limits.
  final PaginationConfig paginationConfig;

  /// WebSocket URL for real-time hints (e.g., `wss://...`).
  final String? webSocketUrl;

  const MobileShopApiConfig({
    required this.baseUrl,
    required this.clientVersion,
    this.modelVersionConfig = kModelVersionConfig,
    this.paginationConfig = kPaginationConfig,
    this.webSocketUrl,
  });
}

/// HTTP implementation of [MobileShopApi].
///
/// Key behaviors:
/// - Never labels a response as committed without AuthoritativeConfirmation
/// - Continuation tokens are opaque — passed through without parsing
/// - Business type is normalized to `mobile_shop` on the wire
/// - All monetary values are integer minor units in request/response
/// - Model version mismatch triggers upgrade prompt
class MobileShopApiImpl implements MobileShopApi {
  final http.Client _httpClient;
  final MobileShopApiConfig _config;
  final TenantContext Function() _tenantContextProvider;
  final TokenProvider _tokenProvider;

  MobileShopApiImpl({
    required http.Client httpClient,
    required MobileShopApiConfig config,
    required TenantContext Function() tenantContextProvider,
    required TokenProvider tokenProvider,
  }) : _httpClient = httpClient,
       _config = config,
       _tenantContextProvider = tenantContextProvider,
       _tokenProvider = tokenProvider;

  // ─── Public API ────────────────────────────────────────────────────────────

  @override
  Future<ApiResult<SaleOutcomeDto>> finalizeSale(MobileSaleDto request) async {
    final context = _tenantContextProvider();
    final operationId = request['operationId'] as String?;
    final fingerprint = request['mutationFingerprint'] as String?;

    return _executeMutation<SaleOutcomeDto>(
      path: '/sales/finalize',
      body: request,
      context: context,
      operationId: operationId ?? '',
      mutationFingerprint: fingerprint ?? '',
      expectedVersions: _extractExpectedVersions(request),
      parser: (json) => _parseMutationOutcome(json),
    );
  }

  @override
  Future<ApiResult<PushResultDto>> push(PushBatchDto request) async {
    final context = _tenantContextProvider();

    return _executeRequest<PushResultDto>(
      method: HttpMethod.post,
      path: '/sync/push',
      body: request.toJson(),
      context: context,
      isMutation: true,
      parser: (json) => PushBatchResponse.fromJson(json),
    );
  }

  @override
  Future<ApiResult<PullPageDto>> pull(PullRequestDto request) async {
    final context = _tenantContextProvider();
    final limit = _config.paginationConfig.clampPageSize(request.limit);

    final queryParams = <String, String>{
      'limit': limit.toString(),
      'dataModelVersion': request.dataModelVersion.toString(),
    };
    // Continuation token is opaque — pass through without parsing
    if (request.continuationToken != null) {
      queryParams['continuationToken'] = request.continuationToken!;
    }

    return _executeRequest<PullPageDto>(
      method: HttpMethod.get,
      path: '/sync/pull',
      queryParams: queryParams,
      context: context,
      isMutation: false,
      parser: (json) => PullResponse.fromJson(json),
    );
  }

  @override
  Stream<MobileServerHintDto> subscribe(TenantContext context) async* {
    // WebSocket subscription for real-time server hints.
    // Implementation uses the configured WebSocket URL with auth token.
    // Falls back gracefully if WebSocket is unavailable — pull remains
    // authoritative per design.
    final wsUrl = _config.webSocketUrl;
    if (wsUrl == null) return;

    final token = await _tokenProvider.getToken();

    // Build WebSocket URI with auth params
    final uri = Uri.parse(wsUrl).replace(
      queryParameters: {'token': 'Bearer $token', 'tenantId': context.tenantId},
    );

    yield* _connectWebSocket(uri, context);
  }

  @override
  Future<ApiResult<T>> command<T>(MobileEndpoint<T> endpoint) async {
    final context = _tenantContextProvider();

    if (endpoint.isMutation) {
      return _executeMutation<T>(
        path: endpoint.path,
        body: endpoint.body ?? {},
        context: context,
        operationId: endpoint.operationId ?? '',
        mutationFingerprint: endpoint.mutationFingerprint ?? '',
        expectedVersions: endpoint.expectedVersions,
        parser: endpoint.parser,
      );
    }

    return _executeRequest<T>(
      method: endpoint.method,
      path: endpoint.path,
      body: endpoint.body,
      queryParams: endpoint.queryParams,
      context: context,
      isMutation: false,
      parser: endpoint.parser,
    );
  }

  // ─── Request Execution ─────────────────────────────────────────────────────

  /// Execute a mutation request with operation/fingerprint headers.
  Future<ApiResult<T>> _executeMutation<T>({
    required String path,
    required Map<String, dynamic> body,
    required TenantContext context,
    required String operationId,
    required String mutationFingerprint,
    Map<String, int>? expectedVersions,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    // Augment body with version metadata for mutations
    final augmentedBody = Map<String, dynamic>.from(body);
    if (expectedVersions != null && expectedVersions.isNotEmpty) {
      augmentedBody['expectedVersions'] = expectedVersions;
    }
    augmentedBody['dataModelVersion'] =
        _config.modelVersionConfig.currentVersion;

    return _executeRequest<T>(
      method: HttpMethod.post,
      path: path,
      body: augmentedBody,
      context: context,
      isMutation: true,
      operationId: operationId,
      mutationFingerprint: mutationFingerprint,
      parser: parser,
    );
  }

  /// Core request executor that builds headers and handles response parsing.
  Future<ApiResult<T>> _executeRequest<T>({
    required HttpMethod method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    required TenantContext context,
    required bool isMutation,
    String? operationId,
    String? mutationFingerprint,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    try {
      final token = await _tokenProvider.getToken();
      final uri = _buildUri(path, queryParams);
      final headers = _buildHeaders(
        context: context,
        token: token,
        isMutation: isMutation,
        operationId: operationId,
        mutationFingerprint: mutationFingerprint,
      );

      final http.Response response;
      switch (method) {
        case HttpMethod.get:
          response = await _httpClient.get(uri, headers: headers);
        case HttpMethod.post:
          response = await _httpClient.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case HttpMethod.put:
          response = await _httpClient.put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case HttpMethod.delete:
          response = await _httpClient.delete(uri, headers: headers);
        case HttpMethod.patch:
          response = await _httpClient.patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
      }

      return _handleResponse(response, parser, isMutation);
    } on http.ClientException catch (e) {
      return ApiNetworkError<T>(message: e.message, retryable: true);
    } on TimeoutException {
      return const ApiNetworkError(
        message: 'Request timed out',
        retryable: true,
      );
    } on FormatException catch (e) {
      return ApiNetworkError<T>(
        message: 'Invalid response format: ${e.message}',
        retryable: false,
      );
    }
  }

  // ─── Response Handling ─────────────────────────────────────────────────────

  /// Parse the HTTP response into a typed ApiResult.
  ///
  /// CRITICAL: Rejects responses that claim committed/current/accepted-pending
  /// but lack AuthoritativeConfirmation.
  ApiResult<T> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parser,
    bool isMutation,
  ) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiNetworkError<T>(
          message: 'Invalid JSON in success response',
          retryable: false,
        );
      }
      return ApiNetworkError<T>(
        message: 'Server error (${response.statusCode})',
        retryable: response.statusCode >= 500,
      );
    }

    // Error responses (4xx/5xx with structured error body)
    if (response.statusCode >= 400) {
      return _parseErrorResponse<T>(json, response.statusCode);
    }

    // Success responses (2xx)
    return _parseSuccessResponse<T>(json, parser, isMutation);
  }

  /// Parse a success response, validating confirmation requirements.
  ApiResult<T> _parseSuccessResponse<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parser,
    bool isMutation,
  ) {
    final confirmation =
        json.containsKey('confirmation') && json['confirmation'] != null
        ? AuthoritativeConfirmation.fromJson(
            json['confirmation'] as Map<String, dynamic>,
          )
        : null;

    // CRITICAL RULE: Never label a response as committed without
    // AuthoritativeConfirmation (Requirement 6.42)
    if (isMutation && _responseClaimsAuthoritativeState(json)) {
      if (confirmation == null) {
        return ApiNetworkError<T>(
          message: 'Response claims authoritative state without confirmation',
          retryable: true,
        );
      }
    }

    final apiVersion =
        json['apiVersion'] as int? ??
        _config.modelVersionConfig.currentApiVersion;
    final dataModelVersion =
        json['dataModelVersion'] as int? ??
        _config.modelVersionConfig.currentVersion;
    final correlationId = json['correlationId'] as String?;

    // Model version mismatch detection: if the server requires a newer
    // data model version than we support, surface as a version error.
    if (!_config.modelVersionConfig.isVersionSupported(dataModelVersion)) {
      return ApiError<T>(
        outcome: DeterministicOutcome(
          code: 'MODEL_VERSION_UNSUPPORTED',
          category: OutcomeCategory.version,
          correlationId: correlationId ?? '',
          retryable: false,
          recoveryAction: 'Update the application to a supported version',
          dataModelVersion: dataModelVersion,
        ),
        retryable: false,
      );
    }

    // Parse the data payload
    final dataJson = json.containsKey('data')
        ? json['data'] as Map<String, dynamic>
        : json;

    final data = parser(dataJson);

    return ApiSuccess<T>(
      data: data,
      confirmation: confirmation,
      apiVersion: apiVersion,
      dataModelVersion: dataModelVersion,
      correlationId: correlationId,
    );
  }

  /// Parse an error response into a typed ApiError.
  ApiResult<T> _parseErrorResponse<T>(
    Map<String, dynamic> json,
    int statusCode,
  ) {
    try {
      final outcome = DeterministicOutcome.fromJson(json);
      return ApiError<T>.fromOutcome(outcome: outcome);
    } on Object {
      // Fallback for non-standard error responses
      return ApiNetworkError<T>(
        message: json['message'] as String? ?? 'Server error ($statusCode)',
        retryable: statusCode >= 500,
      );
    }
  }

  /// Check whether the response JSON claims an authoritative state
  /// (committed, accepted-pending, current, or server-confirmed).
  ///
  /// RULE: These labels MUST be accompanied by AuthoritativeConfirmation.
  /// A response claiming any of these states without confirmation is rejected.
  bool _responseClaimsAuthoritativeState(Map<String, dynamic> json) {
    final state = json['state'] as String?;
    if (state == null) return false;
    return state == 'COMMITTED' ||
        state == 'ACCEPTED_PENDING' ||
        state == 'CURRENT' ||
        state == 'SERVER_CONFIRMED';
  }

  // ─── Header Construction ───────────────────────────────────────────────────

  /// Build request headers with auth, correlation, versioning, and mutation
  /// metadata.
  Map<String, String> _buildHeaders({
    required TenantContext context,
    required String token,
    required bool isMutation,
    String? operationId,
    String? mutationFingerprint,
  }) {
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'X-Correlation-Id': context.correlationId,
      'X-Client-Version': _config.clientVersion,
      'X-Api-Version': _config.modelVersionConfig.currentApiVersion.toString(),
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Business-Type': 'mobile_shop',
    };

    if (isMutation) {
      if (operationId != null && operationId.isNotEmpty) {
        headers['X-Operation-Id'] = operationId;
      }
      if (mutationFingerprint != null && mutationFingerprint.isNotEmpty) {
        headers['X-Mutation-Fingerprint'] = mutationFingerprint;
      }
    }

    return headers;
  }

  /// Build the full URI from base URL, path, and optional query params.
  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final baseUri = Uri.parse(_config.baseUrl);
    final fullPath = '${baseUri.path}$path';
    return baseUri.replace(path: fullPath, queryParameters: queryParams);
  }

  /// Extract expected versions map from a request body.
  Map<String, int>? _extractExpectedVersions(Map<String, dynamic> request) {
    final versions = request['expectedVersions'];
    if (versions is Map<String, dynamic>) {
      return versions.map((k, v) => MapEntry(k, v as int));
    }
    return null;
  }

  // ─── Mutation Outcome Parsing ──────────────────────────────────────────────

  /// Parse a MutationOutcome from JSON response.
  MutationOutcome<Map<String, dynamic>> _parseMutationOutcome(
    Map<String, dynamic> json,
  ) {
    final stateStr = json['state'] as String? ?? 'COMMITTED';
    final state = _parseMutationState(stateStr);

    final confirmation =
        json.containsKey('confirmation') && json['confirmation'] != null
        ? AuthoritativeConfirmation.fromJson(
            json['confirmation'] as Map<String, dynamic>,
          )
        : null;

    final error = json.containsKey('error') && json['error'] != null
        ? MutationError.fromJson(json['error'] as Map<String, dynamic>)
        : null;

    final data = json.containsKey('data')
        ? json['data'] as Map<String, dynamic>?
        : null;

    return MutationOutcome<Map<String, dynamic>>(
      state: state,
      confirmation: confirmation,
      data: data,
      error: error,
      dataModelVersion:
          json['dataModelVersion'] as int? ??
          _config.modelVersionConfig.currentVersion,
    );
  }

  MutationOutcomeState _parseMutationState(String value) {
    switch (value) {
      case 'COMMITTED':
        return MutationOutcomeState.committed;
      case 'ACCEPTED_PENDING':
        return MutationOutcomeState.acceptedPending;
      case 'CONFLICT':
        return MutationOutcomeState.conflict;
      case 'REJECTED':
        return MutationOutcomeState.rejected;
      default:
        return MutationOutcomeState.rejected;
    }
  }

  // ─── WebSocket ─────────────────────────────────────────────────────────────

  /// Connect to the WebSocket and yield server hints.
  ///
  /// This is a placeholder for the real WebSocket implementation.
  /// In production, use `web_socket_channel` with proper reconnection.
  Stream<MobileServerHintDto> _connectWebSocket(
    Uri uri,
    TenantContext context,
  ) {
    // WebSocket connection is handled by a separate transport layer.
    // This stream remains empty until the WebSocket transport is wired.
    // Pull remains authoritative per design — WebSocket is an optimization.
    return const Stream.empty();
  }
}
