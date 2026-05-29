import 'dart:convert';

class JwtUtils {
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool isExpired(String token) {
    final payload = decodePayload(token);
    if (payload == null) return true;
    final exp = payload['exp'];
    if (exp == null) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    return DateTime.now().isAfter(expiry);
  }

  static DateTime? expiryFromToken(String token) {
    final payload = decodePayload(token);
    if (payload == null) return null;
    final exp = payload['exp'];
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
  }
}
