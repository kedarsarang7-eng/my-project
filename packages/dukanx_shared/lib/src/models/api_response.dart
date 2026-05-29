import 'package:equatable/equatable.dart';

class ApiResponse<T> extends Equatable {
  final int statusCode;
  final T? data;
  final String? error;
  final String? code;
  final bool isSuccess;
  final String? correlationId;

  const ApiResponse({
    required this.statusCode,
    this.data,
    this.error,
    this.code,
    required this.isSuccess,
    this.correlationId,
  });

  factory ApiResponse.success(int statusCode, T data, {String? correlationId}) =>
      ApiResponse(statusCode: statusCode, data: data, isSuccess: true, correlationId: correlationId);

  factory ApiResponse.failure(int statusCode, String error, {String? code, String? correlationId}) =>
      ApiResponse(statusCode: statusCode, error: error, code: code, isSuccess: false, correlationId: correlationId);

  factory ApiResponse.offline() => const ApiResponse(
        statusCode: -1,
        error: 'No internet connection',
        code: 'OFFLINE',
        isSuccess: false,
      );

  factory ApiResponse.networkError(String message) => ApiResponse(
        statusCode: -2,
        error: message,
        code: 'NETWORK_ERROR',
        isSuccess: false,
      );

  factory ApiResponse.timeout() => const ApiResponse(
        statusCode: -3,
        error: 'Request timed out',
        code: 'TIMEOUT',
        isSuccess: false,
      );

  @override
  List<Object?> get props => [statusCode, data, error, code, isSuccess, correlationId];
}
