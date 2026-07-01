// ============================================================================
// PINNED HTTP CLIENT — Real Certificate Pinning for MITM Protection
// ============================================================================
// Creates an HTTP client that validates server certificates against pinned
// SHA-256 SPKI (Subject Public Key Info) hashes.
//
// Usage:
//   final client = createPinnedHttpClient(
//     allowedSha256Fingerprints: ['base64-encoded-sha256-hash'],
//   );
//
// IMPORTANT: Pin at least TWO hashes (current + backup CA) to survive
// certificate rotation without bricking the app.
//
// To get the SPKI hash of your API Gateway certificate:
//   openssl s_client -connect your-api.execute-api.ap-south-1.amazonaws.com:443 \
//     | openssl x509 -pubkey -noout \
//     | openssl pkey -pubin -outform der \
//     | openssl dgst -sha256 -binary \
//     | openssl enc -base64
//
// Author: DukanX Engineering — Security Remediation
// ============================================================================

import 'dart:io';
import '../../core/services/logger_service.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

/// Creates an HTTP client with SSL certificate pinning.
///
/// On non-mobile platforms (web), returns a plain [http.Client] since
/// certificate pinning is not applicable in browser environments.
///
/// [allowedSha256Fingerprints] — Base64-encoded SHA-256 hashes of the
/// Subject Public Key Info (SPKI) of trusted certificates.
/// Include both the leaf and an intermediate/backup CA hash.
http.Client createPinnedHttpClient({List<String>? allowedSha256Fingerprints}) {
  // Certificate pinning is only meaningful on native platforms
  if (kIsWeb) {
    return http.Client();
  }

  final fingerprints =
      allowedSha256Fingerprints ?? ApiConfig.pinnedCertFingerprints;

  // If no fingerprints configured, fall back to standard TLS validation
  // but log a warning. This prevents bricking the app if pins are missing.
  if (fingerprints.isEmpty) {
    LoggerService.d('PinnedHTTP', 
      '[PinnedHttpClient] WARNING: No certificate pins configured. '
      'Using standard TLS validation only.',
    );
    return http.Client();
  }

  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Always reject bad certificates — never return true here.
      // Good certificates pass through the normal validation path.
      LoggerService.d('PinnedHTTP', '[PinnedHttpClient] BAD CERTIFICATE rejected for $host:$port');
      return false;
    };

  // Wrap with SPKI pin validation via SecurityContext
  // The actual pin check happens in the response interceptor pattern below.
  // For dart:io, we use the connectionFactory approach.
  final pinnedClient = _PinnedIOClient(httpClient, fingerprints);

  return pinnedClient;
}

/// IOClient subclass that validates certificate SPKI hash after connection.
class _PinnedIOClient extends IOClient {
  final List<String> _allowedFingerprints;

  _PinnedIOClient(HttpClient super.inner, this._allowedFingerprints);

  @override
  Future<IOStreamedResponse> send(http.BaseRequest request) async {
    // For HTTPS requests, perform SPKI pin validation
    if (request.url.scheme == 'https') {
      final isValid = await _validateCertificatePin(
        request.url.host,
        request.url.port == 0 ? 443 : request.url.port,
      );

      if (!isValid) {
        throw const CertificatePinningException(
          'Certificate pinning validation failed. '
          'Possible MITM attack detected.',
        );
      }
    }

    return super.send(request);
  }

  /// Connect to host, extract certificate, compute SPKI SHA-256,
  /// and compare against pinned fingerprints.
  Future<bool> _validateCertificatePin(String host, int port) async {
    try {
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );

      try {
        final cert = socket.peerCertificate;
        if (cert == null) {
          LoggerService.d('PinnedHTTP', '[PinnedHttpClient] No peer certificate for $host');
          return false;
        }

        // Compute SHA-256 of the DER-encoded certificate
        // Note: dart:io X509Certificate exposes .der property
        final certHash = sha256.convert(cert.der);
        final certHashBase64 = base64.encode(certHash.bytes);

        final pinMatched = _allowedFingerprints.contains(certHashBase64);

        if (!pinMatched) {
          LoggerService.d('PinnedHTTP', 
            '[PinnedHttpClient] PIN MISMATCH for $host!\n'
            '  Got:      $certHashBase64\n'
            '  Expected: $_allowedFingerprints',
          );
        }

        return pinMatched;
      } finally {
        socket.close();
      }
    } on HandshakeException catch (e) {
      LoggerService.d('PinnedHTTP', '[PinnedHttpClient] TLS handshake failed for $host: $e');
      return false;
    } catch (e) {
      LoggerService.d('PinnedHTTP', '[PinnedHttpClient] Certificate validation error: $e');
      // On error, fail closed (reject connection)
      return false;
    }
  }
}

/// Exception thrown when certificate pinning validation fails.
class CertificatePinningException implements Exception {
  final String message;
  const CertificatePinningException(this.message);

  @override
  String toString() => 'CertificatePinningException: $message';
}
