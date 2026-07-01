// ============================================================================
// ACTIVATION_TRANSPORT — one-time online call to the License_Server
// ============================================================================
// Feature: offline-license-activation (Task 4.3)
//
// Sends the license key + Machine_Fingerprint to the License_Server endpoint
// `POST /license/activate-offline` (added by task 3.2) and classifies the
// outcome into exactly the three cases the Activation_Service needs to honour
// Requirements 5.3, 5.11, 5.12:
//
//   * [ActivationTransportSuccess]     — 2xx; carries the OfflineActivationResult.
//   * [ActivationTransportRejected]    — a DEFINITIVE 4xx server "no" (invalid/
//                                        expired/revoked/denylisted/allowance
//                                        exhausted). Maps to ActivationFailed.
//   * [ActivationTransportUnavailable] — network error, >30s timeout, or a 5xx
//                                        server error (no definitive answer).
//                                        Maps to ActivationConnectionError.
//
// REUSE, DON'T REBUILD:
//   * Network transport reuses the project's pinned HTTP client
//     (`createPinnedHttpClient`) — the same client `api_client.dart` uses.
//   * The base URL is the existing `ApiConfig.baseUrl` (the AWS License_Server).
//   * The bearer token is read from the existing `SessionManager`.
// The request/response shape mirrors `my-backend` `activateOfflineLicense`
// exactly (request: { licenseKey, fingerprint:{cpuId,macAddress,hddSerial,
// osType,hostname} }; success envelope: { data: { licenseToken, ... } }).
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../config/api_config.dart';
import '../../../security/network/pinned_http_client.dart';
import '../../di/service_locator.dart';
import '../../services/logger_service.dart';
import '../../session/session_manager.dart';

/// The maximum time the Activation_Service waits for a License_Server response
/// (Requirement 5.3). Exceeding it is treated as a connection error (5.12).
const Duration kActivationResponseBudget = Duration(seconds: 30);

/// Classified result of the one-time activation call.
sealed class ActivationTransportResult {
  const ActivationTransportResult();
}

/// 2xx success carrying the parsed `data` object from the response envelope.
class ActivationTransportSuccess extends ActivationTransportResult {
  /// The OfflineActivationResult fields: licenseToken, fingerprintHash,
  /// tenantId, plan, maxDevices, activatedDeviceCount, ttlSeconds, expiresAt.
  final Map<String, dynamic> data;
  const ActivationTransportSuccess(this.data);
}

/// A definitive server rejection (4xx). Carries the structured reason so the
/// Activation_Service can surface exactly why activation was refused (Req 5.11).
class ActivationTransportRejected extends ActivationTransportResult {
  /// Machine-readable error code (e.g. `KEY_DENYLISTED`,
  /// `DEVICE_ALLOWANCE_EXHAUSTED`, `INVALID_LICENSE_KEY`).
  final String code;

  /// Human-readable rejection message.
  final String message;

  /// The HTTP status code that carried the rejection.
  final int statusCode;

  const ActivationTransportRejected({
    required this.code,
    required this.message,
    required this.statusCode,
  });
}

/// The server could not be reached, did not answer within the budget, or
/// returned a 5xx — i.e. no definitive answer (Req 5.12).
class ActivationTransportUnavailable extends ActivationTransportResult {
  /// One of [reasonTimeout], [reasonConnectionFailed], [reasonServerError].
  final String reason;

  /// A short detail for logging/UX (never contains secrets).
  final String detail;

  const ActivationTransportUnavailable({
    required this.reason,
    this.detail = '',
  });

  static const String reasonTimeout = 'timeout';
  static const String reasonConnectionFailed = 'connection_failed';
  static const String reasonServerError = 'server_error';
}

/// Sends the activation request to the License_Server.
abstract class ActivationTransport {
  /// POSTs the [licenseKey] + [fingerprint] components to the License_Server and
  /// returns a classified [ActivationTransportResult]. Must apply the response
  /// budget ([kActivationResponseBudget]) and must never throw for ordinary
  /// network/timeout/5xx conditions — those become
  /// [ActivationTransportUnavailable].
  Future<ActivationTransportResult> activateOffline({
    required String licenseKey,
    required Map<String, String> fingerprint,
  });
}

/// Default HTTP implementation against `POST /license/activate-offline`.
class HttpActivationTransport implements ActivationTransport {
  static const String _logTag = 'ActivationTransport';
  static const String _path = '/license/activate-offline';

  final http.Client _httpClient;
  final String _baseUrl;
  final Duration _responseBudget;
  final Future<String?> Function()? _authTokenProvider;

  HttpActivationTransport({
    http.Client? httpClient,
    String? baseUrl,
    Duration responseBudget = kActivationResponseBudget,
    Future<String?> Function()? authTokenProvider,
  }) : _httpClient = httpClient ?? createPinnedHttpClient(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _responseBudget = responseBudget,
       _authTokenProvider = authTokenProvider;

  @override
  Future<ActivationTransportResult> activateOffline({
    required String licenseKey,
    required Map<String, String> fingerprint,
  }) async {
    final uri = Uri.parse('$_baseUrl$_path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await _resolveAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final body = jsonEncode({
      'licenseKey': licenseKey,
      'fingerprint': {
        'cpuId': fingerprint['cpuId'] ?? '',
        'macAddress': fingerprint['macAddress'] ?? '',
        'hddSerial': fingerprint['hddSerial'] ?? '',
        'osType': fingerprint['osType'] ?? '',
        'hostname': fingerprint['hostname'] ?? '',
      },
    });

    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: body)
          .timeout(_responseBudget);
      return _classify(response);
    } on TimeoutException {
      LoggerService.w(_logTag, 'Activation request timed out (>30s).');
      return const ActivationTransportUnavailable(
        reason: ActivationTransportUnavailable.reasonTimeout,
        detail: 'No response within the 30-second activation window.',
      );
    } on SocketException catch (e) {
      LoggerService.w(_logTag, 'Activation request connection failed.');
      return ActivationTransportUnavailable(
        reason: ActivationTransportUnavailable.reasonConnectionFailed,
        detail: e.message,
      );
    } on http.ClientException catch (e) {
      LoggerService.w(_logTag, 'Activation request client error.');
      return ActivationTransportUnavailable(
        reason: ActivationTransportUnavailable.reasonConnectionFailed,
        detail: e.message,
      );
    } on HandshakeException catch (e) {
      LoggerService.w(_logTag, 'Activation request TLS handshake failed.');
      return ActivationTransportUnavailable(
        reason: ActivationTransportUnavailable.reasonConnectionFailed,
        detail: e.message,
      );
    } on CertificatePinningException catch (e) {
      LoggerService.w(_logTag, 'Activation request certificate pin failed.');
      return ActivationTransportUnavailable(
        reason: ActivationTransportUnavailable.reasonConnectionFailed,
        detail: e.message,
      );
    }
  }

  /// Classifies an HTTP response into the transport result cases.
  ActivationTransportResult _classify(http.Response response) {
    final status = response.statusCode;
    final parsed = _tryParseJson(response.body);

    if (status >= 200 && status < 300) {
      // Success envelope: { status, success, data: {...}, meta }.
      final data = parsed?['data'];
      if (data is Map<String, dynamic> && data['licenseToken'] is String) {
        return ActivationTransportSuccess(data);
      }
      // 2xx without a usable token is treated as an unavailable server: we
      // cannot complete activation and must not fabricate a token.
      LoggerService.w(_logTag, 'Activation 2xx response missing licenseToken.');
      return const ActivationTransportUnavailable(
        reason: ActivationTransportUnavailable.reasonServerError,
        detail: 'Success response did not contain a license token.',
      );
    }

    if (status >= 500) {
      // No definitive answer — treat like a connection error (Req 5.12).
      return ActivationTransportUnavailable(
        reason: ActivationTransportUnavailable.reasonServerError,
        detail: 'HTTP $status',
      );
    }

    // 4xx — a definitive rejection (Req 5.11). Pull the structured error.
    final error = parsed?['error'];
    final code = (error is Map && error['code'] is String)
        ? error['code'] as String
        : 'ACTIVATION_REJECTED';
    final message = (error is Map && error['message'] is String)
        ? error['message'] as String
        : (parsed?['message'] as String?) ?? 'Activation was rejected.';

    return ActivationTransportRejected(
      code: code,
      message: message,
      statusCode: status,
    );
  }

  Map<String, dynamic>? _tryParseJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Resolves the bearer token from the injected provider, falling back to the
  /// registered [SessionManager]. Never throws.
  Future<String?> _resolveAuthToken() async {
    if (_authTokenProvider != null) {
      try {
        return await _authTokenProvider();
      } catch (_) {
        return null;
      }
    }
    try {
      if (sl.isRegistered<SessionManager>()) {
        return await sl<SessionManager>().getAccessToken();
      }
    } catch (_) {
      // ignore — proceed unauthenticated; the server decides.
    }
    return null;
  }
}
