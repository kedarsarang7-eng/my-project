// ============================================================================
// LICENSE_VALIDATION_TRANSPORT — bounded background revalidation call
// ============================================================================
// Feature: offline-license-activation (Task 5.2)
//
// Sends the stored License_Token + current Machine_Fingerprint to the
// License_Server endpoint `POST /license/validate-offline` so the silent
// background validator can confirm the license is still valid and learn the
// server-provided `Last_Validated_At` (Requirements 7.3, 7.5).
//
// It classifies the outcome into exactly the cases the License_Validator needs:
//
//   * [ValidationTransportSuccess]     — 2xx carrying the server `Last_Validated_At`.
//   * [ValidationTransportRejected]    — a DEFINITIVE 4xx server "no" (revoked /
//                                        denylisted / invalid). The validator
//                                        RETAINS state; the un-refreshed
//                                        `Last_Validated_At` then drives the
//                                        grace period naturally over time.
//   * [ValidationTransportUnavailable] — network error, >2s timeout, or a 5xx
//                                        server error (no definitive answer).
//                                        The validator RETAINS state (Req 7.12).
//
// REUSE, DON'T REBUILD (mirrors `activation_transport.dart` exactly):
//   * Network transport reuses the project's pinned HTTP client
//     (`createPinnedHttpClient`) — the same client `api_client.dart` uses.
//   * The base URL is the existing `ApiConfig.baseUrl`.
//   * The bearer token is read from the existing `SessionManager`.
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

/// The maximum time a single background validation attempt may take before it
/// is abandoned (Requirement 7.3). The License_Validator enforces this as the
/// authoritative per-attempt budget; the transport applies the same value to
/// its own network call so a hung socket cannot exceed it.
const Duration kValidationAttemptBudget = Duration(seconds: 2);

/// Classified result of one background validation call.
sealed class ValidationTransportResult {
  const ValidationTransportResult();
}

/// 2xx success carrying the server-provided `Last_Validated_At` (Requirement 7.5).
class ValidationTransportSuccess extends ValidationTransportResult {
  /// The trusted timestamp the server recorded for this successful validation.
  final DateTime lastValidatedAt;
  const ValidationTransportSuccess(this.lastValidatedAt);
}

/// A definitive server rejection (4xx): the license was revoked, denylisted, or
/// is otherwise invalid. The validator does not advance state from this; the
/// stale `Last_Validated_At` causes the grace period to elapse naturally.
class ValidationTransportRejected extends ValidationTransportResult {
  /// Machine-readable error code (e.g. `KEY_DENYLISTED`, `LICENSE_REVOKED`).
  final String code;

  /// Human-readable rejection message (never contains secrets).
  final String message;

  /// The HTTP status code that carried the rejection.
  final int statusCode;

  const ValidationTransportRejected({
    required this.code,
    required this.message,
    required this.statusCode,
  });
}

/// The server could not be reached, did not answer within the budget, or
/// returned a 5xx — i.e. no definitive answer (Requirement 7.12).
class ValidationTransportUnavailable extends ValidationTransportResult {
  /// One of [reasonTimeout], [reasonConnectionFailed], [reasonServerError].
  final String reason;

  /// A short detail for logging (never contains secrets).
  final String detail;

  const ValidationTransportUnavailable({
    required this.reason,
    this.detail = '',
  });

  static const String reasonTimeout = 'timeout';
  static const String reasonConnectionFailed = 'connection_failed';
  static const String reasonServerError = 'server_error';
}

/// Performs the bounded background revalidation request.
abstract class LicenseValidationTransport {
  /// POSTs the [licenseToken] + [fingerprint] components to the License_Server
  /// and returns a classified [ValidationTransportResult]. Must apply the
  /// response budget ([kValidationAttemptBudget]) and must never throw for
  /// ordinary network/timeout/5xx conditions — those become
  /// [ValidationTransportUnavailable].
  Future<ValidationTransportResult> validate({
    required String licenseToken,
    required Map<String, String> fingerprint,
  });
}

/// Default HTTP implementation against `POST /license/validate-offline`.
class HttpLicenseValidationTransport implements LicenseValidationTransport {
  static const String _logTag = 'LicenseValidationTransport';
  static const String _path = '/license/validate-offline';

  final http.Client _httpClient;
  final String _baseUrl;
  final Duration _responseBudget;
  final Future<String?> Function()? _authTokenProvider;

  HttpLicenseValidationTransport({
    http.Client? httpClient,
    String? baseUrl,
    Duration responseBudget = kValidationAttemptBudget,
    Future<String?> Function()? authTokenProvider,
  }) : _httpClient = httpClient ?? createPinnedHttpClient(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _responseBudget = responseBudget,
       _authTokenProvider = authTokenProvider;

  @override
  Future<ValidationTransportResult> validate({
    required String licenseToken,
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
      'licenseToken': licenseToken,
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
      LoggerService.w(_logTag, 'Validation request timed out (>2s).');
      return const ValidationTransportUnavailable(
        reason: ValidationTransportUnavailable.reasonTimeout,
        detail: 'No response within the 2-second validation budget.',
      );
    } on SocketException catch (e) {
      LoggerService.w(_logTag, 'Validation request connection failed.');
      return ValidationTransportUnavailable(
        reason: ValidationTransportUnavailable.reasonConnectionFailed,
        detail: e.message,
      );
    } on http.ClientException catch (e) {
      LoggerService.w(_logTag, 'Validation request client error.');
      return ValidationTransportUnavailable(
        reason: ValidationTransportUnavailable.reasonConnectionFailed,
        detail: e.message,
      );
    } on HandshakeException catch (e) {
      LoggerService.w(_logTag, 'Validation request TLS handshake failed.');
      return ValidationTransportUnavailable(
        reason: ValidationTransportUnavailable.reasonConnectionFailed,
        detail: e.message,
      );
    } on CertificatePinningException catch (e) {
      LoggerService.w(_logTag, 'Validation request certificate pin failed.');
      return ValidationTransportUnavailable(
        reason: ValidationTransportUnavailable.reasonConnectionFailed,
        detail: e.message,
      );
    }
  }

  /// Classifies an HTTP response into the transport result cases.
  ValidationTransportResult _classify(http.Response response) {
    final status = response.statusCode;
    final parsed = _tryParseJson(response.body);

    if (status >= 200 && status < 300) {
      // Success envelope: { status, success, data: { lastValidatedAt }, meta }.
      final data = parsed?['data'];
      if (data is Map<String, dynamic>) {
        final lastValidated = _parseTimestamp(data['lastValidatedAt']);
        if (lastValidated != null) {
          return ValidationTransportSuccess(lastValidated);
        }
      }
      // 2xx without a usable timestamp cannot be trusted to advance state.
      LoggerService.w(
        _logTag,
        'Validation 2xx response missing lastValidatedAt.',
      );
      return const ValidationTransportUnavailable(
        reason: ValidationTransportUnavailable.reasonServerError,
        detail: 'Success response did not contain a Last_Validated_At value.',
      );
    }

    if (status >= 500) {
      // No definitive answer — treat like a connection error (Req 7.12).
      return ValidationTransportUnavailable(
        reason: ValidationTransportUnavailable.reasonServerError,
        detail: 'HTTP $status',
      );
    }

    // 4xx — a definitive rejection. Pull the structured error.
    final error = parsed?['error'];
    final code = (error is Map && error['code'] is String)
        ? error['code'] as String
        : 'VALIDATION_REJECTED';
    final message = (error is Map && error['message'] is String)
        ? error['message'] as String
        : (parsed?['message'] as String?) ?? 'Validation was rejected.';

    return ValidationTransportRejected(
      code: code,
      message: message,
      statusCode: status,
    );
  }

  /// Parses an ISO-8601 string or epoch-seconds/millis number into a UTC
  /// [DateTime], returning `null` when the value is absent/unparseable.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc();
    }
    if (value is num) {
      // Heuristic: values past year ~2001 in seconds are < 1e12; treat large
      // values as milliseconds.
      final asInt = value.toInt();
      final ms = asInt > 1000000000000 ? asInt : asInt * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    return null;
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
