class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  AppException({
    required this.message,
    this.code,
    this.details,
  });

  @override
  String toString() {
    return 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
  }

  factory AppException.fromDioError(dynamic error) {
    if (error is Map<String, dynamic>) {
      return AppException(
        message: error['message'] ?? 'An error occurred',
        code: error['code'],
        details: error['details'],
      );
    }

    return AppException(
      message: error.toString(),
    );
  }

  factory AppException.networkError() {
    return AppException(
      message: 'Network connection error. Please check your internet connection.',
      code: 'NETWORK_ERROR',
    );
  }

  factory AppException.unauthorized() {
    return AppException(
      message: 'You are not authorized to perform this action.',
      code: 'UNAUTHORIZED',
    );
  }

  factory AppException.forbidden() {
    return AppException(
      message: 'Access denied. You do not have permission to access this resource.',
      code: 'FORBIDDEN',
    );
  }

  factory AppException.notFound() {
    return AppException(
      message: 'The requested resource was not found.',
      code: 'NOT_FOUND',
    );
  }

  factory AppException.validationError(String field, String reason) {
    return AppException(
      message: 'Validation error: $field - $reason',
      code: 'VALIDATION_ERROR',
      details: {'field': field, 'reason': reason},
    );
  }

  factory AppException.serverError() {
    return AppException(
      message: 'Server error. Please try again later.',
      code: 'SERVER_ERROR',
    );
  }
}