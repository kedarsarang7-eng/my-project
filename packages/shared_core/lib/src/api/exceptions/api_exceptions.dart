/// Base exception for all API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Network / connectivity error
class NetworkException extends ApiException {
  const NetworkException({required super.message}) : super(statusCode: null);
}

/// 401 Unauthorized
class UnauthorizedException extends ApiException {
  const UnauthorizedException({required super.message}) : super(statusCode: 401);
}

/// 403 Forbidden
class ForbiddenException extends ApiException {
  const ForbiddenException({required super.message}) : super(statusCode: 403);
}

/// 429 Rate limit exceeded
class RateLimitException extends ApiException {
  final int? retryAfter;

  const RateLimitException({required super.message, this.retryAfter})
      : super(statusCode: 429);
}

/// 5xx Server error
class ServerException extends ApiException {
  const ServerException({required super.message, required int statusCode})
      : super(statusCode: statusCode);
}
