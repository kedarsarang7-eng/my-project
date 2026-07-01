// ============================================================================
// LICENSE_TOKEN — RS256 license JWT returned by the License_Server
// ============================================================================
// Feature: offline-license-activation (supports Task 4.3, reused by 5.x / 10.x)
//
// The License_Token is the RSA-signed (RS256) JWT the License_Server returns on
// successful activation (Requirement 5.5). It wraps the UNCHANGED
// LicenseKeyPayload claims (tenantId, plan, allowedBusinessTypes, maxUsers,
// maxDevices, features, expiresAt, issuedAt, keyVersion, superAdminOverride)
// plus the machine-binding `fingerprintHash` and the standard JWT `iat`/`exp`
// claims (design "Data Models → License_Token").
//
// This model is a thin, dependency-free holder around the raw JWT and its
// decoded claims. It deliberately does NOT verify the RS256 signature here:
//   * On activation (task 4.3) the token has just arrived over TLS from the
//     License_Server, so it is trusted for storage.
//   * Signature verification against the bundled public key is the
//     License_Validator's responsibility (task 5.x).
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:convert';

/// The RS256 license JWT plus its decoded claim set.
///
/// Construct with [LicenseToken.fromJwt] from the compact JWT string the
/// License_Server returns, or with the default constructor when the raw token
/// and claims are already known (e.g. when re-reading a stored token).
class LicenseToken {
  /// The compact RS256 JWT exactly as issued by the License_Server. This is the
  /// value persisted (encrypted) in the Local_License_File.
  final String raw;

  /// The decoded JWT payload (claims). Read-only view of the bound license.
  final Map<String, dynamic> claims;

  const LicenseToken({required this.raw, required this.claims});

  /// Decode a compact JWT string into a [LicenseToken] without verifying the
  /// signature. Throws [FormatException] when the value is not a well-formed
  /// three-part JWT with a JSON object payload.
  factory LicenseToken.fromJwt(String jwt) {
    final token = jwt.trim();
    final parts = token.split('.');
    if (parts.length != 3 || parts[1].isEmpty) {
      throw const FormatException('Not a well-formed JWT');
    }

    final payloadJson = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JWT payload is not a JSON object');
    }

    return LicenseToken(raw: token, claims: decoded);
  }

  /// Owning tenant identifier.
  String? get tenantId => claims['tenantId'] as String?;

  /// Granted plan tier label (e.g. `basic`, `pro`, `premium`, `enterprise`).
  String? get plan => claims['plan'] as String?;

  /// Business verticals this license grants access to.
  List<String> get allowedBusinessTypes {
    final value = claims['allowedBusinessTypes'];
    if (value is List) {
      return value.map((e) => e.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  /// The device allowance carried by the unchanged `LicenseKeyPayload`
  /// (`maxDevices`). This is the count of devices the license permits to share
  /// one offline deployment, used by the LAN_Coordinator to cap the number of
  /// connected devices (Requirement 15.5). Defaults to one device per license
  /// (Requirement 5.8) when the claim is missing or unparseable, and is never
  /// reported below 1.
  int get maxDevices {
    final value = claims['maxDevices'];
    final parsed = switch (value) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? 1,
      _ => 1,
    };
    return parsed < 1 ? 1 : parsed;
  }

  /// Machine-binding hash carried in the token: SHA256(cpuId+macAddress+hddSerial).
  String? get fingerprintHash => claims['fingerprintHash'] as String?;

  /// Whether the token carries the super-admin override (grants everything).
  bool get superAdminOverride => claims['superAdminOverride'] == true;

  /// Token issued-at time, derived from the JWT `iat` claim (seconds since
  /// epoch), or `null` when absent/unparseable.
  DateTime? get issuedAt => _epochSeconds(claims['iat']);

  /// Token expiry time, derived from the JWT `exp` claim (seconds since epoch),
  /// or `null` when absent/unparseable.
  DateTime? get expiresAt => _epochSeconds(claims['exp']);

  static DateTime? _epochSeconds(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * 1000,
        isUtc: true,
      );
    }
    return null;
  }

  /// Masked representation — a raw license token is a secret and must never
  /// reach logs verbatim (Security_Layer log-scrubbing, Requirement 17.10).
  @override
  String toString() {
    final tail = raw.length <= 8 ? '****' : '…${raw.substring(raw.length - 6)}';
    return 'LicenseToken(tenant: $tenantId, plan: $plan, jwt: $tail)';
  }
}
