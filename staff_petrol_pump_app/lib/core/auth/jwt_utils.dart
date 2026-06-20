import 'dart:convert';

/// Decodes the payload (claims) from a JWT token without signature verification.
/// Signature verification is handled server-side by Cognito.
///
/// Throws [FormatException] if the token is malformed (not 3 segments or
/// invalid base64).
Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw const FormatException(
      'Invalid JWT: token must have exactly 3 segments',
    );
  }

  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  } catch (e) {
    throw FormatException('Invalid JWT payload: $e');
  }
}

/// Returns `true` if the token's `exp` claim is in the past or missing.
///
/// A token is considered expired when:
/// - The token is malformed (cannot be decoded)
/// - The `exp` claim is missing
/// - The `exp` timestamp is less than or equal to the current Unix time
bool isTokenExpired(String token) {
  try {
    final payload = decodeJwtPayload(token);
    final exp = payload['exp'];
    if (exp == null) return true;
    final expSeconds = (exp is int) ? exp : (exp as num).toInt();
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds >= expSeconds;
  } catch (_) {
    return true;
  }
}
