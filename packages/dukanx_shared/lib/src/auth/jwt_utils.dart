import 'dart:convert';

class JwtUtils {
  JwtUtils._();

  /// Decodes a JWT payload without signature verification.
  /// Verification is performed server-side by Cognito.
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static DateTime? expiryFromToken(String token) {
    final payload = decodePayload(token);
    if (payload == null) return null;
    final exp = payload['exp'];
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
  }

  static String? claimFromToken(String token, String claim) {
    return decodePayload(token)?[claim] as String?;
  }

  static bool isExpired(String token) {
    final expiry = expiryFromToken(token);
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry);
  }

  static bool isNearExpiry(String token, {int bufferMinutes = 5}) {
    final expiry = expiryFromToken(token);
    if (expiry == null) return true;
    return DateTime.now()
        .isAfter(expiry.subtract(Duration(minutes: bufferMinutes)));
  }
}
