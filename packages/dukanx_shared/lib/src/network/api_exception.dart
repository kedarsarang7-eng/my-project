class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final String? correlationId;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.correlationId,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
  bool get isOffline => statusCode == -1;

  factory ApiException.fromBody(int statusCode, Map<String, dynamic> body,
      {String? correlationId}) {
    return ApiException(
      statusCode: statusCode,
      message: body['message'] as String? ?? 'Unexpected error',
      code: body['code'] as String? ?? body['error'] as String?,
      correlationId: correlationId,
    );
  }

  @override
  String toString() =>
      'ApiException($statusCode, code: $code, message: $message)';
}
